import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'formula_evaluator.dart';
import 'models/dynamic_form_field.dart';
import 'widgets/dynamic_form_field_wrapper.dart';
import 'widgets/formula_field_widget.dart';
import 'widgets/boolean_field_widget.dart';
import 'widgets/datetime_field_widget.dart';
import 'widgets/gps_coordinates_field_widget.dart';
import 'widgets/gps_field_widget.dart';
import 'widgets/long_text_field_widget.dart';
import 'widgets/multiple_choice_field_widget.dart';
import 'widgets/number_field_widget.dart';
import 'widgets/photo_field_widget.dart';
import 'widgets/rating_field_widget.dart';
import 'widgets/single_choice_field_widget.dart';
import 'widgets/text_field_widget.dart';
import '../widgets/location_field_widget.dart';
import '../widgets/erp_partner_field_widget.dart';
import '../widgets/geo_select_field_widget.dart';
import '../map/app_map_location_card.dart';

class DynamicFormBuilder extends StatefulWidget {
  /// Danh sách đặc tả các trường form nhận từ API
  final List<DynamicFormField> fields;

  /// Dữ liệu khởi tạo (Map key-value)
  final Map<String, dynamic> initialData;

  /// Callback khi có bất kỳ trường nào thay đổi giá trị
  final void Function(Map<String, dynamic> formData)? onChanged;

  /// Callback khi nhấn nút Lưu / Submit form
  final Future<void> Function(Map<String, dynamic> formData)? onSubmit;

  /// Text nút submit (nếu null sẽ không vẽ nút submit tự động)
  final String? submitButtonText;

  /// Đang submit (loading)
  final bool isSubmitting;

  /// Giữ ĐÚNG thứ tự [fields]: mỗi đoạn ô liền nhau cùng `section` là một khối, không gom ô cùng mục ở xa về một chỗ
  /// (màn tạo điểm bán theo Cấu hình trường điểm bán — chủ hệ thống 21/10/2026). Mặc định gom như cũ.
  final bool keepFieldOrder;

  /// Vẽ RIÊNG một số ô theo MÃ (vd `erp_links` — ô "Khách hàng ERP" của form điểm bán, #24331) — màn gọi cung cấp widget, form
  /// động giữ giá trị và lỗi như ô thường. `onChanged` của builder = [updateFieldValue].
  final Map<String, Widget Function(DynamicFormField field, dynamic value, String? errorText, ValueChanged<dynamic> onChanged)>?
      customFieldBuilders;

  /// Kiểm RIÊNG theo MÃ (chạy thay cho phép kiểm "bắt buộc" mặc định của ô đó): trả câu lỗi hoặc `null`.
  final Map<String, String? Function(DynamicFormField field, dynamic value)>? customValidators;

  /// Mã các ô đang ẨN theo điều kiện `show_if`, tính từ dữ liệu ĐANG nhập (gọi lại sau mỗi lần đổi giá trị). Ô ẩn: không
  /// vẽ, không kiểm bắt buộc, không có trong [DynamicFormBuilderState.getFormData] / `onSubmit` (giá trị đã gõ vẫn giữ
  /// trong form để hiện lại khi điều kiện đúng trở lại). `null` = không ô nào ẩn.
  final Set<String> Function(Map<String, dynamic> formData)? hiddenFieldsOf;

  /// Giá trị NỀN cho ô công thức (màn sửa: giá trị đang lưu của điểm bán) — ô động không có trên form vẫn được công
  /// thức đọc như server (đang lưu + phần gửi). Giá trị trên form đè lên nền.
  final Map<String, dynamic> formulaBaseData;

  const DynamicFormBuilder({
    super.key,
    required this.fields,
    this.initialData = const {},
    this.onChanged,
    this.onSubmit,
    this.submitButtonText,
    this.isSubmitting = false,
    this.keepFieldOrder = false,
    this.customFieldBuilders,
    this.customValidators,
    this.hiddenFieldsOf,
    this.formulaBaseData = const {},
  });

  @override
  State<DynamicFormBuilder> createState() => DynamicFormBuilderState();
}

class DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final Map<String, dynamic> _formData = {};
  final Map<String, String?> _errors = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};
  final Map<String, GlobalKey> _fieldKeys = {};

  /// Địa chỉ bản đồ vừa tự điền vào `address` — lấy lại vị trí thì được thay, còn người dùng đã sửa tay thì giữ.
  String? _autoAddress;

  FocusNode _getFocusNode(String code) {
    return _fieldFocusNodes.putIfAbsent(code, () => FocusNode());
  }

  GlobalKey _getFieldKey(String code) {
    return _fieldKeys.putIfAbsent(code, () => GlobalKey());
  }

  @override
  void initState() {
    super.initState();
    _initializeData(preserveExisting: false);
  }

  @override
  void didUpdateWidget(covariant DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi widget cập nhật (rebuild, isSubmitting thay đổi, v.v.), luôn giữ lại toàn bộ dữ liệu người dùng đã nhập
    _initializeData(preserveExisting: true);
  }

  @override
  void dispose() {
    for (final node in _fieldFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _initializeData({bool preserveExisting = false}) {
    final existingData = preserveExisting ? Map<String, dynamic>.from(_formData) : <String, dynamic>{};
    _formData.clear();

    for (final field in widget.fields) {
      // Khởi tạo trước key và focusNode cho trường
      _getFieldKey(field.code);
      _getFocusNode(field.code);

      // Nếu người dùng đã nhập hoặc chỉnh sửa dữ liệu của trường này -> Giữ nguyên 100% không bị mất
      if (preserveExisting && existingData.containsKey(field.code) && existingData[field.code] != null) {
        _formData[field.code] = existingData[field.code];
      } else if (widget.initialData.containsKey(field.code)) {
        _formData[field.code] = widget.initialData[field.code];
      } else if (preserveExisting && existingData.containsKey(field.code)) {
        _formData[field.code] = existingData[field.code];
      } else if (field.initialValue != null) {
        _formData[field.code] = field.initialValue;
      } else {
        // Default fallbacks according to type
        switch (field.type) {
          case DynamicFormFieldType.multipleChoice:
            _formData[field.code] = <dynamic>[];
            break;
          case DynamicFormFieldType.photo:
            _formData[field.code] = <String>[];
            break;
          case DynamicFormFieldType.boolean:
            _formData[field.code] = false;
            break;
          case DynamicFormFieldType.rating:
            _formData[field.code] = (field.min ?? 5).toInt();
            break;
          default:
            _formData[field.code] = null;
        }
      }
    }

    // `address` không có ô riêng (admin ẩn) vẫn được ô Vị trí ghi vào — giữ qua mỗi lần dựng lại, không thì mất địa chỉ.
    if (!widget.fields.any((f) => f.code == 'address')) {
      final addr = existingData['address'] ?? widget.initialData['address'];
      if (addr != null) _formData['address'] = addr;
    }
  }

  /// Điền địa chỉ tra từ vị trí bản đồ vào `address` khi ô đang trống hoặc vẫn là địa chỉ tự điền lần trước (lấy lại vị
  /// trí thì địa chỉ đi theo); người dùng đã gõ / sửa thì giữ nguyên.
  void _fillAddressFromMap(String? newAddress) {
    if (newAddress == null || newAddress.trim().isEmpty) return;
    final current = _formData['address']?.toString().trim() ?? '';
    if (current.isEmpty || current == _autoAddress) {
      _autoAddress = newAddress.trim();
      updateFieldValue('address', _autoAddress);
    }
  }

  /// Ô Tỉnh/Xã (#24072): đổi tỉnh ⇒ BỎ giá trị mọi ô xã lọc theo ô tỉnh này (xã cũ không còn thuộc tỉnh mới — server
  /// cũng từ chối cặp lệch). Chọn lại đúng tỉnh cũ thì không bỏ.
  void _updateGeo(DynamicFormField field, int? id) {
    final truoc = GeoSelectFieldWidget.idOf(_formData[field.code]);
    updateFieldValue(field.code, id);
    if (field.type == DynamicFormFieldType.geoProvince && truoc != id) {
      for (final f in widget.fields) {
        if (f.dependsOn == field.code && _formData[f.code] != null) updateFieldValue(f.code, null);
      }
    }
  }

  /// Mã các ô đang ẩn theo `show_if` (xem [DynamicFormBuilder.hiddenFieldsOf]) — điều kiện đọc được kết quả ô công thức.
  Set<String> get hiddenFieldCodes => _hiddenWith(formulaValues);

  Set<String> _hiddenWith(Map<String, num?> formulas) {
    final f = widget.hiddenFieldsOf;
    if (f == null) return const <String>{};
    return f(Map<String, dynamic>.unmodifiable(formulas.isEmpty ? _formData : {..._formData, ...formulas}));
  }

  /// Kết quả các ô công thức (số đã làm tròn theo `decimals`, `null` = rỗng) — tính như server trên TOÀN BỘ giá trị:
  /// nền [DynamicFormBuilder.formulaBaseData] + mọi ô trên form, KỂ CẢ ô đang ẩn.
  Map<String, num?> get formulaValues {
    final configs = <String, FormulaConfig>{
      for (final f in widget.fields)
        if (f.type == DynamicFormFieldType.formula && f.formula != null) f.code: f.formula!,
    };
    if (configs.isEmpty) return const {};
    return FormulaEvaluator.computeAll(configs, {...widget.formulaBaseData, ..._formData});
  }

  /// Dữ liệu form BỎ các ô đang ẩn và ô công thức (server tự tính lại) — thứ được gửi đi.
  Map<String, dynamic> _visibleFormData() {
    final hidden = hiddenFieldCodes;
    final congThuc = {for (final f in widget.fields) if (f.type == DynamicFormFieldType.formula) f.code};
    return Map<String, dynamic>.from(_formData)..removeWhere((k, _) => hidden.contains(k) || congThuc.contains(k));
  }

  void updateFieldValue(String code, dynamic value) {
    setState(() {
      _formData[code] = value;
      // Clear error for this field
      if (_errors.containsKey(code)) {
        _errors[code] = null;
      }
    });
    widget.onChanged?.call(Map<String, dynamic>.from(_formData));
  }

  /// Focus vào trường dữ liệu cụ thể và cuộn màn hình đến vị trí trường đó
  void focusField(String code) {
    var targetCode = code;
    // Map alias nếu có (ví dụ lng dùng chung widget với lat, photo alias)
    if (targetCode == 'lng' && !_fieldKeys.containsKey('lng') && _fieldKeys.containsKey('lat')) {
      targetCode = 'lat';
    } else if (targetCode == 'photo' && !_fieldKeys.containsKey('photo') && _fieldKeys.containsKey('photo_file_id')) {
      targetCode = 'photo_file_id';
    } else if (targetCode == 'photo_file_id' && !_fieldKeys.containsKey('photo_file_id') && _fieldKeys.containsKey('photo')) {
      targetCode = 'photo';
    }

    // 1. Request focus trên FocusNode nếu trường hỗ trợ input
    final node = _fieldFocusNodes[targetCode];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
    }

    // 2. Cuộn viewport tới widget của trường đó
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _fieldKeys[targetCode];
      final targetContext = key?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
    });
  }

  /// Kiểm tra tính hợp lệ toàn bộ form (Validate)
  /// Nếu [focusFirstError] = true (mặc định), tự động focus và cuộn đến trường lỗi đầu tiên
  bool validate({bool focusFirstError = true}) {
    bool isValid = true;
    final newErrors = <String, String?>{};
    String? firstInvalidCode;
    final hidden = hiddenFieldCodes;

    for (final field in widget.fields) {
      // Ô đang ẩn theo `show_if` được MIỄN mọi phép kiểm (kể cả bắt buộc); ô công thức chỉ đọc, không kiểm.
      if (hidden.contains(field.code) || field.type == DynamicFormFieldType.formula) continue;
      final value = _formData[field.code];

      // 0. Ô có phép kiểm riêng (màn gọi cung cấp) — thay cho kiểm "bắt buộc" mặc định.
      final kiemRieng = widget.customValidators?[field.code];
      if (kiemRieng != null) {
        final loi = kiemRieng(field, value);
        if (loi != null) {
          newErrors[field.code] = loi;
          isValid = false;
          firstInvalidCode ??= field.code;
        }
        continue;
      }

      // 1. Kiểm tra bắt buộc nhập (Required check)
      if (field.isRequired) {
        if (value == null) {
          newErrors[field.code] = '${field.label} là bắt buộc';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
        if (value is String && value.trim().isEmpty) {
          newErrors[field.code] = '${field.label} không được để trống';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
        if (value is List && value.isEmpty) {
          newErrors[field.code] = 'Vui lòng chọn ít nhất 1 ${field.label.toLowerCase()}';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
      }

      // 2. Kiểm tra trường Vị trí GPS / Địa chỉ
      if (field.type == DynamicFormFieldType.location) {
        final isPureAddress = (field.code == 'address' ||
            field.code == 'delivery_address' ||
            field.code.contains('dia_chi') ||
            field.label.toLowerCase().contains('địa chỉ')) && !field.isCoordsField;

        if (value is Map) {
          final latVal = value['lat'];
          final lngVal = value['lng'];
          final addrVal = value['address']?.toString();

          if (isPureAddress) {
            // Đối với field địa chỉ trong form động: luôn cho phép nhập/sửa địa chỉ mà không bắt buộc toạ độ GPS
            if (field.isRequired && (addrVal == null || addrVal.trim().isEmpty)) {
              newErrors[field.code] = '${field.label} không được để trống.';
              isValid = false;
              firstInvalidCode ??= field.code;
              continue;
            }
          } else {
            // Đối với trường toạ độ GPS
            if (field.isRequired && (latVal == null || lngVal == null)) {
              if (addrVal != null && addrVal.trim().isNotEmpty) {
                newErrors[field.code] = '${field.label} cần có toạ độ GPS — bấm "Lấy vị trí".';
              } else {
                newErrors[field.code] = '${field.label} không được để trống.';
              }
              isValid = false;
              firstInvalidCode ??= field.code;
              continue;
            } else if (!field.isRequired && (latVal == null || lngVal == null) && addrVal != null && addrVal.trim().isNotEmpty) {
              newErrors[field.code] = '${field.label} cần có toạ độ GPS — bấm "Lấy vị trí".';
              isValid = false;
              firstInvalidCode ??= field.code;
              continue;
            }
          }

          if (latVal != null && lngVal != null) {
            final numLat = latVal is num ? latVal : double.tryParse(latVal.toString());
            final numLng = lngVal is num ? lngVal : double.tryParse(lngVal.toString());
            if (numLat == null || numLng == null || numLat < -90 || numLat > 90 || numLng < -180 || numLng > 180) {
              newErrors[field.code] = '${field.label} có giá trị không hợp lệ.';
              isValid = false;
              firstInvalidCode ??= field.code;
              continue;
            }
          }
        } else if (field.isRequired) {
          newErrors[field.code] = '${field.label} không được để trống.';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
      }

      // 3. Kiểm tra giới hạn số (Min/Max check)
      if (field.type == DynamicFormFieldType.number && value is num) {
        if (field.min != null && value < field.min!) {
          newErrors[field.code] = 'Giá trị phải lớn hơn hoặc bằng ${field.min}';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
        if (field.max != null && value > field.max!) {
          newErrors[field.code] = 'Giá trị phải nhỏ hơn hoặc bằng ${field.max}';
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });

    if (!isValid && focusFirstError && firstInvalidCode != null) {
      focusField(firstInvalidCode);
    }

    return isValid;
  }

  /// Lấy toàn bộ dữ liệu form hiện tại
  Map<String, dynamic> getFormData() {
    return _visibleFormData();
  }

  Future<void> _handleSubmit() async {
    if (validate()) {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(_visibleFormData());
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng hoàn thành các trường thông tin bắt buộc (*).'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  IconData _getSectionIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('chung') || lower.contains('cơ bản') || lower.contains('tổng quan')) {
      return Icons.storefront_rounded;
    }
    if (lower.contains('liên hệ') || lower.contains('người liên hệ') || lower.contains('contact')) {
      return Icons.contact_phone_rounded;
    }
    if (lower.contains('địa chỉ') || lower.contains('vị trí') || lower.contains('tọa độ') || lower.contains('gps')) {
      return Icons.location_on_rounded;
    }
    if (lower.contains('ảnh') || lower.contains('hình') || lower.contains('photo') || lower.contains('image')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('mở rộng') || lower.contains('động') || lower.contains('dynamic') || lower.contains('khác')) {
      return Icons.extension_rounded;
    }
    return Icons.folder_open_rounded;
  }

  bool _isDynamicSection(String title) {
    final lower = title.toLowerCase().trim();
    return lower.contains('mở rộng') ||
        lower.contains('động') ||
        lower.contains('dynamic') ||
        lower.isEmpty;
  }

  bool _isLocationSection(String title) {
    final lower = title.toLowerCase().trim();
    return lower.contains('vị trí') ||
        lower.contains('toạ độ') ||
        lower.contains('tọa độ') ||
        lower == 'coords';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phân nhóm các trường theo Section (nếu có) — bỏ các ô đang ẩn theo `show_if`
    _formulaValuesCache = formulaValues;
    final hidden = _hiddenWith(_formulaValuesCache);
    final sections = <MapEntry<String, List<DynamicFormField>>>[];
    for (final field in widget.fields) {
      if (hidden.contains(field.code)) continue;
      final sec = field.isCoordsField ? 'Vị trí trên bản đồ' : (field.section ?? 'Thông tin chung');
      final khoi = widget.keepFieldOrder
          ? (sections.isNotEmpty && sections.last.key == sec ? sections.last : null)
          : sections.where((e) => e.key == sec).firstOrNull;
      if (khoi != null) {
        khoi.value.add(field);
      } else {
        sections.add(MapEntry(sec, [field]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.indexed.map((cap) {
          final secEntry = cap.$2;
          final sectionTitle = secEntry.key;
          final sectionFields = secEntry.value;
          // keepFieldOrder: mục bị bản đồ (hoặc khối khác) chia đôi — phần sau vẫn trong khung nhưng KHÔNG lặp tiêu đề.
          final noiTiep = sections.take(cap.$1).any((e) => e.key == sectionTitle);

          // 🔴 Bỏ hẳn card thông tin mở rộng (động): không vẽ Card container và không vẽ Header bar,
          // các field được vẽ trực tiếp ra ngoài layout form
          if (_isDynamicSection(sectionTitle)) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSectionFieldWidgets(sectionFields),
              ),
            );
          }

          // 🔴 Giống form sửa điểm bán: Bỏ hẳn card bọc ở ngoài với field toạ độ / vị trí trên bản đồ,
          // vẽ trực tiếp AppMapLocationCard ra ngoài layout form kèm header phân đoạn
          if (_isLocationSection(sectionTitle) || sectionFields.every((f) => f.isCoordsField || f.code == 'lat' || f.code == 'lng')) {
            final isCoordsRequired = sectionFields.any((f) => f.isRequired);
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    icon: Icons.map_rounded,
                    title: sectionTitle.toLowerCase().contains('vị trí') ? sectionTitle : 'Vị trí trên bản đồ',
                    badge: isCoordsRequired ? 'Bắt buộc' : 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  ..._buildSectionFieldWidgets(sectionFields),
                ],
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header Bar
                if (!noiTiep) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Icon(
                          _getSectionIcon(sectionTitle),
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sectionTitle,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fields List inside Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSectionFieldWidgets(sectionFields),
                  ),
                ),
              ],
            ),
          );
        }),

        if (widget.submitButtonText != null) ...[
          const SizedBox(height: 8),
          AppButton(
            text: widget.submitButtonText!,
            isLoading: widget.isSubmitting,
            icon: Icons.check_circle_outline_rounded,
            width: double.infinity,
            height: 48,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String badge,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainer
                : AppColors.surfaceContainerHigh,
            borderRadius: AppRadius.roundedFull,
          ),
          child: Text(
            badge,
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSectionFieldWidgets(List<DynamicFormField> sectionFields) {
    final widgets = <Widget>[];
    final hasLat = sectionFields.any((f) => f.code == 'lat');
    final hasLng = sectionFields.any((f) => f.code == 'lng');

    for (int i = 0; i < sectionFields.length; i++) {
      final field = sectionFields[i];

      // Nếu gặp trường lat (và có lng đi cùng hoặc lat đơn lẻ) -> Dựng DynamicGpsCoordinatesWidget
      if (field.code == 'lat') {
        final lngField = hasLng ? sectionFields.firstWhere((f) => f.code == 'lng') : null;
        final latVal = _formData['lat'] is num
            ? _formData['lat'] as num
            : num.tryParse(_formData['lat']?.toString() ?? '');
        final lngVal = _formData['lng'] is num
            ? _formData['lng'] as num
            : num.tryParse(_formData['lng']?.toString() ?? '');
        final errText = _errors['lat'] ?? _errors['lng'];

        widgets.add(
          KeyedSubtree(
            key: _getFieldKey('lat'),
            child: DynamicGpsCoordinatesWidget(
              latField: field,
              lngField: lngField,
              lat: latVal,
              lng: lngVal,
              errorText: errText,
              onCoordinatesChanged: (newLat, newLng) {
                updateFieldValue('lat', newLat);
                if (hasLng) {
                  updateFieldValue('lng', newLng);
                }
              },
            ),
          ),
        );
        continue;
      }

      // Nếu gặp trường lng mà đã có trường lat đi cùng -> Đã được vẽ chung trong GpsCoordinatesWidget
      if (field.code == 'lng' && hasLat) {
        continue;
      }

      // Nếu chỉ có lng đơn lẻ mà không có lat
      if (field.code == 'lng' && !hasLat) {
        final lngVal = _formData['lng'] is num
            ? _formData['lng'] as num
            : num.tryParse(_formData['lng']?.toString() ?? '');
        final errText = _errors['lng'];

        widgets.add(
          KeyedSubtree(
            key: _getFieldKey('lng'),
            child: DynamicGpsCoordinatesWidget(
              lngField: field,
              lat: null,
              lng: lngVal,
              errorText: errText,
              onCoordinatesChanged: (newLat, newLng) {
                updateFieldValue('lng', newLng);
              },
            ),
          ),
        );
        continue;
      }

      // Các trường thông thường khác
      widgets.add(
        KeyedSubtree(
          key: _getFieldKey(field.code),
          child: _buildFieldWidget(field),
        ),
      );
    }

    return widgets;
  }

  /// Kết quả ô công thức của lần dựng hiện tại (tính một lần mỗi `build`).
  Map<String, num?> _formulaValuesCache = const {};

  Widget _buildFieldWidget(DynamicFormField field) {
    final value = _formData[field.code];
    final errorText = _errors[field.code];
    final focusNode = _getFocusNode(field.code);

    final veRieng = widget.customFieldBuilders?[field.code];
    if (veRieng != null) {
      return veRieng(field, value, errorText, (v) => updateFieldValue(field.code, v));
    }

    switch (field.type) {
      case DynamicFormFieldType.text:
        return DynamicTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          focusNode: focusNode,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.longText:
        return DynamicLongTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          focusNode: focusNode,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.number:
        return DynamicNumberFieldWidget(
          field: field,
          value: value is num ? value : num.tryParse(value?.toString() ?? ''),
          errorText: errorText,
          focusNode: focusNode,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.singleChoice:
        return DynamicSingleChoiceFieldWidget(
          field: field,
          value: value,
          errorText: errorText,
          focusNode: focusNode,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.multipleChoice:
        final selectedList = value is List ? List<dynamic>.from(value) : <dynamic>[];
        return DynamicMultipleChoiceFieldWidget(
          field: field,
          selectedValues: selectedList,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.date:
      case DynamicFormFieldType.time:
      case DynamicFormFieldType.datetime:
        return DynamicDateTimeFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.photo:
        final photoList = value is List ? List<String>.from(value.map((e) => e.toString())) : <String>[];
        return DynamicPhotoFieldWidget(
          field: field,
          photoPaths: photoList,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.boolean:
        final boolVal = value == true || value == 1 || value == '1' || value == 'true';
        return DynamicBooleanFieldWidget(
          field: field,
          value: boolVal,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.rating:
        final intVal = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 5);
        return DynamicRatingFieldWidget(
          field: field,
          value: intVal,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.gps:
        final gpsMap = value is Map<String, dynamic> ? value : (value is Map ? Map<String, dynamic>.from(value) : null);
        return DynamicGpsFieldWidget(
          field: field,
          value: gpsMap,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.location:
        if (field.isCoordsField) {
          double? lat;
          double? lng;
          double? accuracy;
          bool? isMock;

          final val = _formData[field.code];
          if (val is Map) {
            lat = (val['lat'] as num?)?.toDouble() ?? double.tryParse(val['lat']?.toString() ?? '');
            lng = (val['lng'] as num?)?.toDouble() ?? double.tryParse(val['lng']?.toString() ?? '');
            accuracy = (val['accuracy'] as num?)?.toDouble() ?? double.tryParse(val['accuracy']?.toString() ?? '');
            isMock = val['mock'] as bool?;
          } else if (_formData['lat'] != null && _formData['lng'] != null) {
            lat = (_formData['lat'] as num?)?.toDouble() ?? double.tryParse(_formData['lat']?.toString() ?? '');
            lng = (_formData['lng'] as num?)?.toDouble() ?? double.tryParse(_formData['lng']?.toString() ?? '');
          }

          final initialAddr = _formData['address']?.toString() ??
              _formData['delivery_address']?.toString();

          final card = AppMapLocationCard(
            title: (field.label.isEmpty || field.label == 'Toạ độ' || field.label == 'coords')
                ? 'Vị trí điểm bán trên bản đồ'
                : field.label,
            lat: lat,
            lng: lng,
            accuracyM: accuracy,
            isReadOnly: field.isReadOnly,
            isRequired: field.isRequired,
            initialAddress: initialAddr?.trim().isNotEmpty == true ? initialAddr!.trim() : null,
            showCoordinates: false, // Ẩn thông số kinh / vĩ độ dạng text (giống form sửa điểm bán)
            showStyleSwitcher: true, // Cho phép chuyển đổi xem Vệ tinh / Đường phố (giống form sửa điểm bán)
            mapHeight: 250, // Chiều cao 250 (giống form sửa điểm bán)
            zoom: 16.5, // Mức phóng 16.5 (giống form sửa điểm bán)
            locateButtonText: 'LẤY VỊ TRÍ HIỆN TẠI',
            updateButtonText: 'CẬP NHẬT LẠI VỊ TRÍ HIỆN TẠI',
            errorText: errorText,
            onLocationChanged: (newLat, newLng, newAddress) {
              updateFieldValue(field.code, {
                'lat': newLat,
                'lng': newLng,
                'accuracy': accuracy ?? 8.0,
                'mock': isMock ?? false,
              });
              _fillAddressFromMap(newAddress);
            },
            onCoordinatesDetailsChanged: (newLat, newLng, newAddress, newAcc, newMock) {
              updateFieldValue(field.code, {
                'lat': newLat,
                'lng': newLng,
                'accuracy': newAcc != null ? double.parse(newAcc.toStringAsFixed(1)) : 8.0,
                'mock': newMock ?? false,
              });
              _fillAddressFromMap(newAddress);
            },
            onCleared: () {
              updateFieldValue(field.code, null);
            },
          );

          // Ô Vị trí lưu CẢ địa chỉ lẫn toạ độ (chủ hệ thống 21/10/2026): schema không có ô Địa chỉ riêng (admin ẩn) thì
          // vẽ ô chữ Địa chỉ ngay dưới bản đồ — tự điền theo vị trí, người dùng sửa được; lưu vào khoá gốc `address`.
          if (widget.fields.any((f) => f.code == 'address')) return card;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              card,
              const SizedBox(height: 12),
              DynamicLongTextFieldWidget(
                field: const DynamicFormField(
                  code: 'address',
                  label: 'Địa chỉ',
                  type: DynamicFormFieldType.longText,
                  max: 500,
                  placeholder: 'Địa chỉ điểm bán — tự điền khi lấy vị trí, có thể sửa',
                ),
                value: _formData['address']?.toString(),
                focusNode: _getFocusNode('address'),
                onChanged: (val) => updateFieldValue('address', val),
              ),
            ],
          );
        }

        Map<String, dynamic>? locMap = value is Map<String, dynamic>
            ? value
            : (value is Map ? Map<String, dynamic>.from(value) : null);
        return LocationFieldWidget(
          label: field.label,
          isRequired: field.isRequired,
          isReadOnly: field.isReadOnly,
          description: field.helperText,
          maxLength: field.max?.toInt() ?? 500,
          errorText: errorText,
          value: locMap,
          showAddressInput: true,
          showBorderContainer: true,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.signature:
        return DynamicTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          focusNode: focusNode,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.erpPartner:
        // Khách hàng pháp nhân: giá trị là MÃ chuỗi (giữ số 0 đầu) — chọn một: một chuỗi, chọn nhiều: mảng chuỗi
        return ErpPartnerFieldWidget(
          fieldCode: field.code,
          label: field.label,
          description: field.helperText,
          isRequired: field.isRequired,
          isReadOnly: field.isReadOnly,
          multiple: field.erpPartnerMultiple,
          selectedCodes: ErpPartnerFieldWidget.codesFromValue(value),
          errorText: errorText,
          onChanged: (codes) => updateFieldValue(
            field.code,
            ErpPartnerFieldWidget.valueFromCodes(codes, multiple: field.erpPartnerMultiple),
          ),
        );

      case DynamicFormFieldType.geoProvince:
      case DynamicFormFieldType.geoWard:
        // Tỉnh/Xã theo danh mục đã lưu máy (chạy offline). Ô xã đọc tỉnh đang chọn ở ô cha (`dependsOn`).
        final laXa = field.type == DynamicFormFieldType.geoWard;
        return GeoSelectFieldWidget(
          field: field,
          wardLevel: laXa,
          provinceId: laXa ? GeoSelectFieldWidget.idOf(_formData[field.dependsOn ?? 'province_id']) : null,
          value: value,
          errorText: errorText,
          onChanged: (id) => _updateGeo(field, id),
        );

      case DynamicFormFieldType.formula:
        // Chỉ đọc: số tự tính lại mỗi lần đổi giá trị ô khác (updateFieldValue ⇒ setState ⇒ build).
        return DynamicFormFieldWrapper(
          field: field,
          child: FormulaValueBox(value: _formulaValuesCache[field.code], config: field.formula),
        );
    }
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'choice_other.dart';
import 'formula_evaluator.dart';
import 'models/dynamic_form_field.dart';
import 'widgets/display_matrix_field_widget.dart';
import 'widgets/dynamic_form_field_wrapper.dart';
import '../widgets/form_fields/form_field_parts.dart';
import 'widgets/formula_field_widget.dart';
import 'widgets/boolean_field_widget.dart';
import 'widgets/datetime_field_widget.dart';
import 'widgets/gps_coordinates_field_widget.dart';
import 'widgets/gps_field_widget.dart';
import 'widgets/heading_field_widget.dart';
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
import '../widgets/note_field_widget.dart';
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

  /// Giá trị ĐANG LƯU của bản ghi (màn sửa). Ô ma trận trùng giá trị này không được gửi đi ⇒ không kiểm: số do phiếu khảo
  /// sát áp vào hiện trạng (#24789) hoặc admin vừa nâng số ảnh tối thiểu không chặn lần sửa ô khác (#24698 vòng 4, C3).
  final Map<String, dynamic> savedData;

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
    this.savedData = const {},
  });

  @override
  State<DynamicFormBuilder> createState() => DynamicFormBuilderState();
}

class DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final Map<String, dynamic> _formData = {};
  final Map<String, String?> _errors = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};
  final Map<String, GlobalKey> _fieldKeys = {};

  /// Ô chọn đang chọn «Khác…» (xem [ChoiceOther]): mã ô → chuỗi đang gõ (đã trim, có thể rỗng). Trạng thái giao diện —
  /// [_formData] chỉ chứa giá trị THẬT (chuỗi gõ tay đặt thẳng làm giá trị).
  final Map<String, String> _otherText = {};

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
      // Ô trình bày (tiêu đề / ghi chú) không thu giá trị ⇒ KHÔNG có khoá trong [_formData]: không lọt vào dữ liệu gửi
      // đi, bản lưu nháp, hàng đợi, so sánh "đã thay đổi" — kể cả khi bản lưu cũ / dữ liệu điểm bán mang trùng mã.
      if (field.isDisplayOnly) continue;

      // Nếu người dùng đã nhập hoặc chỉnh sửa dữ liệu của trường này -> Giữ nguyên 100% không bị mất
      if (preserveExisting && existingData.containsKey(field.code) && existingData[field.code] != null) {
        _formData[field.code] = existingData[field.code];
      } else if (widget.initialData.containsKey(field.code)) {
        _formData[field.code] = widget.initialData[field.code];
        _untouchedDefaults.remove(field.code); // giá trị nạp vào là giá trị thật
      } else if (preserveExisting && existingData.containsKey(field.code)) {
        _formData[field.code] = existingData[field.code];
      } else if (field.initialValue != null) {
        // Giá trị điền sẵn theo cấu hình là giá trị THẬT người dùng thấy và chấp nhận — gửi đi như thường.
        _formData[field.code] = field.initialValue;
      } else {
        _untouchedDefaults.add(field.code);
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
            // Số sao hiện đầy trên form — người dùng thấy và chấp nhận ⇒ giá trị thật, không coi là mặc định chưa đụng.
            _formData[field.code] = (field.min ?? 5).toInt();
            _untouchedDefaults.remove(field.code);
            break;
          default:
            _formData[field.code] = null;
        }
      }
    }

    // Ô cho nhập «Khác…»: giá trị (nháp / bản ghi cũ) ngoài danh sách ⇒ chọn sẵn «Khác…» với chuỗi đó. Dựng lại giữ
    // nguyên trạng thái đang có (kể cả «Khác…» vừa chọn mà chưa gõ).
    if (!preserveExisting) _otherText.clear();
    for (final field in widget.fields) {
      if (!_allowsOther(field) || _otherText.containsKey(field.code)) continue;
      final optVals = field.options.map((o) => o.value);
      final v = _formData[field.code];
      final other = field.type == DynamicFormFieldType.multipleChoice
          ? ChoiceOther.foreignMulti(v, optVals)
          : ChoiceOther.foreignSingle(v, optVals);
      if (other != null) _otherText[field.code] = other;
    }

    // `address` không có ô riêng (admin ẩn) vẫn được ô Vị trí ghi vào — giữ qua mỗi lần dựng lại, không thì mất địa chỉ.
    if (!widget.fields.any((f) => f.code == 'address')) {
      final addr = existingData['address'] ?? widget.initialData['address'];
      if (addr != null) _formData['address'] = addr;
    }
  }

  bool _allowsOther(DynamicFormField field) =>
      field.allowOther &&
      (field.type == DynamicFormFieldType.singleChoice || field.type == DynamicFormFieldType.multipleChoice);

  /// «Khác…» của ô chọn: `''` = vừa chọn (ô chọn một bỏ lựa chọn cũ, chờ gõ), chuỗi = đang gõ (ghi THẲNG làm giá trị;
  /// ô chọn nhiều: thêm sau các lựa chọn đã tích), `null` = bỏ «Khác…» (ô chọn nhiều bỏ chuỗi gõ tay; ô chọn một do
  /// lựa chọn mới ghi đè).
  void _updateOther(DynamicFormField field, String? text) {
    setState(() {
      if (text == null) {
        _otherText.remove(field.code);
      } else {
        _otherText[field.code] = text;
      }
    });
    if (field.type == DynamicFormFieldType.multipleChoice) {
      final current = _formData[field.code];
      updateFieldValue(
        field.code,
        ChoiceOther.composeMulti<dynamic>(
          current is List ? current : const [],
          field.options.map((o) => o.value),
          text,
          optionLabels: field.options.map((o) => o.label),
        ),
      );
    } else if (text != null) {
      updateFieldValue(field.code, text.isEmpty ? null : text);
    }
  }

  /// Điền địa chỉ tra từ vị trí bản đồ vào `address` khi ô đang trống hoặc vẫn là địa chỉ tự điền lần trước (lấy lại vị
  /// trí thì địa chỉ đi theo); người dùng đã gõ / sửa thì giữ nguyên.
  void _fillAddressFromMap(String? newAddress) {
    if (newAddress == null) return;
    final current = _formData['address']?.toString().trim() ?? '';
    // '' = bản đồ lấy toạ độ MỚI lúc mất mạng (không tra được địa chỉ): bỏ địa chỉ TỰ ĐIỀN của toạ độ cũ — địa chỉ người
    // dùng tự gõ thì giữ.
    if (newAddress.trim().isEmpty) {
      if (_autoAddress != null && current == _autoAddress) {
        _autoAddress = null;
        updateFieldValue('address', '');
      }
      return;
    }
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

  /// Mã các ô mang giá trị MẶC ĐỊNH theo loại ô (không có trong dữ liệu nạp vào, không có giá trị điền sẵn) mà người dùng
  /// chưa đụng tới.
  final Set<String> _untouchedDefaults = {};

  /// Ô [code] đang giữ giá trị mặc định THEO LOẠI ô (ô có/không = `false`, chọn nhiều = `[]`, số sao) chứ không phải giá trị
  /// người dùng chọn — màn sửa không gửi nó: bản ghi chưa có ô này mà gửi mặc định là ghi đè "chưa nhập" thành `false`.
  bool isUntouchedDefault(String code) => _untouchedDefaults.contains(code);

  void updateFieldValue(String code, dynamic value) {
    _untouchedDefaults.remove(code);
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
      if (hidden.contains(field.code) || field.type == DynamicFormFieldType.formula || field.isDisplayOnly) continue;
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

      // Ô cho nhập «Khác…»: đã chọn «Khác…» mà chưa gõ (ô bắt buộc) / quá trần ⇒ lỗi; ô chọn nhiều giữ tối đa MỘT
      // chuỗi gõ tay (server từ chối nhiều hơn).
      if (_allowsOther(field)) {
        final other = _otherText[field.code];
        final loi = ChoiceOther.validate(active: other != null, required: field.isRequired, other: other);
        if (loi != null) {
          newErrors[field.code] = loi;
          isValid = false;
          firstInvalidCode ??= field.code;
          continue;
        }
        if (value is List) {
          _formData[field.code] = ChoiceOther.composeMulti<dynamic>(
            value,
            field.options.map((o) => o.value),
            other,
            optionLabels: field.options.map((o) => o.label),
          );
        }
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

      // Ô ma trận trưng bày: luật số + ảnh theo loại (cùng luật server).
      // Ô ma trận trùng giá trị đang lưu ([DynamicFormBuilder.savedData]) không gửi đi ⇒ không kiểm (C3) — trừ ô đếm gõ sai
      // dạng (số bị gỡ khỏi giá trị nên giá trị trông như chưa đổi).
      if (field.type == DynamicFormFieldType.displayMatrix) {
        if (value != null &&
            _matrixInvalid[field.code] != true &&
            DisplayMatrixFieldWidget.sameValue(value, widget.savedData[field.code])) {
          continue;
        }
        final loi = _matrixError(field, value);
        if (loi != null) {
          newErrors[field.code] = loi;
          isValid = false;
          firstInvalidCode ??= field.code;
        }
        continue;
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

  bool _isDynamicSection(String title) {
    final lower = title.toLowerCase().trim();
    return lower.contains('mở rộng') ||
        lower.contains('động') ||
        lower.contains('dynamic') ||
        lower.isEmpty;
  }

  /// Khúc chỉ gồm ô toạ độ (coords / lat / lng) — ô trình bày (dòng mô tả, ghi chú) không tính; phải có ít nhất một ô toạ độ.
  bool _onlyCoords(List<DynamicFormField> fs) {
    final nhap = fs.where((f) => !f.isDisplayOnly);
    return nhap.isNotEmpty && nhap.every((f) => f.isCoordsField || f.code == 'lat' || f.code == 'lng');
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
    // Mục theo cấu hình (danh tính [DynamicFormField.sectionKey], không thì tên mục) KHÔNG còn ô nhập nào được vẽ (kể cả
    // bản đồ) ⇒ bỏ luôn ô trình bày của mục (mô tả, tiêu đề con, ghi chú) — không vẽ khung chỉ có chữ trình bày.
    String mucCua(DynamicFormField f) => f.sectionKey != null ? 'h:${f.sectionKey}' : 's:${f.section ?? 'Thông tin chung'}';
    final dangHien = widget.fields.where((f) => !hidden.contains(f.code)).toList();
    final mucCoNhap = {for (final f in dangHien) if (!f.isDisplayOnly) mucCua(f)};

    // Chia khúc theo thứ tự cấu hình. Khoá khúc = danh tính mục; bản đồ (coords) luôn là khúc riêng.
    final sections = <({String key, String title, List<DynamicFormField> fields})>[];
    for (final field in dangHien) {
      if (field.isDisplayOnly && !mucCoNhap.contains(mucCua(field))) continue;
      final key = field.isCoordsField ? 'coords' : mucCua(field);
      final title = field.isCoordsField ? 'Vị trí trên bản đồ' : (field.section ?? 'Thông tin chung');
      final khoi = widget.keepFieldOrder
          ? (sections.isNotEmpty && sections.last.key == key ? sections.last : null)
          : sections.where((e) => e.key == key).firstOrNull;
      if (khoi != null) {
        khoi.fields.add(field);
      } else {
        sections.add((key: key, title: title, fields: [field]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.indexed.map((cap) {
          final secEntry = cap.$2;
          final sectionTitle = secEntry.title;
          final sectionFields = secEntry.fields;
          // Mục mở bởi tiêu đề của cấu hình: KHÔNG đoán kiểu mục theo chữ trong tên.
          final theoTieuDe = sectionFields.any((f) => f.sectionKey != null && !f.isCoordsField);
          // keepFieldOrder: mục bị bản đồ (hoặc khối khác) chia đôi — phần sau vẫn trong khung nhưng KHÔNG lặp tiêu đề
          // (so theo DANH TÍNH mục, không theo tên).
          final noiTiep = sections.take(cap.$1).any((e) => e.key == secEntry.key);

          // 🔴 Bỏ hẳn card thông tin mở rộng (động): không vẽ Card container và không vẽ Header bar,
          // các field được vẽ trực tiếp ra ngoài layout form
          if (!theoTieuDe && _isDynamicSection(sectionTitle)) {
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
          if ((!theoTieuDe && _isLocationSection(sectionTitle)) || _onlyCoords(sectionFields)) {
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

          // Mục thường: tiêu đề mục kiểu tiêu đề của biểu mẫu khảo sát/thu thập (#24756) rồi các ô — không khung thẻ.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!noiTiep)
                Padding(
                  padding: const EdgeInsets.only(bottom: kFormFieldSpacing),
                  child: HeadingFieldWidget(code: secEntry.key, title: sectionTitle),
                ),
              ..._buildSectionFieldWidgets(sectionFields),
            ],
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

  /// Ô ma trận đang có ô đếm gõ sai dạng — [validate] chặn (không lặng lẽ bỏ số khỏi tổng).
  final Map<String, bool> _matrixInvalid = {};

  /// Ô MA TRẬN TRƯNG BÀY (#24773) ở form điểm bán: thẻ theo thương hiệu + ảnh theo loại (bộ chụp ảnh của form điểm bán,
  /// chỉ máy ảnh). Giá trị `{counts, photos}`; ảnh là đường dẫn máy / token — màn gửi đổi ra token trước khi lưu.
  Widget _buildDisplayMatrix(DynamicFormField field, dynamic value, String? errorText) {
    final cfg = DisplayMatrixConfig.fromConfig({'matrix': field.matrix});
    // Chỉ loại ĐANG hỏi và còn nhận ảnh (max > 0): ảnh của loại đã thôi chụp không có ô để xoá, gửi lại thì server từ chối.
    final hoi = {for (final t in cfg.types) if (t.maxPhotos > 0) t.code};
    final photos = value is Map && value['photos'] is Map
        ? (Map<String, dynamic>.from(value['photos'] as Map)..removeWhere((k, _) => !hoi.contains(k)))
        : <String, dynamic>{};
    void ghi(DisplayMatrixCounts counts, Map<String, dynamic> anh) =>
        updateFieldValue(field.code, counts.isEmpty && anh.isEmpty ? null : {'counts': counts, 'photos': anh});

    return DisplayMatrixFieldWidget(
      fieldCode: field.code,
      label: field.label,
      description: field.description,
      isRequired: field.isRequired,
      config: cfg,
      counts: DisplayMatrixFieldWidget.countsOf(value),
      errorText: errorText,
      onChanged: (counts, invalid) {
        _matrixInvalid[field.code] = invalid;
        ghi(counts, photos);
      },
      photoSection: (t) => DynamicPhotoFieldWidget(
        field: DynamicFormField(
          code: '${field.code}::${t.code}',
          label: 'Ảnh ${t.name}',
          type: DynamicFormFieldType.photo,
          maxPhotos: t.maxPhotos.clamp(1, 10),
          allowGallery: false,
        ),
        photoPaths: (photos[t.code] is List ? photos[t.code] as List : const []).map((e) => e.toString()).toList(),
        onChanged: (list) {
          // Đọc giá trị MỚI NHẤT (ảnh loại khác có thể vừa thêm trong lúc máy ảnh/đóng dấu đang chạy).
          final cur = _formData[field.code];
          final anh = cur is Map && cur['photos'] is Map
              ? (Map<String, dynamic>.from(cur['photos'] as Map)..removeWhere((k, _) => !hoi.contains(k)))
              : <String, dynamic>{};
          if (list.isEmpty) {
            anh.remove(t.code);
          } else {
            anh[t.code] = list;
          }
          ghi(DisplayMatrixFieldWidget.onlyAsked(DisplayMatrixFieldWidget.countsOf(_formData[field.code]), cfg), anh);
        },
      ),
    );
  }

  /// Lỗi của ô ma trận theo luật server (C2 ảnh tối thiểu khi loại có số > 0, số lẻ/trần, ô gõ sai dạng); hợp lệ ⇒ `null`.
  String? _matrixError(DynamicFormField field, dynamic value) {
    if (_matrixInvalid[field.code] == true) return '${field.label} – có ô đếm nhập sai dạng số.';
    final cfg = DisplayMatrixConfig.fromConfig({'matrix': field.matrix});
    // Chỉ thương hiệu/loại ĐANG hỏi — số của thương hiệu đã tắt không hiện để sửa, không gửi đi (C3).
    final counts = DisplayMatrixFieldWidget.onlyAsked(DisplayMatrixFieldWidget.countsOf(value), cfg);
    final cellErr = DisplayMatrixFieldWidget.countsError(counts, cfg);
    if (cellErr != null) return '${field.label} – $cellErr';
    final photos = value is Map && value['photos'] is Map ? value['photos'] as Map : const {};
    for (final t in cfg.types) {
      final n = photos[t.code] is List ? (photos[t.code] as List).length : 0;
      if (t.maxPhotos > 0 && n > t.maxPhotos) return '${field.label} – ${t.name}: tối đa ${t.maxPhotos} ảnh.';
      if (t.effectiveMinPhotos > 0 && DisplayMatrixTotals.sumOfType(counts, t.code) > 0 && n < t.effectiveMinPhotos) {
        return '${field.label} – ${t.name}: cần ít nhất ${t.effectiveMinPhotos} ảnh.';
      }
    }
    return null;
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
          otherText: _otherText[field.code],
          onOtherChanged: _allowsOther(field) ? (t) => _updateOther(field, t) : null,
        );

      case DynamicFormFieldType.multipleChoice:
        final selectedList = value is List ? List<dynamic>.from(value) : <dynamic>[];
        return DynamicMultipleChoiceFieldWidget(
          field: field,
          selectedValues: selectedList,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
          otherText: _otherText[field.code],
          onOtherChanged: _allowsOther(field) ? (t) => _updateOther(field, t) : null,
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

      case DynamicFormFieldType.displayMatrix:
        return _buildDisplayMatrix(field, value, errorText);

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

      case DynamicFormFieldType.heading:
        final moTa = field.helperText?.trim() ?? '';
        // Dòng mô tả của tiêu đề cấp 1 đã thành tiêu đề khung mục / tiêu đề cấp 1 nhãn rỗng: chỉ vẽ dòng mô tả.
        if (field.isSectionDescription || (field.level != 2 && field.label.trim().isEmpty)) {
          return moTa.isEmpty
              ? const SizedBox.shrink()
              : Padding(padding: const EdgeInsets.only(bottom: kFormFieldSpacing), child: HeadingFieldWidget.descriptionText(context, moTa));
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: kFormFieldSpacing),
          child: HeadingFieldWidget(code: field.code, title: field.label, description: field.helperText, level: field.level),
        );

      case DynamicFormFieldType.note:
        return Padding(
          padding: const EdgeInsets.only(bottom: kFormFieldSpacing),
          child: NoteFieldWidget(title: field.label, description: field.helperText),
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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/form_photo_model.dart';
import '../../../data/models/market_form_submission_model.dart';
import '../../../domain/entities/market_form_entity.dart';
import '../../../domain/services/dynamic_rule_evaluator.dart';
import 'currency_field_widget.dart';
import '../../../../../core/dynamic_form/widgets/display_matrix_field_widget.dart';
import '../../../../../core/dynamic_form/matrix_photo_key.dart';
import '../../../../../core/widgets/note_field_widget.dart';
import '../../../../../core/widgets/form_fields/form_field_parts.dart';
import '../../../../../core/dynamic_form/widgets/heading_field_widget.dart';
import 'ref_customer_field_widget.dart';
import 'route_field_widget.dart';
import '../../../../../core/widgets/location_field_widget.dart';
import '../../../../../core/widgets/erp_partner_field_widget.dart';
import '../../../../../core/widgets/geo_select_field_widget.dart';
import '../../../../../core/dynamic_form/choice_other.dart';
import '../../../../../core/dynamic_form/formula_evaluator.dart';
import '../../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../../../../../core/dynamic_form/widgets/choice_other_input.dart';
import '../../../../../core/dynamic_form/widgets/formula_field_widget.dart';
import '../../../../../core/widgets/voice_input_mic_button.dart';
import '../../../../../core/utils/photo_watermark_helper.dart';
import '../../../../../core/widgets/camera_permission_dialog.dart';

/// Mục ảnh quản lý trạng thái tải lên và hiển thị cục bộ
class FormPhotoEntry {
  String localPath;
  String? token;
  String? previewUrl;
  bool isUploading;
  String? uploadError;

  FormPhotoEntry({
    required this.localPath,
    this.token,
    this.previewUrl,
    this.isUploading = false,
    this.uploadError,
  });

  String get fullPreviewUrl {
    if (previewUrl == null || previewUrl!.isEmpty) return '';
    if (previewUrl!.startsWith('http://') || previewUrl!.startsWith('https://')) {
      return previewUrl!;
    }
    final clean = previewUrl!.startsWith('/') ? previewUrl! : '/$previewUrl';
    return '${AppConstants.baseUrl}$clean';
  }
}

class MarketFormRenderer extends StatefulWidget {
  final List<MarketFormBlockEntity> blocks;
  final Map<String, dynamic> initialAnswers;
  final Map<String, dynamic> customerContext;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  final int? defaultCustomerId;
  final String? defaultCustomerName;
  final String? defaultCustomerCode;
  final String? defaultCustomerAddress;
  final bool lockCustomer;

  /// Tuyến ưu tiên để TỰ ĐIỀN ô `ref_dms_route` (tuyến của lượt viếng thăm, rồi tuyến của điểm bán) — chỉ điền id có
  /// trong danh sách tuyến của NV.
  final List<int> defaultRouteIds;

  /// `data` của hồ sơ điểm bán đang viếng thăm (ô động) — ô ma trận bật "Cập nhật hiện trạng điểm bán"
  /// (`config.update_customer_field`) lấy số hiện trạng làm gợi ý mờ (#24789).
  final Map<String, dynamic> customerData;
  final int defaultMaxPhotos;
  final Future<FormPhotoModel> Function(File file)? onUploadPhoto;

  const MarketFormRenderer({
    super.key,
    required this.blocks,
    this.initialAnswers = const {},
    this.customerContext = const {},
    this.onChanged,
    this.defaultCustomerId,
    this.defaultCustomerName,
    this.defaultCustomerCode,
    this.defaultCustomerAddress,
    this.lockCustomer = false,
    this.defaultRouteIds = const [],
    this.customerData = const {},
    this.defaultMaxPhotos = 10,
    this.onUploadPhoto,
  });

  @override
  State<MarketFormRenderer> createState() => MarketFormRendererState();
}

class MarketFormRendererState extends State<MarketFormRenderer> {
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _errors = {};
  final Map<String, TextEditingController> _textControllers = {};

  /// Khoá + FocusNode theo mã ô — nộp còn lỗi thì cuộn tới ô lỗi ĐẦU TIÊN, ô gõ chữ/số thì focus luôn.
  final Map<String, GlobalKey> _blockKeys = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, List<FormPhotoEntry>> _photoEntries = {};
  Map<String, bool> _visibilityMap = {};

  /// Ô chọn đang chọn «Khác…» (xem [ChoiceOther]): mã ô → chuỗi đang gõ (đã trim, có thể rỗng). Trạng thái giao diện —
  /// câu trả lời chỉ chứa chuỗi gõ tay thật.
  final Map<String, String> _otherText = {};

  /// Kết quả các ô CÔNG THỨC (chưa định dạng, đã làm tròn theo `decimals`), tính trên TOÀN BỘ câu trả lời (kể cả ô ẩn)
  /// như server — không nằm trong [_answers] nên không gửi lên (server tự tính lại và lưu).
  Map<String, num?> _formulaValues = {};

  TextEditingController _getController(String code, String initial) {
    if (!_textControllers.containsKey(code)) {
      _textControllers[code] = TextEditingController(text: initial);
    }
    return _textControllers[code]!;
  }

  /// Trả về bản đồ đường dẫn ảnh cục bộ trên máy phục vụ lưu trữ offline (§5)
  Map<String, List<String>> getLocalPhotoPaths() {
    final Map<String, List<String>> map = {};
    _photoEntries.forEach((code, entries) {
      // Ảnh khôi phục từ bản nháp chỉ có token (không còn tệp trên máy) ⇒ đưa TOKEN vào danh sách, đúng vị trí: hàng đợi
      // giữ nguyên token đó và thay cả danh sách — bỏ đi thì lượt tải lại làm rơi ảnh.
      final paths = entries
          .map((e) => e.localPath.isNotEmpty ? e.localPath : (e.token ?? ''))
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isNotEmpty) {
        map[code] = paths;
      }
    });
    return map;
  }

  /// Ô ma trận đang có ô đếm gõ sai dạng (vd `2,5,`) — bước Lưu chặn, không lặng lẽ bỏ số khỏi tổng.
  final Map<String, bool> _matrixInvalid = {};

  /// Số hiện trạng điểm bán cho ô ma trận có ô đích `config.update_customer_field` (#24789); không có ⇒ rỗng.
  DisplayMatrixCounts _hintCountsOf(dynamic config) {
    final target = config is Map ? config['update_customer_field'] : null;
    return target is String && target.isNotEmpty ? DisplayMatrixFieldWidget.countsOf(widget.customerData[target]) : const {};
  }

  /// Danh mục ô ma trận đã đọc từ `config` — bất biến suốt màn điền, đọc một lần mỗi ô.
  final Map<String, DisplayMatrixConfig> _matrixCfg = {};

  DisplayMatrixConfig _matrixOf(MarketFormBlockEntity block) =>
      _matrixCfg.putIfAbsent(block.resolved.code, () => DisplayMatrixConfig.fromConfig(block.resolved.configMap));

  bool _isMatrixBlock(MarketFormBlockEntity block) => block.resolved.inputType.toLowerCase() == 'display_matrix';

  int _resolveMaxFiles(MarketFormBlockEntity block) {
    if (block.resolved.maxFiles > 0) {
      return block.resolved.maxFiles.clamp(1, 10);
    }
    return widget.defaultMaxPhotos.clamp(1, 10);
  }

  /// Số ảnh tối thiểu hiệu lực — chỉ ô `image` (như server ImageFieldLimits), không vượt tối đa.
  int _resolveMinFiles(MarketFormBlockEntity block) =>
      block.resolved.isImage ? block.resolved.minFiles.clamp(0, _resolveMaxFiles(block)) : 0;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  bool _isCustomerBlock(MarketFormBlockEntity block) {
    final type = block.resolved.inputType.toLowerCase();
    if (type == 'ref_customer') return true;
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_id' ||
        code == 'khach_hang_id' ||
        code == 'diem_ban_khao_sat';
  }

  bool _isCustomerNameBlock(MarketFormBlockEntity block) {
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_name' ||
        code == 'ten_khach_hang' ||
        code == 'ten_diem_ban';
  }

  bool _isCustomerCodeBlock(MarketFormBlockEntity block) {
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_code' ||
        code == 'ma_khach_hang' ||
        code == 'ma_diem_ban';
  }

  @override
  void initState() {
    super.initState();
    _answers.addAll(widget.initialAnswers);

    // Khởi tạo danh sách ảnh cho các ô ảnh / tệp từ initialAnswers
    for (final block in widget.blocks) {
      if (block.isImage || block.resolved.inputType.toLowerCase() == 'file') {
        final code = block.resolved.code;
        final rawVal = _answers[code];
        final List<FormPhotoEntry> entries = [];
        if (rawVal is List) {
          for (final item in rawVal) {
            final str = item.toString().trim();
            if (str.isEmpty) continue;
            if (str.length == 32 && !str.contains('/') && !str.contains(r'\')) {
              // Token hex 32 ký tự
              entries.add(FormPhotoEntry(
                localPath: '',
                token: str,
                previewUrl: '/dms/form-photos/public/$str',
              ));
            } else {
              // File cục bộ
              entries.add(FormPhotoEntry(localPath: str));
            }
          }
        } else if (rawVal is String && rawVal.trim().isNotEmpty) {
          final str = rawVal.trim();
          if (str.length == 32 && !str.contains('/') && !str.contains(r'\')) {
            entries.add(FormPhotoEntry(
              localPath: '',
              token: str,
              previewUrl: '/dms/form-photos/public/$str',
            ));
          } else {
            entries.add(FormPhotoEntry(localPath: str));
          }
        }
        if (entries.isNotEmpty) {
          _photoEntries[code] = entries;
        }
      }
    }

    // Ô ma trận trưng bày: ảnh theo loại ở `photos.<mã loại>` (token hoặc đường dẫn máy của bản nháp ngoại tuyến).
    for (final block in widget.blocks) {
      if (!_isMatrixBlock(block)) continue;
      final raw = _answers[block.resolved.code];
      final photos = raw is Map ? raw['photos'] : null;
      if (photos is! Map) continue;
      final nhanAnh = {for (final t in _matrixOf(block).types) if (t.maxPhotos > 0) t.code};
      photos.forEach((type, list) {
        // Loại đã thôi nhận ảnh / không còn trong ô: ảnh cũ của bản nháp không nạp — gửi đi là server từ chối.
        if (list is! List || !nhanAnh.contains('$type')) return;
        final entries = <FormPhotoEntry>[
          for (final item in list)
            if ('$item'.trim().isNotEmpty)
              isUploadedPhotoToken('$item')
                  ? FormPhotoEntry(localPath: '', token: '$item', previewUrl: '/dms/form-photos/public/$item')
                  : FormPhotoEntry(localPath: '$item'),
        ];
        if (entries.isNotEmpty) _photoEntries[matrixPhotoKey(block.resolved.code, '$type')] = entries;
      });
    }

    // Tự động gán defaultCustomerId cho các ô ref_customer hoặc ô khách hàng
    if (widget.defaultCustomerId != null) {
      for (final block in widget.blocks) {
        if (_isCustomerBlock(block)) {
          final code = block.resolved.code;
          if (widget.lockCustomer || !_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerId;
          }
        }
      }
    }

    if (widget.lockCustomer) {
      for (final block in widget.blocks) {
        if (_isCustomerNameBlock(block) && widget.defaultCustomerName != null) {
          final code = block.resolved.code;
          if (!_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerName;
          }
        } else if (_isCustomerCodeBlock(block) && widget.defaultCustomerCode != null) {
          final code = block.resolved.code;
          if (!_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerCode;
          }
        }
      }
    }

    // #23819: ô Kênh/Tuyến bật "tự điền theo phòng ban" — server gửi `config.default` tính cho chính người đăng nhập.
    // Chỉ điền ô CÒN TRỐNG (câu trả lời nháp đã có thì giữ); lựa chọn của app là CHUỖI nên đổi giá trị về chuỗi để ô chọn
    // khớp được (ô chọn nhiều: server gửi mảng).
    for (final block in widget.blocks) {
      final cfg = block.resolved.config;
      final code = block.resolved.code;
      if (code.isEmpty || cfg is! Map || cfg['default'] == null) continue;
      final current = _answers[code];
      final trong = current == null || (current is String && current.trim().isEmpty) || (current is List && current.isEmpty);
      if (!trong) continue;
      final d = cfg['default'];
      _answers[code] = d is List ? d.map((e) => e.toString()).toList() : d.toString();
    }

    // Ô Tuyến bán hàng: giá trị là SỐ NGUYÊN id tuyến (nháp / mặc định có thể là chuỗi số).
    for (final block in widget.blocks) {
      if (block.resolved.inputType.toLowerCase() != 'ref_dms_route') continue;
      final code = block.resolved.code;
      final id = RouteFieldWidget.idOf(_answers[code]);
      if (id == null) {
        _answers.remove(code);
      } else {
        _answers[code] = id;
      }
    }

    // Ô cho nhập «Khác…»: câu trả lời (nháp / bản ghi cũ) có giá trị ngoài danh sách ⇒ chọn sẵn «Khác…».
    for (final block in widget.blocks) {
      final other = _allowsOther(block) ? _foreignOf(block) : null;
      if (other != null) _otherText[block.resolved.code] = other;
    }

    _recomputeVisibility();
  }

  bool _isMultiChoice(MarketFormBlockEntity block) =>
      const {'checkbox', 'multiselect'}.contains(block.resolved.inputType.toLowerCase());

  /// Ô chọn (select / radio / multiselect / checkbox) có bật «Cho phép nhập giá trị khác».
  bool _allowsOther(MarketFormBlockEntity block) =>
      block.resolved.allowOther &&
      const {'select', 'radio', 'checkbox', 'multiselect'}.contains(block.resolved.inputType.toLowerCase());

  Iterable<String> _optionValues(MarketFormBlockEntity block) => block.resolved.options.map((o) => o.value);
  Iterable<String> _optionLabels(MarketFormBlockEntity block) => block.resolved.options.map((o) => o.label);

  /// Giá trị ngoài danh sách đang nằm trong câu trả lời của ô; `null` nếu không có.
  String? _foreignOf(MarketFormBlockEntity block) {
    final val = _answers[block.resolved.code];
    return _isMultiChoice(block)
        ? ChoiceOther.foreignMulti(val, _optionValues(block))
        : ChoiceOther.foreignSingle(val, _optionValues(block));
  }

  /// Bật / tắt «Khác…». Bật: ô chọn một bỏ lựa chọn cũ (chờ gõ); tắt: ô chọn nhiều bỏ chuỗi gõ tay.
  void _setOtherActive(MarketFormBlockEntity block, bool active) {
    final code = block.resolved.code;
    setState(() {
      if (active) {
        _otherText[code] = '';
        if (!_isMultiChoice(block)) _answers.remove(code);
      } else {
        _otherText.remove(code);
        if (_isMultiChoice(block)) {
          final list = (_answers[code] as List?)?.map((e) => e.toString()) ?? const <String>[];
          _answers[code] = ChoiceOther.composeMulti(list, _optionValues(block), null);
        }
      }
      _errors.remove(code);
      _recomputeVisibility();
    });
    widget.onChanged?.call(_answers);
  }

  /// Người dùng gõ giá trị «Khác» (đã trim) — ghi THẲNG làm giá trị ô (chọn nhiều: thêm vào sau các lựa chọn đã tích).
  void _updateOtherText(MarketFormBlockEntity block, String text) {
    final code = block.resolved.code;
    _otherText[code] = text;
    if (_isMultiChoice(block)) {
      final list = (_answers[code] as List?)?.map((e) => e.toString()) ?? const <String>[];
      _updateTypedValue(
        code,
        ChoiceOther.composeMulti(list, _optionValues(block), text, optionLabels: _optionLabels(block)),
      );
    } else {
      _updateTypedValue(code, text.isEmpty ? null : text);
    }
  }

  /// Ô gõ «Khác» hiện dưới ô chọn đang chọn «Khác…».
  Widget _buildOtherInput(MarketFormBlockEntity block, bool isDark) => ChoiceOtherInput(
        key: ValueKey('choice_other_${block.resolved.code}'),
        initialText: _otherText[block.resolved.code],
        onChanged: (t) => _updateOtherText(block, t),
      );

  @override
  void didUpdateWidget(covariant MarketFormRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks ||
        oldWidget.customerContext != widget.customerContext) {
      _recomputeVisibility();
    }
  }

  /// Tính toán lại trạng thái ẩn/hiện của tất cả các block theo quy tắc §3 & §7
  /// Ô công thức tính TRƯỚC trên toàn bộ câu trả lời; `show_if` đọc số đã tính (ô ẩn vẫn coi là rỗng khi so điều kiện).
  void _recomputeVisibility() {
    _formulaValues = FormulaEvaluator.computeAll({
      for (final b in widget.blocks)
        if (b.resolved.formula != null && b.resolved.code.isNotEmpty) b.resolved.code: b.resolved.formula!,
    }, _answers);
    _visibilityMap = DynamicRuleEvaluator.computeVisibility(
      blocks: widget.blocks,
      answers: _formulaValues.isEmpty ? _answers : {..._answers, ..._formulaValues},
      customerContext: widget.customerContext,
    );
  }

  /// Trả về bản sao các câu trả lời hiện tại
  Map<String, dynamic> get currentAnswers => Map<String, dynamic>.from(_answers);

  /// Danh sách các mục ảnh theo mã trường
  Map<String, List<FormPhotoEntry>> get photoEntries => _photoEntries;

  /// Danh sách các mã code thuộc nhóm trình bày (không thu dữ liệu)
  Set<String> get _presentationCodes {
    return widget.blocks
        .where((b) => b.isPresentation)
        .map((b) => b.resolved.code)
        .toSet();
  }

  /// Kiểm tra điều kiện show_if của một block (dựa trên visibility map đã duyệt theo thứ tự)
  bool _isBlockVisible(MarketFormBlockEntity block) {
    final code = block.resolved.code;
    final ref = block.ref;
    return _visibilityMap[code] ?? _visibilityMap[ref] ?? true;
  }

  /// Validate toàn bộ form và trả về câu trả lời đã làm sạch (hoặc null nếu có lỗi)
  Map<String, dynamic>? validateAndGetAnswers() {
    if (widget.lockCustomer && widget.defaultCustomerId != null) {
      for (final block in widget.blocks) {
        if (_isCustomerBlock(block)) {
          _answers[block.resolved.code] = widget.defaultCustomerId;
        }
      }
    }

    _recomputeVisibility();
    final Map<String, String> newErrors = {};

    for (final block in widget.blocks) {
      if (block.isPresentation) continue;
      // Ô đang ẩn được MIỄN kiểm tra bắt buộc (§5)
      if (!_isBlockVisible(block)) continue;
      // Ô công thức: chỉ đọc, không bắt buộc, không gửi (server tự tính)
      if (_isFormulaBlock(block)) continue;

      final code = block.resolved.code;
      final label = block.resolved.label.isNotEmpty ? block.resolved.label : code;

      // Ô ma trận trưng bày (#24767): cùng luật server — ô trống = 0 (C1); ảnh tối thiểu chỉ bắt khi loại có số > 0 (C2).
      if (_isMatrixBlock(block)) {
        final err = _syncMatrixAnswer(block, validate: true);
        if (err != null) newErrors[code] = err;
        continue;
      }

      // Xử lý riêng cho ô ảnh (§1, §2, §3)
      if (block.isImage || block.resolved.inputType.toLowerCase() == 'file') {
        final entries = _photoEntries[code] ?? [];
        if (block.required && entries.isEmpty) {
          newErrors[code] = '$label không được để trống.';
          continue;
        }
        final maxAllowed = _resolveMaxFiles(block);
        if (entries.length > maxAllowed) {
          newErrors[code] = '$label chỉ cho phép tối đa $maxAllowed ảnh.';
          continue;
        }
        final minAllowed = _resolveMinFiles(block);
        if (entries.isNotEmpty && entries.length < minAllowed) {
          newErrors[code] = '$label cần ít nhất $minAllowed ảnh.';
          continue;
        }
        if (entries.isNotEmpty) {
          // LUÔN gửi mảng các token (hoặc local path nếu offline chưa có token) (§3)
          _answers[code] = entries
              .map((e) => (e.token != null && e.token!.isNotEmpty) ? e.token! : e.localPath)
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          _answers.remove(code);
        }
        continue;
      }

      var val = _answers[code];

      // Xử lý riêng cho ô vị trí (§2, §3, §4)
      if (block.isLocation) {
        if (val == null || DynamicRuleEvaluator.isEmptyValue(val)) {
          if (block.required) {
            newErrors[code] = '$label không được để trống.';
          }
          continue;
        }

        if (val is! Map) {
          newErrors[code] = '$label có giá trị không hợp lệ.';
          continue;
        }

        final latVal = val['lat'];
        final lngVal = val['lng'];
        final addrVal = val['address']?.toString();

        final inputType = block.resolved.inputType.toLowerCase();
        final isPureAddressField = inputType == 'address' ||
            inputType == 'dia_chi' ||
            code == 'address' ||
            code == 'dia_chi' ||
            code == 'dia_chi_giao_dich' ||
            label.toLowerCase().contains('địa chỉ');

        // Chỉ có address hoặc chỉ một nửa toạ độ
        if (latVal == null || lngVal == null) {
          if (isPureAddressField) {
            // Đối với field địa chỉ trong form động: luôn cho phép nhập/sửa địa chỉ mà không bắt buộc toạ độ GPS
            if (addrVal != null && addrVal.trim().isNotEmpty) {
              final maxLen = block.resolved.validation?.maxLength ?? 500;
              if (addrVal.trim().length > maxLen) {
                newErrors[code] = '$label không được vượt quá $maxLen ký tự.';
              }
              continue;
            } else if (block.required) {
              newErrors[code] = '$label không được để trống.';
              continue;
            }
          } else {
            // Đối với trường vị trí / toạ độ kho / GPS
            if (addrVal != null && addrVal.trim().isNotEmpty) {
              newErrors[code] = '$label cần có toạ độ GPS — bấm "Lấy vị trí".';
            } else if (block.required) {
              newErrors[code] = '$label không được để trống.';
            }
            continue;
          }
        }

        final numLat = latVal is num ? latVal : double.tryParse(latVal.toString());
        final numLng = lngVal is num ? lngVal : double.tryParse(lngVal.toString());
        final accuracyVal = val['accuracy'];
        final numAcc = accuracyVal is num
            ? accuracyVal
            : (accuracyVal != null ? double.tryParse(accuracyVal.toString()) : null);

        if (numLat == null ||
            numLng == null ||
            numLat < -90 ||
            numLat > 90 ||
            numLng < -180 ||
            numLng > 180 ||
            (numAcc != null && numAcc < 0)) {
          newErrors[code] = '$label có giá trị không hợp lệ.';
          continue;
        }

        final maxLen = block.resolved.validation?.maxLength ?? 500;
        if (addrVal != null && addrVal.trim().length > maxLen) {
          newErrors[code] = '$label không được vượt quá $maxLen ký tự.';
          continue;
        }

        continue;
      }

      // Ô cho nhập «Khác…»: đã chọn «Khác…» mà chưa gõ (ô bắt buộc) / quá trần ⇒ lỗi; ô chọn nhiều giữ tối đa MỘT chuỗi
      // gõ tay (server từ chối nhiều hơn).
      if (_allowsOther(block)) {
        final active = _otherText.containsKey(code);
        final other = _otherText[code];
        final loi = ChoiceOther.validate(active: active, required: block.required, other: other);
        if (loi != null) {
          newErrors[code] = loi;
          continue;
        }
        if (val is List) {
          val = _answers[code] = ChoiceOther.composeMulti(
            val.map((e) => e.toString()),
            _optionValues(block),
            active ? other : null,
            optionLabels: _optionLabels(block),
          );
        }
      }

      // 1. Kiểm tra bắt buộc (required) - 0, "0", false không phải rỗng (§2 Luật 1)
      final isEmpty = DynamicRuleEvaluator.isEmptyValue(val);

      if (block.required && isEmpty) {
        newErrors[code] = '$label không được để trống.';
        continue;
      }

      // 2. Kiểm tra validation nếu có giá trị
      if (!isEmpty && block.resolved.validation != null) {
        final v = block.resolved.validation!;
        if (val is num) {
          if (v.min != null && val < v.min!) {
            newErrors[code] = '$label tối thiểu là ${v.min}.';
          } else if (v.max != null && val > v.max!) {
            newErrors[code] = '$label tối đa là ${v.max}.';
          }
        } else if (val is String) {
          if (v.minLength != null && val.trim().length < v.minLength!) {
            newErrors[code] = '$label phải có ít nhất ${v.minLength} ký tự.';
          } else if (v.maxLength != null && val.trim().length > v.maxLength!) {
            newErrors[code] = '$label không được vượt quá ${v.maxLength} ký tự.';
          }
        }
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });

    if (newErrors.isNotEmpty) {
      _focusBlock(newErrors.keys.first);
      return null;
    }

    // Lấy danh sách các mã trường đang hiển thị để loại bỏ ô ẩn khi nộp (§5, §9) — ô công thức không gửi
    final visibleCodes = widget.blocks
        .where((b) => !b.isPresentation && !_isFormulaBlock(b) && _isBlockVisible(b))
        .map((b) => b.resolved.code)
        .toSet();

    final imageCodes = widget.blocks
        .where((b) => b.isImage || b.resolved.inputType.toLowerCase() == 'file')
        .map((b) => b.resolved.code)
        .toSet();

    // Làm sạch: Bỏ các trường rỗng, ô trình bày, và ô đang ẩn (§5, §9)
    return MarketFormSubmissionModel.sanitizeAnswers(
      _answers,
      presentationCodes: _presentationCodes,
      allowedCodes: visibleCodes,
      imageCodes: imageCodes,
    );
  }

  /// Ô gõ chữ / số: nội dung do chính ô giữ (controller theo mã ô / initialValue) ⇒ KHÔNG dựng lại cả biểu mẫu ở mỗi
  /// phím (biểu mẫu là một Column dựng hết mọi ô); chỉ dựng lại khi ẩn/hiện các ô khác thay đổi hoặc cần xoá lỗi đang hiện.
  void _updateTypedValue(String code, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      _answers.remove(code);
    } else {
      _answers[code] = value;
    }
    final hadError = _errors.remove(code) != null;
    final visibilityBefore = _visibilityMap;
    final formulasBefore = _formulaValues;
    _recomputeVisibility();
    if (hadError || !mapEquals(visibilityBefore, _visibilityMap) || !mapEquals(formulasBefore, _formulaValues)) {
      setState(() {});
    }
    widget.onChanged?.call(_answers);
  }

  void _updateValue(String code, dynamic value) {
    setState(() {
      if (value == null || (value is String && value.isEmpty)) {
        _answers.remove(code);
      } else {
        _answers[code] = value;
      }
      _errors.remove(code);
      _recomputeVisibility();
    });
    widget.onChanged?.call(_answers);
  }

  FocusNode _focusNodeOf(String code) => _focusNodes.putIfAbsent(code, FocusNode.new);

  /// Cuộn tới ô [code]; ô gõ chữ/số thì focus luôn (bật bàn phím). Ô khác KHÔNG cất bàn phím: ô đang gõ (vd ô số ma
  /// trận) ghi giá trị khi mất focus ⇒ xoá luôn lỗi vừa báo.
  void _focusBlock(String code) {
    final node = _focusNodes[code];
    if (node != null && node.context != null && node.canRequestFocus) {
      node.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _blockKeys[code]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleBlocks = widget.blocks.where(_isBlockVisible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleBlocks.map((block) {
        return Padding(
          // Khoá theo mã ô: ô ẩn/hiện theo điều kiện làm các ô dồn chỗ — không khoá thì trạng thái (mở/thu ô hướng dẫn,
          // đã tự điền tuyến…) nhảy sang ô khác hoặc dựng lại từ đầu.
          key: ValueKey('block_${block.resolved.code}'),
          padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
          child: KeyedSubtree(
            key: _blockKeys.putIfAbsent(block.resolved.code, GlobalKey.new),
            child: _buildBlock(context, block, isDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final type = block.resolved.inputType.toLowerCase();
    final code = block.resolved.code.toLowerCase();

    if (type == 'formula') return _buildFormulaField(block, isDark);

    // Tự động nhận diện trường Địa chỉ / Vị trí / GPS từ schema API (Bỏ fix cứng)
    if (type == 'location' ||
        type == 'address' ||
        type == 'dia_chi' ||
        type == 'gps' ||
        code == 'address' ||
        code == 'dia_chi' ||
        code == 'dia_chi_giao_dich' ||
        code == 'location') {
      return _buildLocationField(block, isDark);
    }

    switch (type) {
      case 'heading':
        return HeadingFieldWidget(
          code: block.resolved.code,
          title: block.resolved.label,
          description: block.resolved.description,
          level: DynamicFormField.headingLevelOf({'config': block.resolved.configMap}),
        );
      case 'divider':
        return const Divider(height: 24, thickness: 1);
      case 'note':
        return _buildNote(block, isDark);
      case 'text':
        return _buildTextField(block, isDark, isMultiline: false);
      case 'textarea':
        return _buildTextField(block, isDark, isMultiline: true);
      case 'number':
        return _buildNumberField(block, isDark);
      case 'currency':
        return CurrencyFieldWidget(
          block: block,
          initialValue: _answers[block.resolved.code] as num?,
          errorText: _errors[block.resolved.code],
          onChanged: (val) => _updateValue(block.resolved.code, val),
        );
      case 'boolean':
        return _buildBooleanField(block, isDark);
      case 'checkbox':
        return _buildCheckboxField(block, isDark);
      case 'radio':
        return _buildRadioField(block, isDark);
      case 'select':
        return _buildSelectField(block, isDark);
      case 'multiselect':
        return _buildMultiSelectField(block, isDark);
      case 'date':
        return _buildDateField(context, block, isDark);
      case 'image':
      case 'file':
        return _buildImageField(context, block, isDark);
      case 'display_matrix':
        return _buildDisplayMatrixField(context, block, isDark);
      case 'location':
      case 'address':
      case 'dia_chi':
      case 'gps':
        return _buildLocationField(block, isDark);
      case 'ref_customer':
        final currentVal = _answers[block.resolved.code];
        final int? selectedId = (widget.lockCustomer && widget.defaultCustomerId != null)
            ? widget.defaultCustomerId
            : (currentVal is int
                ? currentVal
                : (currentVal != null ? int.tryParse(currentVal.toString()) : null));
        return RefCustomerFieldWidget(
          block: block,
          selectedId: selectedId ?? (widget.lockCustomer ? widget.defaultCustomerId : null),
          errorText: _errors[block.resolved.code],
          defaultCustomerName: widget.defaultCustomerName,
          defaultCustomerCode: widget.defaultCustomerCode,
          defaultCustomerAddress: widget.defaultCustomerAddress,
          isReadOnly: widget.lockCustomer,
          onChanged: widget.lockCustomer
              ? (_) {}
              : (val) => _updateValue(block.resolved.code, val),
        );
      case 'ref_erp_partner':
        // Khách hàng pháp nhân (khách ERP Bravo): tìm trên server; giá trị là MÃ chuỗi (giữ số 0 đầu) —
        // ô chọn một lưu một chuỗi, ô chọn nhiều (`config.multiple`) lưu mảng chuỗi.
        final cfg = block.resolved.config;
        final multiple = cfg is Map && cfg['multiple'] == true;
        return ErpPartnerFieldWidget(
          fieldCode: block.resolved.code,
          label: block.resolved.label.isNotEmpty ? block.resolved.label : block.resolved.code,
          description: block.resolved.description,
          isRequired: block.required,
          multiple: multiple,
          selectedCodes: ErpPartnerFieldWidget.codesFromValue(_answers[block.resolved.code]),
          errorText: _errors[block.resolved.code],
          onChanged: (codes) => _updateValue(
            block.resolved.code,
            ErpPartnerFieldWidget.valueFromCodes(codes, multiple: multiple),
          ),
        );
      case 'ref_province':
      case 'ref_ward':
        return _buildGeoField(block);
      case 'ref_dms_route':
        return RouteFieldWidget(
          label: _buildLabel(block, isDark),
          selectedId: RouteFieldWidget.idOf(_answers[block.resolved.code]),
          preferredIds: widget.defaultRouteIds,
          decoration: _inputDecoration(
            hintText: 'Chọn tuyến bán hàng...',
            isDark: isDark,
            errorText: _errors[block.resolved.code],
          ),
          onChanged: (id) => _updateValue(block.resolved.code, id),
        );
      default:
        return _buildTextField(block, isDark, isMultiline: false);
    }
  }

  // ==========================================
  // Ô TỈNH/THÀNH → XÃ/PHƯỜNG (#24072)
  // ==========================================

  /// Ô Tỉnh/Xã theo danh mục đã lưu máy (chạy offline). Ô xã lọc theo ô tỉnh ở `config.depends_on` (server tự nối với ô
  /// tỉnh đứng trên); đổi tỉnh ⇒ bỏ giá trị mọi ô xã phụ thuộc. Giá trị là ID.
  Widget _buildGeoField(MarketFormBlockEntity block) {
    final r = block.resolved;
    final laXa = r.inputType.toLowerCase() == 'ref_ward';
    final cha = _geoParentOf(block);
    final field = DynamicFormField(
      code: r.code,
      label: r.label.isNotEmpty ? r.label : r.code,
      type: laXa ? DynamicFormFieldType.geoWard : DynamicFormFieldType.geoProvince,
      helperText: r.description,
      isRequired: block.required,
    );
    return GeoSelectFieldWidget(
      field: field,
      wardLevel: laXa,
      provinceId: cha == null ? null : GeoSelectFieldWidget.idOf(_answers[cha]),
      value: _answers[r.code],
      errorText: _errors[r.code],
      onChanged: (id) {
        final truoc = GeoSelectFieldWidget.idOf(_answers[r.code]);
        _updateValue(r.code, id);
        if (!laXa && truoc != id) {
          for (final b in widget.blocks) {
            if (_geoParentOf(b) == r.code && _answers.containsKey(b.resolved.code)) {
              _updateValue(b.resolved.code, null);
            }
          }
        }
      },
    );
  }

  /// Mã ô tỉnh mà ô [block] lọc theo (`config.depends_on[0].field_code`), hoặc null.
  String? _geoParentOf(MarketFormBlockEntity block) {
    final cfg = block.resolved.config;
    final dep = cfg is Map ? cfg['depends_on'] : null;
    if (dep is List && dep.isNotEmpty && dep.first is Map) {
      return (dep.first as Map)['field_code']?.toString();
    }
    return null;
  }

  // ==========================================
  // Ô ĐỊA CHỈ + TOẠ ĐỘ GPS (LOCATION - SPEC 13/10/2026)
  // ==========================================

  Widget _buildLocationField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final val = _answers[code];
    Map<String, dynamic>? locMap;
    if (val is Map<String, dynamic>) {
      locMap = Map<String, dynamic>.from(val);
    } else if (val is Map) {
      locMap = Map<String, dynamic>.from(val);
    } else if (val is String && val.trim().isNotEmpty) {
      locMap = {'address': val.trim()};
    }

    // Nếu trường chưa có toạ độ nhưng context điểm bán có toạ độ, tự điền khởi tạo
    if (locMap != null && locMap['lat'] == null) {
      final custLat = widget.customerContext['lat'];
      final custLng = widget.customerContext['lng'];
      if (custLat != null && custLng != null) {
        locMap['lat'] = custLat;
        locMap['lng'] = custLng;
      }
    } else if (locMap == null && widget.defaultCustomerAddress != null && widget.defaultCustomerAddress!.isNotEmpty) {
      locMap = {
        'address': widget.defaultCustomerAddress,
        if (widget.customerContext['lat'] != null) 'lat': widget.customerContext['lat'],
        if (widget.customerContext['lng'] != null) 'lng': widget.customerContext['lng'],
      };
    }

    return LocationFieldWidget(
      label: block.resolved.label.isNotEmpty ? block.resolved.label : code,
      isRequired: block.required,
      isReadOnly: false,
      description: block.resolved.description,
      maxLength: block.resolved.validation?.maxLength ?? 500,
      errorText: _errors[code],
      value: locMap,
      onChanged: (newMap) {
        _updateValue(code, newMap);
      },
    );
  }

  // ==========================================
  // NHÓM TRÌNH BÀY (HEADING / NOTE / DIVIDER)
  // ==========================================

  Widget _buildNote(MarketFormBlockEntity block, bool isDark) => NoteFieldWidget(
        title: block.resolved.label,
        description: block.resolved.description,
      );

  // ==========================================
  // Ô NHẬP VĂN BẢN (TEXT & TEXTAREA)
  // ==========================================

  Widget _buildTextField(
    MarketFormBlockEntity block,
    bool isDark, {
    required bool isMultiline,
  }) {
    final isCustomerField = _isCustomerBlock(block) ||
        _isCustomerNameBlock(block) ||
        _isCustomerCodeBlock(block);
    final isLocked = widget.lockCustomer && isCustomerField;

    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';
    final controller = _getController(code, initial);

    final isPhone = !isMultiline && (code.toLowerCase().contains('phone') ||
        code.toLowerCase().contains('dien_thoai') ||
        code.toLowerCase().contains('sdt') ||
        block.resolved.label.toLowerCase().contains('điện thoại') ||
        block.resolved.label.toLowerCase().contains('sđt'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: isLocked ? null : _focusNodeOf(code),
          readOnly: isLocked,
          maxLines: isMultiline ? 4 : 1,
          minLines: isMultiline ? 3 : 1,
          keyboardType: isMultiline
              ? TextInputType.multiline
              : (isPhone ? TextInputType.phone : TextInputType.text),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: _inputDecoration(
            hintText: 'Nhập ${block.resolved.label.toLowerCase()}...',
            isDark: isDark,
            errorText: _errors[code],
            suffixIcon: isLocked
                ? null
                : VoiceInputMicButton(
                    fieldName: block.resolved.label.isNotEmpty ? block.resolved.label : code,
                    // Tự ghép với chữ ĐANG có trong ô: ô chữ không còn dựng lại mỗi phím (_updateTypedValue) nên
                    // `currentText` truyền lúc dựng có thể đã cũ — ghép theo nó là mất phần vừa gõ.
                    appendText: false,
                    onTextRecognized: (recognized) {
                      final typed = controller.text.trim();
                      final text = typed.isEmpty ? recognized : '$typed $recognized';
                      controller.text = text;
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                      _updateValue(code, text);
                    },
                  ),
          ),
          onChanged: isLocked ? null : (val) => _updateTypedValue(code, val),
        ),
      ],
    );
  }

  bool _isFormulaBlock(MarketFormBlockEntity block) => block.resolved.inputType.toLowerCase() == 'formula';

  // ==========================================
  // Ô CÔNG THỨC (FORMULA) — chỉ đọc, tự tính lại khi ô tham chiếu đổi
  // ==========================================

  Widget _buildFormulaField(MarketFormBlockEntity block, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        FormulaValueBox(
          value: _formulaValues[block.resolved.code],
          config: block.resolved.formula,
        ),
      ],
    );
  }

  // ==========================================
  // Ô NHẬP SỐ (NUMBER)
  // ==========================================

  Widget _buildNumberField(MarketFormBlockEntity block, bool isDark) {
    final isLocked = widget.lockCustomer && _isCustomerBlock(block);
    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initial,
          focusNode: isLocked ? null : _focusNodeOf(code),
          readOnly: isLocked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: _inputDecoration(
            hintText: 'Nhập số...',
            isDark: isDark,
            errorText: _errors[code],
          ),
          onChanged: isLocked
              ? null
              : (val) {
                  final parsed = num.tryParse(val);
                  _updateTypedValue(code, parsed);
                },
        ),
      ],
    );
  }

  // ==========================================
  // Ô BẬT TẮT (BOOLEAN)
  // ==========================================

  Widget _buildBooleanField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    return FormSwitchTile(
      title: _buildLabel(block, isDark),
      value: _answers[code] == true,
      hasError: _errors.containsKey(code),
      onChanged: (val) => _updateValue(code, val),
    );
  }

  // ==========================================
  // Ô CHỌN MỘT (RADIO)
  // ==========================================

  Widget _buildRadioField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final current = _answers[code];
    final allowOther = _allowsOther(block);
    final otherActive = allowOther && _otherText.containsKey(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: kFormLabelGapChoice),
        FormRadioGroup(
          options: _choiceOptions(block, allowOther),
          selectedKey: otherActive ? ChoiceOther.key : current?.toString(),
          hasError: _errors.containsKey(code),
          onChanged: (val) {
            if (val == ChoiceOther.key) {
              _setOtherActive(block, true);
            } else {
              _otherText.remove(code);
              _updateValue(code, val);
            }
          },
        ),
        if (otherActive) _buildOtherInput(block, isDark),
        if (_errors.containsKey(code)) FormFieldErrorText(_errors[code]!),
      ],
    );
  }

  /// Lựa chọn của ô (giá trị chuỗi) + «Khác…» cuối danh sách khi ô cho nhập khác.
  List<FormChoiceOption> _choiceOptions(MarketFormBlockEntity block, bool allowOther) => [
        ...block.resolved.options.map((o) => FormChoiceOption(o.value, o.label)),
        if (allowOther) const FormChoiceOption(ChoiceOther.key, ChoiceOther.label),
      ];

  /// Tích / bỏ tích một lựa chọn của ô chọn nhiều — «Khác…» bật/tắt ô gõ.
  void _toggleMulti(MarketFormBlockEntity block, List<String> currentList, Object? value, bool on) {
    if (value == ChoiceOther.key) {
      _setOtherActive(block, on);
      return;
    }
    final updated = List<String>.from(currentList);
    if (on) {
      updated.add(value as String);
    } else {
      updated.remove(value);
    }
    _updateValue(block.resolved.code, updated);
  }

  // ==========================================
  // Ô CHỌN NHIỀU (CHECKBOX)
  // ==========================================

  Widget _buildCheckboxField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final currentList = (_answers[code] as List?)?.map((e) => e.toString()).toList() ?? [];
    final allowOther = _allowsOther(block);
    final otherActive = allowOther && _otherText.containsKey(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: kFormLabelGapChoice),
        FormCheckboxGroup(
          options: _choiceOptions(block, allowOther),
          isChecked: (v) => v == ChoiceOther.key ? otherActive : currentList.contains(v),
          hasError: _errors.containsKey(code),
          onChanged: (v, on) => _toggleMulti(block, currentList, v, on),
        ),
        if (otherActive) _buildOtherInput(block, isDark),
        if (_errors.containsKey(code)) FormFieldErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // Ô SELECT (DROPDOWN CHỌN MỘT)
  // ==========================================

  Widget _buildSelectField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final current = _answers[code]?.toString();
    final options = block.resolved.options;
    final allowOther = _allowsOther(block);
    final otherActive = allowOther && _otherText.containsKey(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: kFormLabelGap),
        FormDropdown<String>(
          initialValue: otherActive ? ChoiceOther.key : (options.any((o) => o.value == current) ? current : null),
          items: [
            ...options.map((o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label),
                )),
            if (allowOther) const DropdownMenuItem(value: ChoiceOther.key, child: Text(ChoiceOther.label)),
          ],
          hintText: 'Chọn một giá trị...',
          errorText: _errors[code],
          onChanged: (val) {
            if (val == ChoiceOther.key) {
              _setOtherActive(block, true);
            } else {
              _otherText.remove(code);
              _updateValue(code, val);
            }
          },
        ),
        if (otherActive) _buildOtherInput(block, isDark),
      ],
    );
  }

  // ==========================================
  // Ô MULTISELECT (CHIPS CHỌN NHIỀU)
  // ==========================================

  Widget _buildMultiSelectField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final currentList = (_answers[code] as List?)?.map((e) => e.toString()).toList() ?? [];
    final allowOther = _allowsOther(block);
    final otherActive = allowOther && _otherText.containsKey(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: kFormLabelGap),
        FormChipGroup(
          options: _choiceOptions(block, allowOther),
          isSelected: (v) => v == ChoiceOther.key ? otherActive : currentList.contains(v),
          onSelected: (v, on) => _toggleMulti(block, currentList, v, on),
        ),
        if (otherActive) _buildOtherInput(block, isDark),
        if (_errors.containsKey(code)) FormFieldErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // Ô CHỌN NGÀY (DATE)
  // ==========================================

  Widget _buildDateField(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final code = block.resolved.code;
    final current = _answers[code]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: kFormLabelGap),
        FormTapField(
          text: current ?? 'Chưa chọn ngày',
          hasValue: current != null,
          hintText: 'Chọn ngày...',
          errorText: _errors[code],
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
          onTap: () async {
            final initialDate = current != null
                ? (DateTime.tryParse(current) ?? DateTime.now())
                : DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final formatted =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              _updateValue(code, formatted);
            }
          },
        ),
      ],
    );
  }

  // ==========================================
  // Ô ẢNH / MÁY ẢNH (IMAGE & FILE) (§1, §2, §3)
  // ==========================================

  Widget _buildImageField(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final code = block.resolved.code;
    return _buildPhotoPicker(
      context,
      isDark,
      key: code,
      label: block.resolved.label,
      description: block.resolved.description,
      isRequired: block.required,
      minFiles: _resolveMinFiles(block),
      maxFiles: _resolveMaxFiles(block),
      error: _errors[code],
    );
  }

  /// Bộ chụp ảnh dùng chung: ô ảnh (khoá = mã ô) và ảnh từng loại của ô ma trận (khoá [matrixPhotoKey]).
  Widget _buildPhotoPicker(
    BuildContext context,
    bool isDark, {
    required String key,
    required String label,
    String? watermark,
    String? description,
    bool isRequired = false,
    int minFiles = 0,
    required int maxFiles,
    String? error,
  }) {
    final entries = _photoEntries[key] ?? [];
    final canAddMore = entries.length < maxFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(
          label: label,
          isRequired: isRequired,
          description: description,
          trailing: FormPhotoCountBadge(count: entries.length, max: maxFiles, min: minFiles),
        ),
        const SizedBox(height: kFormLabelGap),

        FormPhotoFrame(
          hasError: error != null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entries.isNotEmpty) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: entries
                      .map((entry) => _buildPhotoThumbnail(context, key, entry, isDark))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Nút chụp ảnh
              if (canAddMore)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    side: BorderSide(
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(
                    entries.isEmpty
                        ? 'Chụp ảnh $label'.trim()
                        : 'Chụp thêm ảnh (${entries.length}/$maxFiles)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => _pickAndUploadPhoto(context, key, watermark ?? label, maxFiles),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryFixedDim : AppColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Đã đủ $maxFiles ảnh tối đa',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (error != null) FormFieldErrorText(error),
      ],
    );
  }

  // ==========================================
  // Ô MA TRẬN TRƯNG BÀY SOS (#24767)
  // ==========================================

  Widget _buildDisplayMatrixField(BuildContext context, MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final cfg = _matrixOf(block);
    return DisplayMatrixFieldWidget(
      fieldCode: code,
      label: block.resolved.label,
      description: block.resolved.description,
      isRequired: block.required,
      config: cfg,
      counts: DisplayMatrixFieldWidget.countsOf(_answers[code]),
      // Số hiện trạng của điểm bán (ô đích của "Cập nhật hiện trạng điểm bán") — gợi ý mờ, không điền sẵn (#24789).
      hintCounts: _hintCountsOf(block.resolved.configMap),
      errorText: _errors[code],
      onChanged: (counts, invalid) {
        _matrixInvalid[code] = invalid;
        final cur = _answers[code];
        final photos = cur is Map && cur['photos'] is Map ? cur['photos'] as Map : const {};
        // Xoá hết số và không ảnh ⇒ ô RỖNG (điều kiện hiển thị "có giá trị" và bản nháp đọc đúng).
        _updateValue(code, counts.isEmpty && photos.isEmpty ? null : {'counts': counts, 'photos': photos});
      },
      photoSection: (t) => _buildPhotoPicker(
        context,
        isDark,
        key: matrixPhotoKey(code, t.code),
        label: 'Ảnh ${t.name}',
        // Đóng dấu ảnh theo nhãn ô như mọi ảnh biểu mẫu khác (không theo tên loại).
        watermark: block.resolved.label,
        minFiles: t.effectiveMinPhotos,
        maxFiles: t.maxPhotos.clamp(1, 10),
      ),
    );
  }

  /// Ghép số đếm + ảnh theo loại vào câu trả lời của ô ma trận; [validate] ⇒ trả câu lỗi (cùng luật server) hoặc `null`.
  /// Không nhập ô nào và không ảnh nào ⇒ gỡ câu trả lời (rỗng — luật bắt buộc quyết).
  String? _syncMatrixAnswer(MarketFormBlockEntity block, {bool validate = false}) {
    final code = block.resolved.code;
    final cfg = _matrixOf(block);
    final counts = DisplayMatrixFieldWidget.onlyAsked(DisplayMatrixFieldWidget.countsOf(_answers[code]), cfg);
    final photos = <String, List<String>>{};
    for (final t in cfg.types) {
      // Loại không chụp ảnh (max 0): ảnh còn sót của bản nháp cũ không gửi — server từ chối "không nhận ảnh".
      if (t.maxPhotos <= 0) continue;
      final list = (_photoEntries[matrixPhotoKey(code, t.code)] ?? const <FormPhotoEntry>[])
          .map((e) => (e.token != null && e.token!.isNotEmpty) ? e.token! : e.localPath)
          .where((s) => s.isNotEmpty)
          .toList();
      if (list.isNotEmpty) photos[t.code] = list;
    }
    if (counts.isEmpty && photos.isEmpty) {
      _answers.remove(code);
    } else {
      _answers[code] = {'counts': counts, 'photos': photos};
    }
    if (!validate) return null;

    final label = block.resolved.label.isNotEmpty ? block.resolved.label : code;
    if (block.required && counts.isEmpty && photos.isEmpty) return '$label không được để trống.';
    if (_matrixInvalid[code] == true) return '$label – có ô đếm nhập sai dạng số.';
    final cellErr = DisplayMatrixFieldWidget.countsError(counts, cfg);
    if (cellErr != null) return '$label – $cellErr';
    for (final t in cfg.types) {
      final n = (photos[t.code] ?? const []).length;
      if (t.maxPhotos > 0 && n > t.maxPhotos) return '$label – ${t.name}: tối đa ${t.maxPhotos} ảnh.';
      if (t.effectiveMinPhotos > 0 && DisplayMatrixTotals.sumOfType(counts, t.code) > 0 && n < t.effectiveMinPhotos) {
        return '$label – ${t.name}: cần ít nhất ${t.effectiveMinPhotos} ảnh.';
      }
    }
    return null;
  }

  Widget _buildPhotoThumbnail(
    BuildContext context,
    String key,
    FormPhotoEntry entry,
    bool isDark,
  ) {
    final hasLocal = entry.localPath.isNotEmpty && File(entry.localPath).existsSync();
    final hasRemote = entry.previewUrl != null && entry.previewUrl!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showImagePreviewDialog(context, entry),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              ),
              color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerHigh,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasLocal)
                    Image.file(
                      File(entry.localPath),
                      key: ValueKey(entry.localPath),
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                    )
                  else if (hasRemote)
                    Image.network(
                      entry.fullPreviewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: AppColors.error),
                      ),
                      cacheWidth: 720,
                    )
                  else
                    const Center(child: Icon(Icons.photo_rounded, size: 28, color: Colors.grey)),

                  // Trạng thái đang tải lên / xử lý ảnh
                  if (entry.isUploading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Trạng thái lỗi tải lên
                  if (!entry.isUploading && entry.uploadError != null)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => _retryUploadPhoto(key, entry),
                              child: const Text(
                                'Thử lại',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Nút xoá ảnh
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removePhoto(key, entry),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }


  void _showImagePreviewDialog(BuildContext context, FormPhotoEntry entry) {
    final hasLocal = entry.localPath.isNotEmpty && File(entry.localPath).existsSync();
    final hasRemote = entry.previewUrl != null && entry.previewUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: hasLocal
                    ? Image.file(File(entry.localPath), fit: BoxFit.contain)
                    : hasRemote
                        ? Image.network(entry.fullPreviewUrl, fit: BoxFit.contain)
                        : Container(
                            color: Colors.black,
                            height: 200,
                            child: const Center(
                              child: Text('Không thể tải ảnh', style: TextStyle(color: Colors.white)),
                            ),
                          ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
    BuildContext context,
    String code,
    String label,
    int maxFiles,
  ) async {
    final currentEntries = _photoEntries[code] ?? [];
    if (currentEntries.length >= maxFiles) return;

    // Chỉ cho phép chụp ảnh từ Camera
    final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
      context,
      featureName: 'khảo sát thị trường',
      customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh khảo sát trực tiếp tại điểm bán. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
    );
    if (!hasPermission) return;

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo == null) return;

      // HIỂN THỊ NGAY LẬP TỨC BOX ẢNH VỚI VÒNG XOAY LOADING TRÊN GIAO DIỆN
      final entry = FormPhotoEntry(
        localPath: photo.path,
        isUploading: true,
      );

      setState(() {
        if (!_photoEntries.containsKey(code)) {
          _photoEntries[code] = [];
        }
        _photoEntries[code]!.add(entry);
        _errors.remove(code);
      });

      // Thực hiện đóng dấu toạ độ và tải lên ngầm
      try {
        final watermarked = await PhotoWatermarkHelper.addWatermark(
          imageFile: File(photo.path),
          locationName: label,
        );
        entry.localPath = watermarked.path;

        if (widget.onUploadPhoto != null) {
          final result = await widget.onUploadPhoto!(watermarked);
          if (mounted) {
            setState(() {
              entry.token = result.token;
              entry.previewUrl = result.url;
              entry.isUploading = false;
              entry.uploadError = null;
              _updateAnswersForImageField(code);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              entry.isUploading = false;
              _updateAnswersForImageField(code);
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            entry.isUploading = false;
            entry.uploadError = e.toString().replaceAll('AppException: ', '');
            _updateAnswersForImageField(code);
          });
        }
      }
    } catch (e) {
      debugPrint('[MarketFormRenderer] Lỗi chụp ảnh: $e');
    }
  }

  Future<void> _retryUploadPhoto(
    String code,
    FormPhotoEntry entry,
  ) async {
    if (widget.onUploadPhoto == null || entry.localPath.isEmpty) return;

    setState(() {
      entry.isUploading = true;
      entry.uploadError = null;
    });

    try {
      final result = await widget.onUploadPhoto!(File(entry.localPath));
      if (mounted) {
        setState(() {
          entry.token = result.token;
          entry.previewUrl = result.url;
          entry.isUploading = false;
          entry.uploadError = null;
          _updateAnswersForImageField(code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          entry.isUploading = false;
          entry.uploadError = e.toString().replaceAll('AppException: ', '');
          _updateAnswersForImageField(code);
        });
      }
    }
  }

  void _removePhoto(String code, FormPhotoEntry entry) {
    setState(() {
      _photoEntries[code]?.remove(entry);
      if (_photoEntries[code]?.isEmpty ?? false) {
        _photoEntries.remove(code);
      }
      _updateAnswersForImageField(code);
    });
  }

  void _updateAnswersForImageField(String code) {
    // Ảnh của một loại trong ô ma trận: ghép lại câu trả lời của CẢ ô.
    final matrix = splitMatrixPhotoKey(code);
    if (matrix != null) {
      final block = widget.blocks.where((b) => b.resolved.code == matrix.$1).firstOrNull;
      if (block != null) {
        _errors.remove(matrix.$1);
        _syncMatrixAnswer(block);
      }
      widget.onChanged?.call(_answers);
      return;
    }
    final entries = _photoEntries[code] ?? [];
    if (entries.isNotEmpty) {
      _answers[code] = entries
          .map((e) => (e.token != null && e.token!.isNotEmpty) ? e.token! : e.localPath)
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      _answers.remove(code);
    }
    widget.onChanged?.call(_answers);
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildLabel(MarketFormBlockEntity block, bool isDark) => FormFieldLabel(
        label: block.resolved.label,
        isRequired: block.required,
        description: block.resolved.description,
      );

  InputDecoration _inputDecoration({
    required String hintText,
    required bool isDark,
    String? errorText,
    Widget? suffixIcon,
  }) =>
      formFieldDecoration(hintText: hintText, isDark: isDark, errorText: errorText, suffixIcon: suffixIcon);
}

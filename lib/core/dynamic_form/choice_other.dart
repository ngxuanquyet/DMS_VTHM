/// «Cho phép nhập giá trị khác» của ô chọn một / chọn nhiều (chốt 31/10/2026) — dùng chung cho form điểm bán
/// ([DynamicFormBuilder]) và biểu mẫu thị trường ([MarketFormRenderer]).
///
/// Admin bật cờ `allow_other` cho từng ô có danh sách gõ tay ⇒ cuối danh sách có thêm mục «Khác…»; chọn mục đó thì
/// hiện ô gõ. Chuỗi gõ tay đặt THẲNG làm giá trị (đã trim): ô chọn một gửi chuỗi đó, ô chọn nhiều gửi các lựa chọn đã
/// tích + TỐI ĐA MỘT chuỗi gõ tay. Giá trị không thuộc danh sách khi mở lại bản ghi/nháp ⇒ coi là giá trị «Khác».
///
/// 🔴 [key] chỉ là giá trị nội bộ của mục «Khác…» trên giao diện (Dropdown/Radio) — KHÔNG bao giờ ghi vào dữ liệu form
/// hay bản nháp; "đang chọn Khác" do màn chứa giữ riêng (tập mã ô), dữ liệu chỉ chứa giá trị THẬT. Ô gõ:
/// [ChoiceOtherInput] (`widgets/choice_other_input.dart`).
class ChoiceOther {
  ChoiceOther._();

  /// Giá trị nội bộ của mục «Khác…» trong ô chọn — chỉ sống trong widget.
  static const String key = '__other__';

  /// Nhãn mục «Khác…».
  static const String label = 'Khác…';

  /// Trần độ dài chuỗi gõ tay (server từ chối quá trần — `ChoiceOtherConfig::MAX_LENGTH`).
  static const int maxLength = 255;

  /// Lỗi khi ô bắt buộc đã chọn «Khác…» mà chưa gõ.
  static const String emptyError = 'Vui lòng nhập giá trị khác';

  /// Lỗi khi chuỗi gõ tay vượt trần (bản ghi cũ — ô gõ đã chặn [maxLength]).
  static const String tooLongError = 'Giá trị khác không được vượt quá $maxLength ký tự';

  /// Cờ của ô: khoá phẳng `allow_other` (schema form điểm bán) hoặc `config.allow_other` (biểu mẫu thị trường).
  static bool enabledIn(dynamic json) {
    if (json is! Map) return false;
    if (json['allow_other'] == true) return true;
    final cfg = json['config'];
    return cfg is Map && cfg['allow_other'] == true;
  }

  static bool _inOptions(dynamic v, Iterable<dynamic> optionValues) =>
      optionValues.any((o) => o == v || o.toString() == v.toString());

  static bool _blank(dynamic v) => v == null || v.toString().trim().isEmpty;

  /// Giá trị gõ tay của ô chọn một: chuỗi không rỗng KHÔNG thuộc danh sách; `null` nếu trống / thuộc danh sách.
  static String? foreignSingle(dynamic value, Iterable<dynamic> optionValues) {
    if (value is List || value is Map || _blank(value)) return null;
    return _inOptions(value, optionValues) ? null : value.toString();
  }

  /// Giá trị gõ tay của ô chọn nhiều: phần tử ĐẦU TIÊN không thuộc danh sách (server chỉ nhận một).
  static String? foreignMulti(dynamic values, Iterable<dynamic> optionValues) {
    if (values is! List) return null;
    for (final v in values) {
      if (!_blank(v) && !_inOptions(v, optionValues)) return v.toString();
    }
    return null;
  }

  /// Ghép giá trị ô chọn nhiều: các lựa chọn THUỘC danh sách đang tích (giữ thứ tự) + chuỗi gõ tay (đã trim, bỏ nếu
  /// trống). Mọi phần tử lạ khác bị bỏ — server chỉ nhận một giá trị ngoài danh sách.
  ///
  /// 🔴 Chữ gõ TRÙNG một lựa chọn (value hoặc nhãn [optionLabels], so chính xác) KHÔNG đưa vào giá trị — muốn chọn thì
  /// người dùng tự tích. Không thì gõ dần "Siêu thị mini" đi qua "Siêu thị" sẽ phát ra lựa chọn "Siêu thị", lượt sau
  /// coi là đã tích ⇒ lưu cả hai (cùng luật với SPA).
  static List<T> composeMulti<T>(
    Iterable<T> values,
    Iterable<dynamic> optionValues,
    String? other, {
    Iterable<String> optionLabels = const [],
  }) {
    final out = values.where((v) => _inOptions(v, optionValues)).toList();
    final text = other?.trim() ?? '';
    final trungLuaChon = optionValues.any((o) => o.toString() == text) || optionLabels.contains(text);
    if (text.isNotEmpty && !trungLuaChon) out.add(text as T);
    return out;
  }

  /// Lỗi của phần «Khác» khi lưu; `null` = hợp lệ. Ô KHÔNG bắt buộc để trống ⇒ coi như không chọn «Khác» (hợp lệ).
  static String? validate({required bool active, required bool required, required String? other}) {
    if (!active) return null;
    final text = other?.trim() ?? '';
    if (text.isEmpty) return required ? emptyError : null;
    if (text.length > maxLength) return tooLongError;
    return null;
  }
}

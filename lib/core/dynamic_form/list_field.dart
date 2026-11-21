/// Ô lưu DANH SÁCH giá trị (chọn nhiều) — bản app của `RuleEvaluator::isListType()` (server) / `isListType` (SPA, #24038):
/// `multiselect`, `checkbox` có lựa chọn, ô tham chiếu bật `config.multiple` (Điểm bán, Khách hàng pháp nhân). Điều kiện
/// hiển thị đọc ô này như danh sách.
bool isListFieldType(String inputType, {bool hasOptions = false, bool multiple = false}) =>
    inputType == 'multiselect' ||
    (inputType == 'checkbox' && hasOptions) ||
    (multiple && (inputType == 'ref_customer' || inputType == 'ref_erp_partner'));

/// `!empty()` của PHP — `null`, `false`, `0`, `'0'`, `''`, mảng/map rỗng là rỗng (server `hasChoices` / `config.multiple`).
bool phpNotEmpty(dynamic v) =>
    !(v == null ||
        v == false ||
        v == 0 ||
        v == '' ||
        v == '0' ||
        (v is Iterable && v.isEmpty) ||
        (v is Map && v.isEmpty));

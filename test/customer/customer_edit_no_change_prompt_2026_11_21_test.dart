import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/presentation/screens/edit_customer_screen.dart';

/// #24755: điểm bán chưa có ảnh — form dựng ô ảnh thành [] còn dữ liệu gốc không có khoá ⇒ không được coi là đã sửa.
void main() {
  test('ô ảnh rỗng [] so với không có (null) ⇒ không đổi', () {
    expect(editCustomerValueChanged('photo_file_id', <dynamic>[], null), isFalse);
    expect(editCustomerValueChanged('note', '', null), isFalse);
    expect(editCustomerValueChanged('extra', <String, dynamic>{}, null), isFalse);
  });

  test('thêm ảnh / gõ chữ vẫn là đã sửa', () {
    expect(editCustomerValueChanged('photo_file_id', ['a.jpg'], null), isTrue);
    expect(editCustomerValueChanged('photo_file_id', ['a.jpg'], ['b.jpg']), isTrue);
    expect(editCustomerValueChanged('name', 'Tạp hoá A', 'Tạp hoá B'), isTrue);
    expect(editCustomerValueChanged('photo_file_id', <dynamic>[], ['b.jpg']), isTrue);
  });

  test('toạ độ so theo số', () {
    expect(editCustomerValueChanged('coords', {'lat': 21, 'lng': 105}, {'lat': 21.0, 'lng': 105.0}), isFalse);
    expect(editCustomerValueChanged('coords', {'lat': 21.1, 'lng': 105}, {'lat': 21.0, 'lng': 105.0}), isTrue);
  });
}

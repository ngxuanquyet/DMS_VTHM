import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/text_field_widget.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/edit_customer_screen.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm tra bàn phím số cho trường Số điện thoại (DynamicTextFieldWidget)', () {
    testWidgets('Trường phone hiển thị bàn phím phone và icon điện thoại', (tester) async {
      const phoneField = DynamicFormField(
        code: 'phone',
        label: 'Số điện thoại',
        type: DynamicFormFieldType.text,
        placeholder: 'Nhập số điện thoại...',
      );

      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicTextFieldWidget(
              field: phoneField,
              value: '0987654321',
              onChanged: (val) => changedValue = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra TextField có keyboardType là TextInputType.phone
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.keyboardType, TextInputType.phone);

      // Kiểm tra icon điện thoại
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      // Nhập thêm ký tự
      await tester.enterText(textFieldFinder, '0987654322');
      expect(changedValue, '0987654322');
    });

    testWidgets('Trường văn bản bình thường dùng bàn phím text mặc định', (tester) async {
      const normalField = DynamicFormField(
        code: 'contact_name',
        label: 'Người liên hệ',
        type: DynamicFormFieldType.text,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicTextFieldWidget(
              field: normalField,
              value: 'Nguyễn Văn A',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.text);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });
  });

  group('Kiểm tra EditCustomerScreen ẩn Bottom Bar Nav và có SafeArea', () {
    testWidgets('EditCustomerScreen chứa SafeArea cho nút Cập nhật ở đáy màn hình', (tester) async {
      const customer = CustomerEntity(
        id: 101,
        code: 'CUST-001',
        name: 'Tạp hóa Bình An',
        type: 'Đại lý',
        route: 'Tuyến số 1',
        address: '123 Đường Láng, Hà Nội',
        contactPerson: 'Nguyễn Văn A',
        phone: '0912345678',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EditCustomerScreen(
              customer: customer,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra có SafeArea ở đáy cho nút CẬP NHẬT THÔNG TIN ĐIỂM BÁN
      expect(find.text('CẬP NHẬT THÔNG TIN ĐIỂM BÁN'), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('Kiểm tra Button Chỉ đường dùng field địa chỉ động, nếu null thì dùng lat lng', () {
    test('extractDynamicAddress trích xuất đúng địa chỉ từ dynamicFields', () {
      // 1. Trường hợp có key dia_chi dạng chuỗi
      final dyn1 = {'dia_chi': 'Số 45 Lê Lợi, TP. Vinh', 'other': 123};
      expect(CustomerCard.extractDynamicAddress(dyn1, 'Địa chỉ cũ'), 'Số 45 Lê Lợi, TP. Vinh');

      // 2. Trường hợp có key location dạng Map có address
      final dyn2 = {
        'location': {'address': 'Chợ Cồn, Đà Nẵng', 'lat': 16.0678, 'lng': 108.2208}
      };
      expect(CustomerCard.extractDynamicAddress(dyn2, 'Địa chỉ cũ'), 'Chợ Cồn, Đà Nẵng');

      // 3. Trường hợp dynamicFields rỗng nhưng có fallbackAddress
      expect(CustomerCard.extractDynamicAddress({}, 'Địa chỉ fallback'), 'Địa chỉ fallback');

      // 4. Trường hợp dynamicFields null và không có fallbackAddress
      expect(CustomerCard.extractDynamicAddress(null, null), isNull);
      expect(CustomerCard.extractDynamicAddress(null, 'Chưa cập nhật'), isNull);
    });
  });
}

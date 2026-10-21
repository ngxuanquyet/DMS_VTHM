import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Màn tạo điểm bán theo ĐÚNG thứ tự Cấu hình trường điểm bán (mẫu chuẩn — chủ hệ thống 21/10/2026).
void main() {
  DynamicFormField o(String code, {String? section, DynamicFormFieldType type = DynamicFormFieldType.text}) =>
      DynamicFormField(code: code, label: 'Nhãn $code', type: type, section: section);

  test('không tiêu đề ⇒ một mục chung, giữ nguyên thứ tự (ô động không bị dồn xuống cuối)', () {
    final f = sectionsFromConfig([
      o('name', section: 'Thông tin chung'),
      o('nha_phan_phoi', section: 'Thông tin mở rộng (Động)'),
      o('region_id', section: 'Thông tin chung'),
      o('phone', section: 'Thông tin liên hệ'),
    ], {});
    expect(f.map((x) => x.code), ['name', 'nha_phan_phoi', 'region_id', 'phone']);
    expect(f.map((x) => x.section).toSet(), {'Thông tin điểm bán'});
  });

  test('ô heading mở mục cho các ô sau nó và không thành ô', () {
    final f = sectionsFromConfig([
      o('name'),
      const DynamicFormField(code: 'h1', label: 'Liên hệ', type: DynamicFormFieldType.text),
      o('phone'),
      o('email'),
    ], {'h1'});
    expect(f.map((x) => x.code), ['name', 'phone', 'email']);
    expect(f.map((x) => x.section), ['Thông tin điểm bán', 'Liên hệ', 'Liên hệ']);
  });

  testWidgets('keepFieldOrder: ô cùng mục nằm hai bên bản đồ KHÔNG bị gom lên trước bản đồ', (tester) async {
    final fields = sectionsFromConfig([
      o('name'),
      const DynamicFormField(code: 'coords', label: 'Toạ độ', type: DynamicFormFieldType.location),
      o('mw_nhan_1'),
    ], {});
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: DynamicFormBuilder(fields: fields, keepFieldOrder: true))),
      ),
    ));
    final yTen = tester.getTopLeft(find.text('Nhãn name')).dy;
    final yBanDo = tester.getTopLeft(find.text('Vị trí trên bản đồ').first).dy;
    final yNhan = tester.getTopLeft(find.text('Nhãn mw_nhan_1')).dy;
    expect(yTen < yBanDo && yBanDo < yNhan, isTrue, reason: 'thứ tự vẽ phải đúng thứ tự cấu hình');
    expect(find.text('Thông tin điểm bán'), findsOneWidget, reason: 'phần sau bản đồ không lặp tiêu đề mục');
  });
}

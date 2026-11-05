import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/erp_link_picker_sheet.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/erp_links_form_field.dart';

import '../helpers/fake_erp_link_request_service.dart';

/// Ô "Khách hàng ERP" trong form điểm bán (#24331, spec DIEM-BAN-KHACH-ERP §12).
void main() {
  test('giá trị ô: khứ hồi JSON; bắt buộc khi tạo = ≥1 khách hoặc tick; sửa ra đề xuất thêm / gỡ, không có role', () {
    final v = ErpLinksValue(
      customerId: 7,
      add: [
        ErpLinkPick(code: 'K2', name: 'NPP B', matchReason: 'manual', channelId: 1),
        ErpLinkPick(code: 'K4', name: 'NPP D', matchReason: 'phone', channelId: 1),
      ],
      remove: const {'K3'},
    );
    final lai = ErpLinksValue.fromJson(v.toJson());
    expect(lai.customerId, 7);
    expect(lai.editChanges(), [
      {'action': 'add', 'code': 'K2', 'match_reason': 'manual'},
      {'action': 'add', 'code': 'K4', 'match_reason': 'phone'},
      {'code': 'K3', 'action': 'remove'},
    ]);
    expect(lai.createLinks(), [
      {'code': 'K2', 'match_reason': 'manual'},
      {'code': 'K4', 'match_reason': 'phone'},
    ]);
    expect(const ErpLinksValue().satisfiesRequired, isFalse);
    expect(const ErpLinksValue(unknown: true).satisfiesRequired, isTrue);
    expect(ErpLinksValue.fromJson(null).hasChanges, isFalse);

    const o = DynamicFormField(code: 'erp_links', label: 'Khách hàng ERP', type: DynamicFormFieldType.erpPartner, isRequired: true);
    expect(erpLinksCreateValidator(o, null), isNotNull);
    expect(erpLinksCreateValidator(o, const ErpLinksValue(unknown: true).toJson()), isNull);
    expect(erpLinksCreateValidator(o.copyWith(isRequired: false), null), isNull, reason: 'admin tắt bắt buộc');
  });

  test('giá trị form lưu máy đời cũ (còn role / change_role) đọc không lỗi, bỏ vai', () {
    final cu = ErpLinksValue.fromJson({
      'customer_id': 7,
      'add': [
        {'code': 'K2', 'name': 'NPP B', 'role': 'owner', 'match_reason': 'phone'},
      ],
      'change_role': {'K1': 'showroom'},
      'remove': ['K3'],
    });
    expect(cu.editChanges(), [
      {'action': 'add', 'code': 'K2', 'match_reason': 'phone'},
      {'code': 'K3', 'action': 'remove'},
    ]);
    expect(cu.toJson().containsKey('change_role'), isFalse);
  });

  testWidgets('sửa: hiện đã duyệt / chờ duyệt / đã từ chối kèm lý do, không có vai; xin gỡ mối nối ⇒ giá trị có remove', (tester) async {
    final fake = FakeErpLinkRequestService(
      state: ErpLinkStateOfStore(
        links: [
          // Server đời cũ còn trả role/role_label — app bỏ qua.
          ErpLinkState.fromJson(const {'code': 'K1', 'name': 'NPP Hoàng Long', 'role': 'c2', 'role_label': 'Đại lý C2', 'channel_id': 1}),
        ],
        pending: const [ErpLinkState(id: 9, code: 'K2', name: 'NPP Hoàng Gia', action: 'add')],
        rejected: const [
          ErpLinkState(id: 8, code: 'K3', name: 'Cửa hàng X', action: 'add', actionLabel: 'Thêm khách ERP', decisionNote: 'Sai NPP'),
        ],
        unknown: false,
      ),
    );
    ErpLinksValue? giaTri;
    await tester.pumpWidget(ProviderScope(
      overrides: [erpLinkRequestServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ErpLinksFormField(
              label: 'Khách hàng ERP',
              value: const ErpLinksValue(customerId: 5),
              onChanged: (v) => giaTri = v,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Chờ duyệt · thêm khách hàng'), findsOneWidget);
    expect(find.textContaining('Quan hệ với NPP', findRichText: true), findsNothing, reason: 'bỏ vai 05/11/2026');
    expect(find.textContaining('Đại lý C2', findRichText: true), findsNothing);
    expect(find.text('Đã từ chối · Thêm khách ERP — Sai NPP'), findsOneWidget);
    expect(find.byKey(const Key('erp-links-unknown')), findsNothing, reason: 'sửa: không có ô tick');

    await tester.tap(find.descendant(of: find.byKey(const Key('erp-link-existing-K1')), matching: find.byIcon(Icons.edit_rounded)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đổi vai'), findsNothing);
    await tester.tap(find.byKey(const Key('erp-link-remove-existing-K1')));
    await tester.pumpAndSettle();
    expect(giaTri?.remove, {'K1'});
    expect(giaTri?.editChanges(), [
      {'code': 'K1', 'action': 'remove'},
    ]);
  });

  testWidgets('tạo: bắt buộc ⇒ có ô tick "Chưa xác định NPP"; tick đổi giá trị', (tester) async {
    ErpLinksValue? giaTri;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ErpLinksFormField(label: 'Khách hàng ERP', isRequired: true, value: const ErpLinksValue(), onChanged: (v) => giaTri = v),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erp-links-unknown')));
    await tester.pumpAndSettle();
    expect(giaTri?.unknown, isTrue);
  });
}

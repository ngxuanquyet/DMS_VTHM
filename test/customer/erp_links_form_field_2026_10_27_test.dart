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
  test('giá trị ô: khứ hồi JSON; bắt buộc khi tạo = ≥1 khách hoặc tick; sửa ra đề xuất thêm / đổi vai / gỡ', () {
    final v = ErpLinksValue(
      customerId: 7,
      add: [ErpLinkPick(code: 'K2', name: 'NPP B', role: ErpLinkRole.c2, matchReason: 'manual', channelId: 1)],
      changeRole: const {'K1': ErpLinkRole.showroom},
      remove: const {'K3'},
    );
    final lai = ErpLinksValue.fromJson(v.toJson());
    expect(lai.customerId, 7);
    expect(lai.editChanges(), [
      {'action': 'add', 'code': 'K2', 'role': 'c2', 'match_reason': 'manual'},
      {'code': 'K1', 'action': 'change_role', 'role': 'showroom'},
      {'code': 'K3', 'action': 'remove'},
    ]);
    expect(const ErpLinksValue().satisfiesRequired, isFalse);
    expect(const ErpLinksValue(unknown: true).satisfiesRequired, isTrue);
    expect(ErpLinksValue.fromJson(null).hasChanges, isFalse);

    const o = DynamicFormField(code: 'erp_links', label: 'Khách hàng ERP', type: DynamicFormFieldType.erpPartner, isRequired: true);
    expect(erpLinksCreateValidator(o, null), isNotNull);
    expect(erpLinksCreateValidator(o, const ErpLinksValue(unknown: true).toJson()), isNull);
    expect(erpLinksCreateValidator(o.copyWith(isRequired: false), null), isNull, reason: 'admin tắt bắt buộc');
  });

  testWidgets('sửa: hiện đã duyệt / chờ duyệt (đổi vai) / đã từ chối kèm lý do; xin gỡ mối nối ⇒ giá trị có remove', (tester) async {
    final fake = FakeErpLinkRequestService(
      state: const ErpLinkStateOfStore(
        links: [ErpLinkState(code: 'K1', name: 'NPP Hoàng Long', role: 'c2', roleLabel: 'Đại lý C2', channelId: 1)],
        pending: [
          ErpLinkState(
            id: 9, code: 'K2', name: 'NPP Hoàng Gia', role: 'showroom', roleLabel: 'Showroom',
            action: 'change_role', beforeRole: 'c2', beforeRoleLabel: 'Đại lý C2',
          ),
        ],
        rejected: [
          ErpLinkState(id: 8, code: 'K3', name: 'Cửa hàng X', role: 'owner', roleLabel: 'Chính khách', action: 'add',
              actionLabel: 'Thêm khách ERP', decisionNote: 'Sai NPP'),
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
    expect(find.text('Chờ duyệt · đổi vai Đại lý C2 → Showroom'), findsOneWidget);
    // Vai là quan hệ của điểm bán với khách ERP — dòng riêng "Quan hệ với NPP" (28/10/2026).
    expect(
      find.descendant(of: find.byKey(const Key('erp-link-existing-K1')), matching: find.text('Quan hệ với NPP: Đại lý C2', findRichText: true)),
      findsOneWidget,
    );
    expect(find.text('Đã từ chối · Thêm khách ERP — Sai NPP'), findsOneWidget);
    expect(find.byKey(const Key('erp-links-unknown')), findsNothing, reason: 'sửa: không có ô tick');

    await tester.tap(find.descendant(of: find.byKey(const Key('erp-link-existing-K1')), matching: find.byIcon(Icons.edit_rounded)));
    await tester.pumpAndSettle();
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

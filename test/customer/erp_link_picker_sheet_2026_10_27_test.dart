import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/services/erp_catalog_service.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/erp_link_picker_sheet.dart';

/// Khung "Điểm bán liên quan khách ERP nào?" (#24327): chọn nhiều khách, mỗi khách một vai theo kênh, chính khách tối đa một,
/// bắt buộc ≥1 khách hoặc tick "Chưa xác định NPP" khi tạo.
void main() {
  final catalog = ErpCatalog.fromJson({
    'roles': {'owner': [], 'showroom': [1], 'c2': [1]},
    'items': [
      {'code': '01380001', 'name': 'NPP Hoàng Long', 'address': 'Hà Nội', 'channel_id': 1, 'channel_name': 'Kênh phân phối'},
      {'code': '02700019', 'name': 'Cửa hàng Minh Phát', 'address': 'Tây Ninh', 'channel_id': 2, 'channel_name': 'Kênh bán lẻ'},
      {'code': '01380002', 'name': 'NPP Hoàng Gia', 'address': 'Hải Phòng', 'channel_id': 1, 'channel_name': 'Kênh phân phối'},
    ],
  });
  const goiY = [
    ErpLinkSuggestion(code: '02700019', name: 'Cửa hàng Minh Phát', channelId: 2, channelName: 'Kênh bán lẻ', matchReason: 'phone'),
  ];

  Future<void> moKhung(WidgetTester tester, Widget sheet, void Function(ErpLinkPickResult?) ketQua) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async => ketQua(await showModalBottomSheet<ErpLinkPickResult>(
            context: ctx,
            isScrollControlled: true,
            builder: (_) => sheet,
          )),
          child: const Text('mo'),
        ),
      ),
    ));
    await tester.tap(find.text('mo'));
    await tester.pumpAndSettle();
  }

  testWidgets('tạo: gợi ý SĐT ⇒ chính khách; tìm thêm NPP ⇒ C2; chính khách khoá ở khách thứ hai; xác nhận trả đủ', (tester) async {
    ErpLinkPickResult? kq;
    await moKhung(tester, ErpLinkPickerSheet(catalog: catalog, suggestions: goiY), (v) => kq = v);

    expect(find.text('Trùng SĐT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('erp-link-02700019')));
    await tester.pumpAndSettle();
    expect(find.text('Đã chọn (1)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('erp-link-search')), 'hoang long');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả tìm (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('erp-link-01380001')));
    await tester.pumpAndSettle();

    final seg = tester.widget<SegmentedButton<String>>(find.byKey(const Key('erp-link-role-01380001')));
    expect(seg.selected, {ErpLinkRole.c2});
    expect(seg.segments.firstWhere((s) => s.value == ErpLinkRole.owner).enabled, isFalse, reason: 'đã có chính khách');
    final segBanLe = tester.widget<SegmentedButton<String>>(find.byKey(const Key('erp-link-role-02700019')));
    expect(segBanLe.segments.map((s) => s.value), [ErpLinkRole.owner], reason: 'kênh bán lẻ chỉ làm chính khách');

    await tester.tap(find.byKey(const Key('erp-link-confirm')));
    await tester.pumpAndSettle();
    expect(kq?.picks.map((p) => p.toPayload()).toList(), [
      {'code': '02700019', 'role': 'owner', 'match_reason': 'phone'},
      {'code': '01380001', 'role': 'c2', 'match_reason': 'manual'},
    ]);
  });

  testWidgets('gợi ý khách thuộc kênh không vai nào nối được (bán lẻ) bị ẩn', (tester) async {
    final chiPhanPhoi = ErpCatalog.fromJson({
      'roles': {'owner': [1], 'showroom': [1], 'c2': [1]},
      'items': [
        {'code': '01380001', 'name': 'NPP Hoàng Long', 'address': 'Hà Nội', 'channel_id': 1, 'channel_name': 'Kênh phân phối'},
      ],
    });
    const goiY2 = [
      ...goiY,
      ErpLinkSuggestion(code: '01380001', name: 'NPP Hoàng Long', channelId: 1, channelName: 'Kênh phân phối', matchReason: 'name_address'),
    ];
    await moKhung(tester, ErpLinkPickerSheet(catalog: chiPhanPhoi, suggestions: goiY2), (_) {});
    expect(find.byKey(const Key('erp-link-02700019')), findsNothing);
    expect(find.byKey(const Key('erp-link-01380001')), findsOneWidget);
  });

  testWidgets('bỏ hết khách đã chọn vẫn xác nhận được (trả danh sách rỗng); không có ô tick trong khung', (tester) async {
    ErpLinkPickResult? kq;
    await moKhung(
      tester,
      ErpLinkPickerSheet(catalog: catalog, initial: [
        ErpLinkPick(code: '01380001', name: 'NPP Hoàng Long', role: ErpLinkRole.c2, matchReason: 'manual', channelId: 1),
      ]),
      (v) => kq = v,
    );
    expect(find.byKey(const Key('erp-link-unknown')), findsNothing);
    await tester.tap(find.byKey(const Key('erp-link-remove-01380001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('erp-link-confirm')));
    await tester.pumpAndSettle();
    expect(kq?.picks, isEmpty);
  });

  testWidgets('ẩn khách đã nối/đề xuất, chính khách khoá khi điểm bán đã có', (tester) async {
    await moKhung(
      tester,
      ErpLinkPickerSheet(catalog: catalog, ownerTaken: true, excludeCodes: const {'01380001'}),
      (_) {},
    );
    await tester.enterText(find.byKey(const Key('erp-link-search')), 'npp hoang');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('erp-link-01380001')), findsNothing);
    expect(find.byKey(const Key('erp-link-01380002')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('erp-link-search')), 'minh phat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Kênh không được nối'), findsOneWidget, reason: 'khách bán lẻ chỉ làm chính khách mà điểm bán đã có ⇒ mờ');
  });

  testWidgets('chưa có danh mục trên máy (mất mạng từ lần đầu): ô tìm khoá', (tester) async {
    await moKhung(tester, const ErpLinkPickerSheet(catalog: null), (_) {});
    expect(tester.widget<TextField>(find.byKey(const Key('erp-link-search'))).enabled, isFalse);
  });
}

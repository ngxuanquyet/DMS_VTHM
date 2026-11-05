import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/services/erp_catalog_service.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/erp_link_picker_sheet.dart';

/// Khung "Điểm bán liên quan khách ERP nào?" (#24327): chọn NHIỀU nhà phân phối, không còn vai (chủ hệ thống bỏ 05/11/2026);
/// chỉ khách thuộc kênh danh mục cho phép.
void main() {
  final catalog = ErpCatalog.fromJson({
    'channels': [],
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

  testWidgets('tạo: chọn gợi ý SĐT + tìm thêm NPP ⇒ chọn được 2 NPP, không có ô vai, payload không có role', (tester) async {
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
    // Đã chọn luôn ở ĐẦU, kể cả khi đang tìm (28/10/2026) — không phải cuộn qua danh sách lọc mới thấy.
    expect(
      tester.getTopLeft(find.text('Đã chọn (1)')).dy,
      lessThan(tester.getTopLeft(find.text('Kết quả tìm (1)')).dy),
    );
    await tester.tap(find.byKey(const Key('erp-link-01380001')));
    await tester.pumpAndSettle();
    expect(find.text('Đã chọn (2)'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing, reason: 'bỏ vai 05/11/2026');
    expect(find.text('Quan hệ với NPP:'), findsNothing);

    await tester.tap(find.byKey(const Key('erp-link-confirm')));
    await tester.pumpAndSettle();
    expect(kq?.picks.map((p) => p.toPayload()).toList(), [
      {'code': '02700019', 'match_reason': 'phone'},
      {'code': '01380001', 'match_reason': 'manual'},
    ]);
  });

  testWidgets('danh mục chỉ cho kênh phân phối: gợi ý + kết quả tìm khách kênh bán lẻ bị ẩn', (tester) async {
    final chiPhanPhoi = ErpCatalog.fromJson({
      'channels': [1],
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

    await tester.enterText(find.byKey(const Key('erp-link-search')), 'minh phat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả tìm (0)'), findsOneWidget);
  });

  testWidgets('bỏ hết khách đã chọn vẫn xác nhận được (trả danh sách rỗng); không có ô tick trong khung', (tester) async {
    ErpLinkPickResult? kq;
    await moKhung(
      tester,
      ErpLinkPickerSheet(catalog: catalog, initial: [
        ErpLinkPick(code: '01380001', name: 'NPP Hoàng Long', matchReason: 'manual', channelId: 1),
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

  testWidgets('ẩn khách đã nối/đề xuất cho điểm bán', (tester) async {
    await moKhung(tester, ErpLinkPickerSheet(catalog: catalog, excludeCodes: const {'01380001'}), (_) {});
    await tester.enterText(find.byKey(const Key('erp-link-search')), 'npp hoang');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('erp-link-01380001')), findsNothing);
    expect(find.byKey(const Key('erp-link-01380002')), findsOneWidget);
  });

  testWidgets('chưa có danh mục trên máy (mất mạng từ lần đầu): ô tìm khoá', (tester) async {
    await moKhung(tester, const ErpLinkPickerSheet(catalog: null), (_) {});
    expect(tester.widget<TextField>(find.byKey(const Key('erp-link-search'))).enabled, isFalse);
  });
}

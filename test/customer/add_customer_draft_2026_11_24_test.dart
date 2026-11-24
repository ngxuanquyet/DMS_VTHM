import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/forms/data/services/form_draft_store.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

import '../helpers/fake_inter_fonts.dart';

/// Chốt 24/11/2026: màn "Thêm mới điểm bán" tự lưu nháp như biểu mẫu — MỘT nháp mỗi tài khoản, giữ 20 giờ; mở lại màn thì
/// khôi phục + dải "Đã khôi phục nháp"; thoát khi đã có nháp không hỏi; "Xoá nháp, làm lại" bỏ nháp, màn trống.
class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

void main() {
  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 42})});
    docs = Directory.systemTemp.createTempSync('customer_draft');
    PathProviderPlatform.instance = _Paths(docs);
    fakeInterFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
  });

  tearDown(() => docs.deleteSync(recursive: true));

  ProviderContainer khoi() => ProviderContainer(
        overrides: [
          customerFormSchemaProvider.overrideWith((ref) => Stream.value({
                'status': 'success',
                'data': {
                  'form': {'name': 'Hồ sơ điểm bán'},
                  'version': '1.0',
                  'fields': [
                    {'code': 'name', 'label': 'Tên điểm bán', 'type': 'text', 'is_required': true},
                    {'code': 'note', 'label': 'Ghi chú', 'type': 'text', 'is_required': false},
                  ],
                },
              })),
          customerMetaProvider.overrideWith((ref) async => kDefaultCustomerMeta),
          userAssignedRoutesProvider.overrideWith((ref) async => const <UserRouteEntity>[]),
        ],
      );

  Widget app(ProviderContainer c) =>
      UncontrolledProviderScope(container: c, child: const MaterialApp(home: AddCustomerScreen()));

  Future<Map<String, dynamic>?> nhap() async => (await FormDraftStore.load(
        visitId: FormDraftStore.collectVisitId,
        clientUuid: FormDraftStore.customerUuid,
        configId: FormDraftStore.customerConfigId,
        slotKey: FormDraftStore.customerSlot('42'),
      ))
          ?.answers;

  /// Cho kho nháp (IO thật) ghi xong — chuỗi ghi tĩnh của kho chạy trong vùng thời gian giả của test.
  Future<void> choGhi(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  // MỘT ca: kho nháp ghi nối tiếp qua chuỗi TĨNH — chuỗi mở trong vùng thời gian giả của ca trước không xong ở ca sau.
  testWidgets('gõ ⇒ tự lưu nháp; mở lại ⇒ khôi phục + dải nháp; thoát không hỏi; «Xoá nháp, làm lại» ⇒ màn trống, hết nháp; '
      'rời ngay sau khi gõ vẫn lưu',
      (tester) async {
    final c = khoi();
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(find.text('Đã khôi phục nháp', findRichText: true), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Tạp hoá Bình Minh');
    await tester.pump(const Duration(seconds: 2)); // nhịp tự lưu 1 s
    await choGhi(tester);
    expect((await tester.runAsync(nhap))?['form'], containsPair('name', 'Tạp hoá Bình Minh'));

    // Có nháp ⇒ bấm HỦY BỎ rời màn luôn, không hỏi «Rời khỏi màn hình?».
    await tester.tap(find.text('HỦY BỎ'));
    await tester.pumpAndSettle();
    expect(find.text('Rời khỏi màn hình?'), findsNothing);

    // Mở lại màn (app bị đóng rồi mở lại) ⇒ khôi phục.
    await tester.pumpWidget(const SizedBox());
    await choGhi(tester);
    await tester.pumpWidget(app(c));
    await choGhi(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã khôi phục nháp lúc'), findsOneWidget);
    expect(find.text('Tạp hoá Bình Minh'), findsOneWidget);

    await tester.tap(find.text('Xoá nháp, làm lại'));
    await tester.pumpAndSettle();
    await choGhi(tester);
    expect(find.textContaining('Đã khôi phục nháp lúc'), findsNothing);
    expect(find.text('Tạp hoá Bình Minh'), findsNothing);
    expect(await tester.runAsync(nhap), isNull);

    // Gõ rồi rời màn NGAY (chưa tới nhịp tự lưu 1 s) ⇒ nháp vẫn ghi ở dispose (không dùng `ref` sau khi màn đã gỡ).
    await tester.enterText(find.byType(TextField).first, 'Rời ngay');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await choGhi(tester);
    final luu = await tester.runAsync(nhap);
    expect(luu?['form'], containsPair('name', 'Rời ngay'));
    // client_uuid đi cùng nháp — khôi phục rồi Lưu lại vẫn cùng uuid (server trả điểm bán cũ, không tạo trùng).
    expect(luu?['client_uuid'], isA<String>().having((u) => u.length, 'độ dài', 36));

    // Nháp của HÔM TRƯỚC ⇒ mở màn thì bỏ (chốt 24/11/2026): lùi `saved_at` về hôm qua.
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      final key = FormDraftStore.customerSlot('42');
      final slot = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      final draft = (slot['drafts'] as Map)['${FormDraftStore.customerConfigId}'] as Map;
      draft['saved_at'] = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      await prefs.setString(key, jsonEncode(slot));
    });
    await tester.pumpWidget(app(c));
    await choGhi(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã khôi phục nháp lúc'), findsNothing);
    expect(find.text('Rời ngay'), findsNothing);
    expect(await tester.runAsync(nhap), isNull);

    await tester.pumpWidget(const SizedBox());
    await choGhi(tester);
    c.dispose();
    // Lượt tải danh sách điểm bán nền (gọi mạng thật, hỏng ngay trong test) còn hẹn giờ trong Dio — chạy nốt.
    await tester.pump(const Duration(seconds: 5));
  });

}

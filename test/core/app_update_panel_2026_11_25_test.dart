import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/core/update/app_update_logic.dart';
import 'package:vthm_dms/core/update/app_update_overlay.dart';

class _ManifestAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options) responder;
  _ManifestAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FixedRulesNotifier extends MobileRulesNotifier {
  _FixedRulesNotifier(MobileRules initial) : super(_FakeApiClient()) {
    state = initial;
  }

  @override
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async => state;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async => const <String, dynamic>{};
}

class _OnlineConnectivityNotifier extends ConnectivityNotifier {
  _OnlineConnectivityNotifier() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async => true;
}

/// Hộp cập nhật app (25/11/2026, review vòng 2): gỡ hộp GIỮA LÚC đang tải (mạng chập chờn / bản mới thay khoá) không được
/// ném lỗi «setState() called during build», và lớp phủ phải nhận lại tín hiệu «thôi tải».
void main() {
  const offer = AppUpdateOffer(
    forced: true,
    latestBuild: 16,
    url: 'https://one.vthmgroup.vn/dl/vthm-dms.apk',
    sha256: 'e07f7f227a7ab20d3c41ff3897835e9085902048aabaf848516c95b8e838d548',
  );

  testWidgets('bấm Cập nhật rồi gỡ hộp ⇒ không lỗi, cha nhận busy true rồi false', (tester) async {
    // Kênh native của ota_update: luồng tải MỞ mãi (không sự kiện cuối) ⇒ chỉ dispose() mới báo «thôi tải» — đúng nhánh cần đo.
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('sk.fourq.ota_update/stream'),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    var cancelled = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('sk.fourq.ota_update/method'), (call) async {
      if (call.method == 'cancel') cancelled++;
      return null;
    });
    addTearDown(() {
      messenger.setMockStreamHandler(const EventChannel('sk.fourq.ota_update/stream'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('sk.fourq.ota_update/method'), null);
    });
    final busy = <bool>[];
    final show = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, __) => Stack(
              children: [
                const SizedBox.expand(),
                if (visible) Positioned.fill(child: AppUpdatePanel(offer: offer, onActiveChanged: busy.add)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cập nhật'));
    await tester.pump();
    expect(busy, [true]);

    show.value = false;
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(busy, [true, false]);
    // Gỡ hộp giữa lượt tải ⇒ huỷ lượt native (không thì lượt mồ côi tự mở màn cài sau này).
    expect(cancelled, 1);
  });

  testWidgets(
    'AppUpdateOverlay (Android): manifest trả Content-Type application/json (versionCode 18 > build 17) ⇒ hiện hộp báo cập nhật, Để sau ẩn hộp',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'VTHM Đồng hành',
        packageName: 'vn.vthmgroup.dms',
        version: '1.0.15',
        buildNumber: '17',
        buildSignature: '',
      );

      const manifestUrl = 'https://one.vthmgroup.vn/dl/vthm-dms.json';
      final manifestBody = jsonEncode({
        'versionCode': 18,
        'versionName': '1.0.16',
        'fileName': 'vthm-dms.apk',
        'package': 'vn.vthmgroup.dms',
        'size': 122227325,
        'sha256': '942fbbf9f7b78d7e4396fb7b38d6720cc19cc952b0acb59e9098df355ae43bc0',
        'publishedAt': '2026-11-27T12:00:57Z',
        'notes': '',
      });

      // Dùng Dio thật (giữ nguyên DioMixin.fetch + FusedTransformer) để bắt đúng bẫy Content-Type: application/json.
      final dio = Dio()
        ..httpClientAdapter = _ManifestAdapter(
          (_) => ResponseBody.fromString(
            manifestBody,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json; charset=utf-8'],
            },
          ),
        );
      addTearDown(dio.close);

      final rulesNotifier = _FixedRulesNotifier(
        const MobileRules(appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileRulesProvider.overrideWith((_) => rulesNotifier),
            connectivityProvider.overrideWith((_) => _OnlineConnectivityNotifier()),
          ],
          child: MaterialApp(
            builder: (_, child) => AppUpdateOverlay(dio: dio, child: child ?? const SizedBox.shrink()),
            home: const Scaffold(body: Text('Trang chủ')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Có bản app mới'), findsOneWidget);
      expect(find.textContaining('1.0.16 (117 MB)'), findsOneWidget);
      expect(find.text('Cập nhật'), findsOneWidget);
      expect(find.text('Để sau'), findsOneWidget);

      await tester.tap(find.text('Để sau'));
      await tester.pump();
      expect(find.text('Có bản app mới'), findsNothing);

      // Máy chủ nâng min_build = 18 ⇒ bản bắt buộc vẫn phải hiện lại và không có nút Để sau.
      rulesNotifier.setRules(
        const MobileRules(appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần cập nhật app'), findsOneWidget);
      expect(find.text('Để sau'), findsNothing);
    },
  );

  testWidgets(
    'AppUpdateOverlay (Android): JSON hỏng kèm Content-Type application/json trả 200 ⇒ coi là không có bản, còn lỗi 500 giữ màn bắt buộc',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'VTHM Đồng hành',
        packageName: 'vn.vthmgroup.dms',
        version: '1.0.15',
        buildNumber: '17',
        buildSignature: '',
      );

      const manifestUrl = 'https://one.vthmgroup.vn/dl/vthm-dms.json';
      final validBody = jsonEncode({
        'versionCode': 18,
        'versionName': '1.0.16',
        'fileName': 'vthm-dms.apk',
        'package': 'vn.vthmgroup.dms',
        'size': 122227325,
        'sha256': '942fbbf9f7b78d7e4396fb7b38d6720cc19cc952b0acb59e9098df355ae43bc0',
      });

      var statusCode = 200;
      var body = validBody;
      final dio = Dio()
        ..httpClientAdapter = _ManifestAdapter(
          (_) => ResponseBody.fromString(
            body,
            statusCode,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
      addTearDown(dio.close);

      final rulesNotifier = _FixedRulesNotifier(
        const MobileRules(appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileRulesProvider.overrideWith((_) => rulesNotifier),
            connectivityProvider.overrideWith((_) => _OnlineConnectivityNotifier()),
          ],
          child: MaterialApp(
            builder: (_, child) => AppUpdateOverlay(dio: dio, child: child ?? const SizedBox.shrink()),
            home: const Scaffold(body: Text('Trang chủ')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần cập nhật app'), findsOneWidget);

      // Lỗi máy chủ 500 khi nạp lại luật ⇒ GIỮ màn bắt buộc cũ.
      statusCode = 500;
      body = '{"error":"bad gateway"}';
      rulesNotifier.setRules(
        const MobileRules(
          visit: VisitRules(minDurationMinutes: 12),
          appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18),
        ),
      );
      // Luật appUpdate chưa đổi nên gọi qua onStale hoặc đổi nhẹ iosLatestBuild để kích hoạt _check.
      rulesNotifier.setRules(
        const MobileRules(appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18, iosLatestBuild: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần cập nhật app'), findsOneWidget);

      // 200 qua https nhưng JSON bị cắt cụt (kể cả Content-Type: application/json) ⇒ coi là manifest hỏng (true, null), không phải lỗi mạng.
      statusCode = 200;
      body = '{"versionCode": 18';
      rulesNotifier.setRules(
        const MobileRules(appUpdate: AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18, iosLatestBuild: 2)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần cập nhật app'), findsNothing);
    },
  );
}

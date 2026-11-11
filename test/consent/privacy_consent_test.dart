import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/widgets/app_button.dart';
import 'package:vthm_dms/features/consent/data/privacy_consent_content.dart';
import 'package:vthm_dms/features/consent/data/privacy_consent_service.dart';
import 'package:vthm_dms/core/router/app_router.dart';
import 'package:vthm_dms/features/consent/presentation/privacy_consent_overlay.dart';

class FakeApiClient implements ApiClient {
  dynamic getResponse;
  bool offline = false;
  final List<Map<String, dynamic>> posts = [];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    if (offline) throw Exception('offline');
    return getResponse;
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    if (offline) throw Exception('offline');
    posts.add(Map<String, dynamic>.from(data as Map));
    return {'success': true, 'data': {'accepted': true}};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const vi = AppStrings(AppLanguage.vi);

Future<void> _login(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': id}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiClient api;
  late PrivacyConsentService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApiClient();
    service = PrivacyConsentService(api);
  });

  test('không rõ tài khoản trong máy ⇒ vẫn hỏi (không cho qua)', () async {
    expect(await service.needsConsent(), isTrue);
  });

  test('device_info dài quá trần cột máy chủ được cắt', () async {
    await _login('7');
    await service.accept();
    await Future<void>.delayed(Duration.zero);
    expect((api.posts.single['device_info'] as String).length, lessThanOrEqualTo(255));
  });

  test('máy chủ báo đã đồng ý ⇒ không hỏi, lần sau không gọi lại máy chủ', () async {
    await _login('7');
    api.getResponse = {'success': true, 'data': {'accepted': true, 'accepted_at': '2026-11-11 09:00:00+07'}};
    expect(await service.needsConsent(), isFalse);

    api.offline = true;
    expect(await service.needsConsent(), isFalse);
  });

  test('chưa đồng ý ⇒ hỏi; đồng ý thì gửi máy chủ đúng phiên bản và không hỏi lại', () async {
    await _login('7');
    api.getResponse = {'success': true, 'data': {'accepted': false}};
    expect(await service.needsConsent(), isTrue);

    await service.accept();
    await Future<void>.delayed(Duration.zero);
    expect(api.posts.single['terms_version'], privacyConsentVersion);
    expect(api.posts.single['accepted_at'], endsWith('Z'));
    expect(await service.needsConsent(), isFalse);
  });

  test('mất mạng ⇒ vẫn hỏi; đồng ý lúc offline được gửi bù khi có mạng', () async {
    await _login('7');
    api.offline = true;
    expect(await service.needsConsent(), isTrue);
    await service.accept();
    expect(api.posts, isEmpty);
    expect(await service.needsConsent(), isFalse);

    api.offline = false;
    expect(await service.needsConsent(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(api.posts, hasLength(1));
  });

  test('mỗi tài khoản đồng ý riêng trên cùng một máy', () async {
    await _login('7');
    api.offline = true;
    await service.accept();
    await _login('8');
    expect(await service.needsConsent(), isTrue);
  });

  group('cổng đồng ý', () {
    test('check: chưa đồng ý ⇒ required; đã đồng ý ⇒ accepted; accept ⇒ accepted + gửi máy chủ', () async {
      await _login('7');
      final gate = PrivacyConsentGate(service);
      api.getResponse = {'success': true, 'data': {'accepted': false}};
      await gate.check();
      expect(gate.state, ConsentGateStatus.required);

      await gate.accept();
      await Future<void>.delayed(Duration.zero);
      expect(gate.state, ConsentGateStatus.accepted);
      expect(api.posts, hasLength(1));

      await gate.check();
      expect(gate.state, ConsentGateStatus.accepted);
      gate.reset();
      expect(gate.state, ConsentGateStatus.unknown);
    });
  });

  test('kết quả check() cũ không đè trạng thái sau reset', () async {
    await _login('7');
    final gate = PrivacyConsentGate(service);
    api.getResponse = {'success': true, 'data': {'accepted': true}};
    final pending = gate.check();
    gate.reset();
    await pending;
    expect(gate.state, ConsentGateStatus.unknown);
  });

  testWidgets('thông báo chạm lúc chưa đồng ý được hoãn, đồng ý xong mới mở; khác phiên thì bỏ', (tester) async {
    final gate = PrivacyConsentGate(service);
    addTearDown(gate.reset);
    var opened = 0;

    // Chạm lúc chưa đăng nhập (phiên trước) ⇒ người đăng nhập sau đồng ý cũng KHÔNG mở.
    gate.reset();
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isTrue);
    gate.reset(); // bắt đầu đăng nhập
    gate.state = ConsentGateStatus.accepted;
    await tester.pump();
    expect(opened, 0);

    // Chạm trong lúc chờ đồng ý ⇒ đồng ý xong mở đúng một lần.
    gate.state = ConsentGateStatus.required;
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isTrue);
    gate.state = ConsentGateStatus.accepted;
    await tester.pump();
    expect(opened, 1);
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isFalse);

    // Đồng ý rồi nhưng đăng xuất + người khác đồng ý trước khung hình kế ⇒ không mở.
    gate.state = ConsentGateStatus.required;
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isTrue);
    gate.state = ConsentGateStatus.accepted;
    gate.reset();
    gate.state = ConsentGateStatus.accepted;
    await tester.pump();
    expect(opened, 1);

    // Cổng rời accepted trước khung hình kế (cùng phiên) ⇒ lần chạm được giữ lại, đồng ý lại thì mở.
    gate.state = ConsentGateStatus.required;
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isTrue);
    gate.state = ConsentGateStatus.accepted;
    gate.state = ConsentGateStatus.required;
    await tester.pump();
    expect(opened, 1);
    gate.state = ConsentGateStatus.accepted;
    await tester.pump();
    expect(opened, 2);

    // Chạm mới trong lúc lần hoãn cũ đang chờ khung hình ⇒ chỉ mở lần MỚI NHẤT, đúng một màn.
    final order = <String>[];
    gate.state = ConsentGateStatus.required;
    PrivacyConsentGate.deferUntilAccepted(() => order.add('A'));
    gate.state = ConsentGateStatus.accepted;
    expect(PrivacyConsentGate.deferUntilAccepted(() => order.add('B')), isTrue);
    await tester.pump();
    expect(order, ['B']);

    // Cổng mới (provider dựng lại) chưa kiểm ⇒ vẫn hoãn, không thừa hưởng accepted của cổng cũ.
    final fresh = PrivacyConsentGate(service);
    addTearDown(fresh.reset);
    expect(PrivacyConsentGate.deferUntilAccepted(() => opened++), isTrue);
  });

  group('lớp phủ', () {
    late PrivacyConsentGate gate;
    late GoRouter router;
    late int homeTaps;

    Future<void> pump(WidgetTester tester) async {
      homeTaps = 0;
      router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => Scaffold(
            body: Center(child: ElevatedButton(onPressed: () => homeTaps++, child: const Text('home-action'))),
          ),
        ),
        GoRoute(path: '/attendance', builder: (_, __) => const Scaffold(body: Text('attendance'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          privacyConsentGateProvider.overrideWith((ref) => gate),
          appRouterProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PrivacyConsentOverlay(child: child!),
        ),
      ));
      await tester.pumpAndSettle();
    }

    bool acceptEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, vi.consentAccept)).onPressed != null;

    setUp(() async {
      await _login('7');
      gate = PrivacyConsentGate(service)..state = ConsentGateStatus.required;
    });

    testWidgets('che app: chạm xuyên nền không lọt, màn mở từ thông báo vẫn bị che', (tester) async {
      await pump(tester);
      expect(find.text(vi.consentTitle), findsOneWidget);

      await tester.tap(find.text('home-action'), warnIfMissed: false);
      expect(homeTaps, 0);

      router.push('/attendance');
      await tester.pumpAndSettle();
      expect(find.text('attendance'), findsOneWidget);
      expect(find.text(vi.consentTitle), findsOneWidget);
    });

    testWidgets('nút Đồng ý chỉ sáng khi tick đủ hai ô; đồng ý thì lớp phủ biến mất', (tester) async {
      await pump(tester);
      expect(acceptEnabled(tester), isFalse);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(acceptEnabled(tester), isFalse);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(acceptEnabled(tester), isTrue);

      await tester.tap(find.text(vi.consentAccept));
      await tester.pumpAndSettle();
      expect(gate.state, ConsentGateStatus.accepted);
      expect(find.text(vi.consentTitle), findsNothing);
      await tester.tap(find.text('home-action'));
      expect(homeTaps, 1);
    });

    testWidgets('Từ chối ⇒ xác nhận; Xem lại quay về; đọc toàn văn ngay trong lớp phủ', (tester) async {
      await pump(tester);
      await tester.tap(find.text(vi.consentDecline));
      await tester.pumpAndSettle();
      expect(find.text(vi.consentDeclineMessage), findsOneWidget);
      await tester.tap(find.text(vi.consentReview));
      await tester.pumpAndSettle();
      expect(find.text(vi.consentTitle), findsOneWidget);

      // Back hệ thống khi lớp phủ hiện: không pop màn dưới, mở xác nhận từ chối.
      expect(await ConsentBackGuard.instance.didPopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(vi.consentDeclineMessage), findsOneWidget);
      expect(await ConsentBackGuard.instance.didPopRoute(), isTrue);
      await tester.pumpAndSettle();

      await tester.tapOnText(find.textRange.ofSubstring(vi.consentPrivacyLink));
      await tester.pumpAndSettle();
      expect(find.text(personalDataConsentDocument.title), findsOneWidget);
      await tester.tap(find.text(vi.close));
      await tester.pumpAndSettle();
      expect(find.text(vi.consentTitle), findsOneWidget);
    });
  });
}

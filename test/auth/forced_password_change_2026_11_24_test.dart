import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/auth/data/services/auth_api_service.dart';
import 'package:vthm_dms/features/auth/data/services/password_change_service.dart';
import 'package:vthm_dms/features/auth/domain/entities/user_entity.dart';
import 'package:vthm_dms/features/auth/domain/repositories/auth_repository.dart';
import 'package:vthm_dms/features/auth/domain/usecases/auth_usecases.dart';
import 'package:vthm_dms/features/auth/presentation/states/auth_state.dart';
import 'package:vthm_dms/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:vthm_dms/features/auth/presentation/widgets/forced_password_change_overlay.dart';

/// #25831: quản trị đặt lại mật khẩu ⇒ máy chủ trả 403 PASSWORD_CHANGE_REQUIRED cho mọi API trừ auth/* và đổi mật khẩu.
/// Lỗi cũ: app không có màn đổi mật khẩu — đăng nhập được nhưng mọi màn 403; mở lại app thì bị đăng xuất với câu "chưa
/// được cấp quyền dùng app".

const _pcrBody = {
  'success': false,
  'code': 'PASSWORD_CHANGE_REQUIRED',
  'message': 'Bạn phải đổi mật khẩu trước khi tiếp tục.',
};

class _Repo implements AuthRepository {
  Object? appAccessError;
  bool loggedOut = false;
  int refreshCalls = 0;
  bool mustChange = false;
  bool appAccess = true;

  UserEntity get _user => UserEntity(
        id: '7',
        username: 'TEST001',
        email: '',
        employeeCode: 'TEST001',
        displayName: 'Thử',
        jobTitle: '',
        avatarUrl: '',
        mustChangePassword: mustChange,
      );

  @override
  Future<bool> checkAppAccess() async {
    if (appAccessError != null) throw appAccessError!;
    return appAccess;
  }

  @override
  Future<UserEntity?> checkAuthStatus() async => _user;

  @override
  Future<UserEntity> login({required String username, required String password, required bool rememberMe}) async =>
      _user;

  @override
  Future<void> logout({bool keepAccountDrafts = false}) async => loggedOut = true;

  @override
  Future<String?> refreshToken() async {
    refreshCalls++;
    return 'new-access';
  }

  @override
  Future<String?> getSavedUsername() async => null;
}

AuthViewModel _vm(_Repo repo) => AuthViewModel(
      loginUseCase: LoginUseCase(repo),
      checkAuthUseCase: CheckAuthUseCase(repo),
      checkAppAccessUseCase: CheckAppAccessUseCase(repo),
      logoutUseCase: LogoutUseCase(repo),
      getSavedUsernameUseCase: GetSavedUsernameUseCase(repo),
    );

typedef _Handler = (int, Object) Function(RequestOptions o);

class _Adapter implements HttpClientAdapter {
  final _Handler handler;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    final r = handler(o);
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _Online extends ConnectivityNotifier {
  _Online({bool online = true}) {
    state = ConnectivityState(isOnline: online);
  }

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void handleNetworkDisconnection() {}
}

class _Api extends Fake implements AuthApiService {
  Map<String, dynamic>? sent;
  Object? error;

  @override
  Future<void> changeOwnPassword({required String currentPassword, required String newPassword, String? refreshToken}) async {
    if (error != null) throw error!;
    sent = {'current': currentPassword, 'new': newPassword, 'refresh': refreshToken};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Interceptor', () {
    test('403 PASSWORD_CHANGE_REQUIRED ⇒ báo hook một lần, lỗi trả nguyên mã cho nơi gọi', () async {
      var goi = 0;
      AuthInterceptor.onPasswordChangeRequired = () => goi++;
      addTearDown(() => AuthInterceptor.onPasswordChangeRequired = null);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = _Adapter((_) => (403, _pcrBody));
      dio.interceptors.add(AuthInterceptor(dio));

      await expectLater(
        ApiClient(dio).get('/dms/routes/mine'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', passwordChangeRequiredCode)),
      );
      expect(goi, 1);
    });

    test('403 quyền thường ⇒ KHÔNG báo buộc đổi mật khẩu', () async {
      var goi = 0;
      AuthInterceptor.onPasswordChangeRequired = () => goi++;
      addTearDown(() => AuthInterceptor.onPasswordChangeRequired = null);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((_) => (403, {'success': false, 'message': 'Không có quyền'}));
      dio.interceptors.add(AuthInterceptor(dio));

      await expectLater(ApiClient(dio).get('/dms/routes/mine'), throwsA(isA<AppException>()));
      expect(goi, 0);
    });
  });

  group('AuthViewModel', () {
    test('khôi phục phiên gặp 403 PASSWORD_CHANGE_REQUIRED ⇒ vào app với cờ bật, KHÔNG đăng xuất', () async {
      final repo = _Repo()
        ..appAccessError = const ServerException('Bạn phải đổi mật khẩu', 403, passwordChangeRequiredCode);
      final vm = _vm(repo);

      final ok = await vm.checkAuth();

      expect(ok, isTrue, reason: 'lỗi cũ: 403 ⇒ đăng xuất, báo "chưa được cấp quyền dùng app"');
      expect(repo.loggedOut, isFalse);
      expect(vm.state.status, AuthStatus.authenticated);
      expect(vm.state.user!.mustChangePassword, isTrue);
    });

    test('cờ cũ lưu trên máy nhưng máy chủ trả lời được (đã đổi ở web) ⇒ hạ cờ', () async {
      final repo = _Repo()..mustChange = true;
      final vm = _vm(repo);

      await vm.checkAuth();

      expect(vm.state.user!.mustChangePassword, isFalse);
    });

    test('máy chủ không xác nhận quyền (trang Wi-Fi 200 ⇒ false) ⇒ GIỮ cờ', () async {
      final repo = _Repo()
        ..mustChange = true
        ..appAccess = false;
      final vm = _vm(repo);

      await vm.checkAuth();

      expect(vm.state.user!.mustChangePassword, isTrue);
    });

    test('đang dùng app thì gặp 403 ⇒ requirePasswordChange bật cờ; chưa đăng nhập thì bỏ qua', () async {
      final repo = _Repo();
      final vm = _vm(repo);
      vm.requirePasswordChange();
      expect(vm.state.user, isNull);

      await vm.login('TEST001', 'x');
      vm.requirePasswordChange();
      expect(vm.state.user!.mustChangePassword, isTrue);
      expect(vm.state.status, AuthStatus.authenticated);
    });
  });

  group('PasswordChangeService', () {
    test('gửi kèm refresh token (giữ phiên này), làm mới token, hạ cờ trong hồ sơ lưu máy', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyRefreshToken: 'rt-1',
        AppConstants.keyUserData: jsonEncode({'id': '7', 'must_change_password': true}),
      });
      final api = _Api();
      final repo = _Repo();

      await PasswordChangeService(api, repo).change(currentPassword: 'cu', newPassword: 'moi12345');

      expect(api.sent, {'current': 'cu', 'new': 'moi12345', 'refresh': 'rt-1'});
      expect(repo.refreshCalls, 1);
      final saved = jsonDecode((await SharedPreferences.getInstance()).getString(AppConstants.keyUserData)!);
      expect(saved['must_change_password'], isFalse);
    });

    test('sai mật khẩu hiện tại (422) ⇒ ném lỗi, cờ giữ nguyên', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyUserData: jsonEncode({'id': '7', 'must_change_password': true}),
      });
      final api = _Api()..error = const ServerException('Mật khẩu hiện tại không đúng', 422, 'VALIDATION_ERROR');

      await expectLater(
          PasswordChangeService(api, _Repo()).change(currentPassword: 'sai', newPassword: 'moi12345'),
          throwsA(isA<AppException>()));
      final saved = jsonDecode((await SharedPreferences.getInstance()).getString(AppConstants.keyUserData)!);
      expect(saved['must_change_password'], isTrue);
    });
  });

  group('Hàng đợi đồng bộ', () {
    test('403 PASSWORD_CHANGE_REQUIRED ⇒ mục giữ pending, không dead, lô dừng', () async {
      final db = AppDatabase(NativeDatabase.memory(), 1);
      final adapter = _Adapter((_) => (403, _pcrBody));
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
        connectivityProvider.overrideWith((ref) => _Online()),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      Future<int> enqueue(String uuid) => db.enqueue(SyncQueueEntriesCompanion.insert(
            entity: 'declaration',
            op: 'create',
            clientUuid: uuid,
            payload: '{"reason_id":1,"lat":1,"lng":1}',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            createdElapsed: SystemClock.nowMonotonicMs,
            bootId: SystemClock.bootId,
          ));
      final a = await enqueue('d1');
      final b = await enqueue('d2');

      final result = await container.read(syncServiceProvider).syncQueue(force: true);

      Future<String> state(int id) async =>
          (await (db.select(db.syncQueueEntries)..where((t) => t.id.equals(id))).getSingle()).state;
      expect(result.deadErrors, isEmpty, reason: 'lỗi cũ: 403 ⇒ dead, chỉ xoá được — mất khai báo');
      expect(await state(a), 'pending');
      expect(await state(b), 'pending');
      expect(adapter.calls.length, 1, reason: 'mục sau cũng sẽ 403 — không gửi tiếp');
    });
  });

  group('Lớp phủ đổi mật khẩu bắt buộc', () {
    Future<AuthViewModel> pump(WidgetTester tester, {required bool mustChange, bool online = true}) async {
      final repo = _Repo()..mustChange = mustChange;
      final vm = _vm(repo);
      await vm.login('TEST001', 'x');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith((ref) => vm),
          connectivityProvider.overrideWith((ref) => _Online(online: online)),
        ],
        child: MaterialApp(
          builder: (context, child) => ForcedPasswordChangeOverlay(child: child!),
          home: const Scaffold(body: Text('Trang chủ')),
        ),
      ));
      return vm;
    }

    testWidgets('cờ bật ⇒ che app bằng màn đổi mật khẩu; nhập lại lệch ⇒ báo, không gọi máy chủ', (tester) async {
      await pump(tester, mustChange: true);

      expect(find.byKey(const Key('forced_pw_submit')), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const Key('forced_pw_current')), matching: find.byType(TextField)), 'cu');
      await tester.enterText(find.descendant(of: find.byKey(const Key('forced_pw_new')), matching: find.byType(TextField)), 'moi12345');
      await tester.enterText(find.descendant(of: find.byKey(const Key('forced_pw_confirm')), matching: find.byType(TextField)), 'khac');
      await tester.tap(find.byKey(const Key('forced_pw_submit')));
      await tester.pump();

      expect(find.text('Mật khẩu nhập lại không khớp mật khẩu mới.'), findsOneWidget);
    });

    testWidgets('mất mạng ⇒ KHÔNG che (việc ngoại tuyến vẫn làm được; đổi mật khẩu cần mạng)', (tester) async {
      await pump(tester, mustChange: true, online: false);
      expect(find.byKey(const Key('forced_pw_submit')), findsNothing);
      expect(find.text('Trang chủ'), findsOneWidget);
    });

    testWidgets('đang hiện mà mạng chập chờn ⇒ KHÔNG gỡ lớp phủ (đang gõ / đang gửi)', (tester) async {
      await pump(tester, mustChange: true);
      expect(find.byKey(const Key('forced_pw_submit')), findsOneWidget);
      final conn = ProviderScope.containerOf(tester.element(find.text('Trang chủ'))).read(connectivityProvider.notifier);
      conn.state = const ConnectivityState(isOnline: false);
      await tester.pump();
      expect(find.byKey(const Key('forced_pw_submit')), findsOneWidget);
    });

    testWidgets('cờ tắt ⇒ không che; 403 giữa chừng (requirePasswordChange) ⇒ hiện lớp phủ', (tester) async {
      final vm = await pump(tester, mustChange: false);
      expect(find.byKey(const Key('forced_pw_submit')), findsNothing);

      vm.requirePasswordChange();
      await tester.pump();

      expect(find.byKey(const Key('forced_pw_submit')), findsOneWidget);
    });
  });
}

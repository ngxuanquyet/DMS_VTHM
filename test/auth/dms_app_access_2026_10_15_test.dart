import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/auth/domain/entities/user_entity.dart';
import 'package:vthm_dms/features/auth/domain/repositories/auth_repository.dart';
import 'package:vthm_dms/features/auth/domain/usecases/auth_usecases.dart';
import 'package:vthm_dms/features/auth/presentation/states/auth_state.dart';
import 'package:vthm_dms/features/auth/presentation/viewmodels/auth_view_model.dart';

class MockAuthRepository implements AuthRepository {
  bool checkAppAccessShouldThrow403 = false;
  bool checkAppAccessShouldThrowNetwork = false;
  bool loginShouldThrowForbidden = false;
  String? forbiddenMessage;

  @override
  Future<bool> checkAppAccess() async {
    if (checkAppAccessShouldThrow403) {
      throw DmsAppForbiddenException(
        forbiddenMessage ?? 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
      );
    }
    if (checkAppAccessShouldThrowNetwork) {
      throw const NetworkException();
    }
    return true;
  }

  @override
  Future<UserEntity?> checkAuthStatus() async {
    return const UserEntity(
      id: '1',
      username: 'VTG920',
      displayName: 'Nguyễn Văn A',
      employeeCode: 'VTG920',
      jobTitle: 'Nhân viên thị trường',
      avatarUrl: '',
      email: 'a@vthm.vn',
    );
  }

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    if (loginShouldThrowForbidden) {
      throw DmsAppForbiddenException(
        forbiddenMessage ?? 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
      );
    }
    return const UserEntity(
      id: '1',
      username: 'VTG920',
      displayName: 'Nguyễn Văn A',
      employeeCode: 'VTG920',
      jobTitle: 'Nhân viên thị trường',
      avatarUrl: '',
      email: 'a@vthm.vn',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String?> refreshToken() async => 'mock_new_token';

  @override
  Future<String?> getSavedUsername() async => 'VTG920';
}

void main() {
  group('SPEC 2026-10-15 DMS App Access Tests', () {
    test('1. AppConstants defines X-Client: dms-app header', () {
      expect(AppConstants.headerClientKey, equals('X-Client'));
      expect(AppConstants.headerClientValue, equals('dms-app'));
    });

    test('2. DmsAppForbiddenException has status 403 and code DMS_APP_FORBIDDEN', () {
      const ex = DmsAppForbiddenException();
      expect(ex.statusCode, equals(403));
      expect(ex.code, equals('DMS_APP_FORBIDDEN'));
      expect(ex.message, contains('Tài khoản chưa được cấp quyền dùng app DMS'));
    });

    test('3. Login with 403 DMS_APP_FORBIDDEN sets exact server message without claiming wrong password', () async {
      final mockRepo = MockAuthRepository()..loginShouldThrowForbidden = true;
      final vm = AuthViewModel(
        loginUseCase: LoginUseCase(mockRepo),
        checkAuthUseCase: CheckAuthUseCase(mockRepo),
        checkAppAccessUseCase: CheckAppAccessUseCase(mockRepo),
        logoutUseCase: LogoutUseCase(mockRepo),
        getSavedUsernameUseCase: GetSavedUsernameUseCase(mockRepo),
      );

      final success = await vm.login('VTG999', 'correct_password');
      expect(success, isFalse);
      expect(vm.state.status, equals(AuthStatus.error));
      expect(vm.state.errorMessage, equals('Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.'));
      expect(vm.state.errorMessage, isNot(contains('Sai mật khẩu')));
    });

    test('4. checkAuth logs out and sets error message if checkAppAccess throws 403 forbidden', () async {
      final mockRepo = MockAuthRepository()..checkAppAccessShouldThrow403 = true;
      final vm = AuthViewModel(
        loginUseCase: LoginUseCase(mockRepo),
        checkAuthUseCase: CheckAuthUseCase(mockRepo),
        checkAppAccessUseCase: CheckAppAccessUseCase(mockRepo),
        logoutUseCase: LogoutUseCase(mockRepo),
        getSavedUsernameUseCase: GetSavedUsernameUseCase(mockRepo),
      );

      final isAuth = await vm.checkAuth();
      expect(isAuth, isFalse);
      expect(vm.state.status, equals(AuthStatus.error));
      expect(vm.state.errorMessage, contains('Tài khoản chưa được cấp quyền dùng app DMS'));
    });

    test('5. checkAuth retains session when offline or network error occurs during checkAppAccess', () async {
      final mockRepo = MockAuthRepository()..checkAppAccessShouldThrowNetwork = true;
      final vm = AuthViewModel(
        loginUseCase: LoginUseCase(mockRepo),
        checkAuthUseCase: CheckAuthUseCase(mockRepo),
        checkAppAccessUseCase: CheckAppAccessUseCase(mockRepo),
        logoutUseCase: LogoutUseCase(mockRepo),
        getSavedUsernameUseCase: GetSavedUsernameUseCase(mockRepo),
      );

      final isAuth = await vm.checkAuth();
      expect(isAuth, isTrue);
      expect(vm.state.status, equals(AuthStatus.authenticated));
      expect(vm.state.user?.username, equals('VTG920'));
    });

    test('6. AuthInterceptor attaches X-Client: dms-app to /auth/login request and omits Authorization header', () async {
      final dio = Dio();
      final interceptor = AuthInterceptor(dio);
      final options = RequestOptions(
        path: '/auth/login',
        headers: {},
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers[AppConstants.headerClientKey], equals('dms-app'));
      expect(options.headers['Authorization'], isNull);
    });

    test('7. AuthInterceptor attaches X-Client: dms-app to /auth/refresh request', () async {
      final dio = Dio();
      final interceptor = AuthInterceptor(dio);
      final options = RequestOptions(
        path: '/auth/refresh',
        headers: {},
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.headers[AppConstants.headerClientKey], equals('dms-app'));
      expect(options.headers['Authorization'], isNull);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/services/error_tracker_service.dart';
import '../../../../core/services/fcm_push_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/auth_api_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../../home/presentation/viewmodels/home_view_model.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';
import '../../../profile/presentation/viewmodels/personal_info_view_model.dart';
import '../../../travel/presentation/viewmodels/travel_view_model.dart';
import '../../../daily_report/presentation/viewmodels/visit_report_view_model.dart';
import '../../../position_declaration/presentation/viewmodels/position_declaration_view_model.dart';
import '../../../home/presentation/widgets/attendance_punch_reminder.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../customer/presentation/viewmodels/customer_view_model.dart';
import '../../../customer/presentation/viewmodels/rejected_read_status_notifier.dart';
import '../states/auth_state.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.read(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authApiServiceProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.read(authRepositoryProvider));
});

final checkAuthUseCaseProvider = Provider<CheckAuthUseCase>((ref) {
  return CheckAuthUseCase(ref.read(authRepositoryProvider));
});

final checkAppAccessUseCaseProvider = Provider<CheckAppAccessUseCase>((ref) {
  return CheckAppAccessUseCase(ref.read(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.read(authRepositoryProvider));
});

final getSavedUsernameUseCaseProvider = Provider<GetSavedUsernameUseCase>((ref) {
  return GetSavedUsernameUseCase(ref.read(authRepositoryProvider));
});

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(
    loginUseCase: ref.read(loginUseCaseProvider),
    checkAuthUseCase: ref.read(checkAuthUseCaseProvider),
    checkAppAccessUseCase: ref.read(checkAppAccessUseCaseProvider),
    logoutUseCase: ref.read(logoutUseCaseProvider),
    getSavedUsernameUseCase: ref.read(getSavedUsernameUseCaseProvider),
    ref: ref,
  );
});

class AuthViewModel extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final CheckAuthUseCase checkAuthUseCase;
  final CheckAppAccessUseCase checkAppAccessUseCase;
  final LogoutUseCase logoutUseCase;
  final GetSavedUsernameUseCase getSavedUsernameUseCase;
  final Ref? ref;

  AuthViewModel({
    required this.loginUseCase,
    required this.checkAuthUseCase,
    required this.checkAppAccessUseCase,
    required this.logoutUseCase,
    required this.getSavedUsernameUseCase,
    this.ref,
  }) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final savedUser = await getSavedUsernameUseCase();
    if (savedUser != null && savedUser.isNotEmpty) {
      state = state.copyWith(savedUsername: savedUser, rememberMe: true);
    }
  }

  Future<bool> checkAuth() async {
    try {
      final user = await checkAuthUseCase();
      if (user != null) {
        // Kiểm tra quyền app-access (§2.3 spec 15/10/2026: GET /dms/app-access)
        try {
          await checkAppAccessUseCase();
        } on DmsAppForbiddenException catch (e) {
          // Bị thu quyền -> Thu hồi phiên, đẩy về màn đăng nhập kèm thông báo
          await logout();
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message,
            errorCode: e.displayErrorCode ?? 'DMS_APP_FORBIDDEN (403)',
          );
          return false;
        } on ServerException catch (e) {
          if (e.statusCode == 403 || e.code == 'DMS_APP_FORBIDDEN') {
            await logout();
            state = state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
              errorCode: e.displayErrorCode ?? 'DMS_APP_FORBIDDEN (403)',
            );
            return false;
          }
        } catch (_) {
          // Mất mạng / ngoại tuyến: Không đẩy ra ngoài, giữ phiên để app chạy offline
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
        // Tải luật thị trường khi khởi động phiên đăng nhập (§1.3)
        ref?.read(mobileRulesProvider.notifier).fetchRules();
        try {
          ref?.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
        } catch (_) {}
        // Đăng ký FCM device token cho tài khoản (§3.1 API-THONG-BAO-DAY-MOBILE-2026-10-19)
        try {
          ref?.read(fcmPushServiceProvider).setCurrentUserId(user.id.toString());
          ref?.read(fcmPushServiceProvider).registerDeviceToken();
        } catch (_) {}
        return true;
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    }
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  Future<bool> login(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Vui lòng điền đầy đủ tài khoản và mật khẩu',
        errorCode: 'VALIDATION_ERROR',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null, errorCode: null);

    try {
      final user = await loginUseCase(
        username: username.trim(),
        password: password.trim(),
        rememberMe: state.rememberMe,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
      ref?.read(syncServiceProvider).resume();
      _resetPerUserState();
      // Gọi GET /dms/mobile-rules lúc đăng nhập, lưu bản sao trong máy (§1.3)
      ref?.read(mobileRulesProvider.notifier).fetchRules();
      // Gửi bù lỗi app gặp trước khi đăng nhập (máy chủ chỉ nhận lỗi của người đã đăng nhập).
      ErrorTrackerService.instance.flushPending().ignore();
      try {
        ref?.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
      } catch (_) {}
      // Đăng ký FCM device token cho tài khoản (§3.1 API-THONG-BAO-DAY-MOBILE-2026-10-19)
      try {
        ref?.read(fcmPushServiceProvider).setCurrentUserId(user.id.toString());
        ref?.read(fcmPushServiceProvider).registerDeviceToken();
      } catch (_) {}
      return true;
    } catch (e) {
      String msg;
      String? errCode;
      if (e is AppException) {
        msg = e.message;
        errCode = e.displayErrorCode;
      } else {
        msg = e.toString()
            .replaceAll('AppException: ', '')
            .replaceAll('ServerException: ', '')
            .replaceAll('DmsAppForbiddenException: ', '');
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
        errorCode: errCode,
      );
      return false;
    }
  }

  /// [requireCleared] (đăng xuất chủ động từ màn Hồ sơ, người dùng đã được cảnh báo mục lỗi sẽ mất): xoá hàng đợi +
  /// điểm bán + ảnh offline TRƯỚC; còn mục chờ gửi (vừa phát sinh sau lúc màn hình kiểm) thì KHÔNG đăng xuất, trả false
  /// — trừ khi [discardPending] (người dùng đã xác nhận bỏ dữ liệu chưa gửi).
  /// Đăng xuất cưỡng bức (bị thu quyền app) KHÔNG đụng hàng đợi — không ai được hỏi, không xoá mất dữ liệu.
  Future<bool> logout({bool requireCleared = false, bool discardPending = false}) async {
    // Lỗi DB thì ném lên cho màn hình báo — đừng nuốt thành "còn mục chờ gửi" (người dùng đồng bộ lại mãi vô ích).
    if (requireCleared) {
      final db = ref?.read(appDatabaseProvider);
      if (db == null) return false;
      final sync = ref!.read(syncServiceProvider);
      // Bỏ dữ liệu chưa gửi: dừng bộ đồng bộ và chờ lô đang gửi xong TRƯỚC khi xoá — kẻo lô đã nạp vào RAM gửi tiếp
      // bằng token người sau. Dừng tới lần đăng nhập kế ([login] gọi resume).
      try {
        if (discardPending && !await sync.pauseAndDrain()) {
          sync.resume();
          return false;
        }
        if (!await db.clearUserData(discardPending: discardPending)) {
          sync.resume();
          return false;
        }
      } catch (_) {
        sync.resume();
        rethrow;
      }
    }

    // Nhả máy push (POST /notification/device-token/release) trước khi xóa access token (§3.2)
    try {
      ref?.read(fcmPushServiceProvider).setCurrentUserId(null);
      await ref?.read(fcmPushServiceProvider).unregisterDeviceToken();
    } catch (_) {}

    try {
      await logoutUseCase();
    } catch (_) {
      // Vẫn còn đăng nhập ⇒ đừng để bộ đồng bộ dừng mãi (đã pause ở nhánh bỏ dữ liệu chưa gửi).
      ref?.read(syncServiceProvider).resume();
      rethrow;
    }

    ref?.read(syncServiceProvider).clearRecentDeadErrors();
    AttendancePunchReminder.reset();

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
    );
    return true;
  }

  /// ViewModel giữ state suốt vòng đời app mang dữ liệu của người đăng nhập trước — lời chào, chấm công, hồ sơ,
  /// công tác, báo cáo, check-in, khai báo vị trí, điểm bán + nhãn đã đọc điểm bán bị từ chối. Bỏ hết khi có người đăng nhập; gọi SAU khi state
  /// đã authenticated để bản dựng lại tải bằng token mới.
  void _resetPerUserState() {
    final r = ref;
    if (r == null) return;
    r.invalidate(homeViewModelProvider);
    r.invalidate(profileViewModelProvider);
    r.invalidate(personalInfoViewModelProvider);
    r.invalidate(travelViewModelProvider);
    r.invalidate(visitReportViewModelProvider);
    r.invalidate(checkInViewModelProvider);
    r.invalidate(positionDeclarationViewModelProvider);
    // autoDispose nhưng bị unreadRejectedCountProvider (không autoDispose) giữ sống mãi.
    r.invalidate(customerViewModelProvider);
    r.invalidate(rejectedReadStatusProvider);
  }
}

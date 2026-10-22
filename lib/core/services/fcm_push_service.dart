// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import 'app_notification_service.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/customer/presentation/viewmodels/customer_view_model.dart';
import '../../features/notifications/presentation/viewmodels/notifications_view_model.dart';
import '../../firebase_options.dart';

/// Background message handler chạy khi app đã tắt hoặc ở chế độ nền.
/// Bắt buộc là hàm top-level và gắn @pragma('vm:entry-point') theo chuẩn Firebase Messaging.
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FcmBackground] Nhận push khi app ở nền/tắt: id=${message.messageId}, type=${message.data['type']}');
  // Khối notification đã được hệ điều hành Android tự hiển thị trên khay hệ thống với channel_id = vthm_alerts.
}

final fcmPushServiceProvider = Provider<FcmPushService>((ref) {
  final service = FcmPushService();
  service.setRef(ref);
  return service;
});

/// Dịch vụ quản lý thông báo đẩy FCM (Chuẩn đặc tả API-THONG-BAO-DAY-MOBILE-2026-10-19)
class FcmPushService {
  static final FcmPushService _instance = FcmPushService._internal();
  factory FcmPushService() => _instance;
  FcmPushService._internal();

  Ref? _ref;
  String? _fcmToken;
  String? _cachedUserId;
  bool _isInitialized = false;

  static const String _prefsTokenKey = 'fcm_device_token_v1';
  static const String _prefsPendingReleaseKey = 'fcm_pending_release_token_v1';

  void setRef(Ref ref) {
    _ref = ref;
    try {
      final uid = ref.read(authViewModelProvider).user?.id;
      if (uid != null) {
        _cachedUserId = uid.toString();
      }
    } catch (_) {}
  }

  /// Cập nhật user ID đang hoạt động để kiểm tra data.uids tức thì
  void setCurrentUserId(String? id) {
    _cachedUserId = id;
  }

  /// Khởi tạo Firebase Messaging và thiết lập lắng nghe 3 trạng thái của ứng dụng (§5.2)
  Future<void> init({Ref? ref}) async {
    if (ref != null) setRef(ref);
    if (_isInitialized) return;

    // Chỉ chạy FCM trên thiết bị Android hoặc iOS thực tế (tránh lỗi trên Desktop runner hoặc Unit Test)
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint('[FcmPushService] Bỏ qua FCM trên nền tảng: $defaultTargetPlatform');
      _isInitialized = true;
      return;
    }

    try {
      // 1. Khởi tạo Firebase App với cấu hình DefaultFirebaseOptions (hỗ trợ cả Android & iOS)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[FcmPushService] Firebase.initializeApp() với DefaultFirebaseOptions thành công');
      } catch (e) {
        debugPrint('[FcmPushService] Firebase.initializeApp() lỗi options, thử fallback: $e');
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
      }

      // 2. Thiết lập background handler
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);

      // 3. Xin quyền thông báo (Android 13+ / iOS) trước khi lấy token (§1)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FcmPushService] Quyền thông báo FCM: ${settings.authorizationStatus}');

      // Bật hiển thị thông báo đầy đủ khi app ở foreground (iOS & Android hỗ trợ)
      try {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      // Nạp cachedUserId từ SharedPreferences để sẵn sàng kiểm tra uids
      try {
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString(AppConstants.keyUserData);
        if (userData != null && userData.isNotEmpty) {
          final decoded = jsonDecode(userData) as Map<String, dynamic>;
          _cachedUserId = decoded['id']?.toString();
          debugPrint('[FcmPushService] Đã nạp cachedUserId ban đầu: $_cachedUserId');
        }
      } catch (_) {}

      // 4. Lấy token hiện tại và lưu trữ cục bộ
      try {
        // Trên iOS: cần đợi APNs token được cấp phát trước khi lấy FCM token
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            for (int i = 0; i < 6; i++) {
              await Future.delayed(const Duration(milliseconds: 500));
              apnsToken = await FirebaseMessaging.instance.getAPNSToken();
              if (apnsToken != null) break;
            }
          }
          debugPrint('[FcmPushService] iOS APNs Token: $apnsToken');
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          _fcmToken = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsTokenKey, token);
          debugPrint('[FcmPushService] FCM Token hiện tại: $token');
        }
      } catch (e) {
        debugPrint('[FcmPushService] Lấy FCM Token ban đầu lỗi: $e');
      }

      // 5. Lắng nghe sự kiện token refresh (§3.1)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FcmPushService] FCM Token được làm mới: $newToken');
        _fcmToken = newToken;
        registerDeviceToken(token: newToken);
      });

      // 6. Xử lý 3 trạng thái ứng dụng (§5.2):

      // (a) App đã TẮT (Terminated) được mở lên từ việc chạm vào thông báo
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FcmPushService] Khởi động từ push (Terminated): ${initialMessage.data}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          openFromPush(initialMessage);
        });
      }

      // (b) App đang ở NỀN (Background) được mở lên từ khay hệ thống
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FcmPushService] Mở app từ push (Background): ${message.data}');
        openFromPush(message);
      });

      // (c) App đang MỞ (Foreground): Android không tự hiện tin, app tự hiện banner và xử lý
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FcmPushService] Nhận push khi app đang mở (Foreground): ${message.data}');
        _handleForegroundMessage(message);
      });

      // 7. Giải phóng token tồn đọng nếu lần trước mất mạng (§3.3)
      _flushPendingRelease();

      _isInitialized = true;
      debugPrint('[FcmPushService] Khởi tạo hoàn tất');
    } catch (e) {
      debugPrint('[FcmPushService] Khởi tạo FCM lỗi: $e');
      _isInitialized = true;
    }
  }

  // ===========================================================================
  // 1. ĐĂNG KÝ VÀ NHẢ THIẾT BỊ (§3)
  // ===========================================================================

  /// Đăng ký thiết bị với server: POST /notification/device-token (§3.1)
  /// Bắt buộc: "platform": "android", "app": "dms" để kích hoạt cơ chế prefer_app = dms (§7)
  Future<void> registerDeviceToken({String? token}) async {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      final fcmToken = token ?? _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint('[FcmPushService] Không có FCM Token để đăng ký');
        return;
      }
      _fcmToken = fcmToken;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsTokenKey, fcmToken);

      final deviceName = _getDeviceName();
      final apiClient = _getApiClient();
      if (apiClient == null) {
        debugPrint('[FcmPushService] Chưa có ApiClient hoặc phiên đăng nhập để đăng ký token');
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      debugPrint('[FcmPushService] Gửi POST /notification/device-token (app=dms, platform=$platform)');
      final response = await apiClient.post(
        '/notification/device-token',
        data: {
          'token': fcmToken,
          'platform': platform,
          'app': 'dms',
          'device_name': deviceName,
        },
      );
      debugPrint('[FcmPushService] Đăng ký máy thành công: $response');
    } catch (e) {
      debugPrint('[FcmPushService] Đăng ký máy thất bại: $e');
    }
  }

  /// Đăng xuất chủ động: nhả máy qua POST /notification/device-token/release (§3.2, #23920).
  /// Gọi TRƯỚC khi xóa access token để tránh nhận tin của người cũ. Cửa cũ DELETE /notification/device-token
  /// sắp bị gỡ (#23634); cửa /release không cần phiên nên vẫn nhả được khi access token đã hết hạn.
  Future<void> unregisterDeviceToken() async {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    String? token;
    try {
      final prefs = await SharedPreferences.getInstance();
      token = _fcmToken ?? prefs.getString(_prefsTokenKey);
      if (token == null || token.trim().isEmpty) return;

      await _postRelease(token);
      debugPrint('[FcmPushService] Hủy đăng ký máy thành công');

      await prefs.remove(_prefsTokenKey);
      _fcmToken = null;
    } catch (e) {
      debugPrint('[FcmPushService] Hủy đăng ký máy lỗi (lưu vào pending release): $e');
      if (token != null && token.isNotEmpty) {
        await _savePendingRelease(token);
      }
    }
  }

  /// Mất phiên / Ngoại tuyến / Hết hạn: POST /notification/device-token/release (§3.3)
  /// Endpoint công khai (không cần Bearer token). Token FCM chính là bằng chứng xác thực.
  Future<void> releaseDeviceTokenPublic({String? token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenToRelease = token ?? _fcmToken ?? prefs.getString(_prefsTokenKey);
      if (tokenToRelease == null || tokenToRelease.trim().isEmpty) return;

      await _postRelease(tokenToRelease);
      debugPrint('[FcmPushService] Nhả máy qua cửa công khai /release thành công');

      await prefs.remove(_prefsTokenKey);
      await prefs.remove(_prefsPendingReleaseKey);
      _fcmToken = null;
    } catch (e) {
      debugPrint('[FcmPushService] Gửi /release thất bại: $e');
    }
  }

  /// Gọi cửa công khai POST /notification/device-token/release — ném lỗi để nơi gọi tự quyết lưu pending hay bỏ qua.
  Future<void> _postRelease(String token) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          AppConstants.headerClientKey: AppConstants.headerClientValue,
        },
      ),
    );

    debugPrint('[FcmPushService] Gửi POST /notification/device-token/release (Công khai)');
    await dio.post(
      '/notification/device-token/release',
      data: {'token': token},
    );
  }

  // ===========================================================================
  // 2. XỬ LÝ FOREGROUND & LƯỚI BẢO VỆ data.uids (§5.3)
  // ===========================================================================

  /// Kiểm tra tin có thuộc tài khoản đang đăng nhập hay không (§5.3)
  bool isForCurrentUser(RemoteMessage message) {
    final raw = message.data['uids']?.toString();
    if (raw == null || raw.trim().isEmpty) return true; // Tin cũ hoặc không có danh sách ⇒ Cho phép hiện

    final currentUid = _getCurrentUserId();
    // Nếu chưa xác định được currentUid (chưa nạp xong state hoặc user chưa login hoàn tất)
    // nhưng push được gửi tới device token của máy này, thì vẫn cho phép hiện để không làm mất tin của người dùng.
    if (currentUid == null || currentUid.trim().isEmpty) {
      debugPrint('[FcmPushService] Chưa xác định currentUid, cho phép hiển thị thông báo push tới máy này');
      return true;
    }

    final uids = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final isMatch = uids.contains(currentUid);
    if (!isMatch) {
      debugPrint('[FcmPushService] data.uids ($raw) không chứa currentUid ($currentUid) -> Bỏ qua');
    }
    return isMatch;
  }

  /// Xử lý tin khi app đang mở (Foreground)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // 1. Kiểm tra lưới an toàn uids: nếu không dành cho tài khoản hiện tại thì bỏ qua (§5.3)
    if (!isForCurrentUser(message)) {
      debugPrint('[FcmPushService] Bỏ qua tin push do không khớp uids người dùng hiện tại');
      return;
    }

    final notif = message.notification;
    final title = notif?.title ?? message.data['title']?.toString() ?? 'Thông báo VTHM';
    final body = notif?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString() ?? '';
    final type = message.data['type']?.toString() ?? 'system';
    final tag = message.data['tag']?.toString();

    // 2. Hiển thị thông báo trên khay hệ thống (Notification Tray) trên kênh vthm_alerts (§4)
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payloadJson = jsonEncode(message.data);

    await AppNotificationService().showFcmAlertNotification(
      id: notifId,
      title: title,
      body: body,
      payload: payloadJson,
      tag: tag,
    );

    // 4. Lưu vào in-app notification store để hiển thị trong màn Thông báo
    final resolvedRoutePath = type == 'crm.customer_rejected'
        ? '/customers/rejected'
        : message.data['link']?.toString();

    await AppNotificationService().sendNotification(
      id: notifId,
      type: type,
      title: title,
      message: body,
      category: 'work',
      routePath: resolvedRoutePath,
      showSystemTray: false, // Đã hiển thị qua showFcmAlertNotification ở trên
    );

    // 5. Làm mới dữ liệu liên quan (§6, §5.2)
    refreshAfterPush(message);
  }

  /// Làm mới dữ liệu liên quan tương ứng với loại tin push (§6, §5.2)
  void refreshAfterPush(RemoteMessage message) {
    final type = message.data['type']?.toString().trim();
    if (type == 'crm.customer_approved' || type == 'crm.customer_rejected') {
      debugPrint('[FcmPushService] Làm mới danh sách điểm bán /crm/customers/mine sau khi nhận push duyệt');
      try {
        _ref?.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
      } catch (_) {}
    }

    // Luôn invalidate số đếm thông báo chưa đọc
    try {
      _ref?.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
  }

  // ===========================================================================
  // 3. ĐIỀU HƯỚNG KHI BẤM VÀO THÔNG BÁO (§6)
  // ===========================================================================

  /// Mở màn hình tương ứng khi người dùng chạm vào push ở cả 3 trạng thái
  void openFromPush(RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[FcmPushService] rootNavigatorKey context null, không thể điều hướng');
      return;
    }

    // 1. Kiểm tra an toàn uids: nếu không thuộc tài khoản hiện tại thì về /home (§5.3)
    if (!isForCurrentUser(message)) {
      debugPrint('[FcmPushService] Push không dành cho tài khoản hiện tại, điều hướng về /home');
      context.go('/home');
      return;
    }

    final type = message.data['type']?.toString().trim() ?? '';
    final link = message.data['link']?.toString().trim();
    debugPrint('[FcmPushService] Điều hướng từ push: type=$type, link=$link');

    switch (type) {
      // 1. Nhắc ca làm việc (§6.1)
      case 'att.shift_remind_in':
      case 'att.shift_remind_out':
        context.push('/attendance');
        return;

      // 2. Điểm bán được duyệt (§6.1)
      case 'crm.customer_approved':
        final rawLink = link ?? '';
        final uri = Uri.tryParse(rawLink);
        final openParam = uri?.queryParameters['open'] ?? RegExp(r'[?&]open=(\d+)').firstMatch(rawLink)?.group(1);
        final openId = int.tryParse(openParam ?? '');

        if (openId != null && openId > 0) {
          debugPrint('[FcmPushService] Mở chi tiết điểm bán theo open=$openId');
          context.push('/crm/customers?open=$openId');
          // Làm mới danh sách để đồng bộ trạng thái mới nhất
          try {
            _ref?.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
          } catch (_) {}
          return;
        }
        context.push('/customers');
        return;

      // 3. Điểm bán bị từ chối duyệt: chuyển ngay đến màn hình RejectedCustomersScreen
      case 'crm.customer_rejected':
        debugPrint('[FcmPushService] Mở màn hình danh sách điểm bán bị từ chối /customers/rejected');
        context.push('/customers/rejected');
        try {
          _ref?.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        } catch (_) {}
        return;

      // 3. Các loại tin khác (§6.2)
      default:
        if (link != null && link.isNotEmpty) {
          if (link.startsWith('/crm/')) {
            context.push(link);
            return;
          }
          if (link.startsWith('http://') || link.startsWith('https://')) {
            launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            return;
          }
          final fullWebUrl = 'https://one.vthmgroup.vn${link.startsWith('/') ? '' : '/'}$link';
          launchUrl(Uri.parse(fullWebUrl), mode: LaunchMode.externalApplication);
          return;
        }
        // Fallback về màn hình thông báo
        context.push('/notifications');
        return;
    }
  }

  // ===========================================================================
  // 4. CÁC HÀM TIỆN ÍCH NỘI BỘ
  // ===========================================================================

  ApiClient? _getApiClient() {
    if (_ref != null) {
      try {
        return _ref!.read(apiClientProvider);
      } catch (_) {}
    }
    return null;
  }

  String? _getCurrentUserId() {
    // 1. Đọc từ Riverpod AuthState nếu có
    if (_ref != null) {
      try {
        final user = _ref!.read(authViewModelProvider).user;
        if (user != null) {
          final uid = user.id.toString();
          _cachedUserId = uid;
          return uid;
        }
      } catch (_) {}
    }

    // 2. Trả về cache đã nạp từ SharedPreferences hoặc lúc đăng nhập
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId;
    }

    return null;
  }

  String _getDeviceName() {
    try {
      if (Platform.isAndroid) {
        return 'Android (${Platform.operatingSystemVersion.split(' ').first})';
      } else if (Platform.isIOS) {
        return 'iOS (${Platform.operatingSystemVersion})';
      }
    } catch (_) {}
    return 'DMS Mobile Device';
  }

  Future<void> _savePendingRelease(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsPendingReleaseKey, token);
    } catch (_) {}
  }

  Future<void> _flushPendingRelease() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString(_prefsPendingReleaseKey);
      if (pendingToken != null && pendingToken.isNotEmpty) {
        debugPrint('[FcmPushService] Giải phóng pending release token: $pendingToken');
        await releaseDeviceTokenPublic(token: pendingToken);
      }
    } catch (_) {}
  }
}

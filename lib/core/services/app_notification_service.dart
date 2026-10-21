import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:go_router/go_router.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../router/app_router.dart';

final appNotificationServiceProvider = Provider<AppNotificationService>((ref) {
  final service = AppNotificationService();
  service.init();
  return service;
});

/// Dịch vụ thông báo toàn diện (Local Push Notifications & In-App Notification Store)
class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  FlutterLocalNotificationsPlugin? _localNotifications;
  bool _isInitialized = false;

  static const String _channelId = 'dms_vthm_notifications';
  static const String _channelName = 'Thông báo DMS VTHM';
  static const String _channelDesc =
      'Kênh nhận thông báo chấm công, lộ trình, cảnh báo và đồng bộ ngoại tuyến';
  static const String _alertChannelId = 'vthm_alerts';
  static const String _alertChannelName = 'Thông báo VTHM';
  static const String _alertChannelDesc =
      'Kênh cảnh báo và nhắc chấm công vào ca, ra ca';
  /// Id lịch nhắc ca hôm nay của bản app cũ — chỉ còn để huỷ ([cancelLegacyAttendanceReminders]).
  static const int legacyShiftRemindInTodayId = 2001;
  static const int legacyShiftRemindOutTodayId = 2002;
  static const String _prefsKey = 'local_notifications_store_v1';
  static const String _readIdsKey = 'local_notifications_read_ids_v1';
  static const String _throttlePrefix = 'notify_throttle_';

  /// Khởi tạo plugin thông báo cục bộ
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications?.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[NotificationService] Người dùng chạm thông báo: ${response.payload}');
          _handleNotificationTapPayload(response.payload);
        },
      );

      // Tạo notification channel trên Android
      final androidPlatform = _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        // Tạo notification channel vthm_alerts theo chuẩn Server §3.5
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            _alertChannelId,
            _alertChannelName,
            description: _alertChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        // Xin quyền thông báo trên Android 13+
        await androidPlatform.requestNotificationsPermission();
      }

      // Xin quyền thông báo trên iOS
      final iosPlatform = _localNotifications
          ?.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      try {
        tz.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
        } catch (_) {}
      } catch (_) {}

      _isInitialized = true;
      debugPrint('[NotificationService] Khởi tạo thành công');
    } catch (e) {
      _isInitialized = true;
    }
  }

  /// Xử lý điều hướng khi người dùng chạm vào thông báo (hỗ trợ FCM link `/crm/customers?open=<id>` hoặc `/crm/my-customers?open=<id>`)
  void _handleNotificationTapPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      String targetPath = payload.trim();
      bool isRejectedCustomer = false;

      if (targetPath == 'att.shift_remind_in' || targetPath == 'att.shift_remind_out') {
        targetPath = '/attendance';
      } else if (targetPath == 'crm.customer_rejected' || targetPath == '/customers/rejected') {
        targetPath = '/customers/rejected';
        isRejectedCustomer = true;
      } else if (targetPath.startsWith('{') && targetPath.endsWith('}')) {
        try {
          final decoded = jsonDecode(targetPath) as Map<String, dynamic>;
          final type = decoded['type']?.toString();
          if (type == 'att.shift_remind_in' || type == 'att.shift_remind_out') {
            targetPath = '/attendance';
          } else if (type == 'crm.customer_rejected') {
            targetPath = '/customers/rejected';
            isRejectedCustomer = true;
          } else {
            final rawData = decoded['data'] is Map<String, dynamic> ? decoded['data'] as Map<String, dynamic> : null;
            final link = decoded['link'] ?? decoded['routePath'] ?? decoded['url'] ?? rawData?['link'];
            if (link != null) targetPath = link.toString().trim();
          }
        } catch (_) {}
      }

      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        if (isRejectedCustomer || targetPath == '/customers/rejected') {
          context.push('/customers/rejected');
          return;
        }

        // Cập nhật 19/10/2026: Ưu tiên đọc tham số open=<id> từ link bất kể vai trò/tiền tố đường dẫn
        final uri = Uri.tryParse(targetPath);
        final openParam = uri?.queryParameters['open'] ?? RegExp(r'[?&]open=(\d+)').firstMatch(targetPath)?.group(1);
        if (openParam != null && int.tryParse(openParam) != null) {
          context.push('/crm/customers?open=$openParam');
          return;
        }

        if (targetPath.startsWith('/')) {
          context.push(targetPath);
        } else if (targetPath.contains('/crm/customers') || targetPath.contains('/crm/my-customers')) {
          final idx = targetPath.indexOf('/crm/');
          context.push(targetPath.substring(idx));
        } else if (targetPath.contains('/attendance')) {
          context.push('/attendance');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Lỗi điều hướng từ thông báo: $e');
    }
  }

  // ===========================================================================
  // 1. IN-APP PERSISTENT STORAGE
  // ===========================================================================

  /// Lấy toàn bộ thông báo đã lưu
  Future<NotificationDataEntity> getSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = await getReadNotificationIds();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return const NotificationDataEntity(today: [], earlier: []);
      }
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final model = NotificationDataModel.fromJson(decoded);
      final rawEntity = model.toEntity();

      // Đồng bộ trạng thái đã đọc từ readIds
      final todayWithRead = rawEntity.today.map((e) => e.copyWith(
        isRead: e.isRead || readIds.contains(e.id),
      )).toList();
      final earlierWithRead = rawEntity.earlier.map((e) => e.copyWith(
        isRead: e.isRead || readIds.contains(e.id),
      )).toList();

      return NotificationDataEntity(today: todayWithRead, earlier: earlierWithRead);
    } catch (e) {
      debugPrint('[NotificationService] Lỗi đọc thông báo đã lưu: $e');
      return const NotificationDataEntity(today: [], earlier: []);
    }
  }

  /// Lấy danh sách ID các thông báo đã đọc
  Future<Set<String>> getReadNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_readIdsKey)?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  /// Thêm 1 thông báo mới vào bộ nhớ cục bộ
  Future<void> _saveNotification(NotificationEntity item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getSavedNotifications();
      final readIds = await getReadNotificationIds();

      // Kiểm tra trùng lặp ID hoặc nội dung gần nhất
      final exists = current.today.any((e) => e.id == item.id) ||
          current.earlier.any((e) => e.id == item.id);
      if (exists) return;

      final itemWithRead = item.copyWith(
        isRead: item.isRead || readIds.contains(item.id),
      );

      final updatedToday = [itemWithRead, ...current.today];
      // Giới hạn tối đa 50 thông báo gần nhất
      final limitedToday = updatedToday.take(30).toList();
      final limitedEarlier = current.earlier.take(20).toList();

      final model = NotificationDataModel(
        today: limitedToday
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: e.isRead,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
        earlier: limitedEarlier
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: e.isRead,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
      );

      await prefs.setString(_prefsKey, jsonEncode(model.toJson()));
    } catch (e) {
      debugPrint('[NotificationService] Lỗi lưu thông báo cục bộ: $e');
    }
  }

  /// Đánh dấu một thông báo cụ thể là đã đọc
  Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Lưu ID vào danh sách đã đọc để luôn duy trì trạng thái kể cả khi tải lại từ server
      final readIds = prefs.getStringList(_readIdsKey)?.toSet() ?? <String>{};
      readIds.add(id);
      await prefs.setStringList(_readIdsKey, readIds.toList());

      // 2. Cập nhật trong bộ nhớ local notifications store
      final current = await getSavedNotifications();
      final updatedToday = current.today.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList();
      final updatedEarlier = current.earlier.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList();

      final model = NotificationDataModel(
        today: updatedToday
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: e.isRead,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
        earlier: updatedEarlier
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: e.isRead,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
      );

      await prefs.setString(_prefsKey, jsonEncode(model.toJson()));
    } catch (e) {
      debugPrint('[NotificationService] Lỗi cập nhật đã đọc theo ID $id: $e');
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getSavedNotifications();

      final readIds = prefs.getStringList(_readIdsKey)?.toSet() ?? <String>{};
      for (final e in current.today) {
        readIds.add(e.id);
      }
      for (final e in current.earlier) {
        readIds.add(e.id);
      }
      await prefs.setStringList(_readIdsKey, readIds.toList());

      final updatedToday = current.today.map((e) => e.copyWith(isRead: true)).toList();
      final updatedEarlier = current.earlier.map((e) => e.copyWith(isRead: true)).toList();

      final model = NotificationDataModel(
        today: updatedToday
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: true,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
        earlier: updatedEarlier
            .map((e) => NotificationModel(
                  id: e.id,
                  type: e.type,
                  title: e.title,
                  message: e.message,
                  timeAgo: e.timeAgo,
                  isRead: true,
                  category: e.category,
                  routePath: e.routePath,
                  createdAt: e.createdAt,
                ))
            .toList(),
      );

      await prefs.setString(_prefsKey, jsonEncode(model.toJson()));
    } catch (e) {
      debugPrint('[NotificationService] Lỗi cập nhật đã đọc: $e');
    }
  }

  /// Đếm số thông báo chưa đọc
  Future<int> getUnreadCount() async {
    final data = await getSavedNotifications();
    final countToday = data.today.where((e) => !e.isRead).length;
    final countEarlier = data.earlier.where((e) => !e.isRead).length;
    return countToday + countEarlier;
  }

  // ===========================================================================
  // 2. DISPATCH NOTIFICATION (SYSTEM TRAY + IN-APP PERSISTENCE)
  // ===========================================================================

  /// Gửi thông báo đến khay hệ thống (nếu có) và lưu vào danh sách In-App
  Future<void> sendNotification({
    required int id,
    required String title,
    required String message,
    required String type,
    String category = 'work',
    String? routePath,
    bool showSystemTray = true,
  }) async {
    final now = DateTime.now();
    final entity = NotificationEntity(
      id: '${type}_${now.millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      timeAgo: 'Vừa xong',
      isRead: false,
      category: category,
      routePath: routePath,
      createdAt: now,
    );

    // 1. Lưu vào In-App Store
    await _saveNotification(entity);

    // 2. Hiển thị thông báo trên khay hệ thống (Android / iOS)
    if (showSystemTray && _localNotifications != null) {
      try {
        const androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _localNotifications?.show(
          id: id,
          title: title,
          body: message,
          notificationDetails: details,
          payload: routePath,
        );
      } catch (e) {
        debugPrint('[NotificationService] Không thể hiển thị notification khay hệ thống: $e');
      }
    }
  }

  /// Hiển thị thông báo trên kênh cao cấp vthm_alerts theo chuẩn Server (§4 API-THONG-BAO-DAY-MOBILE-2026-10-19)
  Future<void> showFcmAlertNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? tag,
  }) async {
    if (_localNotifications == null) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        tag: tag,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _localNotifications?.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Lỗi hiển thị FCM banner: $e');
    }
  }

  /// Gửi thông báo thử nghiệm để kiểm tra hoạt động của hệ thống
  Future<void> sendTestNotification() async {
    await sendNotification(
      id: 999,
      title: 'Kiểm tra thông báo DMS VTHM',
      message: 'Hệ thống thông báo hoạt động tốt! Bạn sẽ nhận được thông báo nhắc chấm công Vào ca (07:50) và Ra ca (17:00).',
      type: 'test_notification',
      category: 'system',
      routePath: '/home',
    );
  }

  /// Lên lịch thông báo thử nghiệm sau [seconds] giây để người dùng kiểm tra khi tắt app.
  /// Người dùng bấm nút, sau đó có thể thoát hẳn ứng dụng (vuốt tắt app) và khóa màn hình
  /// để kiểm tra xem hệ thống Android & iOS có tự động đánh thức và nổ chuông hay không.
  Future<DateTime> scheduleTestNotificationAfterSeconds({int seconds = 10}) async {
    if (_localNotifications == null) {
      await init();
    }
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(Duration(seconds: seconds));

    final scheduleMode = await _resolveAndroidScheduleMode();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications?.zonedSchedule(
      id: 998,
      title: '🔔 Thử nghiệm thông báo khi tắt app!',
      body: 'Thông báo nền DMS VTHM hoạt động thành công! Lịch nhắc Vào ca (07:50) & Ra ca (17:00) sẽ tự động đổ chuông đúng giờ.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
      payload: '/home',
    );

    debugPrint('[NotificationService] Đã lên lịch thông báo thử nghiệm sau $seconds giây tại $scheduledDate');
    return scheduledDate;
  }

  // ===========================================================================
  // 3. THROTTLING & SPAM PROTECTION
  // ===========================================================================

  Future<bool> _shouldThrottle(String key, Duration minInterval) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('$_throttlePrefix$key');
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (lastMs != null && (nowMs - lastMs) < minInterval.inMilliseconds) {
        return true;
      }
      await prefs.setInt('$_throttlePrefix$key', nowMs);
      return false;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // 4. CÁC NGHIỆP VỤ THÔNG BÁO CỤ THỂ (8 LOẠI YÊU CẦU)
  // ===========================================================================

  /// 2. Nhắc lộ trình đầu ngày
  Future<void> notifyRouteBriefing({
    required int totalDealers,
    required String routeName,
  }) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final throttled = await _shouldThrottle('route_brief_$todayStr', const Duration(hours: 12));
    if (throttled) return;

    await sendNotification(
      id: 102,
      title: 'Lộ trình hôm nay',
      message: 'Hôm nay bạn có $totalDealers điểm bán cần viếng thăm trên tuyến "$routeName". Chúc bạn một ngày làm việc hiệu quả!',
      type: 'route_briefing',
      category: 'work',
      routePath: '/routes',
    );
  }

  /// 3. Cảnh báo tiến độ tuyến trong ngày
  Future<void> notifyRouteProgress({
    required int completed,
    required int total,
    required String period, // 'Trưa' hoặc 'Chiều'
  }) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final throttled = await _shouldThrottle('progress_${period}_$todayStr', const Duration(hours: 3));
    if (throttled) return;

    final percent = total > 0 ? (completed / total * 100).toInt() : 0;
    final remaining = total - completed;

    await sendNotification(
      id: period == 'Trưa' ? 103 : 104,
      title: 'Cảnh báo tiến độ tuyến ($period)',
      message: 'Bạn đã hoàn thành $completed/$total điểm bán ($percent%). Còn $remaining điểm chưa ghé, hãy tăng tốc để kịp tiến độ!',
      type: 'route_progress',
      category: 'work',
      routePath: '/routes',
    );
  }

  /// 4. Cảnh báo quên Check-out
  Future<void> notifyForgotCheckout({
    required String dealerName,
    required int minutes,
    String? reason,
  }) async {
    final throttled = await _shouldThrottle(
      'forgot_co_${dealerName}_$minutes',
      const Duration(minutes: 20),
    );
    if (throttled) return;

    final msg = reason ??
        'Bạn đang check-in tại "$dealerName" hơn $minutes phút. Đừng quên hoàn thành biểu mẫu và bấm Kết thúc viếng thăm!';

    await sendNotification(
      id: 105,
      title: 'Cảnh báo quên Check-out',
      message: msg,
      type: 'forgot_checkout',
      category: 'work',
      routePath: '/routes',
    );
  }

  /// 5. Gợi ý thông minh theo vị trí
  Future<void> notifyNearbyDealerSuggestion({
    required String dealerName,
    required int distanceMeters,
    required String dealerId,
  }) async {
    final throttled = await _shouldThrottle(
      'nearby_$dealerId',
      const Duration(hours: 2),
    );
    if (throttled) return;

    await sendNotification(
      id: 106,
      title: 'Gợi ý điểm bán lân cận',
      message: 'Bạn đang ở gần "$dealerName" (cách ${distanceMeters}m) trên tuyến hôm nay. Ghé thăm ngay để tối ưu lộ trình di chuyển!',
      type: 'nearby_suggestion',
      category: 'work',
      routePath: '/routes',
    );
  }

  /// 5b. Cảnh báo rời khỏi điểm bán vượt bán kính cho phép
  static const int visitGeofenceAlertId = 108;

  Future<void> notifyVisitGeofenceExit({
    required String dealerName,
    required int distanceMeters,
    required int allowedRadiusMeters,
  }) async {
    final throttled = await _shouldThrottle(
      'geofence_exit_$dealerName',
      const Duration(minutes: 3),
    );
    if (throttled) return;

    final distText = distanceMeters < 1000
        ? '${distanceMeters}m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    final radiusText = allowedRadiusMeters < 1000
        ? '${allowedRadiusMeters}m'
        : '${(allowedRadiusMeters / 1000).toStringAsFixed(1)}km';

    await sendNotification(
      id: visitGeofenceAlertId,
      title: '⚠️ Cảnh báo rời xa điểm bán',
      message:
          'Bạn đang ở cách "$dealerName" $distText (vượt bán kính cho phép $radiusText). Vui lòng hoàn tất công việc và thực hiện Check-out!',
      type: 'visit_geofence_exit',
      category: 'work',
      routePath: '/routes',
    );
  }

  /// Hủy thông báo cảnh báo rời điểm bán khi đã check-out hoặc huỷ lượt
  Future<void> cancelVisitGeofenceExitNotification() async {
    try {
      await _localNotifications?.cancel(id: visitGeofenceAlertId);
    } catch (_) {}
  }

  /// 7. Thông báo đồng bộ ngoại tuyến thành công
  Future<void> notifyOfflineSyncSuccess({
    required int successCount,
    String? summaryText,
  }) async {
    if (successCount <= 0) return;
    final messageDetail = summaryText != null && summaryText.isNotEmpty
        ? summaryText
        : '$successCount tác vụ';
    await sendNotification(
      id: 108,
      title: 'Đồng bộ ngoại tuyến thành công',
      message: 'Đã gửi thành công $messageDetail lên hệ thống máy chủ.',
      type: 'sync_success',
      category: 'system',
      routePath: null,
    );
  }

  /// 8. Cảnh báo tồn đọng hàng đợi offline
  Future<void> notifyOfflineQueuePending({
    required int pendingCount,
    String? summaryText,
    String? reason,
  }) async {
    if (pendingCount <= 0) return;
    final throttled = await _shouldThrottle('queue_pending', const Duration(hours: 1));
    if (throttled) return;

    final detail = summaryText != null && summaryText.isNotEmpty
        ? summaryText
        : '$pendingCount bản ghi ngoại tuyến';

    final msg = reason ??
        'Bạn đang có $detail chưa được gửi lên máy chủ. Vui lòng kết nối mạng để đồng bộ tránh thất thoát dữ liệu!';

    await sendNotification(
      id: 109,
      title: 'Cảnh báo dữ liệu chưa đồng bộ',
      message: msg,
      type: 'offline_queue_warning',
      category: 'system',
      routePath: null,
    );
  }

  /// Tổng hợp kiểm tra và tự động kích hoạt các nhắc nhở theo khung giờ trong ngày (tuyến, hàng đợi ngoại tuyến).
  ///
  /// Nhắc CHẤM CÔNG không còn ở đây: từ 21/10/2026 (anh Quyết chốt) chỉ dùng push của server — cron nhắc theo đúng ca
  /// thật của từng người (`att.shift_remind_in` / `att.shift_remind_out`). Nhắc cục bộ giờ cứng 7:50/17:00 lệch ca thật và
  /// nhắc trùng với push.
  Future<void> checkDailyReminders({
    int? totalDealers,
    int? completedDealers,
    String? routeName,
    int? pendingSyncCount,
  }) async {
    final now = DateTime.now();
    final hour = now.hour;

    // 1. Nhắc Lộ trình đầu ngày: 08:00 - 11:00 nếu có tuyến và điểm bán
    if (hour >= 8 && hour < 11 && (totalDealers ?? 0) > 0) {
      await notifyRouteBriefing(
        totalDealers: totalDealers!,
        routeName: routeName ?? 'Tuyến hôm nay',
      );
    }

    // 2. Cảnh báo tiến độ tuyến trong ngày:
    // - Khung trưa: 11:15 - 12:30
    if (hour >= 11 && hour < 13 && (totalDealers ?? 0) > 0) {
      final total = totalDealers!;
      final completed = completedDealers ?? 0;
      if (completed < total) {
        await notifyRouteProgress(
          completed: completed,
          total: total,
          period: 'Trưa',
        );
      }
    }
    // - Khung chiều: 15:00 - 16:30
    if (hour >= 15 && hour < 17 && (totalDealers ?? 0) > 0) {
      final total = totalDealers!;
      final completed = completedDealers ?? 0;
      if (completed < total) {
        await notifyRouteProgress(
          completed: completed,
          total: total,
          period: 'Chiều',
        );
      }
    }

    // 3. Cảnh báo tồn đọng hàng đợi offline:
    if ((pendingSyncCount ?? 0) > 0 && hour >= 16) {
      await notifyOfflineQueuePending(pendingCount: pendingSyncCount!);
    }
  }

  // ===========================================================================
  // 5. LÊN LỊCH VỚI HỆ ĐIỀU HÀNH
  // ===========================================================================

  /// Xác định chế độ báo thức tối ưu nhất trên Android (ưu tiên exactAlarm nếu được cấp phép)
  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    try {
      final androidPlatform = _localNotifications
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final canExact = await androidPlatform.canScheduleExactNotifications();
        if (canExact == true) {
          return AndroidScheduleMode.exactAllowWhileIdle;
        }
      }
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Huỷ mọi lịch nhắc CHẤM CÔNG cục bộ mà bản app cũ đã đặt với hệ điều hành (gọi mỗi lần khởi động).
  ///
  /// 🔴 Gỡ code đặt lịch là CHƯA đủ: lịch `zonedSchedule` lặp hằng tuần (`DateTimeComponents.dayOfWeekAndTime`) nằm trong
  /// hệ điều hành và vẫn kêu sau khi cập nhật app. Dải id là của bản cũ: 101/107 (nhắc tức thời), 1011–1016 (vào ca 7:50
  /// T2–T7), 1071–1076 (ra ca 17:00 T2–T7), 2001/2002 (theo ca hôm nay), 20000–39999 (theo ca từng ngày).
  Future<void> cancelLegacyAttendanceReminders() async {
    if (_localNotifications == null) return;
    try {
      final ids = <int>{101, 107, legacyShiftRemindInTodayId, legacyShiftRemindOutTodayId};
      for (int day = DateTime.monday; day <= DateTime.saturday; day++) {
        ids
          ..add(1010 + day)
          ..add(1070 + day);
      }
      final pending = await _localNotifications!.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id >= 20000 && req.id < 40000) ids.add(req.id);
      }
      for (final id in ids) {
        await _localNotifications?.cancel(id: id);
      }
      debugPrint('[NotificationService] Đã huỷ ${ids.length} lịch nhắc chấm công cục bộ của bản cũ');
    } catch (e) {
      debugPrint('[NotificationService] Lỗi huỷ lịch nhắc chấm công cục bộ cũ: $e');
    }
  }
}

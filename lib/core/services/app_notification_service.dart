import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:go_router/go_router.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../../features/attendance/domain/entities/attendance_entity.dart';
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
  static const int shiftRemindInTodayId = 2001;
  static const int shiftRemindOutTodayId = 2002;
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

  /// Tự động kiểm tra trạng thái chấm công hôm nay từ bộ nhớ cache hoặc SharedPreferences
  Future<bool> checkHasCheckedInToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final userId = prefs.getString('auth_user_id') ?? prefs.getString('user_id');
      final attHistoryKey = (userId != null && userId.isNotEmpty)
          ? 'dms_attendance_history_cache_v2_$userId'
          : 'dms_attendance_history_cache_v2';
      final cachedJson = prefs.getString(attHistoryKey) ??
          prefs.getString('dms_attendance_history_cache_v2') ??
          prefs.getString('att_mobile_history_cache');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        return list.any((item) => (item['punch_at']?.toString() ?? '').startsWith(todayStr));
      }
    } catch (_) {}
    return false;
  }

  Future<bool> checkHasCheckedOutToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final userId = prefs.getString('auth_user_id') ?? prefs.getString('user_id');
      final attHistoryKey = (userId != null && userId.isNotEmpty)
          ? 'dms_attendance_history_cache_v2_$userId'
          : 'dms_attendance_history_cache_v2';
      final cachedJson = prefs.getString(attHistoryKey) ??
          prefs.getString('dms_attendance_history_cache_v2') ??
          prefs.getString('att_mobile_history_cache');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        final todayPunches = list.where((item) => (item['punch_at']?.toString() ?? '').startsWith(todayStr)).toList();
        final hasOutPunch = todayPunches.any((item) =>
            item['direction']?.toString() == 'out' ||
            item['direction_label']?.toString() == 'Ra');
        return hasOutPunch || todayPunches.length >= 2;
      }
    } catch (_) {}
    return false;
  }

  /// 1. Nhắc Chấm công Vào ca buổi sáng (Ca 8h, Thứ 2 - Thứ 7)
  Future<void> notifyAttendanceCheckinReminder({bool? isLate}) async {
    final now = DateTime.now();
    if (now.weekday == DateTime.sunday) return; // Không nhắc Chủ nhật

    final todayStr = now.toIso8601String().substring(0, 10);
    final isLateTime = isLate ?? (now.hour > 8 || (now.hour == 8 && now.minute > 5));
    final throttleKey = isLateTime ? 'att_in_late_$todayStr' : 'att_in_$todayStr';
    final throttled = await _shouldThrottle(throttleKey, const Duration(hours: 2));
    if (throttled) return;

    final title = isLateTime ? 'Cảnh báo chưa chấm công vào ca' : 'Nhắc chấm công vào ca';
    final message = isLateTime
        ? 'Bạn chưa chấm công Vào ca hôm nay (giờ vào ca: 08:00). Hãy chấm công ngay để ghi nhận công làm việc!'
        : 'Sắp đến giờ vào ca (08:00). Đừng quên chấm công Vào ca để ghi nhận công hôm nay!';

    await sendNotification(
      id: 101,
      title: title,
      message: message,
      type: 'attendance_checkin',
      category: 'work',
      routePath: '/attendance',
    );
  }

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

  /// 6. Nhắc Chấm công Ra ca cuối ngày (Ca tan 17h, Thứ 2 - Thứ 7)
  Future<void> notifyAttendanceCheckoutReminder({bool? isOverdue}) async {
    final now = DateTime.now();
    if (now.weekday == DateTime.sunday) return; // Không nhắc Chủ nhật

    final todayStr = now.toIso8601String().substring(0, 10);
    final isOverdueTime = isOverdue ?? (now.hour > 17 || (now.hour == 17 && now.minute >= 15));
    final throttleKey = isOverdueTime ? 'att_out_overdue_$todayStr' : 'att_out_$todayStr';
    final throttled = await _shouldThrottle(throttleKey, const Duration(hours: 2));
    if (throttled) return;

    final title = isOverdueTime ? 'Cảnh báo chưa chấm công ra ca' : 'Nhắc chấm công ra ca';
    final message = isOverdueTime
        ? 'Đã quá giờ tan ca (17:00). Bạn chưa chấm công Ra ca hôm nay, hãy bấm Ra ca để chốt công!'
        : 'Đã đến giờ tan ca (17:00). Đừng quên chấm công Ra ca để ghi nhận đầy đủ công hôm nay nhé!';

    await sendNotification(
      id: 107,
      title: title,
      message: message,
      type: 'attendance_checkout',
      category: 'work',
      routePath: '/attendance',
    );
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

  /// Tổng hợp kiểm tra và tự động kích hoạt các nhắc nhở theo khung giờ trong ngày
  /// Ca làm việc: 08:00 - 17:00 từ Thứ 2 đến Thứ 7 (Chủ nhật nghỉ)
  Future<void> checkDailyReminders({
    bool? hasCheckedInToday,
    bool? hasCheckedOutToday,
    int? totalDealers,
    int? completedDealers,
    String? routeName,
    int? pendingSyncCount,
  }) async {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final isWorkingDay = now.weekday != DateTime.sunday; // Thứ 2 đến Thứ 7 (1..6)

    final checkedIn = hasCheckedInToday ?? await checkHasCheckedInToday();
    final checkedOut = hasCheckedOutToday ?? await checkHasCheckedOutToday();

    // 1. Nhắc Chấm công Vào ca buổi sáng: Khung giờ 07:00 - 12:00 (Thứ 2 đến Thứ 7)
    // Nếu trong buổi sáng chưa vào ca, dù mở app lúc 07:45 hay 09:30, 10:15 ĐỀU nhắc!
    if (isWorkingDay && hour >= 7 && hour < 12) {
      if (!checkedIn) {
        await notifyAttendanceCheckinReminder(isLate: hour >= 8);
      }
    }

    // 2. Nhắc Lộ trình đầu ngày: 08:00 - 11:00 nếu có tuyến và điểm bán
    if (hour >= 8 && hour < 11 && (totalDealers ?? 0) > 0) {
      await notifyRouteBriefing(
        totalDealers: totalDealers!,
        routeName: routeName ?? 'Tuyến hôm nay',
      );
    }

    // 3. Cảnh báo tiến độ tuyến trong ngày:
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

    // 6. Nhắc Chấm công Ra ca cuối ngày: Khung giờ 16:45 - 20:30 (Thứ 2 đến Thứ 7)
    if (isWorkingDay && (hour >= 16 && (hour > 16 || minute >= 45)) && hour < 21) {
      if (checkedIn && !checkedOut) {
        await notifyAttendanceCheckoutReminder(isOverdue: hour > 17 || (hour == 17 && minute >= 15));
      }
    }

    // 8. Cảnh báo tồn đọng hàng đợi offline:
    if ((pendingSyncCount ?? 0) > 0 && hour >= 16) {
      await notifyOfflineQueuePending(pendingCount: pendingSyncCount!);
    }

    // 9. Đồng bộ lịch hẹn với Hệ điều hành (Bảo đảm TẮT HẲN APP vẫn nổ chuông theo ca 8h-17h T2-T7)
    await setupDefaultWeeklySchedules(
      hasCheckedInToday: checkedIn,
      hasCheckedOutToday: checkedOut,
    );
  }

  // ===========================================================================
  // 5. LÊN LỊCH VỚI HỆ ĐIỀU HÀNH KHI TẮT APP (OS ALARM SCHEDULING - CA 8H - 17H T2-T7)
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

  void _ensureTimezone() {
    try {
      tz.local;
    } catch (_) {
      try {
        tz.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
        } catch (_) {
          tz.setLocalLocation(tz.UTC);
        }
      } catch (_) {}
    }
  }

  /// Tính thời điểm hẹn giờ gần nhất cho một thứ cụ thể trong tuần (T2 - T7)
  tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, int hour, int minute) {
    _ensureTimezone();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    int daysDifference = (weekday - scheduledDate.weekday) % 7;
    if (daysDifference < 0) {
      daysDifference += 7;
    }
    scheduledDate = scheduledDate.add(Duration(days: daysDifference));

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  /// Thiết lập trọn bộ lịch nhắc chấm công Vào ca (07:50) & Ra ca (17:00) từ T2 đến T7
  /// Đảm bảo dù tắt hẳn ứng dụng, hệ thống iOS và Android vẫn tự động phát thông báo định kỳ hàng tuần.
  Future<void> setupDefaultWeeklySchedules({
    bool? hasCheckedInToday,
    bool? hasCheckedOutToday,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      await init();
    }
    await scheduleDailyCheckinReminder(hour: 7, minute: 50, skipTodayIfCheckedIn: hasCheckedInToday);
    await scheduleDailyCheckoutReminder(hour: 17, minute: 0, skipTodayIfCheckedOut: hasCheckedOutToday);
  }

  /// Lên lịch nhắc chấm công Ra ca với Hệ điều hành lúc [hour]:[minute] (mặc định 17:00)
  /// Áp dụng từ Thứ 2 đến Thứ 7, hoàn toàn KHÔNG đặt lịch vào Chủ nhật.
  /// Dù người dùng có TẮT HẲN APP (killed/closed), hệ thống Android/iOS vẫn tự động phát thông báo.
  Future<void> scheduleDailyCheckoutReminder({
    int hour = 17,
    int minute = 0,
    bool? skipTodayIfCheckedOut,
  }) async {
    if (_localNotifications == null) return;
    try {
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

      final now = DateTime.now();
      final todayCheckedOut = skipTodayIfCheckedOut ?? await checkHasCheckedOutToday();

      // Lên lịch riêng cho 6 ngày làm việc từ Thứ 2 đến Thứ 7 (bỏ qua Chủ nhật)
      for (int day = DateTime.monday; day <= DateTime.saturday; day++) {
        var scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);

        // Nếu hôm nay là ngày này và đã chấm công ra ca rồi,
        // dời lịch sang tuần sau để không phát lại hôm nay nhưng KHÔNG hủy tuần tới
        if (day == now.weekday && todayCheckedOut) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }

        await _localNotifications?.zonedSchedule(
          id: 1070 + day, // 1071 (T2) .. 1076 (T7)
          title: 'Nhắc chấm công ra ca',
          body: 'Đã đến giờ tan ca ($hour:${minute.toString().padLeft(2, '0')}). Đừng quên chấm công Ra ca để ghi nhận đầy đủ công hôm nay nhé!',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '/attendance',
        );
      }
      debugPrint('[NotificationService] Đã lên lịch nhắc Ra ca lúc $hour:${minute.toString().padLeft(2, '0')} (T2-T7) với Hệ điều hành');
    } catch (e) {
      debugPrint('[NotificationService] Lỗi lên lịch nhắc Ra ca với Hệ điều hành: $e');
    }
  }

  /// Hủy lịch nhắc chấm công Ra ca (khi nhân viên đã chấm công ra ca)
  /// [todayOnly]: nếu true chỉ dời lịch của ngày hôm nay sang tuần sau (giữ nguyên các ngày khác)
  Future<void> cancelCheckoutReminder({bool todayOnly = true}) async {
    try {
      final now = DateTime.now();
      await _localNotifications?.cancel(id: 107);
      if (todayOnly && now.weekday != DateTime.sunday) {
        final scheduleMode = await _resolveAndroidScheduleMode();
        final nextWeekDate = _nextInstanceOfDayAndTime(now.weekday, 17, 0).add(const Duration(days: 7));
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
        await _localNotifications?.zonedSchedule(
          id: 1070 + now.weekday,
          title: 'Nhắc chấm công ra ca',
          body: 'Đã đến giờ tan ca (17:00). Đừng quên chấm công Ra ca để ghi nhận đầy đủ công hôm nay nhé!',
          scheduledDate: nextWeekDate,
          notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '/attendance',
        );
        debugPrint('[NotificationService] Đã dời lịch nhắc Ra ca hôm nay (Thứ ${now.weekday + 1}) sang tuần sau');
      } else {
        for (int day = DateTime.monday; day <= DateTime.saturday; day++) {
          await _localNotifications?.cancel(id: 1070 + day);
        }
        debugPrint('[NotificationService] Đã hủy toàn bộ lịch nhắc Ra ca T2-T7');
      }
    } catch (e) {
      debugPrint('[NotificationService] Lỗi hủy lịch nhắc Ra ca: $e');
    }
  }

  /// Lên lịch nhắc chấm công Vào ca với Hệ điều hành lúc [hour]:[minute] sáng (mặc định 07:50)
  /// Áp dụng từ Thứ 2 đến Thứ 7, hoàn toàn KHÔNG đặt lịch vào Chủ nhật.
  Future<void> scheduleDailyCheckinReminder({
    int hour = 7,
    int minute = 50,
    bool? skipTodayIfCheckedIn,
  }) async {
    if (_localNotifications == null) return;
    try {
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

      final now = DateTime.now();
      final todayCheckedIn = skipTodayIfCheckedIn ?? await checkHasCheckedInToday();

      // Lên lịch riêng cho 6 ngày làm việc từ Thứ 2 đến Thứ 7 (bỏ qua Chủ nhật)
      for (int day = DateTime.monday; day <= DateTime.saturday; day++) {
        var scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);

        // Nếu hôm nay là ngày này và đã chấm công vào ca rồi,
        // dời lịch sang tuần sau để không phát thông báo hôm nay nhưng KHÔNG hủy tuần tới
        if (day == now.weekday && todayCheckedIn) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }

        await _localNotifications?.zonedSchedule(
          id: 1010 + day, // 1011 (T2) .. 1016 (T7)
          title: 'Nhắc chấm công vào ca',
          body: 'Sắp đến giờ vào ca (08:00). Đừng quên chấm công Vào ca để ghi nhận công hôm nay!',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '/attendance',
        );
      }
      debugPrint('[NotificationService] Đã lên lịch nhắc Vào ca lúc $hour:${minute.toString().padLeft(2, '0')} (T2-T7) với Hệ điều hành');
    } catch (e) {
      debugPrint('[NotificationService] Lỗi lên lịch nhắc Vào ca với Hệ điều hành: $e');
    }
  }

  /// Hủy lịch nhắc chấm công Vào ca (khi nhân viên đã chấm công vào ca)
  Future<void> cancelCheckinReminder({bool todayOnly = true}) async {
    try {
      final now = DateTime.now();
      await _localNotifications?.cancel(id: 101);
      if (todayOnly && now.weekday != DateTime.sunday) {
        final scheduleMode = await _resolveAndroidScheduleMode();
        final nextWeekDate = _nextInstanceOfDayAndTime(now.weekday, 7, 50).add(const Duration(days: 7));
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
        await _localNotifications?.zonedSchedule(
          id: 1010 + now.weekday,
          title: 'Nhắc chấm công vào ca',
          body: 'Sắp đến giờ vào ca (08:00). Đừng quên chấm công Vào ca để ghi nhận công hôm nay!',
          scheduledDate: nextWeekDate,
          notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '/attendance',
        );
        debugPrint('[NotificationService] Đã dời lịch nhắc Vào ca hôm nay (Thứ ${now.weekday + 1}) sang tuần sau');
      } else {
        for (int day = DateTime.monday; day <= DateTime.saturday; day++) {
          await _localNotifications?.cancel(id: 1010 + day);
        }
        debugPrint('[NotificationService] Đã hủy toàn bộ lịch nhắc Vào ca T2-T7');
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 6. LÊN LỊCH NHẮC THEO CA LÀM VIỆC (§8 API-NHAC-CA-MOBILE-2026-10-17)
  // ===========================================================================

  /// Lên lịch nhắc chấm công vào ca và ra ca theo ca làm việc hôm nay (§8)
  /// Nhắc Vào ca: 15 phút trước giờ bắt đầu ca
  /// Hủy nhắc Vào ca nếu đã có lượt chấm công (punchCount > 0)
  /// Nhắc Ra ca: đúng giờ kết thúc ca (hỗ trợ ca qua đêm crossMidnight)
  Future<void> scheduleShiftReminders(
    AttendanceShiftScheduleEntity? schedule, {
    int punchCount = 0,
  }) async {
    if (schedule == null || schedule.shift == null || !schedule.isShift) {
      return;
    }
    await scheduleMultiDayShiftReminders([schedule], todayPunchCount: punchCount);
  }

  /// Lên lịch nhắc ca cho nhiều ngày (từ GET /attendance/mobile/shifts)
  Future<void> scheduleMultiDayShiftReminders(
    List<AttendanceShiftScheduleEntity> schedules, {
    int todayPunchCount = 0,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      await init();
    }
    if (_localNotifications == null) return;

    try {
      _ensureTimezone();
      final now = tz.TZDateTime.now(tz.local);
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final scheduleMode = await _resolveAndroidScheduleMode();

      const androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDesc,
        importance: Importance.high,
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

      for (final schedule in schedules) {
        if (!schedule.isShift || schedule.shift == null) continue;
        final shift = schedule.shift!;
        final workDateParsed = DateTime.tryParse(schedule.workDate);
        if (workDateParsed == null) continue;

        final isToday = schedule.workDate == todayStr;

        // Parse start_time (HH:mm or HH:mm:ss)
        final startParts = shift.startTime.split(':');
        if (startParts.length < 2) continue;
        final startH = int.tryParse(startParts[0]) ?? 8;
        final startM = int.tryParse(startParts[1]) ?? 0;

        // Parse end_time (HH:mm or HH:mm:ss)
        final endParts = shift.endTime.split(':');
        if (endParts.length < 2) continue;
        final endH = int.tryParse(endParts[0]) ?? 17;
        final endM = int.tryParse(endParts[1]) ?? 30;

        // 1. Nhắc vào ca: 15 phút trước giờ bắt đầu (§3.1)
        final shiftStart = tz.TZDateTime(
          tz.local,
          workDateParsed.year,
          workDateParsed.month,
          workDateParsed.day,
          startH,
          startM,
        );
        final remindInTime = shiftStart.subtract(const Duration(minutes: 15));

        // Generate distinct ID for this date
        final dateKey = (workDateParsed.year % 100) * 500 + workDateParsed.month * 32 + workDateParsed.day;
        final inId = 20000 + dateKey;
        final outId = 30000 + dateKey;

        // Nếu là hôm nay và đã có lượt chấm công (today.punch_count > 0) thì huỷ/không đặt nhắc vào ca
        if (isToday && todayPunchCount > 0) {
          await _localNotifications?.cancel(id: inId);
          await _localNotifications?.cancel(id: shiftRemindInTodayId);
        } else if (remindInTime.isAfter(now)) {
          final payloadIn = jsonEncode({
            'type': 'att.shift_remind_in',
            'link': '/attendance',
            'work_date': schedule.workDate,
            'shift_name': shift.name,
          });

          await _localNotifications?.zonedSchedule(
            id: isToday ? shiftRemindInTodayId : inId,
            title: 'Sắp vào ca: ${shift.name} bắt đầu lúc ${shift.startTime}',
            body: 'Ca ${shift.name} (${shift.startTime}–${shift.endTime}) của bạn sắp bắt đầu. Mở app để chấm công vào ca.',
            scheduledDate: remindInTime,
            notificationDetails: details,
            androidScheduleMode: scheduleMode,
            payload: payloadIn,
          );
          debugPrint('[NotificationService] Đã lên lịch nhắc vào ca lúc $remindInTime cho ngày ${schedule.workDate}');
        }

        // 2. Nhắc ra ca: đúng giờ kết thúc ca (hỗ trợ ca qua đêm crossMidnight §3.1 & §8)
        var endDate = workDateParsed;
        if (shift.crossMidnight) {
          endDate = endDate.add(const Duration(days: 1));
        }
        final remindOutTime = tz.TZDateTime(
          tz.local,
          endDate.year,
          endDate.month,
          endDate.day,
          endH,
          endM,
        );

        if (remindOutTime.isAfter(now)) {
          final payloadOut = jsonEncode({
            'type': 'att.shift_remind_out',
            'link': '/attendance',
            'work_date': schedule.workDate,
            'shift_name': shift.name,
          });

          await _localNotifications?.zonedSchedule(
            id: isToday ? shiftRemindOutTodayId : outId,
            title: 'Nhớ chấm công ra: ${shift.name} đã kết thúc lúc ${shift.endTime}',
            body: 'Ca ${shift.name} (${shift.startTime}–${shift.endTime}) của bạn đã kết thúc. Mở app để chấm công ra ca.',
            scheduledDate: remindOutTime,
            notificationDetails: details,
            androidScheduleMode: scheduleMode,
            payload: payloadOut,
          );
          debugPrint('[NotificationService] Đã lên lịch nhắc ra ca lúc $remindOutTime cho ngày ${schedule.workDate}');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Lỗi lên lịch nhắc ca làm việc: $e');
    }
  }

  /// Hủy nhắc vào ca (gọi ngay sau khi chấm công thành công)
  Future<void> cancelShiftInReminder() async {
    try {
      await _localNotifications?.cancel(id: shiftRemindInTodayId);
      final now = DateTime.now();
      final dateKey = (now.year % 100) * 500 + now.month * 32 + now.day;
      await _localNotifications?.cancel(id: 20000 + dateKey);
      await _localNotifications?.cancel(id: 101);
      debugPrint('[NotificationService] Đã hủy thông báo nhắc vào ca hôm nay');
    } catch (e) {
      debugPrint('[NotificationService] Lỗi hủy nhắc vào ca: $e');
    }
  }

  /// Hủy nhắc ra ca
  Future<void> cancelShiftOutReminder() async {
    try {
      await _localNotifications?.cancel(id: shiftRemindOutTodayId);
      final now = DateTime.now();
      final dateKey = (now.year % 100) * 500 + now.month * 32 + now.day;
      await _localNotifications?.cancel(id: 30000 + dateKey);
      await _localNotifications?.cancel(id: 107);
      debugPrint('[NotificationService] Đã hủy thông báo nhắc ra ca hôm nay');
    } catch (e) {
      debugPrint('[NotificationService] Lỗi hủy nhắc ra ca: $e');
    }
  }

  /// Hủy toàn bộ nhắc ca
  Future<void> cancelAllShiftReminders() async {
    try {
      await _localNotifications?.cancel(id: shiftRemindInTodayId);
      await _localNotifications?.cancel(id: shiftRemindOutTodayId);
    } catch (_) {}
  }
}

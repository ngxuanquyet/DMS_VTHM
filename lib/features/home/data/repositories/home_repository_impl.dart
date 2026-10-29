import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/account_key.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../services/home_api_service.dart';

class HomeRepositoryImpl implements HomeRepository {
  // ignore: unused_field
  final HomeApiService? _apiService;
  final AppDatabase? _database;

  static const String _visitsListKey = 'dms_visits_local_cache_v2';
  static const String _declarationsListKey = 'pos_declarations_local_list';

  HomeRepositoryImpl([this._apiService, this._database]);

  @override
  Future<DashboardEntity> getDashboardData() async {
    // Xây dựng DashboardEntity hoàn toàn từ dữ liệu thực tế của phiên đăng nhập và SQLite/Cache cục bộ.
    // Hệ thống backend DMS VTHM quản lý dữ liệu phân tán theo từng phân hệ (chấm công, viếng thăm, điểm bán)
    // và không cung cấp endpoint /dashboard riêng lẻ, tránh phát sinh request 404 không cần thiết khi mở ứng dụng.
    return _buildRealLocalDashboard();
  }

  /// Xây dựng toàn bộ Dashboard từ dữ liệu thực tế trên máy, không dùng bất kỳ mock data nào
  Future<DashboardEntity> _buildRealLocalDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Greeting thực tế từ UserModel lưu khi login
    String userName = 'Nhân viên';
    String role = 'Nhân viên kinh doanh';
    final userJson = prefs.getString(AppConstants.keyUserData);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(map);
        if (user.displayName.trim().isNotEmpty) {
          userName = user.displayName.trim();
        } else if (user.username.trim().isNotEmpty) {
          userName = user.username.trim();
        }
        if (user.jobTitle.trim().isNotEmpty) {
          role = user.jobTitle.trim();
        }
      } catch (_) {}
    }

    final currentDate = _formatVietnameseDate(now);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 2. Chấm công thực tế từ lịch sử module Attendance (SPEC 2026-10-05)
    bool isCheckedIn = false;
    String checkInTime = '--:--';
    String workDuration = '00:00';
    String statusLabel = 'Chưa vào ca';

    // CHỈ lượt chấm công thật của CHÍNH tài khoản này (bộ đệm lịch sử theo tài khoản). KHÔNG lấy giờ check-in viếng thăm
    // hay phiên "đang làm việc" của bản cũ làm giờ vào: hai nguồn đó làm thẻ hiện "đã chấm" khi người dùng chưa chấm
    // (và tắt luôn lời nhắc chấm công).
    final attHistoryKey = attendanceHistoryCacheKey(prefs);
    final attHistoryJson = attHistoryKey == null ? null : prefs.getString(attHistoryKey);
    final todayAttendancePunches = <Map<String, dynamic>>[];
    if (attHistoryJson != null && attHistoryJson.isNotEmpty) {
      try {
        final list = jsonDecode(attHistoryJson) as List<dynamic>;
        for (final item in list) {
          if (item is Map) {
            final punchAt = item['punch_at']?.toString() ?? '';
            DateTime? punchDt;
            try {
              final cleanIso = punchAt.replaceAll('+07', '+0700');
              punchDt = DateTime.parse(cleanIso).toLocal();
            } catch (_) {}
            final isToday = punchDt != null
                ? DateFormat('yyyy-MM-dd').format(punchDt) == todayStr
                : punchAt.startsWith(todayStr);
            if (isToday) {
              todayAttendancePunches.add(Map<String, dynamic>.from(item));
            }
          }
        }

        if (todayAttendancePunches.isNotEmpty) {
          todayAttendancePunches.sort((a, b) => (a['punch_at']?.toString() ?? '').compareTo(b['punch_at']?.toString() ?? ''));
          isCheckedIn = true;
          final firstPunchAt = todayAttendancePunches.first['punch_at']?.toString() ?? '';
          try {
            final cleanIso = firstPunchAt.replaceAll('+07', '+0700');
            final dt = DateTime.parse(cleanIso);
            checkInTime = DateFormat('HH:mm').format(dt.toLocal());
            final diff = now.difference(dt.toLocal());
            final hours = diff.inHours.toString().padLeft(2, '0');
            final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
            workDuration = '$hours:$mins';
          } catch (_) {
            if (firstPunchAt.length >= 16) {
              checkInTime = firstPunchAt.substring(11, 16);
            }
          }
          statusLabel = todayAttendancePunches.length > 1 ? 'Đã chấm (${todayAttendancePunches.length} lượt)' : 'Đang làm việc';
        }
      } catch (_) {}
    }

    // 3. Tuyến bán hàng và lượt viếng thăm thực tế trong ngày
    int completedCount = 0;
    int totalCount = 0;
    String routeName = 'Tất cả tuyến';
    String nextStop = '--';

    final visitsJson = prefs.getString(_visitsListKey);
    final todayVisits = <VisitEntity>[];
    if (visitsJson != null && visitsJson.isNotEmpty) {
      try {
        // Lịch sử 60 ngày (2–4 MB JSON): giải mã + lọc lượt HÔM NAY trong isolate riêng, chỉ mang về vài chục lượt —
        // giải mã cả khối trên luồng giao diện là khựng mỗi lần mở / làm mới Trang chủ.
        for (final v in await compute(_todayVisitsFrom, (visitsJson, todayStr))) {
          todayVisits.add(v);
          if (v.checkoutAt != null || v.visitResult != null) {
            completedCount++;
          }
        }
      } catch (_) {}
    }

    // Tính tổng số điểm bán thực tế từ SQLite
    if (_database != null) {
      try {
        // Đếm + lấy điểm kế tiếp bằng SQL — không nạp cả bảng 1.000+ điểm bán (đủ cột) chỉ để lấy `length` và một tên.
        totalCount = await _database.countLocalCustomers();
        if (totalCount > 0) {
          // Tìm điểm tiếp theo chưa ghé
          final visitedCustomerIds = todayVisits.map((v) => v.customerId).toSet();
          nextStop = await _database.firstLocalCustomerNameNotIn(visitedCustomerIds) ?? nextStop;
          if (nextStop == '--' && completedCount >= totalCount) {
            nextStop = 'Hoàn thành tất cả';
          }
        }
      } catch (_) {}
    }

    if (totalCount == 0 && completedCount > 0) {
      totalCount = completedCount;
    }

    final progressPercent = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    // 4. Biểu mẫu thực tế (lấy từ hàng đợi đồng bộ và dữ liệu hôm nay)
    int pendingFormCount = 0;
    int completedFormCount = 0;
    if (_database != null) {
      try {
        final queue = await _database.getPendingQueueEntries(limit: 100);
        pendingFormCount = queue.where((e) => e.entity == 'form_submission').length;
      } catch (_) {}
    }

    // 5. Dòng thời gian hoạt động thực tế trong ngày hôm nay
    final activities = <ActivityTimelineEntity>[];

    // Hoạt động chấm công thực tế
    for (int i = 0; i < todayAttendancePunches.length; i++) {
      final punch = todayAttendancePunches[i];
      final punchAt = punch['punch_at']?.toString() ?? '';
      String timeFormatted = '--:--';
      try {
        final cleanIso = punchAt.replaceAll('+07', '+0700');
        final dt = DateTime.parse(cleanIso);
        timeFormatted = DateFormat('HH:mm').format(dt.toLocal());
      } catch (_) {
        if (punchAt.length >= 16) {
          timeFormatted = punchAt.substring(11, 16);
        }
      }

      final direction = punch['direction']?.toString();
      String directionLabel = punch['direction_label']?.toString() ?? '';
      if (directionLabel.isEmpty) {
        directionLabel = (i == 0 || direction == 'in') ? 'Vào' : 'Ra';
      }

      final isOut = directionLabel == 'Ra' || direction == 'out';
      final geofenceName = punch['geofence_name']?.toString() ?? 'Địa bàn làm việc';
      final isOutside = punch['is_outside_geofence'] == true;
      final suffix = isOutside ? '(Ngoài vùng)' : '(Trong vùng)';

      final photoUrls = <String>[];
      final rawPhotos = punch['photos'];
      if (rawPhotos is List) {
        for (final p in rawPhotos) {
          if (p is Map) {
            final u = p['url']?.toString() ?? p['file_path']?.toString() ?? p['path']?.toString();
            if (u != null && u.isNotEmpty) photoUrls.add(u);
          } else if (p is String && p.isNotEmpty) {
            photoUrls.add(p);
          }
        }
      }

      final lat = (punch['lat'] is num) ? (punch['lat'] as num).toDouble() : null;
      final lng = (punch['lng'] is num) ? (punch['lng'] as num).toDouble() : null;

      activities.add(
        ActivityTimelineEntity(
          id: 'att_${punch['id'] ?? punch['client_uuid'] ?? i}',
          time: timeFormatted,
          title: 'Chấm công $directionLabel',
          highlight: geofenceName,
          suffix: suffix,
          isPrimary: !isOut,
          photos: photoUrls,
          lat: lat,
          lng: lng,
        ),
      );
    }

    // Hoạt động viếng thăm
    for (final v in todayVisits) {
      if (v.checkinAt != null) {
        activities.add(
          ActivityTimelineEntity(
            id: 'visit_in_${v.id}_${v.checkinAt!.millisecondsSinceEpoch}',
            time: DateFormat('HH:mm').format(v.checkinAt!.toLocal()),
            title: 'Check-in tại',
            highlight: v.customerName,
            suffix: v.isOnRoute ? '(Trong tuyến)' : '(Ngoài tuyến)',
            isPrimary: false,
            photos: v.photoUrls,
            lat: v.checkoutLat,
            lng: v.checkoutLng,
          ),
        );
      }
      if (v.checkoutAt != null) {
        activities.add(
          ActivityTimelineEntity(
            id: 'visit_out_${v.id}_${v.checkoutAt!.millisecondsSinceEpoch}',
            time: DateFormat('HH:mm').format(v.checkoutAt!.toLocal()),
            title: 'Hoàn thành viếng thăm',
            highlight: v.customerName,
            suffix: v.visitResult == 'closed' ? '(Đóng cửa)' : '(Mở cửa)',
            isPrimary: true,
            photos: v.photoUrls,
            lat: v.checkoutLat,
            lng: v.checkoutLng,
          ),
        );
      }
    }

    // Hoạt động khai báo vị trí thực tế
    final declJson = prefs.getString(_declarationsListKey);
    if (declJson != null && declJson.isNotEmpty) {
      try {
        final declList = jsonDecode(declJson) as List<dynamic>;
        for (final item in declList) {
          if (item is Map) {
            final ms = item['created_at_ms'] as int? ?? 0;
            if (ms > 0) {
              final dt = DateTime.fromMillisecondsSinceEpoch(ms);
              if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                final reason = item['reason_display']?.toString() ?? 'Khai báo vị trí';
                final addr = item['address']?.toString() ?? '';
                activities.add(
                  ActivityTimelineEntity(
                    id: 'pos_${item['client_uuid'] ?? ms}',
                    time: DateFormat('HH:mm').format(dt),
                    title: 'Khai báo vị trí',
                    highlight: reason,
                    suffix: addr.isNotEmpty ? 'tại $addr' : '',
                    isPrimary: false,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // Sắp xếp hoạt động thực tế theo thứ tự thời gian mới nhất lên đầu
    activities.sort((a, b) => b.time.compareTo(a.time));

    return DashboardEntity(
      greeting: DashboardGreetingEntity(
        userName: userName,
        role: role,
        currentDate: currentDate,
      ),
      attendance: DashboardAttendanceEntity(
        isCheckedIn: isCheckedIn,
        checkInTime: checkInTime,
        workDuration: workDuration,
        statusLabel: statusLabel,
      ),
      routeSummary: DashboardRouteEntity(
        routeName: routeName,
        completedCount: completedCount,
        totalCount: totalCount,
        progressPercent: progressPercent,
        nextStop: nextStop,
      ),
      formSummary: DashboardFormSummaryEntity(
        pendingCount: pendingFormCount,
        completedCount: completedFormCount,
        overdueCount: 0,
      ),
      recentActivities: activities,
    );
  }

  String _formatVietnameseDate(DateTime dt) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    final weekdayName = weekdays[dt.weekday - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$weekdayName, ngày $day/$month/$year';
  }
}

/// Lượt thăm của ngày `todayStr` (không tính lượt đã huỷ) trong JSON lịch sử — chạy trong `compute`.
List<VisitEntity> _todayVisitsFrom((String, String) args) {
  final (visitsJson, todayStr) = args;
  final out = <VisitEntity>[];
  for (final item in jsonDecode(visitsJson) as List<dynamic>) {
    if (item is Map) {
      final v = VisitEntity.fromJson(Map<String, dynamic>.from(item));
      final vDate = v.visitDate ?? (v.checkinAt != null ? DateFormat('yyyy-MM-dd').format(v.checkinAt!.toLocal()) : '');
      if (vDate == todayStr && !v.isCancelled) out.add(v);
    }
  }
  return out;
}

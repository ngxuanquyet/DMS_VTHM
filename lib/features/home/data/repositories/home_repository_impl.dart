import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../services/home_api_service.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeApiService _apiService;
  final AppDatabase? _database;

  static const String _activeVisitKey = 'dms_active_visit_session_v1';
  static const String _visitsListKey = 'dms_visits_local_cache_v2';
  static const String _attendanceStorageKey = 'dms_local_attendance_session_v1';
  static const String _declarationsListKey = 'pos_declarations_local_list';

  HomeRepositoryImpl(this._apiService, [this._database]);

  @override
  Future<DashboardEntity> getDashboardData() async {
    // 1. Thử gọi API nếu server backend có triển khai /dashboard
    try {
      final model = await _apiService.getDashboardData();
      return _enrichDashboard(model.toEntity());
    } catch (_) {
      // 2. Khi backend chưa có /dashboard hoặc thiết bị đang ngoại tuyến:
      // Xây dựng DashboardEntity hoàn toàn từ dữ liệu thực tế của phiên đăng nhập và SQLite/Cache cục bộ.
      return _buildRealLocalDashboard();
    }
  }

  /// Làm giàu dữ liệu dashboard từ thông tin người dùng và hoạt động thực tế
  Future<DashboardEntity> _enrichDashboard(DashboardEntity remote) async {
    final real = await _buildRealLocalDashboard();
    return DashboardEntity(
      greeting: real.greeting,
      attendance: real.attendance.isCheckedIn ? real.attendance : remote.attendance,
      routeSummary: real.routeSummary.totalCount > 0 ? real.routeSummary : remote.routeSummary,
      formSummary: remote.formSummary,
      recentActivities: real.recentActivities.isNotEmpty ? real.recentActivities : remote.recentActivities,
    );
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

    // 2a. Ưu tiên đọc từ cache lịch sử chấm công thật của mobile (att_mobile_history_cache)
    final attHistoryJson = prefs.getString('att_mobile_history_cache');
    if (attHistoryJson != null && attHistoryJson.isNotEmpty) {
      try {
        final list = jsonDecode(attHistoryJson) as List<dynamic>;
        final todayPunches = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map) {
            final punchAt = item['punch_at']?.toString() ?? '';
            if (punchAt.startsWith(todayStr)) {
              todayPunches.add(Map<String, dynamic>.from(item));
            }
          }
        }

        if (todayPunches.isNotEmpty) {
          todayPunches.sort((a, b) => (a['punch_at']?.toString() ?? '').compareTo(b['punch_at']?.toString() ?? ''));
          isCheckedIn = true;
          final firstPunchAt = todayPunches.first['punch_at']?.toString() ?? '';
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
          statusLabel = todayPunches.length > 1 ? 'Đã chấm (${todayPunches.length} lượt)' : 'Đang làm việc';
        }
      } catch (_) {}
    }

    // 2b. Kiểm tra nếu có lượt viếng thăm mở
    if (!isCheckedIn) {
      final activeVisitJson = prefs.getString(_activeVisitKey);
      if (activeVisitJson != null && activeVisitJson.isNotEmpty) {
        try {
          final vMap = jsonDecode(activeVisitJson) as Map<String, dynamic>;
          final activeVisit = VisitEntity.fromJson(vMap);
          if (activeVisit.isOpen) {
            isCheckedIn = true;
            if (activeVisit.checkinAt != null) {
              checkInTime = DateFormat('HH:mm').format(activeVisit.checkinAt!.toLocal());
              final diff = now.difference(activeVisit.checkinAt!.toLocal());
              final hours = diff.inHours.toString().padLeft(2, '0');
              final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
              workDuration = '$hours:$mins';
            }
            statusLabel = 'Đang viếng thăm';
          }
        } catch (_) {}
      }
    }

    // 2c. Kiểm tra nếu có phiên chấm công ca làm việc độc lập cũ
    if (!isCheckedIn) {
      final attSessionJson = prefs.getString(_attendanceStorageKey);
      if (attSessionJson != null && attSessionJson.isNotEmpty) {
        try {
          final attMap = jsonDecode(attSessionJson) as Map<String, dynamic>;
          if (attMap['is_working'] == true) {
            isCheckedIn = true;
            checkInTime = attMap['check_in_time']?.toString() ?? '--:--';
            final checkInIso = attMap['check_in_iso']?.toString();
            if (checkInIso != null) {
              final checkInDt = DateTime.parse(checkInIso);
              final diff = now.difference(checkInDt);
              final hours = diff.inHours.toString().padLeft(2, '0');
              final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
              workDuration = '$hours:$mins';
            }
            statusLabel = 'Đang làm việc';
          }
        } catch (_) {}
      }
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
        final list = jsonDecode(visitsJson) as List<dynamic>;
        for (final item in list) {
          if (item is Map) {
            final v = VisitEntity.fromJson(Map<String, dynamic>.from(item));
            final vDate = v.visitDate ?? (v.checkinAt != null ? DateFormat('yyyy-MM-dd').format(v.checkinAt!.toLocal()) : '');
            if (vDate == todayStr && !v.isCancelled) {
              todayVisits.add(v);
              if (v.checkoutAt != null || v.visitResult != null) {
                completedCount++;
              }
            }
          }
        }
      } catch (_) {}
    }

    // Tính tổng số điểm bán thực tế từ SQLite
    if (_database != null) {
      try {
        final localCustomers = await _database.getAllLocalCustomers();
        totalCount = localCustomers.length;
        if (localCustomers.isNotEmpty) {
          // Tìm điểm tiếp theo chưa ghé
          final visitedCustomerIds = todayVisits.map((v) => v.customerId).toSet();
          for (final c in localCustomers) {
            if (!visitedCustomerIds.contains(c.id)) {
              nextStop = c.name;
              break;
            }
          }
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

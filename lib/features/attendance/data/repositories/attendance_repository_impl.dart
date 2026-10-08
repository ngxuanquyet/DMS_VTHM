import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/utils/system_clock.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../models/attendance_model.dart';
import '../services/attendance_api_service.dart';

final attendanceApiServiceProvider = Provider<AttendanceApiService>((ref) {
  return AttendanceApiService(ref.read(apiClientProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    ref.read(attendanceApiServiceProvider),
    database: ref.read(appDatabaseProvider),
    ref: ref,
  );
});

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceApiService _apiService;
  final AppDatabase? database;
  final Ref? ref;

  static const String _configCacheKey = 'dms_attendance_config_cache_v2';
  static const String _historyCacheKey = 'dms_attendance_history_cache_v2';
  static const String _sessionKey = 'dms_local_attendance_session_v1';
  static const String _legacyHistoryKey = 'dms_local_attendance_history_v1';

  AttendanceDetailEntity? _cachedEntity;

  AttendanceRepositoryImpl(
    this._apiService, {
    this.database,
    this.ref,
  });

  bool get _isOnline => ref?.read(connectivityProvider).isOnline ?? true;

  String _getUserConfigCacheKey(SharedPreferences prefs) {
    try {
      final userJson = prefs.getString('vthm_user_data');
      if (userJson != null) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final uid = map['id'] ?? map['username'];
        if (uid != null) {
          return '${_configCacheKey}_$uid';
        }
      }
    } catch (_) {}
    return _configCacheKey;
  }

  // ===========================================================================
  // 1. CẤU HÌNH & ĐỊA ĐIỂM CHẤM CÔNG (GET /attendance/mobile/config)
  // ===========================================================================

  @override
  Future<AttendanceConfigEntity> getConfig({double? lat, double? lng}) async {
    final prefs = await SharedPreferences.getInstance();
    final userCacheKey = _getUserConfigCacheKey(prefs);

    if (_isOnline) {
      try {
        final model = await _apiService.getConfig(lat: lat, lng: lng);
        await prefs.setString(userCacheKey, jsonEncode(model.toJson()));
        return model.toEntity();
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi tải config từ server: $e');
        if (e is ServerException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          rethrow;
        }
      }
    }

    // Đọc từ cache nếu mất mạng hoặc lỗi server 5xx (tách theo từng tài khoản §3.2 & §5)
    final cachedJson = prefs.getString(userCacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        return AttendanceConfigModel.fromJson(map).toEntity();
      } catch (_) {}
    }

    // Cấu hình mặc định an toàn
    return const AttendanceConfigEntity(
      canPunch: true,
      blockedReason: null,
      group: AttendanceGroupEntity(
        code: 'MARKET',
        name: 'Khối thị trường',
        enforceGeofence: true,
      ),
      photo: AttendancePhotoConfigEntity(
        minPhotos: 2,
        maxPhotos: 10,
        requireBoth: true,
      ),
      locations: [],
    );
  }

  // ===========================================================================
  // 2. GỬI LƯỢT CHẤM CÔNG (POST /attendance/mobile/punch)
  // ===========================================================================

  @override
  Future<AttendancePunchEntity> punch({
    required double lat,
    required double lng,
    double? accuracyM,
    bool? isMockLocation,
    String? clientUuid,
  }) async {
    // 🔴 QUY TẮC §3: client_uuid SINH LÚC NGƯỜI DÙNG BẤM, KHÔNG PHẢI LÚC GỬI
    final finalUuid = clientUuid ?? const Uuid().v4();
    final now = DateTime.now();
    final clientTimeIso = now.toIso8601String();

    final deviceInfo = {
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'app_version': '1.0.0',
    };

    final requestModel = AttendancePunchRequestModel(
      clientUuid: finalUuid,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      clientTime: clientTimeIso,
      isMockLocation: isMockLocation == true ? '1' : '0',
      isRootedDevice: '0',
      deviceInfo: deviceInfo,
    );

    if (_isOnline) {
      try {
        final punchModel = await _apiService.punch(requestModel);
        final punchEntity = punchModel.toEntity();

        // Cập nhật lượt chấm vào đầu danh sách lịch sử cục bộ
        await _savePunchToLocalHistory(punchEntity);
        return punchEntity;
      } on ServerException catch (serverErr) {
        // 🔴 QUY TẮC §3.1: Nếu server trả về 422 (ngoài vùng, chưa khai địa điểm, chưa có mã nhân viên)
        // hoặc 4xx luật: TUYỆT ĐỐI KHÔNG đưa vào hàng đợi gửi lại! Ném lỗi ra để hiện nguyên văn cho người dùng.
        debugPrint('[AttendanceRepo] Server từ chối chấm công (${serverErr.statusCode}): ${serverErr.message}');
        rethrow;
      } catch (e) {
        // Lỗi mạng hoặc server sập 5xx -> Đưa vào hàng đợi ngoại tuyến
        debugPrint('[AttendanceRepo] Lỗi mạng khi chấm công -> Đưa vào hàng đợi ngoại tuyến: $e');
      }
    }

    // 🔴 Xử lý ngoại tuyến: Lưu vào bảng SyncQueueEntries (§3.2 & §8)
    final nowMs = now.millisecondsSinceEpoch;
    if (database != null) {
      await database!.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'attendance_punch',
          op: 'create',
          clientUuid: finalUuid,
          payload: jsonEncode(requestModel.toJson()),
          createdAt: nowMs,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
        ),
      );
    }

    // Tạo bản ghi lạc quan (optimistic) hiển thị trên app
    final optimisticPunch = AttendancePunchEntity(
      id: -nowMs, // id tạm thời âm cho bản ghi offline
      punchAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      clientUuid: finalUuid,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      geofenceId: null,
      geofenceName: 'Lưu ngoại tuyến (chờ gửi)',
      isOutsideGeofence: false,
      isMockLocation: isMockLocation ?? false,
      isTimeTampered: AntiFraudService.getEstimatedClockSkewMinutes().abs() > 15,
      duplicate: false,
      photos: const [],
      requirements: const AttendanceRequirementsEntity(
        photoCount: 0,
        minPhotos: 2,
        maxPhotos: 10,
        needFront: true,
        needBack: true,
        requireBoth: true,
        satisfied: false,
      ),
    );

    await _savePunchToLocalHistory(optimisticPunch);
    return optimisticPunch;
  }

  // ===========================================================================
  // 3. TẢI ẢNH CỦA LƯỢT CHẤM (POST /attendance/mobile/punches/{id}/photos)
  // ===========================================================================

  @override
  Future<AttendancePunchPhotoEntity> uploadPunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? parentUuid,
  }) async {
    final now = takenAt ?? DateTime.now();

    if (_isOnline && punchId > 0) {
      try {
        final photoModel = await _apiService.uploadPunchPhoto(
          punchId,
          file: file,
          photoType: photoType,
          takenAt: now,
          lat: lat,
          lng: lng,
        );
        final photoEntity = photoModel.toEntity();

        // Cập nhật ảnh vào lượt chấm trong lịch sử cục bộ
        await _attachPhotoToLocalPunch(punchId, photoEntity);
        return photoEntity;
      } on ServerException catch (serverErr) {
        // Lỗi 4xx (ảnh quá trần, định dạng sai, không tìm thấy lượt): ném lỗi
        debugPrint('[AttendanceRepo] Server từ chối tải ảnh: ${serverErr.message}');
        rethrow;
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi mạng khi tải ảnh -> Đưa vào hàng đợi ngoại tuyến: $e');
      }
    }

    // 🔴 Ngoại tuyến: Đưa vào hàng đợi SyncQueueEntries riêng biệt (§4.1 & §8)
    final photoUuid = const Uuid().v4();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final payloadMap = {
      'punch_id': punchId,
      'photo_type': photoType,
      'taken_at': now.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'local_path': file.path,
    };

    if (database != null) {
      await database!.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'attendance_photo',
          op: 'upload',
          clientUuid: photoUuid,
          parentUuid: parentUuid != null ? Value(parentUuid) : const Value.absent(),
          localPath: Value(file.path),
          payload: jsonEncode(payloadMap),
          createdAt: nowMs,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
        ),
      );
    }

    // Trả về đối tượng ảnh cục bộ tạm thời
    final tempPhoto = AttendancePunchPhotoEntity(
      id: -nowMs,
      fileId: null,
      token: null,
      url: file.path,
      photoType: photoType,
      photoTypeLabel: photoType == 'front' ? 'Ảnh chân dung' : 'Ảnh khung cảnh',
      photoTypeColor: 'primary',
      takenAt: now.toIso8601String(),
      sortOrder: 0,
      duplicate: false,
    );

    await _attachPhotoToLocalPunch(punchId, tempPhoto);
    return tempPhoto;
  }

  // ===========================================================================
  // 4. LỊCH SỬ CHẤM CÔNG CỦA MÌNH (GET /attendance/mobile/history)
  // ===========================================================================

  @override
  Future<List<AttendancePunchEntity>> getHistory({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();

    if (_isOnline) {
      try {
        final models = await _apiService.getHistory(days: days);
        final entities = models.map((m) => m.toEntity()).toList();

        // Lưu cache lịch sử
        final rawList = models.map((m) => m.toJson()).toList();
        await prefs.setString(_historyCacheKey, jsonEncode(rawList));
        return entities;
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi lấy lịch sử từ server: $e');
      }
    }

    // Đọc cache ngoại tuyến
    final cachedJson = prefs.getString(_historyCacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        return list
            .map((item) => AttendancePunchModel.fromJson(item as Map<String, dynamic>).toEntity())
            .toList();
      } catch (_) {}
    }

    return const [];
  }

  // ===========================================================================
  // HÀM TIỆN ÍCH QUẢN LÝ LỊCH SỬ CỤC BỘ
  // ===========================================================================

  Future<void> _savePunchToLocalHistory(AttendancePunchEntity punch) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_historyCacheKey);
    List<Map<String, dynamic>> rawList = [];

    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        rawList = list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    // Loại bỏ lượt có cùng clientUuid nếu đã có
    rawList.removeWhere((item) => item['client_uuid'] == punch.clientUuid);

    // Chuyển entity sang map để lưu
    final punchMap = {
      'id': punch.id,
      'punch_at': punch.punchAt,
      'client_uuid': punch.clientUuid,
      'lat': punch.lat,
      'lng': punch.lng,
      'accuracy_m': punch.accuracyM,
      'geofence_id': punch.geofenceId,
      'geofence_name': punch.geofenceName,
      'is_outside_geofence': punch.isOutsideGeofence,
      'is_mock_location': punch.isMockLocation,
      'is_time_tampered': punch.isTimeTampered,
      'duplicate': punch.duplicate,
      'direction': punch.direction,
      'direction_label': punch.directionLabel,
      'photos': punch.photos.map((p) => {
        'id': p.id,
        'file_id': p.fileId,
        'token': p.token,
        'url': p.url,
        'photo_type': p.photoType,
        'photo_type_label': p.photoTypeLabel,
        'photo_type_color': p.photoTypeColor,
        'taken_at': p.takenAt,
        'sort_order': p.sortOrder,
        'duplicate': p.duplicate,
      }).toList(),
      'requirements': {
        'photo_count': punch.requirements.photoCount,
        'min_photos': punch.requirements.minPhotos,
        'max_photos': punch.requirements.maxPhotos,
        'need_front': punch.requirements.needFront,
        'need_back': punch.requirements.needBack,
        'require_both': punch.requirements.requireBoth,
        'satisfied': punch.requirements.satisfied,
      },
    };

    rawList.insert(0, punchMap);
    await prefs.setString(_historyCacheKey, jsonEncode(rawList));
  }

  Future<void> _attachPhotoToLocalPunch(int punchId, AttendancePunchPhotoEntity photo) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_historyCacheKey);
    if (cachedJson == null || cachedJson.isEmpty) return;

    try {
      final list = jsonDecode(cachedJson) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic> && item['id'] == punchId) {
          final photos = (item['photos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          // Không thêm trùng ảnh cùng loại
          photos.removeWhere((p) => p['photo_type'] == photo.photoType);
          photos.add({
            'id': photo.id,
            'file_id': photo.fileId,
            'token': photo.token,
            'url': photo.url,
            'photo_type': photo.photoType,
            'photo_type_label': photo.photoTypeLabel,
            'photo_type_color': photo.photoTypeColor,
            'taken_at': photo.takenAt,
            'sort_order': photo.sortOrder,
            'duplicate': photo.duplicate,
          });
          item['photos'] = photos;

          final hasFront = photos.any((p) => p['photo_type'] == 'front');
          final hasBack = photos.any((p) => p['photo_type'] == 'back');
          item['requirements'] = {
            'photo_count': photos.length,
            'min_photos': 2,
            'max_photos': 10,
            'need_front': !hasFront,
            'need_back': !hasBack,
            'require_both': true,
            'satisfied': hasFront && hasBack,
          };
          break;
        }
      }
      await prefs.setString(_historyCacheKey, jsonEncode(list));
    } catch (_) {}
  }

  // ===========================================================================
  // PHƯƠNG THỨC TƯƠNG THÍCH NGƯỢC VỚI TEST VÀ CÁC MÀN CŨ
  // ===========================================================================

  @override
  Future<AttendanceDetailEntity> getAttendanceDetail() async {
    // Tải dữ liệu từ SharedPreferences cục bộ để tương thích ngược
    return _loadRealLocalAttendance();
  }

  Future<AttendanceDetailEntity> _loadRealLocalAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final dateStr = _formatVietnameseDate(now);
    final currentMonthLabel = 'Tháng ${now.month.toString().padLeft(2, '0')}/${now.year}';

    bool isWorking = false;
    String checkInTime = '--:--';
    int workDurationSeconds = 0;

    // Đọc phiên chấm công ca làm việc
    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson != null && sessionJson.isNotEmpty) {
      try {
        final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
        isWorking = sessionMap['is_working'] == true;
        checkInTime = sessionMap['check_in_time']?.toString() ?? '--:--';
        final checkInIso = sessionMap['check_in_iso']?.toString();
        if (checkInIso != null && isWorking) {
          final checkInDt = DateTime.parse(checkInIso);
          workDurationSeconds = now.difference(checkInDt).inSeconds;
          if (workDurationSeconds < 0) workDurationSeconds = 0;
        }
      } catch (_) {}
    }

    // Đọc lịch sử chấm công thực tế
    final history = <AttendanceHistoryItemEntity>[];
    final historyJson = prefs.getString(_legacyHistoryKey);
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final list = jsonDecode(historyJson) as List<dynamic>;
        for (final item in list) {
          if (item is Map) {
            history.add(
              AttendanceHistoryItemEntity(
                id: item['id']?.toString() ?? const Uuid().v4(),
                date: item['date']?.toString() ?? '',
                timeRange: item['time_range']?.toString() ?? '',
                status: item['status']?.toString() ?? 'Đúng giờ',
                isLate: item['is_late'] == true,
              ),
            );
          }
        }
      } catch (_) {}
    }

    // Tính toán thống kê tháng từ lịch sử thực tế
    int workingDays = 0;
    int lateDays = 0;
    final currentMonthPrefix = '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final distinctDays = <String>{};
    for (final h in history) {
      if (h.date.contains(currentMonthPrefix) || h.date.contains('${now.month}/')) {
        distinctDays.add(h.date);
        if (h.isLate) {
          lateDays++;
        }
      }
    }
    workingDays = distinctDays.length;

    _cachedEntity = AttendanceDetailEntity(
      isWorking: isWorking,
      currentTime: timeStr,
      currentDateFormatted: dateStr,
      checkInTime: checkInTime,
      workDurationSeconds: workDurationSeconds,
      location: const AttendanceLocationEntity(
        address: 'Vị trí hiện tại',
        gpsAccuracy: 'Độ chính xác cao',
        latitude: 21.0285,
        longitude: 105.8542,
      ),
      monthlyStats: MonthlyAttendanceStatsEntity(
        monthLabel: currentMonthLabel,
        workingDays: workingDays,
        lateDays: lateDays,
      ),
      history: history,
    );

    return _cachedEntity!;
  }

  @override
  Future<AttendanceDetailEntity> toggleAttendanceCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final timeFormatted = DateFormat('HH:mm').format(now);
    final dateFormatted = DateFormat('dd/MM/yyyy').format(now);

    final current = _cachedEntity ?? await getAttendanceDetail();
    final newIsWorking = !current.isWorking;

    final history = List<AttendanceHistoryItemEntity>.from(current.history);

    if (newIsWorking) {
      final sessionData = {
        'is_working': true,
        'check_in_time': timeFormatted,
        'check_in_iso': now.toIso8601String(),
      };
      await prefs.setString(_sessionKey, jsonEncode(sessionData));
    } else {
      final start = current.checkInTime != '--:--' ? current.checkInTime : timeFormatted;
      final newHistoryItem = AttendanceHistoryItemEntity(
        id: const Uuid().v4(),
        date: dateFormatted,
        timeRange: '$start - $timeFormatted',
        status: 'Đúng giờ',
        isLate: false,
      );
      history.insert(0, newHistoryItem);

      final historyRaw = history.map((e) => {
        'id': e.id,
        'date': e.date,
        'time_range': e.timeRange,
        'status': e.status,
        'is_late': e.isLate,
      }).toList();
      await prefs.setString(_legacyHistoryKey, jsonEncode(historyRaw));
      await prefs.remove(_sessionKey);
    }

    _cachedEntity = AttendanceDetailEntity(
      isWorking: newIsWorking,
      currentTime: DateFormat('HH:mm:ss').format(now),
      currentDateFormatted: _formatVietnameseDate(now),
      checkInTime: newIsWorking ? timeFormatted : '--:--',
      workDurationSeconds: newIsWorking ? 0 : current.workDurationSeconds,
      location: current.location,
      monthlyStats: MonthlyAttendanceStatsEntity(
        monthLabel: current.monthlyStats.monthLabel,
        workingDays: newIsWorking ? current.monthlyStats.workingDays : current.monthlyStats.workingDays + 1,
        lateDays: current.monthlyStats.lateDays,
      ),
      history: history,
    );

    return _cachedEntity!;
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

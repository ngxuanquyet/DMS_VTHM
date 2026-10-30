import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/utils/account_key.dart';
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
    // Khoá bộ đệm của người BẤM — lấy trước `await` mạng: đổi tài khoản giữa chừng thì lượt này không rơi vào bộ đệm người mới.
    final historyKey = attendanceHistoryCacheKey(await SharedPreferences.getInstance());
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
        await _savePunchToLocalHistory(historyKey, punchEntity);
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

    // Hàng đợi gắn người ĐANG đăng nhập — tài khoản đổi trong lúc chờ mạng thì lượt của người bấm không được gửi dưới tên
    // người mới.
    if (attendanceHistoryCacheKey(await SharedPreferences.getInstance()) != historyKey) {
      throw const AppException('Tài khoản đăng nhập đã thay đổi trong lúc chấm công. Vui lòng chấm công lại.');
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
    final optimisticPunch = _optimisticPunch(
      clientUuid: finalUuid,
      at: now,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      isMockLocation: isMockLocation ?? false,
    );

    await _savePunchToLocalHistory(historyKey, optimisticPunch);
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
    final historyKey = attendanceHistoryCacheKey(await SharedPreferences.getInstance());

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
        await _attachPhotoToLocalPunch(historyKey, punchId, photoEntity);
        return photoEntity;
      } on ServerException catch (serverErr) {
        // Lỗi 4xx (ảnh quá trần, định dạng sai, không tìm thấy lượt): ném lỗi
        debugPrint('[AttendanceRepo] Server từ chối tải ảnh: ${serverErr.message}');
        rethrow;
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi mạng khi tải ảnh -> Đưa vào hàng đợi ngoại tuyến: $e');
      }
    }

    // Như punch(): tài khoản đổi trong lúc chờ mạng thì không gửi ảnh của người cũ dưới tên người mới.
    if (attendanceHistoryCacheKey(await SharedPreferences.getInstance()) != historyKey) {
      throw const AppException('Tài khoản đăng nhập đã thay đổi trong lúc gửi ảnh. Vui lòng chấm công lại.');
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

    await _attachPhotoToLocalPunch(historyKey, punchId, tempPhoto);
    return tempPhoto;
  }

  @override
  Future<AttendancePunchPhotoEntity> enqueuePunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? parentUuid,
  }) async {
    final now = takenAt ?? DateTime.now();
    final historyKey = attendanceHistoryCacheKey(await SharedPreferences.getInstance());
    final photoUuid = const Uuid().v4();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Lưu ảnh vào thư mục attendance_photos cố định
    String localSavedPath = file.path;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final attDir = Directory(p.join(appDocDir.path, 'attendance_photos'));
      if (!await attDir.exists()) {
        await attDir.create(recursive: true);
      }
      final persistentFile = await file.copy(
        p.join(attDir.path, PhotoWatermarkHelper.keepMarkerName(file, 'att_${photoType}_${nowMs}_$photoUuid.jpg')),
      );
      localSavedPath = persistentFile.path;
    } catch (e) {
      debugPrint('[AttendanceRepo] Không thể copy ảnh vào thư mục riêng: $e');
    }

    // Chép ảnh là I/O bất đồng bộ — tài khoản đổi trong lúc đó thì không gửi ảnh của người cũ dưới tên người mới.
    if (attendanceHistoryCacheKey(await SharedPreferences.getInstance()) != historyKey) {
      // Bản chép là ảnh chân dung người cũ, không có dòng hàng đợi nào trỏ tới ⇒ không ai dọn — xoá ngay.
      if (localSavedPath != file.path) {
        try {
          await File(localSavedPath).delete();
        } catch (_) {}
      }
      throw const AppException('Tài khoản đăng nhập đã thay đổi trong lúc lưu ảnh. Vui lòng chấm công lại.');
    }

    final payloadMap = {
      'punch_id': punchId,
      'photo_type': photoType,
      'taken_at': now.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'local_path': localSavedPath,
    };

    if (database != null) {
      await database!.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'attendance_photo',
          op: 'upload',
          clientUuid: photoUuid,
          parentUuid: parentUuid != null ? Value(parentUuid) : const Value.absent(),
          localPath: Value(localSavedPath),
          payload: jsonEncode(payloadMap),
          createdAt: nowMs,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
        ),
      );
    }

    final tempPhoto = AttendancePunchPhotoEntity(
      id: -nowMs,
      fileId: null,
      token: null,
      url: localSavedPath,
      photoType: photoType,
      photoTypeLabel: photoType == 'front' ? 'Ảnh chân dung' : 'Ảnh khung cảnh',
      photoTypeColor: 'primary',
      takenAt: now.toIso8601String(),
      sortOrder: 0,
      duplicate: false,
    );

    await _attachPhotoToLocalPunch(historyKey, punchId, tempPhoto);
    return tempPhoto;
  }

  // ===========================================================================
  // 4. LỊCH SỬ CHẤM CÔNG CỦA MÌNH (GET /attendance/mobile/history)
  // ===========================================================================

  @override
  Future<List<AttendancePunchEntity>> getHistory({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    // `null` (chưa rõ tài khoản) ⇒ vẫn lấy từ server + ghép hàng đợi (hàng đợi tự lọc theo chủ), chỉ bỏ đọc/ghi bộ đệm.
    final historyKey = attendanceHistoryCacheKey(prefs);

    // Mọi `await` làm TRƯỚC (server, hàng đợi); phần đọc bộ đệm → ghép → ghi bên dưới chạy liền một mạch, không `await` nào
    // xen giữa ⇒ không đè mất lượt/ảnh mà chỗ khác vừa lưu vào bộ đệm trong lúc chờ.
    // Hàng đợi đọc CẢ TRƯỚC lẫn SAU lần gọi server rồi gộp: lượt được gửi xong trong lúc gọi server chỉ còn ở bản đọc trước
    // (server đã có ⇒ trùng uuid, bỏ); lượt vừa vào hàng đợi trong lúc đó chỉ có ở bản đọc sau. Thiếu một trong hai thì lượt
    // đó lọt cả hai nguồn và bị xoá khỏi bộ đệm ⇒ báo "chưa chấm".
    final queuedBefore = await _queuedAttendancePunches();
    List<Map<String, dynamic>>? serverRaw;
    if (_isOnline) {
      try {
        final models = await _apiService.getHistory(days: days);
        serverRaw = models.map((m) => m.toJson()).toList();
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi lấy lịch sử từ server: $e');
      }
    }
    final queuedAfter = await _queuedAttendancePunches();
    final queuedUuids = queuedAfter.map((e) => e.clientUuid).toSet();
    final queued = [...queuedAfter, ...queuedBefore.where((e) => !queuedUuids.contains(e.clientUuid))];
    var queuedPhotos = const <SyncQueueEntry>[];
    if (queued.isNotEmpty && database != null) {
      try {
        queuedPhotos = await database!.getQueuedAttendancePhotos();
      } catch (_) {}
    }

    // Tài khoản đổi trong lúc chờ ⇒ server, bộ đệm, hàng đợi lẫn lộn người cũ/mới: không trả, không ghi gì.
    if (attendanceHistoryCacheKey(prefs) != historyKey) return const [];

    final cachedRaw = _readHistoryCache(prefs, historyKey);
    final base = serverRaw ?? cachedRaw;
    final extra = _queuedPunchesMissingFrom(queued, queuedPhotos, base, cachedRaw);
    final raw = [...extra, ...base];
    if (historyKey != null && (serverRaw != null || extra.isNotEmpty)) {
      // setString cập nhật bản trong bộ nhớ NGAY (đồng bộ) rồi mới ghi đĩa ⇒ không có khe cho chỗ khác chen vào.
      await prefs.setString(historyKey, jsonEncode(raw));
    }

    final entities = <AttendancePunchEntity>[];
    for (final item in raw) {
      try {
        entities.add(AttendancePunchModel.fromJson(item).toEntity());
      } catch (_) {}
    }
    return entities;
  }

  Future<List<SyncQueueEntry>> _queuedAttendancePunches() async {
    if (database == null) return const [];
    try {
      return await database!.getQueuedAttendancePunches();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _readHistoryCache(SharedPreferences prefs, String? historyKey) {
    final cachedJson = historyKey == null ? null : prefs.getString(historyKey);
    if (cachedJson == null || cachedJson.isEmpty) return const [];
    try {
      return (jsonDecode(cachedJson) as List<dynamic>).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Các lượt chấm CÒN CHỜ GỬI trong hàng đợi ([queued], của người đang đăng nhập, mới → cũ) mà [base] chưa có.
  ///
  /// Lịch sử server chưa có lượt bấm lúc mất mạng, còn bộ đệm có thể đã mất nó (lịch sử server ghi đè, đăng xuất xoá, nâng
  /// cấp dọn khoá cũ). Thiếu lượt này thì màn hình báo "Chưa chấm công", hiện nhắc, người dùng bấm lần nữa ⇒ trùng lượt.
  /// Bản trong bộ đệm (còn ảnh đã gắn) được giữ; không có thì dựng lại từ payload hàng đợi kèm ảnh còn chờ gửi.
  List<Map<String, dynamic>> _queuedPunchesMissingFrom(
    List<SyncQueueEntry> queued,
    List<SyncQueueEntry> queuedPhotos,
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> cachedRaw,
  ) {
    final known = base.map((p) => p['client_uuid']?.toString() ?? '').where((u) => u.isNotEmpty).toSet();
    final extra = <Map<String, dynamic>>[];
    for (final e in queued) {
      if (known.contains(e.clientUuid)) continue;
      final cached = cachedRaw.where((p) => p['client_uuid'] == e.clientUuid).firstOrNull;
      if (cached != null) {
        extra.add(cached);
        continue;
      }
      try {
        final payload = jsonDecode(e.payload) as Map<String, dynamic>;
        final punch = _optimisticPunch(
          clientUuid: e.clientUuid,
          at: DateTime.tryParse(payload['client_time']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(e.createdAt),
          lat: (payload['lat'] as num).toDouble(),
          lng: (payload['lng'] as num).toDouble(),
          accuracyM: (payload['accuracy_m'] as num?)?.toDouble(),
          isMockLocation: payload['is_mock_location']?.toString() == '1',
        );
        final map = _punchToMap(punch);
        final photos = <Map<String, dynamic>>[];
        for (final ph in queuedPhotos.where((p) => p.parentUuid == e.clientUuid)) {
          // Ảnh hỏng chỉ bỏ ảnh đó — không được kéo mất cả lượt chấm (mất lượt ⇒ báo "chưa chấm" ⇒ chấm trùng).
          try {
            photos.add(_queuedPhotoToMap(ph));
          } catch (_) {}
        }
        if (photos.isNotEmpty) {
          map['photos'] = photos;
          map['requirements'] = _photoRequirements(photos);
        }
        extra.add(map);
      } catch (err) {
        debugPrint('[AttendanceRepo] Không dựng lại được lượt chấm chờ gửi ${e.clientUuid}: $err');
      }
    }
    return extra;
  }

  Map<String, dynamic> _queuedPhotoToMap(SyncQueueEntry e) {
    final payload = jsonDecode(e.payload) as Map<String, dynamic>;
    final type = payload['photo_type']?.toString() ?? '';
    return {
      'id': -e.createdAt,
      'file_id': null,
      'token': null,
      'url': e.localPath ?? payload['local_path'],
      'photo_type': type,
      'photo_type_label': type == 'front' ? 'Ảnh chân dung' : 'Ảnh khung cảnh',
      'photo_type_color': 'primary',
      'taken_at': payload['taken_at'],
      'sort_order': 0,
      'duplicate': false,
    };
  }

  /// Lượt chấm hiển thị tạm cho lượt bấm lúc mất mạng (chưa có id server ⇒ id âm).
  AttendancePunchEntity _optimisticPunch({
    required String clientUuid,
    required DateTime at,
    required double lat,
    required double lng,
    double? accuracyM,
    bool isMockLocation = false,
  }) {
    return AttendancePunchEntity(
      id: -at.millisecondsSinceEpoch,
      punchAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(at),
      clientUuid: clientUuid,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      geofenceId: null,
      geofenceName: 'Lưu ngoại tuyến (chờ gửi)',
      isOutsideGeofence: false,
      isMockLocation: isMockLocation,
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
  }

  @override
  Future<List<AttendanceShiftScheduleEntity>> getMobileShifts({
    String? from,
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userCacheKey = '${_getUserConfigCacheKey(prefs)}_shifts';

    if (_isOnline) {
      try {
        final models = await _apiService.getMobileShifts(from: from, days: days);
        final jsonList = models.map((m) => m.toJson()).toList();
        await prefs.setString(userCacheKey, jsonEncode(jsonList));
        return models.map((m) => m.toEntity()).toList();
      } catch (e) {
        debugPrint('[AttendanceRepo] Lỗi tải lịch ca làm việc ($from, $days ngày): $e');
      }
    }

    // Đọc từ bộ nhớ cache cục bộ nếu mất mạng hoặc lỗi server
    final cachedJson = prefs.getString(userCacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final rawList = jsonDecode(cachedJson) as List<dynamic>;
        return rawList
            .map((item) => AttendanceShiftScheduleModel.fromJson(item as Map<String, dynamic>).toEntity())
            .toList();
      } catch (_) {}
    }

    return const [];
  }

  /// Kết quả công theo tháng: chỉ đọc mạng, KHÔNG ghi đè bộ đệm lịch ca 7 ngày (`_shifts`). Mất mạng thì NÉM lỗi — trả rỗng
  /// sẽ bị hiểu là "tháng này không đi muộn ngày nào".
  @override
  Future<List<AttendanceDayResultEntity>> getMobileDays(String month) async {
    if (!_isOnline) throw StateError('offline');
    final models = await _apiService.getMobileDays(month);
    return models.map((m) => m.toEntity()).toList();
  }

  // ===========================================================================
  // HÀM TIỆN ÍCH QUẢN LÝ LỊCH SỬ CỤC BỘ
  // ===========================================================================

  Future<void> _savePunchToLocalHistory(String? historyKey, AttendancePunchEntity punch) async {
    final prefs = await SharedPreferences.getInstance();
    // Ghi SAU `await` mạng: tài khoản đã đổi / đã đăng xuất ⇒ bỏ, không dựng lại bộ đệm của người cũ.
    if (historyKey == null || attendanceHistoryCacheKey(prefs) != historyKey) return;
    final cachedJson = prefs.getString(historyKey);
    List<Map<String, dynamic>> rawList = [];

    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        rawList = list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    // Loại bỏ lượt có cùng clientUuid nếu đã có
    rawList.removeWhere((item) => item['client_uuid'] == punch.clientUuid);
    rawList.insert(0, _punchToMap(punch));
    await prefs.setString(historyKey, jsonEncode(rawList));
  }

  Map<String, dynamic> _punchToMap(AttendancePunchEntity punch) => {
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

  /// Điều kiện ảnh của một lượt chấm tạm (chưa có số server) — đủ khi có cả ảnh chân dung lẫn khung cảnh.
  Map<String, dynamic> _photoRequirements(List<Map<String, dynamic>> photos) {
    final hasFront = photos.any((p) => p['photo_type'] == 'front');
    final hasBack = photos.any((p) => p['photo_type'] == 'back');
    return {
      'photo_count': photos.length,
      'min_photos': 2,
      'max_photos': 10,
      'need_front': !hasFront,
      'need_back': !hasBack,
      'require_both': true,
      'satisfied': hasFront && hasBack,
    };
  }

  Future<void> _attachPhotoToLocalPunch(String? historyKey, int punchId, AttendancePunchPhotoEntity photo) async {
    final prefs = await SharedPreferences.getInstance();
    if (historyKey == null || attendanceHistoryCacheKey(prefs) != historyKey) return;
    final cachedJson = prefs.getString(historyKey);
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

          item['requirements'] = _photoRequirements(photos);
          break;
        }
      }
      await prefs.setString(historyKey, jsonEncode(list));
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
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final dateStr = _formatVietnameseDate(now);
    final currentMonthLabel = 'Tháng ${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Phiên "đang làm việc" + lịch sử kiểu cũ (bật/tắt ca trong máy) đã gỡ: giờ vào chỉ từ lượt chấm thật của server.
    _cachedEntity = AttendanceDetailEntity(
      isWorking: false,
      currentTime: timeStr,
      currentDateFormatted: dateStr,
      checkInTime: '--:--',
      workDurationSeconds: 0,
      location: const AttendanceLocationEntity(
        address: 'Vị trí hiện tại',
        gpsAccuracy: 'Độ chính xác cao',
        latitude: 21.0285,
        longitude: 105.8542,
      ),
      monthlyStats: MonthlyAttendanceStatsEntity(
        monthLabel: currentMonthLabel,
        workingDays: 0,
        lateDays: 0,
      ),
      history: const [],
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

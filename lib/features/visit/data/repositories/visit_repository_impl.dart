import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/visit_entity.dart';
import '../../domain/entities/visit_photo_entity.dart';
import '../../domain/entities/visit_requirements_entity.dart';
import '../../domain/repositories/visit_repository.dart';
import '../models/checkin_request_model.dart';
import '../models/checkout_request_model.dart';
import '../services/visit_api_service.dart';
import '../../domain/entities/visit_history_entity.dart';

final visitApiServiceProvider = Provider<VisitApiService>((ref) {
  return VisitApiService(ref.watch(apiClientProvider));
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepositoryImpl(ref.watch(visitApiServiceProvider));
});

/// [a] và [b] là CÙNG một lượt: cùng mã (khác 0 — 0 là "chưa có mã"), hoặc cùng `client_uuid` khác rỗng.
bool isSameVisit(VisitEntity a, VisitEntity b) =>
    (a.id != 0 && a.id == b.id) || ((a.clientUuid?.isNotEmpty ?? false) && a.clientUuid == b.clientUuid);

/// Server XÁC NHẬN lượt [visit] không còn mở (không có trong danh sách lượt còn mở). Không tra được ⇒ `false` (giữ lượt).
Future<bool> serverConfirmsVisitNotOpen(VisitRepository repo, VisitEntity visit) async {
  if (repo is! VisitRepositoryImpl) return false;
  try {
    // Màn đang mở chờ kết quả này ⇒ có trần; quá trần coi như không tra được (giữ lượt).
    final open = await repo.getOpenVisits().timeout(const Duration(seconds: 8));
    return !open.any((v) => isSameVisit(v, visit));
  } catch (_) {
    return false;
  }
}

class VisitRepositoryImpl implements VisitRepository {
  final VisitApiService _apiService;
  static const String _activeVisitKey = 'dms_active_visit_session_v1';
  static const String _visitsListKey = 'dms_visits_local_cache_v2';

  VisitRepositoryImpl(this._apiService);

  /// Lượt CÒN MỞ trên server, KHÔNG giới hạn ngày (lượt treo từ hôm trước vẫn chặn mọi check-in mới). Lỗi mạng ném ra —
  /// nơi gọi coi là "không tra được", không kết luận gì.
  Future<List<VisitEntity>> getOpenVisits() => _apiService.getMyVisits(openOnly: true, perPage: 20);

  @override
  Future<List<VisitEntity>> getTodayVisits() async {
    return getVisitsByDate(DateTime.now());
  }

  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Đồng bộ từ API khi có mạng. `null` = không tải được ⇒ chỉ còn dữ liệu máy, không kết luận gì từ việc server thiếu lượt.
    List<VisitEntity>? remote;
    try {
      remote = await _apiService.getMyVisits(
        dateFrom: dateStr,
        dateTo: dateStr,
        perPage: 100,
      );
      if (remote.isNotEmpty) {
        await saveLocalVisits(remote);
      }
    } catch (e) {
      debugPrint('[VisitRepo] Không thể đồng bộ lượt viếng thăm từ API: $e. Sử dụng dữ liệu cục bộ.');
    }

    // Đọc từ bộ nhớ máy
    final all = await getAllLocalVisits();
    final matching = all.where((v) {
      if (v.visitDate != null && v.visitDate!.isNotEmpty) {
        return v.visitDate == dateStr;
      }
      if (v.checkinAt != null) {
        return DateFormat('yyyy-MM-dd').format(v.checkinAt!) == dateStr;
      }
      return false;
    }).toList();

    // Server bỏ lượt ĐÃ HUỶ khỏi danh sách (VisitSearch) ⇒ lượt đã có mã đang "mở" trong máy mà danh sách tải được không có
    // = nghi huỷ ở máy khác (#24895). Thiếu chưa đủ kết luận (vừa check-in sau ảnh chụp, danh sách bị cắt trang) ⇒ hỏi lại
    // danh sách lượt CÒN MỞ một lần: không có ⇒ bỏ bản sao khỏi bộ đệm máy (mất mạng sau đó nó không hiện lại) — KHÔNG ghi
    // "đã huỷ": đó là suy luận, ghi huỷ thì bản server về sau không đè được (saveLocalVisits); đoán sai thì lần tải sau server
    // trả lại. Bản lưu "đang mở" để tuyến xử lý (_loadTodayVisits). Có hoặc không tra được ⇒ giữ.
    final serverList = remote;
    if (serverList != null) {
      final suspects =
          matching.where((v) => v.id > 0 && v.isOpen && !serverList.any((r) => isSameVisit(r, v))).toList();
      if (suspects.isNotEmpty) {
        List<VisitEntity>? open;
        try {
          open = await getOpenVisits().timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('[VisitRepo] Không tra được lượt còn mở: $e');
        }
        if (open != null) {
          // Bộ đệm đọc TRƯỚC lần hỏi lại (tới 8 giây) ⇒ đọc lại ngay trước khi xoá: lượt vừa check-out trong lúc chờ thì
          // giữ bản mới, không xoá lượt thật.
          final fresh = await getAllLocalVisits();
          for (final v in suspects) {
            if (open.any((o) => isSameVisit(o, v))) continue;
            final idx = matching.indexOf(v);
            final now = fresh.where((x) => isSameVisit(x, v)).firstOrNull;
            if (now != null && !now.isOpen) {
              matching[idx] = now;
              continue;
            }
            await removeLocalVisit(v.id, clientUuid: (v.clientUuid?.isNotEmpty ?? false) ? v.clientUuid : null);
            matching.removeAt(idx);
          }
        }
      }
    }

    // Ngày hôm nay: ghép lượt đang mở lưu trong máy nếu chưa có trong danh sách — CHỈ lượt chưa có mã (ngoại tuyến chưa gửi;
    // bỏ là mất lượt), hoặc lượt check-in HÔM NAY khi không tải được server. Lượt ngày cũ đã có mã KHÔNG ghép: không giữ làm
    // lượt đang mở, cron đầu ngày đánh dấu "Chưa check-out" (chủ hệ thống chốt #24894, 06/11/2026). Ghép bừa từng làm lượt đã
    // huỷ hôm trước hiện "đang mở" sáng hôm sau, đồng hồ đếm từ hôm trước (#24893).
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr == todayStr) {
      final active = await getActiveVisit();
      if (active != null &&
          active.isOpen &&
          (active.id <= 0 || (remote == null && active.isCheckinToday)) &&
          !matching.any((v) => isSameVisit(v, active))) {
        matching.insert(0, active);
      }
    }

    return matching;
  }

  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) async {
    var visit = await _apiService.checkin(request);
    if (visit.customerId <= 0) {
      visit = visit.copyWith(customerId: request.customerId);
    }
    if (visit.clientUuid == null || visit.clientUuid!.isEmpty) {
      visit = visit.copyWith(clientUuid: request.clientUuid);
    }
    await saveActiveVisit(visit);
    await saveLocalVisit(visit);
    return visit;
  }

  @override
  Future<VisitRequirementsEntity> getRequirements(
    int visitId, {
    String? visitResult,
  }) {
    return _apiService.getRequirements(visitId, visitResult: visitResult);
  }

  @override
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) {
    return _apiService.uploadPhoto(
      visitId: visitId,
      file: file,
      photoType: photoType,
      takenAt: takenAt,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<VisitRequirementsEntity> deletePhoto({
    required int visitId,
    required int photoId,
  }) {
    return _apiService.deletePhoto(visitId: visitId, photoId: photoId);
  }

  @override
  Future<VisitEntity> checkout({
    required int visitId,
    required CheckoutRequestModel request,
  }) async {
    final result = await _apiService.checkout(
      visitId: visitId,
      request: request,
    );
    await clearActiveVisit();
    await saveLocalVisit(result);
    return result;
  }

  @override
  Future<void> cancelVisit(int visitId, {String? clientUuid}) async {
    // Server từ chối (500/403/mất mạng) ⇒ ném ra, KHÔNG gắn "đã huỷ" trong máy: lượt còn mở trên server mà máy ghi huỷ thì
    // bản server không đè lại được, lượt sau gặp STILL_OPEN tới trần (#24698 vòng 6).
    if (visitId > 0) {
      await _apiService.cancelVisit(visitId);
    }
    try {
      await markVisitCancelledLocally(visitId, clientUuid: clientUuid);
    } catch (e) {
      // Server đã huỷ — lỗi ghi máy không được thành "huỷ thất bại" (lần nạp tuyến sau lấy trạng thái server).
      debugPrint('[VisitRepo] Lỗi ghi huỷ lượt trong máy: $e');
    }
  }

  @override
  Future<void> markVisitCancelledLocally(int visitId, {String? clientUuid}) async {
    // Khớp theo mã server (>0) hoặc client_uuid khác rỗng — id 0 / uuid rỗng khớp nhầm lượt khác.
    final uuid = (clientUuid?.isNotEmpty ?? false) ? clientUuid : null;
    bool laLuotNay(VisitEntity v) => (visitId > 0 && v.id == visitId) || (uuid != null && v.clientUuid == uuid);
    // Chỉ dọn lượt đang mở khi CHÍNH là lượt này — lệnh huỷ lượt A tới muộn không được xoá lượt B đang mở.
    final active = await getActiveVisit();
    if (active != null && laLuotNay(active)) await clearActiveVisit();
    final all = await getAllLocalVisits();
    final idx = all.indexWhere(laLuotNay);
    if (idx >= 0) {
      final updated = all[idx].copyWith(
        cancelledAt: DateTime.now(),
        cancelledAtRaw: DateTime.now().toIso8601String(),
      );
      await saveLocalVisit(updated);
    }
  }

  @override
  Future<void> removeLocalVisit(int visitId, {String? clientUuid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllLocalVisits();
      final updated = all.where((v) {
        if (v.id == visitId) return false;
        if (clientUuid != null && v.clientUuid == clientUuid) return false;
        return true;
      }).toList();
      await prefs.setString(
        _visitsListKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi xoá lượt viếng thăm cục bộ: $e');
    }
  }

  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeVisitKey, jsonEncode(visit.toJson()));
    } catch (_) {}
  }

  @override
  Future<VisitEntity?> getActiveVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeVisitKey);
      if (raw != null && raw.isNotEmpty) {
        final entity = VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        // Bản lưu hỏng (không id lượt, không điểm bán). Lượt ngoại tuyến ở điểm bán tạo ngoại tuyến nhận diện điểm bán qua
        // `customer_client_uuid` — GIỮ (xoá là mất lượt đang làm dở, #24698 vòng 2).
        if (entity.id <= 0 && entity.customerId <= 0 && (entity.customerClientUuid?.isEmpty ?? true)) {
          await prefs.remove(_activeVisitKey);
          return null;
        }
        return entity;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearActiveVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeVisitKey);
    } catch (_) {}
  }

  @override
  Future<List<VisitEntity>> getAllLocalVisits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_visitsListKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final visits = list
            .whereType<Map<String, dynamic>>()
            .map((e) => VisitEntity.fromJson(e))
            .toList();
        visits.sort((a, b) {
          final aTime = a.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return visits;
      }
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi đọc danh sách lượt viếng thăm cục bộ: $e');
    }
    return const [];
  }

  @override
  Future<void> saveLocalVisit(VisitEntity visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllLocalVisits();
      final updated = List<VisitEntity>.from(all);
      final idx = updated.indexWhere((v) =>
          v.id == visit.id ||
          (visit.clientUuid != null && v.clientUuid != null && v.clientUuid == visit.clientUuid));
      if (idx >= 0) {
        updated[idx] = visit;
      } else {
        updated.insert(0, visit);
      }
      updated.sort((a, b) {
        final aTime = a.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      await prefs.setString(
        _visitsListKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi lưu lượt viếng thăm cục bộ: $e');
    }
  }

  @override
  Future<void> saveLocalVisits(List<VisitEntity> visits) async {
    if (visits.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllLocalVisits();
      final map = <int, VisitEntity>{};
      for (final v in all) {
        map[v.id] = v;
      }
      for (final v in visits) {
        final existing = map[v.id];
        // Không ghi đè lượt đã bị huỷ cục bộ bằng bản ghi cũ từ server (khi server chưa kịp nhận cancel)
        if (existing != null && existing.isCancelled && !v.isCancelled) {
          continue;
        }
        map[v.id] = v;
      }
      final merged = map.values.toList();
      merged.sort((a, b) {
        final aTime = a.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      await prefs.setString(
        _visitsListKey,
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi lưu danh sách lượt viếng thăm: $e');
    }
  }

  @override
  Future<CustomerVisitHistoryResponse> getCustomerVisitHistory(
    int customerId, {
    int page = 1,
    int perPage = 20,
  }) async {
    return await _apiService.getCustomerVisitHistory(customerId, page: page, perPage: perPage);
  }

  @override
  Future<VisitHistoryDetailEntity> getCustomerVisitHistoryDetail(
    int customerId,
    int visitId,
  ) async {
    return await _apiService.getCustomerVisitHistoryDetail(customerId, visitId);
  }
}

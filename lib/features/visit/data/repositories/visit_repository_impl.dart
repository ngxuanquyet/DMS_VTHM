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

final visitApiServiceProvider = Provider<VisitApiService>((ref) {
  return VisitApiService(ref.watch(apiClientProvider));
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepositoryImpl(ref.watch(visitApiServiceProvider));
});

class VisitRepositoryImpl implements VisitRepository {
  final VisitApiService _apiService;
  static const String _activeVisitKey = 'dms_active_visit_session_v1';
  static const String _visitsListKey = 'dms_visits_local_cache_v2';

  VisitRepositoryImpl(this._apiService);

  @override
  Future<List<VisitEntity>> getTodayVisits() async {
    return getVisitsByDate(DateTime.now());
  }

  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Đồng bộ từ API khi có mạng
    try {
      final remote = await _apiService.getMyVisits(
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

    // Nếu là ngày hôm nay, ghép thêm lượt active nếu chưa nằm trong danh sách
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr == todayStr) {
      final active = await getActiveVisit();
      if (active != null && active.isOpen && !matching.any((v) => v.id == active.id)) {
        matching.insert(0, active);
      }
    }

    return matching;
  }

  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) async {
    final visit = await _apiService.checkin(request);
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
    try {
      if (visitId > 0) {
        await _apiService.cancelVisit(visitId);
      }
    } finally {
      await clearActiveVisit();
      final all = await getAllLocalVisits();
      final idx = all.indexWhere((v) =>
          v.id == visitId || (clientUuid != null && v.clientUuid == clientUuid));
      if (idx >= 0) {
        final updated = all[idx].copyWith(
          cancelledAt: DateTime.now(),
          cancelledAtRaw: DateTime.now().toIso8601String(),
        );
        await saveLocalVisit(updated);
      }
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
        return VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
}

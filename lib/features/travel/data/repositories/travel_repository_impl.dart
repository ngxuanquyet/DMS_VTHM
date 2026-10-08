import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/travel_day_entity.dart';
import '../../domain/entities/travel_leg_entity.dart';
import '../../domain/repositories/travel_repository.dart';
import '../models/travel_day_model.dart';
import '../models/travel_leg_model.dart';
import '../services/travel_api_service.dart';

final travelApiServiceProvider = Provider<TravelApiService>((ref) {
  return TravelApiService(ref.watch(apiClientProvider));
});

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepositoryImpl(ref.watch(travelApiServiceProvider));
});

class TravelRepositoryImpl implements TravelRepository {
  final TravelApiService _apiService;
  static const String _travelDaysCacheKey = 'dms_travel_mine_cache_v1';
  static const String _travelLegsCachePrefix = 'dms_travel_legs_cache_v1_';

  TravelRepositoryImpl(this._apiService);

  @override
  Future<List<TravelDayEntity>> getMyTravel({
    String? from,
    String? to,
    int page = 1,
    int perPage = 50,
    String sort = '-work_date',
    bool forceRefresh = false,
  }) async {
    try {
      final remoteList = await _apiService.getMyTravel(
        from: from,
        to: to,
        page: page,
        perPage: perPage,
        sort: sort,
      );

      // Cập nhật bộ nhớ đệm cục bộ khi có dữ liệu
      if (remoteList.isNotEmpty) {
        _saveTravelDaysCache(remoteList);
      }

      return remoteList;
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi tải quãng đường từ API: $e. Sử dụng dữ liệu bộ nhớ đệm.');
      // Nếu không có mạng hoặc lỗi, tải từ bộ nhớ đệm
      final cached = await _loadTravelDaysCache();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<TravelLegEntity>> getTravelLegs({
    required dynamic userId,
    required String workDate,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$_travelLegsCachePrefix${userId}_$workDate';
    try {
      final remoteLegs = await _apiService.getTravelLegs(
        userId: userId,
        workDate: workDate,
      );

      if (remoteLegs.isNotEmpty) {
        _saveTravelLegsCache(cacheKey, remoteLegs);
      }

      return remoteLegs;
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi tải chặng từ API: $e. Sử dụng dữ liệu bộ nhớ đệm.');
      final cached = await _loadTravelLegsCache(cacheKey);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  // --- Cache helpers ---

  Future<void> _saveTravelDaysCache(List<TravelDayModel> days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = days.map((e) => e.toJson()).toList();
      await prefs.setString(_travelDaysCacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi lưu cache ngày: $e');
    }
  }

  Future<List<TravelDayEntity>> _loadTravelDaysCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_travelDaysCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => TravelDayModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi đọc cache ngày: $e');
    }
    return const [];
  }

  Future<void> _saveTravelLegsCache(String key, List<TravelLegModel> legs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = legs.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi lưu cache chặng: $e');
    }
  }

  Future<List<TravelLegEntity>> _loadTravelLegsCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => TravelLegModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[TravelRepository] Lỗi đọc cache chặng: $e');
    }
    return const [];
  }
}

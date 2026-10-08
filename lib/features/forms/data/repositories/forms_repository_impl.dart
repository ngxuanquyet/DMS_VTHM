import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/system_clock.dart';
import '../../domain/entities/market_form_entity.dart';
import '../../domain/repositories/forms_repository.dart';
import '../models/market_form_model.dart';
import '../models/market_form_submission_model.dart';
import '../services/forms_api_service.dart';

class FormsRepositoryImpl implements FormsRepository {
  final FormsApiService _apiService;
  final AppDatabase _db;

  FormsRepositoryImpl(this._apiService, this._db);

  @override
  Future<List<MarketFormConfigEntity>> getAvailableForms({
    required String kind,
    int? customerId,
  }) async {
    final cacheKey = 'dms_market_forms_${kind}_${customerId ?? 0}';

    try {
      final models = await _apiService.getAvailableForms(
        kind: kind,
        customerId: customerId,
      );

      // Lưu cache cục bộ phục vụ chế độ offline
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawJson = jsonEncode(models.map((m) => m.toJson()).toList());
        await prefs.setString(cacheKey, rawJson);
      } catch (cacheErr) {
        debugPrint('[FormsRepository] Lỗi lưu cache biểu mẫu: $cacheErr');
      }

      return models.map((m) => m.toEntity()).toList();
    } catch (e) {
      debugPrint('[FormsRepository] Không kết nối được server, đọc cache cục bộ: $e');
      // Đọc từ cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          final list = jsonDecode(cached) as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => MarketFormConfigModel.fromJson(item).toEntity())
              .toList();
        }
      } catch (readErr) {
        debugPrint('[FormsRepository] Lỗi đọc cache: $readErr');
      }

      rethrow;
    }
  }

  @override
  Future<MarketFormSubmitResult> submitForm(
    MarketFormSubmissionModel submission, {
    bool isOffline = false,
  }) async {
    if (isOffline) {
      return _saveToSyncQueue(submission);
    }

    try {
      return await _apiService.submitForm(submission);
    } catch (e) {
      debugPrint('[FormsRepository] Nộp trực tiếp thất bại, chuyển vào hàng đợi offline: $e');
      return _saveToSyncQueue(submission);
    }
  }

  Future<MarketFormSubmitResult> _saveToSyncQueue(
    MarketFormSubmissionModel submission,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Đảm bảo đánh dấu is_offline_sync: true trong payload lưu trữ
    final offlinePayload = submission.toJson();
    offlinePayload['is_offline_sync'] = true;

    await _db.enqueue(
      SyncQueueEntriesCompanion(
        entity: const Value('form_submission'),
        op: const Value('create'),
        clientUuid: Value(submission.clientUuid),
        parentUuid: submission.parentUuid != null ? Value(submission.parentUuid) : const Value.absent(),
        payload: Value(jsonEncode(offlinePayload)),
        state: const Value('pending'),
        createdAt: Value(nowMs),
        createdElapsed: Value(SystemClock.nowMonotonicMs),
        bootId: Value(SystemClock.bootId),
        attempts: const Value(0),
      ),
    );

    return const MarketFormSubmitResult(
      success: true,
      message: 'Đã lưu phiếu trên máy. Dữ liệu sẽ tự động gửi khi có mạng trở lại.',
    );
  }
}

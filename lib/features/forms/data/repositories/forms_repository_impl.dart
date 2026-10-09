import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/system_clock.dart';
import '../../domain/entities/market_form_entity.dart';
import '../../domain/repositories/forms_repository.dart';
import '../models/form_photo_model.dart';
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
  Future<FormPhotoModel> uploadPhoto(dynamic file) async {
    final f = file is File ? file : File(file.toString());
    return await _apiService.uploadPhoto(f);
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
      final errStr = e.toString().toLowerCase();
      // §5 & §6: Nếu server báo không tìm thấy ảnh (do bị dọn rác), tự động tải lại ảnh gốc từ máy
      if ((errStr.contains('không tìm thấy ảnh') || errStr.contains('không tìm thấy ảnh vừa tải lên')) &&
          submission.localPhotoPaths != null &&
          submission.localPhotoPaths!.isNotEmpty) {
        try {
          debugPrint('[FormsRepository] Phát hiện ảnh bị dọn rác, tự động tải lại ảnh gốc từ máy...');
          final updatedAnswers = Map<String, dynamic>.from(submission.answers);
          for (final entry in submission.localPhotoPaths!.entries) {
            final fieldCode = entry.key;
            final paths = entry.value;
            final newTokens = <String>[];
            for (final p in paths) {
              final file = File(p);
              if (await file.exists()) {
                final photoResult = await _apiService.uploadPhoto(file);
                newTokens.add(photoResult.token);
              }
            }
            if (newTokens.isNotEmpty) {
              updatedAnswers[fieldCode] = newTokens;
            }
          }
          final retrySubmission = MarketFormSubmissionModel(
            configId: submission.configId,
            visitId: submission.visitId,
            customerId: submission.customerId,
            answers: updatedAnswers,
            submitLat: submission.submitLat,
            submitLng: submission.submitLng,
            submitAddress: submission.submitAddress,
            parentUuid: submission.parentUuid,
            clientUuid: submission.clientUuid,
            clientTime: submission.clientTime,
            isOfflineSync: submission.isOfflineSync,
            localPhotoPaths: submission.localPhotoPaths,
          );
          return await _apiService.submitForm(retrySubmission);
        } catch (retryErr) {
          debugPrint('[FormsRepository] Thử tải lại ảnh và nộp lại thất bại: $retryErr');
        }
      }

      debugPrint('[FormsRepository] Nộp trực tiếp thất bại, chuyển vào hàng đợi offline: $e');
      return _saveToSyncQueue(submission);
    }
  }

  Future<MarketFormSubmitResult> _saveToSyncQueue(
    MarketFormSubmissionModel submission,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // §5: Đảm bảo lưu cả đường dẫn ảnh cục bộ _local_photo_paths vào hàng đợi offline
    final offlinePayload = submission.toJson(includeInternal: true);
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

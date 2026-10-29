import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/local_history_retention.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/account_key.dart';
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

  /// Lượt tải biểu mẫu đang chạy theo khoá bản lưu — xem [getAvailableForms].
  final Map<String, Future<List<MarketFormConfigModel>>> _inflight = {};
  final Set<String> _backgroundSaves = {};

  /// Trần chờ server khi tải biểu mẫu (mobile-rules `forms.fetch_timeout_seconds`); không truyền ⇒ 5 giây.
  final Duration Function() _fetchTimeout;

  FormsRepositoryImpl(this._apiService, this._db, {Duration Function()? fetchTimeout})
      : _fetchTimeout = fetchTimeout ?? (() => const Duration(seconds: 5));

  @override
  Future<List<MarketFormConfigEntity>> getAvailableForms({
    required String kind,
    int? customerId,
  }) async {
    // TÁCH theo tài khoản: biểu mẫu mang giá trị "tự điền theo phòng ban" (`config.default`) và danh sách kênh đã thu
    // hẹp theo phòng của người tải về — người sau dùng chung máy mà đọc nhầm bản này khi mất mạng là điền sai phòng.
    // Chưa rõ tài khoản ⇒ không đọc/ghi bản lưu ([cacheAccountKey]). `logout()` xoá mọi khoá `dms_market_forms_*`.
    final account = cacheAccountKey(await SharedPreferences.getInstance());
    final cacheKey = account == null ? null : 'dms_market_forms_${account}_${kind}_${customerId ?? 0}';

    try {
      // Mở đi mở lại khi mạng chậm ⇒ dùng chung lượt tải đang chạy của cùng bản lưu (không chồng nhiều lượt, bản cũ về
      // sau ghi đè bản mới).
      final inflightKey = cacheKey ?? '$kind/${customerId ?? 0}';
      final fetch = _inflight[inflightKey] ??= _apiService
          .getAvailableForms(kind: kind, customerId: customerId)
          // Khối lệnh, KHÔNG `=> _inflight.remove(...)`: remove trả lại chính Future này, whenComplete sẽ chờ nó ⇒ tự chờ
          // chính mình, treo vĩnh viễn.
          .whenComplete(() {
            _inflight.remove(inflightKey);
          });
      // Chờ server có TRẦN (tham số `forms.fetch_timeout_seconds`, mobile-rules): mạng yếu thì trước đây đứng chờ tới
      // hết quá giờ 15s mới được dùng bản trong máy. Quá trần mà CÓ bản lưu ⇒ mở bản lưu ngay, lượt tải chạy tiếp
      // ngầm rồi ghi đè bản lưu; chưa có bản lưu thì chờ tiếp như cũ.
      List<MarketFormConfigModel> models;
      try {
        models = await fetch.timeout(_fetchTimeout());
      } on TimeoutException {
        final cached = await _readCached(cacheKey, account);
        if (cached == null) {
          models = await fetch;
        } else {
          // Nhiều lượt cùng chờ một lượt tải ⇒ chỉ MỘT lần ghi bản lưu ngầm.
          if (_backgroundSaves.add(inflightKey)) {
            unawaited(fetch
                .then((fresh) => _saveCacheIfSameAccount(fresh, cacheKey, account))
                .catchError((Object e) {
              debugPrint('[FormsRepository] Làm mới biểu mẫu ngầm lỗi: $e');
            }).whenComplete(() {
              _backgroundSaves.remove(inflightKey);
            }));
          }
          return cached;
        }
      }

      // 🔴 Đổi tài khoản trong lúc chờ mạng ⇒ đây là biểu mẫu (tự điền, kênh thu hẹp) của người CŨ: không ghi lại bản lưu
      // mà logout() vừa xoá, và tải lại cho người đang đăng nhập. Phiên vừa hết (null) thì trả luôn, đừng gọi lại không token.
      final accountNow = cacheAccountKey(await SharedPreferences.getInstance());
      if (accountNow != account) {
        if (accountNow == null) return <MarketFormConfigEntity>[];
        return await getAvailableForms(kind: kind, customerId: customerId);
      }

      // Lưu cache cục bộ phục vụ chế độ offline
      await _saveCacheIfSameAccount(models, cacheKey, account);

      return models.map((m) => m.toEntity()).toList();
    } catch (e) {
      debugPrint('[FormsRepository] Không kết nối được server, đọc cache cục bộ: $e');
      // Đổi sang tài khoản KHÁC trong lúc chờ ⇒ làm lại cho người đang đăng nhập (đọc đúng bản lưu của họ).
      final nowAccount = cacheAccountKey(await SharedPreferences.getInstance());
      if (nowAccount != account && nowAccount != null) {
        return await getAvailableForms(kind: kind, customerId: customerId);
      }
      final cached = await _readCached(cacheKey, account);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Bản biểu mẫu đã lưu — CHỈ của tài khoản đang đăng nhập (đổi tài khoản giữa chừng thì khoá lúc đầu là của người cũ).
  /// `null` khi chưa có / đọc hỏng.
  Future<List<MarketFormConfigEntity>?> _readCached(String? cacheKey, String? account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = cacheKey == null || cacheAccountKey(prefs) != account ? null : prefs.getString(cacheKey);
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
    return null;
  }

  /// Ghi bản lưu — bỏ qua nếu đã đổi tài khoản (bản này của người cũ; logout() vừa xoá bản lưu).
  Future<void> _saveCacheIfSameAccount(List<MarketFormConfigModel> models, String? cacheKey, String? account) async {
    if (cacheKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cacheAccountKey(prefs) != account) return;
      await prefs.setString(cacheKey, jsonEncode(models.map((m) => m.toJson()).toList()));
      await LocalHistoryRetention.touchFormsCache(prefs, cacheKey);
    } catch (cacheErr) {
      debugPrint('[FormsRepository] Lỗi lưu cache biểu mẫu: $cacheErr');
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
    // Kiểm tra xem trong answers có ảnh nào chưa có token (đang lưu tạm localPath) không
    bool hasPendingLocalPhotos = false;
    submission.answers.forEach((k, v) {
      if (v is List) {
        for (final item in v) {
          final str = item.toString();
          if (str.contains('/') || str.contains(r'\') || str.length != 32) {
            hasPendingLocalPhotos = true;
          }
        }
      }
    });

    if (isOffline || hasPendingLocalPhotos) {
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
      message: 'Đã lưu phiếu! Dữ liệu và ảnh đang được tải lên chạy nền.',
    );
  }
}

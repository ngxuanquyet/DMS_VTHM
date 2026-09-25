import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/form_draft_model.dart';

final formDraftServiceProvider = Provider<FormDraftService>((ref) {
  return FormDraftService();
});

/// Provider danh sách bản nháp hiện có
final formDraftsListProvider =
    FutureProvider.autoDispose<List<FormDraft>>((ref) async {
  final service = ref.watch(formDraftServiceProvider);
  return service.getDrafts();
});

/// Provider đếm tổng số bản nháp
final formDraftsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final drafts = await ref.watch(formDraftsListProvider.future);
  return drafts.length;
});

class FormDraftService {
  static const String _keyDrafts = 'dms_market_form_drafts_v1';

  /// Lấy toàn bộ danh sách bản nháp
  Future<List<FormDraft>> getDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyDrafts);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final drafts = list
          .whereType<Map<String, dynamic>>()
          .map((item) => FormDraft.fromJson(item))
          .toList();

      // Sắp xếp bản nháp mới nhất lên đầu
      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  /// Lưu hoặc cập nhật một bản nháp
  Future<void> saveDraft(FormDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();

    final index = drafts.indexWhere((d) => d.id == draft.id);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.insert(0, draft);
    }

    final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDrafts, raw);
  }

  /// Xóa bản nháp theo ID
  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();

    drafts.removeWhere((d) => d.id == id);
    final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDrafts, raw);
  }

  /// Xóa bản nháp theo configId và customerId (sau khi đã nộp phiếu thành công)
  Future<void> deleteDraftByConfig(int configId, {int? customerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();

    drafts.removeWhere(
      (d) => d.configId == configId && d.customerId == customerId,
    );
    final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDrafts, raw);
  }
}

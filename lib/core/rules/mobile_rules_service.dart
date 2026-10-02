import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'mobile_rules_model.dart';

final mobileRulesProvider =
    StateNotifierProvider<MobileRulesNotifier, MobileRules>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return MobileRulesNotifier(apiClient);
});

class MobileRulesNotifier extends StateNotifier<MobileRules> {
  final ApiClient _apiClient;
  static const String cacheKey = 'dms_mobile_rules_cache_v1';

  MobileRulesNotifier(this._apiClient) : super(const MobileRules()) {
    _loadFromCache();
  }

  /// Tải luật đã lưu trong máy để app có giá trị ngay cả khi chưa có mạng
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final json = jsonDecode(cachedStr) as Map<String, dynamic>;
        state = MobileRules.fromJson(json);
      }
    } catch (e) {
      debugPrint('[MobileRules] Lỗi đọc cache quy tắc: $e');
    }
  }

  /// Gọi GET /dms/mobile-rules để đọc cấu hình mới nhất từ server (§1)
  /// Lưu bản sao vào máy; không bao giờ crash nếu mất sóng
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async {
    try {
      final response = await _apiClient.get('/dms/mobile-rules');
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final rules = MobileRules.fromJson(data);
          state = rules;

          // Lưu bản sao trong máy (§1.3)
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(cacheKey, jsonEncode(rules.toJson()));
          } catch (_) {}

          return rules;
        }
      }
    } catch (e) {
      debugPrint('[MobileRules] Không thể tải luật từ server (dùng bản lưu): $e');
    }
    return state;
  }
}

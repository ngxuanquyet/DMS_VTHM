import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'mobile_rules_model.dart';

final mobileRulesProvider =
    StateNotifierProvider<MobileRulesNotifier, MobileRules>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return MobileRulesNotifier(apiClient);
});

class MobileRulesNotifier extends StateNotifier<MobileRules> with WidgetsBindingObserver {
  final ApiClient _apiClient;
  static const String cacheKey = 'dms_mobile_rules_cache_v1';
  bool _isFetching = false;

  MobileRulesNotifier(this._apiClient) : super(const MobileRules()) {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    _init();
  }

  void setRules(MobileRules rules) {
    state = rules;
  }

  /// Đọc nhanh quy tắc từ SharedPreferences
  static Future<MobileRules?> getCachedRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final json = jsonDecode(cachedStr) as Map<String, dynamic>;
        return MobileRules.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Khi người dùng quay lại app từ màn hình khác, tự động đồng bộ lại luật
      fetchRules();
    }
  }

  Future<void> _init() async {
    // 1. Tải trước từ cache để có ngay quy tắc phục vụ offline hoặc khởi động tức thì
    await _loadFromCache();
    // 2. Tự động đồng bộ ngay từ server để lấy dữ liệu mới nhất nếu có mạng
    await fetchRules();
  }

  /// Tải luật đã lưu trong máy để app có giá trị ngay cả khi chưa có mạng
  Future<MobileRules> _loadFromCache() async {
    try {
      final cached = await getCachedRules();
      if (cached != null) {
        state = cached;
        debugPrint('[MobileRules] Đã nạp quy tắc từ cache: minDuration=${state.visit.minDurationMinutes}, defaultRadiusM=${state.visit.defaultRadiusM}');
      }
    } catch (e) {
      debugPrint('[MobileRules] Lỗi đọc cache quy tắc: $e');
    }
    return state;
  }

  /// Gọi GET /dms/mobile-rules để đọc cấu hình mới nhất từ server (§1)
  /// Lưu bản sao vào máy; không bao giờ crash nếu mất sóng
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async {
    if (_isFetching && !forceRefresh) return state;
    _isFetching = true;
    try {
      final response = await _apiClient.get('/dms/mobile-rules');
      if (response is Map) {
        final rawData = response['data'] is Map ? response['data'] : response;
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          final rules = MobileRules.fromJson(data);
          state = rules;

          // Lưu bản sao trong máy (§1.3)
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(cacheKey, jsonEncode(rules.toJson()));
            debugPrint('[MobileRules] Đã cập nhật và lưu cache luật mới: minDuration=${rules.visit.minDurationMinutes}, defaultRadiusM=${rules.visit.defaultRadiusM}');
          } catch (_) {}

          return rules;
        }
      }
    } catch (e) {
      debugPrint('[MobileRules] Không thể tải luật từ server (dùng bản lưu): $e');
      // Khi mất sóng hoặc lỗi mạng, đảm bảo nạp lại từ cache bản lưu
      await _loadFromCache();
    } finally {
      _isFetching = false;
    }
    return state;
  }
}

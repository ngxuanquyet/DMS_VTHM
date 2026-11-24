import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/account_key.dart';
import '../models/location_ping_point_model.dart';

/// Lưu trữ và quản lý hàng đợi toạ độ ngoại tuyến theo §4 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class EmployeeTrackingLocalStorage {
  /// Hàng đợi THEO TÀI KHOẢN (rà soát 24/11/2026): khoá chung cũ làm người đăng nhập SAU gửi điểm GPS của người trước bằng
  /// token của mình (server ghi theo người của token). Chưa rõ tài khoản ⇒ không đọc / ghi gì.
  static const String _queuePrefix = 'dms_location_pending_queue_v2_';

  /// Khoá chung đời cũ — điểm trong đó không rõ của ai ⇒ bỏ.
  static const String _legacyQueueKey = 'dms_location_pending_queue_v1';

  static String? _queueKey(SharedPreferences prefs) {
    final account = cacheAccountKey(prefs);
    return account == null ? null : '$_queuePrefix$account';
  }
  static const int _maxQueueCapacity = 200;

  /// Đưa 1 điểm vào hàng đợi
  Future<void> enqueuePoint(LocationPingPointModel point) async {
    await enqueuePoints([point]);
  }

  /// Đưa danh sách điểm vào hàng đợi (tự động loại bỏ điểm quá hạn hoặc trùng client_uuid)
  Future<void> enqueuePoints(List<LocationPingPointModel> newPoints) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentPoints = await getAllPoints();

      final seenUuids = currentPoints.map((p) => p.clientUuid).toSet();
      final filteredNew = <LocationPingPointModel>[];
      for (final p in newPoints) {
        if (!seenUuids.contains(p.clientUuid)) {
          seenUuids.add(p.clientUuid);
          filteredNew.add(p);
        }
      }

      final merged = [...currentPoints, ...filteredNew];

      // Dọn dẹp các điểm quá cũ (lớn hơn 6 giờ) theo quy định §4
      final now = DateTime.now();
      final validPoints = merged.where((p) {
        try {
          final measured = DateTime.parse(p.clientTime);
          return now.difference(measured).inHours < 6;
        } catch (_) {
          return true;
        }
      }).toList();

      // Giới hạn trần 200 điểm
      final bounded = validPoints.length > _maxQueueCapacity
          ? validPoints.sublist(validPoints.length - _maxQueueCapacity)
          : validPoints;

      final key = _queueKey(prefs);
      if (key == null) return;
      final jsonStr = jsonEncode(bounded.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('[TrackingLocalStorage] Lỗi lưu hàng đợi vị trí: $e');
    }
  }

  /// Lấy toàn bộ danh sách điểm trong hàng đợi
  Future<List<LocationPingPointModel>> getAllPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_legacyQueueKey)) await prefs.remove(_legacyQueueKey);
      final key = _queueKey(prefs);
      final jsonStr = key == null ? null : prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => LocationPingPointModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TrackingLocalStorage] Lỗi đọc hàng đợi: $e');
      return [];
    }
  }

  /// Lấy tối đa limit điểm (mặc định 200 điểm theo trần kỹ thuật của API)
  Future<List<LocationPingPointModel>> getPendingBatch({int limit = 200}) async {
    final all = await getAllPoints();
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  /// Xoá các điểm đã gửi thành công hoặc duplicated khỏi hàng đợi theo client_uuid
  Future<void> removeByClientUuids(Iterable<String> clientUuids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllPoints();
      final toRemove = clientUuids.toSet();

      final remaining = all.where((p) => !toRemove.contains(p.clientUuid)).toList();
      final key = _queueKey(prefs);
      if (key == null) return;
      final jsonStr = jsonEncode(remaining.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('[TrackingLocalStorage] Lỗi xoá điểm khỏi hàng đợi: $e');
    }
  }

  /// Xoá toàn bộ hàng đợi
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _queueKey(prefs);
      if (key != null) await prefs.remove(key);
    } catch (_) {}
  }

  /// Đếm số điểm đang chờ
  Future<int> getPendingCount() async {
    final all = await getAllPoints();
    return all.length;
  }
}

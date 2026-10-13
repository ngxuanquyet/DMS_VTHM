import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_ping_point_model.dart';

/// Lưu trữ và quản lý hàng đợi toạ độ ngoại tuyến theo §4 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class EmployeeTrackingLocalStorage {
  static const String _queueKey = 'dms_location_pending_queue_v1';
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

      final jsonStr = jsonEncode(bounded.map((e) => e.toJson()).toList());
      await prefs.setString(_queueKey, jsonStr);
    } catch (e) {
      debugPrint('[TrackingLocalStorage] Lỗi lưu hàng đợi vị trí: $e');
    }
  }

  /// Lấy toàn bộ danh sách điểm trong hàng đợi
  Future<List<LocationPingPointModel>> getAllPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_queueKey);
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
      final jsonStr = jsonEncode(remaining.map((e) => e.toJson()).toList());
      await prefs.setString(_queueKey, jsonStr);
    } catch (e) {
      debugPrint('[TrackingLocalStorage] Lỗi xoá điểm khỏi hàng đợi: $e');
    }
  }

  /// Xoá toàn bộ hàng đợi
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (_) {}
  }

  /// Đếm số điểm đang chờ
  Future<int> getPendingCount() async {
    final all = await getAllPoints();
    return all.length;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/visit_entity.dart';

/// Bộ đệm lượt trong máy (lượt đang mở + lịch sử ~60 ngày, có toạ độ check-out — dữ liệu vị trí, Luật 91/2025) của MỘT tài
/// khoản (#24728). Khoá chung [activeKey] / [listKey] luôn là của CHỦ hiện tại ([ownerKey], đổi lúc đăng nhập —
/// [switchOwner]); của người khác cất ở `<khoá>_u<id>`. [owner] null ⇒ chủ hiện tại LÚC THAO TÁC; có [owner] ⇒ ghi đúng ngăn
/// của người đó dù chủ đã đổi giữa chừng: thao tác chờ mạng chốt chủ TRƯỚC `await` ([current]), hàng đợi đồng bộ dùng chủ
/// của dòng — kẻo kết quả của người trước rơi vào bộ đệm người sau (bản thử 02/11 khoá theo hồ sơ hiện tại rơi đúng ca này).
/// Mọi thao tác đọc–sửa–ghi và đổi chủ làm trọn trong MỘT đoạn đồng bộ (không `await` giữa đọc và lời gọi ghi —
/// SharedPreferences cập nhật bộ nhớ ngay lúc gọi `setString`): đổi chủ chen giữa đọc và ghi là mất bản ghi / ghi nhầm ngăn.
/// KHÔNG dùng khoá bằng Future tĩnh: Future dùng chung giữa các vùng (zone) treo vĩnh viễn khi vùng cũ không còn chạy.
class VisitLocalStore {
  static const String activeKey = 'dms_active_visit_session_v1';
  static const String listKey = 'dms_visits_local_cache_v2';
  static const String ownerKey = 'dms_visits_local_owner';

  /// Mốc chủ sau khi TỰ đăng xuất ([clearCurrentOwner]): bộ đệm chung trống, chưa ai — ghi như máy chưa ghi chủ (khoá chung).
  static const int _nobody = 0;

  /// Danh sách tài khoản đã TỰ đăng xuất (xoá dữ liệu của mình khỏi máy) mà chưa đăng nhập lại: lần ghi muộn của ngăn chốt cho
  /// họ (tải tuyến, gửi lượt về muộn — kể cả sau khi người khác đã đăng nhập) bị BỎ, không dựng lại ngăn vừa xoá.
  static const String clearedKey = 'dms_visits_local_cleared';
  static const int _clearedMax = 50;

  /// [_clearedMax] phần tử CUỐI (mới nhất) của [list].
  static List<String> _keepNewest(List<String> list) =>
      list.length <= _clearedMax ? list : list.sublist(list.length - _clearedMax);

  /// Tài khoản (`usr_user.id`) sở hữu bộ đệm này; `null` = chủ hiện tại lúc thao tác.
  final int? owner;

  const VisitLocalStore([this.owner]);

  /// Ngăn của chủ HIỆN TẠI, chốt ngay — gọi TRƯỚC `await` mạng.
  static Future<VisitLocalStore> current() async {
    try {
      final current = (await SharedPreferences.getInstance()).getInt(ownerKey);
      return VisitLocalStore(current == _nobody ? null : current);
    } catch (_) {
      return const VisitLocalStore(); // không đọc được mốc chủ ⇒ chủ hiện tại lúc thao tác (như trước)
    }
  }

  /// Lần ghi của ngăn này phải BỎ: chủ đã chốt nằm trong [clearedKey] (tự đăng xuất sau khi chốt, chưa đăng nhập lại).
  bool _dropped(SharedPreferences prefs) =>
      owner != null && (prefs.getStringList(clearedKey)?.contains('$owner') ?? false);

  /// Máy chưa ghi chủ (bản app cũ, chưa ai đăng nhập từ khi nâng cấp) ⇒ khoá chung. «Chưa ai» sau khi tự đăng xuất ⇒ khoá
  /// chung chỉ cho ngăn không chốt chủ; ngăn của một người cụ thể vào ngăn cất của họ (đăng nhập lại là lấy về).
  String _key(SharedPreferences prefs, String base) {
    final current = prefs.getInt(ownerKey);
    return owner == null || current == null || owner == current ? base : '${base}_u$owner';
  }

  /// Đổi chủ khi [userId] đăng nhập: cất bản của chủ trước sang ngăn riêng, lấy lại ngăn đã cất của người mới. Máy chưa ghi
  /// chủ (bản app cũ trước #24698 vòng 8) ⇒ giữ nguyên bản đang có (giao cho người đăng nhập đầu tiên, như hàng đợi). Vừa tự
  /// đăng xuất ([_nobody]) ⇒ không cất gì, lấy ngăn của người mới.
  static Future<void> switchOwner(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    // Từ đây tới hết vòng lặp: chỉ đọc đồng bộ + GỌI ghi (không await) — trọn một đoạn đồng bộ.
    final writes = <Future<bool>>[];
    final previous = prefs.getInt(ownerKey);
    if (previous != userId) {
      for (final key in const [activeKey, listKey]) {
        if (previous != null && previous != _nobody) {
          final mine = prefs.getString(key);
          writes.add(mine != null ? prefs.setString('${key}_u$previous', mine) : prefs.remove('${key}_u$previous'));
        }
        // Máy chưa từng ghi chủ (bản app cũ) ⇒ bộ đệm chung giao cho người đăng nhập đầu tiên, không đụng gì.
        if (previous == null) continue;
        final stashed = prefs.getString('${key}_u$userId');
        if (stashed != null) {
          writes
            ..add(prefs.setString(key, stashed))
            ..add(prefs.remove('${key}_u$userId'));
        } else {
          writes.add(prefs.remove(key));
        }
      }
    }
    writes.add(prefs.setInt(ownerKey, userId));
    final cleared = prefs.getStringList(clearedKey);
    if (cleared != null && cleared.contains('$userId')) {
      writes.add(prefs.setStringList(clearedKey, [...cleared]..remove('$userId')));
    }
    await Future.wait(writes);
  }

  /// TỰ đăng xuất (máy có thể trao người khác; lượt đang mở và hàng đợi đã được kiểm là trống): bỏ bộ đệm lượt của chủ hiện
  /// tại, mốc chủ thành «không ai» ([_nobody]) — không để lịch sử có toạ độ của người này nằm lại máy. Ngăn đã cất của người KHÁC giữ nguyên (họ vào
  /// lại là thấy). Đăng xuất cưỡng bức KHÔNG gọi: đúng người đăng nhập lại là thấy lại lượt đang làm dở.
  static Future<void> clearCurrentOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getInt(ownerKey);
    final cleared = prefs.getStringList(clearedKey) ?? const <String>[];
    await Future.wait([
      for (final key in const [activeKey, listKey]) ...[
        prefs.remove(key),
        if (owner != null) prefs.remove('${key}_u$owner'),
      ],
      // Giữ tối đa [_clearedMax] người gần nhất — người rời máy lâu không còn thao tác nào đang chờ mạng.
      if (owner != null && owner != _nobody && !cleared.contains('$owner'))
        prefs.setStringList(clearedKey, _keepNewest([...cleared, '$owner'])),
      prefs.setInt(ownerKey, _nobody),
    ]);
  }

  List<VisitEntity> _readAll(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key(prefs, listKey));
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final visits = list.whereType<Map<String, dynamic>>().map((e) => VisitEntity.fromJson(e)).toList();
        _sortNewest(visits);
        return visits;
      }
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi đọc danh sách lượt viếng thăm cục bộ: $e');
    }
    return const [];
  }

  static void _sortNewest(List<VisitEntity> visits) => visits.sort((a, b) {
    final aTime = a.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });

  Future<void> _writeAll(SharedPreferences prefs, List<VisitEntity> visits) async {
    if (_dropped(prefs)) return;
    await prefs.setString(_key(prefs, listKey), jsonEncode(visits.map((e) => e.toJson()).toList()));
  }

  Future<List<VisitEntity>> getAll() async => _readAll(await SharedPreferences.getInstance());

  Future<void> saveVisit(VisitEntity visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = List<VisitEntity>.from(_readAll(prefs));
      final idx = updated.indexWhere(
        (v) =>
            v.id == visit.id || (visit.clientUuid != null && v.clientUuid != null && v.clientUuid == visit.clientUuid),
      );
      if (idx >= 0) {
        updated[idx] = visit;
      } else {
        updated.insert(0, visit);
      }
      _sortNewest(updated);
      await _writeAll(prefs, updated);
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi lưu lượt viếng thăm cục bộ: $e');
    }
  }

  Future<void> saveVisits(List<VisitEntity> visits) async {
    if (visits.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <int, VisitEntity>{for (final v in _readAll(prefs)) v.id: v};
      for (final v in visits) {
        final existing = map[v.id];
        // Không ghi đè lượt đã bị huỷ cục bộ bằng bản ghi cũ từ server (khi server chưa kịp nhận cancel)
        if (existing != null && existing.isCancelled && !v.isCancelled) continue;
        map[v.id] = v;
      }
      final merged = map.values.toList();
      _sortNewest(merged);
      await _writeAll(prefs, merged);
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi lưu danh sách lượt viếng thăm: $e');
    }
  }

  /// Sửa lượt đầu tiên khớp [match] bằng [change] — đọc và ghi trong MỘT đoạn đồng bộ (đọc rồi `await` rồi mới ghi thì đổi
  /// chủ chen giữa làm bản sửa rơi vào bộ đệm người sau, hoặc đè mất lần ghi khác bằng bản cũ). Không có ⇒ không làm gì.
  Future<void> updateVisit(bool Function(VisitEntity) match, VisitEntity Function(VisitEntity) change) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = List<VisitEntity>.from(_readAll(prefs));
      final idx = all.indexWhere(match);
      if (idx < 0) return;
      all[idx] = change(all[idx]);
      _sortNewest(all);
      await _writeAll(prefs, all);
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi sửa lượt viếng thăm cục bộ: $e');
    }
  }

  /// Sửa lượt đang mở bằng [change] nếu nó khớp [match] (cùng một đoạn đồng bộ như [updateVisit]); trả bản đã sửa hoặc null.
  Future<VisitEntity?> updateActive(bool Function(VisitEntity) match, VisitEntity Function(VisitEntity) change) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(prefs, activeKey);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final active = VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!match(active)) return null;
      final updated = change(active);
      if (_dropped(prefs)) return null;
      await prefs.setString(key, jsonEncode(updated.toJson()));
      return updated;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeVisit(int visitId, {String? clientUuid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = _readAll(prefs).where((v) {
        if (v.id == visitId) return false;
        if (clientUuid != null && v.clientUuid == clientUuid) return false;
        return true;
      }).toList();
      await _writeAll(prefs, updated);
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi xoá lượt viếng thăm cục bộ: $e');
    }
  }

  Future<void> saveActive(VisitEntity visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dropped(prefs)) return;
      await prefs.setString(_key(prefs, activeKey), jsonEncode(visit.toJson()));
    } catch (_) {}
  }

  Future<VisitEntity?> getActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(prefs, activeKey);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final entity = VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        // Bản lưu hỏng (không id lượt, không điểm bán). Lượt ngoại tuyến ở điểm bán tạo ngoại tuyến nhận diện điểm bán qua
        // `customer_client_uuid` — GIỮ (xoá là mất lượt đang làm dở, #24698 vòng 2).
        if (entity.id <= 0 && entity.customerId <= 0 && (entity.customerClientUuid?.isEmpty ?? true)) {
          await prefs.remove(key);
          return null;
        }
        return entity;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(prefs, activeKey));
    } catch (_) {}
  }

  /// Xoá lượt đang mở CHỈ khi nó là lượt [visitId] / [clientUuid] (đọc và xoá trong một đoạn đồng bộ — lệnh về lượt A tới muộn
  /// không được xoá lượt B vừa mở).
  Future<void> clearActiveIf(int visitId, String? clientUuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(prefs, activeKey);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final active = VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final uuid = (clientUuid?.isNotEmpty ?? false) ? clientUuid : null;
      if ((visitId > 0 && active.id == visitId) || (uuid != null && active.clientUuid == uuid)) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// Ghi "đã huỷ" cho lượt [visitId] / [clientUuid] trong máy (+ dọn lượt đang mở nếu chính là nó) — trọn MỘT đoạn đồng bộ
  /// (đổi chủ chen giữa hai bước thì lượt đang mở đã dọn mà lịch sử vẫn "chưa huỷ").
  Future<void> markCancelled(int visitId, {String? clientUuid}) async {
    // Khớp theo mã server (>0) hoặc client_uuid khác rỗng — id 0 / uuid rỗng khớp nhầm lượt khác.
    final uuid = (clientUuid?.isNotEmpty ?? false) ? clientUuid : null;
    bool laLuotNay(VisitEntity v) => (visitId > 0 && v.id == visitId) || (uuid != null && v.clientUuid == uuid);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dropped(prefs)) return;
      final writes = <Future<void>>[];
      final activeK = _key(prefs, activeKey);
      final rawActive = prefs.getString(activeK);
      // Bản lưu lượt đang mở hỏng không được chặn việc ghi huỷ vào lịch sử.
      try {
        if (rawActive != null && rawActive.isNotEmpty &&
            laLuotNay(VisitEntity.fromJson(jsonDecode(rawActive) as Map<String, dynamic>))) {
          writes.add(prefs.remove(activeK));
        }
      } catch (_) {}
      final all = List<VisitEntity>.from(_readAll(prefs));
      final idx = all.indexWhere(laLuotNay);
      if (idx >= 0) {
        final now = DateTime.now();
        all[idx] = all[idx].copyWith(cancelledAt: now, cancelledAtRaw: now.toIso8601String());
        writes.add(_writeAll(prefs, all));
      }
      await Future.wait(writes);
    } catch (e) {
      debugPrint('[VisitRepo] Lỗi ghi huỷ lượt cục bộ: $e');
    }
  }
}

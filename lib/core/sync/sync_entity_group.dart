import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/app_database.dart';

/// Đại diện cho một nhóm nghiệp vụ trong hàng đợi ngoại tuyến
/// (Ví dụ: 1 lượt viếng thăm gồm bản ghi check-in + các ảnh thực địa đi kèm)
class GroupedSyncItem {
  final String key;
  final String entityType; // 'visit', 'customer', 'form_submission', 'declaration', 'attendance', 'other'
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int totalEntries;
  final int photoCount;
  final bool isSending;
  final List<SyncQueueEntry> entries;

  const GroupedSyncItem({
    required this.key,
    required this.entityType,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.totalEntries,
    this.photoCount = 0,
    required this.isSending,
    required this.entries,
  });
}

/// Tiện ích gom nhóm các bản ghi kỹ thuật thô của hàng đợi thành các nghiệp vụ kinh doanh
class SyncEntityGroupHelper {
  /// Gom danh sách các bản ghi thô (SyncQueueEntry) thành danh sách các nhóm nghiệp vụ thực tế
  /// (Ví dụ: 1 lượt check-in + 3 ảnh chụp thực địa -> gom thành 1 lượt viếng thăm kèm 3 ảnh)
  static List<GroupedSyncItem> groupEntries(List<SyncQueueEntry> rawEntries) {
    if (rawEntries.isEmpty) return const [];

    final Map<String, List<SyncQueueEntry>> visitBuckets = {};
    final Map<String, List<SyncQueueEntry>> attendanceBuckets = {};
    final List<SyncQueueEntry> customers = [];
    final List<SyncQueueEntry> forms = [];
    final List<SyncQueueEntry> declarations = [];
    final List<SyncQueueEntry> others = [];

    for (final e in rawEntries) {
      if (e.entity == 'visit' || e.entity == 'visit_photo' || e.entity == 'photo' || e.entity == 'visit_material') {
        String? visitKey = e.parentUuid;
        if (visitKey == null || visitKey.isEmpty) {
          if (e.entity == 'visit') {
            visitKey = e.clientUuid;
          } else {
            try {
              final p = jsonDecode(e.payload) as Map<String, dynamic>;
              if (p['visit_id'] != null) {
                visitKey = 'visit_${p['visit_id']}';
              }
            } catch (_) {}
          }
        }
        visitKey ??= e.clientUuid;
        visitBuckets.putIfAbsent(visitKey, () => []).add(e);
      } else if (e.entity == 'attendance_punch' || e.entity == 'attendance_photo') {
        String? attKey = e.parentUuid;
        if (attKey == null || attKey.isEmpty) {
          attKey = e.clientUuid;
        }
        attendanceBuckets.putIfAbsent(attKey, () => []).add(e);
      } else if (e.entity == 'customer') {
        customers.add(e);
      } else if (e.entity == 'form_submission') {
        forms.add(e);
      } else if (e.entity == 'declaration') {
        declarations.add(e);
      } else {
        others.add(e);
      }
    }

    final List<GroupedSyncItem> result = [];

    // 1. Lượt viếng thăm
    for (final entry in visitBuckets.entries) {
      final list = entry.value;
      final visitEntry = list.firstWhere(
        (e) => e.entity == 'visit',
        orElse: () => list.first,
      );
      final photoCount = list.where((e) => e.entity == 'visit_photo' || e.entity == 'photo').length;
      final materialCount = list.where((e) => e.entity == 'visit_material').length;
      final hasCheckout = list.any((e) => e.entity == 'visit' && e.op == 'checkout');
      final isSending = list.any((e) => e.state == 'sending');

      String dealerName = 'Điểm bán';
      try {
        final payload = jsonDecode(visitEntry.payload) as Map<String, dynamic>;
        if (payload['dealer_name'] != null && payload['dealer_name'].toString().trim().isNotEmpty) {
          dealerName = payload['dealer_name'].toString().trim();
        }
      } catch (_) {}

      final subtitleParts = <String>[];
      if (hasCheckout) {
        subtitleParts.add('Đã check-out');
      }
      if (photoCount > 0) {
        subtitleParts.add('Kèm $photoCount ảnh');
      }
      if (materialCount > 0) {
        subtitleParts.add('$materialCount thao tác vật tư');
      }
      subtitleParts.add(isSending ? 'Đang gửi' : 'Chờ gửi');

      result.add(
        GroupedSyncItem(
          key: entry.key,
          entityType: 'visit',
          title: 'Lượt viếng thăm: $dealerName',
          subtitle: subtitleParts.join(' • '),
          icon: Icons.location_on_rounded,
          color: const Color(0xFF06B6D4),
          bgColor: const Color(0xFFECFEFF),
          totalEntries: list.length,
          photoCount: photoCount,
          isSending: isSending,
          entries: list,
        ),
      );
    }

    // 2. Khách hàng
    for (final c in customers) {
      String name = 'Điểm bán mới';
      String? address;
      String? route;
      try {
        final p = jsonDecode(c.payload) as Map<String, dynamic>;
        if (p['name'] != null && p['name'].toString().trim().isNotEmpty) {
          name = p['name'].toString().trim();
        }
        if (p['address'] != null && p['address'].toString().trim().isNotEmpty) {
          address = p['address'].toString().trim();
        }
        if (p['route'] != null && p['route'].toString().trim().isNotEmpty) {
          route = p['route'].toString().trim();
        }
      } catch (_) {}
      final sub = <String>[];
      if (route != null && route.isNotEmpty) sub.add('Tuyến: $route');
      if (address != null && address.isNotEmpty) sub.add(address);
      sub.add(c.state == 'sending' ? 'Đang gửi' : 'Chờ gửi');

      result.add(
        GroupedSyncItem(
          key: c.clientUuid,
          entityType: 'customer',
          title: 'Thêm điểm bán mới: $name',
          subtitle: sub.join(' • '),
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
          totalEntries: 1,
          isSending: c.state == 'sending',
          entries: [c],
        ),
      );
    }

    // 3. Biểu mẫu thị trường
    for (final f in forms) {
      String formTitle = 'Biểu mẫu thị trường';
      try {
        final p = jsonDecode(f.payload) as Map<String, dynamic>;
        if (p['title'] != null && p['title'].toString().trim().isNotEmpty) {
          formTitle = p['title'].toString().trim();
        } else if (p['form_code'] != null) {
          formTitle = 'Biểu mẫu #${p['form_code']}';
        }
      } catch (_) {}

      result.add(
        GroupedSyncItem(
          key: f.clientUuid,
          entityType: 'form_submission',
          title: formTitle,
          subtitle: f.state == 'sending'
              ? 'Đang gửi lên hệ thống'
              : 'Đã lưu trên máy, tự động gửi khi có mạng',
          icon: Icons.assignment_turned_in_rounded,
          color: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFEFF6FF),
          totalEntries: 1,
          isSending: f.state == 'sending',
          entries: [f],
        ),
      );
    }

    // 4. Khai báo vị trí
    for (final d in declarations) {
      String reason = 'Điểm bán';
      String? addr;
      try {
        final p = jsonDecode(d.payload) as Map<String, dynamic>;
        if (p['reason_name'] != null) reason = p['reason_name'].toString().trim();
        if (p['address'] != null && p['address'].toString().trim().isNotEmpty) {
          addr = p['address'].toString().trim();
        }
      } catch (_) {}

      result.add(
        GroupedSyncItem(
          key: d.clientUuid,
          entityType: 'declaration',
          title: 'Khai báo vị trí: $reason',
          subtitle: addr != null ? '$addr (Chờ gửi)' : 'Chờ gửi lên hệ thống',
          icon: Icons.pin_drop_rounded,
          color: const Color(0xFF0D9488),
          bgColor: const Color(0xFFF0FDFA),
          totalEntries: 1,
          isSending: d.state == 'sending',
          entries: [d],
        ),
      );
    }

    // 5. Chấm công
    for (final entry in attendanceBuckets.entries) {
      final list = entry.value;
      final photoCount = list.where((e) => e.entity == 'attendance_photo').length;
      final isSending = list.any((e) => e.state == 'sending');

      result.add(
        GroupedSyncItem(
          key: entry.key,
          entityType: 'attendance',
          title: 'Lượt chấm công',
          subtitle: photoCount > 0
              ? 'Kèm $photoCount ảnh xác thực • Chờ gửi'
              : 'Đã lưu trên máy, chờ gửi',
          icon: Icons.access_time_filled_rounded,
          color: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
          totalEntries: list.length,
          photoCount: photoCount,
          isSending: isSending,
          entries: list,
        ),
      );
    }

    // 6. Mục khác
    for (final o in others) {
      result.add(
        GroupedSyncItem(
          key: o.clientUuid,
          entityType: o.entity,
          title: 'Dữ liệu lưu trên máy (${o.entity})',
          subtitle: 'Sẽ tự động gửi khi có mạng',
          icon: Icons.cloud_upload_outlined,
          color: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
          totalEntries: 1,
          isSending: o.state == 'sending',
          entries: [o],
        ),
      );
    }

    return result;
  }

  /// Tạo chuỗi mô tả tóm tắt ngắn gọn các nghiệp vụ đã đồng bộ thành công
  /// (VD: "1 lượt viếng thăm", "1 khách hàng, 1 lượt viếng thăm")
  static String buildSummaryText(List<SyncQueueEntry> entries) {
    if (entries.isEmpty) return '0 tác vụ';
    final grouped = groupEntries(entries);
    if (grouped.isEmpty) return '${entries.length} tác vụ';

    int visitCount = 0;
    int customerCount = 0;
    int formCount = 0;
    int declCount = 0;
    int attCount = 0;
    int otherCount = 0;

    for (final g in grouped) {
      switch (g.entityType) {
        case 'visit':
          visitCount++;
          break;
        case 'customer':
          customerCount++;
          break;
        case 'form_submission':
          formCount++;
          break;
        case 'declaration':
          declCount++;
          break;
        case 'attendance':
          attCount++;
          break;
        default:
          otherCount++;
          break;
      }
    }

    final parts = <String>[];
    if (customerCount > 0) parts.add('$customerCount điểm bán');
    if (visitCount > 0) parts.add('$visitCount lượt viếng thăm');
    if (formCount > 0) parts.add('$formCount biểu mẫu');
    if (declCount > 0) parts.add('$declCount khai báo vị trí');
    if (attCount > 0) parts.add('$attCount lượt chấm công');
    if (otherCount > 0) parts.add('$otherCount tác vụ khác');

    if (parts.isEmpty) {
      return '${grouped.length} tác vụ';
    }
    return parts.join(', ');
  }
}

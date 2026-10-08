import 'package:flutter/material.dart';

/// Thực thể biểu diễn chi tiết 1 Chặng di chuyển trong ngày công
/// Theo đặc tả API-QUANG-DUONG-MOBILE-2026-10-08.md §4.2 & §3
class TravelLegEntity {
  final int id;
  final int seq; // Thứ tự chặng trong ngày, từ 1
  final String legKind; // 'start' | 'between' (không còn 'end')
  final String legKindLabel; // Hiện thẳng từ server, không tự dịch
  final String status; // 'ok' | 'skipped_short' | 'missing_anchor' | 'pending' | 'provider_error'
  final String statusLabel; // Hiện thẳng từ server, không tự dịch
  final String statusColor; // Mã Bootstrap: 'success' | 'danger' | 'warning' | 'info' | 'secondary'
  final String? haversineM; // Đường chim bay (đối chứng)
  final String? roadM; // Đường bộ tính bằng MÉT (null khi pending/provider_error, 0.00 khi missing_anchor)
  final int? fromVisitId;
  final int? toVisitId;
  final int? fromPunchId;
  final int? toPunchId;
  final String? provider;
  final String? errorNote; // 🔴 Dành cho quản trị, KHÔNG hiển thị cho nhân viên (§4.2)

  const TravelLegEntity({
    required this.id,
    required this.seq,
    required this.legKind,
    required this.legKindLabel,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    this.haversineM,
    this.roadM,
    this.fromVisitId,
    this.toVisitId,
    this.fromPunchId,
    this.toPunchId,
    this.provider,
    this.errorNote,
  });

  /// 🔴 §3 & §4.2: DÙNG status ĐỂ QUYẾT ĐỊNH HIỂN THỊ, KHÔNG ĐOÁN TỪ road_m
  /// Ba trạng thái:
  /// - số (vd 8900 m): đã tính xong -> "8.9 km" (✅ đã chốt)
  /// - 0: thiếu mốc -> "0 km" (✅ đã chốt, chi được, cảnh báo)
  /// - null: CHƯA tính -> "—" (❌ chưa chốt, pending hoặc provider_error)
  String get displayDistance {
    switch (status) {
      case 'pending':
      case 'provider_error':
        return '—';
      case 'missing_anchor':
        return '0 km';
      case 'ok':
      case 'skipped_short':
        if (roadM == null) return '—';
        final m = double.tryParse(roadM!);
        if (m == null) return '—';
        return '${(m / 1000.0).toStringAsFixed(1)} km';
      default:
        // Fallback an toàn nếu có status mới
        if (roadM == null) return '—';
        final m = double.tryParse(roadM!);
        if (m == null) return '—';
        if (m == 0) return '0 km';
        return '${(m / 1000.0).toStringAsFixed(1)} km';
    }
  }

  /// Khoảng cách chim bay dạng km
  String? get displayHaversineKm {
    if (haversineM == null) return null;
    final m = double.tryParse(haversineM!);
    if (m == null) return null;
    return '${(m / 1000.0).toStringAsFixed(1)} km';
  }

  /// Trạng thái đã chốt con số hay chưa
  bool get isFinalized =>
      status == 'ok' || status == 'skipped_short' || status == 'missing_anchor';

  /// Thiếu mốc để đo (đã chốt bằng 0)
  bool get isMissingAnchor => status == 'missing_anchor';

  /// Chờ tính
  bool get isPending => status == 'pending';

  /// Lỗi dịch vụ bản đồ
  bool get isProviderError => status == 'provider_error';

  /// Quá ngắn
  bool get isSkippedShort => status == 'skipped_short';

  /// Đã tính xong
  bool get isOk => status == 'ok';

  /// Màu sắc theo mã Bootstrap của server
  Color get statusColorValue {
    switch (statusColor.toLowerCase()) {
      case 'success':
        return const Color(0xFF16A34A); // Green
      case 'danger':
        return const Color(0xFFDC2626); // Red
      case 'warning':
        return const Color(0xFFD97706); // Amber
      case 'info':
        return const Color(0xFF0284C7); // Blue
      case 'secondary':
      default:
        return const Color(0xFF64748B); // Slate / Grey
    }
  }

  /// Màu nền nhạt cho badge
  Color get statusBackgroundColorValue {
    switch (statusColor.toLowerCase()) {
      case 'success':
        return const Color(0xFFDCFCE7);
      case 'danger':
        return const Color(0xFFFEE2E2);
      case 'warning':
        return const Color(0xFFFEF3C7);
      case 'info':
        return const Color(0xFFE0F2FE);
      case 'secondary':
      default:
        return const Color(0xFFF1F5F9);
    }
  }
}

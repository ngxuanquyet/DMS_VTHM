import 'package:intl/intl.dart';

/// Thực thể biểu diễn Quãng đường trong 1 ngày công của nhân viên
/// Theo đặc tả API-QUANG-DUONG-MOBILE-2026-10-08.md §4.1
class TravelDayEntity {
  final int id;
  final int userId;
  final String workDate;
  final String? roadMTotal; // Tổng đường bộ tính bằng MÉT (string hoặc num)
  final num? roadKm; // Đã chia 1000 và làm tròn 1 chữ số — dùng để hiển thị
  final String? haversineMTotal; // Đường chim bay chỉ để đối chứng
  final int legCount; // Tổng số chặng của ngày
  final int legMissingCount; // Số chặng = 0 vì THIẾU MỐC (đã chốt)
  final int legErrorCount; // Số chặng CHƯA ra số (chưa tính / gọi hỏng)
  final bool isComplete; // true khi leg_error_count = 0 => ngày đã chốt
  final String? calculatedAt;

  const TravelDayEntity({
    required this.id,
    required this.userId,
    required this.workDate,
    this.roadMTotal,
    this.roadKm,
    this.haversineMTotal,
    this.legCount = 0,
    this.legMissingCount = 0,
    this.legErrorCount = 0,
    this.isComplete = false,
    this.calculatedAt,
  });

  /// Ngày công dạng DateTime
  DateTime? get parsedWorkDate {
    try {
      return DateTime.parse(workDate);
    } catch (_) {
      return null;
    }
  }

  /// Chuỗi hiển thị thứ ngày tháng tiếng Việt (ví dụ: Thứ Sáu, 04/09/2026)
  String get formattedWorkDate {
    final d = parsedWorkDate;
    if (d == null) return workDate;
    const weekdays = [
      '',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    final dayOfWeek = weekdays[d.weekday];
    return '$dayOfWeek, ${DateFormat('dd/MM/yyyy').format(d)}';
  }

  /// 🔴 §4.1: is_complete = false => ĐỪNG hiện road_km như con số đã chốt.
  /// Ngày đó còn chặng chưa tính, tổng sẽ còn tăng.
  String get displayKmText {
    if (roadKm == null) return '—';
    final kmVal = roadKm!.toDouble();
    if (!isComplete) {
      return '${kmVal.toStringAsFixed(1)} km (tạm tính)';
    }
    return '${kmVal.toStringAsFixed(1)} km';
  }

  /// Số km dạng số đơn thuần
  String get kmOnlyText {
    if (roadKm == null) return '—';
    return '${roadKm!.toDouble().toStringAsFixed(1)} km';
  }

  /// Nhãn trạng thái ngày công
  String get statusBadgeLabel {
    if (legCount == 0) return 'Không có chặng';
    if (isComplete) return 'Đã chốt';
    return 'Còn $legErrorCount chặng chưa tính';
  }

  /// Có chặng thiếu mốc không
  bool get hasMissingAnchors => legMissingCount > 0;

  /// Có chặng lỗi / chưa tính không
  bool get hasPendingErrors => legErrorCount > 0;
}

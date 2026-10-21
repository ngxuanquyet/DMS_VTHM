import 'package:flutter/material.dart';

/// Nhãn loại lượt viếng thăm (`visit_kind_label`, nghiệp vụ 21/10/2026) — chỉ hiện cho lượt
/// "Tạo điểm bán" (`visit_kind == new_outlet`), dùng chung cho danh sách lượt của tôi, lịch sử
/// viếng thăm điểm bán và chi tiết lượt. Màu theo `visit_kind_color` (Bootstrap) đã ánh xạ sẵn.
class VisitKindBadge extends StatelessWidget {
  final String? label;
  final Color? color;
  final double fontSize;

  const VisitKindBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = (label != null && label!.trim().isNotEmpty) ? label!.trim() : 'Tạo điểm bán';
    final c = color ?? const Color(0xFF0284C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_business_rounded, size: fontSize + 1, color: c),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

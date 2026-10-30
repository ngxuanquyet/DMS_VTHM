import 'package:flutter/material.dart';

import '../../data/models/visit_material_model.dart';
import '../../domain/entities/visit_entity.dart';

/// Màu tình trạng vật tư theo mã Bootstrap — dùng chung bảng màu nhãn lượt viếng thăm ([VisitEntity.bootstrapColorOf]);
/// `dark` (Mất) và mã lạ rơi về xám đậm.
Color conditionColor(String bootstrap) => VisitEntity.bootstrapColorOf(bootstrap) ?? const Color(0xFF334155);

class ConditionDot extends StatelessWidget {
  final Color color;
  const ConditionDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Huy hiệu số lượng theo từng tình trạng (🟢4 🟠1), theo thứ tự danh mục.
class MaterialConditionBadges extends StatelessWidget {
  final Map<String, int> counts;
  final List<MaterialCondition> conditions;

  const MaterialConditionBadges({super.key, required this.counts, required this.conditions});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final c in conditions) {
      final n = counts[c.code] ?? 0;
      if (n <= 0) continue;
      final color = conditionColor(c.color);
      chips.add(Tooltip(
        message: c.name,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConditionDot(color: color),
              const SizedBox(width: 4),
              Text('$n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ));
    }
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

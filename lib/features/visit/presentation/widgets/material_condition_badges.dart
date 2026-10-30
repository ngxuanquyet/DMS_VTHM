import 'package:flutter/material.dart';

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

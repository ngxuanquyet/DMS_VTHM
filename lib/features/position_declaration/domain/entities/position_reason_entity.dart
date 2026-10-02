import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Thực thể Lý do khai báo vị trí (GET /dms/position-reasons/active)
/// Theo đặc tả §2 API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md
class PositionReasonEntity {
  final int id;
  final String code;
  final String name;
  final String? color; // Mã Bootstrap: 'success' | 'danger' | 'warning' | 'info' | 'primary' | 'secondary' | 'dark' | null

  const PositionReasonEntity({
    required this.id,
    required this.code,
    required this.name,
    this.color,
  });

  /// Hiển thị mã cạnh tên theo §2: [code] name
  String get displayName => '[$code] $name';

  factory PositionReasonEntity.fromJson(Map<String, dynamic> json) {
    return PositionReasonEntity(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'color': color,
  };

  /// Ánh xạ mã màu Bootstrap sang Color trong ứng dụng Flutter
  Color get colorValue {
    switch (color?.toLowerCase()) {
      case 'success':
        return AppColors.success;
      case 'danger':
        return AppColors.error;
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'info':
        return const Color(0xFF0284C7);
      case 'primary':
        return AppColors.primary;
      case 'secondary':
        return AppColors.secondary;
      case 'dark':
        return const Color(0xFF334155);
      default:
        return AppColors.primary;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionReasonEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

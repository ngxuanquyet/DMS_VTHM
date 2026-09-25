import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hiệu ứng chuyển trang thu phóng (Zoom Transition) nhẹ, mượt mà và phản hồi tức thì
/// khi mở các màn con (Check-in, Chấm công, Thông báo, Thông tin cá nhân, v.v.).
///
/// Tối ưu hiệu năng:
/// - Thời lượng chuyển cảnh 240ms cực nhanh, không gây cảm giác chờ đợi hay nặng nề.
/// - Không can thiệp secondaryAnimation của màn hình cha (giữ nguyên không render lại màn cha).
/// - Scale nhẹ từ 0.93 -> 1.0 theo chuẩn Material 3 chuyển động tự nhiên.
class ZoomPageTransition<T> extends CustomTransitionPage<T> {
  ZoomPageTransition({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = const Duration(milliseconds: 240),
    Duration reverseDuration = const Duration(milliseconds: 180),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

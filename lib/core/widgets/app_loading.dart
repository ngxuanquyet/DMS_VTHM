import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Reusable loading indicator powered by Lottie animation `loading.json`.
/// Falls back to [CircularProgressIndicator] if the animation cannot be rendered.
class AppLoading extends StatelessWidget {
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLoading({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Generous default size for prominent, clear visibility
    final effectiveWidth = size ?? width ?? 200.0;
    final effectiveHeight = size ?? height ?? 200.0;

    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: SizedBox(
              width: (effectiveWidth * 0.4).clamp(16.0, 56.0),
              height: (effectiveHeight * 0.4).clamp(16.0, 56.0),
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
          );
        },
      ),
    );
  }
}

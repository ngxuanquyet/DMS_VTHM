import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/attendance_entity.dart';

class AttendancePhotoViewerDialog extends StatelessWidget {
  final AttendancePunchPhotoEntity photo;

  const AttendancePhotoViewerDialog({super.key, required this.photo});

  static Future<void> show(
    BuildContext context, {
    required AttendancePunchPhotoEntity photo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AttendancePhotoViewerDialog(photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = photo.getFullUrl(AppConstants.baseUrl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                photo.photoTypeLabel,
                style: AppTypography.titleMedium(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadius.roundedLg,
            child: Container(
              color: Colors.black,
              constraints: const BoxConstraints(maxHeight: 500),
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // §4.4: Hạn lưu 90 ngày, sau đó trả 404
                  return Container(
                    height: 220,
                    color: AppColors.surfaceVariant.withValues(alpha: 0.2),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ảnh đã hết hạn lưu trữ (sau 90 ngày)\nhoặc không tìm thấy.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (photo.takenAt != null && photo.takenAt!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Chụp lúc: ${photo.takenAt}',
              style: AppTypography.bodySmall(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

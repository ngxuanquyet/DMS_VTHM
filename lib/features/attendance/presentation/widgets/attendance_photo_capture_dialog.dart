import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';

class AttendancePhotoCaptureDialog extends ConsumerStatefulWidget {
  final AttendancePunchEntity punch;

  const AttendancePhotoCaptureDialog({
    super.key,
    required this.punch,
  });

  static Future<void> show(
    BuildContext context, {
    required AttendancePunchEntity punch,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AttendancePhotoCaptureDialog(punch: punch),
    );
  }

  @override
  ConsumerState<AttendancePhotoCaptureDialog> createState() =>
      _AttendancePhotoCaptureDialogState();
}

class _AttendancePhotoCaptureDialogState
    extends ConsumerState<AttendancePhotoCaptureDialog> {
  final ImagePicker _picker = ImagePicker();

  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  File? _localFrontFile;
  File? _localBackFile;

  AttendancePunchEntity? _livePunch;

  @override
  void initState() {
    super.initState();
    _livePunch = widget.punch;
  }

  AttendancePunchEntity get punch => _livePunch ?? widget.punch;
  AttendanceRequirementsEntity get req => punch.requirements;

  bool get hasFrontPhoto =>
      punch.photos.any((p) => p.photoType == 'front') || _localFrontFile != null;
  bool get hasBackPhoto =>
      punch.photos.any((p) => p.photoType == 'back') || _localBackFile != null;

  Future<void> _capturePhoto({
    required String photoType,
    required CameraDevice preferredCamera,
  }) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCamera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (xFile == null) return;
      final file = File(xFile.path);

      setState(() {
        if (photoType == 'front') {
          _isUploadingFront = true;
          _localFrontFile = file;
        } else if (photoType == 'back') {
          _isUploadingBack = true;
          _localBackFile = file;
        }
      });

      final vm = ref.read(attendanceViewModelProvider.notifier);
      final photo = await vm.uploadPunchPhoto(
        punchId: punch.id,
        file: file,
        photoType: photoType,
        lat: punch.lat,
        lng: punch.lng,
      );

      if (mounted) {
        setState(() {
          if (photoType == 'front') _isUploadingFront = false;
          if (photoType == 'back') _isUploadingBack = false;

          if (photo != null) {
            // Cập nhật punch cục bộ
            final updatedPhotos = List<AttendancePunchPhotoEntity>.from(punch.photos);
            updatedPhotos.removeWhere((p) => p.photoType == photoType);
            updatedPhotos.add(photo);

            final hasFront = updatedPhotos.any((p) => p.photoType == 'front');
            final hasBack = updatedPhotos.any((p) => p.photoType == 'back');

            final updatedReq = AttendanceRequirementsEntity(
              photoCount: updatedPhotos.length,
              minPhotos: req.minPhotos,
              maxPhotos: req.maxPhotos,
              needFront: !hasFront,
              needBack: !hasBack,
              requireBoth: true,
              satisfied: hasFront && hasBack,
            );

            _livePunch = AttendancePunchEntity(
              id: punch.id,
              punchAt: punch.punchAt,
              clientUuid: punch.clientUuid,
              lat: punch.lat,
              lng: punch.lng,
              accuracyM: punch.accuracyM,
              geofenceId: punch.geofenceId,
              geofenceName: punch.geofenceName,
              isOutsideGeofence: punch.isOutsideGeofence,
              isMockLocation: punch.isMockLocation,
              isTimeTampered: punch.isTimeTampered,
              duplicate: punch.duplicate,
              photos: updatedPhotos,
              requirements: updatedReq,
            );
          }
        });

        // 🔴 QUY TẮC §4.1: Tín hiệu DUY NHẤT để đóng màn hình là requirements.satisfied == true
        if (_livePunch != null && _livePunch!.requirements.satisfied) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã hoàn tất chụp ảnh chấm công!'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingFront = false;
          _isUploadingBack = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải ảnh: ${e.toString().replaceAll("AppException: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSatisfied = req.satisfied;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
          borderRadius: AppRadius.roundedXl,
          boxShadow: AppShadows.level3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSatisfied
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isSatisfied ? Icons.verified_rounded : Icons.camera_alt_rounded,
                    color: isSatisfied ? AppColors.primary : AppColors.secondary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                isSatisfied ? 'Đã đủ ảnh chấm công' : 'Chụp ảnh xác thực chấm công',
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                'Lượt chấm đã ghi nhận lúc ${punch.timeFormatted}. Vui lòng chụp đủ 2 ảnh (camera trước và camera sau) theo quy định.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              // Progress Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSatisfied
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: AppRadius.roundedFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSatisfied ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: isSatisfied ? AppColors.primary : AppColors.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Đã có: ${punch.photos.length}/${req.minPhotos} ảnh bắt buộc',
                      style: AppTypography.labelLarge(
                        color: isSatisfied
                            ? AppColors.primary
                            : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2 Nút chụp ảnh: Camera trước + Camera sau (§2: đọc từ photo.require_both)
              Row(
                children: [
                  // Nút 1: Camera trước (Ảnh chân dung)
                  Expanded(
                    child: _buildPhotoSlot(
                      title: 'Camera trước',
                      subtitle: 'Ảnh chân dung',
                      isFront: true,
                      isUploaded: punch.photos.any((p) => p.photoType == 'front'),
                      isLoading: _isUploadingFront,
                      localFile: _localFrontFile,
                      serverPhoto: punch.frontPhoto,
                      onTap: () => _capturePhoto(
                        photoType: 'front',
                        preferredCamera: CameraDevice.front,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nút 2: Camera sau (Ảnh khung cảnh)
                  Expanded(
                    child: _buildPhotoSlot(
                      title: 'Camera sau',
                      subtitle: 'Ảnh khung cảnh',
                      isFront: false,
                      isUploaded: punch.photos.any((p) => p.photoType == 'back'),
                      isLoading: _isUploadingBack,
                      localFile: _localBackFile,
                      serverPhoto: punch.backPhoto,
                      onTap: () => _capturePhoto(
                        photoType: 'back',
                        preferredCamera: CameraDevice.rear,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              if (isSatisfied)
                AppButton(
                  text: 'Hoàn tất',
                  icon: Icons.check_rounded,
                  height: 48,
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                Column(
                  children: [
                    Text(
                      'Bạn có thể chụp bổ sung sau từ mục Lịch sử.',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Để sau / Đóng',
                        style: AppTypography.labelLarge(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot({
    required String title,
    required String subtitle,
    required bool isFront,
    required bool isUploaded,
    required bool isLoading,
    required File? localFile,
    required AttendancePunchPhotoEntity? serverPhoto,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: AppRadius.roundedLg,
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant.withValues(alpha: 0.35),
          borderRadius: AppRadius.roundedLg,
          border: Border.all(
            color: isUploaded
                ? AppColors.primary
                : (isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant),
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview hoặc Icon
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.roundedMd,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (serverPhoto != null && serverPhoto.url.isNotEmpty)
                      Image.network(
                        serverPhoto.getFullUrl(AppConstants.baseUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => localFile != null
                            ? Image.file(
                                localFile,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : _placeholderIcon(isFront),
                      )
                    else if (localFile != null)
                      Image.file(
                        localFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    else
                      _placeholderIcon(isFront),

                    if (isLoading)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    if (isUploaded && !isLoading)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(bool isFront) {
    return Container(
      color: Colors.black.withValues(alpha: 0.04),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFront ? Icons.face_rounded : Icons.photo_camera_back_rounded,
              color: AppColors.secondary,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'Chạm để chụp',
              style: AppTypography.bodySmall(
                color: AppColors.secondary,
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

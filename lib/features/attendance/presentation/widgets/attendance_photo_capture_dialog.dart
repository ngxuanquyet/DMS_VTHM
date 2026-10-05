import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';

class AttendancePhotoCaptureDialog extends ConsumerStatefulWidget {
  final AttendancePunchEntity? punch;
  final Position? position;

  const AttendancePhotoCaptureDialog({
    super.key,
    this.punch,
    this.position,
  }) : assert(punch != null || position != null, 'Cần cung cấp punch hoặc position');

  static Future<void> show(
    BuildContext context, {
    AttendancePunchEntity? punch,
    Position? position,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AttendancePhotoCaptureDialog(
        punch: punch,
        position: position,
      ),
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
  bool _isSubmitting = false;

  File? _localFrontFile;
  File? _localBackFile;

  AttendancePunchEntity? _livePunch;

  bool get isNewPunch => widget.punch == null;

  @override
  void initState() {
    super.initState();
    _livePunch = widget.punch;
  }

  AttendancePunchEntity? get punch => _livePunch ?? widget.punch;

  bool get hasFrontPhoto =>
      _localFrontFile != null || (punch?.photos.any((p) => p.photoType == 'front') ?? false);
  bool get hasBackPhoto =>
      _localBackFile != null || (punch?.photos.any((p) => p.photoType == 'back') ?? false);

  int get capturedCount {
    if (isNewPunch) {
      int count = 0;
      if (_localFrontFile != null) count++;
      if (_localBackFile != null) count++;
      return count;
    }
    return punch?.photos.length ?? 0;
  }

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
      final rawFile = File(xFile.path);

      // Đóng dấu Watermark thông tin chấm công (thời gian, toạ độ GPS, tên nhân sự, địa điểm)
      final user = ref.read(authViewModelProvider).user;
      final staffName = user?.name;
      final pos = widget.position;
      final locations = ref.read(attendanceViewModelProvider).config?.locations;
      final locName = punch?.geofenceName ??
          (locations != null && locations.isNotEmpty ? locations.first.name : null);

      final file = await PhotoWatermarkHelper.addWatermark(
        imageFile: rawFile,
        timestamp: DateTime.now(),
        latitude: pos?.latitude ?? punch?.lat,
        longitude: pos?.longitude ?? punch?.lng,
        accuracy: pos?.accuracy ?? punch?.accuracyM,
        locationName: locName,
        staffName: staffName,
      );

      if (isNewPunch) {
        // Luồng chấm công mới: Chỉ lưu file cục bộ, chưa gửi mạng và chưa lưu lịch sử
        setState(() {
          if (photoType == 'front') {
            _localFrontFile = file;
          } else if (photoType == 'back') {
            _localBackFile = file;
          }
        });
        return;
      }

      // Luồng bổ sung ảnh cho lượt chấm đã có trên server
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
        punchId: punch!.id,
        file: file,
        photoType: photoType,
        lat: punch!.lat,
        lng: punch!.lng,
      );

      if (mounted) {
        setState(() {
          if (photoType == 'front') _isUploadingFront = false;
          if (photoType == 'back') _isUploadingBack = false;

          if (photo != null && punch != null) {
            final updatedPhotos = List<AttendancePunchPhotoEntity>.from(punch!.photos);
            updatedPhotos.removeWhere((p) => p.photoType == photoType);
            updatedPhotos.add(photo);

            final hasFront = updatedPhotos.any((p) => p.photoType == 'front');
            final hasBack = updatedPhotos.any((p) => p.photoType == 'back');

            final updatedReq = AttendanceRequirementsEntity(
              photoCount: updatedPhotos.length,
              minPhotos: punch!.requirements.minPhotos,
              maxPhotos: punch!.requirements.maxPhotos,
              needFront: !hasFront,
              needBack: !hasBack,
              requireBoth: true,
              satisfied: hasFront && hasBack,
            );

            _livePunch = AttendancePunchEntity(
              id: punch!.id,
              punchAt: punch!.punchAt,
              clientUuid: punch!.clientUuid,
              lat: punch!.lat,
              lng: punch!.lng,
              accuracyM: punch!.accuracyM,
              geofenceId: punch!.geofenceId,
              geofenceName: punch!.geofenceName,
              isOutsideGeofence: punch!.isOutsideGeofence,
              isMockLocation: punch!.isMockLocation,
              isTimeTampered: punch!.isTimeTampered,
              duplicate: punch!.duplicate,
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
                content: Text('Đã hoàn tất chụp ảnh bổ sung!'),
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
            content: Text('Lỗi chụp ảnh: ${e.toString().replaceAll("AppException: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Gửi lượt chấm công thật kèm ảnh đã chụp
  Future<void> _handleConfirmNewPunch() async {
    final photoConfig = ref.read(attendanceViewModelProvider).config?.photo;
    final minPhotos = photoConfig?.minPhotos ?? 2;
    final requireBoth = photoConfig?.requireBoth ?? true;

    if (requireBoth) {
      if (_localFrontFile == null || _localBackFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chụp đủ cả 2 ảnh: camera trước và camera sau!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else {
      if (capturedCount < minPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vui lòng chụp ít nhất $minPhotos ảnh trước khi gửi chấm công!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final vm = ref.read(attendanceViewModelProvider.notifier);
    final success = await vm.submitPunchWithPhotos(
      position: widget.position!,
      frontPhoto: _localFrontFile,
      backPhoto: _localBackFile,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấm công thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoConfig = ref.watch(attendanceViewModelProvider.select((s) => s.config?.photo));
    final minPhotos = isNewPunch ? (photoConfig?.minPhotos ?? 2) : (punch?.requirements.minPhotos ?? 2);
    final isSatisfied = isNewPunch
        ? (_localFrontFile != null && _localBackFile != null)
        : (punch?.requirements.satisfied ?? false);

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
              // Nút đóng góc trên
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                      size: 22,
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),

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
                isNewPunch
                    ? 'Vui lòng chụp đủ 2 ảnh (camera trước và camera sau) để thực hiện lượt chấm công.'
                    : 'Lượt chấm đã ghi nhận lúc ${punch!.timeFormatted}. Vui lòng chụp bổ sung ảnh theo quy định.',
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
                      'Đã chụp: $capturedCount/$minPhotos ảnh bắt buộc',
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

              // 2 Nút chụp ảnh: Camera trước + Camera sau (§2)
              Row(
                children: [
                  // Nút 1: Camera trước (Ảnh chân dung)
                  Expanded(
                    child: _buildPhotoSlot(
                      title: 'Camera trước',
                      subtitle: 'Ảnh chân dung',
                      isFront: true,
                      isUploaded: hasFrontPhoto,
                      isLoading: _isUploadingFront,
                      localFile: _localFrontFile,
                      serverPhoto: punch?.frontPhoto,
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
                      isUploaded: hasBackPhoto,
                      isLoading: _isUploadingBack,
                      localFile: _localBackFile,
                      serverPhoto: punch?.backPhoto,
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
              if (isNewPunch) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                        ),
                        child: const Text('Hủy bỏ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: _isSubmitting ? 'Đang gửi...' : 'Gửi chấm công',
                        isLoading: _isSubmitting,
                        icon: Icons.send_rounded,
                        height: 48,
                        onPressed: _isSubmitting ? null : _handleConfirmNewPunch,
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
      onTap: isLoading || _isSubmitting ? null : onTap,
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
                    if (localFile != null)
                      Image.file(
                        localFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    else if (serverPhoto != null && serverPhoto.url.isNotEmpty)
                      Image.network(
                        serverPhoto.getFullUrl(AppConstants.baseUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholderIcon(isFront),
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
              isUploaded ? 'Chạm để chụp lại' : subtitle,
              style: AppTypography.bodySmall(
                color: isUploaded
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
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

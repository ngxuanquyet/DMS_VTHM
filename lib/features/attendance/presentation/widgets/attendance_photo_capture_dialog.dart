import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/camera_permission_dialog.dart';
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
  bool _isProcessingFront = false;
  bool _isProcessingBack = false;
  bool _isSubmitting = false;
  double _submitProgress = 0.0;
  String _submitStatus = '';

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
  }) async {
    final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
      context,
      featureName: 'chấm công',
      customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh chân dung và bối cảnh xác thực ca làm việc. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
    );
    if (!hasPermission) return;

    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (xFile == null) return;

      setState(() {
        if (photoType == 'front') _isProcessingFront = true;
        if (photoType == 'back') _isProcessingBack = true;
      });

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
            _isProcessingFront = false;
          } else if (photoType == 'back') {
            _localBackFile = file;
            _isProcessingBack = false;
          }
        });
        return;
      }

      // Luồng bổ sung ảnh cho lượt chấm đã có trên server
      setState(() {
        if (photoType == 'front') {
          _isProcessingFront = false;
          _isUploadingFront = true;
          _localFrontFile = file;
        } else if (photoType == 'back') {
          _isProcessingBack = false;
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

            final updatedReq = photo.requirements ?? AttendanceRequirementsEntity(
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
            AppSnackBar.showSuccess(
              context,
              'Đã hoàn tất chụp ảnh bổ sung! Ảnh đang được tải lên nền.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingFront = false;
          _isProcessingBack = false;
          _isUploadingFront = false;
          _isUploadingBack = false;
        });
        AppSnackBar.showError(
          context,
          e,
        );
      }
    }
  }

  /// Gửi lượt chấm công thật kèm ảnh
  Future<void> _handleConfirmNewPunch() async {
    final photoConfig = ref.read(attendanceViewModelProvider).config?.photo;
    final minPhotos = photoConfig?.minPhotos ?? 2;
    final requireBoth = photoConfig?.requireBoth ?? true;

    if (requireBoth) {
      if (_localFrontFile == null || _localBackFile == null) {
        AppSnackBar.showError(
          context,
          'Vui lòng chụp đủ cả 2 ảnh: ảnh chân dung và ảnh khung cảnh!',
        );
        return;
      }
    } else {
      if (capturedCount < minPhotos) {
        AppSnackBar.showError(
          context,
          'Vui lòng chụp ít nhất $minPhotos ảnh trước khi gửi chấm công!',
        );
        return;
      }
    }

    // 🔴 KIỂM TRA CHỐNG GIAN LẬN TRƯỚC KHI GỬI CHẤM CÔNG THẬT
    if (widget.position != null) {
      final fraudCheck = await ref.read(antiFraudServiceProvider).validateAction(
        context,
        position: widget.position!,
        actionType: AntiFraudActionType.attendance,
        actionTitle: 'Chấm công',
      );
      if (!fraudCheck.isAllowed) return;
    }

    setState(() {
      _isSubmitting = true;
      _submitProgress = 0.20;
      _submitStatus = 'Đang gửi lượt chấm công...';
    });

    final vm = ref.read(attendanceViewModelProvider.notifier);
    final success = await vm.submitPunchWithPhotos(
      position: widget.position!,
      frontPhoto: _localFrontFile,
      backPhoto: _localBackFile,
      onProgress: (progress, status) {
        if (mounted) {
          setState(() {
            _submitProgress = progress;
            _submitStatus = status;
          });
        }
      },
    );

    if (mounted) {
      if (success) {
        setState(() {
          _submitProgress = 1.0;
          _submitStatus = 'Đã chấm công thành công!';
        });
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackBar.showSuccess(
            context,
            'Đã chấm công thành công! Ảnh đang được tải lên nền.',
          );
        }
      } else {
        setState(() => _isSubmitting = false);
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
                    ? 'Vui lòng chụp đủ 2 ảnh (ảnh chân dung và ảnh khung cảnh) để thực hiện lượt chấm công. Dùng camera nào cũng được.'
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
                    Flexible(
                      child: Text(
                        'Đã chụp: $capturedCount/$minPhotos ảnh bắt buộc',
                        style: AppTypography.labelLarge(
                          color: isSatisfied
                              ? AppColors.primary
                              : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                        ).copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2 Nút chụp ảnh: Ảnh chân dung + Ảnh khung cảnh (§2) — không ép camera nào, máy hỏng một camera vẫn chụp đủ
              Builder(
                builder: (context) {
                  final bool isFrontLoading = _isUploadingFront ||
                      _isProcessingFront ||
                      (_isSubmitting &&
                          _localFrontFile != null &&
                          (_localBackFile == null ? _submitProgress < 0.95 : _submitProgress < 0.60));

                  final bool isBackLoading = _isUploadingBack ||
                      _isProcessingBack ||
                      (_isSubmitting &&
                          _localBackFile != null &&
                          (_localFrontFile == null
                              ? _submitProgress < 0.95
                              : (_submitProgress >= 0.40 && _submitProgress < 0.95)));

                  return Row(
                    children: [
                      // Nút 1: Ảnh chân dung (selfie)
                      Expanded(
                        child: _buildPhotoSlot(
                          title: 'Ảnh chân dung',
                          subtitle: 'Selfie của bạn',
                          isFront: true,
                          isUploaded: hasFrontPhoto && !isFrontLoading,
                          isLoading: isFrontLoading,
                          localFile: _localFrontFile,
                          serverPhoto: punch?.frontPhoto,
                          onTap: () => _capturePhoto(
                            photoType: 'front',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nút 2: Ảnh khung cảnh
                      Expanded(
                        child: _buildPhotoSlot(
                          title: 'Ảnh khung cảnh',
                          subtitle: 'Nơi làm việc',
                          isFront: false,
                          isUploaded: hasBackPhoto && !isBackLoading,
                          isLoading: isBackLoading,
                          localFile: _localBackFile,
                          serverPhoto: punch?.backPhoto,
                          onTap: () => _capturePhoto(
                            photoType: 'back',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (!isNewPunch && (_isUploadingFront || _isUploadingBack)) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    minHeight: 5,
                    backgroundColor: Color(0xFFDCFCE7),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006E15)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đang tải ảnh lên hệ thống...',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              if (isNewPunch) ...[
                if (_isSubmitting) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006E15)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _submitStatus.isNotEmpty
                                    ? _submitStatus
                                    : 'Đang gửi lượt chấm công...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF166534),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_submitProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF006E15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _submitProgress.clamp(0.05, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFDCFCE7),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006E15)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
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
                        text: _isSubmitting ? 'Đang gửi chấm công...' : 'Gửi chấm công',
                        icon: _isSubmitting ? null : Icons.send_rounded,
                        isLoading: _isSubmitting,
                        height: 48,
                        onPressed: _isSubmitting ? null : _handleConfirmNewPunch,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                if (_isUploadingFront || _isUploadingBack)
                  AppButton(
                    text: 'Đang tải ảnh lên...',
                    isLoading: true,
                    height: 48,
                    onPressed: null,
                  )
                else if (isSatisfied)
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
                        cacheWidth: 720,
                      )
                    else if (serverPhoto != null && serverPhoto.url.isNotEmpty)
                      Image.network(
                        serverPhoto.getFullUrl(AppConstants.baseUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholderIcon(isFront),
                        cacheWidth: 720,
                      )
                    else
                      _placeholderIcon(isFront),

                    if (isLoading)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isNewPunch ? 'Đang tải...' : 'Đang gửi...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
              isLoading ? 'Đang tải ảnh...' : (isUploaded ? 'Chạm để chụp lại' : subtitle),
              style: AppTypography.bodySmall(
                color: isUploaded && !isLoading
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

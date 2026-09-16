import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicPhotoFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final List<String> photoPaths;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;

  const DynamicPhotoFieldWidget({
    super.key,
    required this.field,
    required this.photoPaths,
    required this.onChanged,
    this.errorText,
  });

  Future<void> _requestCameraAndCapture(BuildContext context) {
    return _handleImageAction(context, isCamera: true);
  }

  Future<void> _pickFromGallery(BuildContext context) {
    return _handleImageAction(context, isCamera: false);
  }

  Future<void> _handleImageAction(BuildContext context, {required bool isCamera}) async {
    if (field.isReadOnly) return;
    if (photoPaths.length >= field.maxPhotos) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đạt giới hạn tối đa ${field.maxPhotos} ảnh.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (isCamera) {
      // 1. Check & Request Camera Permission
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted && !status.isLimited) {
        if (!context.mounted) return;
        _showPermissionDeniedDialog(
          context,
          title: 'Yêu cầu quyền Máy ảnh',
          description: 'Ứng dụng cần quyền truy cập Camera để chụp ảnh thực tế tại điểm bán. Vui lòng cấp quyền trong Cài đặt thiết bị.',
          isPermanentlyDenied: status.isPermanentlyDenied,
        );
        return;
      }
    } else {
      // 2. Check Photo Library Permission
      var status = await Permission.photos.status;
      if (status.isDenied) {
        status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return;
        _showPermissionDeniedDialog(
          context,
          title: 'Yêu cầu quyền Thư viện ảnh',
          description: 'Ứng dụng cần quyền truy cập Thư viện ảnh để chọn hình ảnh tải lên. Vui lòng cấp quyền trong Cài đặt thiết bị.',
          isPermanentlyDenied: true,
        );
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && context.mounted) {
        final updated = List<String>.from(photoPaths)..add(image.path);
        onChanged(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCamera ? 'Đã chụp và lưu ảnh thành công!' : 'Đã chọn ảnh thành công!'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lấy ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String description,
    required bool isPermanentlyDenied,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
        title: Row(
          children: [
            const Icon(Icons.camera_alt_outlined, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTypography.titleMedium(color: AppColors.onSurface).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: AppTypography.bodyMedium(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
            ),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Mở cài đặt'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _handleAddPhoto(BuildContext context) {
    if (field.isReadOnly) return;
    if (photoPaths.length >= field.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đạt giới hạn tối đa ${field.maxPhotos} ảnh.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đính kèm hình ảnh',
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                  ),
                  title: const Text('Chụp ảnh từ Camera'),
                  subtitle: const Text('Yêu cầu quyền truy cập Camera để chụp ảnh'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _requestCameraAndCapture(context);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.secondaryContainer,
                    child: Icon(Icons.photo_library_rounded, color: Colors.white),
                  ),
                  title: const Text('Chọn từ Thư viện'),
                  subtitle: const Text('Chọn ảnh có sẵn từ thiết bị'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleRemovePhoto(int index) {
    if (field.isReadOnly) return;
    final updated = List<String>.from(photoPaths)..removeAt(index);
    onChanged(updated);
  }

  void _viewFullImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: AppRadius.roundedLg,
              child: InteractiveViewer(
                child: _buildImageWidget(path, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 28, color: AppColors.outline),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 28, color: AppColors.outline),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image_rounded, size: 28, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos Grid Preview + Add Button
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...photoPaths.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _viewFullImage(context, path),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.roundedMd,
                          child: _buildImageWidget(path),
                        ),
                      ),
                    ),
                    if (!field.isReadOnly)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _handleRemovePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              }),

              // Add Photo Card
              if (!field.isReadOnly && photoPaths.length < field.maxPhotos)
                InkWell(
                  onTap: () => _handleAddPhoto(context),
                  borderRadius: AppRadius.roundedMd,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                      borderRadius: AppRadius.roundedMd,
                      border: Border.all(
                        color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                        style: BorderStyle.solid,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 24,
                          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${photoPaths.length}/${field.maxPhotos}',
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

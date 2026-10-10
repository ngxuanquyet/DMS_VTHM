import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_donut_chart.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../../core/widgets/voice_input_mic_button.dart';
import '../../../../core/widgets/camera_permission_dialog.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/entities/visit_requirements_entity.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/rules/geofence_rule_helper.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../widgets/active_visit_blocking_dialog.dart';
import '../widgets/checkin_distance_warning_dialog.dart';
import '../widgets/checkout_success_dialog.dart';
import '../../../forms/presentation/screens/market_form_fill_screen.dart';
import '../../../forms/presentation/widgets/market_form_card.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../domain/entities/route_entity.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  final DealerEntity? dealer;
  const CheckInScreen({super.key, this.dealer});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _closedNoteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initAndCheckin();
      await _checkLostData();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _closedNoteController.dispose();
    super.dispose();
  }

  Future<void> _initAndCheckin() async {
    final vm = ref.read(checkInViewModelProvider.notifier);

    // Kiểm tra xem có phiên viếng thăm khác đang mở không (§3 Luật 3)
    // Áp dụng cả khi online lẫn offline
    final currentState = ref.read(checkInViewModelProvider);
    VisitEntity? activeVisit = currentState.visitId != 0 && currentState.visitEntity?.isOpen == true
        ? currentState.visitEntity
        : null;

    if (activeVisit == null) {
      try {
        final saved = await ref.read(visitRepositoryProvider).getActiveVisit();
        if (saved != null && saved.isOpen) {
          activeVisit = saved;
        }
      } catch (_) {}
    }

    if (activeVisit == null) {
      try {
        final routeActive = ref.read(routeViewModelProvider).activeVisit;
        if (routeActive != null && routeActive.isOpen) {
          activeVisit = routeActive;
        }
      } catch (_) {}
    }

    // Kiểm tra tính hợp lệ của active visit so với danh sách lượt thực tế hôm nay
    final currentActive = activeVisit;
    if (currentActive != null) {
      final todayVisits = ref.read(routeViewModelProvider).todayVisits;
      final matchingServerVisit = todayVisits.where(
        (v) => (v.id == currentActive.id && v.id > 0) || v.customerId == currentActive.customerId,
      ).firstOrNull;
      if (matchingServerVisit != null && !matchingServerVisit.isOpen) {
        // Lượt này trên máy chủ đã check-out (hoặc huỷ) rồi!
        debugPrint('[CheckInScreen] Active visit id=${currentActive.id} đã hoàn tất trên server, giải phóng phiên stale.');
        await ref.read(visitRepositoryProvider).clearActiveVisit();
        ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
        vm.resetSession();
        activeVisit = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hôm nay bạn đã hoàn thành (check-out) viếng thăm điểm bán này rồi.'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _safePop();
          return;
        }
      }
    }

    if (widget.dealer != null && widget.dealer!.status == DealerVisitStatus.completed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hôm nay bạn đã hoàn thành (check-out) viếng thăm điểm bán này rồi.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _safePop();
        return;
      }
    }

    if (activeVisit != null && widget.dealer != null) {
      final targetCustomerId = widget.dealer!.customer is CustomerEntity
          ? (widget.dealer!.customer as CustomerEntity).id
          : int.tryParse(widget.dealer!.id.replaceAll(RegExp(r'[^\d]'), ''));

      if (targetCustomerId != null && targetCustomerId != activeVisit.customerId) {
        final activeName = activeVisit.customerName.isNotEmpty
            ? activeVisit.customerName
            : (currentState.checkinData?.dealer.name ?? 'Điểm bán khác');
        if (mounted) {
          await showActiveVisitBlockingDialog(
            context: context,
            ref: ref,
            activeVisit: activeVisit,
            activeDealerName: activeName,
            targetDealerName: widget.dealer!.name,
            onClose: () {
              if (mounted) _safePop();
            },
          );
        }
        return;
      }

      // ⚠️ Khi quay lại đúng điểm bán đang có phiên mở dở dang:
      // Tự động phục hồi phiên và tuyệt đối KHÔNG gọi check-in mới để tránh duplicate
      if (targetCustomerId != null && targetCustomerId == activeVisit.customerId) {
        final dealerToInit = widget.dealer!.visit != null
            ? widget.dealer!
            : widget.dealer!.copyWith(visit: activeVisit, status: DealerVisitStatus.inProgress);
        vm.initCheckinWithDealer(dealerToInit);
        await vm.restoreActiveVisitIfAvailable(targetCustomerId);
        return;
      }
    }

    if (widget.dealer != null) {
      vm.initCheckinWithDealer(widget.dealer!);
    } else {
      final restored = await vm.restoreActiveVisitIfAvailable();
      if (!restored) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn một điểm bán từ danh sách tuyến để thực hiện viếng thăm.')),
          );
          _safePop();
        }
        return;
      }
    }
    await _checkinIfNeeded();
  }

  Future<void> _checkinIfNeeded() async {
    var state = ref.read(checkInViewModelProvider);
    if (state.visitId != 0 && state.visitEntity != null && state.visitEntity!.isOpen) return; // Đã có phiên hợp lệ (cả online lẫn offline)

    if (state.checkinData == null) {
      await ref.read(checkInViewModelProvider.notifier).loadCheckinData();
      state = ref.read(checkInViewModelProvider);
    }

    if (state.visitId != 0 && state.visitEntity != null && state.visitEntity!.isOpen) return;

    final customer = state.customer is CustomerEntity ? (state.customer as CustomerEntity) : null;
    final customerId = customer?.id ??
        (int.tryParse(state.checkinData?.dealer.id.replaceAll(RegExp(r'[^\d]'), '') ?? '') ?? 0);

    // Kiểm tra bản ghi active visit lưu trữ cục bộ để chặn offline (§3 Luật 3)
    try {
      final savedActive = await ref.read(visitRepositoryProvider).getActiveVisit();
      if (savedActive != null && savedActive.isOpen) {
        if (savedActive.customerId != customerId) {
          _showCheckinErrorDialog('Bạn còn một lượt viếng thăm tại điểm bán khác chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới.');
          return;
        } else {
          // Trùng customerId: Đang có lượt mở cho điểm bán này, phục hồi phiên thay vì check-in mới
          await ref.read(checkInViewModelProvider.notifier).restoreActiveVisitIfAvailable(customerId);
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _isCheckingIn = true;
    });

    if (!mounted) return;
    final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context);

    // 🔴 KIỂM TRA CHỐNG GIAN LẬN TRƯỚC KHI CHECK-IN VIẾNG THĂM
    if (mounted) {
      final fraudCheck = await ref.read(antiFraudServiceProvider).validateAction(
        context,
        position: pos,
        actionType: AntiFraudActionType.visitCheckin,
        actionTitle: 'Check-in viếng thăm',
      );
      if (!fraudCheck.isAllowed) {
        setState(() => _isCheckingIn = false);
        return;
      }
    }

    final error = await ref.read(checkInViewModelProvider.notifier).performCheckin(
      customerId: customerId,
      lat: pos?.latitude,
      lng: pos?.longitude,
      accuracyM: pos?.accuracy,
      isMockLocation: pos?.isMocked,
      address: customer?.address ?? state.checkinData?.dealer.address,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() {
      _isCheckingIn = false;
    });

    if (error != null) {
      _showCheckinErrorDialog(error);
    } else {
      final updatedState = ref.read(checkInViewModelProvider);
      if (updatedState.visitEntity != null) {
        ref.read(routeViewModelProvider.notifier).setActiveVisit(updatedState.visitEntity);
        await ref.read(visitRepositoryProvider).saveActiveVisit(updatedState.visitEntity!);
      }
    }
  }

  void _showCheckinErrorDialog(String errorMessage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Không thể Check-in',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hệ thống không cho phép mở lượt viếng thăm này theo quy định hiện tại.',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _safePop();
            },
            child: const Text('QUAY LẠI'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _checkinIfNeeded();
            },
            child: const Text('THỬ LẠI'),
          ),
        ],
      ),
    );
  }

  void _safePop() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        context.pop();
      } catch (_) {}
    }
  }

  bool _hasUnsavedData() {
    return _noteController.text.trim().isNotEmpty || _closedNoteController.text.trim().isNotEmpty;
  }

  /// Xác nhận và thực hiện huỷ lượt viếng thăm (§3.4 & §5.1 HUY-LUOT-VIENG-THAM-2026-09-30)
  Future<void> _confirmAndCancelVisit(CheckInViewModel vm) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hủy lượt check-in?',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn hủy lượt viếng thăm này không? Lượt check-in sẽ được hủy hoàn toàn và bạn có thể check-in lại điểm bán này sau mà không bị tính vào báo cáo.',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Ở lại',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÁC NHẬN HỦY'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final (success, errorMsg) = await vm.cancelVisit();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // pop loading
      }

      if (success && mounted) {
        ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
        await ref.read(visitRepositoryProvider).clearActiveVisit();
        if (!mounted) return;
        ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMsg ?? 'Đã hủy lượt check-in thành công.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _safePop();
      } else if (errorMsg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleExit() async {
    final state = ref.read(checkInViewModelProvider);
    final vm = ref.read(checkInViewModelProvider.notifier);

    // Nếu chưa check-in (chưa có phiên viếng thăm nào đang mở)
    final isOpenVisit = state.visitId != 0 && (state.visitEntity == null || state.visitEntity!.isOpen);
    if (!isOpenVisit) {
      if (_hasUnsavedData()) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Rời khỏi màn hình?'),
            content: const Text('Dữ liệu ghi chú chưa lưu sẽ bị mất.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ở lại')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Rời khỏi')),
            ],
          ),
        );
        if (leave == true && mounted) {
          _safePop();
        }
      } else {
        _safePop();
      }
      return;
    }

    // Nếu lượt đang mở (cả online lẫn offline): Rời màn hình là hủy check-in luôn
    await _confirmAndCancelVisit(vm);
  }

  void _openNoteDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tempController = TextEditingController(text: _noteController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: isDark ? AppColors.primaryFixedDim : AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Ghi chú chuyến ghé',
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: TextField(
          controller: tempController,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập ý kiến phản hồi hoặc ghi chú từ điểm bán...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: VoiceInputMicButton(
              fieldName: 'Ghi chú viếng thăm',
              currentText: tempController.text,
              onTextRecognized: (text) {
                tempController.text = text;
                tempController.selection = TextSelection.fromPosition(
                  TextPosition(offset: text.length),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _noteController.text = tempController.text;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('LƯU GHI CHÚ'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTakePhoto(CheckInViewModel vm) async {
    final state = ref.read(checkInViewModelProvider);
    if (state.visitId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đợi check-in thành công trước khi chụp ảnh.')),
      );
      return;
    }

    final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
      context,
      featureName: 'viếng thăm',
      customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh check-in và trưng bày tại điểm bán. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
    );
    if (!hasPermission) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      // Chọn loại ảnh theo quy ước (§4.1)
      final photoType = await _showPhotoTypeSelectionSheet();
      if (photoType == null || !mounted) return;

      final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context);

      final watermarkedFile = await PhotoWatermarkHelper.addWatermark(
        imageFile: File(image.path),
        timestamp: DateTime.now(),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        accuracy: pos?.accuracy,
        locationName: widget.dealer?.name,
      );

      final (success, message) = await vm.uploadPhoto(
        watermarkedFile,
        photoType: photoType,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message ?? 'Đã tải ảnh lên thành công.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chụp ảnh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Khôi phục ảnh chụp nếu ứng dụng bị Android kill tiến trình nền khi mở Camera (§Tối ưu máy ít RAM)
  Future<void> _checkLostData() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null || !mounted) return;

      final lostFile = File(response.file!.path);
      if (!lostFile.existsSync()) return;

      final photoType = await _showPhotoTypeSelectionSheet();
      if (photoType == null || !mounted) return;

      final vm = ref.read(checkInViewModelProvider.notifier);
      final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context);

      final watermarkedFile = await PhotoWatermarkHelper.addWatermark(
        imageFile: lostFile,
        timestamp: DateTime.now(),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        accuracy: pos?.accuracy,
        locationName: widget.dealer?.name,
      );

      final (success, message) = await vm.uploadPhoto(
        watermarkedFile,
        photoType: photoType,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message ?? 'Đã khôi phục và tải ảnh chụp lên thành công.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<String?> _showPhotoTypeSelectionSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chọn phân loại ảnh chụp',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Phân loại giúp chuẩn hóa báo cáo trưng bày và hình ảnh điểm bán',
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildPhotoTypeTile(ctx, 'store_front', 'Mặt tiền điểm bán', Icons.storefront_outlined, isDark),
              _buildPhotoTypeTile(ctx, 'display', 'Ảnh trưng bày hàng hóa', Icons.grid_view_rounded, isDark),
              _buildPhotoTypeTile(ctx, 'posm', 'Vật phẩm quảng cáo (POSM)', Icons.campaign_outlined, isDark),
              _buildPhotoTypeTile(ctx, 'document', 'Hóa đơn / Giấy tờ / Sổ sách', Icons.receipt_long_outlined, isDark),
              _buildPhotoTypeTile(ctx, 'other', 'Ảnh chụp khác', Icons.photo_outlined, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTypeTile(
    BuildContext ctx,
    String type,
    String label,
    IconData icon,
    bool isDark,
  ) {
    return ListTile(
      leading: Icon(icon, color: isDark ? AppColors.primaryFixedDim : AppColors.primary),
      title: Text(
        label,
        style: TextStyle(
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.of(ctx).pop(type),
    );
  }

  Future<void> _handleDeletePhoto(CheckInViewModel vm, VisitPhotoEntity photo) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa ảnh?'),
        content: const Text('Bạn có chắc chắn muốn xóa ảnh này khỏi lượt viếng thăm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final (success, message) = await vm.deletePhoto(photo.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa ảnh thành công.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openSurveyFormsSheet(BuildContext context, CheckInState state, CheckInViewModel vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surveys = state.surveyForms;
    final customer = state.customer is CustomerEntity ? (state.customer as CustomerEntity) : null;
    final customerId = customer?.id ??
        (state.visitEntity?.customerId != null && state.visitEntity!.customerId > 0
            ? state.visitEntity!.customerId
            : (int.tryParse(state.checkinData?.dealer.id.replaceAll(RegExp(r'[^\d]'), '') ?? '') ?? 0));
    final dealerName = customer?.name ??
        (state.visitEntity?.customerName.isNotEmpty == true ? state.visitEntity!.customerName : null) ??
        state.checkinData?.dealer.name ??
        'Điểm bán';
    final customerCode = customer?.code ??
        state.visitEntity?.customerCode ??
        state.checkinData?.dealer.id;
    final customerAddress = customer?.address ??
        state.visitEntity?.customerAddress ??
        state.checkinData?.dealer.address;

    final customerContext = MarketFormFillArgs.buildCustomerContext(
      typeId: customer?.customerTypeId,
      channelId: customer?.channelId,
      regionId: customer?.regionId,
      groupId: customer?.customerGroupId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biểu mẫu khảo sát điểm bán',
                    style: AppTypography.titleLarge(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Điểm bán: $dealerName',
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (surveys.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Hiện không có biểu mẫu khảo sát nào cho điểm bán này'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: surveys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (c, idx) {
                      final item = surveys[idx];
                      final isSubmitted = state.submittedSurveyConfigIds.contains(item.configId);
                      return MarketFormCard(
                        config: item,
                        isSubmitted: isSubmitted,
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final result = await context.push<bool>(
                            '/forms/fill',
                            extra: MarketFormFillArgs(
                              config: item,
                              kind: 'survey',
                              customerId: customerId,
                              visitId: state.visitId,
                              dealerName: dealerName,
                              customerCode: customerCode,
                              customerAddress: customerAddress,
                              customerContext: customerContext,
                              lockCustomer: true,
                            ),
                          );
                          if (result == true) {
                            vm.markSurveySubmitted(item.configId);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockersDialog(List<String> blockers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa thể Check-out',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn chưa hoàn thành các điều kiện bắt buộc theo quy định:',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: blockers
                    .map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                b,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hãy hoàn thành các công việc trên trước khi đóng lượt viếng thăm.',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ĐÃ HIỂU'),
          ),
        ],
      ),
    );
  }

  void _showTimeWarningDialog(int secondsRemaining) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = secondsRemaining >= 60
        ? '${secondsRemaining ~/ 60} phút ${(secondsRemaining % 60).toString().padLeft(2, '0')} giây'
        : '$secondsRemaining giây';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa đủ thời gian',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chưa đủ thời gian viếng thăm tối thiểu theo quy định.',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vui lòng ở lại thêm $timeStr nữa để hoàn thành lượt viếng thăm.',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ĐÃ HIỂU'),
          ),
        ],
      ),
    );
  }

  void _showSurveyWarningDialog(
    List<MissingFormEntity> missingForms,
    CheckInState state,
    CheckInViewModel vm,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assignment_late_outlined, color: Color(0xFF0284C7), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa hoàn thành khảo sát',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Điểm bán này yêu cầu bạn hoàn thành các biểu mẫu khảo sát bắt buộc trước khi check-out:',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: missingForms
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                f.name,
                                style: const TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ĐỂ SAU'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openSurveyFormsSheet(context, state, vm);
            },
            child: const Text('LÀM KHẢO SÁT'),
          ),
        ],
      ),
    );
  }

  void _showPhotoWarningDialog(int photosMissing, CheckInViewModel vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_a_photo_outlined, color: Color(0xFF8B5CF6), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa đủ ảnh chụp',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lượt viếng thăm này yêu cầu chụp ảnh xác thực tại điểm bán.',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Color(0xFF7C3AED), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn cần chụp thêm ít nhất $photosMissing ảnh nữa (mặt tiền / trưng bày / POSM) để có thể check-out.',
                      style: const TextStyle(
                        color: Color(0xFF6D28D9),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ĐỂ SAU'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleTakePhoto(vm);
            },
            child: const Text('CHỤP ẢNH NGAY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInViewModelProvider);
    final vm = ref.read(checkInViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surveyCount = state.surveyForms.length;
    final completedSurveys = state.submittedSurveyConfigIds.length;
    final surveyProgress =
        surveyCount > 0 ? (completedSurveys / surveyCount).clamp(0.0, 1.0) : 0.0;
    final hasRequired = state.hasUnsubmittedRequiredSurveys;

    final req = state.requirements;
    final isClosed = state.visitResult == 'closed';
    final isTimeSatisfied = isClosed || (req != null ? req.secondsRemaining <= 0 : false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
        appBar: VthmTopAppBar(
          title: strings.visitingStoreTitle,
          showBackButton: true,
          showAvatar: false,
          showLogo: false,
          onBackPressed: _handleExit,
          trailing: const SizedBox.shrink(),
        ),
        body: state.checkinData == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.errorMessage ?? 'Không tải được dữ liệu điểm bán'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initAndCheckin,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isCheckingIn && state.visitId <= 0)
                    Container(
                      width: double.infinity,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Đang xác thực vị trí và mở lượt check-in...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Dealer Info Card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.marginMobile,
                            16,
                            AppSpacing.marginMobile,
                            0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.outlineVariant,
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(AppSpacing.marginMobile),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.checkinData!.dealer.name,
                                        style: AppTypography.titleMedium(
                                          color: isDark
                                              ? AppColors.primaryFixedDim
                                              : AppColors.primary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (state.visitId != 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (state.visitId > 0 ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: (state.visitId > 0 ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (state.visitId < 0) ...[
                                              const Icon(Icons.cloud_off_rounded, size: 12, color: Colors.amber),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              state.visitId > 0 ? 'Lượt #${state.visitId}' : 'Lưu trên máy',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: state.visitId > 0 ? const Color(0xFF10B981) : Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mã: ${state.checkinData!.dealer.id} · ${state.checkinData!.dealer.address}',
                                  style: AppTypography.labelSmall(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Divider(
                                  height: 1,
                                  color: (isDark
                                          ? AppColors.darkOutlineVariant
                                          : AppColors.outlineVariant)
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkSurfaceContainerLowest
                                              : AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.login_rounded,
                                              size: 18,
                                              color: isDark
                                                  ? AppColors.primaryFixedDim
                                                  : AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Giờ check-in',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? AppColors.darkOnSurfaceVariant
                                                          : AppColors.onSurfaceVariant,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    state.checkinTime,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: 'monospace',
                                                      color: isDark
                                                          ? AppColors.primaryFixedDim
                                                          : AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryContainer.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.timer_outlined,
                                              size: 18,
                                              color: AppColors.secondary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Thời gian viếng thăm',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? AppColors.darkOnSurfaceVariant
                                                          : AppColors.onSurfaceVariant,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    state.liveVisitDuration,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: 'monospace',
                                                      color: AppColors.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. Visit Result Selector (Mở cửa / Đóng cửa §6 & §7)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.marginMobile,
                            16,
                            AppSpacing.marginMobile,
                            0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tình trạng điểm bán lúc viếng thăm',
                                  style: AppTypography.labelSmall(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => vm.setVisitResult('visited'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: !isClosed
                                                ? AppColors.primary.withValues(alpha: 0.12)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: !isClosed
                                                  ? AppColors.primary
                                                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                                              width: !isClosed ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                !isClosed ? Icons.radio_button_checked : Icons.radio_button_off,
                                                size: 18,
                                                color: !isClosed ? AppColors.primary : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Mở cửa',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: !isClosed ? FontWeight.w600 : FontWeight.normal,
                                                  color: !isClosed
                                                      ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                                      : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => vm.setVisitResult('closed'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: isClosed
                                                ? AppColors.secondary.withValues(alpha: 0.12)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isClosed
                                                  ? AppColors.secondary
                                                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                                              width: isClosed ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isClosed ? Icons.radio_button_checked : Icons.radio_button_off,
                                                size: 18,
                                                color: isClosed ? AppColors.secondary : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Đóng cửa',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
                                                  color: isClosed
                                                      ? AppColors.secondary
                                                      : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isClosed) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ℹ️ Lượt đóng cửa được miễn thời gian tối thiểu và khảo sát. Cần chụp tối thiểu 1 ảnh đóng cửa làm bằng chứng.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _closedNoteController,
                                    decoration: InputDecoration(
                                      hintText: 'Nhập lý do điểm bán đóng cửa (nghỉ lễ, sửa chữa...)...',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      suffixIcon: VoiceInputMicButton(
                                        fieldName: 'Lý do đóng cửa',
                                        currentText: _closedNoteController.text,
                                        onTextRecognized: (text) {
                                          _closedNoteController.text = text;
                                          _closedNoteController.selection = TextSelection.fromPosition(
                                            TextPosition(offset: text.length),
                                          );
                                          vm.setClosedNote(text);
                                        },
                                      ),
                                    ),
                                    onChanged: (val) => vm.setClosedNote(val),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 4. Tasks Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.marginMobile,
                            20,
                            AppSpacing.marginMobile,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Công việc cần làm',
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),

                              // Task 1: Forms
                              _buildTaskCard(
                                context: context,
                                isDark: isDark,
                                icon: Icons.assignment_outlined,
                                iconColor: isClosed
                                    ? const Color(0xFF10B981)
                                    : (completedSurveys > 0 && completedSurveys >= surveyCount
                                        ? const Color(0xFF10B981)
                                        : (hasRequired ? AppColors.error : AppColors.primary)),
                                title: 'Khảo sát điểm bán',
                                subtitle: isClosed
                                    ? 'Được miễn khảo sát do điểm bán đóng cửa'
                                    : (surveyCount > 0
                                        ? (hasRequired
                                            ? 'Còn ${state.unsubmittedRequiredSurveys.length} biểu mẫu bắt buộc'
                                            : 'Đã hoàn thành $completedSurveys/$surveyCount')
                                        : 'Không có biểu mẫu khảo sát'),
                                trailing: isClosed
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$completedSurveys/$surveyCount',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: hasRequired
                                                  ? AppColors.error
                                                  : (isDark ? AppColors.primaryFixedDim : AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          CustomDonutProgress(
                                            progress: surveyProgress,
                                            size: 24,
                                            strokeWidth: 3.5,
                                            progressColor: completedSurveys > 0 && completedSurveys >= surveyCount
                                                ? const Color(0xFF10B981)
                                                : (hasRequired
                                                    ? AppColors.error
                                                    : (isDark ? AppColors.primaryFixedDim : AppColors.primaryContainer)),
                                          ),
                                        ],
                                      ),
                                onTap: isClosed ? () {} : () => _openSurveyFormsSheet(context, state, vm),
                              ),
                              const SizedBox(height: 12),

                              // Task 2: Photos (§4)
                              _buildTaskCard(
                                context: context,
                                isDark: isDark,
                                icon: Icons.photo_camera_outlined,
                                iconColor: state.photos.isNotEmpty
                                    ? const Color(0xFF10B981)
                                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                                title: 'Chụp ảnh điểm bán',
                                subtitleWidget: state.isUploadingPhoto
                                    ? const Row(
                                        children: [
                                          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                          SizedBox(width: 6),
                                          Text('Đang tải ảnh lên...', style: TextStyle(fontSize: 12)),
                                        ],
                                      )
                                    : state.photos.isNotEmpty
                                        ? Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${state.photos.length} ảnh đã chụp',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            children: [
                                              Icon(Icons.error_outline, size: 14, color: AppColors.error),
                                              SizedBox(width: 4),
                                              Text(
                                                'Chưa có ảnh',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                trailing: state.isUploadingPhoto
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(
                                        Icons.add_a_photo_outlined,
                                        color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                      ),
                                onTap: () => _handleTakePhoto(vm),
                              ),

                              // Photo Gallery Thumbnails
                              if (state.photos.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 100,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: state.photos.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (ctx, idx) {
                                      final photo = state.photos[idx];
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: photo.localPath != null && File(photo.localPath!).existsSync()
                                                ? Image.file(File(photo.localPath!), fit: BoxFit.cover)
                                                : Image.network(
                                                    photo.fullPublicUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            bottom: 4,
                                            left: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                photo.photoTypeLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white, fontSize: 9),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: GestureDetector(
                                              onTap: () => _handleDeletePhoto(vm, photo),
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Task 3: Notes
                              _buildTaskCard(
                                context: context,
                                isDark: isDark,
                                icon: Icons.edit_note_rounded,
                                iconColor: _noteController.text.trim().isNotEmpty
                                    ? const Color(0xFF10B981)
                                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                                title: 'Ghi chú chuyến ghé',
                                subtitle: _noteController.text.trim().isNotEmpty
                                    ? _noteController.text.trim()
                                    : 'Thêm ý kiến phản hồi',
                                trailing: Icon(
                                  _noteController.text.trim().isNotEmpty
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right,
                                  color: _noteController.text.trim().isNotEmpty
                                      ? const Color(0xFF10B981)
                                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                                ),
                                onTap: _openNoteDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        bottomNavigationBar: state.checkinData == null
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        offset: Offset(0, -4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Rời phiên / Hủy Button
                      OutlinedButton.icon(
                        onPressed: () => _confirmAndCancelVisit(vm),
                        icon: const Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Hủy check-in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          minimumSize: const Size(0, 48),
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CHECK-OUT Button (§7)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.status == CheckInStatus.checkingOut
                              ? null
                              : () async {
                                  // Ưu tiên 1: THỜI GIAN (Time)
                                  if (!isClosed && req != null && req.secondsRemaining > 0) {
                                    _showTimeWarningDialog(req.secondsRemaining);
                                    return;
                                  }

                                  // Ưu tiên 2: KHẢO SÁT (Surveys)
                                  if (!isClosed && req != null && req.missingForms.isNotEmpty) {
                                    _showSurveyWarningDialog(req.missingForms, state, vm);
                                    return;
                                  }

                                  // Ưu tiên 3: ẢNH CHỤP (Photos)
                                  if (req != null && req.photosMissing > 0) {
                                    _showPhotoWarningDialog(req.photosMissing, vm);
                                    return;
                                  }

                                  // Fallback: blockers khác từ server
                                  if (req != null && !req.satisfied && req.blockers.isNotEmpty) {
                                    _showBlockersDialog(req.blockers);
                                    return;
                                  }

                                  final pos = await ref
                                      .read(locationServiceProvider)
                                      .checkAndGetLocation(context);

                                  // Kiểm tra khoảng cách check-out (nếu điểm bán có toạ độ GPS)
                                  double? dealerLat = widget.dealer?.lat ?? state.checkinData?.dealer.lat;
                                  double? dealerLng = widget.dealer?.lng ?? state.checkinData?.dealer.lng;
                                  String dealerName = widget.dealer?.name ?? state.checkinData?.dealer.name ?? '';
                                  String? dealerAddress = widget.dealer?.address ?? state.checkinData?.dealer.address;

                                  if (dealerLat == null && state.customer is CustomerEntity) {
                                    final cust = state.customer as CustomerEntity;
                                    dealerLat = cust.lat;
                                    dealerLng = cust.lng;
                                    if (dealerName.isEmpty) dealerName = cust.name;
                                    dealerAddress ??= cust.address;
                                  }
                                  if (dealerName.isEmpty) {
                                    dealerName = state.visitEntity?.customerName ?? 'Điểm bán';
                                  }

                                  final mobileRules = ref.read(mobileRulesProvider);
                                  final allowedRadius = GeofenceRuleHelper.resolveAllowedRadius(
                                    dealer: widget.dealer ?? state.checkinData?.dealer,
                                    customer: state.customer is CustomerEntity ? (state.customer as CustomerEntity) : null,
                                    rules: mobileRules,
                                  );

                                  if (dealerLat != null && dealerLng != null && mobileRules.visit.requireGeofence) {
                                    if (pos == null) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vui lòng bật định vị GPS để xác thực khoảng cách khi check-out'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    final distanceM = Geolocator.distanceBetween(
                                      pos.latitude,
                                      pos.longitude,
                                      dealerLat,
                                      dealerLng,
                                    );

                                    if (distanceM > allowedRadius) {
                                      if (context.mounted) {
                                        showCheckinDistanceWarningDialog(
                                          context,
                                          dealerName: dealerName,
                                          distanceMeters: distanceM,
                                          allowedRadiusMeters: allowedRadius,
                                          lat: dealerLat,
                                          lng: dealerLng,
                                          address: dealerAddress,
                                          isCheckout: true,
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  // 🔴 KIỂM TRA CHỐNG GIAN LẬN TRƯỚC KHI CHECK-OUT VIẾNG THĂM
                                  if (context.mounted) {
                                    final fraudCheck = await ref.read(antiFraudServiceProvider).validateAction(
                                      context,
                                      position: pos,
                                      actionType: AntiFraudActionType.visitCheckout,
                                      actionTitle: 'Check-out viếng thăm',
                                    );
                                    if (!fraudCheck.isAllowed) return;
                                  }

                                  final (success, errorMsg) = await vm.checkout(
                                    lat: pos?.latitude,
                                    lng: pos?.longitude,
                                    accuracyM: pos?.accuracy,
                                    allowedRadiusMeters: allowedRadius,
                                    requireGeofence: mobileRules.visit.requireGeofence,
                                  );

                                  if (success && context.mounted) {
                                    // Tải lại danh sách tuyến để cập nhật trạng thái "Đã ghé" (§2.3)
                                    ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
                                    await ref.read(visitRepositoryProvider).clearActiveVisit();
                                    if (!context.mounted) return;
                                    ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);

                                    await CheckoutSuccessDialog.show(
                                      context,
                                      dealerName: state.checkinData?.dealer.name ?? 'Khách hàng',
                                    );
                                    if (context.mounted) {
                                      vm.resetSession();
                                      context.pop();
                                    }
                                  } else if (errorMsg != null && context.mounted) {
                                    _showBlockersDialog([errorMsg]);
                                  }
                                },
                          icon: state.status == CheckInStatus.checkingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(
                                  isTimeSatisfied
                                      ? Icons.check_circle_rounded
                                      : Icons.timer_outlined,
                                  size: 18,
                                  color: isTimeSatisfied
                                      ? Colors.white
                                      : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B)),
                                ),
                          label: Text(
                            state.status == CheckInStatus.checkingOut
                                ? 'ĐANG CHECK-OUT...'
                                : 'CHECK-OUT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isTimeSatisfied
                                  ? Colors.white
                                  : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B)),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTimeSatisfied
                                ? const Color(0xFF10B981)
                                : (isDark
                                    ? AppColors.darkSurfaceContainer
                                    : const Color(0xFFE2E8F0)),
                            foregroundColor: isTimeSatisfied
                                ? Colors.white
                                : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B)),
                            elevation: isTimeSatisfied ? 3 : 0,
                            shadowColor: isTimeSatisfied
                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                : Colors.transparent,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    if (subtitleWidget != null)
                      subtitleWidget
                    else if (subtitle != null)
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

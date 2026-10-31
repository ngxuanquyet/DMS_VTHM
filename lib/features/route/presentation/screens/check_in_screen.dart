import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_donut_chart.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../../core/widgets/voice_input_mic_button.dart';
import '../../../../core/widgets/camera_permission_dialog.dart';
import '../../../../core/widgets/app_fullscreen_image_viewer.dart';
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
import '../widgets/checkout_confirmation_dialog.dart';
import '../widgets/checkout_success_dialog.dart';
import '../widgets/visit_exit_options_dialog.dart';
import '../../../forms/presentation/screens/market_form_fill_screen.dart';
import '../../../forms/presentation/widgets/market_form_card.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../../visit/presentation/widgets/customer_visit_history_widget.dart';
import '../../../visit/data/repositories/visit_material_repository.dart';
import '../../../visit/presentation/screens/visit_materials_screen.dart';

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

  /// 403 khi nạp vật tư ⇒ tài khoản không có quyền vật tư, ẩn mục Vật tư (#24522).
  bool _materialsForbidden = false;

  /// Chưa có danh sách vật tư bắt buộc của CHÍNH điểm bán (chưa từng tải, hoặc chỉ có danh mục của điểm bán khác) ⇒
  /// không biết cổng ④ đòi gì: hỏi lại trước khi check-out, KHÔNG chặn cứng (luật theo loại điểm bán). Đặt lại khi
  /// GET vật tư sau đó thành công.
  bool _materialsUnknown = false;

  /// Số loại vật tư bắt buộc của lượt (bản nạp gần nhất) — dòng "Vật tư bắt buộc" của hộp xác nhận check-out.
  int? _requiredMaterialCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initAndCheckin();
      await _checkLostData();
      await _prefetchMaterials();
    });
  }

  /// id điểm bán của lượt đang mở (điểm bán đã nạp → điểm bán của tuyến → mã số trong dealer.id).
  int _effectiveCustomerId(CheckInState state) {
    if (state.customer is CustomerEntity) return (state.customer as CustomerEntity).id;
    if (widget.dealer?.customer is CustomerEntity) return (widget.dealer!.customer as CustomerEntity).id;
    return int.tryParse(state.checkinData?.dealer.id.replaceAll(RegExp(r'[^\d]'), '') ?? '') ?? 0;
  }

  /// Nạp sẵn vật tư sau check-in: lưu danh mục để dùng ngoại tuyến, biết có quyền không, và (ngoại tuyến) dựng cổng
  /// check-out ④ từ bản lưu trên máy — khi trực tuyến `requirements` của server đã mang `missing_materials`.
  /// Lượt nạp vật tư gần nhất — lượt mới CHỜ lượt trước xong rồi mới chạy (postFrame + visitId 0→>0 + rời màn Vật tư có
  /// thể gọi chồng nhau; hai GET song song ghi đè cache của nhau).
  Future<void>? _prefetchChain;

  Future<void> _prefetchMaterials() {
    final previous = _prefetchChain;
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _prefetchMaterialsOnce();
    }();
    _prefetchChain = next;
    return next;
  }

  Future<void> _prefetchMaterialsOnce() async {
    if (!mounted) return;
    final state = ref.read(checkInViewModelProvider);
    if (state.visitId == 0) return;
    final vm = ref.read(checkInViewModelProvider.notifier);
    final res = await ref.read(visitMaterialRepositoryProvider).load(
          visitId: state.visitId,
          customerId: _effectiveCustomerId(state),
          visitClientUuid: vm.sessionClientUuid,
        );
    if (!mounted) return;
    if (res.forbidden) {
      setState(() {
        _materialsForbidden = true;
        _requiredMaterialCount = null;
      });
      return;
    }
    setState(() {
      _materialsUnknown = res.data == null || res.requiredFromOtherOutlet;
      _requiredMaterialCount = _materialsUnknown ? null : res.data!.requiredTypeIds.length;
    });
    if (res.data != null) vm.applyMaterialRequirements(res.data!.missingAfterLocal);
  }

  /// Chưa biết danh sách vật tư bắt buộc (chưa từng tải) ⇒ hỏi lại trước khi check-out — server có thể từ chối.
  Future<bool> _confirmCheckoutWithoutMaterialList() async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.materialsTaskTitle),
        content: Text(strings.materialsRequiredUnknownCheckout),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(strings.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(strings.continueAction)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openMaterials(CheckInState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VisitMaterialsScreen(
          customerId: _effectiveCustomerId(state),
          dealerName: state.checkinData?.dealer.name ?? '',
        ),
      ),
    );
    // Màn Vật tư vừa tải / lưu ⇒ nạp lại để cập nhật cờ "chưa biết danh sách bắt buộc" + cổng ④.
    await _prefetchMaterials();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _closedNoteController.dispose();
    super.dispose();
  }

  Future<void> _initAndCheckin() async {
    final vm = ref.read(checkInViewModelProvider.notifier);

    // Đồng bộ hoặc nạp quy tắc viếng thăm từ cache
    ref.read(mobileRulesProvider.notifier).fetchRules();

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
        (v) => (v.id == currentActive.id && v.id > 0) ||
            (currentActive.clientUuid != null &&
                currentActive.clientUuid!.isNotEmpty &&
                v.clientUuid == currentActive.clientUuid),
      ).firstOrNull;

      // ⚠️ Nếu todayVisits đã tải về từ server thành công nhưng lượt server (currentActive.id > 0) biến mất:
      // Theo §4.1 HUY-LUOT-VIENG-THAM-2026-09-30, lượt đã huỷ biến mất khỏi /dms/visits/mine
      final isStaleCancelledOnServer = todayVisits.isNotEmpty &&
          currentActive.id > 0 &&
          matchingServerVisit == null;

      if ((matchingServerVisit != null && !matchingServerVisit.isOpen) || isStaleCancelledOnServer) {
        final isCancelled = isStaleCancelledOnServer || (matchingServerVisit?.isCancelled == true);
        debugPrint('[CheckInScreen] Active visit id=${currentActive.id} đã ${isCancelled ? "bị huỷ" : "hoàn tất"} trên server, giải phóng phiên stale.');
        await ref.read(visitRepositoryProvider).clearActiveVisit();
        if (isCancelled) {
          await ref.read(visitRepositoryProvider).cancelVisit(currentActive.id, clientUuid: currentActive.clientUuid);
          ref.read(routeViewModelProvider.notifier).markVisitCancelledLocally(currentActive.id, clientUuid: currentActive.clientUuid);
        }
        ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
        vm.resetSession();
        activeVisit = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCancelled
                    ? 'Lượt viếng thăm trước đó đã được huỷ. Bạn có thể bắt đầu lượt check-in mới.'
                    : 'Lượt viếng thăm trước đó đã hoàn tất. Bạn có thể bắt đầu lượt check-in mới.',
              ),
              backgroundColor: isCancelled ? const Color(0xFF0284C7) : const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    final targetCustomerId = widget.dealer != null
        ? (widget.dealer!.customer is CustomerEntity
            ? (widget.dealer!.customer as CustomerEntity).id
            : (widget.dealer!.customer is Map
                ? int.tryParse((widget.dealer!.customer as Map)['id']?.toString() ?? '')
                : int.tryParse(widget.dealer!.id.replaceAll(RegExp(r'[^\d]'), ''))))
        : null;

    if (activeVisit != null) {
      if (targetCustomerId != null && targetCustomerId != activeVisit.customerId) {
        final activeName = activeVisit.customerName.isNotEmpty
            ? activeVisit.customerName
            : (currentState.checkinData?.dealer.name ?? 'Điểm bán khác');
        if (mounted) {
          final chosenDealer = await showActiveVisitBlockingDialog(
            context: context,
            ref: ref,
            activeVisit: activeVisit,
            activeDealerName: activeName,
            targetDealerName: widget.dealer!.name,
            onClose: () {
              if (mounted) _safePop();
            },
          );
          if (chosenDealer != null && mounted) {
            context.pushReplacement('/check-in', extra: chosenDealer);
          } else if (mounted) {
            _safePop();
          }
        }
        return;
      }

      // ⚠️ Khi quay lại đúng điểm bán đang có phiên mở dở dang:
      // Tự động phục hồi phiên và tuyệt đối KHÔNG gọi check-in mới để tránh duplicate
      if (targetCustomerId == null || targetCustomerId == activeVisit.customerId) {
        final dealerToInit = widget.dealer != null
            ? (widget.dealer!.visit != null
                ? widget.dealer!
                : widget.dealer!.copyWith(visit: activeVisit, status: DealerVisitStatus.inProgress))
            : DealerEntity(
                id: activeVisit.customerId.toString(),
                order: '01',
                name: activeVisit.customerName,
                address: activeVisit.customerAddress ?? '',
                status: DealerVisitStatus.inProgress,
                statusLabel: 'Đang ghé',
                isVip: false,
                visit: activeVisit,
              );
        vm.initCheckinWithDealer(dealerToInit);
        await vm.restoreActiveVisitIfAvailable(activeVisit.customerId);

        final cs = ref.read(checkInViewModelProvider);
        if (_noteController.text.isEmpty && cs.visitNote.isNotEmpty) {
          _noteController.text = cs.visitNote;
        }
        if (_closedNoteController.text.isEmpty && cs.closedNote.isNotEmpty) {
          _closedNoteController.text = cs.closedNote;
        }
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
        final currentState = ref.read(checkInViewModelProvider);
        if (currentState.visitId != 0) {
          await ref.read(checkInViewModelProvider.notifier).cancelVisit();
        } else {
          ref.read(checkInViewModelProvider.notifier).resetSession();
          await ref.read(visitRepositoryProvider).clearActiveVisit();
          ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
        }
        if (mounted) {
          ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy lượt check-in.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
          _safePop();
        }
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

    String displayMessage = errorMessage;
    String? code;
    final codeRegex = RegExp(r'\(Mã lỗi:\s*([^)]+)\)');
    final match = codeRegex.firstMatch(displayMessage);
    if (match != null) {
      code = match.group(1)?.trim();
      displayMessage = displayMessage.replaceAll(codeRegex, '').trim();
    } else {
      final legacyRegExp = RegExp(r'\(code:\s*(\d+),\s*error_code:\s*([^)]+)\)');
      final legacyMatch = legacyRegExp.firstMatch(displayMessage);
      if (legacyMatch != null) {
        code = '${legacyMatch.group(2)?.trim()} (${legacyMatch.group(1)})';
        displayMessage = displayMessage.replaceAll(legacyRegExp, '').trim();
      }
    }

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
                displayMessage,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Mã lỗi: $code',
                        style: TextStyle(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã lỗi vào bộ nhớ tạm.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              final currentState = ref.read(checkInViewModelProvider);
              if (currentState.visitId != 0) {
                await ref.read(checkInViewModelProvider.notifier).cancelVisit();
              } else {
                ref.read(checkInViewModelProvider.notifier).resetSession();
                await ref.read(visitRepositoryProvider).clearActiveVisit();
                ref.read(routeViewModelProvider.notifier).setActiveVisit(null);
              }
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
      } catch (_) {
        if (mounted) {
          context.go('/route');
        }
      }
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
        AppSnackBar.showError(context, errorMsg);
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
          vm.resetSession();
          _safePop();
        }
      } else {
        vm.resetSession();
        _safePop();
      }
      return;
    }

    // Nếu lượt đang mở (cả online lẫn offline): Cho phép tạm rời giữ trạng thái viếng thăm hoặc huỷ lượt
    await _showExitOptionsDialog(vm);
  }

  /// Hộp thoại lựa chọn khi thoát màn hình lúc đang có phiên viếng thăm mở
  Future<void> _showExitOptionsDialog(CheckInViewModel vm) async {
    final state = ref.read(checkInViewModelProvider);
    final dealerName = state.checkinData?.dealer.name ??
        state.visitEntity?.customerName ??
        widget.dealer?.name ??
        'Điểm bán';

    final choice = await VisitExitOptionsDialog.show(
      context: context,
      dealerName: dealerName,
    );

    if (!mounted || choice == null || choice == 'stay') return;

    if (choice == 'cancel') {
      await _confirmAndCancelVisit(vm);
      return;
    }

    if (choice == 'pause') {
      vm.setVisitNote(_noteController.text.trim());
      vm.setClosedNote(_closedNoteController.text.trim());
      await vm.saveCurrentActiveSession();

      try {
        final isOnline = ref.read(connectivityProvider).isOnline;
        if (isOnline) {
          unawaited(ref.read(syncServiceProvider).syncQueue());
        }
      } catch (_) {}

      ref.read(routeViewModelProvider.notifier).loadRouteDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.pause_circle_filled_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang tạm rời. Lượt viếng thăm tại $dealerName vẫn được giữ nguyên.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        _safePop();
      }
    }
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
              ref.read(checkInViewModelProvider.notifier).setVisitNote(tempController.text);
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
        if (message.startsWith('VISIT_CANCELLED:') ||
            message.toLowerCase().contains('đã bị huỷ') ||
            message.toLowerCase().contains('đã huỷ') ||
            message.toLowerCase().contains('already cancelled')) {
          _showCancelledVisitRecoveryDialog(vm);
          return;
        }

        AppSnackBar.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e);
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
      } else if (message != null) {
        if (message.startsWith('VISIT_CANCELLED:') ||
            message.toLowerCase().contains('đã bị huỷ') ||
            message.toLowerCase().contains('đã huỷ') ||
            message.toLowerCase().contains('already cancelled')) {
          _showCancelledVisitRecoveryDialog(vm);
          return;
        }
      }
    } catch (_) {}
  }

  /// Hộp thoại hỗ trợ khôi phục khi lượt viếng thăm trên server đã bị huỷ
  Future<void> _showCancelledVisitRecoveryDialog(CheckInViewModel vm) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClosed = ref.read(checkInViewModelProvider).visitResult == 'closed';
    final savedClosedNote = _closedNoteController.text;
    final savedVisitNote = _noteController.text;

    final shouldRecheckin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lượt viếng thăm đã bị huỷ',
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
              'Lượt viếng thăm này đã bị huỷ trên hệ thống nên không thể thêm ảnh hay hoàn tất.',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn có muốn tạo lượt check-in mới ngay bây giờ để tiếp tục ghi nhận ${isClosed ? "điểm bán đóng cửa" : "viếng thăm"} không?',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('QUAY LẠI TUYẾN'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CHECK-IN LẠI'),
          ),
        ],
      ),
    );

    if (shouldRecheckin == true && mounted) {
      vm.resetSession();
      if (isClosed) {
        vm.setVisitResult('closed');
        if (savedClosedNote.isNotEmpty) {
          _closedNoteController.text = savedClosedNote;
          vm.setClosedNote(savedClosedNote);
        }
      }
      if (savedVisitNote.isNotEmpty) {
        _noteController.text = savedVisitNote;
        vm.setVisitNote(savedVisitNote);
      }
      await _checkinIfNeeded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo lượt check-in mới thành công. Bạn có thể chụp ảnh ngay bây giờ.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (mounted) {
      vm.resetSession();
      _safePop();
    }
  }

  Future<String?> _showPhotoTypeSelectionSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClosed = ref.read(checkInViewModelProvider).visitResult == 'closed';
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
                isClosed
                    ? 'Ghi nhận điểm bán đóng cửa - Chụp ảnh cửa hàng đóng/biển hiệu làm bằng chứng'
                    : 'Phân loại giúp chuẩn hóa báo cáo trưng bày và hình ảnh điểm bán',
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (isClosed)
                _buildPhotoTypeTile(ctx, 'closed_store', 'Ảnh đóng cửa điểm bán', Icons.door_back_door_outlined, isDark),
              _buildPhotoTypeTile(ctx, 'store_front', 'Mặt tiền điểm bán', Icons.storefront_outlined, isDark),
              if (!isClosed) ...[
                _buildPhotoTypeTile(ctx, 'display', 'Ảnh trưng bày hàng hóa', Icons.grid_view_rounded, isDark),
                _buildPhotoTypeTile(ctx, 'posm', 'Vật phẩm quảng cáo (POSM)', Icons.campaign_outlined, isDark),
                _buildPhotoTypeTile(ctx, 'document', 'Hóa đơn / Giấy tờ / Sổ sách', Icons.receipt_long_outlined, isDark),
              ],
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
        AppSnackBar.showError(context, message);
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

    // #23682: chỉ kênh Bravo (`erp_channels`). KHÔNG rơi về `channelId` cũ — đó là id danh mục kênh MobiWork, khác hẳn
    // id `sales_channel` mà điều kiện `@customer.channel_ids` so sánh.
    final customerChannelIds = customer?.erpChannels.map((c) => c.id).toList() ?? <int>[];
    final customerTerritoryCodes = customer?.territories ?? <String>[];

    final customerContext = MarketFormFillArgs.buildCustomerContext(
      typeId: customer?.customerTypeId,
      channelIds: customerChannelIds,
      territoryCodes: customerTerritoryCodes,
      regionId: customer?.regionId,
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
                              visitClientUuid: vm.sessionClientUuid,
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

  /// [action]: nút đi sửa ngay (vd "Đi kiểm vật tư") cạnh "ĐÃ HIỂU" — đóng hộp rồi chạy.
  void _showBlockersDialog(List<String> blockers, {({String label, VoidCallback onPressed})? action}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedBlockers = blockers.map((b) {
      String text = b;
      String? code;
      final codeRegex = RegExp(r'\(Mã lỗi:\s*([^)]+)\)');
      final match = codeRegex.firstMatch(b);
      if (match != null) {
        code = match.group(1)?.trim();
        text = b.replaceAll(codeRegex, '').trim();
      }
      return (text, code);
    }).toList();

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
                children: parsedBlockers
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    item.$1,
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
                            if (item.$2 != null && item.$2!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Mã lỗi: ${item.$2}',
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: item.$2!));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã sao chép mã lỗi vào bộ nhớ tạm.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
          if (action != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                action.onPressed();
              },
              child: Text(action.label),
            ),
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
    final isClosed = ref.read(checkInViewModelProvider).visitResult == 'closed';
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
              isClosed
                  ? 'Lượt ghi nhận điểm bán đóng cửa yêu cầu chụp ảnh xác thực cửa hàng đang đóng.'
                  : 'Lượt viếng thăm này yêu cầu chụp ảnh xác thực tại điểm bán.',
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
                      isClosed
                          ? 'Bạn cần chụp thêm ít nhất $photosMissing ảnh xác nhận đóng cửa điểm bán để có thể check-out.'
                          : 'Bạn cần chụp thêm ít nhất $photosMissing ảnh nữa (mặt tiền / trưng bày / POSM) để có thể check-out.',
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
    // Lượt ngoại tuyến vừa lên server (có id thật) ⇒ GET vật tư được rồi: nạp lại để thay danh sách ước đoán.
    ref.listen<int>(checkInViewModelProvider.select((s) => s.visitId), (prev, next) {
      if (next > 0 && (prev ?? 0) <= 0) _prefetchMaterials();
    });
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
    final isOpenVisit = state.visitId != 0 && (state.visitEntity == null || state.visitEntity!.isOpen);

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
          trailing: isOpenVisit
              ? TextButton.icon(
                  onPressed: _handleExit,
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Tạm rời',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
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
                  if (state.isOutOfGeofence && state.currentDistanceToDealerM != null)
                    _buildGeofenceAlertBanner(context, state, isDark),
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
                                () {
                                  final activeCust = state.customer is CustomerEntity
                                      ? (state.customer as CustomerEntity)
                                      : (widget.dealer?.customer is CustomerEntity
                                          ? (widget.dealer!.customer as CustomerEntity)
                                          : null);
                                  final isPendingAppr = activeCust?.isPendingApproval ?? false;
                                  final isRejectedAppr = activeCust?.isRejectedApproval ?? false;

                                  if (isPendingAppr) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0x33D97706) : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFCD34D)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 15),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Điểm bán đang chờ duyệt — Hồ sơ & lượt viếng thăm này sẽ được gửi duyệt đồng thời.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (isRejectedAppr) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0x33DC2626) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 15),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Điểm bán bị từ chối duyệt: ${activeCust?.approvalNote ?? "Chưa rõ lý do"}. Lượt viếng thăm vẫn được lưu lại nhưng không tính KPI.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }(),
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
                                                  // Đồng hồ chạy từng giây — chỉ dựng lại dòng này, không cả màn.
                                                  ValueListenableBuilder<String>(
                                                    valueListenable: vm.liveDuration,
                                                    builder: (context, duration, _) => Text(
                                                    duration,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: 'monospace',
                                                      color: AppColors.secondary,
                                                    ),
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
                                    child: Text(
                                      'ℹ️ Lượt đóng cửa được miễn thời gian tối thiểu và khảo sát. Cần chụp tối thiểu ${ref.watch(mobileRulesProvider).visit.closedMinPhotos} ảnh đóng cửa làm bằng chứng.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
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
                                                '${state.photos.length} ảnh đã chụp${req != null && req.photosMissing > 0 ? " (còn thiếu ${req.photosMissing})" : ""}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                                              const SizedBox(width: 4),
                                              Text(
                                                isClosed
                                                    ? 'Cần chụp ít nhất ${ref.watch(mobileRulesProvider).visit.closedMinPhotos} ảnh đóng cửa'
                                                    : 'Chưa có ảnh (cần tối thiểu ${ref.watch(mobileRulesProvider).visit.minPhotos} ảnh)',
                                                style: const TextStyle(
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
                                          GestureDetector(
                                            onTap: () {
                                              final items = state.photos.map((p) {
                                                return FullScreenImageItem(
                                                  filePath: p.localPath,
                                                  url: p.fullPublicUrl,
                                                  title: p.photoTypeLabel,
                                                  subtitle: p.takenAt != null ? 'Chụp lúc: ${p.takenAt}' : null,
                                                );
                                              }).toList();
                                              AppFullScreenImageViewer.open(
                                                context,
                                                items: items,
                                                initialIndex: idx,
                                              );
                                            },
                                            child: Container(
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
                                                  ? Image.file(File(photo.localPath!), fit: BoxFit.cover, cacheWidth: 300)
                                                  : Image.network(
                                                      photo.fullPublicUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Center(
                                                        child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                                      ),
                                                      cacheWidth: 300,
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

                              // Task: Vật tư tại điểm bán (#24522) — cổng check-out ④
                              if (isOpenVisit && !_materialsForbidden) ...[
                                _buildTaskCard(
                                  context: context,
                                  isDark: isDark,
                                  icon: Icons.inventory_2_outlined,
                                  iconColor: isClosed || (req?.missingMaterials.isEmpty ?? true)
                                      ? const Color(0xFF10B981)
                                      : AppColors.error,
                                  title: strings.materialsTaskTitle,
                                  subtitle: isClosed
                                      ? strings.materialsClosedExempt
                                      : _materialsUnknown
                                      ? strings.materialsRequiredUnknown
                                      : ((req?.missingMaterials.isNotEmpty ?? false)
                                          ? strings.materialsMissingCount(req!.missingMaterials.length)
                                          : strings.materialsTapToCheck),
                                  trailing: (!isClosed && (req?.missingMaterials.isNotEmpty ?? false))
                                      ? const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20)
                                      : Icon(
                                          Icons.chevron_right,
                                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                                        ),
                                  onTap: () => _openMaterials(state),
                                ),
                                const SizedBox(height: 12),
                              ],

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

                        // 5. Lịch sử viếng thăm của điểm bán (§2.4 SPEC 16/10/2026)
                        () {
                          final effectiveCustomerId = _effectiveCustomerId(state);
                          if (effectiveCustomerId <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.marginMobile,
                              16,
                              AppSpacing.marginMobile,
                              20,
                            ),
                            child: CustomerVisitHistoryWidget(
                              customerId: effectiveCustomerId,
                              customerName: state.checkinData?.dealer.name,
                              initiallyExpanded: true,
                            ),
                          );
                        }(),
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

                                  // Ưu tiên 4: VẬT TƯ BẮT BUỘC (#24522) — server đã có câu trong blockers
                                  if (!isClosed && req != null && req.missingMaterials.isNotEmpty) {
                                    _showBlockersDialog(
                                      [
                                        strings.materialsCheckoutBlocked(
                                          req.missingMaterials.map((m) => m.name).join(', '),
                                        ),
                                      ],
                                      action: (
                                        label: strings.materialsGoCheck,
                                        // Đọc lượt MỚI lúc bấm (không dùng bản chụp lúc dựng nút); màn đã đóng thì thôi.
                                        onPressed: () {
                                          if (mounted) _openMaterials(ref.read(checkInViewModelProvider));
                                        },
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isClosed &&
                                      _materialsUnknown &&
                                      !_materialsForbidden &&
                                      !await _confirmCheckoutWithoutMaterialList()) {
                                    return;
                                  }
                                  if (!context.mounted) return;

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

                                  double? checkoutDistanceM;
                                  if (pos != null && dealerLat != null && dealerLng != null) {
                                    checkoutDistanceM = Geolocator.distanceBetween(
                                      pos.latitude,
                                      pos.longitude,
                                      dealerLat,
                                      dealerLng,
                                    );
                                  } else if (pos == null && dealerLat != null && dealerLng != null && mobileRules.visit.requireGeofence) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Không thể lấy tọa độ GPS lúc check-out. Tọa độ sẽ được ghi nhận là chưa tính được.'),
                                          backgroundColor: AppColors.warning,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }

                                  final isOutOfGeofence = checkoutDistanceM != null &&
                                      mobileRules.visit.requireGeofence &&
                                      checkoutDistanceM > allowedRadius;

                                  bool userConfirmedCheckout = false;

                                  // Kiểm tra luật khoảng cách trước khi check-out (§1 & §3 SPEC-2026-10-13)
                                  if (isOutOfGeofence) {
                                    if (!context.mounted) return;
                                    // Thông báo khoảng cách vượt bán kính và có thể bị gắn cờ vi phạm (ngoài vùng)
                                    final acceptProceed = await showCheckoutDistanceWarningDialog(
                                      context,
                                      dealerName: dealerName,
                                      distanceMeters: checkoutDistanceM,
                                      allowedRadiusMeters: allowedRadius,
                                      lat: dealerLat,
                                      lng: dealerLng,
                                      address: dealerAddress,
                                    );

                                    // Nếu user không chấp nhận -> dừng lại, không check-out
                                    if (!acceptProceed || !context.mounted) return;
                                    userConfirmedCheckout = true;
                                  } else {
                                    // Trường hợp vị trí hợp lệ hoặc không có GPS/tọa độ điểm bán: Hiện xác nhận check-out thông thường
                                    if (!context.mounted) return;
                                    final isConfirmed = await CheckoutConfirmationDialog.show(
                                      context: context,
                                      dealerName: dealerName,
                                      durationText: vm.liveDuration.value,
                                      photoCount: state.photos.length,
                                      surveyCompletedCount: completedSurveys,
                                      surveyTotalCount: surveyCount,
                                      isClosed: isClosed,
                                      distanceMeters: checkoutDistanceM,
                                      // Chỉ khi cổng ④ THẬT SỰ đã xét (có requirements, không còn thiếu) — không có req thì
                                      // cổng bị bỏ qua, ghi "Đạt" là nói sai.
                                      materialRow: _materialsForbidden ||
                                              _materialsUnknown ||
                                              _requiredMaterialCount == null ||
                                              req == null ||
                                              req.missingMaterials.isNotEmpty
                                          ? null
                                          : (
                                              label: strings.materialsCheckoutRowLabel,
                                              value: strings.materialsCheckoutRowValue(_requiredMaterialCount!),
                                            ),
                                    );

                                    if (!isConfirmed || !context.mounted) return;
                                    userConfirmedCheckout = true;
                                  }

                                  if (!userConfirmedCheckout || !context.mounted) return;

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

                                  if (!context.mounted) return;

                                  final (success, errorMsg) = await vm.checkout(
                                    lat: pos?.latitude,
                                    lng: pos?.longitude,
                                    accuracyM: pos?.accuracy,
                                    allowedRadiusMeters: allowedRadius,
                                    requireGeofence: mobileRules.visit.requireGeofence,
                                    forceCheckout: true,
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
                                    if (errorMsg.startsWith('VISIT_CANCELLED:') ||
                                        errorMsg.toLowerCase().contains('đã bị huỷ') ||
                                        errorMsg.toLowerCase().contains('đã huỷ') ||
                                        errorMsg.toLowerCase().contains('already cancelled')) {
                                      _showCancelledVisitRecoveryDialog(vm);
                                      return;
                                    }
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

  Widget _buildGeofenceAlertBanner(
    BuildContext context,
    CheckInState state,
    bool isDark,
  ) {
    final distM = state.currentDistanceToDealerM?.round() ?? 0;
    final radiusM = state.allowedGeofenceRadiusM?.round() ?? 100;
    final distText =
        distM < 1000 ? '${distM}m' : '${(distM / 1000).toStringAsFixed(1)}km';
    final radiusText = radiusM < 1000
        ? '${radiusM}m'
        : '${(radiusM / 1000).toStringAsFixed(1)}km';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cảnh báo: Bạn đang ở xa điểm bán ($distText)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Khoảng cách đã vượt bán kính cho phép ($radiusText). Vui lòng hoàn thành công việc và thực hiện Check-out để tránh bị ghi nhận sai vị trí.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF7F1D1D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

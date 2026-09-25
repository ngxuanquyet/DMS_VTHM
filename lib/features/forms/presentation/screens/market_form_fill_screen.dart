import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../data/models/market_form_submission_model.dart';
import '../../domain/entities/market_form_entity.dart';
import '../viewmodels/forms_view_model.dart';
import '../widgets/dynamic_renderer/market_form_renderer.dart';

import 'package:uuid/uuid.dart';
import '../../data/models/form_draft_model.dart';
import '../../data/services/form_draft_service.dart';

class MarketFormFillArgs {
  final MarketFormConfigEntity config;
  final String kind; // 'survey' | 'collect'
  final int? customerId;
  final int? visitId;
  final String? dealerName;
  final Map<String, dynamic>? initialAnswers;
  final String? draftId;
  final Map<String, dynamic>? customerContext;

  const MarketFormFillArgs({
    required this.config,
    required this.kind,
    this.customerId,
    this.visitId,
    this.dealerName,
    this.initialAnswers,
    this.draftId,
    this.customerContext,
  });

  /// Dựng ngữ cảnh @customer.* từ các thuộc tính điểm bán theo spec 25/09/2026 (§4)
  static Map<String, dynamic> buildCustomerContext({
    int? typeId,
    int? channelId,
    int? regionId,
    int? groupId,
  }) {
    return {
      '@customer': {
        'type_id': typeId,
        'channel_id': channelId,
        'region_id': regionId,
        'group_id': groupId,
      }
    };
  }
}

class MarketFormFillScreen extends ConsumerStatefulWidget {
  final MarketFormFillArgs args;

  const MarketFormFillScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<MarketFormFillScreen> createState() => _MarketFormFillScreenState();
}

enum _ExitDialogAction {
  stay,
  discard,
  saveDraft,
}

class _MarketFormFillScreenState extends ConsumerState<MarketFormFillScreen> {
  final GlobalKey<MarketFormRendererState> _rendererKey = GlobalKey();
  bool _isSubmitting = false;
  bool _isExiting = false;

  void _safePop([bool result = false]) {
    if (!mounted) return;
    setState(() => _isExiting = true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    } else {
      try {
        context.pop(result);
      } catch (_) {}
    }
  }

  bool _hasDraftableData([Map<String, dynamic>? answers]) {
    final ans = answers ?? _rendererKey.currentState?.currentAnswers ?? {};
    if (ans.isEmpty) return false;
    for (final val in ans.values) {
      if (val == null) continue;
      if (val is String && val.trim().isNotEmpty) return true;
      if (val is List && val.isNotEmpty) return true;
      if (val is Map && val.isNotEmpty) return true;
      if (val is num) return true;
      if (val is bool) return true;
    }
    return false;
  }

  Future<bool> _saveDraftInternal() async {
    final answers = _rendererKey.currentState?.currentAnswers ?? {};
    if (!_hasDraftableData(answers)) {
      return false;
    }

    final draftService = ref.read(formDraftServiceProvider);
    final draftId = widget.args.draftId ?? const Uuid().v4();
    final draft = FormDraft(
      id: draftId,
      configId: widget.args.config.configId,
      configName: widget.args.config.name,
      configCode: widget.args.config.code,
      kind: widget.args.kind,
      customerId: widget.args.customerId,
      visitId: widget.args.visitId,
      dealerName: widget.args.dealerName,
      answers: answers,
      updatedAt: DateTime.now(),
    );

    await draftService.saveDraft(draft);
    ref.invalidate(formDraftsListProvider);
    return true;
  }

  Future<void> _handleSaveDraft() async {
    final saved = await _saveDraftInternal();
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng điền ít nhất một trường thông tin để lưu nháp.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.bookmark_added_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Đã lưu bản nháp thành công!'),
            ],
          ),
          backgroundColor: Color(0xFF6366F1),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _safePop(false);
    }
  }

  Future<void> _handleExit() async {
    if (_isSubmitting || _isExiting) return;

    if (!_hasDraftableData()) {
      _safePop(false);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showDialog<_ExitDialogAction>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_outline_rounded,
                color: Color(0xFF6366F1),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lưu bản nháp?',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn đang điền biểu mẫu này. Bạn có muốn lưu bản nháp các thông tin đã nhập trước khi thoát không?',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actionsOverflowButtonSpacing: 8,
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitDialogAction.stay),
            child: Text(
              'Tiếp tục điền',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitDialogAction.discard),
            child: Text(
              'Không lưu',
              style: AppTypography.labelLarge(
                color: AppColors.error,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(_ExitDialogAction.saveDraft),
            icon: const Icon(Icons.bookmark_added_rounded, size: 16),
            label: const Text(
              'Lưu nháp',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == _ExitDialogAction.stay) {
      return;
    }

    if (action == _ExitDialogAction.discard) {
      _safePop(false);
      return;
    }

    if (action == _ExitDialogAction.saveDraft) {
      await _saveDraftInternal();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.bookmark_added_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã lưu bản nháp thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF6366F1),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _safePop(false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final answers = _rendererKey.currentState?.validateAndGetAnswers();
    if (answers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng kiểm tra và điền đầy đủ các thông tin bắt buộc.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Xác nhận nộp phiếu',
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn nộp biểu mẫu này không?\n\nLưu ý: Sau khi nộp thành công, thông tin sẽ được chốt và không thể chỉnh sửa.',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Kiểm tra lại',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nộp phiếu'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Lấy vị trí GPS hiện tại
      double? lat;
      double? lng;
      String? address;

      try {
        final position = await ref.read(locationServiceProvider).checkAndGetLocation(context);
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      // 2. Tạo submission DTO
      final submission = MarketFormSubmissionModel(
        configId: widget.args.config.configId,
        visitId: widget.args.kind == 'survey' ? widget.args.visitId : null,
        customerId: widget.args.customerId,
        answers: answers,
        submitLat: lat,
        submitLng: lng,
        submitAddress: address,
      );

      final isOnline = ref.read(connectivityProvider).isOnline;
      final submitUseCase = ref.read(submitMarketFormUseCaseProvider);

      final result = await submitUseCase(submission, isOffline: !isOnline);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Xóa bản nháp nếu có sau khi nộp thành công
        if (result.success) {
          if (widget.args.draftId != null) {
            await ref.read(formDraftServiceProvider).deleteDraft(widget.args.draftId!);
          }
          await ref.read(formDraftServiceProvider).deleteDraftByConfig(
                widget.args.config.configId,
                customerId: widget.args.customerId,
              );
          ref.invalidate(formDraftsListProvider);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor:
                  result.success ? const Color(0xFF10B981) : AppColors.error,
            ),
          );

          if (result.success) {
            _safePop(true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi nộp phiếu: ${e.toString().replaceAll('AppException: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final config = widget.args.config;

    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isExiting) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
        appBar: VthmTopAppBar(
          title: config.name,
          showBackButton: true,
          showAvatar: false,
          showLogo: false,
          onBackPressed: _handleExit,
          trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: isOnline ? const Color(0xFF10B981) : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? const Color(0xFF10B981) : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.stackMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerLowest
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (widget.args.kind == 'survey'
                                  ? AppColors.primary
                                  : AppColors.secondary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.args.kind == 'survey' ? 'Khảo sát điểm bán' : 'Thu thập thị trường',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.args.kind == 'survey'
                                ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                      if (config.isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bắt buộc trước khi Check-out',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.name,
                    style: AppTypography.titleLarge(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (widget.args.dealerName != null &&
                      widget.args.dealerName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.args.dealerName!,
                            style: AppTypography.bodyMedium(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Form Renderer
            MarketFormRenderer(
              key: _rendererKey,
              blocks: config.schema.blocks,
              initialAnswers: widget.args.initialAnswers ?? const {},
              customerContext: widget.args.customerContext ?? const {},
              defaultCustomerId: widget.args.customerId,
              defaultCustomerName: widget.args.dealerName,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Nút Lưu Nháp
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSaveDraft,
                  icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                  label: const Text(
                    'LƯU NHÁP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nút Nộp Biểu Mẫu
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: AppLoading(size: 24),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'NỘP BIỂU MẪU',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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
}

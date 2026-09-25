import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/custom_donut_chart.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/checkout_success_dialog.dart';
import '../../../forms/presentation/screens/market_form_fill_screen.dart';
import '../../../forms/presentation/widgets/market_form_card.dart';
import '../../../customer/domain/entities/customer_entity.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final TextEditingController _noteController = TextEditingController();
  final List<String> _photos = [];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
    return _noteController.text.trim().isNotEmpty || _photos.isNotEmpty;
  }

  Future<void> _handleExit() async {
    if (!_hasUnsavedData()) {
      // Chưa ghi gì -> Thoát ngay lập tức không hiện popup cảnh báo
      _safePop();
      return;
    }

    // Đang nhập / đã có dữ liệu -> Hiện dialog cảnh báo
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hủy check-in?',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có ghi chú/thông tin chưa lưu. Bạn có chắc chắn muốn thoát khỏi phiên check-in này không? Dữ liệu bạn vừa nhập sẽ bị mất.',
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
            child: const Text('Hủy check-in'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy phiên check-in điểm bán.'),
          backgroundColor: AppColors.error,
        ),
      );
      _safePop();
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

  void _openSurveyFormsSheet(BuildContext context, CheckInState state, CheckInViewModel vm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surveys = state.surveyForms;
    final customer = state.customer is CustomerEntity ? (state.customer as CustomerEntity) : null;
    final customerId = customer?.id ??
        (int.tryParse(state.checkinData?.dealer.id.replaceAll(RegExp(r'[^\d]'), '') ?? '') ?? 8338);
    final dealerName = customer?.name ?? state.checkinData?.dealer.name ?? 'Điểm bán';

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
                              customerContext: customerContext,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInViewModelProvider);
    final vm = ref.read(checkInViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surveyCount = state.surveyForms.length;
    final completedSurveys = state.submittedSurveyConfigIds.length;
    final surveyProgress = surveyCount > 0
        ? (completedSurveys / surveyCount).clamp(0.0, 1.0)
        : 0.0;
    final hasRequired = state.hasUnsubmittedRequiredSurveys;

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
      body: state.status == CheckInStatus.loading && state.checkinData == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : state.checkinData == null
              ? Center(child: Text(state.errorMessage ?? 'Không tải được dữ liệu điểm bán'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dealer Info Card (bỏ text VIP, khoảng cách thực tế)
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
                              Text(
                                state.checkinData!.dealer.name,
                                style: AppTypography.titleMedium(
                                  color: isDark
                                      ? AppColors.primaryFixedDim
                                      : AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${state.checkinData!.dealer.id}',
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

                      // Tasks Section
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
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            // Task 1: Forms
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.assignment_outlined,
                              iconColor: completedSurveys > 0 && completedSurveys >= surveyCount
                                  ? const Color(0xFF10B981)
                                  : (hasRequired ? AppColors.error : AppColors.primary),
                              title: 'Khảo sát điểm bán',
                              subtitle: surveyCount > 0
                                  ? (hasRequired
                                      ? 'Còn ${state.unsubmittedRequiredSurveys.length} biểu mẫu bắt buộc'
                                      : 'Đã hoàn thành $completedSurveys/$surveyCount')
                                  : 'Không có biểu mẫu khảo sát',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$completedSurveys/$surveyCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: hasRequired
                                          ? AppColors.error
                                          : (isDark
                                              ? AppColors.primaryFixedDim
                                              : AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CustomDonutProgress(
                                    progress: surveyProgress,
                                    size: 24,
                                    strokeWidth: 3.5,
                                    progressColor: completedSurveys > 0 &&
                                            completedSurveys >= surveyCount
                                        ? const Color(0xFF10B981)
                                        : (hasRequired
                                            ? AppColors.error
                                            : (isDark
                                                ? AppColors.primaryFixedDim
                                                : AppColors.primaryContainer)),
                                  ),
                                ],
                              ),
                              onTap: () => _openSurveyFormsSheet(context, state, vm),
                            ),
                            const SizedBox(height: 12),

                            // Task 2: Photos
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.photo_camera_outlined,
                              iconColor: _photos.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline),
                              title: 'Chụp ảnh điểm bán',
                              subtitleWidget: _photos.isNotEmpty
                                  ? Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_photos.length} ảnh đã chụp',
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
                                        Icon(
                                          Icons.error_outline,
                                          size: 14,
                                          color: AppColors.error,
                                        ),
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
                              trailing: Icon(
                                _photos.isNotEmpty
                                    ? Icons.check_rounded
                                    : Icons.chevron_right,
                                color: _photos.isNotEmpty
                                    ? const Color(0xFF10B981)
                                    : (isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.outline),
                              ),
                              onTap: () {
                                setState(() {
                                  _photos.add('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã chụp và đính kèm 1 ảnh điểm bán.')),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Task 3: Notes
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.edit_note_rounded,
                              iconColor: _noteController.text.trim().isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline),
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
                                    : (isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.outline),
                              ),
                              onTap: _openNoteDialog,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      // Cố định hàng HỦY CHECK-IN và CHECK-OUT ở cuối màn hình
      bottomNavigationBar: state.checkinData == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.marginMobile),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
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
                    // Hủy check-in Button
                    OutlinedButton.icon(
                      onPressed: _handleExit,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.surface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // CHECK-OUT Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.status == CheckInStatus.checkingOut
                            ? null
                            : () async {
                                // 1. Chặn Check-out nếu còn biểu mẫu bắt buộc chưa nộp (§1 & §2)
                                if (state.hasUnsubmittedRequiredSurveys) {
                                  final missingList = state.unsubmittedRequiredSurveys
                                      .map((f) => '• ${f.name}')
                                      .join('\n');
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: isDark
                                          ? AppColors.darkSurfaceContainer
                                          : AppColors.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Row(
                                        children: [
                                          const Icon(
                                            Icons.block_rounded,
                                            color: AppColors.error,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Chưa thể Check-out',
                                              style: AppTypography.titleLarge(
                                                color: isDark
                                                    ? AppColors.darkOnSurface
                                                    : AppColors.onSurface,
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
                                            'Bạn chưa hoàn thành các biểu mẫu khảo sát bắt buộc của điểm bán này:',
                                            style: AppTypography.bodyMedium(
                                              color: isDark
                                                  ? AppColors.darkOnSurfaceVariant
                                                  : AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              missingList,
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Theo quy định, bạn phải nộp toàn bộ biểu mẫu khảo sát bắt buộc trước khi check-out kết thúc phiên viếng thăm.',
                                            style: AppTypography.bodySmall(
                                              color: isDark
                                                  ? AppColors.darkOnSurfaceVariant
                                                  : AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            _openSurveyFormsSheet(context, state, vm);
                                          },
                                          child: const Text('LÀM KHẢO SÁT NGAY'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }

                                final position = await ref
                                    .read(locationServiceProvider)
                                    .checkAndGetLocation(context);
                                if (position == null) return;

                                final success = await vm.checkout();
                                if (success && context.mounted) {
                                  await CheckoutSuccessDialog.show(
                                    context,
                                    dealerName: state.checkinData?.dealer.name ??
                                        'Khách hàng',
                                  );
                                  if (context.mounted) {
                                    context.pop();
                                  }
                                }
                              },
                        icon: state.status == CheckInStatus.checkingOut
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: AppLoading(size: 28),
                              )
                            : const Icon(
                                Icons.logout_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'CHECK-OUT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                          shadowColor: const Color(0x1A000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
      color: isDark
          ? AppColors.darkSurfaceContainerLowest
          : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.outlineVariant,
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
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
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
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    if (subtitleWidget != null)
                      subtitleWidget
                    else if (subtitle != null)
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
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

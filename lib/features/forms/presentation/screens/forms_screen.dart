import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../data/services/form_draft_service.dart';
import '../states/forms_state.dart';
import '../viewmodels/forms_view_model.dart';
import '../widgets/forms_circular_menu.dart';
import '../widgets/market_form_card.dart';
import '../widgets/market_form_drafts_sheet.dart';
import 'market_form_fill_screen.dart';

class FormsScreen extends ConsumerStatefulWidget {
  const FormsScreen({super.key});

  @override
  ConsumerState<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends ConsumerState<FormsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    final isOnline = ref.read(connectivityProvider).isOnline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppLoading(size: 32),
            const SizedBox(width: 10),
            Text(isOnline
                ? 'Đang đồng bộ biểu mẫu từ máy chủ...'
                : 'Đang tải lại dữ liệu biểu mẫu ngoại tuyến...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await ref.read(formsViewModelProvider.notifier).loadForms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isOnline
                    ? 'Đồng bộ biểu mẫu thành công!'
                    : 'Đã làm mới dữ liệu biểu mẫu ngoại tuyến.'),
              ),
            ],
          ),
          backgroundColor:
              isOnline ? AppColors.primary : const Color(0xFFD97706),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleViewDrafts() {
    MarketFormDraftsSheet.show(context);
  }

  Future<void> _handleSendOfflineData() async {
    final isOnline = ref.read(connectivityProvider).isOnline;
    final db = ref.read(appDatabaseProvider);
    final pendingCount = await db.countPendingSync();

    if (pendingCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Tất cả dữ liệu đã được gửi lên máy chủ!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Hiện không có mạng. Có $pendingCount mục sẽ tự động gửi khi có kết nối.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const AppLoading(size: 32),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Đang gửi $pendingCount mục ngoại tuyến lên máy chủ...')),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await ref.read(syncServiceProvider).syncQueue();

    final remaining = await db.countPendingSync();
    if (mounted) {
      if (remaining == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã gửi toàn bộ dữ liệu ngoại tuyến thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(formsViewModelProvider.notifier).loadForms();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Đã gửi thành công. Còn $remaining mục đang xử lý.')),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(formsViewModelProvider);
    final vm = ref.read(formsViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingOfflineCount =
        ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final draftCount = ref.watch(formDraftsCountProvider).valueOrNull ?? 0;
    final offlineEntries =
        ref.watch(formSubmissionEntriesProvider).valueOrNull ?? [];
    final pendingFormCount = offlineEntries
        .where((e) =>
            e.state == 'pending' || e.state == 'sending' || e.state == 'dead')
        .length;
    final totalDraftCount = draftCount + pendingFormCount;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Top Header & Search Bar Section (cố định trên cùng, giống màn route)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.surfaceContainerLowest,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row with Form Count Badge (không có nút refresh)
                      Row(
                        children: [
                          Text(
                            'Biểu mẫu thị trường',
                            style: AppTypography.titleLarge(
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadius.roundedFull,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '${state.filteredMarketForms.length} biểu mẫu',
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.primaryFixedDim
                                    : AppColors.primary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Thu thập khảo sát & thông tin thị trường',
                        style: AppTypography.bodySmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Text Field (Fixed / Pinned)
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerLowest
                              : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkOutlineVariant
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => vm.setSearchQuery(val),
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm biểu mẫu theo tên hoặc mã...',
                            hintStyle: AppTypography.bodySmall(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.outline,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.outline,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      vm.setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content List (chiếm trọn không gian dọc còn lại qua Expanded)
                Expanded(
                  child: state.status == FormsStatus.loading &&
                          state.marketForms.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: AppLoading(size: 80),
                          ),
                        )
                      : state.filteredMarketForms.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 48.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.assignment_turned_in_outlined,
                                      size: 54,
                                      color: isDark
                                          ? AppColors.darkOutline
                                          : AppColors.outlineVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      state.marketForms.isEmpty
                                          ? (strings.isVietnamese
                                              ? 'Hiện chưa có biểu mẫu thị trường khả dụng'
                                              : 'No market forms available at this time')
                                          : (strings.isVietnamese
                                              ? 'Không tìm thấy biểu mẫu phù hợp'
                                              : 'No matching forms found'),
                                      style: AppTypography.bodyLarge(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => vm.loadForms(),
                              child: ListView.separated(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 160),
                                itemCount: state.filteredMarketForms.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item =
                                      state.filteredMarketForms[index];

                                  return MarketFormCard(
                                    config: item,
                                    showStatus: false,
                                    onTap: () async {
                                      await context.push<bool>(
                                        '/forms/fill',
                                        extra: MarketFormFillArgs(
                                          config: item,
                                          kind: 'collect',
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),

          // Menu button tròn (radial circular menu) overlay - nằm chuẩn đáy màn hình (bottom: 88, right: 16)
          Positioned.fill(
            child: FormsCircularMenu(
              onSync: _handleSync,
              onViewDrafts: _handleViewDrafts,
              onSendOfflineData: _handleSendOfflineData,
              pendingOfflineCount: pendingOfflineCount,
              draftCount: totalDraftCount,
              isSyncing: state.status == FormsStatus.loading,
            ),
          ),
        ],
      ),
    );
  }
}

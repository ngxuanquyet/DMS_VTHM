import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/home_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/form_summary_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/recent_activity_timeline.dart';
import '../widgets/route_progress_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeVM = ref.read(homeViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: homeState.status == HomeStatus.loading && homeState.dashboard == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : homeState.status == HomeStatus.error && homeState.dashboard == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(homeState.errorMessage ?? 'Đã xảy ra lỗi'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => homeVM.loadDashboard(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  onRefresh: () => homeVM.loadDashboard(isRefresh: true),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                      vertical: AppSpacing.stackMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        if (homeState.dashboard?.greeting != null)
                          GreetingHeader(greeting: homeState.dashboard!.greeting),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Quick Actions
                        const QuickActionsGrid(),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Bento Grid Metrics
                        if (homeState.dashboard?.attendance != null)
                          AttendanceSummaryCard(attendance: homeState.dashboard!.attendance),
                        const SizedBox(height: AppSpacing.stackMd),

                        if (homeState.dashboard?.routeSummary != null)
                          RouteProgressCard(route: homeState.dashboard!.routeSummary),
                        const SizedBox(height: AppSpacing.stackMd),

                        if (homeState.dashboard?.formSummary != null)
                          FormSummaryCard(formSummary: homeState.dashboard!.formSummary),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Recent Activity Timeline
                        if (homeState.dashboard?.recentActivities != null &&
                            homeState.dashboard!.recentActivities.isNotEmpty)
                          RecentActivityTimeline(
                            activities: homeState.dashboard!.recentActivities,
                          ),
                        const SizedBox(height: 80), // Padding for FAB & nav
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () {
          _showActionBottomSheet(context);
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showActionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.secondary),
                  title: const Text('Check-in tại điểm bán mới'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/check-in');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment, color: AppColors.primary),
                  title: const Text('Tạo biểu mẫu mới'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/forms');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

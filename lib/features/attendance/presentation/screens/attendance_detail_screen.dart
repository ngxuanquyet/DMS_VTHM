import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../domain/entities/attendance_entity.dart';
import '../states/attendance_state.dart';
import '../viewmodels/attendance_view_model.dart';
import '../widgets/attendance_geofence_card.dart';
import '../widgets/attendance_history_card.dart';
import '../widgets/attendance_out_of_range_dialog.dart';
import '../widgets/attendance_photo_capture_dialog.dart';
import '../widgets/gps_location_card.dart';
import '../widgets/monthly_stats_card.dart';

class AttendanceDetailScreen extends ConsumerStatefulWidget {
  const AttendanceDetailScreen({super.key});

  @override
  ConsumerState<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends ConsumerState<AttendanceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGpsAndConfig();
    });
  }

  Future<void> _initGpsAndConfig() async {
    final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context, showDialog: false);
    if (pos != null && mounted) {
      ref.read(attendanceViewModelProvider.notifier).updateUserLocation(pos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceViewModelProvider);
    final vm = ref.read(attendanceViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lắng nghe thông báo lỗi từ server (§0 & §6: hiện nguyên văn câu tiếng Việt của server)
    ref.listen<String?>(attendanceViewModelProvider.select((s) => s.errorMessage), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        AppErrorDialog.show(
          context,
          title: 'Thông báo chấm công',
          message: next,
          onRetry: () => vm.loadInitialData(),
        );
      }
    });

    // Lắng nghe thông báo thành công
    ref.listen<String?>(attendanceViewModelProvider.select((s) => s.successMessage), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    });

    // Tính toán ca làm việc hôm nay từ history (§3.4)
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayPunches = state.history.where((p) => p.punchAt.startsWith(todayStr)).toList();

    String firstCheckIn = '--:--';
    String lastCheckOut = '--:--';
    if (todayPunches.isNotEmpty) {
      todayPunches.sort((a, b) => a.punchAt.compareTo(b.punchAt));
      firstCheckIn = todayPunches.first.timeFormatted;
      if (todayPunches.length > 1) {
        lastCheckOut = todayPunches.last.timeFormatted;
      }
    }

    final isWorking = todayPunches.isNotEmpty;

    // Tính thống kê tháng từ history
    final currentMonthPrefix = '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final distinctWorkingDays = state.history
        .where((p) => p.dateFormatted.contains(currentMonthPrefix) || p.dateFormatted.contains('/${now.month}/'))
        .map((p) => p.dateFormatted)
        .toSet()
        .length;
    final lateDaysCount = state.history.where((p) => p.isTimeTampered).length;

    final stats = MonthlyAttendanceStatsEntity(
      monthLabel: 'Tháng ${now.month.toString().padLeft(2, '0')}/${now.year}',
      workingDays: distinctWorkingDays,
      lateDays: lateDaysCount,
    );

    final locationEntity = AttendanceLocationEntity(
      address: 'Vị trí hiện tại',
      gpsAccuracy: state.currentPosition != null
          ? 'Sai số: ${state.currentPosition!.accuracy.round()}m'
          : 'Độ chính xác cao',
      latitude: state.currentPosition?.latitude ?? 21.0285,
      longitude: state.currentPosition?.longitude ?? 105.8542,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: 'Chấm công bằng app',
        showBackButton: true,
      ),
      body: state.status == AttendanceStatus.loading && state.config == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context, showDialog: false);
                await vm.loadInitialData(lat: pos?.latitude, lng: pos?.longitude);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.stackLg,
                ),
                child: Column(
                  children: [
                    // =========================================================
                    // 1. HERO / DIGITAL CLOCK SECTION
                    // =========================================================
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isWorking
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceVariant,
                            borderRadius: AppRadius.roundedFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isWorking ? AppColors.primary : AppColors.outline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isWorking ? 'Đã có lượt chấm hôm nay' : 'Chưa chấm công hôm nay',
                                style: AppTypography.labelLarge(
                                  color: isWorking
                                      ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                      : AppColors.outline,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final liveTime = ref.watch(
                              attendanceViewModelProvider.select((s) => s.liveCurrentTime),
                            );
                            return Text(
                              liveTime,
                              style: AppTypography.displayLarge(
                                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatVietnameseDate(now),
                          style: AppTypography.bodyLarge(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackLg),

                    // =========================================================
                    // 2. GEOFENCE & WORKPLACE CONFIG CARD (§2)
                    // =========================================================
                    const AttendanceGeofenceCard(),
                    const SizedBox(height: AppSpacing.stackMd),

                    // =========================================================
                    // 3. GPS MAP & LOCATION CARD
                    // =========================================================
                    GpsLocationCard(location: locationEntity),
                    const SizedBox(height: AppSpacing.stackMd),

                    // =========================================================
                    // 4. MAIN PUNCH ACTION CARD (§3)
                    // =========================================================
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Giờ vào đầu tiên:',
                                style: AppTypography.bodyMedium(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                firstCheckIn,
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (todayPunches.length > 1) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Lượt chấm gần nhất:',
                                  style: AppTypography.bodyMedium(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  lastCheckOut,
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                strings.workingDurationFull,
                                style: AppTypography.bodyMedium(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  final durationStr = ref.watch(
                                    attendanceViewModelProvider.select(
                                      (s) => s.formattedWorkDuration,
                                    ),
                                  );
                                  return Text(
                                    durationStr,
                                    style: AppTypography.titleMedium(
                                      color: isDark
                                          ? AppColors.primaryFixedDim
                                          : AppColors.primary,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Nút bấm chấm công chính
                          _buildPunchButton(context, state, vm),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),

                    // =========================================================
                    // 5. THỐNG KÊ THÁNG
                    // =========================================================
                    MonthlyStatsCard(stats: stats),
                    const SizedBox(height: AppSpacing.stackMd),

                    // =========================================================
                    // 6. LỊCH SỬ CHẤM CÔNG CỦA MÌNH (§5)
                    // =========================================================
                    AttendanceHistoryCard(history: state.history),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPunchButton(
    BuildContext context,
    AttendanceState state,
    AttendanceViewModel vm,
  ) {
    final canPunch = state.canPunch;
    final hasLocations = state.hasLocations;
    final isBlockedByGeofence = state.isBlockedByGeofence;
    final isPunching = state.isPunching;

    // Nếu tài khoản không thể chấm (chưa có mã nhân viên)
    if (!canPunch) {
      return AppButton(
        text: 'Chưa có mã nhân viên',
        height: 52,
        icon: Icons.block_rounded,
        onPressed: null,
      );
    }

    // Nếu chưa khai địa điểm nào
    if (!hasLocations) {
      return AppButton(
        text: 'Chưa khai địa điểm',
        height: 52,
        icon: Icons.location_off_rounded,
        onPressed: null,
      );
    }

    return AppButton(
      text: isPunching ? 'Đang gửi lượt chấm...' : 'Chấm công bằng app',
      height: 52,
      isLoading: isPunching,
      icon: Icons.fingerprint_rounded,
      onPressed: isPunching
          ? null
          : () async {
              // 1. Lấy vị trí GPS hiện tại
              final position = await ref
                  .read(locationServiceProvider)
                  .checkAndGetLocation(context);
              if (position == null) return;

              // Cập nhật toạ độ vào state
              await vm.updateUserLocation(position);

              // 2. Nếu ngoài vùng và nhóm enforce_geofence: hiển thị cảnh báo
              if (isBlockedByGeofence) {
                final closest = state.closestLocation;
                if (context.mounted && closest != null) {
                  AttendanceOutOfRangeDialog.show(
                    context,
                    workplace: closest,
                    userPoint: GoongLatLng(position.latitude, position.longitude),
                    distanceMeters: (closest.distanceM ?? 9999).toDouble(),
                    maxAllowedMeters: closest.radiusM.toDouble(),
                  );
                }
                return;
              }

              // 3. Thực hiện chấm công (§3)
              final punchResult = await vm.punch(position: position);
              if (punchResult == null) return;

              // 4. Nếu chưa đủ ảnh (requirements.satisfied == false): mở màn chụp ảnh ngay (§4.1)
              if (context.mounted && !punchResult.requirements.satisfied) {
                AttendancePhotoCaptureDialog.show(
                  context,
                  punch: punchResult,
                );
              }
            },
    );
  }

  String _formatVietnameseDate(DateTime dt) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    final weekdayName = weekdays[dt.weekday - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$weekdayName, ngày $day/$month/$year';
  }
}

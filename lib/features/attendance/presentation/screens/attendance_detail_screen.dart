import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/services/anti_fraud_service.dart';
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
import '../widgets/attendance_shift_card.dart';
import '../widgets/gps_location_card.dart';


class AttendanceDetailScreen extends ConsumerStatefulWidget {
  const AttendanceDetailScreen({super.key});

  @override
  ConsumerState<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends ConsumerState<AttendanceDetailScreen> {
  /// Đang lấy vị trí cho lượt chấm — khoá nút (lấy GPS mới mất vài giây, bấm đúp là hai lượt).
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGpsAndConfig();
    });
  }

  Future<void> _initGpsAndConfig() async {
    final locationService = ref.read(locationServiceProvider);
    final pos = await locationService.checkAndGetLocation(context, showDialog: false);
    if (pos != null && mounted) {
      await ref.read(attendanceViewModelProvider.notifier).updateUserLocation(pos);
    }
    // `checkAndGetLocation` trả bản cache (có thể từ hàng giờ trước) ⇒ tự lấy thêm vị trí MỚI rồi cập nhật lại.
    // Chờ lần trên xong mới cập nhật: hai lượt tải cấu hình chạy chồng thì lượt về sau (có thể của vị trí cũ) thắng.
    final fresh = await locationService.getFreshPosition();
    if (fresh != null && mounted) {
      await ref.read(attendanceViewModelProvider.notifier).updateUserLocation(fresh);
    }
  }

  /// Vị trí cho lượt chấm: vị trí MỚI từ GPS; không được (chưa quyền / tắt GPS / quá giờ) mới qua đường có hộp thoại
  /// xin quyền (có thể trả bản cache).
  Future<Position?> _positionForPunch(BuildContext context) async {
    final locationService = ref.read(locationServiceProvider);
    return await locationService.getFreshPosition() ??
        (context.mounted ? await locationService.checkAndGetLocation(context) : null);
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

    // Tính toán ca làm việc hôm nay: ưu tiên config.today (§2 SPEC-2026-10-06), fallback sang history
    final today = state.config?.today;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayPunches = state.history.where((p) => p.punchAt.startsWith(todayStr)).toList();

    String firstCheckIn = today?.firstInTimeFormatted ?? '--:--';
    String lastCheckOut = today?.lastOutTimeFormatted ?? '--:--';
    if (firstCheckIn == '--:--' && todayPunches.isNotEmpty) {
      todayPunches.sort((a, b) => a.punchAt.compareTo(b.punchAt));
      firstCheckIn = todayPunches.first.timeFormatted;
      if (todayPunches.length > 1) {
        lastCheckOut = todayPunches.last.timeFormatted;
      }
    }

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
        title: 'Chấm công',
        showBackButton: true,
      ),
      body: state.status == AttendanceStatus.loading && state.config == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final locationService = ref.read(locationServiceProvider);
                final pos = await locationService.getFreshPosition() ??
                    (context.mounted ? await locationService.checkAndGetLocation(context, showDialog: false) : null);
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
                    // 1. GEOFENCE & WORKPLACE CONFIG CARD (§2)
                    // =========================================================
                    const AttendanceGeofenceCard(),
                    const SizedBox(height: AppSpacing.stackMd),

                    // =========================================================
                    // 2. SHIFT & SCHEDULE CARD (§8 SPEC-2026-10-17)
                    // =========================================================
                    const AttendanceShiftCard(),
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
                              _LiveWorkDuration(
                                style: AppTypography.titleMedium(
                                  color: isDark
                                      ? AppColors.primaryFixedDim
                                      : AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w600),
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
                    // 5. LỊCH SỬ CHẤM CÔNG CỦA MÌNH (§5)
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

    // Nhãn nút lấy từ today.next_action_label ("Vào" hoặc "Ra" §2 SPEC-2026-10-06)
    final punchActionLabel = state.config?.today?.nextActionLabel;
    final punchText = _locating
        ? 'Đang lấy vị trí...'
        : isPunching
            ? 'Đang gửi lượt chấm...'
            : (punchActionLabel != null ? 'Chấm $punchActionLabel' : 'Chấm công');
    final punchIcon = state.config?.today?.nextAction == 'out'
        ? Icons.logout_rounded
        : (state.config?.today?.nextAction == 'in' ? Icons.login_rounded : Icons.fingerprint_rounded);

    return AppButton(
      text: punchText,
      height: 52,
      isLoading: isPunching || _locating,
      icon: punchIcon,
      onPressed: isPunching || _locating
          ? null
          : () async {
              // 1. Lấy vị trí GPS hiện tại — vị trí MỚI, không dùng bản cache có thể đã cũ
              setState(() => _locating = true);
              final Position? position;
              try {
                position = await _positionForPunch(context);
              } finally {
                if (mounted) setState(() => _locating = false);
              }
              if (position == null) return;

              // Cập nhật toạ độ vào state (tính lại khoảng cách tới địa điểm chấm công theo vị trí mới)
              await vm.updateUserLocation(position);
              if (!mounted) return;
              // Đọc LẠI state sau khi cập nhật vị trí — `state`/`isBlockedByGeofence` ở trên là bản lúc dựng nút.
              final latest = ref.read(attendanceViewModelProvider);

              // 🔴 KIỂM TRA CHỐNG GIAN LẬN (MOCK LOCATION & CLOCK SKEW) TRƯỚC KHI CHẤM CÔNG
              if (context.mounted) {
                final fraudCheck = await ref.read(antiFraudServiceProvider).validateAction(
                  context,
                  position: position,
                  actionType: AntiFraudActionType.attendance,
                  actionTitle: 'Chấm công',
                );
                if (!fraudCheck.isAllowed) return;
              }

              // 2. Nếu ngoài vùng và nhóm enforce_geofence: hiển thị cảnh báo
              if (latest.isBlockedByGeofence) {
                final targetLocation = latest.activeLocation ?? latest.closestLocation;
                if (context.mounted && targetLocation != null) {
                  AttendanceOutOfRangeDialog.show(
                    context,
                    workplace: targetLocation,
                    userPoint: GoongLatLng(position.latitude, position.longitude),
                    distanceMeters: (targetLocation.distanceM ?? 9999).toDouble(),
                    maxAllowedMeters: (targetLocation.radiusM ?? 200).toDouble(),
                  );
                }
                return;
              }

              // 3. Nếu không yêu cầu ảnh (min_photos == 0): gửi trực tiếp
              final minPhotos = latest.config?.photo.minPhotos ?? 2;
              if (minPhotos == 0) {
                await vm.submitPunchWithPhotos(position: position);
                return;
              }

              // 4. Mở dialog chụp ảnh xác thực trước khi gửi lượt chấm công thật
              if (context.mounted) {
                AttendancePhotoCaptureDialog.show(
                  context,
                  position: position,
                );
              }
            },
    );
  }
}

/// Thời gian làm việc chạy từng giây — timer RIÊNG của dòng chữ này, chỉ dựng lại chính nó. Trước đây đồng hồ nằm trong
/// state chung (cập nhật mỗi giây) nên Home, thẻ chấm công và cả màn này dựng lại toàn bộ mỗi giây.
class _LiveWorkDuration extends ConsumerStatefulWidget {
  final TextStyle style;

  const _LiveWorkDuration({required this.style});

  @override
  ConsumerState<_LiveWorkDuration> createState() => _LiveWorkDurationState();
}

class _LiveWorkDurationState extends ConsumerState<_LiveWorkDuration> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(
      attendanceViewModelProvider.select((s) => (s.liveWorkDurationSeconds, s.workDurationAsOf)),
    );
    final text = AttendanceState.workDurationAt(base.$1, base.$2, DateTime.now());
    return Text(text, style: widget.style);
  }
}

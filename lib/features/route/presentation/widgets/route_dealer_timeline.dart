import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/incremental_list_view.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/presentation/widgets/customer_card.dart';
import '../../../customer/presentation/widgets/pending_sync_dismissible.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';
import 'active_visit_blocking_dialog.dart';
import 'checkin_distance_warning_dialog.dart';

class RouteDealerTimeline extends ConsumerWidget {
  final List<DealerEntity> dealers;

  /// Danh sách tự cuộn và dựng LƯỜI (chỉ thẻ đang trong khung nhìn) — tuyến có thể 1–2.000 điểm bán; bọc trong
  /// `SingleChildScrollView` + `shrinkWrap` thì dựng cả 2.000 thẻ mỗi lần GPS đổi/gõ tìm kiếm.
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  /// Đổi khi bộ lọc/từ khoá/kiểu sắp đổi ⇒ danh sách quay về những điểm đầu ([IncrementalListView]).
  final Object? resetKey;

  /// Điểm gốc tính khoảng cách — vị trí lấy MỘT lần khi mở màn (và khi người dùng bấm làm mới GPS / sắp theo khoảng
  /// cách), KHÔNG theo GPS liên tục: tuyến 1.000+ điểm mà mỗi lần vị trí đổi lại tính + dựng lại cả danh sách là giật.
  /// `null` (chưa có vị trí) ⇒ không hiện khoảng cách.
  final double? originLat;
  final double? originLng;

  const RouteDealerTimeline({
    super.key,
    required this.dealers,
    this.controller,
    this.padding,
    this.resetKey,
    this.originLat,
    this.originLng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultRadius = ref.watch(mobileRulesProvider).visit.defaultRadiusM;

    if (dealers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 48,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Không có điểm bán nào trên tuyến này',
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IncrementalListView(
      controller: controller,
      padding: padding,
      resetKey: resetKey,
      itemCount: dealers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dealer = dealers[index];
        final allowedRadius = dealer.geofenceRadiusM ??
            (dealer.customer is CustomerEntity
                ? (dealer.customer as CustomerEntity).geofenceRadiusM
                : null) ??
            defaultRadius;

        double? distance;
        if (originLat != null && originLng != null && dealer.lat != null && dealer.lng != null) {
          distance = Geolocator.distanceBetween(originLat!, originLng!, dealer.lat!, dealer.lng!);
        }

        final isPending = dealer.customer is CustomerEntity &&
            ((dealer.customer as CustomerEntity).syncStatus == 'pending' ||
             (dealer.customer as CustomerEntity).syncStatus == 'error');
        final clientUuid = (dealer.customer is CustomerEntity)
            ? (dealer.customer as CustomerEntity).clientUuid
            : null;
        final itemKey = clientUuid ?? 'dealer_${dealer.id}_$index';

        return PendingSyncDismissible(
          key: ValueKey('dismissible_$itemKey'),
          itemKey: itemKey,
          title: dealer.name,
          isPending: isPending,
          onConfirmDelete: () async {
            if (clientUuid != null) {
              return await ref.read(routeViewModelProvider.notifier).deletePendingCustomer(clientUuid);
            }
            return false;
          },
          child: CustomerCard.fromDealer(
            key: ValueKey(itemKey),
            dealer: dealer,
            distance: distance,
            showBorder: index != 0,
            onCheckIn: () => _handleCheckin(
              context,
              ref,
              dealer,
              allowedRadius: allowedRadius,
            ),
            onTap: dealer.customer is CustomerEntity
                ? () => context.push('/customers/detail', extra: dealer.customer)
                : null,
          ),
        );
      },
    );
  }

  Future<void> _handleCheckin(
    BuildContext context,
    WidgetRef ref,
    DealerEntity dealer, {
    int? allowedRadius,
  }) async {
    // 0.1. Kiểm tra phiên viếng thăm đang mở (§3 Luật 3)
    final checkInState = ref.read(checkInViewModelProvider);
    final routeState = ref.read(routeViewModelProvider);
    VisitEntity? activeVisit = checkInState.visitId != 0 && checkInState.visitEntity?.isOpen == true
        ? checkInState.visitEntity
        : (routeState.activeVisit?.isOpen == true ? routeState.activeVisit : null);

    if (activeVisit == null) {
      try {
        final saved = await ref.read(visitRepositoryProvider).getActiveVisit();
        if (saved != null && saved.isOpen) {
          activeVisit = saved;
        }
      } catch (_) {}
    }

    final targetCustomerId = dealer.customer is CustomerEntity
        ? (dealer.customer as CustomerEntity).id
        : int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), ''));

    // Nếu chính là điểm bán đang có phiên viếng thăm mở -> Vào tiếp tục ngay (§3 Luật 3)
    if (activeVisit != null && targetCustomerId != null && activeVisit.customerId == targetCustomerId) {
      final dealerWithVisit = dealer.visit != null
          ? dealer
          : dealer.copyWith(visit: activeVisit, status: DealerVisitStatus.inProgress);
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealerWithVisit);
      if (context.mounted) {
        await context.push('/check-in', extra: dealerWithVisit);
        if (context.mounted) {
          ref.read(routeViewModelProvider.notifier).loadRouteDetail();
        }
      }
      return;
    }

    // Nếu điểm bán đang có phiên viếng thăm mở (§3 Luật 3) -> Vào tiếp tục ngay
    if (dealer.status == DealerVisitStatus.inProgress) {
      final dealerWithVisit = dealer.visit != null
          ? dealer
          : (activeVisit != null ? dealer.copyWith(visit: activeVisit) : dealer);
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealerWithVisit);
      if (context.mounted) {
        await context.push('/check-in', extra: dealerWithVisit);
        if (context.mounted) {
          ref.read(routeViewModelProvider.notifier).loadRouteDetail();
        }
      }
      return;
    }

    // Chặn mở lượt mới nếu ĐANG CÓ một lượt viếng thăm tại điểm bán khác chưa đóng (§3 Luật 3)
    if (activeVisit != null && targetCustomerId != null && activeVisit.customerId != targetCustomerId) {
      final activeDealerName = activeVisit.customerName.isNotEmpty
          ? activeVisit.customerName
          : (checkInState.checkinData?.dealer.name ?? 'Điểm bán khác');
      if (context.mounted) {
        final chosenDealer = await showActiveVisitBlockingDialog(
          context: context,
          ref: ref,
          activeVisit: activeVisit,
          activeDealerName: activeDealerName,
          targetDealerName: dealer.name,
        );
        if (chosenDealer != null && context.mounted) {
          ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(chosenDealer);
          await context.push('/check-in', extra: chosenDealer);
          if (context.mounted) {
            ref.read(routeViewModelProvider.notifier).loadRouteDetail();
          }
        }
      }
      return;
    }

    // 1. Kiểm tra nhanh quyền vị trí & trạng thái GPS từ RAM (0ms)
    final locState = ref.read(locationProvider);
    if (!locState.isReady) {
      // Chưa cấp quyền hoặc chưa bật GPS -> Mở dialog yêu cầu cấp quyền
      if (!context.mounted) return;
      await ref.read(locationServiceProvider).checkAndGetLocation(context);
      return;
    }

    // 2. Cảnh báo sớm khi đang ở xa (nếu điểm bán có toạ độ GPS) — màn check-in và server vẫn tự kiểm bán kính bằng
    // vị trí lúc check-in, đây chỉ là báo trước. Dùng vị trí gần nhất mà app đã lấy được (`LocationService` chỉ đổi
    // khi có màn/dịch vụ lấy vị trí — cùng nguồn `currentPointProvider` trả về, như bản trước): đọc tức thì, không chờ
    // GPS (không treo nút, không làm mới provider ⇒ không dựng lại các danh sách đang nghe nó). Chưa có ⇒ bỏ qua báo trước.
    // Theo đặc tả §3: Điểm bán không có toạ độ trong hồ sơ -> Luật 4 luôn cho qua
    final cachedPos = LocationService.currentCachedPosition;
    if (dealer.lat != null && dealer.lng != null && cachedPos != null) {
      final actualDistance = Geolocator.distanceBetween(
        cachedPos.latitude,
        cachedPos.longitude,
        dealer.lat!,
        dealer.lng!,
      );

      final mobileRules = ref.read(mobileRulesProvider);
      final effectiveRadius = allowedRadius ??
          dealer.geofenceRadiusM ??
          (dealer.customer is CustomerEntity
              ? (dealer.customer as CustomerEntity).geofenceRadiusM
              : null) ??
          mobileRules.visit.defaultRadiusM;

      // Nếu yêu cầu geofence và khoảng cách > bán kính áp dụng -> Hiển thị popup cảnh báo
      if (mobileRules.visit.requireGeofence && actualDistance > effectiveRadius) {
        if (context.mounted) {
          showCheckinDistanceWarningDialog(
            context,
            dealerName: dealer.name,
            distanceMeters: actualDistance,
            allowedRadiusMeters: effectiveRadius,
            lat: dealer.lat,
            lng: dealer.lng,
            address: dealer.address,
          );
        }
        return;
      }
    }

    // 3. Khởi tạo sẵn dữ liệu điểm bán và vào màn check-in tức thì
    ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);
    if (context.mounted) {
      await context.push('/check-in', extra: dealer);
      if (context.mounted) {
        ref.read(routeViewModelProvider.notifier).loadRouteDetail();
      }
    }
  }
}


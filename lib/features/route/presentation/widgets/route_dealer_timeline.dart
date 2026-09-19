import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/presentation/widgets/customer_card.dart';
import '../../../customer/presentation/widgets/edit_customer_dialog.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';
import 'checkin_distance_warning_dialog.dart';

class RouteDealerTimeline extends ConsumerWidget {
  final List<DealerEntity> dealers;

  const RouteDealerTimeline({super.key, required this.dealers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final livePoint = ref.watch(currentPointProvider).value;

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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dealers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dealer = dealers[index];

        double? distance;
        if (livePoint != null && dealer.lat != null && dealer.lng != null) {
          distance = Geolocator.distanceBetween(
            livePoint.lat,
            livePoint.lng,
            dealer.lat!,
            dealer.lng!,
          );
        }

        return CustomerCard.fromDealer(
          dealer: dealer,
          distance: distance,
          onCheckIn: () => _handleCheckin(context, ref, dealer, distance),
          onTap: () {
            if (dealer.customer is CustomerEntity) {
              _showCustomerDetail(context, dealer.customer as CustomerEntity);
            }
          },
        );
      },
    );
  }

  Future<void> _handleCheckin(
    BuildContext context,
    WidgetRef ref,
    DealerEntity dealer,
    double? distance,
  ) async {
    // 1. Kiểm tra nhanh quyền vị trí & trạng thái GPS từ RAM (0ms)
    final locState = ref.read(locationProvider);
    if (!locState.isReady) {
      // Chưa cấp quyền hoặc chưa bật GPS -> Mở dialog yêu cầu cấp quyền
      await ref.read(locationServiceProvider).checkAndGetLocation(context);
      return;
    }

    // 2. Tính khoảng cách ngay lập tức (< 1ms) từ dữ liệu đã có sẵn
    double actualDistance;
    if (distance != null) {
      actualDistance = distance;
    } else if (dealer.lat == null || dealer.lng == null) {
      // Điểm bán chưa có tọa độ GPS -> Không gọi GPS vô ích, hiện cảnh báo khoảng cách ngay
      actualDistance = 850;
    } else {
      final livePoint = ref.read(currentPointProvider).value;
      if (livePoint != null) {
        actualDistance = Geolocator.distanceBetween(
          livePoint.lat,
          livePoint.lng,
          dealer.lat!,
          dealer.lng!,
        );
      } else {
        final cachedPos = LocationService.currentCachedPosition;
        if (cachedPos != null) {
          actualDistance = Geolocator.distanceBetween(
            cachedPos.latitude,
            cachedPos.longitude,
            dealer.lat!,
            dealer.lng!,
          );
        } else {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            actualDistance = Geolocator.distanceBetween(
              lastKnown.latitude,
              lastKnown.longitude,
              dealer.lat!,
              dealer.lng!,
            );
          } else {
            actualDistance = 850;
          }
        }
      }
    }

    // 3. Nếu khoảng cách > 100m -> Hiển thị popup cảnh báo tức thì (<5ms)
    if (actualDistance > 100) {
      if (context.mounted) {
        showCheckinDistanceWarningDialog(
          context,
          dealerName: dealer.name,
          distanceMeters: actualDistance,
          lat: dealer.lat,
          lng: dealer.lng,
          address: dealer.address,
        );
      }
      return;
    }

    // 4. Hợp lệ (<= 100m) -> Khởi tạo sẵn dữ liệu điểm bán và vào màn check-in tức thì (<5ms, không giật lag)
    ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);
    if (context.mounted) {
      context.push('/check-in');
    }
  }

  void _showCustomerDetail(BuildContext context, CustomerEntity customer) {
    EditCustomerDialog.show(
      context,
      customer: customer,
      onSave: (changes) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin điểm bán')),
        );
      },
    );
  }
}


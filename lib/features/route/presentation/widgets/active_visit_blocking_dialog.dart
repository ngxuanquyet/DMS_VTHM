import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';

/// Hộp thoại chặn check-in điểm bán mới khi đang có lượt viếng thăm chưa đóng (§3 Luật 3)
/// Áp dụng cho cả môi trường Online và Offline
Future<void> showActiveVisitBlockingDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VisitEntity activeVisit,
  required String activeDealerName,
  required String targetDealerName,
  VoidCallback? onClose,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ActiveVisitBlockingDialog(
      activeVisit: activeVisit,
      activeDealerName: activeDealerName,
      targetDealerName: targetDealerName,
      onClose: onClose,
    ),
  );
}

class ActiveVisitBlockingDialog extends ConsumerWidget {
  final VisitEntity activeVisit;
  final String activeDealerName;
  final String targetDealerName;
  final VoidCallback? onClose;

  const ActiveVisitBlockingDialog({
    super.key,
    required this.activeVisit,
    required this.activeDealerName,
    required this.targetDealerName,
    this.onClose,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lượt viếng thăm chưa đóng',
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
            'Bạn đang có một lượt viếng thăm chưa check-out tại điểm bán:',
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
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF0284C7),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeDealerName,
                        style: AppTypography.titleMedium(
                          color: const Color(0xFF0284C7),
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (activeVisit.checkinAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Đã check-in lúc ${_formatTime(activeVisit.checkinAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Theo quy định hệ thống (áp dụng cả Online và Offline), bạn không thể check-in điểm bán "$targetDealerName" khi đang có lượt viếng thăm khác chưa kết thúc.',
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vui lòng quay lại hoàn thành check-out hoặc hủy lượt đang mở trước khi mở lượt mới.',
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onClose?.call();
          },
          child: const Text('Đóng'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Vào lượt đang mở'),
          onPressed: () {
            Navigator.of(context).pop();

            // Tìm DealerEntity tương ứng hoặc tạo fallback
            final routeState = ref.read(routeViewModelProvider);
            DealerEntity? targetDealer;
            if (routeState.routeDetail?.dealers != null) {
              for (final d in routeState.routeDetail!.dealers) {
                final cId = d.customer is CustomerEntity
                    ? (d.customer as CustomerEntity).id
                    : int.tryParse(d.id.replaceAll(RegExp(r'[^\d]'), ''));
                if (cId == activeVisit.customerId) {
                  targetDealer = d;
                  break;
                }
              }
            }

            targetDealer ??= DealerEntity(
              id: activeVisit.customerId.toString(),
              order: '01',
              name: activeDealerName,
              address: '',
              status: DealerVisitStatus.inProgress,
              statusLabel: 'Đang ghé',
              isVip: false,
              visit: activeVisit,
            );

            ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(targetDealer);
            context.push('/check-in', extra: targetDealer);
          },
        ),
      ],
    );
  }
}

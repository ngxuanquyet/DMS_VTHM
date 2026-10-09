import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../data/models/market_form_submission_model.dart';
import '../viewmodels/forms_view_model.dart';

/// Màn xem lại chi tiết phiếu biểu mẫu đã nộp theo đặc tả §4.3 & §9:
/// GET /dms/form-submissions/{id}
/// Trả kèm answer_photos map { token -> url }
/// Token có trong answers mà vắng trong answer_photos => báo "ảnh không còn trên hệ thống"
class MarketFormSubmissionDetailScreen extends ConsumerStatefulWidget {
  final int submissionId;
  final MarketFormSubmissionDetailModel? initialDetail;

  const MarketFormSubmissionDetailScreen({
    super.key,
    required this.submissionId,
    this.initialDetail,
  });

  @override
  ConsumerState<MarketFormSubmissionDetailScreen> createState() =>
      _MarketFormSubmissionDetailScreenState();
}

class _MarketFormSubmissionDetailScreenState
    extends ConsumerState<MarketFormSubmissionDetailScreen> {
  late Future<MarketFormSubmissionDetailModel> _detailFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _detailFuture = Future.value(widget.initialDetail);
    } else {
      _detailFuture = ref
          .read(formsApiServiceProvider)
          .getSubmissionDetail(widget.submissionId);
    }
  }

  void _reload() {
    setState(() {
      _detailFuture = ref
          .read(formsApiServiceProvider)
          .getSubmissionDetail(widget.submissionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: 'Chi tiết phiếu #${widget.submissionId}',
        showBackButton: true,
        showAvatar: false,
        showLogo: false,
      ),
      body: FutureBuilder<MarketFormSubmissionDetailModel>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLoading(size: 40));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Lỗi tải thông tin phiếu: ${snapshot.error.toString().replaceAll("AppException: ", "")}',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Thử lại'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(detail, isDark),
                const SizedBox(height: AppSpacing.stackLg),
                Text(
                  'Câu trả lời đã ghi nhận',
                  style: AppTypography.titleMedium(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildAnswersList(detail, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
      MarketFormSubmissionDetailModel detail, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mã phiếu: #${detail.id}',
                style: AppTypography.titleMedium(
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Đã nộp thành công',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          if (detail.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Thời gian nộp: ${detail.createdAt}',
              style: AppTypography.bodySmall(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (detail.clientUuid != null) ...[
            const SizedBox(height: 4),
            Text(
              'Client UUID: ${detail.clientUuid}',
              style: AppTypography.bodySmall(
                color: isDark
                    ? AppColors.darkOutline
                    : AppColors.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswersList(
      MarketFormSubmissionDetailModel detail, bool isDark) {
    if (detail.answers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'Phiếu không có dữ liệu trả lời.',
          style: AppTypography.bodyMedium(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: detail.answers.entries.map((entry) {
        final fieldCode = entry.key;
        final value = entry.value;

        // Kiểm tra xem trường có phải là trường ảnh hay không
        // Ô ảnh trả lời dạng mảng token hex 32 ký tự (§3)
        final isPhotoField = value is List &&
            value.isNotEmpty &&
            value.any((v) =>
                v is String &&
                v.length == 32 &&
                !v.contains('/') &&
                !v.contains(r'\'));

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainer
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldCode,
                style: AppTypography.labelLarge(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (isPhotoField)
                _buildPhotoFieldAnswer(detail, value, isDark)
              else
                Text(
                  value?.toString() ?? '—',
                  style: AppTypography.bodyMedium(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Hiển thị danh sách ảnh của câu trả lời theo §4.3 & §9
  Widget _buildPhotoFieldAnswer(
      MarketFormSubmissionDetailModel detail, List tokens, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tokens.map((t) {
        final token = t.toString().trim();
        final isMissing = detail.isPhotoMissing(token);

        if (isMissing) {
          // §4.3 & §9: Token có trong answers mà vắng trong answer_photos
          // nghĩa là tệp đã mất — hiện "ảnh không còn trên hệ thống", đừng vẽ một khung ảnh vỡ.
          return Container(
            width: 130,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded,
                    color: AppColors.error, size: 28),
                SizedBox(height: 4),
                Text(
                  'Ảnh không còn trên hệ thống',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final relativeUrl = detail.getPhotoUrl(token)!;
        final fullUrl = relativeUrl.startsWith('http')
            ? relativeUrl
            : '${AppConstants.baseUrl}${relativeUrl.startsWith('/') ? '' : '/'}$relativeUrl';

        return GestureDetector(
          onTap: () => _showFullImageDialog(context, fullUrl),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                fullUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Lỗi tải ảnh',
                    style: TextStyle(fontSize: 10, color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded,
                  color: Colors.white, size: 30),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

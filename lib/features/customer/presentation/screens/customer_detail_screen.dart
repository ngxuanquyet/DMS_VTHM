import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/location_field_widget.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../core/map/goong_config.dart';
import '../../../../core/map/goong_map_view.dart';
import '../screens/add_customer_screen.dart';
import '../viewmodels/customer_view_model.dart';
import '../widgets/customer_card.dart';
import '../widgets/pending_sync_dismissible.dart';
import '../../../visit/presentation/widgets/customer_visit_history_widget.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final CustomerEntity customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late CustomerEntity _customer;
  late PageController _pageController;
  int _currentPhotoIndex = 0;
  bool _isLoading = false;
  GoongMapStyle _mapStyle = GoongMapStyle.standard;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _pageController = PageController();

    if (_customer.id > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDetailSilently();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetailSilently() async {
    try {
      final updated = await ref
          .read(customerRepositoryProvider)
          .getCustomerDetail(_customer.id);
      if (mounted) {
        setState(() {
          final effectiveRoute = (updated.route.trim().isNotEmpty && updated.route.trim() != 'Chưa phân tuyến')
              ? updated.route
              : _customer.route;
          final effectiveRoutes = updated.routes.isNotEmpty ? updated.routes : _customer.routes;
          final effectiveRouteIds = updated.routeIds.isNotEmpty ? updated.routeIds : _customer.routeIds;
          final effectiveCreatedBy = updated.createdByName?.trim().isNotEmpty == true
              ? updated.createdByName
              : _customer.createdByName;
          final effectiveUpdatedBy = updated.updatedByName?.trim().isNotEmpty == true
              ? updated.updatedByName
              : _customer.updatedByName;

          _customer = updated.copyWith(
            route: effectiveRoute,
            routes: effectiveRoutes,
            routeIds: effectiveRouteIds,
            createdByName: effectiveCreatedBy,
            updatedByName: effectiveUpdatedBy,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _handleRefresh() async {
    if (_customer.id <= 0) return;
    setState(() => _isLoading = true);
    try {
      final updated = await ref
          .read(customerRepositoryProvider)
          .getCustomerDetail(_customer.id);
      if (mounted) {
        setState(() {
          final effectiveRoute = (updated.route.trim().isNotEmpty && updated.route.trim() != 'Chưa phân tuyến')
              ? updated.route
              : _customer.route;
          final effectiveRoutes = updated.routes.isNotEmpty ? updated.routes : _customer.routes;
          final effectiveRouteIds = updated.routeIds.isNotEmpty ? updated.routeIds : _customer.routeIds;
          final effectiveCreatedBy = updated.createdByName?.trim().isNotEmpty == true
              ? updated.createdByName
              : _customer.createdByName;
          final effectiveUpdatedBy = updated.updatedByName?.trim().isNotEmpty == true
              ? updated.updatedByName
              : _customer.updatedByName;

          _customer = updated.copyWith(
            route: effectiveRoute,
            routes: effectiveRoutes,
            routeIds: effectiveRouteIds,
            createdByName: effectiveCreatedBy,
            updatedByName: effectiveUpdatedBy,
          );
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật dữ liệu mới nhất!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppErrorDialog.show(
          context,
          title: 'Lỗi làm mới chi tiết điểm bán',
          message: e.toString().replaceAll('AppException: ', ''),
          onRetry: _handleRefresh,
        );
      }
    }
  }

  Future<void> _handleDeletePendingCustomer() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await PendingSyncDismissible.showConfirmDialog(
      context,
      title: _customer.name,
      isDark: isDark,
    );
    if (confirmed && mounted && _customer.clientUuid != null) {
      final success = await ref
          .read(customerViewModelProvider.notifier)
          .deletePendingCustomer(_customer.clientUuid!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã xóa bản ghi "${_customer.name}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label vào bộ nhớ tạm'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFullScreenGallery(List<String> photoUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullScreenGalleryViewer(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
          title: _customer.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photos = _customer.fullPhotoUrls;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Can optionally pass _customer back
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
            onPressed: () => context.pop(_customer),
          ),
          title: Text(
            'Chi tiết điểm bán',
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Làm mới dữ liệu',
              icon: _isLoading
                  ? const AppLoading(size: 18)
                  : Icon(
                      Icons.refresh_rounded,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
              onPressed: _isLoading ? null : _handleRefresh,
            ),
            if (_customer.syncStatus == 'pending' || _customer.syncStatus == 'error')
              IconButton(
                tooltip: 'Xóa bản ghi',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                ),
                onPressed: _handleDeletePendingCustomer,
              ),
            const SizedBox(width: 4),
          ],
        ),
        bottomNavigationBar: _buildBottomActionBar(isDark),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 1. Photo Carousel / Header Banner
              _buildPhotoCarousel(photos, isDark),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4xx Error Banner if unrecoverable sync failure
                    if (_customer.syncStatus == 'error') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thông tin chưa hợp lệ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Thông tin điểm bán chưa đáp ứng quy định hệ thống. Vui lòng kiểm tra chỉnh sửa hoặc xóa điểm bán này.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB91C1C),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _handleDeletePendingCustomer,
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  label: const Text('Xóa điểm bán'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Approval Status Banner (§3 API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15)
                    if (_customer.isRejectedApproval) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33DC2626) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Điểm bán bị từ chối',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _customer.approvalNote != null && _customer.approvalNote!.trim().isNotEmpty
                                        ? 'Lý do: ${_customer.approvalNote}'
                                        : 'Điểm bán không được phê duyệt. Vui lòng kiểm tra lại.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFB91C1C),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Bạn vẫn có thể xem và viếng thăm bình thường (lưu vết nhưng chưa tính KPI).',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_customer.isPendingApproval) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33D97706) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Điểm bán đang chờ duyệt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Bạn vẫn viếng thăm bình thường; các lượt ở đây được tính vào báo cáo sau khi được duyệt.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFB45309),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. Identity & Summary Card
                    _buildIdentityCard(isDark),
                    const SizedBox(height: 16),

                    // Approval Status Banner (§3 API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15)
                    if (_customer.approvalStatus != 'approved') ...[
                      _buildApprovalStatusBanner(isDark),
                      const SizedBox(height: 16),
                    ],

                    // 3. Contact Info Card
                    _buildContactCard(isDark),
                    const SizedBox(height: 16),

                    // 4. Address & GPS Coordinates Card
                    _buildAddressAndGpsCard(isDark),
                    const SizedBox(height: 16),

                    // 5. Route & Management Card
                    _buildRouteAndManagementCard(isDark),
                    const SizedBox(height: 16),

                    // 6. Dynamic Fields Card (if available)
                    if (_hasDynamicFields()) ...[
                      _buildDynamicFieldsCard(isDark),
                      const SizedBox(height: 16),
                    ],

                    // 7. Sync & Meta Card
                    _buildSyncStatusCard(isDark),

                    // 8. Lịch sử viếng thăm của điểm bán (§2.4 SPEC 16/10/2026)
                    if (_customer.id > 0) ...[
                      const SizedBox(height: 16),
                      CustomerVisitHistoryWidget(
                        customerId: _customer.id,
                        customerName: _customer.name,
                        initiallyExpanded: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. PHOTO CAROUSEL / BANNER
  // ===========================================================================

  Widget _buildPhotoCarousel(List<String> photos, bool isDark) {
    if (photos.isEmpty) {
      return Container(
        width: double.infinity,
        height: 170,
        color: isDark
            ? AppColors.darkSurfaceContainer
            : const Color(0xFFF1F5F9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 56,
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.outlineVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Chưa có hình ảnh điểm bán',
              style: AppTypography.bodyMedium(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (idx) {
              setState(() => _currentPhotoIndex = idx);
            },
            itemBuilder: (context, index) {
              final url = photos[index];
              return GestureDetector(
                onTap: () => _openFullScreenGallery(photos, index),
                child: Hero(
                  tag: 'customer_photo_$index',
                  child: _buildNetworkOrFileImage(url),
                ),
              );
            },
          ),

          // Gradient overlay top & bottom for legibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // "Ảnh đại diện" badge on 1st photo
          if (_currentPhotoIndex == 0)
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Ảnh đại diện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Photo count pill (e.g. 1 / 3)
          Positioned(
            bottom: 12,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    '${_currentPhotoIndex + 1}/${photos.length} ảnh',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dots Indicator (if > 1 photo)
          if (photos.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (dotIdx) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: dotIdx == _currentPhotoIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotIdx == _currentPhotoIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNetworkOrFileImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: AppLoading(size: 32));
        },
      );
    }
    // Ưu tiên kiểm tra file cục bộ trước khi coi là đường dẫn tương đối server
    try {
      final cleanPath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        );
      }
    } catch (_) {}
    if (path.startsWith('/')) {
      return Image.network(
        '${AppConstants.baseUrl}$path',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: AppLoading(size: 32));
        },
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
    );
  }

  // ===========================================================================
  // 2. IDENTITY & SUMMARY CARD
  // ===========================================================================

  Widget _buildIdentityCard(bool isDark) {
    final isPending = _customer.syncStatus == 'pending';
    final isError = _customer.syncStatus == 'error';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Name
          Text(
            _customer.name,
            style: AppTypography.titleLarge(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          // Code Pill + Click to Copy
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutline : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _customer.code.isNotEmpty ? _customer.code : 'KH${_customer.id}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _copyToClipboard(
                        _customer.code.isNotEmpty ? _customer.code : 'KH${_customer.id}',
                        'Mã khách hàng',
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Chip
              if (isError)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'Cần sửa lại',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 13, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'Chờ đồng bộ',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Hoạt động',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Approval Status Chip (§3 API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15)
              if (_customer.approvalStatus != 'approved') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _customer.isRejectedApproval
                        ? (isDark ? const Color(0x33DC2626) : const Color(0xFFFEE2E2))
                        : (isDark ? const Color(0x33D97706) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _customer.isRejectedApproval
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _customer.isRejectedApproval
                            ? Icons.cancel_outlined
                            : Icons.hourglass_top_rounded,
                        size: 13,
                        color: _customer.isRejectedApproval
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _customer.displayApprovalLabel,
                        style: TextStyle(
                          color: _customer.isRejectedApproval
                              ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                              : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Badges row: Customer Type & Channel
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(
                icon: Icons.category_outlined,
                label: _customer.type,
                color: _customer.accentColor,
                isDark: isDark,
              ),
              if (_customer.channelName != null && _customer.channelName!.isNotEmpty)
                _buildBadge(
                  icon: Icons.store_mall_directory_outlined,
                  label: _customer.channelName!,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              _buildBadge(
                icon: Icons.alt_route_rounded,
                label: _resolveRouteName(),
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusBanner(bool isDark) {
    final isRejected = _customer.isRejectedApproval;
    final bg = isRejected
        ? (isDark ? const Color(0x33DC2626) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0x33D97706) : const Color(0xFFFFFBEB));
    final border = isRejected
        ? (isDark ? const Color(0x55DC2626) : const Color(0xFFFCA5A5))
        : (isDark ? const Color(0x55D97706) : const Color(0xFFFDE68A));
    final iconColor = isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final title = isRejected ? 'Điểm bán bị từ chối duyệt' : 'Điểm bán đang chờ duyệt';
    final note = _customer.approvalNote;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isRejected
                        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                        : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRejected
                      ? (note != null && note.isNotEmpty
                          ? 'Lý do từ chối: $note'
                          : 'Điểm bán chưa được phê duyệt. Vui lòng liên hệ quản lý hoặc cập nhật lại hồ sơ.')
                      : 'Hồ sơ mở mới đang được gửi lên cấp quản lý để phê duyệt. Bạn vẫn có thể thực hiện viếng thăm bình thường.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRejected
                        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C))
                        : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? color.withValues(alpha: 0.9) : color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CONTACT CARD
  // ===========================================================================

  Widget _buildContactCard(bool isDark) {
    final hasPhone = _customer.phone.isNotEmpty && _customer.phone != 'Chưa có SĐT';
    final hasEmail = _customer.email != null && _customer.email!.isNotEmpty;

    return _buildSectionCard(
      title: 'Thông tin người liên hệ',
      icon: Icons.person_outline_rounded,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Người liên hệ',
          value: _customer.contactPerson,
          subValue: _customer.contactTitle != null && _customer.contactTitle!.isNotEmpty
              ? 'Chức vụ: ${_customer.contactTitle}'
              : null,
          icon: Icons.badge_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          label: 'Số điện thoại',
          value: _customer.phone,
          icon: Icons.phone_outlined,
          isDark: isDark,
          trailing: hasPhone
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Sao chép SĐT',
                      onPressed: () => _copyToClipboard(_customer.phone, 'Số điện thoại'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_forwarded_rounded, size: 18, color: AppColors.primary),
                      tooltip: 'Gọi ngay',
                      onPressed: () => CustomerCard.defaultMakePhoneCall(context, _customer.phone),
                    ),
                  ],
                )
              : null,
        ),
        if (hasEmail) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            label: 'Email',
            value: _customer.email!,
            icon: Icons.email_outlined,
            isDark: isDark,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'Sao chép email',
              onPressed: () => _copyToClipboard(_customer.email!, 'Email'),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 4. ADDRESS & GPS CARD
  // ===========================================================================

  Widget _buildAddressAndGpsCard(bool isDark) {
    final coords = CustomerCard.extractCoordinates(
      lat: _customer.lat,
      lng: _customer.lng,
      dynamicFields: _customer.dynamicFields,
    );
    final hasGps = coords != null;

    return _buildSectionCard(
      title: 'Địa chỉ & Tọa độ GPS',
      icon: Icons.location_on_outlined,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Địa chỉ chi tiết',
          value: _customer.address,
          icon: Icons.home_outlined,
          isDark: isDark,
        ),
        if (_customer.wardName != null && _customer.wardName!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Phường / Xã',
            value: _customer.wardName!,
            icon: Icons.holiday_village_outlined,
            isDark: isDark,
          ),
        ],
        if (_customer.provinceName != null && _customer.provinceName!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Tỉnh / Thành phố',
            value: _customer.provinceName!,
            icon: Icons.location_city_outlined,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // Bản đồ Goong Map với đầy đủ tính năng: zoom (+/-), vuốt di chuyển, xem vệ tinh
        if (hasGps) ...[
          Container(
            height: 250,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2420) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. Bản đồ Goong Vector MapLibre
                GoongMapView(
                  key: ValueKey('customer_detail_map_${_customer.id}_${coords.$1}_${coords.$2}_${_mapStyle.styleName}'),
                  center: LatLng(
                    coords.$1,
                    coords.$2,
                  ),
                  zoom: 16.5,
                  mapStyle: _mapStyle,
                  markers: [
                    LatLng(coords.$1, coords.$2),
                  ],
                  showMyLocation: false,
                  showMyLocationButton: true,
                  showZoomControls: true,
                  interactive: true,
                ),

                // 2. Chế độ xem vệ tinh / đường phố / giao thông
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMapStyleChip(GoongMapStyle.standard, 'Đường phố', Icons.map_rounded),
                        const SizedBox(width: 2),
                        _buildMapStyleChip(GoongMapStyle.satellite, 'Vệ tinh', Icons.satellite_alt_rounded),
                        const SizedBox(width: 2),
                        _buildMapStyleChip(GoongMapStyle.navigation, 'Giao thông', Icons.traffic_rounded),
                      ],
                    ),
                  ),
                ),

                // 3. Tọa độ GPS hiển thị nhỏ gọn ở góc dưới
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pin_drop_rounded,
                          size: 13,
                          color: Color(0xFF4ADE80),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${coords.$1.toStringAsFixed(5)}, ${coords.$2.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2420) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 28,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa cập nhật tọa độ GPS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Điểm bán chưa được ghim vị trí để hiển thị bản đồ Goong',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => CustomerCard.defaultOpenDirections(
              context,
              lat: _customer.lat,
              lng: _customer.lng,
              address: _customer.address,
              dynamicFields: _customer.dynamicFields,
            ),
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('Mở Google Maps chỉ đường'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapStyleChip(GoongMapStyle style, String label, IconData icon) {
    final isSelected = _mapStyle == style;
    return InkWell(
      onTap: () {
        if (_mapStyle != style) {
          setState(() => _mapStyle = style);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF006E15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. ROUTE & MANAGEMENT CARD
  // ===========================================================================

  String _resolveRouteName() {
    // 1. Kiểm tra danh sách tuyến từ userAssignedRoutesProvider
    final userRoutes = ref.watch(userAssignedRoutesProvider).valueOrNull ?? [];
    final routeMap = <int, String>{};
    for (final ur in userRoutes) {
      if (ur.name.trim().isNotEmpty) {
        routeMap[ur.id] = ur.name.trim();
      }
    }

    // 2. Tra cứu từ routeIds nếu có
    if (_customer.routeIds.isNotEmpty && routeMap.isNotEmpty) {
      final names = _customer.routeIds
          .map((id) => routeMap[id])
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        return names.join(', ');
      }
    }

    // 3. Nếu route hiện tại có giá trị hợp lệ (khác 'Chưa phân tuyến' và không rỗng)
    if (_customer.route.trim().isNotEmpty &&
        _customer.route.trim() != 'Chưa phân tuyến' &&
        _customer.route.trim() != 'Tất cả tuyến') {
      final numMatch = RegExp(r'^Tuyến\s*#?(\d+)$', caseSensitive: false).firstMatch(_customer.route.trim());
      if (numMatch != null) {
        final id = int.tryParse(numMatch.group(1)!);
        if (id != null && routeMap.containsKey(id)) {
          return routeMap[id]!;
        }
      }
      return _customer.route.trim();
    }

    // 4. Tra cứu từ danh sách routes của customer
    for (final r in _customer.routes) {
      if (r.trim().isNotEmpty &&
          r.trim() != 'Chưa phân tuyến' &&
          r.trim() != 'Tất cả tuyến') {
        final numMatch = RegExp(r'^Tuyến\s*#?(\d+)$', caseSensitive: false).firstMatch(r.trim());
        if (numMatch != null) {
          final id = int.tryParse(numMatch.group(1)!);
          if (id != null && routeMap.containsKey(id)) {
            return routeMap[id]!;
          }
        }
        return r.trim();
      }
    }

    // 5. Tra cứu từ danh sách khách hàng đã load trong CustomerViewModel
    final allCustomers = ref.watch(customerViewModelProvider).allCustomers;
    final matchInList = allCustomers.where((c) => c.id == _customer.id).firstOrNull;
    if (matchInList != null &&
        matchInList.route.trim().isNotEmpty &&
        matchInList.route.trim() != 'Chưa phân tuyến' &&
        matchInList.route.trim() != 'Tất cả tuyến') {
      return matchInList.route.trim();
    }

    // 6. Tra cứu từ dynamicFields (route, route_name, tuyen, tuyen_ban_hang, mw_tuyen)
    final dynFields = _customer.dynamicFields;
    for (final key in ['route_name', 'route', 'tuyen', 'tuyen_ban_hang', 'mw_tuyen', 'routes', 'route_names']) {
      final val = dynFields[key];
      if (val is String && val.trim().isNotEmpty && val.trim() != 'Chưa phân tuyến') {
        return val.trim();
      } else if (val is List && val.isNotEmpty) {
        final first = val.first?.toString().trim();
        if (first != null && first.isNotEmpty && first != 'Chưa phân tuyến') {
          return first;
        }
      } else if (val is Map) {
        final name = (val['name'] ?? val['route_name'] ?? val['title'])?.toString().trim();
        if (name != null && name.isNotEmpty && name != 'Chưa phân tuyến') {
          return name;
        }
      }
    }

    // 7. Tra cứu từ routeIds dạng id nếu có (khi chưa map được tên từ server)
    if (_customer.routeIds.isNotEmpty) {
      return _customer.routeIds.map((id) => 'Tuyến #$id').join(', ');
    }

    return 'Chưa phân tuyến';
  }

  String? _resolveRegionName() {
    // 1. Tên khu vực có sẵn từ đối tượng khách hàng
    if (_customer.regionName != null && _customer.regionName!.trim().isNotEmpty) {
      return _customer.regionName!.trim();
    }

    // 2. Tra cứu từ dynamicFields
    final dynName = _customer.dynamicFields['region_name']?.toString() ??
        _customer.dynamicFields['region']?.toString();
    if (dynName != null && dynName.trim().isNotEmpty) {
      return dynName.trim();
    }

    // 3. Tra cứu theo regionId trong CustomerMetaData (Riverpod Provider)
    final rId = _customer.regionId;
    if (rId != null) {
      final meta = ref.watch(customerViewModelProvider).meta;
      final match = meta.regions.where((r) => r.id == rId).firstOrNull;
      if (match != null) {
        return match.name.isNotEmpty ? match.name : match.code;
      }

      // 4. Fallback tra cứu trong kDefaultCustomerMeta
      final defaultMatch = kDefaultCustomerMeta.regions.where((r) => r.id == rId).firstOrNull;
      if (defaultMatch != null) {
        return defaultMatch.name.isNotEmpty ? defaultMatch.name : defaultMatch.code;
      }

      return 'Khu vực #$rId';
    }

    return null;
  }

  Widget _buildRouteAndManagementCard(bool isDark) {
    final regionDisplayName = _resolveRegionName();

    return _buildSectionCard(
      title: 'Quản trị & Tuyến bán hàng',
      icon: Icons.hub_outlined,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Tuyến bán hàng',
          value: _resolveRouteName(),
          icon: Icons.alt_route_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          label: 'Kênh phân phối',
          value: _customer.channelName ?? 'Kênh truyền thống (GT)',
          icon: Icons.storefront_outlined,
          isDark: isDark,
        ),
        if (regionDisplayName != null && regionDisplayName.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Khu vực',
            value: regionDisplayName,
            icon: Icons.map_outlined,
            isDark: isDark,
          ),
        ],
        if (_customer.assignees.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Nhân viên phụ trách',
            value: _customer.assignees
                .map((a) => '${a.employeeCode}${a.isPrimary ? ' (Chính)' : ''}')
                .join(', '),
            icon: Icons.people_outline_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 6. DYNAMIC FIELDS CARD
  // ===========================================================================

  static const _detailIgnoredDynamicKeys = {
    'photo_url', 'photo_urls', 'photo_token', 'photo_tokens', 'data',
    'routes', 'route_ids', 'route', 'region', 'region_id', 'region_name',
    'id', 'code', 'name', 'address', 'phone', 'contact_name', 'contact_title',
    'email', 'lat', 'lng', 'geofence_radius_m', 'type',
    'created_by', 'created_by_name', 'created_by_code', 'creator_name', 'creator', 'user_create', 'user_create_name', 'created_user',
    'updated_by', 'updated_by_name', 'updated_by_code', 'updater_name', 'updater', 'user_update', 'user_update_name', 'updated_user', 'last_modified_by',
    'created_at', 'updated_at',
    'approval_status', 'approval_label', 'approval_color', 'approval_note', 'approval_at',
  };

  bool _hasDynamicFields() {
    return _customer.dynamicFields.keys.any((k) => !_detailIgnoredDynamicKeys.contains(k));
  }

  Widget _buildDynamicFieldsCard(bool isDark) {
    final columns = ref.watch(customerViewModelProvider).dynamicColumns;
    final entries = _customer.dynamicFields.entries
        .where((e) => !_detailIgnoredDynamicKeys.contains(e.key) && e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return _buildSectionCard(
      title: 'Thuộc tính mở rộng (Dynamic Fields)',
      icon: Icons.dynamic_feed_rounded,
      isDark: isDark,
      children: entries.map((e) {
        final col = columns
            .cast<CustomerDynamicColumn?>()
            .firstWhere((c) => c?.code == e.key, orElse: () => null);
        final label = col?.label.isNotEmpty == true ? col!.label : e.key;
        final isLocation = (col != null && col.isLocation) ||
            (e.value is Map && (e.value.containsKey('lat') || e.value.containsKey('lng') || e.value.containsKey('address')));

        if (isLocation) {
          final locMap = e.value is Map<String, dynamic>
              ? e.value as Map<String, dynamic>
              : (e.value is Map ? Map<String, dynamic>.from(e.value as Map) : null);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: LocationFieldWidget(
              label: label,
              isReadOnly: true,
              value: locMap,
              onChanged: (_) {},
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: _buildInfoRow(
            label: label,
            value: e.value.toString(),
            icon: Icons.fiber_manual_record_rounded,
            isDark: isDark,
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 7. SYNC STATUS & AUDIT CARD
  // ===========================================================================

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Chưa cập nhật';
    final trimmed = raw.trim();
    try {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        final local = parsed.toLocal();
        String pad2(int n) => n.toString().padLeft(2, '0');
        return '${pad2(local.hour)}:${pad2(local.minute)} - ${pad2(local.day)}/${pad2(local.month)}/${local.year}';
      }
    } catch (_) {}
    return trimmed;
  }

  String? _resolveCreatedByName() {
    String? name = _customer.createdByName?.trim();
    String? code;
    final dyn = _customer.dynamicFields;

    for (final k in ['created_by_code', 'creator_code', 'user_create_code']) {
      final v = dyn[k]?.toString().trim();
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }

    if (name == null || name.isEmpty) {
      for (final key in [
        'created_by_name',
        'created_by',
        'creator_name',
        'creator',
        'user_create',
        'user_create_name',
        'created_user',
      ]) {
        final val = dyn[key]?.toString().trim();
        if (val != null && val.isNotEmpty) {
          name = val;
          break;
        }
      }
    }

    if (name == null || name.isEmpty) {
      if (dyn['data'] is Map) {
        final sub = dyn['data'] as Map;
        for (final key in ['created_by_name', 'created_by', 'creator_name']) {
          final val = sub[key]?.toString().trim();
          if (val != null && val.isNotEmpty) {
            name = val;
            break;
          }
        }
        if (code == null) {
          final c = sub['created_by_code']?.toString().trim();
          if (c != null && c.isNotEmpty) code = c;
        }
      }
    }

    if (name == null || name.isEmpty) {
      name = code;
    } else if (code != null && code.isNotEmpty && !name.contains(code)) {
      name = '$name ($code)';
    }

    if ((name == null || name.isEmpty) && _customer.syncStatus == 'pending') {
      try {
        final authState = ref.read(authViewModelProvider);
        if (authState.user != null) {
          final user = authState.user!;
          if (user.displayName.isNotEmpty) {
            return user.employeeCode.isNotEmpty
                ? '${user.displayName} (${user.employeeCode})'
                : user.displayName;
          }
        }
      } catch (_) {}
    }

    return name;
  }

  String? _resolveUpdatedByName() {
    String? name = _customer.updatedByName?.trim();
    String? code;
    final dyn = _customer.dynamicFields;

    for (final k in ['updated_by_code', 'updater_code', 'user_update_code']) {
      final v = dyn[k]?.toString().trim();
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }

    if (name == null || name.isEmpty) {
      for (final key in [
        'updated_by_name',
        'updated_by',
        'updater_name',
        'updater',
        'user_update',
        'user_update_name',
        'updated_user',
        'last_modified_by',
      ]) {
        final val = dyn[key]?.toString().trim();
        if (val != null && val.isNotEmpty) {
          name = val;
          break;
        }
      }
    }

    if (name == null || name.isEmpty) {
      if (dyn['data'] is Map) {
        final sub = dyn['data'] as Map;
        for (final key in ['updated_by_name', 'updated_by', 'updater_name']) {
          final val = sub[key]?.toString().trim();
          if (val != null && val.isNotEmpty) {
            name = val;
            break;
          }
        }
        if (code == null) {
          final c = sub['updated_by_code']?.toString().trim();
          if (c != null && c.isNotEmpty) code = c;
        }
      }
    }

    if (name == null || name.isEmpty) {
      name = code;
    } else if (code != null && code.isNotEmpty && !name.contains(code)) {
      name = '$name ($code)';
    }

    return name;
  }

  Widget _buildSyncStatusCard(bool isDark) {
    final createdBy = _resolveCreatedByName();
    final updatedBy = _resolveUpdatedByName();
    final hasCreatedAt = _customer.createdAt != null && _customer.createdAt!.trim().isNotEmpty;
    final hasUpdatedAt = _customer.updatedAt != null && _customer.updatedAt!.trim().isNotEmpty;

    return _buildSectionCard(
      title: 'Trạng thái & Lịch sử chỉnh sửa',
      icon: Icons.history_rounded,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Trạng thái đồng bộ',
          value: _customer.syncStatus == 'synced'
              ? 'Đã gửi thành công'
              : (_customer.syncStatus == 'error'
                  ? 'Thông tin chưa hợp lệ - Cần chỉnh sửa'
                  : 'Lưu trên máy (Chờ gửi)'),
          icon: _customer.syncStatus == 'synced'
              ? Icons.cloud_done_rounded
              : (_customer.syncStatus == 'error'
                  ? Icons.error_outline_rounded
                  : Icons.cloud_queue_rounded),
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          label: 'Người tạo',
          value: (createdBy != null && createdBy.isNotEmpty) ? createdBy : 'Chưa cập nhật',
          icon: Icons.person_add_alt_1_outlined,
          isDark: isDark,
        ),
        if (hasCreatedAt) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Thời gian tạo',
            value: _formatDateTime(_customer.createdAt),
            icon: Icons.access_time_rounded,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 10),
        _buildInfoRow(
          label: 'Người cập nhật lần cuối',
          value: (updatedBy != null && updatedBy.isNotEmpty) ? updatedBy : 'Chưa cập nhật',
          icon: Icons.manage_accounts_outlined,
          isDark: isDark,
        ),
        if (hasUpdatedAt) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Thời gian cập nhật',
            value: _formatDateTime(_customer.updatedAt),
            icon: Icons.update_rounded,
            isDark: isDark,
          ),
        ],
        if (_customer.clientUuid != null && _customer.clientUuid!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Mã lưu trên máy',
            value: _customer.clientUuid!,
            icon: Icons.fingerprint_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // HELPER CARD & ROW BUILDERS
  // ===========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    required bool isDark,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR
  // ===========================================================================

  Widget _buildBottomActionBar(bool isDark) {
    final hasPhone = _customer.phone.isNotEmpty && _customer.phone != 'Chưa có SĐT';

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Call Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasPhone
                  ? () => CustomerCard.defaultMakePhoneCall(context, _customer.phone)
                  : null,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Gọi điện'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Directions Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => CustomerCard.defaultOpenDirections(
                context,
                lat: _customer.lat,
                lng: _customer.lng,
                address: _customer.address,
                dynamicFields: _customer.dynamicFields,
              ),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Chỉ đường'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FULL SCREEN GALLERY VIEWER
// =============================================================================

class _FullScreenGalleryViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final String title;

  const _FullScreenGalleryViewer({
    required this.photoUrls,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPhoto(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.white54),
        ),
      );
    }
    try {
      final cleanPath = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    } catch (_) {}
    if (path.startsWith('/')) {
      return Image.network(
        '${AppConstants.baseUrl}$path',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.white54),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_currentIndex + 1} / ${widget.photoUrls.length}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoUrls.length,
        onPageChanged: (idx) {
          setState(() => _currentIndex = idx);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'customer_photo_$index',
                child: _buildPhoto(widget.photoUrls[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

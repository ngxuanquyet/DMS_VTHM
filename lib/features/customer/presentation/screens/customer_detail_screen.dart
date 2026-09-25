import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../widgets/customer_card.dart';
import '../widgets/edit_customer_dialog.dart';

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
          _customer = updated;
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
          _customer = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật dữ liệu mới nhất từ máy chủ!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải lại chi tiết: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final state = ref.read(customerViewModelProvider);
    final vm = ref.read(customerViewModelProvider.notifier);

    await EditCustomerDialog.show(
      context,
      customer: _customer,
      meta: state.meta,
      dynamicColumns: state.dynamicColumns,
      onSave: (changes) async {
        await vm.updateCustomer(_customer.id, changes);
        if (_customer.id > 0) {
          await _loadDetailSilently();
        } else {
          // If offline pending customer, merge changes into _customer
          setState(() {
            _customer = _customer.copyWith(
              name: changes['name']?.toString() ?? _customer.name,
              code: changes['code']?.toString() ?? _customer.code,
              address: changes['address']?.toString() ?? _customer.address,
              phone: changes['phone']?.toString() ?? _customer.phone,
              contactPerson: changes['contact_name']?.toString() ?? _customer.contactPerson,
              contactTitle: changes['contact_title']?.toString() ?? _customer.contactTitle,
              email: changes['email']?.toString() ?? _customer.email,
              provinceName: changes['province_name']?.toString() ?? _customer.provinceName,
              wardName: changes['ward_name']?.toString() ?? _customer.wardName,
            );
          });
        }
      },
    );
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
            IconButton(
              tooltip: 'Chỉnh sửa điểm bán',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              onPressed: _handleEdit,
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
                    // 2. Identity & Summary Card
                    _buildIdentityCard(isDark),
                    const SizedBox(height: 16),

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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _handleEdit,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Thêm ảnh ngay'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
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
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        );
      }
    } catch (_) {}
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
              if (isPending)
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
                label: _customer.route,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ],
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
    final hasGps = _customer.lat != null && _customer.lng != null;

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
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // GPS Coordinates Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tọa độ GPS',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasGps
                        ? '${_customer.lat!.toStringAsFixed(5)}, ${_customer.lng!.toStringAsFixed(5)}'
                        : 'Chưa cập nhật GPS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: hasGps
                          ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            if (hasGps)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bán kính: ${_customer.geofenceRadiusM ?? 50}m',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => CustomerCard.defaultOpenDirections(
              context,
              lat: _customer.lat,
              lng: _customer.lng,
              address: _customer.address,
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

  // ===========================================================================
  // 5. ROUTE & MANAGEMENT CARD
  // ===========================================================================

  Widget _buildRouteAndManagementCard(bool isDark) {
    return _buildSectionCard(
      title: 'Quản trị & Tuyến bán hàng',
      icon: Icons.hub_outlined,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Tuyến bán hàng',
          value: _customer.route,
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
        if (_customer.regionId != null) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Khu vực (Region ID)',
            value: '#${_customer.regionId}',
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

  bool _hasDynamicFields() {
    const ignoredKeys = {
      'photo_url', 'photo_urls', 'photo_token', 'photo_tokens', 'data',
      'id', 'code', 'name', 'address', 'phone', 'contact_name', 'contact_title',
      'email', 'lat', 'lng', 'geofence_radius_m', 'type', 'route',
    };
    return _customer.dynamicFields.keys.any((k) => !ignoredKeys.contains(k));
  }

  Widget _buildDynamicFieldsCard(bool isDark) {
    const ignoredKeys = {
      'photo_url', 'photo_urls', 'photo_token', 'photo_tokens', 'data',
      'id', 'code', 'name', 'address', 'phone', 'contact_name', 'contact_title',
      'email', 'lat', 'lng', 'geofence_radius_m', 'type', 'route',
    };

    final columns = ref.watch(customerViewModelProvider).dynamicColumns;
    final entries = _customer.dynamicFields.entries
        .where((e) => !ignoredKeys.contains(e.key) && e.value != null && e.value.toString().isNotEmpty)
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

  Widget _buildSyncStatusCard(bool isDark) {
    return _buildSectionCard(
      title: 'Thông tin hệ thống & Đồng bộ',
      icon: Icons.cloud_done_outlined,
      isDark: isDark,
      children: [
        _buildInfoRow(
          label: 'Trạng thái đồng bộ',
          value: _customer.syncStatus == 'synced' ? 'Đã đồng bộ lên máy chủ' : 'Chờ gửi lên máy chủ (Offline)',
          icon: _customer.syncStatus == 'synced' ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
          isDark: isDark,
        ),
        if (_customer.createdAt != null) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Thời gian tạo',
            value: _customer.createdAt!,
            icon: Icons.access_time_rounded,
            isDark: isDark,
          ),
        ],
        if (_customer.updatedAt != null) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Thời gian cập nhật',
            value: _customer.updatedAt!,
            icon: Icons.update_rounded,
            isDark: isDark,
          ),
        ],
        if (_customer.clientUuid != null) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'Client UUID',
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
          const SizedBox(width: 10),

          // Edit Button
          IconButton.filled(
            tooltip: 'Sửa thông tin',
            onPressed: _handleEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.roundedMd,
                side: BorderSide(
                  color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                ),
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
    if (path.startsWith('/')) {
      return Image.network(
        '${AppConstants.baseUrl}$path',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.white54),
        ),
      );
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    } catch (_) {}
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

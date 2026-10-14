import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/map/app_map_location_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/camera_permission_dialog.dart';
import '../../../../core/widgets/location_field_widget.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../screens/add_customer_screen.dart';
import '../viewmodels/customer_view_model.dart';

/// Màn hình riêng biệt: Chỉnh sửa thông tin khách hàng / Điểm bán
class EditCustomerScreen extends ConsumerStatefulWidget {
  final CustomerEntity customer;
  final CustomerMetaData meta;
  final List<CustomerDynamicColumn> dynamicColumns;
  final Future<void> Function(Map<String, dynamic> changes)? onSave;

  const EditCustomerScreen({
    super.key,
    required this.customer,
    this.meta = const CustomerMetaData(),
    this.dynamicColumns = const [],
    this.onSave,
  });

  /// Phương thức điều hướng mở màn hình EditCustomerScreen (Ẩn bottom bar nav bằng rootNavigator: true)
  static Future<bool?> open(
    BuildContext context, {
    required CustomerEntity customer,
    CustomerMetaData meta = const CustomerMetaData(),
    List<CustomerDynamicColumn> dynamicColumns = const [],
    Future<void> Function(Map<String, dynamic> changes)? onSave,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditCustomerScreen(
          customer: customer,
          meta: meta,
          dynamicColumns: dynamicColumns,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _RouteOption {
  final int id;
  final String name;
  const _RouteOption(this.id, this.name);
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  // 1. Identification & Classification controllers / state
  late final TextEditingController _nameController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _wardNameController;
  int? _selectedCustomerTypeId;
  int? _selectedChannelId;
  int? _selectedRegionId;
  int? _selectedRouteId;
  String? _selectedRouteName;

  // 2. Contact & Address controllers
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactTitleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  // 3. GPS Location State (Được quản lý qua bản đồ tương tác AppMapLocationCard)
  double? _currentLat;
  double? _currentLng;

  // 4. Dynamic fields controllers
  final Map<String, TextEditingController> _dynamicControllers = {};
  // 4b. Dynamic location values (Spec 13/10/2026: input_type = "location")
  final Map<String, Map<String, dynamic>?> _dynamicLocationValues = {};
  final Map<String, bool> _dynamicLocationTouched = {};

  // 5. Photos state (Spec 23/09/2026: photo_tokens array, max 10 photos)
  late List<String> _photos;
  bool _photosChanged = false;

  bool _isSaving = false;

  static const _ignoredDynamicKeys = {
    // Photos
    'photo_url', 'photo_urls', 'photo_token', 'photo_tokens', 'photo_file_id', 'photo', 'photos',
    'photo_path', 'photo_paths', 'image', 'images', 'image_url', 'image_urls', 'avatar',
    // Routes
    'routes', 'route_ids', 'route', 'route_id', 'route_name', 'routename', 'route_code', 'routecode',
    'sales_route', 'sales_routes',
    // Core fields
    'id', 'code', 'customer_code', 'name', 'customer_name', 'address', 'phone', 'contact_name', 'contact_title', 'contact_person',
    'email', 'lat', 'lng', 'latitude', 'longitude', 'geofence_radius_m', 'geofence',
    'birthday', 'tax_code', 'delivery_address', 'description', 'notes',
    // Classifications & Administrative divisions (handled in Section 1)
    'type', 'customer_type', 'customer_type_id', 'customer_type_name',
    'channel', 'channel_id', 'channel_name',
    'region', 'region_id', 'region_name', 'area_id', 'area_name', 'customer_group_id', 'customer_group_name',
    'province', 'province_id', 'province_name', 'province_code',
    'ward', 'ward_id', 'ward_name', 'ward_code',
    'district', 'district_id', 'district_name', 'district_code',
    // System metadata
    'status', 'is_active', 'is_draft', 'approval_status', 'client_uuid',
    'created_at', 'updated_at', 'deleted_at', 'created_by_name', 'updated_by_name',
    'creator_id', 'user_id', 'assigned_to', 'assignees',
    'sync_status', 'sync_action', 'sync_retry_count', 'sync_error',
    'data', 'dynamic_fields', 'dynamicFieldsJson',
  };

  @override
  void initState() {
    super.initState();
    final c = widget.customer;

    _nameController = TextEditingController(text: c.name);
    _provinceNameController = TextEditingController(text: c.provinceName ?? '');
    _wardNameController = TextEditingController(text: c.wardName ?? '');
    _selectedCustomerTypeId = c.customerTypeId;
    _selectedChannelId = c.channelId;
    _selectedRegionId = c.regionId;

    // Khởi tạo tuyến bán hàng
    _selectedRouteId = c.routeIds.isNotEmpty ? c.routeIds.first : null;
    _selectedRouteName = c.route.isNotEmpty && c.route != 'Tất cả tuyến' ? c.route : null;
    if (_selectedRouteName == null && c.routes.isNotEmpty) {
      _selectedRouteName = c.routes.first;
    }
    if (_selectedRouteId == null && c.dynamicFields['route_ids'] is List) {
      final list = c.dynamicFields['route_ids'] as List;
      if (list.isNotEmpty) {
        _selectedRouteId = int.tryParse(list.first.toString());
      }
    }
    if (_selectedRouteName == null && c.dynamicFields['routes'] is List) {
      final list = c.dynamicFields['routes'] as List;
      if (list.isNotEmpty) {
        _selectedRouteName = list.first.toString();
      }
    }

    _contactNameController = TextEditingController(
      text: c.contactPerson == 'Chưa cập nhật' ? '' : c.contactPerson,
    );
    _contactTitleController = TextEditingController(text: c.contactTitle ?? '');
    _phoneController = TextEditingController(
      text: c.phone == 'Chưa có SĐT' ? '' : c.phone,
    );
    _emailController = TextEditingController(text: c.email ?? '');
    _addressController = TextEditingController(text: c.address);

    _currentLat = c.lat;
    _currentLng = c.lng;

    // Initialize photo list from existing customer entity
    _photos = List<String>.from(c.photoUrls);
    if (_photos.isEmpty && c.photoUrl != null && c.photoUrl!.isNotEmpty) {
      _photos.add(c.photoUrl!);
    }
    if (_photos.isEmpty && c.dynamicFields['photo_urls'] is List) {
      _photos = (c.dynamicFields['photo_urls'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (_photos.isEmpty && c.dynamicFields['photo_url'] != null) {
      final p = c.dynamicFields['photo_url'].toString().trim();
      if (p.isNotEmpty) _photos.add(p);
    }

    // Initialize dynamic controllers from active schema and customer data, strictly filtering out internal/system keys
    final effectiveColumns = widget.dynamicColumns.isNotEmpty
        ? widget.dynamicColumns
        : (widget.meta.dynamicColumns.isNotEmpty
            ? widget.meta.dynamicColumns
            : ref.read(customerViewModelProvider).dynamicColumns);

    final rawDynamicKeys = <String>{
      ...effectiveColumns.map((col) => col.code),
      ...widget.customer.dynamicFields.keys,
    }..removeWhere((k) => _ignoredDynamicKeys.contains(k.toLowerCase().trim()));

    // Deduplicate mw_ prefix keys if both key and mw_key exist
    final allDynamicKeys = <String>{};
    for (final k in rawDynamicKeys) {
      if (k.startsWith('mw_')) {
        final rawKey = k.substring(3);
        if (rawDynamicKeys.contains(rawKey)) {
          final hasRawVal = widget.customer.dynamicFields[rawKey]?.toString().trim().isNotEmpty == true;
          final hasKVal = widget.customer.dynamicFields[k]?.toString().trim().isNotEmpty == true;
          if (hasRawVal && !hasKVal) {
            allDynamicKeys.add(rawKey);
          } else {
            allDynamicKeys.add(k);
          }
          continue;
        }
      } else {
        final mwKey = 'mw_$k';
        if (rawDynamicKeys.contains(mwKey)) {
          continue;
        }
      }
      allDynamicKeys.add(k);
    }

    for (final key in allDynamicKeys) {
      var val = widget.customer.dynamicFields[key];
      if (val == null && key.startsWith('mw_')) {
        val = widget.customer.dynamicFields[key.substring(3)];
      } else if (val == null && !key.startsWith('mw_')) {
        val = widget.customer.dynamicFields['mw_$key'];
      }

      // Kiểm tra nếu là ô vị trí (§1, §2)
      final isLocationKey = val is Map ||
          widget.dynamicColumns.any((col) => (col.code == key || col.legacyKey == key) && col.isLocation);
      if (isLocationKey || val is Map) {
        if (val is Map) {
          _dynamicLocationValues[key] = Map<String, dynamic>.from(val);
        } else {
          _dynamicLocationValues[key] = null;
        }
        continue;
      }

      // Bỏ qua giá trị mảng hoặc object thô như [TEST-QUYETNX]
      if (val is List) continue;
      final valStr = val != null ? val.toString().trim() : '';
      if (valStr.startsWith('[') && valStr.endsWith(']')) continue;
      if (valStr.startsWith('{') && valStr.endsWith('}')) continue;

      _dynamicControllers[key] =
          TextEditingController(text: valStr);
    }

    // Đảm bảo các cột location trong dynamicColumns không bị sót
    for (final col in widget.dynamicColumns) {
      if (col.isLocation && !_ignoredDynamicKeys.contains(col.code)) {
        if (!_dynamicLocationValues.containsKey(col.code)) {
          final rawVal = widget.customer.dynamicFields[col.code];
          _dynamicLocationValues[col.code] = rawVal is Map ? Map<String, dynamic>.from(rawVal) : null;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _provinceNameController.dispose();
    _wardNameController.dispose();

    _contactNameController.dispose();
    _contactTitleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();

    for (final c in _dynamicControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final changes = <String, dynamic>{};
    final c = widget.customer;

    // 1. Tên điểm bán (Mã code do hệ thống tự sinh, không thể sửa)
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != c.name) {
      changes['name'] = newName;
    }

    // 2. Phân loại (Loại khách hàng, Kênh, Khu vực, Tỉnh, Phường)
    if (_selectedCustomerTypeId != c.customerTypeId) {
      changes['customer_type_id'] = _selectedCustomerTypeId;
    }

    if (_selectedChannelId != c.channelId) {
      changes['channel_id'] = _selectedChannelId;
    }

    if (_selectedRegionId != c.regionId) {
      changes['region_id'] = _selectedRegionId;
    }

    final oldRouteId = c.routeIds.isNotEmpty ? c.routeIds.first : null;
    final oldRouteName = c.route;
    if (_selectedRouteId != oldRouteId || (_selectedRouteName != null && _selectedRouteName != oldRouteName)) {
      if (_selectedRouteId != null) {
        changes['route_ids'] = [_selectedRouteId];
      }
      if (_selectedRouteName != null && _selectedRouteName!.isNotEmpty) {
        changes['route'] = _selectedRouteName;
        changes['routes'] = [_selectedRouteName];
      }
    }

    final newProvince = _provinceNameController.text.trim();
    if (newProvince != (c.provinceName ?? '')) {
      changes['province_name'] = newProvince.isNotEmpty ? newProvince : null;
    }

    final newWard = _wardNameController.text.trim();
    if (newWard != (c.wardName ?? '')) {
      changes['ward_name'] = newWard.isNotEmpty ? newWard : null;
    }

    // 3. Thông tin liên hệ & Địa chỉ
    final newContactName = _contactNameController.text.trim();
    final oldContact =
        c.contactPerson == 'Chưa cập nhật' ? '' : c.contactPerson;
    if (newContactName != oldContact) {
      changes['contact_name'] =
          newContactName.isNotEmpty ? newContactName : null;
    }

    final newContactTitle = _contactTitleController.text.trim();
    if (newContactTitle != (c.contactTitle ?? '')) {
      changes['contact_title'] =
          newContactTitle.isNotEmpty ? newContactTitle : null;
    }

    final newPhone = _phoneController.text.trim();
    final oldPhone = c.phone == 'Chưa có SĐT' ? '' : c.phone;
    if (newPhone != oldPhone) {
      changes['phone'] = newPhone.isNotEmpty ? newPhone : null;
    }

    final newEmail = _emailController.text.trim();
    if (newEmail != (c.email ?? '')) {
      changes['email'] = newEmail.isNotEmpty ? newEmail : null;
    }

    final newAddress = _addressController.text.trim();
    if (newAddress.isNotEmpty && newAddress != c.address) {
      changes['address'] = newAddress;
    }

    // 4. GPS Coordinates: Gửi theo cặp lat/lng khi có thay đổi (Vẫn cho sửa lat và lng)
    if (_currentLat != c.lat || _currentLng != c.lng) {
      changes['lat'] = _currentLat;
      changes['lng'] = _currentLng;
    }

    // 5. Dynamic Editable Fields (Cho phép sửa được mọi trường, không quan tâm hệ cũ)
    final dynamicChanges = <String, dynamic>{};
    for (final entry in _dynamicControllers.entries) {
      final key = entry.key;
      final newVal = entry.value.text.trim();
      final oldVal = c.dynamicFields[key]?.toString() ?? '';

      if (newVal != oldVal) {
        dynamicChanges[key] = newVal.isNotEmpty ? newVal : null;
      }
    }

    // 5b. Dynamic Location Fields (§3: gửi null để xoá giá trị; không gửi khoá là giữ nguyên)
    for (final entry in _dynamicLocationValues.entries) {
      final key = entry.key;
      if (_dynamicLocationTouched[key] == true) {
        final newVal = entry.value;
        if (newVal == null) {
          dynamicChanges[key] = null; // Gửi null để xoá giá trị (§3)
        } else {
          dynamicChanges[key] = newVal;
        }
      }
    }

    if (dynamicChanges.isNotEmpty) {
      changes['data'] = dynamicChanges;
    }

    // 6. Xử lý ảnh điểm bán (photo_tokens) theo spec 23/09/2026:
    // TUYỆT ĐỐI không gửi photo_tokens nếu người dùng không chạm vào ảnh
    if (_photosChanged) {
      final repo = ref.read(customerRepositoryProvider);
      final tokens = <String>[];
      for (final p in _photos) {
        final pTrim = p.trim();
        if (pTrim.isEmpty) continue;
        if (pTrim.length == 32 && !pTrim.contains('/') && !pTrim.contains(r'\')) {
          tokens.add(pTrim);
        } else if (pTrim.startsWith('/crm/customer-photos/public/')) {
          final extracted = pTrim.replaceFirst('/crm/customer-photos/public/', '');
          tokens.add(extracted);
        } else if (pTrim.contains('/crm/customer-photos/public/')) {
          final idx = pTrim.indexOf('/crm/customer-photos/public/');
          final extracted = pTrim.substring(idx + '/crm/customer-photos/public/'.length);
          tokens.add(extracted);
        } else {
          // Local file path -> upload lên server để lấy token
          try {
            final uploadRes = await repo.uploadCustomerPhoto(pTrim);
            if (uploadRes['token'] != null) {
              tokens.add(uploadRes['token'].toString());
            } else {
              tokens.add(pTrim);
            }
          } catch (e) {
            debugPrint('[EditCustomerScreen] Lỗi upload ảnh: $e');
            // Nếu là bản ghi offline hoặc chưa có mạng, giữ nguyên đường dẫn ảnh cục bộ
            tokens.add(pTrim);
          }
        }
      }
      changes['photo_tokens'] = tokens;
    }

    if (changes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có thay đổi nào được thực hiện.')),
      );
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.onSave != null) {
        await widget.onSave!(changes);
      } else {
        await ref
            .read(customerViewModelProvider.notifier)
            .updateCustomer(c.id, changes, clientUuid: c.clientUuid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Đã cập nhật ${changes.length} trường thông tin thành công!'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.customer;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sửa thông tin điểm bán',
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${c.code} • ${c.name}',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ).copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppLoading(size: 20),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Lưu'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // 1. Phân loại & Định danh
                  _buildSectionHeader(
                    icon: Icons.storefront_rounded,
                    title: '1. Định danh & Phân loại điểm bán',
                    badge: 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  // Mã điểm bán (Cố định, nhân viên không được sửa)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.roundedMd,
                      border: Border.all(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Mã điểm bán (Mã khách hàng)',
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceContainerLowest
                                    : AppColors.surfaceDim,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Không thể sửa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.code,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tên điểm bán (Có thể sửa)
                  AppTextField(
                    label: 'Tên điểm bán *',
                    hintText: 'Nhập tên điểm bán',
                    controller: _nameController,
                    enableVoiceInput: true,
                    prefixIcon: const Icon(Icons.store_outlined, size: 18),
                  ),
                  const SizedBox(height: 12),
                  _buildClassificationDropdowns(isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProvinceSelector(isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Phường / Xã',
                          hintText: 'Nhập phường/xã...',
                          controller: _wardNameController,
                          enableVoiceInput: true,
                          prefixIcon: const Icon(Icons.signpost_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Thông tin liên hệ & Địa chỉ
                  _buildSectionHeader(
                    icon: Icons.contact_phone_outlined,
                    title: '2. Thông tin liên hệ & Địa chỉ',
                    badge: 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Người liên hệ',
                          hintText: 'Họ và tên',
                          controller: _contactNameController,
                          enableVoiceInput: true,
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Chức vụ / Vai trò',
                          hintText: 'Chủ cửa hàng...',
                          controller: _contactTitleController,
                          enableVoiceInput: true,
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Số điện thoại',
                          hintText: '09xxxxxxxx',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Email',
                          hintText: 'email@domain.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Địa chỉ giao dịch',
                    hintText: 'Số nhà, tên đường, khu vực...',
                    controller: _addressController,
                    enableVoiceInput: true,
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.place_outlined, size: 18),
                  ),
                  const SizedBox(height: 24),

                  // 3. Bản đồ vị trí điểm bán (Bản đồ tương tác, cho phép sửa lat và lng)
                  _buildSectionHeader(
                    icon: Icons.map_rounded,
                    title: '3. Vị trí trên bản đồ',
                    badge: 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  AppMapLocationCard(
                    title: 'Vị trí điểm bán trên bản đồ',
                    lat: _currentLat,
                    lng: _currentLng,
                    isReadOnly: false, // 🟢 Vẫn cho sửa lat và lng theo yêu cầu
                    initialAddress: _addressController.text.trim().isNotEmpty
                        ? _addressController.text.trim()
                        : null,
                    showCoordinates: false, // Ẩn thông số kinh / vĩ độ dạng chữ text
                    showStyleSwitcher: true, // Cho phép chuyển đổi xem Vệ tinh / Đường phố
                    mapHeight: 250,
                    zoom: 16.5,
                    locateButtonText: 'LẤY VỊ TRÍ HIỆN TẠI',
                    updateButtonText: 'CẬP NHẬT LẠI VỊ TRÍ HIỆN TẠI',
                    onLocationChanged: (lat, lng, address) {
                      setState(() {
                        _currentLat = lat;
                        _currentLng = lng;
                        if ((_addressController.text.trim().isEmpty ||
                                _addressController.text.trim() == 'Chưa cập nhật') &&
                            address != null &&
                            address.isNotEmpty) {
                          _addressController.text = address;
                        }
                      });
                    },
                    onCleared: () {
                      setState(() {
                        _currentLat = null;
                        _currentLng = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Các trường mở rộng động (Dynamic Fields) - Vẽ trực tiếp ra ngoài layout, bỏ hẳn card
                  if (_dynamicControllers.isNotEmpty || _dynamicLocationValues.isNotEmpty) ...[
                    _buildDynamicFieldsCard(isDark),
                    const SizedBox(height: 12),
                  ],

                  // 4. Hình ảnh điểm bán (photo_tokens)
                  _buildSectionHeader(
                    icon: Icons.photo_library_outlined,
                    title: '4. Hình ảnh điểm bán',
                    badge: '${_photos.length}/10 ảnh',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildPhotosSection(isDark),
                ],
              ),
            ),

            // Bottom Sticky Action Button (Ẩn bottom bar nav nên dùng SafeArea để tránh sát mép màn hình)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      width: 0.8,
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
                child: AppButton(
                  text: 'CẬP NHẬT THÔNG TIN ĐIỂM BÁN',
                  isLoading: _isSaving,
                  icon: Icons.check_circle_rounded,
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String badge,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainer
                : AppColors.surfaceContainerHigh,
            borderRadius: AppRadius.roundedFull,
          ),
          child: Text(
            badge,
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ).copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationDropdowns(bool isDark) {
    final effectiveMeta = widget.meta.customerTypes.isNotEmpty
        ? widget.meta
        : (ref.watch(customerViewModelProvider).meta.customerTypes.isNotEmpty
            ? ref.watch(customerViewModelProvider).meta
            : (ref.watch(customerMetaProvider).valueOrNull ?? widget.meta));

    final customerTypes = effectiveMeta.customerTypes;
    final channels = effectiveMeta.channels;
    final regions = effectiveMeta.regions;

    final userRoutes = ref.watch(userAssignedRoutesProvider).valueOrNull ?? [];
    final currentRouteState = ref.watch(routeViewModelProvider);

    // Xây dựng danh sách tùy chọn cho Tuyến bán hàng
    final routeOptions = <_RouteOption>[];
    final seenIds = <int>{};
    final seenNames = <String>{};

    if (userRoutes.isNotEmpty) {
      for (final r in userRoutes) {
        final label = r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}');
        routeOptions.add(_RouteOption(r.id, label));
        seenIds.add(r.id);
        seenNames.add(label.toLowerCase().trim());
      }
    } else {
      final validRoutes = currentRouteState.availableRoutes
          .where((r) => r != 'Tất cả tuyến' && !CustomerEntity.isInvalidOrProvinceRoute(r))
          .toList();
      int tempId = 1;
      for (final r in validRoutes) {
        routeOptions.add(_RouteOption(tempId, r));
        seenIds.add(tempId);
        seenNames.add(r.toLowerCase().trim());
        tempId++;
      }
    }

    // Đảm bảo tuyến hiện tại của điểm bán luôn xuất hiện trong danh sách lựa chọn
    if (_selectedRouteName != null &&
        _selectedRouteName!.isNotEmpty &&
        _selectedRouteName != 'Tất cả tuyến') {
      final normalizedName = _selectedRouteName!.toLowerCase().trim();
      final existingIndex = routeOptions.indexWhere(
        (opt) => opt.name.toLowerCase().trim() == normalizedName,
      );
      if (existingIndex != -1) {
        _selectedRouteId ??= routeOptions[existingIndex].id;
      } else {
        final fallbackId = _selectedRouteId ?? (seenIds.isNotEmpty ? (seenIds.reduce((a, b) => a > b ? a : b) + 1) : 1);
        routeOptions.insert(0, _RouteOption(fallbackId, _selectedRouteName!));
        seenIds.add(fallbackId);
        _selectedRouteId = fallbackId;
      }
    } else if (_selectedRouteId != null && !seenIds.contains(_selectedRouteId!)) {
      final label = _selectedRouteName ?? 'Tuyến $_selectedRouteId';
      routeOptions.insert(0, _RouteOption(_selectedRouteId!, label));
      seenIds.add(_selectedRouteId!);
    }

    final effectiveRouteValue = routeOptions.any((opt) => opt.id == _selectedRouteId) ? _selectedRouteId : null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loại khách hàng',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedCustomerTypeId,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.category_outlined, size: 18),
                    ),
                    hint: const Text('Chọn loại KH'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('(Chưa phân loại)', style: TextStyle(color: AppColors.outline)),
                      ),
                      ...customerTypes.map(
                        (t) => DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(t.name.isNotEmpty ? t.name : t.code, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedCustomerTypeId = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kênh bán hàng',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedChannelId,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.hub_outlined, size: 18),
                    ),
                    hint: const Text('Chọn kênh'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('(Chưa chọn kênh)', style: TextStyle(color: AppColors.outline)),
                      ),
                      ...channels.map(
                        (ch) => DropdownMenuItem<int?>(
                          value: ch.id,
                          child: Text(ch.name.isNotEmpty ? ch.name : ch.code, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedChannelId = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Khu vực quản lý',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedRegionId,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.map_outlined, size: 18),
                    ),
                    hint: const Text('Chọn khu vực'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('(Chưa chọn KV)', style: TextStyle(color: AppColors.outline)),
                      ),
                      ...regions.map(
                        (reg) => DropdownMenuItem<int?>(
                          value: reg.id,
                          child: Text(reg.name.isNotEmpty ? reg.name : reg.code, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedRegionId = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tuyến bán hàng',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: effectiveRouteValue,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.alt_route_rounded, size: 18),
                    ),
                    hint: const Text('Chọn tuyến'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('(Chưa chọn tuyến)', style: TextStyle(color: AppColors.outline)),
                      ),
                      ...routeOptions.map(
                        (opt) => DropdownMenuItem<int?>(
                          value: opt.id,
                          child: Text(opt.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedRouteId = val;
                        if (val != null) {
                          final found = routeOptions.where((opt) => opt.id == val).firstOrNull;
                          _selectedRouteName = found?.name;
                        } else {
                          _selectedRouteName = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProvinceSelector(bool isDark) {
    final effectiveMeta = widget.meta.provinces.isNotEmpty
        ? widget.meta
        : (ref.watch(customerViewModelProvider).meta.provinces.isNotEmpty
            ? ref.watch(customerViewModelProvider).meta
            : (ref.watch(customerMetaProvider).valueOrNull ?? widget.meta));

    final provinces = effectiveMeta.provinces;

    if (provinces.isNotEmpty) {
      final currentProvince = _provinceNameController.text.trim();
      final hasCurrentInList = provinces.any((p) => p.provinceName == currentProvince);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tỉnh / Thành',
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: hasCurrentInList ? currentProvince : (currentProvince.isNotEmpty ? currentProvince : null),
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixIcon: Icon(Icons.location_city_outlined, size: 18),
            ),
            hint: const Text('Chọn Tỉnh/Thành'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('(Chưa chọn)', style: TextStyle(color: AppColors.outline)),
              ),
              if (!hasCurrentInList && currentProvince.isNotEmpty)
                DropdownMenuItem<String?>(
                  value: currentProvince,
                  child: Text(currentProvince, overflow: TextOverflow.ellipsis),
                ),
              ...provinces.map(
                (p) => DropdownMenuItem<String?>(
                  value: p.provinceName,
                  child: Text(p.provinceName, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _provinceNameController.text = val ?? '';
              });
            },
          ),
        ],
      );
    }

    return AppTextField(
      label: 'Tỉnh / Thành',
      hintText: 'Hà Nội, Phú Thọ...',
      controller: _provinceNameController,
      prefixIcon: const Icon(Icons.location_city_outlined, size: 18),
    );
  }

  bool _isSelectField(String key, CustomerDynamicColumn? colDef, DynamicFormField? schemaField) {
    if (colDef != null) {
      final it = colDef.inputType.toLowerCase().trim();
      if (it == 'select' ||
          it == 'dropdown' ||
          it == 'single_choice' ||
          it == 'choice' ||
          it == 'radio' ||
          it == 'combobox') {
        return true;
      }
      if (colDef.options.isNotEmpty) return true;
    }

    if (schemaField != null) {
      if (schemaField.type == DynamicFormFieldType.singleChoice) return true;
      if (schemaField.catalog == 'dropdown' || schemaField.catalog == 'select') return true;
      if (schemaField.options.isNotEmpty) return true;
    }

    final k = key.toLowerCase().trim();
    if (k.contains('khach_hang_vthm') || k.contains('kh_vthm')) return true;
    if (k.contains('nhan_1') || k.contains('nhan_2') || k.contains('nhan_3')) return true;

    final label = (colDef?.label ?? schemaField?.label ?? '').toLowerCase().trim();
    if (label.contains('khách hàng vthm') || label.contains('khach hang vthm')) return true;
    if (label.contains('nhãn 1') || label.contains('nhãn 2') || label.contains('nhãn 3') || label.startsWith('nhãn')) return true;

    return false;
  }

  List<String> _resolveSelectOptions({
    required String key,
    required CustomerDynamicColumn? colDef,
    required DynamicFormField? schemaField,
    required String currentValue,
  }) {
    final optionsSet = <String>{};

    // 1. Lấy từ colDef
    if (colDef != null && colDef.options.isNotEmpty) {
      for (final opt in colDef.options) {
        final label = opt.label.trim();
        if (label.isNotEmpty) optionsSet.add(label);
      }
    }

    // 2. Lấy từ schemaField
    if (schemaField != null && schemaField.options.isNotEmpty) {
      for (final opt in schemaField.options) {
        final label = opt.label.trim();
        if (label.isNotEmpty) optionsSet.add(label);
      }
    }

    // 3. Fallback cho các trường danh mục chuẩn MobiWork / DMS
    final k = key.toLowerCase().trim();
    final label = (colDef?.label ?? schemaField?.label ?? '').toLowerCase().trim();

    if (k.contains('khach_hang_vthm') || label.contains('khách hàng vthm')) {
      optionsSet.addAll([
        '1 - KH VTHM',
        '0 - Không phải KH VTHM',
        '2 - Chưa xác định',
      ]);
    }

    // 4. Thu thập các giá trị nhãn thực tế từ danh sách điểm bán khác
    if (k.contains('nhan_') || label.contains('nhãn')) {
      final allCustomers = ref.watch(customerViewModelProvider).allCustomers;
      for (final cust in allCustomers) {
        final v = cust.dynamicFields[key]?.toString().trim() ??
            cust.dynamicFields[k]?.toString().trim() ??
            cust.dynamicFields['mw_$k']?.toString().trim();
        if (v != null && v.isNotEmpty && !v.startsWith('[') && !v.startsWith('{')) {
          optionsSet.add(v);
        }
      }
    }

    // 5. Luôn thêm giá trị hiện tại nếu có
    if (currentValue.isNotEmpty && !currentValue.startsWith('[') && !currentValue.startsWith('{')) {
      optionsSet.add(currentValue);
    }

    return optionsSet.toList();
  }

  Future<void> _promptCustomValue(
    BuildContext context,
    String key,
    String label,
    TextEditingController controller,
  ) async {
    final customController = TextEditingController(text: controller.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhập giá trị: $label',
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: customController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập giá trị cho $label...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, customController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        controller.text = result;
      });
    }
  }

  String _formatDynamicKey(String key) {
    var k = key.replaceFirst('mw_', '');
    if (k == 'khach_hang_vthm') return 'Khách hàng VTHM';
    if (k == 'nhan_1') return 'Nhãn 1';
    if (k == 'nhan_2') return 'Nhãn 2';
    if (k == 'nhan_3') return 'Nhãn 3';
    return k.replaceAll('_', ' ');
  }

  Widget _buildDynamicFieldsCard(bool isDark) {
    final effectiveColumns = widget.dynamicColumns.isNotEmpty
        ? widget.dynamicColumns
        : (widget.meta.dynamicColumns.isNotEmpty
            ? widget.meta.dynamicColumns
            : ref.watch(customerViewModelProvider).dynamicColumns);

    final schemaAsync = ref.watch(customerFormSchemaProvider);
    final schemaFields = (schemaAsync.valueOrNull?['data']?['fields'] as List? ?? [])
        .map((f) => DynamicFormField.fromJson(f as Map<String, dynamic>))
        .toList();

    if (_dynamicControllers.isEmpty && _dynamicLocationValues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          ..._dynamicLocationValues.entries.map((entry) {
            final key = entry.key;
            final locVal = entry.value;

            final colDef = effectiveColumns
                .cast<CustomerDynamicColumn?>()
                .firstWhere(
                  (col) =>
                      col?.code == key ||
                      col?.legacyKey == key ||
                      'mw_${col?.legacyKey}' == key ||
                      col?.code.replaceFirst('mw_', '') == key.replaceFirst('mw_', ''),
                  orElse: () => null,
                );

            final schemaField = schemaFields
                .cast<DynamicFormField?>()
                .firstWhere(
                  (f) =>
                      f?.code == key ||
                      'mw_${f?.code}' == key ||
                      f?.code.replaceFirst('mw_', '') == key.replaceFirst('mw_', ''),
                  orElse: () => null,
                );

            final label = colDef?.label.isNotEmpty == true
                ? colDef!.label
                : (schemaField?.label.isNotEmpty == true
                    ? schemaField!.label
                    : _formatDynamicKey(key));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LocationFieldWidget(
                label: label,
                isRequired: colDef?.required ?? schemaField?.isRequired ?? false,
                isReadOnly: colDef?.readOnly ?? schemaField?.isReadOnly ?? false,
                description: schemaField?.helperText,
                maxLength: schemaField?.max?.toInt() ?? 500,
                value: locVal,
                onChanged: (newVal) {
                  setState(() {
                    _dynamicLocationValues[key] = newVal;
                    _dynamicLocationTouched[key] = true;
                  });
                },
              ),
            );
          }),
          ..._dynamicControllers.entries.map((entry) {
            final key = entry.key;
            final controller = entry.value;

            final colDef = effectiveColumns
              .cast<CustomerDynamicColumn?>()
              .firstWhere(
                (col) =>
                    col?.code == key ||
                    col?.legacyKey == key ||
                    'mw_${col?.legacyKey}' == key ||
                    col?.code.replaceFirst('mw_', '') == key.replaceFirst('mw_', ''),
                orElse: () => null,
              );

          final schemaField = schemaFields
              .cast<DynamicFormField?>()
              .firstWhere(
                (f) =>
                    f?.code == key ||
                    'mw_${f?.code}' == key ||
                    f?.code.replaceFirst('mw_', '') == key.replaceFirst('mw_', ''),
                orElse: () => null,
              );

          final label = colDef?.label.isNotEmpty == true
              ? colDef!.label
              : (schemaField?.label.isNotEmpty == true
                  ? schemaField!.label
                  : _formatDynamicKey(key));

          final isSelect = _isSelectField(key, colDef, schemaField);

          if (isSelect) {
            final currentValue = controller.text.trim();
            final options = _resolveSelectOptions(
              key: key,
              colDef: colDef,
              schemaField: schemaField,
              currentValue: currentValue,
            );

            final hasCurrentInOptions = currentValue.isNotEmpty && options.contains(currentValue);
            final effectiveValue = hasCurrentInOptions
                ? currentValue
                : (currentValue.isNotEmpty ? currentValue : null);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.labelSmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Danh sách chọn',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('dynamic_select_${key}_$currentValue'),
                    initialValue: effectiveValue,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.list_alt_rounded, size: 18),
                      hintText: 'Chọn $label...',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceContainerLowest
                          : AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    dropdownColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('(Chưa chọn)', style: TextStyle(color: AppColors.outline)),
                      ),
                      if (!hasCurrentInOptions && currentValue.isNotEmpty)
                        DropdownMenuItem<String?>(
                          value: currentValue,
                          child: Text(currentValue, overflow: TextOverflow.ellipsis),
                        ),
                      ...options.map(
                        (opt) => DropdownMenuItem<String?>(
                          value: opt,
                          child: Text(opt, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const DropdownMenuItem<String?>(
                        value: '__custom__',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              '+ Nhập giá trị khác...',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (newVal) {
                      if (newVal == '__custom__') {
                        _promptCustomValue(context, key, label, controller);
                      } else {
                        setState(() {
                          controller.text = newVal ?? '';
                        });
                      }
                    },
                  ),
                ],
              ),
            );
          }

          final isPhone = key.toLowerCase().contains('phone') ||
              key.toLowerCase().contains('dien_thoai') ||
              key.toLowerCase().contains('sdt') ||
              label.toLowerCase().contains('điện thoại') ||
              label.toLowerCase().contains('sđt');

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppTextField(
              label: label,
              hintText: 'Nhập $label...',
              controller: controller,
              keyboardType: isPhone ? TextInputType.phone : null,
              prefixIcon: isPhone ? const Icon(Icons.phone_outlined, size: 20) : null,
              enableVoiceInput: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPhotosSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tối đa 10 ảnh. Ảnh đầu tiên làm ảnh đại diện điểm bán.',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (_photos.length < 10)
                TextButton.icon(
                  onPressed: _showPhotoPickerOptions,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Thêm ảnh'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photos.isEmpty)
            InkWell(
              onTap: _showPhotoPickerOptions,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có ảnh điểm bán',
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bấm để chụp ảnh hoặc chọn từ thư viện',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._photos.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final path = entry.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _viewFullPhotoGallery(context, idx),
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: idx == 0
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                              width: idx == 0 ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildPhotoWidget(path),
                          ),
                        ),
                      ),
                      if (idx == 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Text(
                              'Đại diện',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _photos.removeAt(idx);
                              _photosChanged = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_photos.length < 10)
                  InkWell(
                    onTap: _showPhotoPickerOptions,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerLowest
                            : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 22,
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Thêm ảnh',
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                            ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _viewFullPhotoGallery(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) {
        int currentIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  'Ảnh ${currentIndex + 1}/${_photos.length}${currentIndex == 0 ? " (Đại diện)" : ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    tooltip: 'Xóa ảnh này',
                    onPressed: () {
                      setState(() {
                        _photos.removeAt(currentIndex);
                        _photosChanged = true;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: PageView.builder(
                controller: pageController,
                itemCount: _photos.length,
                onPageChanged: (idx) {
                  setDialogState(() {
                    currentIndex = idx;
                  });
                },
                itemBuilder: (context, idx) {
                  final path = _photos[idx];
                  return Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: _buildPhotoWidget(path, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
              bottomNavigationBar: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (currentIndex > 0)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text('Đặt làm ảnh đại diện'),
                          onPressed: () {
                            setState(() {
                              final p = _photos.removeAt(currentIndex);
                              _photos.insert(0, p);
                              _photosChanged = true;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoWidget(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28, color: AppColors.outline)),
      );
    }
    if (path.startsWith('/')) {
      return Image.network(
        '${AppConstants.baseUrl}$path',
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28, color: AppColors.outline)),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28, color: AppColors.outline)),
      );
    }
    return const Center(child: Icon(Icons.image_outlined, size: 28, color: AppColors.outline));
  }

  Future<void> _showPhotoPickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
        context,
        featureName: 'chụp ảnh khách hàng',
        customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh cửa hàng / khách hàng. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
      );
      if (!hasPermission) return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      final watermarked = await PhotoWatermarkHelper.addWatermark(
        imageFile: File(picked.path),
        locationName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : widget.customer.name,
      );
      setState(() {
        if (_photos.length < 10) {
          _photos.add(watermarked.path);
          _photosChanged = true;
        }
      });
    }
  }
}

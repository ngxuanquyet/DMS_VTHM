import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/widgets/camera_permission_dialog.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../screens/add_customer_screen.dart';
import '../screens/edit_customer_screen.dart';
import '../viewmodels/customer_view_model.dart';

class EditCustomerDialog extends ConsumerStatefulWidget {
  final CustomerEntity customer;
  final CustomerMetaData meta;
  final List<CustomerDynamicColumn> dynamicColumns;
  final Future<void> Function(Map<String, dynamic> changes) onSave;

  const EditCustomerDialog({
    super.key,
    required this.customer,
    this.meta = const CustomerMetaData(),
    this.dynamicColumns = const [],
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerEntity customer,
    CustomerMetaData meta = const CustomerMetaData(),
    List<CustomerDynamicColumn> dynamicColumns = const [],
    required Future<void> Function(Map<String, dynamic> changes) onSave,
  }) {
    return EditCustomerScreen.open(
      context,
      customer: customer,
      meta: meta,
      dynamicColumns: dynamicColumns,
      onSave: onSave,
    );
  }

  @override
  ConsumerState<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends ConsumerState<EditCustomerDialog> {
  // 1. Identification & Classification controllers / state
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _wardNameController;
  int? _selectedCustomerTypeId;
  int? _selectedRegionId;

  // 2. Contact & Address controllers
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactTitleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  // 3. GPS & Geofence (read-only manual display, updated via GPS button)
  double? _currentLat;
  double? _currentLng;
  double? _currentAccuracy;
  bool? _isMockLocation;
  late final TextEditingController _geofenceRadiusController;

  // 4. Dynamic fields controllers
  final Map<String, TextEditingController> _dynamicControllers = {};

  // 5. Photos state (Spec 23/09/2026: photo_tokens array, max 10 photos)
  late List<String> _photos;
  bool _photosChanged = false;

  bool _isSaving = false;
  bool _isLocating = false;

  static const _ignoredDynamicKeys = {
    // Photos
    'photo_url', 'photo_urls', 'photo_token', 'photo_tokens', 'photo_file_id', 'photo', 'photos',
    'photo_path', 'photo_paths', 'image', 'images', 'image_url', 'image_urls', 'avatar',
    // Routes
    'routes', 'route_ids', 'route', 'route_id', 'route_name', 'routename', 'route_code', 'routecode',
    'sales_route', 'sales_routes',
    // Core fields
    'id', 'code', 'customer_code', 'name', 'customer_name', 'address', 'phone', 'contact_name', 'contact_title', 'contact_person',
    'email', 'lat', 'lng', 'latitude', 'longitude', 'coords', 'geofence_radius_m', 'geofence',
    'birthday', 'tax_code', 'delivery_address', 'description', 'notes',
    // Classifications & Administrative divisions
    'type', 'customer_type', 'customer_type_id', 'customer_type_name',
    'channel', 'channel_id', 'channel_name',
    'region', 'region_id', 'region_name', 'area_id', 'area_name',
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

    _codeController = TextEditingController(text: c.code);
    _nameController = TextEditingController(text: c.name);
    _provinceNameController = TextEditingController(text: c.provinceName ?? '');
    _wardNameController = TextEditingController(text: c.wardName ?? '');
    _selectedCustomerTypeId = c.customerTypeId;
    _selectedRegionId = c.regionId;

    _contactNameController = TextEditingController(
      text: c.contactPerson == 'Chưa cập nhật' ? '' : c.contactPerson,
    );
    _contactTitleController =
        TextEditingController(text: c.contactTitle ?? '');
    _phoneController = TextEditingController(
      text: c.phone == 'Chưa có SĐT' ? '' : c.phone,
    );
    _emailController = TextEditingController(text: c.email ?? '');
    _addressController = TextEditingController(text: c.address);

    _currentLat = c.lat;
    _currentLng = c.lng;
    _isMockLocation = c.coordsMock;
    _geofenceRadiusController = TextEditingController(
      text: c.geofenceRadiusM?.toString() ?? '50',
    );

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
      if (val is List || val is Map) continue;
      final valStr = val != null ? val.toString().trim() : '';
      if (valStr.startsWith('[') && valStr.endsWith(']')) continue;
      if (valStr.startsWith('{') && valStr.endsWith('}')) continue;

      _dynamicControllers[key] =
          TextEditingController(text: valStr);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _provinceNameController.dispose();
    _wardNameController.dispose();

    _contactNameController.dispose();
    _contactTitleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _geofenceRadiusController.dispose();

    for (final c in _dynamicControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tự động lấy vị trí thực tế từ phần cứng GPS của thiết bị
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chưa được cấp quyền truy cập vị trí GPS.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      // 1. Lấy ngay vị trí đã biết gần nhất từ hệ thống (< 5ms) để phản hồi tức thì
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentLat = double.parse(lastKnown.latitude.toStringAsFixed(6));
          _currentLng = double.parse(lastKnown.longitude.toStringAsFixed(6));
          _currentAccuracy = lastKnown.accuracy;
          _isMockLocation = lastKnown.isMocked;
          _isLocating = false;
        });
        LocationService.updateCachedPosition(lastKnown);
      }

      // 2. Lấy vị trí tươi mới với accuracy medium (timeout 4s)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );

        if (mounted) {
          setState(() {
            _currentLat = double.parse(position.latitude.toStringAsFixed(6));
            _currentLng = double.parse(position.longitude.toStringAsFixed(6));
            _currentAccuracy = position.accuracy;
            _isMockLocation = position.isMocked;
            _isLocating = false;
          });
        }
        LocationService.updateCachedPosition(position);
      } catch (_) {
        if (lastKnown == null) rethrow;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật tọa độ GPS từ vị trí hiện tại thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lấy vị trí GPS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearGps() {
    setState(() {
      _currentLat = null;
      _currentLng = null;
    });
  }

  Future<void> _handleSave() async {
    final changes = <String, dynamic>{};
    final c = widget.customer;

    // 1. Name (Code do hệ thống tự sinh, không thể sửa)
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != c.name) {
      changes['name'] = newName;
    }

    // 2. Classification (Customer Type, Channel, Region, Province, Ward)
    if (_selectedCustomerTypeId != c.customerTypeId) {
      changes['customer_type_id'] = _selectedCustomerTypeId;
    }

    // Spec 20/10/2026 (§3): Bỏ gửi channel_id
    changes.remove('channel_id');

    if (_selectedRegionId != c.regionId) {
      changes['region_id'] = _selectedRegionId;
    }

    final newProvince = _provinceNameController.text.trim();
    if (newProvince != (c.provinceName ?? '')) {
      changes['province_name'] = newProvince.isNotEmpty ? newProvince : null;
    }

    final newWard = _wardNameController.text.trim();
    if (newWard != (c.wardName ?? '')) {
      changes['ward_name'] = newWard.isNotEmpty ? newWard : null;
    }

    // 3. Contact & Address
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

    // 4. GPS Coordinates: Gửi ô cứng 'coords' ({lat, lng, mock}) theo spec 15/10/2026
    // Gửi coords: null để xoá toạ độ. Tuyệt đối KHÔNG gửi kèm lat/lng kẻo bị lỗi 422!
    if (_currentLat != c.lat || _currentLng != c.lng) {
      if (_currentLat != null && _currentLng != null) {
        changes['coords'] = {
          'lat': double.parse(_currentLat!.toStringAsFixed(7)),
          'lng': double.parse(_currentLng!.toStringAsFixed(7)),
          if (_currentAccuracy != null) 'accuracy': double.parse(_currentAccuracy!.toStringAsFixed(1)),
          'mock': _isMockLocation ?? false,
        };
      } else {
        changes['coords'] = null;
      }
    }

    final newGeofence = int.tryParse(_geofenceRadiusController.text.trim());
    if (newGeofence != null && newGeofence != c.geofenceRadiusM) {
      if (newGeofence < 10 || newGeofence > 5000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bán kính Geofence phải nằm trong khoảng 10 - 5000 mét.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      changes['geofence_radius_m'] = newGeofence;
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

    if (dynamicChanges.isNotEmpty) {
      changes['data'] = dynamicChanges;
    }

    // 6. Xử lý ảnh điểm bán (photo_tokens) theo spec 23/09/2026:
    // 🔴 Ba ngữ nghĩa bắt buộc tuân thủ:
    // - Không có khoá photo_tokens: server giữ nguyên bộ ảnh hiện có
    // - "photo_tokens": ["token1", "token2"]: đặt lại trọn bộ đúng thứ tự đó
    // - "photo_tokens": []: xóa sạch bộ ảnh
    // TUYỆT ĐỐI không gửi photo_tokens nếu người dùng không chạm vào ô ảnh!
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
          // Local file path to upload
          try {
            final uploadRes = await repo.uploadCustomerPhoto(pTrim);
            if (uploadRes['token'] != null) {
              tokens.add(uploadRes['token'].toString());
            }
          } catch (e) {
            debugPrint('[EditCustomerDialog] Lỗi upload ảnh: $e');
          }
        }
      }
      changes['photo_tokens'] = tokens;
    }

    if (changes.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có thay đổi nào được thực hiện.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(changes);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã cập nhật ${changes.length} trường thông tin thành công!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        AppSnackBar.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                borderRadius: AppRadius.roundedFull,
              ),
            ),

            // Header Row with Title and Top-Right Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sửa thông tin khách hàng',
                          style: AppTypography.titleMedium(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Chỉnh sửa thông tin điểm bán',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: AppLoading(size: 20),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Cập nhật'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.primary
                            : AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedMd,
                        ),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Form Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Section 1: Phân loại & Định danh
                  _buildSectionHeader(
                    icon: Icons.account_tree_outlined,
                    title: '1. Định danh & Phân loại điểm bán',
                    badge: 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Mã điểm bán (hệ thống tự sinh)',
                          hintText: 'Mã hệ thống tự sinh',
                          controller: _codeController,
                          readOnly: true,
                          prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Tên điểm bán (name)',
                          hintText: 'Nhập tên điểm bán',
                          controller: _nameController,
                          enableVoiceInput: true,
                          prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dropdowns from /crm/customers/meta
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
                          label: 'Phường / Xã (ward_name)',
                          hintText: 'Nhập phường/xã...',
                          controller: _wardNameController,
                          enableVoiceInput: true,
                          prefixIcon: const Icon(Icons.signpost_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Thông tin liên hệ & Địa chỉ
                  _buildSectionHeader(
                    icon: Icons.contact_phone_outlined,
                    title: '2. Thông tin liên hệ & Địa chỉ',
                    badge: 'Có thể sửa',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Người liên hệ',
                          hintText: 'Họ tên',
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
                    hintText: 'Số nhà, tên đường, khu phố...',
                    controller: _addressController,
                    enableVoiceInput: true,
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.place_outlined, size: 18),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Tọa độ GPS & Định vị (Khóa gõ tay, chỉ lấy GPS tự động)
                  _buildSectionHeader(
                    icon: Icons.gps_fixed_rounded,
                    title: '3. Tọa độ GPS & Bán kính Geofence',
                    badge: 'Lấy từ GPS máy',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildGpsAutoCaptureCard(isDark),
                  const SizedBox(height: 20),

                  // Section 4: Dynamic Fields (Trường động)
                  _buildSectionHeader(
                    icon: Icons.dynamic_feed_rounded,
                    title: '4. Trường mở rộng / Động (Dynamic Fields)',
                    badge: '${_dynamicControllers.length} trường',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDynamicFieldsCard(isDark),
                  const SizedBox(height: 20),

                  // Section 5: Hình ảnh điểm bán (photo_tokens - tối đa 10 ảnh theo spec 23/09/2026)
                  _buildSectionHeader(
                    icon: Icons.photo_library_outlined,
                    title: '5. Hình ảnh điểm bán',
                    badge: '${_photos.length}/10 ảnh',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildPhotosSection(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 10),
          if (_photos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: _showPhotoPickerOptions,
                child: Column(
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.outline),
                    const SizedBox(height: 6),
                    Text(
                      'Chưa có ảnh điểm bán. Bấm để thêm.',
                      style: AppTypography.bodySmall(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photos.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final path = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
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
                      if (idx == 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: AppColors.primary.withValues(alpha: 0.85),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Text(
                              'Đại diện',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _photos.removeAt(idx);
                              _photosChanged = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24),
        cacheWidth: 300,
      );
    }
    if (path.startsWith('/')) {
      return Image.network(
        '${AppConstants.baseUrl}$path',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24),
        cacheWidth: 300,
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24),
        cacheWidth: 300,
      );
    }
    return const Icon(Icons.image_outlined, size: 24);
  }

  Future<void> _showPhotoPickerOptions() async {
    final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
      context,
      featureName: 'chụp ảnh khách hàng',
      customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh cửa hàng / khách hàng. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
    );
    if (!hasPermission) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
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
    final customerTypes = widget.meta.customerTypes;
    final regions = widget.meta.regions;

    return Column(
      children: [
        Row(
          children: [
            // Customer Type Dropdown
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
          ],
        ),
        const SizedBox(height: 12),

        // Region (Khu vực cũ 63 khu vực) Dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khu vực quản lý (region_id - 63 khu vực cũ)',
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
              hint: const Text('Chọn khu vực quản lý'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('(Chưa chọn khu vực)', style: TextStyle(color: AppColors.outline)),
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
      ],
    );
  }

  Widget _buildProvinceSelector(bool isDark) {
    final provinces = widget.meta.provinces;

    if (provinces.isNotEmpty) {
      final currentProvince = _provinceNameController.text.trim();
      final hasCurrentInList = provinces.any((p) => p.provinceName == currentProvince);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tỉnh / Thành mới (35 tỉnh)',
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
      label: 'Tỉnh/Thành mới (province)',
      hintText: 'Hà Nội, Phú Thọ...',
      controller: _provinceNameController,
      prefixIcon: const Icon(Icons.location_city_outlined, size: 18),
    );
  }

  /// Khối hiển thị Tọa độ GPS (Read-only manual, chỉ cập nhật bằng nút Lấy GPS)
  Widget _buildGpsAutoCaptureCard(bool isDark) {
    final hasCoords = _currentLat != null && _currentLng != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: hasCoords
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GPS Coordinates Display Box (Read-only, user cannot type)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh,
                    borderRadius: AppRadius.roundedMd,
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
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 14,
                            color: hasCoords
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.outline),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vĩ độ (Latitude):',
                            style: AppTypography.labelSmall(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentLat != null
                            ? 'Đã xác thực vị trí'
                            : '(Chưa có vị trí)',
                        style: AppTypography.bodyMedium(
                          color: _currentLat != null
                              ? (isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface)
                              : (isDark
                                  ? AppColors.darkOutline
                                  : AppColors.outline),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh,
                    borderRadius: AppRadius.roundedMd,
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
                        children: [
                          Icon(
                            Icons.location_searching_rounded,
                            size: 14,
                            color: hasCoords
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.outline),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Kinh độ (Longitude):',
                            style: AppTypography.labelSmall(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentLng != null
                            ? 'Đã xác thực vị trí'
                            : '(Chưa có vị trí)',
                        style: AppTypography.bodyMedium(
                          color: _currentLng != null
                              ? (isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface)
                              : (isDark
                                  ? AppColors.darkOutline
                                  : AppColors.outline),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instruction Note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tọa độ GPS gửi theo cặp (lat/lng). Nhấn nút bên dưới để lấy vị trí thực tế của thiết bị.',
                  style: AppTypography.bodySmall(
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                  ).copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GPS Action Buttons Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating
                      ? const AppLoading(size: 16)
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _isLocating
                        ? 'Đang lấy vị trí GPS...'
                        : 'LẤY VỊ TRÍ HIỆN TẠI TỪ GPS',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                ),
              ),
              if (hasCoords) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _clearGps,
                  tooltip: 'Xóa tọa độ GPS',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Geofence Radius
          AppTextField(
            label: 'Bán kính Geofence (geofence_radius_m: 10 - 5000m)',
            hintText: '50',
            controller: _geofenceRadiusController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.radar_outlined, size: 18),
          ),
        ],
      ),
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

    if (_dynamicControllers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLowest
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            'Không có trường động nào được cấu hình cho ngữ cảnh mobile.',
            style: AppTypography.bodySmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _dynamicControllers.entries.map((entry) {
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
                    key: ValueKey('dialog_select_${key}_$currentValue'),
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

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppTextField(
              label: label,
              hintText: 'Nhập $label...',
              controller: controller,
              enableVoiceInput: true,
            ),
          );
        }).toList(),
      ),
    );
  }
}

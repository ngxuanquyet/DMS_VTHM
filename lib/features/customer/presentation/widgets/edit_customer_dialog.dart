import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';

class EditCustomerDialog extends StatefulWidget {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EditCustomerDialog(
        customer: customer,
        meta: meta,
        dynamicColumns: dynamicColumns.isNotEmpty ? dynamicColumns : meta.dynamicColumns,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  // 1. Identification & Classification controllers / state
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _wardNameController;
  int? _selectedCustomerTypeId;
  int? _selectedChannelId;
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
  late final TextEditingController _geofenceRadiusController;

  // 4. Dynamic fields controllers
  final Map<String, TextEditingController> _dynamicControllers = {};

  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;

    _codeController = TextEditingController(text: c.code);
    _nameController = TextEditingController(text: c.name);
    _provinceNameController = TextEditingController(text: c.provinceName ?? '');
    _wardNameController = TextEditingController(text: c.wardName ?? '');
    _selectedCustomerTypeId = c.customerTypeId;
    _selectedChannelId = c.channelId;
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
    _geofenceRadiusController = TextEditingController(
      text: c.geofenceRadiusM?.toString() ?? '50',
    );

    // Initialize dynamic controllers from active schema and customer data
    final effectiveColumns = widget.dynamicColumns.isNotEmpty
        ? widget.dynamicColumns
        : widget.meta.dynamicColumns;

    final allDynamicKeys = <String>{
      ...effectiveColumns.map((col) => col.code),
      ...widget.customer.dynamicFields.keys,
    };

    for (final key in allDynamicKeys) {
      final val = widget.customer.dynamicFields[key];
      _dynamicControllers[key] =
          TextEditingController(text: val != null ? val.toString() : '');
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _currentLat = double.parse(position.latitude.toStringAsFixed(6));
        _currentLng = double.parse(position.longitude.toStringAsFixed(6));
        _isLocating = false;
      });

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

    // 1. Code & Name
    final newCode = _codeController.text.trim();
    if (newCode.isNotEmpty && newCode != c.code) {
      changes['code'] = newCode;
    }

    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != c.name) {
      changes['name'] = newName;
    }

    // 2. Classification (Customer Type, Channel, Region, Province, Ward)
    if (_selectedCustomerTypeId != c.customerTypeId) {
      changes['customer_type_id'] = _selectedCustomerTypeId;
    }

    if (_selectedChannelId != c.channelId) {
      changes['channel_id'] = _selectedChannelId;
    }

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

    // 4. GPS Coordinates (Must be sent as a pair per API 422 rule)
    if (_currentLat != c.lat || _currentLng != c.lng) {
      changes['lat'] = _currentLat;
      changes['lng'] = _currentLng;
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

    // 5. Dynamic Editable Fields (Only source == "own" and read_only == false per spec)
    final effectiveColumns = widget.dynamicColumns.isNotEmpty
        ? widget.dynamicColumns
        : widget.meta.dynamicColumns;

    final dynamicChanges = <String, dynamic>{};
    for (final entry in _dynamicControllers.entries) {
      final key = entry.key;
      final newVal = entry.value.text.trim();
      final oldVal = c.dynamicFields[key]?.toString() ?? '';

      final colDef = effectiveColumns
          .cast<CustomerDynamicColumn?>()
          .firstWhere((col) => col?.code == key, orElse: () => null);

      final isReadOnly =
          colDef?.readOnly == true || colDef?.source == 'mobiwork';
      if (!isReadOnly && newVal != oldVal) {
        dynamicChanges[key] = newVal.isNotEmpty ? newVal : null;
      }
    }

    if (dynamicChanges.isNotEmpty) {
      changes['data'] = dynamicChanges;
    }

    if (changes.isEmpty) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
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
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
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
                          label: 'Mã điểm bán (code)',
                          hintText: 'Nhập mã KH/điểm bán',
                          controller: _codeController,
                          prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Tên điểm bán (name)',
                          hintText: 'Nhập tên điểm bán',
                          controller: _nameController,
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
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Chức vụ / Vai trò',
                          hintText: 'Chủ cửa hàng...',
                          controller: _contactTitleController,
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
                ],
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
    final customerTypes = widget.meta.customerTypes;
    final channels = widget.meta.channels;
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
            const SizedBox(width: 10),

            // Channel Dropdown
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
                            ? _currentLat!.toStringAsFixed(6)
                            : '(Chưa có vĩ độ)',
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
                            ? _currentLng!.toStringAsFixed(6)
                            : '(Chưa có kinh độ)',
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
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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

  Widget _buildDynamicFieldsCard(bool isDark) {
    final effectiveColumns = widget.dynamicColumns.isNotEmpty
        ? widget.dynamicColumns
        : widget.meta.dynamicColumns;

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
              .firstWhere((col) => col?.code == key, orElse: () => null);

          final label = colDef?.label.isNotEmpty == true ? colDef!.label : key;
          final isReadOnly =
              colDef?.readOnly == true || colDef?.source == 'mobiwork';
          final source = colDef?.source ?? 'own';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelLarge(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isReadOnly
                            ? AppColors.tertiary.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: Text(
                        isReadOnly ? 'Hệ cũ (Chỉ đọc)' : 'Tự tạo ($source)',
                        style: AppTypography.labelSmall(
                          color: isReadOnly
                              ? AppColors.tertiary
                              : AppColors.primary,
                        ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (isReadOnly)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                    child: Text(
                      controller.text.isNotEmpty
                          ? controller.text
                          : '(Trống)',
                      style: AppTypography.bodyMedium(
                        color: controller.text.isNotEmpty
                            ? (isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface)
                            : (isDark
                                ? AppColors.darkOutline
                                : AppColors.outline),
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: controller,
                    style: AppTypography.bodyMedium(
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập $label...',
                      isDense: true,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

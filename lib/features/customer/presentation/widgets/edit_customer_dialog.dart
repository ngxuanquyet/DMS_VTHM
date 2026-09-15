import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';

class EditCustomerDialog extends StatefulWidget {
  final CustomerEntity customer;
  final List<CustomerDynamicColumn> dynamicColumns;
  final Future<void> Function(Map<String, dynamic> changes) onSave;

  const EditCustomerDialog({
    super.key,
    required this.customer,
    this.dynamicColumns = const [],
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerEntity customer,
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
        dynamicColumns: dynamicColumns,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  // 1. Identification & Classification controllers
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _wardNameController;
  late final TextEditingController _customerTypeIdController;
  late final TextEditingController _channelIdController;
  late final TextEditingController _regionIdController;

  // 2. Contact & Address controllers
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactTitleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  // 3. Statuses
  late String _status;
  late String _approvalStatus;

  // 4. GPS & Geofence (read-only manual display, updated via GPS button)
  double? _currentLat;
  double? _currentLng;
  late final TextEditingController _geofenceRadiusController;

  // 5. Dynamic fields controllers
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
    _customerTypeIdController =
        TextEditingController(text: c.customerTypeId?.toString() ?? '');
    _channelIdController =
        TextEditingController(text: c.channelId?.toString() ?? '');
    _regionIdController =
        TextEditingController(text: c.regionId?.toString() ?? '');

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

    _status = c.status.isNotEmpty ? c.status : 'active';
    _approvalStatus =
        c.approvalStatus.isNotEmpty ? c.approvalStatus : 'approved';

    _currentLat = c.lat;
    _currentLng = c.lng;
    _geofenceRadiusController = TextEditingController(
      text: c.geofenceRadiusM?.toString() ?? '50',
    );

    // Initialize dynamic controllers
    final allDynamicKeys = <String>{
      ...widget.dynamicColumns.map((col) => col.code),
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
    _customerTypeIdController.dispose();
    _channelIdController.dispose();
    _regionIdController.dispose();

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

    // 2. Statuses
    if (_status != c.status) {
      changes['status'] = _status;
    }
    if (_approvalStatus != c.approvalStatus) {
      changes['approval_status'] = _approvalStatus;
    }

    // 3. Classification IDs & Names
    final newTypeId = int.tryParse(_customerTypeIdController.text.trim());
    if (newTypeId != c.customerTypeId) {
      changes['customer_type_id'] = newTypeId;
    }

    final newChannelId = int.tryParse(_channelIdController.text.trim());
    if (newChannelId != c.channelId) {
      changes['channel_id'] = newChannelId;
    }

    final newRegionId = int.tryParse(_regionIdController.text.trim());
    if (newRegionId != c.regionId) {
      changes['region_id'] = newRegionId;
    }

    final newProvince = _provinceNameController.text.trim();
    if (newProvince != (c.provinceName ?? '')) {
      changes['province_name'] = newProvince.isNotEmpty ? newProvince : null;
    }

    final newWard = _wardNameController.text.trim();
    if (newWard != (c.wardName ?? '')) {
      changes['ward_name'] = newWard.isNotEmpty ? newWard : null;
    }

    // 4. Contact & Address
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

    // 5. GPS Coordinates (Must be sent as a pair per API 422 rule)
    if (_currentLat != c.lat || _currentLng != c.lng) {
      changes['lat'] = _currentLat;
      changes['lng'] = _currentLng;
    }

    final newGeofence = int.tryParse(_geofenceRadiusController.text.trim());
    if (newGeofence != null && newGeofence != c.geofenceRadiusM) {
      changes['geofence_radius_m'] = newGeofence;
    }

    // 6. Dynamic Editable Fields
    final dynamicChanges = <String, dynamic>{};
    for (final entry in _dynamicControllers.entries) {
      final key = entry.key;
      final newVal = entry.value.text.trim();
      final oldVal = c.dynamicFields[key]?.toString() ?? '';

      final colDef = widget.dynamicColumns
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
    final customer = widget.customer;

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

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: customer.accentColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.roundedSm,
                      border: Border.all(
                        color: customer.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      customer.code,
                      style: AppTypography.labelLarge(
                        color: customer.accentColor,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sửa thông tin điểm bán',
                          style: AppTypography.titleMedium(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Có thể sửa mọi trường thông tin theo API',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  // Statuses Row (Dropdown / Selectors)
                  _buildStatusEditRow(isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'ID Loại KH (customer_type_id)',
                          hintText: '1, 2, 3...',
                          controller: _customerTypeIdController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.category_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'ID Kênh bán (channel_id)',
                          hintText: 'ID kênh (KA, GT...)',
                          controller: _channelIdController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.hub_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'ID Khu vực (region_id)',
                          hintText: 'ID khu vực cũ',
                          controller: _regionIdController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.map_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Tỉnh/Thành mới (province)',
                          hintText: 'Hà Nội, Phú Thọ...',
                          controller: _provinceNameController,
                          prefixIcon: const Icon(Icons.location_city_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Phường / Xã (ward_name)',
                    hintText: 'Phường Vĩnh Phúc, Xã...',
                    controller: _wardNameController,
                    prefixIcon: const Icon(Icons.signpost_outlined, size: 18),
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
                  const SizedBox(height: 20),

                  // Section 5: Lịch sử & Dấu vết hệ thống (Audit Trail)
                  _buildSectionHeader(
                    icon: Icons.history_rounded,
                    title: '5. Thông tin hệ thống (Audit Trail)',
                    badge: 'Chỉ đọc',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildAuditCard(isDark, customer),
                  const SizedBox(height: 24),

                  // Save Button
                  AppButton(
                    text: 'LƯU CẬP NHẬT ĐIỂM BÁN',
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline_rounded,
                    width: double.infinity,
                    height: 50,
                    onPressed: _handleSave,
                  ),
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

  Widget _buildStatusEditRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trạng thái (status)',
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isDense: true,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('🟢 Đang hoạt động (active)'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('🔴 Tạm dừng (inactive)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _status = val);
                        }
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
                      'Phê duyệt (approval_status)',
                      style: AppTypography.labelSmall(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: ['approved', 'pending', 'draft', 'rejected']
                              .contains(_approvalStatus)
                          ? _approvalStatus
                          : 'approved',
                      isDense: true,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('✅ Đã duyệt (approved)'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('⏳ Chờ duyệt (pending)'),
                        ),
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('📝 Bản nháp (draft)'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('❌ Từ chối (rejected)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _approvalStatus = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
                  'Tọa độ GPS không được nhập tay để tránh sai lệch định vị. Nhấn nút bên dưới để lấy vị trí thực tế của thiết bị.',
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

          final colDef = widget.dynamicColumns
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

  Widget _buildAuditCard(bool isDark, CustomerEntity customer) {
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
        children: [
          _buildInfoRow('ID Điểm bán (Khoá chính)', '#${customer.id}', isDark),
          const SizedBox(height: 6),
          _buildInfoRow('Người tạo',
              customer.createdByName ?? 'Hệ thống / MobiWork', isDark),
          const SizedBox(height: 6),
          _buildInfoRow('Ngày tạo', customer.createdAt ?? 'Không rõ', isDark),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildInfoRow(
              'Người sửa gần nhất', customer.updatedByName ?? 'Hệ thống', isDark),
          const SizedBox(height: 6),
          _buildInfoRow(
              'Ngày sửa gần nhất', customer.updatedAt ?? 'Chưa sửa', isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dynamic_form/dynamic_form_builder.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../screens/add_customer_screen.dart';
import '../widgets/erp_links_form_field.dart';
import '../viewmodels/customer_view_model.dart';

/// Màn hình chỉnh sửa thông tin khách hàng / Điểm bán
/// Tuân theo 100% schema biểu mẫu động giống màn Thêm mới (AddCustomerScreen),
/// với dữ liệu của khách hàng hiện tại được điền sẵn (pre-filled).
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
    if (customer.isRejectedApproval) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm bán đã bị từ chối duyệt, không thể chỉnh sửa lại.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return Future.value(false);
    }
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

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final GlobalKey<DynamicFormBuilderState> _formKey = GlobalKey<DynamicFormBuilderState>();
  final Map<String, dynamic> _savedFormData = {};
  late Map<String, dynamic> _initialData;

  /// Người dùng đã bấm "Xác nhận đúng" cho cặp tỉnh/xã đang mang nhãn "suy từ địa chỉ cũ" (#24072).
  bool _geoXacNhan = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initialData = _buildInitialData(widget.customer);
    _savedFormData.addAll(_initialData);
  }

  /// Trích xuất toàn bộ dữ liệu hiện tại của điểm bán để điền sẵn vào các ô biểu mẫu
  Map<String, dynamic> _buildInitialData(CustomerEntity c) {
    final data = <String, dynamic>{};

    // 1. Dữ liệu động từ dynamicFields
    data.addAll(c.dynamicFields);

    // 2. Dữ liệu các trường cố định (fixed fields)
    data['name'] = c.name;
    if (c.customerTypeId != null && c.customerTypeId! > 0) {
      data['customer_type_id'] = c.customerTypeId;
    }
    if (c.customerGroupId != null && c.customerGroupId! > 0) {
      data['customer_group_id'] = c.customerGroupId;
    }
    if (c.regionId != null && c.regionId! > 0) {
      data['region_id'] = c.regionId;
    }

    // Tuyến bán hàng
    if (c.routeIds.isNotEmpty) {
      data['route_ids'] = c.routeIds.first;
      data['route_id'] = c.routeIds.first;
    } else if (c.dynamicFields['route_ids'] != null) {
      final raw = c.dynamicFields['route_ids'];
      if (raw is List && raw.isNotEmpty) {
        data['route_ids'] = int.tryParse(raw.first.toString()) ?? raw.first;
      } else if (raw is num) {
        data['route_ids'] = raw.toInt();
      }
    }

    data['address'] = c.address;
    if (c.provinceName != null && c.provinceName!.isNotEmpty) {
      data['province_name'] = c.provinceName;
    }
    if (c.wardName != null && c.wardName!.isNotEmpty) {
      data['ward_name'] = c.wardName;
    }

    final contactName = c.contactPerson != 'Chưa cập nhật' ? c.contactPerson : '';
    if (contactName.isNotEmpty) {
      data['contact_name'] = contactName;
      data['contact_person'] = contactName;
    }
    if (c.contactTitle != null && c.contactTitle!.isNotEmpty) {
      data['contact_title'] = c.contactTitle;
    }

    final phone = c.phone != 'Chưa có SĐT' ? c.phone : '';
    if (phone.isNotEmpty) {
      data['phone'] = phone;
    }
    if (c.email != null && c.email!.isNotEmpty) {
      data['email'] = c.email;
    }

    // Tọa độ GPS / vị trí điểm bán
    if (c.lat != null && c.lng != null) {
      data['coords'] = {
        'lat': c.lat,
        'lng': c.lng,
        'mock': c.coordsMock ?? false,
        'address': c.address,
      };
      data['lat'] = c.lat;
      data['lng'] = c.lng;
    }

    // Danh sách ảnh điểm bán
    final photos = List<String>.from(c.fullPhotoUrls);
    if (photos.isEmpty && c.photoUrls.isNotEmpty) {
      photos.addAll(c.photoUrls);
    }
    if (photos.isEmpty && c.photoUrl != null && c.photoUrl!.isNotEmpty) {
      photos.add(c.photoUrl!);
    }
    if (photos.isEmpty && c.dynamicFields['photo_urls'] is List) {
      photos.addAll((c.dynamicFields['photo_urls'] as List).map((e) => e.toString()));
    }
    if (photos.isEmpty && c.dynamicFields['photo_url'] != null) {
      photos.add(c.dynamicFields['photo_url'].toString());
    }

    if (photos.isNotEmpty) {
      data['photo_file_id'] = photos;
      data['photo_tokens'] = photos;
      data['photos'] = photos;
    }

    // Ô "Khách hàng ERP" (#24331): mang id điểm bán để ô tự đọc mối nối hiện có từ server; thay đổi = đề xuất chờ duyệt.
    if (c.id > 0) {
      data['erp_links'] = ErpLinksValue(customerId: c.id).toJson();
    }

    return data;
  }

  /// Kiểm tra xem người dùng đã thay đổi dữ liệu nào so với dữ liệu gốc chưa
  bool _hasChanges() {
    final current = _formKey.currentState?.getFormData() ?? _savedFormData;
    for (final entry in current.entries) {
      final key = entry.key;
      final val = entry.value;
      final initialVal = _initialData[key];

      if (val is List && initialVal is List) {
        if (val.length != initialVal.length) return true;
        for (int i = 0; i < val.length; i++) {
          if (val[i].toString() != initialVal[i].toString()) return true;
        }
      } else if (val is Map && initialVal is Map) {
        if (key == 'coords') {
          final lat1 = (val['lat'] as num?)?.toDouble();
          final lng1 = (val['lng'] as num?)?.toDouble();
          final lat2 = (initialVal['lat'] as num?)?.toDouble();
          final lng2 = (initialVal['lng'] as num?)?.toDouble();
          if (lat1 != lat2 || lng1 != lng2) return true;
        } else if (val.toString() != initialVal.toString()) {
          return true;
        }
      } else if (val?.toString().trim() != initialVal?.toString().trim()) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _onWillExit() async {
    if (!_hasChanges()) {
      return true;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rời khỏi màn hình?',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Các thông tin bạn vừa chỉnh sửa chưa được lưu. Nếu thoát ra, các thay đổi sẽ bị mất.',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Ở lại',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rời khỏi'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  void _submitForm() {
    if (_formKey.currentState != null) {
      final isValid = _formKey.currentState!.validate();
      if (isValid) {
        _handleSubmit(_formKey.currentState!.getFormData());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng hoàn thành các trường thông tin bắt buộc (*).'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    if (_isSubmitting) return;

    // 1. Validate Tên điểm bán
    if (formData['name'] == null || formData['name'].toString().trim().isEmpty) {
      _formKey.currentState?.focusField('name');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên điểm bán là bắt buộc.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 2. Validate Khu vực
    if (formData['region_id'] == null || formData['region_id'].toString().trim().isEmpty) {
      _formKey.currentState?.focusField('region_id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn khu vực quản lý (Region).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 3. Chuẩn bị danh sách tuyến
    final userRoutes = ref.read(userAssignedRoutesProvider).valueOrNull ?? [];
    List<int> finalRouteIds = [];
    final rawRouteIds = formData['route_ids'] ?? formData['route_id'];
    if (rawRouteIds is List) {
      finalRouteIds = rawRouteIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    } else if (rawRouteIds != null) {
      final rId = int.tryParse(rawRouteIds.toString());
      if (rId != null) finalRouteIds = [rId];
    }
    if (finalRouteIds.isEmpty && widget.customer.routeIds.isNotEmpty) {
      finalRouteIds = widget.customer.routeIds;
    } else if (finalRouteIds.isEmpty && userRoutes.isNotEmpty) {
      finalRouteIds = [userRoutes.first.id];
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final c = widget.customer;
      final changes = <String, dynamic>{};

      // Tên điểm bán
      final newName = formData['name']?.toString().trim();
      if (newName != null && newName.isNotEmpty && newName != c.name) {
        changes['name'] = newName;
      }

      // Loại khách hàng
      final newTypeId = formData['customer_type_id'] is num
          ? (formData['customer_type_id'] as num).toInt()
          : int.tryParse(formData['customer_type_id']?.toString() ?? '');
      if (newTypeId != null && newTypeId != c.customerTypeId) {
        changes['customer_type_id'] = newTypeId;
      }

      // Nhóm khách hàng
      final newGroupId = formData['customer_group_id'] is num
          ? (formData['customer_group_id'] as num).toInt()
          : int.tryParse(formData['customer_group_id']?.toString() ?? '');
      if (newGroupId != null && newGroupId != c.customerGroupId) {
        changes['customer_group_id'] = newGroupId;
      }

      // Spec 20/10/2026 (§3): Server bỏ qua channel_id, app thôi gửi channel_id
      changes.remove('channel_id');

      // Khu vực
      final newRegionId = formData['region_id'] is num
          ? (formData['region_id'] as num).toInt()
          : int.tryParse(formData['region_id']?.toString() ?? '');
      if (newRegionId != null && newRegionId != c.regionId) {
        changes['region_id'] = newRegionId;
      }

      // Tuyến bán hàng
      if (finalRouteIds.isNotEmpty) {
        final currentRouteId = c.routeIds.isNotEmpty ? c.routeIds.first : null;
        if (currentRouteId == null || finalRouteIds.first != currentRouteId) {
          changes['route_ids'] = finalRouteIds;
        }
      }

      // Tỉnh / Phường
      final newProvince = formData['province_name']?.toString().trim();
      if (newProvince != null && newProvince != (c.provinceName ?? '')) {
        changes['province_name'] = newProvince.isNotEmpty ? newProvince : null;
      }
      final newWard = formData['ward_name']?.toString().trim();
      if (newWard != null && newWard != (c.wardName ?? '')) {
        changes['ward_name'] = newWard.isNotEmpty ? newWard : null;
      }
      // Tỉnh / Xã theo danh mục (#24072): chỉ gửi ô THỰC SỰ đổi (PATCH). Đổi tỉnh thì form đã bỏ xã ⇒ gửi `ward_id: null`.
      int? geoId(dynamic v) => v == null ? null : int.tryParse(v.toString());
      for (final k in const ['province_id', 'ward_id']) {
        if (!formData.containsKey(k)) continue;
        final moi = geoId(formData[k]);
        // Hồ sơ "suy từ địa chỉ cũ" mà người dùng đã bấm "Xác nhận đúng": gửi cả khi không đổi ⇒ server gỡ nhãn. Không bấm thì
        // chỉ gửi khi ĐỔI — sửa số điện thoại không được coi là đã soát tỉnh/xã.
        if (moi != geoId(c.dynamicFields[k]) || (_geoXacNhan && c.dynamicFields['geo_source'] == 'inferred')) changes[k] = moi;
      }

      // Thông tin liên hệ
      final newContactName = (formData['contact_name'] ?? formData['contact_person'])?.toString().trim();
      final oldContact = c.contactPerson == 'Chưa cập nhật' ? '' : c.contactPerson;
      if (newContactName != null && newContactName != oldContact) {
        changes['contact_name'] = newContactName.isNotEmpty ? newContactName : null;
      }
      final newContactTitle = formData['contact_title']?.toString().trim();
      if (newContactTitle != null && newContactTitle != (c.contactTitle ?? '')) {
        changes['contact_title'] = newContactTitle.isNotEmpty ? newContactTitle : null;
      }

      // SĐT
      final newPhone = formData['phone']?.toString().trim();
      final oldPhone = c.phone == 'Chưa có SĐT' ? '' : c.phone;
      if (newPhone != null && newPhone != oldPhone) {
        changes['phone'] = newPhone.isNotEmpty ? newPhone : null;
      }

      // Email
      final newEmail = formData['email']?.toString().trim();
      if (newEmail != null && newEmail != (c.email ?? '')) {
        changes['email'] = newEmail.isNotEmpty ? newEmail : null;
      }

      // Địa chỉ
      final newAddress = formData['address']?.toString().trim();
      if (newAddress != null && newAddress.isNotEmpty && newAddress != c.address) {
        changes['address'] = newAddress;
      }

      // Toạ độ GPS (coords: {lat, lng, mock}) theo spec 15/10/2026
      final rawCoords = formData['coords'];
      if (rawCoords is Map) {
        final newLat = (rawCoords['lat'] as num?)?.toDouble() ?? double.tryParse(rawCoords['lat']?.toString() ?? '');
        final newLng = (rawCoords['lng'] as num?)?.toDouble() ?? double.tryParse(rawCoords['lng']?.toString() ?? '');
        final newMock = rawCoords['mock'] as bool? ?? false;
        final newAcc = (rawCoords['accuracy'] as num?)?.toDouble() ?? double.tryParse(rawCoords['accuracy']?.toString() ?? '');

        if (newLat != null && newLng != null) {
          final hasCoordChange = c.lat == null ||
              c.lng == null ||
              (c.lat! - newLat).abs() > 0.000001 ||
              (c.lng! - newLng).abs() > 0.000001;
          if (hasCoordChange) {
            changes['coords'] = {
              'lat': double.parse(newLat.toStringAsFixed(7)),
              'lng': double.parse(newLng.toStringAsFixed(7)),
              if (newAcc != null) 'accuracy': double.parse(newAcc.toStringAsFixed(1)),
              'mock': newMock,
            };
          }
        }
      } else if (rawCoords == null && c.lat != null) {
        changes['coords'] = null;
      }

      // Hình ảnh điểm bán (photo_tokens)
      final currentPhotos = (formData['photo_file_id'] ?? formData['photos'] ?? formData['photo_tokens']) as List? ?? [];
      final initialPhotos = _initialData['photo_file_id'] as List? ?? [];
      bool photosChanged = currentPhotos.length != initialPhotos.length;
      if (!photosChanged) {
        for (int i = 0; i < currentPhotos.length; i++) {
          if (currentPhotos[i].toString() != initialPhotos[i].toString()) {
            photosChanged = true;
            break;
          }
        }
      }

      if (photosChanged) {
        final tokens = <String>[];
        for (final p in currentPhotos) {
          final pTrim = p.toString().trim();
          if (pTrim.isEmpty) continue;
          if (pTrim.length == 32 && !pTrim.contains('/') && !pTrim.contains(r'\')) {
            tokens.add(pTrim);
          } else if (pTrim.startsWith('/crm/customer-photos/public/')) {
            tokens.add(pTrim.replaceFirst('/crm/customer-photos/public/', ''));
          } else if (pTrim.contains('/crm/customer-photos/public/')) {
            final idx = pTrim.indexOf('/crm/customer-photos/public/');
            tokens.add(pTrim.substring(idx + '/crm/customer-photos/public/'.length));
          } else {
            // Local file -> upload lên server để lấy token
            try {
              final uploadRes = await repo.uploadCustomerPhoto(pTrim);
              if (uploadRes['token'] != null) {
                tokens.add(uploadRes['token'].toString());
              } else {
                tokens.add(pTrim);
              }
            } catch (e) {
              tokens.add(pTrim);
            }
          }
        }
        changes['photo_tokens'] = tokens;
      }

      // Các trường động (dynamic fields) gửi trong 'data'
      const fixedKeys = {
        'name', 'customer_type_id', 'customer_group_id', 'channel_id', 'region_id',
        'route_ids', 'route_id', 'address', 'delivery_address', 'province_name', 'ward_name',
        'contact_name', 'contact_person', 'contact_title', 'phone', 'email', 'coords', 'lat', 'lng',
        'photo_file_id', 'photos', 'photo_tokens', 'code', 'id', 'status', 'is_active',
        'province_id', 'ward_id', 'geo_source', 'erp_links',
      };
      final dynamicChanges = <String, dynamic>{};
      for (final entry in formData.entries) {
        if (fixedKeys.contains(entry.key)) continue;
        final key = entry.key;
        final newVal = entry.value;
        final oldVal = c.dynamicFields[key];
        if (newVal != oldVal) {
          dynamicChanges[key] = newVal;
        }
      }
      if (dynamicChanges.isNotEmpty) {
        changes['data'] = dynamicChanges;
      }

      // Ô "Khách hàng ERP" (#24331): mỗi thay đổi (thêm / đổi vai / gỡ) thành một đề xuất chờ duyệt — server ghi khi lưu.
      final oErp = ErpLinksValue.fromJson(formData['erp_links']);
      if (oErp.hasChanges) {
        changes['erp_link_changes'] = oErp.editChanges();
      }

      if (changes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có thay đổi nào được thực hiện.')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Thực thi lưu
      if (widget.onSave != null) {
        await widget.onSave!(changes);
      } else {
        await ref.read(customerViewModelProvider.notifier).updateCustomer(c.id, changes);
      }

      // Làm mới dữ liệu
      ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
      ref.read(routeViewModelProvider.notifier).loadRouteDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Cập nhật thông tin điểm bán thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schemaAsync = ref.watch(customerFormSchemaProvider);
    final meta = widget.meta.customerTypes.isNotEmpty
        ? widget.meta
        : (ref.watch(customerMetaProvider).valueOrNull ?? widget.meta);
    final c = widget.customer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillExit();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
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
            // Nút đồng bộ lại schema bọc box đẹp mắt
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.sync_rounded,
                      size: 20,
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 20,
                    tooltip: 'Làm mới cấu hình form',
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              AppLoading(size: 24),
                              SizedBox(width: 8),
                              Text('Đang đồng bộ...'),
                            ],
                          ),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      try {
                        final repo = ref.read(customerRepositoryProvider);
                        await Future.wait([
                          repo.getCustomerFormSchema(forceRefresh: true),
                          repo.getCustomerMeta(forceRefresh: true),
                        ]);
                      } catch (_) {}
                      ref.invalidate(customerFormSchemaProvider);
                      ref.invalidate(customerMetaProvider);
                      ref.invalidate(userAssignedRoutesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Đồng bộ cấu hình thành công!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF10B981),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              height: 1,
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: schemaAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppLoading(size: 220),
                  SizedBox(height: 16),
                  Text('Đang tải cấu hình form điểm bán...'),
                ],
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Không thể tải cấu hình form từ hệ thống',
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      text: 'Thử lại',
                      icon: Icons.refresh_rounded,
                      onPressed: () async {
                        try {
                          final repo = ref.read(customerRepositoryProvider);
                          await Future.wait([
                            repo.getCustomerFormSchema(forceRefresh: true),
                            repo.getCustomerMeta(forceRefresh: true),
                          ]);
                        } catch (_) {}
                        ref.invalidate(customerFormSchemaProvider);
                        ref.invalidate(customerMetaProvider);
                        ref.invalidate(userAssignedRoutesProvider);
                      },
                    ),
                  ],
                ),
              ),
            ),
            data: (schemaData) {
              // Tuyến bán hàng từ GET /dms/routes/mine hoặc danh sách tuyến
              final userRoutes = ref.watch(userAssignedRoutesProvider).valueOrNull ?? [];
              // Chỉ lấy 2 trường cần — theo dõi trọn state Tuyến (2.000 điểm bán, đổi theo GPS/lọc/tải ngầm) làm cả form
              // (DynamicFormBuilder) dựng lại liên tục khi đang nhập.
              final currentRouteState = ref.watch(
                routeViewModelProvider.select((s) => (availableRoutes: s.availableRoutes, selectedRoute: s.selectedRoute)),
              );

              final List<DynamicFormOption> dynamicRouteOptions;
              if (userRoutes.isNotEmpty) {
                dynamicRouteOptions = userRoutes
                    .map((r) => DynamicFormOption(
                          label: r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}'),
                          value: r.id,
                        ))
                    .toList();
              } else {
                final validRoutes = currentRouteState.availableRoutes
                    .where((r) => r != 'Tất cả tuyến' && !CustomerEntity.isInvalidOrProvinceRoute(r))
                    .toList();
                if (validRoutes.isNotEmpty) {
                  int tempId = 1;
                  dynamicRouteOptions = validRoutes.map((r) => DynamicFormOption(label: r, value: tempId++)).toList();
                } else {
                  dynamicRouteOptions = [const DynamicFormOption(label: 'Chưa phân tuyến', value: 0)];
                }
              }

              // Đảm bảo tuyến hiện tại của điểm bán luôn xuất hiện trong danh sách lựa chọn
              final customerRouteName = c.route.isNotEmpty && c.route != 'Tất cả tuyến'
                  ? c.route
                  : (c.routes.isNotEmpty ? c.routes.first : null);
              final customerRouteId = c.routeIds.isNotEmpty ? c.routeIds.first : null;
              if (customerRouteName != null && customerRouteName.isNotEmpty) {
                final exists = dynamicRouteOptions.any((opt) =>
                    (customerRouteId != null && opt.value == customerRouteId) ||
                    opt.label.toLowerCase().trim() == customerRouteName.toLowerCase().trim());
                if (!exists) {
                  dynamicRouteOptions.insert(
                    0,
                    DynamicFormOption(
                      label: customerRouteName,
                      value: customerRouteId ?? 99999,
                    ),
                  );
                }
              }

              // Cùng bộ ô với màn Thêm mới — đúng Cấu hình trường điểm bán, không đắp khoá dữ liệu thành ô.
              final fields = buildCustomerFormFields(
                schemaData,
                meta: meta,
                routeOptions: dynamicRouteOptions,
                editing: c,
              )
                  // Điểm bán TẠO ngoại tuyến chưa đồng bộ (id ≤ 0): khách ERP đã chọn lúc tạo đi kèm lượt tạo trong hàng đợi —
                  // ẩn ô, sửa ở đây không có đường ghi (#24331).
                  .where((f) => f.code != 'erp_links' || c.id > 0)
                  // Ô "Khách hàng ERP" chỉ bắt buộc khi TẠO — điểm bán cũ sửa việc khác không bị ép nối (chốt 27/10/2026).
                  .map((f) => f.code == 'erp_links' ? f.copyWith(isRequired: false) : f)
                  .toList();

              if (fields.isEmpty) {
                return const Center(
                  child: Text('Không có trường dữ liệu nào trong cấu hình form.'),
                );
              }

              return SafeArea(
                child: Column(
                  children: [
                    // Main Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tip nhập liệu giọng nói
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.primaryContainer.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : AppColors.primaryContainer.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.mic_rounded,
                                    size: 20,
                                    color: isDark ? AppColors.primaryFixed : AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Nhập liệu giọng nói: Nhấn & giữ biểu tượng 🎙️ ở mỗi ô để nói, thả tay để hoàn tất.',
                                      style: AppTypography.bodySmall(
                                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Tỉnh/xã của hồ sơ này SUY từ địa chỉ cũ (#24072) — nhắc nhân viên đang đứng tại điểm bán soát lại.
                            if (widget.customer.dynamicFields['geo_source'] == 'inferred')
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.roundedMd,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _geoXacNhan
                                            ? 'Đã xác nhận tỉnh/thành, xã/phường — bấm Lưu để gỡ nhãn.'
                                            : 'Tỉnh/thành, xã/phường của điểm bán này được SUY từ địa chỉ cũ — hãy kiểm tra, chọn lại nếu chưa đúng hoặc bấm "Xác nhận đúng".',
                                        style: AppTypography.bodySmall(
                                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (!_geoXacNhan)
                                      TextButton(
                                        onPressed: () => setState(() => _geoXacNhan = true),
                                        child: const Text('Xác nhận đúng'),
                                      ),
                                  ],
                                ),
                              ),

                            // Dynamic form builder với dữ liệu đã điền sẵn
                            DynamicFormBuilder(
                              key: _formKey,
                              fields: fields,
                              keepFieldOrder: true,
                              initialData: _savedFormData,
                              onChanged: (data) {
                                _savedFormData.addAll(data);
                              },
                              onSubmit: _handleSubmit,
                              customFieldBuilders: {'erp_links': erpLinksFieldBuilder},
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Fixed Action Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                            width: 0.8,
                          ),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0a000000),
                            offset: Offset(0, -4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        final canLeave = await _onWillExit();
                                        if (canLeave && context.mounted) {
                                          Navigator.of(context).pop(false);
                                        }
                                      },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                                ),
                                child: const Text('HỦY BỎ'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppButton(
                              text: 'CẬP NHẬT THÔNG TIN ĐIỂM BÁN',
                              isLoading: _isSubmitting,
                              icon: Icons.check_circle_outline_rounded,
                              height: 46,
                              onPressed: _isSubmitting ? null : _submitForm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

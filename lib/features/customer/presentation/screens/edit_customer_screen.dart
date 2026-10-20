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
    if (c.channelId != null && c.channelId! > 0) {
      data['channel_id'] = c.channelId;
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

    return data;
  }

  bool _isCustomerPhotoKey(String key) {
    final k = key.toLowerCase();
    const nonPhotoKeys = {
      'route_ids',
      'route_id',
      'customer_type_id',
      'channel_id',
      'region_id',
      'sale_group_id',
      'id',
      'code',
      'status',
      'lat',
      'lng',
      'data',
      'customer_type_name',
      'channel_name',
      'region_name',
      'route',
      'route_name',
      'type',
      'name',
      'phone',
      'email',
      'address',
      'tax_code',
      'notes',
      'description',
      'contact_name',
      'contact_title',
      'birthday',
      'delivery_address',
      'province_name',
      'ward_name',
    };
    if (nonPhotoKeys.contains(k)) return false;
    return k.contains('photo') || k.contains('image') || k.contains('anh_') || k.contains('hinh_');
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
              final fieldsJson = schemaData['data']?['fields'] as List? ?? [];
              final fields = fieldsJson
                  .map((f) => DynamicFormField.fromJson(f as Map<String, dynamic>))
                  .where((f) {
                    final code = f.code.toLowerCase();
                    final label = f.label.toLowerCase();
                    if (code == 'code' || code == 'id') return false;
                    if (code == 'status' || code == 'is_active') return false;
                    if (label.contains('hoạt động') || label.contains('ngừng hoạt động')) return false;
                    return true;
                  })
                  .toList();

              // Tuyến bán hàng từ GET /dms/routes/mine hoặc danh sách tuyến
              final userRoutes = ref.watch(userAssignedRoutesProvider).valueOrNull ?? [];
              final currentRouteState = ref.watch(routeViewModelProvider);

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

              // Spec 20/10/2026 (§3): Loại bỏ ô chọn Kênh cũ (channel_id / crm_channel)
              fields.removeWhere((f) => f.code == 'channel_id' || f.code == 'crm_channel');

              // Cập nhật options cho các trường phân loại
              for (var i = 0; i < fields.length; i++) {
                final f = fields[i];
                if (f.code == 'customer_type_id') {
                  final opts = f.options.isEmpty && meta.customerTypes.isNotEmpty
                      ? meta.customerTypes
                          .map((t) => DynamicFormOption(label: t.name.isNotEmpty ? t.name : t.code, value: t.id))
                          .toList()
                      : List<DynamicFormOption>.from(f.options);
                  // Đảm bảo loại khách hàng hiện tại có trong options
                  if (c.customerTypeId != null && !opts.any((o) => o.value == c.customerTypeId)) {
                    opts.insert(0, DynamicFormOption(label: c.type.isNotEmpty ? c.type : 'Loại ${c.customerTypeId}', value: c.customerTypeId!));
                  }
                  fields[i] = f.copyWith(options: opts);
                } else if (f.code == 'region_id') {
                  final opts = f.options.isEmpty && meta.regions.isNotEmpty
                      ? meta.regions
                          .map((r) => DynamicFormOption(label: '${r.code} - ${r.name}', value: r.id))
                          .toList()
                      : List<DynamicFormOption>.from(f.options);
                  if (c.regionId != null && !opts.any((o) => o.value == c.regionId)) {
                    opts.insert(0, DynamicFormOption(label: c.regionName ?? 'Khu vực ${c.regionId}', value: c.regionId!));
                  }
                  fields[i] = f.copyWith(options: opts);
                } else if (f.code == 'route_ids' || f.code == 'route_id') {
                  fields[i] = f.copyWith(
                    options: dynamicRouteOptions,
                    catalog: 'dropdown',
                  );
                }
              }

              // Tự động chèn customer_type_id nếu schema thiếu
              if (!fields.any((f) => f.code == 'customer_type_id')) {
                final typeOptions = meta.customerTypes.isNotEmpty
                    ? meta.customerTypes
                        .map((t) => DynamicFormOption(label: t.name.isNotEmpty ? t.name : t.code, value: t.id))
                        .toList()
                    : [const DynamicFormOption(label: 'Đại lý', value: 1)];
                if (c.customerTypeId != null && !typeOptions.any((o) => o.value == c.customerTypeId)) {
                  typeOptions.insert(0, DynamicFormOption(label: c.type.isNotEmpty ? c.type : 'Loại ${c.customerTypeId}', value: c.customerTypeId!));
                }
                final insertIdx = fields.indexWhere((f) => f.code == 'name');
                fields.insert(
                  insertIdx != -1 ? insertIdx + 1 : 0,
                  DynamicFormField(
                    code: 'customer_type_id',
                    label: 'Loại điểm bán',
                    type: DynamicFormFieldType.singleChoice,
                    isRequired: true,
                    options: typeOptions,
                    placeholder: 'Chọn loại điểm bán...',
                    section: 'Thông tin chung',
                  ),
                );
              }

              // Tự động chèn region_id nếu schema thiếu
              if (!fields.any((f) => f.code == 'region_id')) {
                final regionOptions = meta.regions.isNotEmpty
                    ? meta.regions
                        .map((r) => DynamicFormOption(label: '${r.code} - ${r.name}', value: r.id))
                        .toList()
                    : [const DynamicFormOption(label: '08 - Miền Trung', value: 8)];
                if (c.regionId != null && !regionOptions.any((o) => o.value == c.regionId)) {
                  regionOptions.insert(0, DynamicFormOption(label: c.regionName ?? 'Khu vực ${c.regionId}', value: c.regionId!));
                }
                final insertIdx = fields.indexWhere((f) => f.code == 'customer_type_id');
                fields.insert(
                  insertIdx != -1 ? insertIdx + 1 : 1,
                  DynamicFormField(
                    code: 'region_id',
                    label: 'Khu vực quản lý',
                    type: DynamicFormFieldType.singleChoice,
                    isRequired: true,
                    options: regionOptions,
                    placeholder: 'Chọn khu vực quản lý...',
                    section: 'Thông tin chung',
                  ),
                );
              }

              // Tự động chèn route_ids nếu schema thiếu
              if (!fields.any((f) => f.code == 'route_ids' || f.code == 'route_id')) {
                final insertIdx = fields.indexWhere((f) => f.code == 'region_id');
                fields.insert(
                  insertIdx != -1 ? insertIdx + 1 : 1,
                  DynamicFormField(
                    code: 'route_ids',
                    label: 'Tuyến bán hàng',
                    type: DynamicFormFieldType.singleChoice,
                    isRequired: true,
                    options: dynamicRouteOptions,
                    placeholder: 'Chọn tuyến bán hàng...',
                    section: 'Thông tin chung',
                    catalog: 'dropdown',
                  ),
                );
              }

              // Đảm bảo có trường ảnh photo_file_id (giới hạn 10 ảnh)
              if (!fields.any((f) => f.code == 'photo_file_id' || f.code == 'photo')) {
                fields.add(
                  const DynamicFormField(
                    code: 'photo_file_id',
                    label: 'Ảnh điểm bán',
                    type: DynamicFormFieldType.photo,
                    maxPhotos: 10,
                    isRequired: true,
                    allowGallery: false,
                    helperText: 'Chụp tối đa 10 ảnh thực tế điểm bán từ máy ảnh',
                    section: 'Hình ảnh điểm bán',
                  ),
                );
              } else {
                final photoIdx = fields.indexWhere((f) => f.code == 'photo_file_id' || f.code == 'photo');
                if (photoIdx != -1) {
                  final existing = fields[photoIdx];
                  fields[photoIdx] = existing.copyWith(
                    isRequired: true,
                    type: DynamicFormFieldType.photo,
                    allowGallery: false,
                    maxPhotos: existing.maxPhotos < 10 ? 10 : existing.maxPhotos,
                    label: existing.label.isEmpty ? 'Ảnh điểm bán' : existing.label,
                    helperText: existing.helperText?.replaceAll('hoặc tải lên ', '') ??
                        'Chụp tối đa 10 ảnh thực tế điểm bán từ máy ảnh',
                    section: existing.section == null || existing.section!.isEmpty
                        ? 'Hình ảnh điểm bán'
                        : existing.section,
                  );
                }
              }

              // Cấu hình các trường ảnh
              for (int i = 0; i < fields.length; i++) {
                if (fields[i].type == DynamicFormFieldType.photo || _isCustomerPhotoKey(fields[i].code)) {
                  fields[i] = fields[i].copyWith(
                    type: DynamicFormFieldType.photo,
                    allowGallery: false,
                    helperText: fields[i].helperText?.replaceAll('hoặc tải lên ', '') ??
                        'Chụp tối đa ${fields[i].maxPhotos} ảnh thực tế điểm bán từ máy ảnh',
                  );
                }
              }

              // Đảm bảo có ô cứng coords (Toạ độ GPS) theo spec 15/10/2026
              if (!fields.any((f) => f.code == 'coords')) {
                fields.removeWhere((f) => f.code == 'lat' || f.code == 'lng');
                final insertIdx = fields.indexWhere((f) => f.code == 'address');
                fields.insert(
                  insertIdx != -1 ? insertIdx + 1 : fields.length,
                  const DynamicFormField(
                    code: 'coords',
                    label: 'Vị trí điểm bán trên bản đồ',
                    type: DynamicFormFieldType.location,
                    isRequired: true,
                    section: 'Vị trí trên bản đồ',
                  ),
                );
              } else {
                final coordsIdx = fields.indexWhere((f) => f.code == 'coords');
                if (coordsIdx != -1) {
                  fields[coordsIdx] = fields[coordsIdx].copyWith(
                    label: 'Vị trí điểm bán trên bản đồ',
                    section: 'Vị trí trên bản đồ',
                    isRequired: true,
                  );
                }
              }

              // Bổ sung các trường thông tin mở rộng từ meta.dynamicColumns nếu schema chưa có
              if (meta.dynamicColumns.isNotEmpty) {
                for (final col in meta.dynamicColumns) {
                  final colCode = col.code.toLowerCase().trim();
                  if (colCode == 'region_name' ||
                      colCode == 'status' ||
                      colCode == 'is_active' ||
                      colCode == 'code' ||
                      colCode == 'id') {
                    continue;
                  }
                  final exists = fields.any((f) =>
                      f.code.toLowerCase() == colCode ||
                      (col.legacyKey != null && f.code.toLowerCase() == col.legacyKey!.toLowerCase()) ||
                      f.code.toLowerCase() == 'mw_$colCode' ||
                      f.code.toLowerCase().replaceFirst('mw_', '') == colCode.replaceFirst('mw_', ''));
                  if (!exists) {
                    final isSelect = col.inputType == 'select';
                    fields.add(
                      DynamicFormField(
                        code: col.code,
                        label: col.label,
                        type: DynamicFormFieldType.fromString(col.inputType),
                        isRequired: col.required,
                        isReadOnly: col.readOnly,
                        badge: isSelect ? 'Danh sách chọn' : null,
                        options: col.options,
                        placeholder: isSelect ? '(Chưa chọn)' : null,
                        section: 'Thông tin mở rộng (Động)',
                      ),
                    );
                  }
                }
              }

              // Bổ sung các trường thông tin mở rộng từ customer.dynamicFields nếu schema chưa có
              for (final entry in c.dynamicFields.entries) {
                final rawKey = entry.key;
                final lower = rawKey.toLowerCase().trim();
                if (lower == 'routes' ||
                    lower == 'route_ids' ||
                    lower == 'photo_url' ||
                    lower == 'photo_urls' ||
                    lower == 'photos' ||
                    lower == 'region_name' ||
                    lower == 'status' ||
                    lower == 'is_active' ||
                    lower == 'code' ||
                    lower == 'id' ||
                    lower == 'lat' ||
                    lower == 'lng' ||
                    lower == 'coords') {
                  continue;
                }

                final exists = fields.any((f) =>
                    f.code.toLowerCase() == lower ||
                    f.code.toLowerCase() == 'mw_$lower' ||
                    f.code.toLowerCase().replaceFirst('mw_', '') == lower.replaceFirst('mw_', ''));
                if (exists) continue;

                final val = entry.value?.toString() ?? '';
                final isSelect = lower.startsWith('nhan_') ||
                    lower == 'khach_hang_vthm' ||
                    lower.contains('_select') ||
                    lower.contains('_choice');

                String label = rawKey;
                if (lower == 'khach_hang_vthm') {
                  label = 'Khách hàng VTHM';
                } else if (lower.startsWith('nhan_')) {
                  final numPart = rawKey.substring(5);
                  label = 'Nhãn $numPart';
                } else if (lower.startsWith('mw_')) {
                  label = rawKey.substring(3);
                }

                if (isSelect) {
                  final opts = <DynamicFormOption>[];
                  if (val.isNotEmpty) {
                    opts.add(DynamicFormOption(label: val, value: val));
                  }
                  if (lower == 'khach_hang_vthm' && !opts.any((o) => o.value == '1 - KH VTHM')) {
                    opts.add(const DynamicFormOption(label: '1 - KH VTHM', value: '1 - KH VTHM'));
                  }
                  if (lower == 'nhan_3' && !opts.any((o) => o.value == 'Maximos')) {
                    opts.add(const DynamicFormOption(label: 'Maximos', value: 'Maximos'));
                  }

                  fields.add(
                    DynamicFormField(
                      code: rawKey,
                      label: label,
                      type: DynamicFormFieldType.singleChoice,
                      isRequired: false,
                      badge: 'Danh sách chọn',
                      options: opts,
                      placeholder: '(Chưa chọn)',
                      section: 'Thông tin mở rộng (Động)',
                    ),
                  );
                } else {
                  fields.add(
                    DynamicFormField(
                      code: rawKey,
                      label: label,
                      type: DynamicFormFieldType.text,
                      isRequired: false,
                      section: 'Thông tin mở rộng (Động)',
                    ),
                  );
                }
              }

              // Đảm bảo có các trường cốt lõi nếu schema trả về rỗng (offline hoặc mock)
              if (!fields.any((f) => f.code == 'name')) {
                fields.insert(
                  0,
                  const DynamicFormField(
                    code: 'name',
                    label: 'Tên điểm bán',
                    type: DynamicFormFieldType.text,
                    isRequired: true,
                    section: 'Thông tin chung',
                  ),
                );
              }
              if (!fields.any((f) => f.code == 'address')) {
                final insertIdx = fields.indexWhere((f) => f.code == 'route_ids');
                fields.insert(
                  insertIdx != -1 ? insertIdx + 1 : fields.length,
                  const DynamicFormField(
                    code: 'address',
                    label: 'Địa chỉ giao dịch',
                    type: DynamicFormFieldType.text,
                    isRequired: false,
                    section: 'Địa chỉ & Liên hệ',
                  ),
                );
              }

              // Bỏ các text/badge '(Bắt buộc)' trong nhãn
              for (int i = 0; i < fields.length; i++) {
                final cleaned = fields[i].label
                    .replaceAll(RegExp(r'\s*\((?:bắt buộc|Bắt buộc|Region\s*-\s*bắt buộc để sinh mã)\)', caseSensitive: false), '')
                    .replaceAll(RegExp(r'\s*-\s*bắt buộc\b', caseSensitive: false), '')
                    .trim();
                fields[i] = fields[i].copyWith(label: cleaned);
              }

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

                            // Dynamic form builder với dữ liệu đã điền sẵn
                            DynamicFormBuilder(
                              key: _formKey,
                              fields: fields,
                              initialData: _savedFormData,
                              onChanged: (data) {
                                _savedFormData.addAll(data);
                              },
                              onSubmit: _handleSubmit,
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

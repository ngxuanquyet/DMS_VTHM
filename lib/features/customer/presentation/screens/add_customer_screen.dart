import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dynamic_form/dynamic_form_builder.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../../../route/domain/entities/route_entity.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';

/// Provider lấy schema form khách hàng từ API (hoặc cache)
final customerFormSchemaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomerFormSchema(forceRefresh: false);
});

/// Provider lấy danh mục meta (khu vực, loại khách hàng, kênh...)
final customerMetaProvider = FutureProvider.autoDispose<CustomerMetaData>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomerMeta(forceRefresh: false);
});

/// Provider lấy danh sách tuyến của chính nhân viên đăng nhập (GET /dms/routes/mine)
final userAssignedRoutesProvider = FutureProvider.autoDispose<List<UserRouteEntity>>((ref) async {
  final apiService = ref.watch(routeApiServiceProvider);
  final routes = await apiService.getMyRoutes();
  if (routes.isNotEmpty) {
    return routes;
  }

  // Fallback: Lấy các tuyến thực tế từ danh sách khách hàng của chính user
  final customerRepo = ref.watch(customerRepositoryProvider);
  final customers = await customerRepo.getCustomers();
  final routeNames = <String>{};
  for (final c in customers) {
    if (c.route.trim().isNotEmpty && c.route.trim() != 'Tất cả tuyến') {
      routeNames.add(c.route.trim());
    }
  }

  if (routeNames.isNotEmpty) {
    int idCounter = 1;
    return routeNames.map((name) => UserRouteEntity(id: idCounter++, name: name)).toList();
  }

  return [];
});

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final GlobalKey<DynamicFormBuilderState> _formKey = GlobalKey<DynamicFormBuilderState>();
  final Map<String, dynamic> _savedFormData = {};
  bool _isSubmitting = false;

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

  bool _hasUserInput() {
    if (_formKey.currentState != null) {
      final data = _formKey.currentState!.getFormData();
      for (final entry in data.entries) {
        if (entry.key == 'route_ids' || entry.key == 'route_id') continue;
        final val = entry.value;
        if (val == null) continue;
        if (val is String && val.trim().isNotEmpty) return true;
        if (val is List && val.isNotEmpty) return true;
      }
    }
    for (final entry in _savedFormData.entries) {
      if (entry.key == 'route_ids' || entry.key == 'route_id') continue;
      final val = entry.value;
      if (val == null) continue;
      if (val is String && val.trim().isNotEmpty) return true;
      if (val is List && val.isNotEmpty) return true;
    }
    return false;
  }

  Future<bool> _onWillExit() async {
    if (!_hasUserInput()) {
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
          'Dữ liệu điểm bán bạn đang nhập chưa được lưu. Nếu thoát ra, các thông tin đã nhập sẽ bị mất.',
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

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    if (formData['name'] == null || formData['name'].toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên điểm bán là bắt buộc.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final isOnline = ref.read(connectivityProvider).isOnline;
      
      // Chuẩn bị payload dữ liệu submit
      final payload = Map<String, dynamic>.from(formData);
      
      // 🔴 Tuyệt đối không gửi 'code', 'id' và 'status' theo spec 22/09/2026:
      // Server tự động sinh mã theo region_id và đặt trạng thái mặc định active
      payload.remove('code');
      payload.remove('id');
      payload.remove('status');

      final userRoutes = ref.read(userAssignedRoutesProvider).valueOrNull ?? [];

      // 🔴 route_ids là mảng số nguyên [int] - bắt buộc cho nhân viên thị trường
      List<int> finalRouteIds = [];
      final rawRouteIds = payload['route_ids'] ?? payload['route_id'];
      if (rawRouteIds is List) {
        finalRouteIds = rawRouteIds
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      } else if (rawRouteIds != null) {
        final rId = int.tryParse(rawRouteIds.toString());
        if (rId != null) finalRouteIds = [rId];
      }
      if (finalRouteIds.isEmpty) {
        final fallbackRouteId = userRoutes.firstOrNull?.id ?? 5;
        finalRouteIds = [fallbackRouteId];
      }
      payload['route_ids'] = finalRouteIds;

      // 🔴 Upload ảnh lên /crm/customer-photos lấy token khi có mạng (spec mục 2, 3)
      // CHỈ xử lý các trường ảnh, TUYỆT ĐỐI không xử lý route_ids hoặc các trường dữ liệu khác
      if (isOnline) {
        for (final key in payload.keys.toList()) {
          if (!_isCustomerPhotoKey(key)) continue;

          final val = payload[key];
          if (val is List) {
            final tokens = <String>[];
            for (final item in val) {
              final itemStr = item.toString().trim();
              if (itemStr.isNotEmpty) {
                if (itemStr.length == 32 && !itemStr.contains('/') && !itemStr.contains(r'\')) {
                  tokens.add(itemStr);
                } else {
                  try {
                    final uploadRes = await repo.uploadCustomerPhoto(itemStr);
                    if (uploadRes['token'] != null) {
                      tokens.add(uploadRes['token'].toString());
                    } else {
                      tokens.add(itemStr);
                    }
                  } catch (_) {
                    tokens.add(itemStr);
                  }
                }
              }
            }
            if (key == 'photo' || key == 'photo_file_id' || key == 'photo_token') {
              payload['photo_tokens'] = tokens;
              if (tokens.isNotEmpty) {
                payload['photo_token'] = tokens.first;
              }
              payload.remove('photo_file_id');
              payload.remove('photo');
            } else {
              payload[key] = tokens;
            }
          } else if (val is String && val.trim().isNotEmpty) {
            final valStr = val.trim();
            if (valStr.length == 32 && !valStr.contains('/') && !valStr.contains(r'\')) {
              // Đã là token 32-hex
              if (key == 'photo' || key == 'photo_file_id' || key == 'photo_token') {
                payload['photo_tokens'] = [valStr];
                payload['photo_token'] = valStr;
                payload.remove('photo_file_id');
                payload.remove('photo');
              } else {
                payload[key] = [valStr];
              }
            } else if (valStr.endsWith('.jpg') || valStr.endsWith('.png') || valStr.endsWith('.jpeg') || valStr.contains('/') || valStr.contains(r'\')) {
              try {
                final uploadRes = await repo.uploadCustomerPhoto(valStr);
                if (uploadRes['token'] != null) {
                  final token = uploadRes['token'].toString();
                  if (key == 'photo' || key == 'photo_file_id' || key == 'photo_token') {
                    payload['photo_tokens'] = [token];
                    payload['photo_token'] = token;
                    payload.remove('photo_file_id');
                    payload.remove('photo');
                  } else {
                    payload[key] = [token];
                  }
                }
              } catch (_) {
                if (key == 'photo' || key == 'photo_file_id' || key == 'photo_token') {
                  payload['photo_tokens'] = [valStr];
                  payload['photo_token'] = valStr;
                  payload.remove('photo_file_id');
                  payload.remove('photo');
                } else {
                  payload[key] = [valStr];
                }
              }
            }
          }
        }
      }

      // 🔴 Bổ sung tên loại khách hàng, kênh, khu vực để SQLite hiển thị ngay lập tức kể cả khi offline
      final meta = ref.read(customerMetaProvider).valueOrNull ?? kDefaultCustomerMeta;
      if (payload['customer_type_id'] != null) {
        final selectedTypeId = int.tryParse(payload['customer_type_id'].toString());
        if (selectedTypeId != null) {
          final match = meta.customerTypes.where((t) => t.id == selectedTypeId).firstOrNull;
          if (match != null) {
            final typeName = match.name.isNotEmpty ? match.name : match.code;
            payload['customer_type_name'] = typeName;
            payload['type'] = typeName;
          }
        }
      }

      if (payload['channel_id'] != null) {
        final selectedChannelId = int.tryParse(payload['channel_id'].toString());
        if (selectedChannelId != null) {
          final match = meta.channels.where((c) => c.id == selectedChannelId).firstOrNull;
          if (match != null) {
            payload['channel_name'] = match.name.isNotEmpty ? match.name : match.code;
          }
        }
      }

      if (payload['region_id'] != null) {
        final selectedRegionId = int.tryParse(payload['region_id'].toString());
        if (selectedRegionId != null) {
          final match = meta.regions.where((r) => r.id == selectedRegionId).firstOrNull;
          if (match != null) {
            payload['region_name'] = match.name.isNotEmpty ? match.name : match.code;
          }
        }
      }

      // 🔴 Bổ sung route và route_name từ tuyến được chọn để SQLite và danh sách KH hiển thị chính xác
      final selectedRouteId = finalRouteIds.firstOrNull;
      if (selectedRouteId != null) {
        final match = userRoutes.where((r) => r.id == selectedRouteId).firstOrNull;
        if (match != null) {
          payload['route'] = match.name;
          payload['route_name'] = match.name;
        }
      }

      await repo.createCustomer(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Đã lưu điểm bán! Đang đồng bộ lên hệ thống...'
                        : 'Đã lưu trên máy! Điểm bán sẽ tự động đồng bộ khi có mạng.',
                  ),
                ),
              ],
            ),
            backgroundColor: isOnline ? AppColors.primary : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh danh sách khách hàng ở màn hình chính
        ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm điểm bán: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    final meta = ref.watch(customerMetaProvider).valueOrNull ?? kDefaultCustomerMeta;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _onWillExit();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _onWillExit();
              if (canLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thêm mới điểm bán',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            schemaAsync.maybeWhen(
              data: (schemaData) {
                final formName = schemaData['data']?['form']?['name']?.toString() ?? 'Hồ sơ điểm bán';
                final version = schemaData['data']?['version']?.toString() ?? '';
                return Text(
                  '$formName ${version.isNotEmpty ? "• v.$version" : ""}',
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ).copyWith(fontSize: 11),
                );
              },
              orElse: () => Text(
                'Đang tải cấu hình biểu mẫu...',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại cấu hình form',
            onPressed: () => ref.invalidate(customerFormSchemaProvider),
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
      body: schemaAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoading(size: 220),
              SizedBox(height: 16),
              Text('Đang tải cấu hình trường nhập liệu động...'),
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
                  onPressed: () => ref.invalidate(customerFormSchemaProvider),
                ),
              ],
            ),
          ),
        ),
        data: (schemaData) {
          final fieldsJson = schemaData['data']?['fields'] as List? ?? [];
          // 🔴 Loại bỏ các trường:
          // - code, id: do hệ thống tự sinh
          // - status, is_active: điểm bán mới luôn mặc định là active (hoạt động), không cần người dùng nhập
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

          // 🔴 Lấy danh sách tuyến thực tế của user (GET /dms/routes/mine)
          final userRoutes = ref.watch(userAssignedRoutesProvider).valueOrNull ?? [];
          final currentRouteState = ref.watch(routeViewModelProvider);

          // Tạo options cho tuyến bán hàng từ tuyến thực tế của nhân viên (GET /dms/routes/mine)
          final List<DynamicFormOption> dynamicRouteOptions = userRoutes.isNotEmpty
              ? userRoutes.map((r) => DynamicFormOption(
                  label: r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}'),
                  value: r.id,
                )).toList()
              : [
                  const DynamicFormOption(label: 'Vũ Tùng Dương - T2', value: 5),
                  const DynamicFormOption(label: 'Vũ Tùng Dương - T3', value: 7),
                ];

          // Xác định tuyến mặc định: ưu tiên tuyến đang chọn ở màn Tuyến bán hàng
          int? defaultRouteId;
          if (currentRouteState.selectedRoute.isNotEmpty &&
              currentRouteState.selectedRoute != 'Tất cả tuyến') {
            final matched = userRoutes.where((r) =>
                r.name.toLowerCase().trim() == currentRouteState.selectedRoute.toLowerCase().trim() ||
                (r.code != null && r.code!.toLowerCase().trim() == currentRouteState.selectedRoute.toLowerCase().trim())
            ).firstOrNull;
            if (matched != null) {
              defaultRouteId = matched.id;
            }
          }
          defaultRouteId ??= userRoutes.firstOrNull?.id ?? (dynamicRouteOptions.firstOrNull?.value as int? ?? 5);

          // Cập nhật options cho các trường phân loại nếu schema chưa có options.
          // Để trống toàn bộ (initialValue = null) để người dùng chủ động lựa chọn.
          for (var i = 0; i < fields.length; i++) {
            final f = fields[i];
            if (f.code == 'customer_type_id') {
              fields[i] = f.copyWith(
                options: f.options.isEmpty && meta.customerTypes.isNotEmpty
                    ? meta.customerTypes.map((t) => DynamicFormOption(label: t.name.isNotEmpty ? t.name : t.code, value: t.id)).toList()
                    : f.options,
                clearInitialValue: true,
              );
            } else if (f.code == 'channel_id') {
              fields[i] = f.copyWith(
                options: f.options.isEmpty && meta.channels.isNotEmpty
                    ? meta.channels.map((c) => DynamicFormOption(label: c.name.isNotEmpty ? c.name : c.code, value: c.id)).toList()
                    : f.options,
                clearInitialValue: true,
              );
            } else if (f.code == 'region_id') {
              fields[i] = f.copyWith(
                options: f.options.isEmpty && meta.regions.isNotEmpty
                    ? meta.regions.map((r) => DynamicFormOption(label: '${r.code} - ${r.name}', value: r.id)).toList()
                    : f.options,
                clearInitialValue: true,
              );
            } else if (f.code == 'route_ids' || f.code == 'route_id') {
              fields[i] = f.copyWith(
                options: dynamicRouteOptions,
                initialValue: defaultRouteId,
                catalog: 'dropdown',
              );
            }
          }

          // Tự động chèn customer_type_id nếu schema thiếu (mặc định để trống)
          if (!fields.any((f) => f.code == 'customer_type_id')) {
            final typeOptions = meta.customerTypes.isNotEmpty
                ? meta.customerTypes.map((t) => DynamicFormOption(label: t.name.isNotEmpty ? t.name : t.code, value: t.id)).toList()
                : [const DynamicFormOption(label: 'Đại lý', value: 1)];

            final insertIdx = fields.indexWhere((f) => f.code == 'name');
            fields.insert(
              insertIdx != -1 ? insertIdx + 1 : 0,
              DynamicFormField(
                code: 'customer_type_id',
                label: 'Loại điểm bán',
                type: DynamicFormFieldType.singleChoice,
                isRequired: true,
                options: typeOptions,
                initialValue: null,
                placeholder: 'Chọn loại điểm bán...',
                section: 'Thông tin chung',
              ),
            );
          }

          // Tự động chèn channel_id nếu schema thiếu (mặc định để trống)
          if (!fields.any((f) => f.code == 'channel_id')) {
            final channelOptions = meta.channels.isNotEmpty
                ? meta.channels.map((c) => DynamicFormOption(label: c.name.isNotEmpty ? c.name : c.code, value: c.id)).toList()
                : [const DynamicFormOption(label: 'GT (Truyền thống)', value: 1)];

            final insertIdx = fields.indexWhere((f) => f.code == 'customer_type_id');
            fields.insert(
              insertIdx != -1 ? insertIdx + 1 : 1,
              DynamicFormField(
                code: 'channel_id',
                label: 'Kênh bán hàng',
                type: DynamicFormFieldType.singleChoice,
                isRequired: false,
                options: channelOptions,
                initialValue: null,
                placeholder: 'Chọn kênh bán hàng...',
                section: 'Thông tin chung',
              ),
            );
          }

          // 🔴 Bắt buộc theo API POST /crm/customers: region_id để backend sinh mã KH (4 số khu vực + 4 số thứ tự)
          if (!fields.any((f) => f.code == 'region_id')) {
            final regionOptions = meta.regions.isNotEmpty
                ? meta.regions.map((r) => DynamicFormOption(label: '${r.code} - ${r.name}', value: r.id)).toList()
                : [const DynamicFormOption(label: '08 - Miền Trung', value: 8)];

            final insertIdx = fields.indexWhere((f) => f.code == 'channel_id');
            fields.insert(
              insertIdx != -1 ? insertIdx + 1 : 1,
              DynamicFormField(
                code: 'region_id',
                label: 'Khu vực (Region - bắt buộc để sinh mã)',
                type: DynamicFormFieldType.singleChoice,
                isRequired: true,
                options: regionOptions,
                initialValue: null,
                placeholder: 'Chọn khu vực quản lý...',
                section: 'Thông tin chung',
              ),
            );
          }

          // 🔴 Bắt buộc theo API spec 22/09/2026: route_ids (mảng tuyến bán hàng cho nhân viên thị trường từ GET /dms/routes/mine)
          if (!fields.any((f) => f.code == 'route_ids' || f.code == 'route_id')) {
            final insertIdx = fields.indexWhere((f) => f.code == 'region_id');
            fields.insert(
              insertIdx != -1 ? insertIdx + 1 : 1,
              DynamicFormField(
                code: 'route_ids',
                label: 'Tuyến bán hàng (Bắt buộc)',
                type: DynamicFormFieldType.singleChoice,
                isRequired: true,
                options: dynamicRouteOptions,
                initialValue: defaultRouteId,
                placeholder: 'Chọn tuyến bán hàng...',
                section: 'Thông tin chung',
                catalog: 'dropdown',
              ),
            );
          }

          // 🔴 Đảm bảo có trường ảnh photo_file_id với giới hạn 10 ảnh theo đúng API thực tế
          if (!fields.any((f) => f.code == 'photo_file_id' || f.code == 'photo')) {
            fields.add(
              const DynamicFormField(
                code: 'photo_file_id',
                label: 'Ảnh điểm bán',
                type: DynamicFormFieldType.photo,
                maxPhotos: 10,
                isRequired: false,
                helperText: 'Chụp hoặc tải lên tối đa 10 ảnh thực tế điểm bán',
                section: 'Hình ảnh điểm bán',
              ),
            );
          } else {
            final photoIdx = fields.indexWhere((f) => f.code == 'photo_file_id' || f.code == 'photo');
            if (photoIdx != -1) {
              final existing = fields[photoIdx];
              fields[photoIdx] = existing.copyWith(
                type: DynamicFormFieldType.photo,
                maxPhotos: existing.maxPhotos < 10 ? 10 : existing.maxPhotos,
                label: existing.label.isEmpty ? 'Ảnh điểm bán' : existing.label,
                helperText: existing.helperText ?? 'Chụp hoặc tải lên tối đa 10 ảnh thực tế điểm bán',
                section: existing.section == null || existing.section!.isEmpty
                    ? 'Hình ảnh điểm bán'
                    : existing.section,
              );
            }
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
                        // Voice dictation tip banner
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

                        // Form fields
                        DynamicFormBuilder(
                          key: _formKey,
                          fields: fields,
                          initialData: {
                            'route_ids': defaultRouteId,
                            ..._savedFormData,
                          },
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
                        width: 1,
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
                                      Navigator.of(context).pop();
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
                          text: 'LƯU ĐIỂM BÁN',
                          isLoading: _isSubmitting,
                          icon: Icons.check_circle_outline_rounded,
                          height: 46,
                          onPressed: () {
                            if (_formKey.currentState != null &&
                                _formKey.currentState!.validate()) {
                              _handleSubmit(_formKey.currentState!.getFormData());
                            }
                          },
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
  );
  }
}

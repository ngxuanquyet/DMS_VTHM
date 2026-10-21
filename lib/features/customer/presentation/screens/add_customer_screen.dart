import 'dart:convert';
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
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../../../route/domain/entities/route_entity.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';

/// Provider lấy schema form khách hàng (dùng chung màn thêm / sửa điểm bán + hộp sửa nhanh).
/// Hiện bản cache NGAY (app phải chạy offline, mạng chậm không treo màn), rồi khi có mạng tải bản
/// mới từ server; khác bản cache thì phát lại để form dựng theo cấu hình mới (admin vừa bật chọn
/// nhiều, thêm/bỏ ô…). DynamicFormBuilder giữ dữ liệu đã gõ khi danh sách ô đổi (didUpdateWidget).
/// autoDispose ⇒ mỗi lần MỞ màn là chạy lại một lượt.
final customerFormSchemaProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final repo = ref.watch(customerRepositoryProvider);
  final cached = await repo.getCustomerFormSchema(forceRefresh: false);
  yield cached;

  if (!ref.read(connectivityProvider).isOnline) return;
  // forceRefresh lỗi mạng thì repo tự trả lại bản cache ⇒ so khớp, không phát lại.
  // Nuốt mọi lỗi còn lại: đã có bản cache đang hiện, không được đẩy màn sang trạng thái lỗi.
  try {
    final fresh = await repo.getCustomerFormSchema(forceRefresh: true);
    if (jsonEncode(fresh) != jsonEncode(cached)) {
      yield fresh;
    }
  } catch (_) {}
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
    if (c.route.trim().isNotEmpty &&
        c.route.trim() != 'Tất cả tuyến' &&
        !CustomerEntity.isInvalidOrProvinceRoute(c.route, provinceName: c.provinceName)) {
      final parts = c.route.split(',').map((e) => e.trim());
      for (final p in parts) {
        if (!CustomerEntity.isInvalidOrProvinceRoute(p, provinceName: c.provinceName)) {
          routeNames.add(p);
        }
      }
    }
    for (final r in c.routes) {
      if (r.trim().isNotEmpty &&
          r.trim() != 'Tất cả tuyến' &&
          !CustomerEntity.isInvalidOrProvinceRoute(r, provinceName: c.provinceName)) {
        routeNames.add(r.trim());
      }
    }
  }

  if (routeNames.isNotEmpty) {
    int idCounter = 1;
    return routeNames.map((name) => UserRouteEntity(id: idCounter++, name: name, code: name)).toList();
  }

  return [];
});

/// Hai ô Kênh / Tuyến tự khai cho màn TẠO điểm bán (chốt 21/10/2026) — dựng từ `meta.createChoices`.
///
/// Là ô CỨNG ở Cấu hình trường điểm bán: nhãn / bắt buộc lấy từ dòng cùng mã trong `schema` (server gửi khi app xin
/// `with_scope`); `schema` không có dòng nào (admin ẩn, hoặc server cũ) ⇒ không vẽ ô đó.
///
/// Lựa chọn bó trong cặp phòng người đăng nhập (`pairs` NULL ⇒ toàn quyền, mọi mục danh mục; cặp tuyến NULL = "toàn
/// kênh" ⇒ mọi tuyến); server kiểm lại đúng luật đó (`CustomerScopeService::fitsDepartment()`). Điền sẵn giá trị
/// server sẽ tự gán khi để trống. Không có lựa chọn nào (server cũ, phòng chưa gắn kênh) ⇒ không vẽ ô — server tự gán.
List<DynamicFormField> ownChannelTerritoryFields(CustomerMetaData meta, {required List<DynamicFormField> schema}) {
  final cauHinh = {for (final f in schema) f.code: f};
  final kenhCH = cauHinh['own_channel_ids'];
  final tuyenCH = cauHinh['territory_code'];
  if (kenhCH == null && tuyenCH == null) return const [];
  final choices = meta.createChoices;
  if (choices == null || meta.salesChannels.isEmpty) return const [];
  final pairs = choices.pairs;
  if (pairs != null && pairs.isEmpty) return const [];

  final channelIds = pairs?.map((p) => p.channelId).toSet();
  final channels = meta.salesChannels.where((c) => channelIds == null || channelIds.contains(c.id)).toList();
  final allTerritories = pairs == null || pairs.any((p) => p.territoryCode == null);
  final territoryCodes = pairs?.map((p) => p.territoryCode).whereType<String>().toSet() ?? <String>{};
  final territories = allTerritories
      ? meta.territories
      : meta.territories.where((t) => territoryCodes.contains(t.code)).toList();

  final defaultChannels = choices.defaultChannelIds.where((id) => channels.any((c) => c.id == id)).toList();
  return [
    if (kenhCH != null && channels.isNotEmpty)
      DynamicFormField(
        code: 'own_channel_ids',
        label: kenhCH.label.isNotEmpty ? kenhCH.label : 'Kênh',
        type: DynamicFormFieldType.multipleChoice,
        isRequired: kenhCH.isRequired,
        options: channels.map((c) => DynamicFormOption(label: '${c.code} - ${c.name}', value: c.id)).toList(),
        initialValue: defaultChannels,
        helperText: 'Mặc định theo phòng của bạn — chọn lại nếu điểm bán thuộc kênh khác của phòng.',
        section: 'Thông tin chung',
      ),
    if (tuyenCH != null && territories.isNotEmpty)
      DynamicFormField(
        code: 'territory_code',
        label: tuyenCH.label.isNotEmpty ? tuyenCH.label : 'Tuyến',
        type: DynamicFormFieldType.singleChoice,
        isRequired: tuyenCH.isRequired,
        options: territories
            .map((t) => DynamicFormOption(label: t.name.isNotEmpty ? '${t.code} - ${t.name}' : t.code, value: t.code))
            .toList(),
        initialValue: choices.defaultTerritoryCode != null && territories.any((t) => t.code == choices.defaultTerritoryCode)
            ? choices.defaultTerritoryCode
            : null,
        placeholder: 'Chọn tuyến...',
        section: 'Thông tin chung',
        catalog: 'dropdown',
      ),
  ];
}

/// Gán MỤC theo Cấu hình trường điểm bán, giữ nguyên thứ tự: ô `heading` (mã trong [headingCodes]) mở một mục cho mọi ô
/// sau nó và không vẽ thành ô; ô đứng trước tiêu đề đầu tiên thuộc mục chung "Thông tin điểm bán".
List<DynamicFormField> sectionsFromConfig(List<DynamicFormField> fields, Set<String?> headingCodes) {
  var muc = 'Thông tin điểm bán';
  final out = <DynamicFormField>[];
  for (final f in fields) {
    if (headingCodes.contains(f.code)) {
      muc = f.label.isNotEmpty ? f.label : muc;
      continue;
    }
    out.add(f.copyWith(section: muc));
  }
  return out;
}

/// Cấu hình mặc định của hai ô (Kênh bắt buộc, Tuyến không; nhãn gốc) cho [ownChannelTerritoryFields] — dùng khi schema
/// không mang cờ `scope_fields`, hoặc khi chỉ cần giá trị điền sẵn (bước 3b).
const List<DynamicFormField> kScopeFieldStubs = [
  DynamicFormField(code: 'own_channel_ids', label: '', type: DynamicFormFieldType.multipleChoice, isRequired: true),
  DynamicFormField(code: 'territory_code', label: '', type: DynamicFormFieldType.singleChoice),
];

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
    if (_isSubmitting) return;

    // 1. Validate Tên điểm bán (§5)
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

    // 2. Validate Khu vực (§5)
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

    // 3. Validate Tuyến bán hàng (§5: route_ids bắt buộc với nhân viên thị trường)
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
    if (finalRouteIds.isEmpty && userRoutes.isNotEmpty) {
      finalRouteIds = [userRoutes.first.id];
    }
    if (finalRouteIds.isEmpty) {
      _formKey.currentState?.focusField('route_ids');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn ít nhất một tuyến bán hàng cho điểm bán mới.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 3b. Kênh + Tuyến tự khai phải là một bộ trong phạm vi phòng (server kiểm lại; lệch thì 403 — mục ngoại tuyến lệch
    // thì server về mặc định) — báo ngay tại ô thay vì để server từ chối. Giữ nguyên giá trị điền sẵn ⇒ KHÔNG gửi, server tự
    // gán mặc định (danh sách kênh điền sẵn đã lọc theo danh mục đang dùng nên có thể ít hơn bộ mặc định của server).
    var boGuiKenhTuyen = false;
    final meta3b = ref.read(customerMetaProvider).valueOrNull;
    final createChoices = meta3b?.createChoices;
    if (createChoices != null && formData['own_channel_ids'] is List) {
      final kenh = (formData['own_channel_ids'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toSet();
      final tuyen = formData['territory_code']?.toString().trim() ?? '';
      // Giá trị ĐIỀN SẴN (không phụ thuộc admin ẩn ô nào) — dựng như thể cả hai ô đều có mặt.
      final dienSan = ownChannelTerritoryFields(meta3b!, schema: kScopeFieldStubs);
      final kenhSan = dienSan.where((f) => f.code == 'own_channel_ids').firstOrNull?.initialValue;
      final tuyenSan = dienSan.where((f) => f.code == 'territory_code').firstOrNull?.initialValue?.toString() ?? '';
      final giuNguyen = kenhSan is List &&
          kenh.length == kenhSan.length &&
          kenh.containsAll(kenhSan.cast<int>()) &&
          (tuyen.isEmpty || tuyen == tuyenSan);
      if (giuNguyen) {
        boGuiKenhTuyen = true;
      } else if (kenh.isNotEmpty && !createChoices.allows(kenh.toList(), tuyen)) {
        _formKey.currentState?.focusField('territory_code');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kênh và tuyến đã chọn không thuộc phạm vi phòng của bạn — hãy chọn tuyến khớp với kênh.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // 4. Validate Ảnh điểm bán (§5: Bắt buộc chụp ảnh trước khi lưu)
    bool hasPhoto = false;
    for (final key in formData.keys) {
      if (_isCustomerPhotoKey(key)) {
        final val = formData[key];
        if (val is List && val.isNotEmpty) {
          hasPhoto = true;
          break;
        } else if (val is String && val.trim().isNotEmpty) {
          hasPhoto = true;
          break;
        }
      }
    }
    if (!hasPhoto) {
      _formKey.currentState?.focusField('photo_file_id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh điểm bán trước khi lưu.'),
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
      if (boGuiKenhTuyen) {
        payload.remove('own_channel_ids');
        payload.remove('territory_code');
      }
      
      // 🔴 Tuyệt đối không gửi 'code', 'id' và 'status' theo spec 22/09 & 30/09:
      // Server tự động sinh mã theo region_id và đặt trạng thái mặc định active
      payload.remove('code');
      payload.remove('id');
      payload.remove('status');

      payload['route_ids'] = finalRouteIds;

      // 🔴 Theo spec 15/10/2026: Tránh gửi CẢ coords lẫn lat/lng phẳng gây lỗi 422
      if (payload['coords'] != null) {
        payload.remove('lat');
        payload.remove('lng');
      }

      // 🔴 Upload ảnh lên /crm/customer-photos lấy token khi có mạng (spec mục 2, 3, 6)
      if (isOnline) {
        final photoLat = payload['coords'] is Map
            ? (payload['coords']['lat'] as num?)?.toDouble()
            : (payload['lat'] is num ? (payload['lat'] as num).toDouble() : null);
        final photoLng = payload['coords'] is Map
            ? (payload['coords']['lng'] as num?)?.toDouble()
            : (payload['lng'] is num ? (payload['lng'] as num).toDouble() : null);

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
                    final uploadRes = await repo.uploadCustomerPhoto(
                      itemStr,
                      locationName: payload['name']?.toString() ?? 'Điểm bán mới',
                      lat: photoLat,
                      lng: photoLng,
                    );
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
                final uploadRes = await repo.uploadCustomerPhoto(
                  valStr,
                  locationName: payload['name']?.toString() ?? 'Điểm bán mới',
                  lat: photoLat,
                  lng: photoLng,
                );
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
      } else {
        // 🔴 Khi offline: Gom toàn bộ ảnh vào photo_tokens và photo_token để chuẩn bị lưu SQLite & sync_queue
        final List<String> offlinePhotos = [];
        for (final key in payload.keys.toList()) {
          if (!_isCustomerPhotoKey(key)) continue;
          final val = payload[key];
          if (val is List) {
            for (final item in val) {
              final s = item.toString().trim();
              if (s.isNotEmpty && !offlinePhotos.contains(s)) offlinePhotos.add(s);
            }
          } else if (val is String && val.trim().isNotEmpty) {
            final s = val.trim();
            if (!offlinePhotos.contains(s)) offlinePhotos.add(s);
          }
        }
        if (offlinePhotos.isNotEmpty) {
          payload['photo_tokens'] = offlinePhotos;
          payload['photo_token'] = offlinePhotos.first;
          payload['photo_file_id'] = offlinePhotos;
          payload['photo'] = offlinePhotos.first;
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

      // Spec 20/10/2026 (§3): Bỏ qua channel_id, app không gửi trường này
      payload.remove('channel_id');
      payload.remove('crm_channel');

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

      await ref.read(customerViewModelProvider.notifier).createCustomer(payload);

      if (isOnline) {
        // Đồng bộ ngay lập tức lên server khi đang online để người dùng có mã và trạng thái đồng bộ ngay
        try {
          await ref.read(syncServiceProvider).syncQueue(force: true);
        } catch (_) {}
      }

      if (mounted) {
        // Làm mới danh sách tuyến và khách hàng trong nền
        ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);

        final pendingCount = await ref.read(appDatabaseProvider).countPendingSync();
        if (!mounted) return;
        final hasPending = pendingCount > 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !hasPending ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(addCustomerSuccessMessage(hasPending: hasPending)),
                ),
              ],
            ),
            backgroundColor: !hasPending ? AppColors.primary : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // 🔴 Nghiệp vụ 21/10/2026: tạo điểm bán mới = server tự ghi MỘT lượt viếng thăm đã đóng
        // (visit_kind = new_outlet) ⇒ KHÔNG mở màn check-in cho điểm bán vừa tạo, về màn trước như lưu thường.
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
                    Icons.refresh_rounded,
                    size: 20,
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: 'Tải lại cấu hình form',
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
                              Text('Đồng bộ thành công!'),
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

          // Tạo options cho tuyến bán hàng từ tuyến thực tế của nhân viên (GET /dms/routes/mine hoặc SQLite)
          final List<DynamicFormOption> dynamicRouteOptions;
          if (userRoutes.isNotEmpty) {
            dynamicRouteOptions = userRoutes.map((r) => DynamicFormOption(
              label: r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}'),
              value: r.id,
            )).toList();
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
          defaultRouteId ??= userRoutes.firstOrNull?.id ?? (dynamicRouteOptions.firstOrNull?.value as int? ?? 0);

          // Spec 20/10/2026 (§3): Loại bỏ ô chọn Kênh cũ (channel_id / crm_channel)
          fields.removeWhere((f) => f.code == 'channel_id' || f.code == 'crm_channel');

          // #23819: ô Kênh/Tuyến bật "tự điền theo phòng ban" — server gửi `default` tính cho chính người đang đăng nhập.
          // Chỉ màn TẠO mới điền sẵn (nhân viên vẫn sửa được); dữ liệu đã gõ (`_savedFormData`) vẫn thắng vì
          // DynamicFormBuilder ưu tiên `initialData` hơn `initialValue`.
          for (var i = 0; i < fields.length; i++) {
            final f = fields[i];
            if (f.defaultValue != null && f.initialValue == null) {
              fields[i] = f.copyWith(initialValue: f.defaultValue);
            }
          }

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

          // 🔴 Bắt buộc theo API POST /crm/customers: region_id để backend sinh mã KH (4 số khu vực + 4 số thứ tự)
          if (!fields.any((f) => f.code == 'region_id')) {
            final regionOptions = meta.regions.isNotEmpty
                ? meta.regions.map((r) => DynamicFormOption(label: '${r.code} - ${r.name}', value: r.id)).toList()
                : [const DynamicFormOption(label: '08 - Miền Trung', value: 8)];

            final insertIdx = fields.indexWhere((f) => f.code == 'customer_type_id');
            fields.insert(
              insertIdx != -1 ? insertIdx + 1 : 1,
              DynamicFormField(
                code: 'region_id',
                label: 'Khu vực quản lý',
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
                label: 'Tuyến bán hàng',
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

          // Kênh + Tuyến tự khai (chốt 21/10/2026): ô cứng ở Cấu hình trường điểm bán — nhãn / bắt buộc / ẩn và VỊ TRÍ
          // theo schema (`scope_fields` bật ⇒ vắng ô = admin ẩn); schema không mang cờ (server cũ, bản lưu máy cũ, bộ mặc
          // định ngoại tuyến) ⇒ vẽ cả hai ngay sau ô Tuyến bán hàng như trước. Lựa chọn + điền sẵn theo cặp phòng.
          final theoCauHinh = schemaData['data']?['scope_fields'] == true;
          final scopeFields = ownChannelTerritoryFields(meta, schema: theoCauHinh ? fields : kScopeFieldStubs);
          // Thay TỪNG ô tại đúng chỗ của nó trong schema (admin có thể đặt Kênh, Tuyến ở hai nơi khác nhau).
          final dungSan = {for (final f in scopeFields) f.code: f};
          final thayTaiCho = <DynamicFormField>[
            for (final f in fields)
              if (f.code != 'own_channel_ids' && f.code != 'territory_code')
                f
              else if (theoCauHinh && dungSan[f.code] != null)
                dungSan[f.code]!,
          ];
          fields
            ..clear()
            ..addAll(thayTaiCho);

          if (!theoCauHinh) {
            final routeIdx = fields.indexWhere((f) => f.code == 'route_ids' || f.code == 'route_id');
            fields.insertAll(routeIdx != -1 ? routeIdx + 1 : fields.length, scopeFields);
          }

          // 🔴 Đảm bảo có trường ảnh photo_file_id với giới hạn 10 ảnh theo đúng API thực tế (§5: Bắt buộc)
          // Ở màn nhập khách hàng: chỉ cho phép chụp ảnh từ camera, không cho chọn từ thư viện
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

          // Cấu hình toàn bộ các trường ảnh ở màn nhập khách hàng: chỉ cho phép chụp từ camera, không cho chọn từ thư viện
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

          // 🔴 Đảm bảo có ô cứng coords (Toạ độ GPS) theo spec 15/10/2026 thay thế cho lat/lng cũ,
          // định dạng giống form sửa điểm bán (EditCustomerScreen)
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

          // 🔴 THỨ TỰ + MỤC theo đúng Cấu hình trường điểm bán (mẫu chuẩn — chủ hệ thống 21/10/2026): không gom ô theo
          // nhóm app tự đặt theo mã ô, không tự thêm ô động ngoài cấu hình. Mục = ô `heading` của cấu hình (mở một mục cho
          // mọi ô sau nó); chưa có tiêu đề nào thì một mục chung. Ô app tự chèn (tuyến bán hàng, kênh/tuyến khi schema
          // cũ, ô dự phòng thiếu) nằm ngay cạnh ô liên quan nên đi theo mục của ô đứng trước.
          final headingCodes = fieldsJson
              .whereType<Map>()
              .where((f) => f['input_type']?.toString() == 'heading')
              .map((f) => f['code']?.toString())
              .toSet();
          final theoMuc = sectionsFromConfig(fields, headingCodes);
          fields
            ..clear()
            ..addAll(theoMuc);

          // 🔴 Bỏ các text/badge '(Bắt buộc)', '(Region - bắt buộc để sinh mã)' trong nhãn vì trường bắt buộc đã có dấu * đỏ
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
                          keepFieldOrder: true,
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
                          onPressed: _isSubmitting
                              ? null
                              : () {
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
  ),
);
  }
}

/// Thông báo sau khi tạo điểm bán (nghiệp vụ 21/10/2026: tạo điểm bán = tính luôn một lượt viếng thăm).
/// Ngoại tuyến thì lượt được ghi khi hàng đợi đồng bộ xong.
String addCustomerSuccessMessage({required bool hasPending}) => hasPending
    ? 'Đã lưu điểm bán ngoại tuyến — lượt viếng thăm sẽ được ghi nhận khi đồng bộ.'
    : 'Đã tạo điểm bán và ghi nhận lượt viếng thăm.';

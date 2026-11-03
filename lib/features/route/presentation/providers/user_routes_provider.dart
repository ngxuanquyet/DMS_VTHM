import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';

/// Provider lấy danh sách tuyến của chính nhân viên đăng nhập (GET /dms/routes/mine)
final userAssignedRoutesProvider = FutureProvider.autoDispose<List<UserRouteEntity>>((ref) async {
  final apiService = ref.watch(routeApiServiceProvider);
  final routes = (await apiService.getMyRoutes()).where((r) => r.id > 0).toList();
  // Không có danh sách tuyến thì trả rỗng — KHÔNG dựng id giả 1, 2, 3… theo tên tuyến của điểm bán: id 1 là một tuyến thật
  // trên prod, chọn vào là gắn nhầm tuyến (#24698 vòng 3, chủ hệ thống chốt 03/11/2026).
  return routes;
});

/// Lựa chọn ô Tuyến bán hàng — CHỈ tuyến thật của nhân viên ([userAssignedRoutesProvider], đã lọc id). Không có ⇒ rỗng,
/// KHÔNG dựng id giả theo tên: id 1, 2, 3… là tuyến thật trên prod (#24698 vòng 3, chủ hệ thống chốt 03/11/2026). Dùng chung
/// Thêm / Sửa.
List<DynamicFormOption> realRouteOptions(List<UserRouteEntity> routes) => routes
    .map((r) => DynamicFormOption(label: r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}'), value: r.id))
    .toList();

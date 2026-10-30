import '../../../../core/network/api_client.dart';
import '../models/material_create_rules.dart';
import '../models/visit_material_model.dart';

/// Gọi API vật tư của lượt viếng thăm (#24522) — hợp đồng `API-VAT-TU-MOBILE-2026-10-30.md`.
class VisitMaterialApiService {
  final ApiClient _apiClient;

  VisitMaterialApiService(this._apiClient);

  /// `GET /dms/visits/{id}/materials` — trả `data` thô (để lưu cache ngoại tuyến) lẫn bản đã đọc.
  Future<(Map<String, dynamic>, VisitMaterialsData)> getMaterials(int visitId) async {
    final response = await _apiClient.get('/dms/visits/$visitId/materials');
    final data = response is Map && response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return (data, VisitMaterialsData.fromJson(data));
  }

  /// `POST /dms/visits/{id}/materials` — lô thao tác; đọc `results[i].ok` từng phần tử.
  Future<MaterialSaveResponse> saveMaterials(int visitId, Map<String, dynamic> body) async {
    final response = await _apiClient.post('/dms/visits/$visitId/materials', data: body);
    return MaterialSaveResponse.fromJson(response);
  }

  /// `GET /dms/material-create-catalog` (GĐ1b #24526) — danh mục + luật "Tạo điểm bán" của chính người dùng.
  Future<(Map<String, dynamic>, MaterialCreateCatalog)> getCreateCatalog() async {
    final response = await _apiClient.get('/dms/material-create-catalog');
    final data = response is Map && response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return (data, MaterialCreateCatalog.fromJson(data));
  }
}

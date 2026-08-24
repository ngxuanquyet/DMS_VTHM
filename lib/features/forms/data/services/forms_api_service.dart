import '../../../../core/network/api_client.dart';
import '../models/form_model.dart';

class FormsApiService {
  final ApiClient _apiClient;

  FormsApiService(this._apiClient);

  Future<List<FormItemModel>> getForms() async {
    final response = await _apiClient.get('/forms');
    final list = response as List<dynamic>;
    return list.map((e) => FormItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

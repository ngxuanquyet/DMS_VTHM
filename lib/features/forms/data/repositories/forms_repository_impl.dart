import '../../domain/entities/form_entity.dart';
import '../../domain/repositories/forms_repository.dart';
import '../services/forms_api_service.dart';

class FormsRepositoryImpl implements FormsRepository {
  final FormsApiService _apiService;

  FormsRepositoryImpl(this._apiService);

  @override
  Future<List<FormItemEntity>> getForms() async {
    final list = await _apiService.getForms();
    return list.map((e) => e.toEntity()).toList();
  }
}

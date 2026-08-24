import '../entities/form_entity.dart';
import '../repositories/forms_repository.dart';

class GetFormsUseCase {
  final FormsRepository _repository;

  GetFormsUseCase(this._repository);

  Future<List<FormItemEntity>> call() {
    return _repository.getForms();
  }
}

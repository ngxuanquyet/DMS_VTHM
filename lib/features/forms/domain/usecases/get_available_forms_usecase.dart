import '../entities/market_form_entity.dart';
import '../repositories/forms_repository.dart';

class GetAvailableFormsUseCase {
  final FormsRepository _repository;

  GetAvailableFormsUseCase(this._repository);

  Future<List<MarketFormConfigEntity>> call({
    required String kind,
    int? customerId,
  }) {
    return _repository.getAvailableForms(
      kind: kind,
      customerId: customerId,
    );
  }
}

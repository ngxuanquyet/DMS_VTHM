import '../entities/market_form_entity.dart';
import '../repositories/forms_repository.dart';

class GetFormsUseCase {
  final FormsRepository _repository;

  GetFormsUseCase(this._repository);

  Future<List<MarketFormConfigEntity>> call({String kind = 'collect', int? customerId}) {
    return _repository.getAvailableForms(kind: kind, customerId: customerId);
  }
}

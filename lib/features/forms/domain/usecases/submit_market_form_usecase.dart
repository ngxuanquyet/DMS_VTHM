import '../../data/models/market_form_submission_model.dart';
import '../repositories/forms_repository.dart';

class SubmitMarketFormUseCase {
  final FormsRepository _repository;

  SubmitMarketFormUseCase(this._repository);

  Future<MarketFormSubmitResult> call(
    MarketFormSubmissionModel submission, {
    bool isOffline = false,
  }) {
    return _repository.submitForm(
      submission,
      isOffline: isOffline,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/forms_repository_impl.dart';
import '../../data/services/forms_api_service.dart';
import '../../domain/repositories/forms_repository.dart';
import '../../domain/usecases/get_available_forms_usecase.dart';
import '../../domain/usecases/submit_market_form_usecase.dart';
import '../states/forms_state.dart';

final formsApiServiceProvider = Provider<FormsApiService>((ref) {
  return FormsApiService(ref.read(apiClientProvider));
});

final formsRepositoryProvider = Provider<FormsRepository>((ref) {
  return FormsRepositoryImpl(
    ref.read(formsApiServiceProvider),
    ref.read(appDatabaseProvider),
  );
});

final getAvailableFormsUseCaseProvider = Provider<GetAvailableFormsUseCase>((ref) {
  return GetAvailableFormsUseCase(ref.read(formsRepositoryProvider));
});

final submitMarketFormUseCaseProvider = Provider<SubmitMarketFormUseCase>((ref) {
  return SubmitMarketFormUseCase(ref.read(formsRepositoryProvider));
});

final formsViewModelProvider =
    StateNotifierProvider.autoDispose<FormsViewModel, FormsState>((ref) {
  return FormsViewModel(
    getAvailableFormsUseCase: ref.read(getAvailableFormsUseCaseProvider),
  );
});

class FormsViewModel extends StateNotifier<FormsState> {
  final GetAvailableFormsUseCase getAvailableFormsUseCase;

  FormsViewModel({
    required this.getAvailableFormsUseCase,
  }) : super(const FormsState()) {
    loadForms();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTabIndex: index);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void markFormSubmitted(int configId) {
    final updated = Set<int>.from(state.submittedConfigIds)..add(configId);
    state = state.copyWith(submittedConfigIds: updated);
  }

  Future<void> loadForms() async {
    state = state.copyWith(status: FormsStatus.loading);
    try {
      // Tải biểu mẫu thu thập thị trường tại menu chính (kind=collect)
      final forms = await getAvailableFormsUseCase(kind: 'collect');
      state = state.copyWith(
        status: FormsStatus.loaded,
        marketForms: forms,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormsStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }
}

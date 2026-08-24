import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/forms_repository_impl.dart';
import '../../data/services/forms_api_service.dart';
import '../../domain/repositories/forms_repository.dart';
import '../../domain/usecases/get_forms_usecase.dart';
import '../states/forms_state.dart';

final formsApiServiceProvider = Provider<FormsApiService>((ref) {
  return FormsApiService(ref.read(apiClientProvider));
});

final formsRepositoryProvider = Provider<FormsRepository>((ref) {
  return FormsRepositoryImpl(ref.read(formsApiServiceProvider));
});

final getFormsUseCaseProvider = Provider<GetFormsUseCase>((ref) {
  return GetFormsUseCase(ref.read(formsRepositoryProvider));
});

final formsViewModelProvider =
    StateNotifierProvider.autoDispose<FormsViewModel, FormsState>((ref) {
  return FormsViewModel(
    getFormsUseCase: ref.read(getFormsUseCaseProvider),
  );
});

class FormsViewModel extends StateNotifier<FormsState> {
  final GetFormsUseCase getFormsUseCase;

  FormsViewModel({
    required this.getFormsUseCase,
  }) : super(const FormsState()) {
    loadForms();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTabIndex: index);
  }

  Future<void> loadForms() async {
    state = state.copyWith(status: FormsStatus.loading);
    try {
      final forms = await getFormsUseCase();
      state = state.copyWith(
        status: FormsStatus.loaded,
        allForms: forms,
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

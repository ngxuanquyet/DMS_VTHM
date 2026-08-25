import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../states/personal_info_state.dart';
import 'profile_view_model.dart';

final getUserProfileDetailUseCaseProvider =
    Provider<GetUserProfileDetailUseCase>((ref) {
  return GetUserProfileDetailUseCase(ref.read(profileRepositoryProvider));
});

final getUserRelationsUseCaseProvider =
    Provider<GetUserRelationsUseCase>((ref) {
  return GetUserRelationsUseCase(ref.read(profileRepositoryProvider));
});

final personalInfoViewModelProvider =
    StateNotifierProvider<PersonalInfoViewModel, PersonalInfoState>((ref) {
  return PersonalInfoViewModel(
    getProfileDetailUseCase: ref.read(getUserProfileDetailUseCaseProvider),
    getUserRelationsUseCase: ref.read(getUserRelationsUseCaseProvider),
  );
});

class PersonalInfoViewModel extends StateNotifier<PersonalInfoState> {
  final GetUserProfileDetailUseCase getProfileDetailUseCase;
  final GetUserRelationsUseCase getUserRelationsUseCase;

  PersonalInfoViewModel({
    required this.getProfileDetailUseCase,
    required this.getUserRelationsUseCase,
  }) : super(const PersonalInfoState()) {
    loadData();
  }

  Future<void> loadData({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = state.copyWith(status: PersonalInfoStatus.loading);
    }

    try {
      final results = await Future.wait([
        getProfileDetailUseCase(),
        getUserRelationsUseCase(),
      ]);

      final profileDetail = results[0];
      final relations = results[1];

      state = state.copyWith(
        status: PersonalInfoStatus.loaded,
        profileDetail: profileDetail as dynamic,
        relations: (relations as List).cast(),
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: state.profileDetail != null
            ? PersonalInfoStatus.loaded
            : PersonalInfoStatus.error,
        isRefreshing: false,
        errorMessage: e
            .toString()
            .replaceAll('AppException: ', '')
            .replaceAll('ServerException: ', ''),
      );
    }
  }
}

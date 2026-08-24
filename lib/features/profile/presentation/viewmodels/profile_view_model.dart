import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../data/services/profile_api_service.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../states/profile_state.dart';

final profileApiServiceProvider = Provider<ProfileApiService>((ref) {
  return ProfileApiService(ref.read(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.read(profileApiServiceProvider));
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.read(profileRepositoryProvider));
});

final updateDarkModeUseCaseProvider = Provider<UpdateDarkModeUseCase>((ref) {
  return UpdateDarkModeUseCase(ref.read(profileRepositoryProvider));
});

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>((ref) {
  return ProfileViewModel(
    getProfileUseCase: ref.read(getProfileUseCaseProvider),
    updateDarkModeUseCase: ref.read(updateDarkModeUseCaseProvider),
  );
});

class ProfileViewModel extends StateNotifier<ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateDarkModeUseCase updateDarkModeUseCase;

  ProfileViewModel({
    required this.getProfileUseCase,
    required this.updateDarkModeUseCase,
  }) : super(const ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      final profile = await getProfileUseCase();
      state = state.copyWith(
        status: ProfileStatus.loaded,
        profile: profile,
        isDarkMode: profile.isDarkMode,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  Future<void> toggleDarkMode(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    await updateDarkModeUseCase(isDark);
  }
}

import '../../domain/entities/user_profile_entity.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState {
  final ProfileStatus status;
  final UserProfileEntity? profile;
  final bool isDarkMode;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.isDarkMode = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserProfileEntity? profile,
    bool? isDarkMode,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      errorMessage: errorMessage,
    );
  }
}

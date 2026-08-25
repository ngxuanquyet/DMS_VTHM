import '../../domain/entities/user_profile_detail_entity.dart';
import '../../domain/entities/user_relation_entity.dart';

enum PersonalInfoStatus { initial, loading, loaded, error }

class PersonalInfoState {
  final PersonalInfoStatus status;
  final UserProfileDetailEntity? profileDetail;
  final List<UserRelationEntity> relations;
  final String? errorMessage;
  final bool isRefreshing;

  const PersonalInfoState({
    this.status = PersonalInfoStatus.initial,
    this.profileDetail,
    this.relations = const [],
    this.errorMessage,
    this.isRefreshing = false,
  });

  PersonalInfoState copyWith({
    PersonalInfoStatus? status,
    UserProfileDetailEntity? profileDetail,
    List<UserRelationEntity>? relations,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return PersonalInfoState(
      status: status ?? this.status,
      profileDetail: profileDetail ?? this.profileDetail,
      relations: relations ?? this.relations,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

import 'dart:io';
import '../../domain/entities/position_declaration_entity.dart';
import '../../domain/entities/position_reason_entity.dart';

enum PositionDeclarationStatus {
  initial,
  loading,
  submitting,
  success,
  error,
}

class PositionDeclarationState {
  final PositionDeclarationStatus status;
  final List<PositionReasonEntity> reasons;
  final PositionReasonEntity? selectedReason;
  final List<File> photos;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? address;
  final bool isFetchingLocation;
  final String? errorMessage;
  final String? successMessage;
  final PositionDeclarationEntity? lastSubmitted;
  final List<PositionDeclarationEntity> history;
  final bool isLoadingHistory;

  const PositionDeclarationState({
    this.status = PositionDeclarationStatus.initial,
    this.reasons = const [],
    this.selectedReason,
    this.photos = const [],
    this.lat,
    this.lng,
    this.accuracyM,
    this.address,
    this.isFetchingLocation = false,
    this.errorMessage,
    this.successMessage,
    this.lastSubmitted,
    this.history = const [],
    this.isLoadingHistory = false,
  });

  bool get canSubmit =>
      selectedReason != null &&
      lat != null &&
      lng != null &&
      status != PositionDeclarationStatus.submitting;

  PositionDeclarationState copyWith({
    PositionDeclarationStatus? status,
    List<PositionReasonEntity>? reasons,
    PositionReasonEntity? selectedReason,
    bool clearSelectedReason = false,
    List<File>? photos,
    double? lat,
    double? lng,
    double? accuracyM,
    String? address,
    bool? isFetchingLocation,
    String? errorMessage,
    String? successMessage,
    PositionDeclarationEntity? lastSubmitted,
    List<PositionDeclarationEntity>? history,
    bool? isLoadingHistory,
  }) {
    return PositionDeclarationState(
      status: status ?? this.status,
      reasons: reasons ?? this.reasons,
      selectedReason:
          clearSelectedReason ? null : (selectedReason ?? this.selectedReason),
      photos: photos ?? this.photos,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      address: address ?? this.address,
      isFetchingLocation: isFetchingLocation ?? this.isFetchingLocation,
      errorMessage: errorMessage,
      successMessage: successMessage,
      lastSubmitted: lastSubmitted ?? this.lastSubmitted,
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }
}

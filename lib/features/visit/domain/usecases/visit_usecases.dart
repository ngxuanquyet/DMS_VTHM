import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/checkin_request_model.dart';
import '../../data/models/checkout_request_model.dart';
import '../../data/repositories/visit_repository_impl.dart';
import '../entities/visit_entity.dart';
import '../entities/visit_photo_entity.dart';
import '../entities/visit_requirements_entity.dart';
import '../repositories/visit_repository.dart';

final getTodayVisitsUseCaseProvider = Provider<GetTodayVisitsUseCase>((ref) {
  return GetTodayVisitsUseCase(ref.watch(visitRepositoryProvider));
});

final checkinUseCaseProvider = Provider<CheckinUseCase>((ref) {
  return CheckinUseCase(ref.watch(visitRepositoryProvider));
});

final getVisitRequirementsUseCaseProvider =
    Provider<GetVisitRequirementsUseCase>((ref) {
  return GetVisitRequirementsUseCase(ref.watch(visitRepositoryProvider));
});

final uploadVisitPhotoUseCaseProvider =
    Provider<UploadVisitPhotoUseCase>((ref) {
  return UploadVisitPhotoUseCase(ref.watch(visitRepositoryProvider));
});

final deleteVisitPhotoUseCaseProvider =
    Provider<DeleteVisitPhotoUseCase>((ref) {
  return DeleteVisitPhotoUseCase(ref.watch(visitRepositoryProvider));
});

final checkoutUseCaseProvider = Provider<CheckoutUseCase>((ref) {
  return CheckoutUseCase(ref.watch(visitRepositoryProvider));
});

final cancelVisitUseCaseProvider = Provider<CancelVisitUseCase>((ref) {
  return CancelVisitUseCase(ref.watch(visitRepositoryProvider));
});

class GetTodayVisitsUseCase {
  final VisitRepository _repository;
  GetTodayVisitsUseCase(this._repository);

  Future<List<VisitEntity>> call() => _repository.getTodayVisits();
}

class CheckinUseCase {
  final VisitRepository _repository;
  CheckinUseCase(this._repository);

  Future<VisitEntity> call(CheckinRequestModel request) =>
      _repository.checkin(request);
}

class GetVisitRequirementsUseCase {
  final VisitRepository _repository;
  GetVisitRequirementsUseCase(this._repository);

  Future<VisitRequirementsEntity> call(int visitId, {String? visitResult}) =>
      _repository.getRequirements(visitId, visitResult: visitResult);
}

class UploadVisitPhotoUseCase {
  final VisitRepository _repository;
  UploadVisitPhotoUseCase(this._repository);

  Future<VisitPhotoEntity> call({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) =>
      _repository.uploadPhoto(
        visitId: visitId,
        file: file,
        photoType: photoType,
        takenAt: takenAt,
        lat: lat,
        lng: lng,
      );
}

class DeleteVisitPhotoUseCase {
  final VisitRepository _repository;
  DeleteVisitPhotoUseCase(this._repository);

  Future<VisitRequirementsEntity> call({
    required int visitId,
    required int photoId,
  }) =>
      _repository.deletePhoto(visitId: visitId, photoId: photoId);
}

class CheckoutUseCase {
  final VisitRepository _repository;
  CheckoutUseCase(this._repository);

  Future<VisitEntity> call({
    required int visitId,
    required CheckoutRequestModel request,
  }) =>
      _repository.checkout(visitId: visitId, request: request);
}

class CancelVisitUseCase {
  final VisitRepository _repository;
  CancelVisitUseCase(this._repository);

  Future<void> call(int visitId) =>
      _repository.cancelVisit(visitId);
}


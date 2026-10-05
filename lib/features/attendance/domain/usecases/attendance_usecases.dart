import 'dart:io';
import '../entities/attendance_entity.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceConfigUseCase {
  final AttendanceRepository _repository;

  GetAttendanceConfigUseCase(this._repository);

  Future<AttendanceConfigEntity> call({double? lat, double? lng}) {
    return _repository.getConfig(lat: lat, lng: lng);
  }
}

class PunchAttendanceUseCase {
  final AttendanceRepository _repository;

  PunchAttendanceUseCase(this._repository);

  Future<AttendancePunchEntity> call({
    required double lat,
    required double lng,
    double? accuracyM,
    bool? isMockLocation,
    String? clientUuid,
  }) {
    return _repository.punch(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      isMockLocation: isMockLocation,
      clientUuid: clientUuid,
    );
  }
}

class UploadPunchPhotoUseCase {
  final AttendanceRepository _repository;

  UploadPunchPhotoUseCase(this._repository);

  Future<AttendancePunchPhotoEntity> call({
    required int punchId,
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) {
    return _repository.uploadPunchPhoto(
      punchId: punchId,
      file: file,
      photoType: photoType,
      takenAt: takenAt,
      lat: lat,
      lng: lng,
    );
  }
}

class GetAttendanceHistoryUseCase {
  final AttendanceRepository _repository;

  GetAttendanceHistoryUseCase(this._repository);

  Future<List<AttendancePunchEntity>> call({int days = 7}) {
    return _repository.getHistory(days: days);
  }
}

class GetAttendanceDetailUseCase {
  final AttendanceRepository _repository;

  GetAttendanceDetailUseCase(this._repository);

  Future<AttendanceDetailEntity> call() {
    return _repository.getAttendanceDetail();
  }
}

class ToggleAttendanceUseCase {
  final AttendanceRepository _repository;

  ToggleAttendanceUseCase(this._repository);

  Future<AttendanceDetailEntity> call() {
    return _repository.toggleAttendanceCheck();
  }
}

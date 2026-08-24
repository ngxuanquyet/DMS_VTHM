import '../entities/attendance_entity.dart';
import '../repositories/attendance_repository.dart';

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

import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../services/attendance_api_service.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceApiService _apiService;
  AttendanceDetailEntity? _cachedEntity;

  AttendanceRepositoryImpl(this._apiService);

  @override
  Future<AttendanceDetailEntity> getAttendanceDetail() async {
    final model = await _apiService.getAttendanceDetail();
    _cachedEntity = model.toEntity();
    return _cachedEntity!;
  }

  @override
  Future<AttendanceDetailEntity> toggleAttendanceCheck() async {
    if (_cachedEntity == null) {
      await getAttendanceDetail();
    }
    final current = _cachedEntity!;
    _cachedEntity = AttendanceDetailEntity(
      isWorking: !current.isWorking,
      currentTime: current.currentTime,
      currentDateFormatted: current.currentDateFormatted,
      checkInTime: current.isWorking ? '--:--' : '07:42',
      workDurationSeconds: current.isWorking ? 0 : current.workDurationSeconds,
      location: current.location,
      monthlyStats: current.monthlyStats,
      history: current.history,
    );
    return _cachedEntity!;
  }
}

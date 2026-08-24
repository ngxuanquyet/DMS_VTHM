import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../data/services/attendance_api_service.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/attendance_usecases.dart';
import '../states/attendance_state.dart';

final attendanceApiServiceProvider = Provider<AttendanceApiService>((ref) {
  return AttendanceApiService(ref.read(apiClientProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(ref.read(attendanceApiServiceProvider));
});

final getAttendanceDetailUseCaseProvider = Provider<GetAttendanceDetailUseCase>((ref) {
  return GetAttendanceDetailUseCase(ref.read(attendanceRepositoryProvider));
});

final toggleAttendanceUseCaseProvider = Provider<ToggleAttendanceUseCase>((ref) {
  return ToggleAttendanceUseCase(ref.read(attendanceRepositoryProvider));
});

final attendanceViewModelProvider =
    StateNotifierProvider.autoDispose<AttendanceViewModel, AttendanceState>((ref) {
  return AttendanceViewModel(
    getAttendanceDetailUseCase: ref.read(getAttendanceDetailUseCaseProvider),
    toggleAttendanceUseCase: ref.read(toggleAttendanceUseCaseProvider),
  );
});

class AttendanceViewModel extends StateNotifier<AttendanceState> {
  final GetAttendanceDetailUseCase getAttendanceDetailUseCase;
  final ToggleAttendanceUseCase toggleAttendanceUseCase;
  Timer? _timer;

  AttendanceViewModel({
    required this.getAttendanceDetailUseCase,
    required this.toggleAttendanceUseCase,
  }) : super(const AttendanceState()) {
    loadAttendance();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);

      final nextDuration = state.detail?.isWorking == true
          ? state.liveWorkDurationSeconds + 1
          : state.liveWorkDurationSeconds;

      state = state.copyWith(
        liveCurrentTime: timeStr,
        liveWorkDurationSeconds: nextDuration,
      );
    });
  }

  Future<void> loadAttendance() async {
    state = state.copyWith(status: AttendanceStatus.loading);
    try {
      final detail = await getAttendanceDetailUseCase();
      state = state.copyWith(
        status: AttendanceStatus.loaded,
        detail: detail,
        liveWorkDurationSeconds: detail.workDurationSeconds,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  Future<void> toggleAttendance() async {
    try {
      final updated = await toggleAttendanceUseCase();
      state = state.copyWith(
        detail: updated,
        liveWorkDurationSeconds: updated.workDurationSeconds,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

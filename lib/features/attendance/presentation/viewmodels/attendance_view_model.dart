import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/usecases/attendance_usecases.dart';
import '../states/attendance_state.dart';

final getAttendanceConfigUseCaseProvider = Provider<GetAttendanceConfigUseCase>((ref) {
  return GetAttendanceConfigUseCase(ref.read(attendanceRepositoryProvider));
});

final punchAttendanceUseCaseProvider = Provider<PunchAttendanceUseCase>((ref) {
  return PunchAttendanceUseCase(ref.read(attendanceRepositoryProvider));
});

final uploadPunchPhotoUseCaseProvider = Provider<UploadPunchPhotoUseCase>((ref) {
  return UploadPunchPhotoUseCase(ref.read(attendanceRepositoryProvider));
});

final getAttendanceHistoryUseCaseProvider = Provider<GetAttendanceHistoryUseCase>((ref) {
  return GetAttendanceHistoryUseCase(ref.read(attendanceRepositoryProvider));
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
    getConfigUseCase: ref.read(getAttendanceConfigUseCaseProvider),
    punchUseCase: ref.read(punchAttendanceUseCaseProvider),
    uploadPhotoUseCase: ref.read(uploadPunchPhotoUseCaseProvider),
    getHistoryUseCase: ref.read(getAttendanceHistoryUseCaseProvider),
    getAttendanceDetailUseCase: ref.read(getAttendanceDetailUseCaseProvider),
    toggleAttendanceUseCase: ref.read(toggleAttendanceUseCaseProvider),
  );
});

class AttendanceViewModel extends StateNotifier<AttendanceState> {
  final GetAttendanceConfigUseCase getConfigUseCase;
  final PunchAttendanceUseCase punchUseCase;
  final UploadPunchPhotoUseCase uploadPhotoUseCase;
  final GetAttendanceHistoryUseCase getHistoryUseCase;
  final GetAttendanceDetailUseCase getAttendanceDetailUseCase;
  final ToggleAttendanceUseCase toggleAttendanceUseCase;

  Timer? _clockTimer;

  AttendanceViewModel({
    required this.getConfigUseCase,
    required this.punchUseCase,
    required this.uploadPhotoUseCase,
    required this.getHistoryUseCase,
    required this.getAttendanceDetailUseCase,
    required this.toggleAttendanceUseCase,
  }) : super(const AttendanceState()) {
    _startClockTimer();
    loadInitialData();
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);

      final nextDuration = state.liveWorkDurationSeconds > 0
          ? state.liveWorkDurationSeconds + 1
          : 0;

      state = state.copyWith(
        liveCurrentTime: timeStr,
        liveWorkDurationSeconds: nextDuration,
      );
    });
  }

  /// Tải dữ liệu ban đầu khi mở màn hình (§2 & §5)
  Future<void> loadInitialData({double? lat, double? lng}) async {
    state = state.copyWith(
      status: AttendanceStatus.loading,
      errorMessage: null,
    );

    try {
      // 1. Tải cấu hình và danh sách địa điểm
      final config = await getConfigUseCase(lat: lat, lng: lng);

      // 2. Tải lịch sử chấm công của chính mình
      final history = await getHistoryUseCase(days: state.selectedDays);

      // 3. Tính toán thời gian làm việc hôm nay (ưu tiên today.first_in_at từ server §2)
      final now = DateTime.now();
      int workDuration = 0;
      if (config.today?.firstInAt != null) {
        final dt = DateTime.tryParse(config.today!.firstInAt!.replaceAll(' ', 'T'));
        if (dt != null) {
          workDuration = now.difference(dt).inSeconds;
          if (workDuration < 0) workDuration = 0;
        }
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final todayPunches = history.where((p) => p.punchAt.startsWith(todayStr)).toList();

      AttendancePunchEntity? latest;
      if (todayPunches.isNotEmpty) {
        todayPunches.sort((a, b) => a.punchAt.compareTo(b.punchAt));
        if (workDuration == 0) {
          final firstPunchTime = todayPunches.first.punchAtDateTime;
          if (firstPunchTime != null) {
            workDuration = now.difference(firstPunchTime).inSeconds;
            if (workDuration < 0) workDuration = 0;
          }
        }
        latest = todayPunches.last;
      }

      final legacyDetail = await getAttendanceDetailUseCase();

      state = state.copyWith(
        status: AttendanceStatus.loaded,
        config: config,
        history: history,
        latestPunch: latest,
        liveWorkDurationSeconds: workDuration,
        detail: legacyDetail,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi load dữ liệu: $e');
      state = state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  /// Cập nhật toạ độ GPS của người dùng và gọi lại config để tính khoảng cách (§2)
  Future<void> updateUserLocation(Position position) async {
    state = state.copyWith(currentPosition: position);
    try {
      final updatedConfig = await getConfigUseCase(
        lat: position.latitude,
        lng: position.longitude,
      );
      state = state.copyWith(config: updatedConfig);
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi refresh config theo vị trí: $e');
    }
  }

  /// Đổi khoảng thời gian xem lịch sử (§5)
  Future<void> setHistoryDays(int days) async {
    state = state.copyWith(selectedDays: days);
    try {
      final history = await getHistoryUseCase(days: days);
      state = state.copyWith(history: history);
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi tải lịch sử $days ngày: $e');
    }
  }

  /// Thực hiện một lượt chấm công (§3)
  /// Trả về đối tượng lượt chấm thành công hoặc null nếu thất bại
  Future<AttendancePunchEntity?> punch({
    required Position position,
    bool addToHistory = true,
  }) async {
    // 🔴 QUY TẮC §3: client_uuid SINH LÚC BẤM NÚT
    final clickUuid = const Uuid().v4();

    state = state.copyWith(
      isPunching: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final punchResult = await punchUseCase(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        isMockLocation: position.isMocked,
        clientUuid: clickUuid,
      );

      final msg = punchResult.duplicate
          ? 'Lượt chấm này đã có trên hệ thống trước đó.'
          : 'Đã ghi nhận chấm công lúc ${punchResult.timeFormatted}.';

      if (addToHistory) {
        // Cập nhật danh sách lịch sử
        final updatedHistory = List<AttendancePunchEntity>.from(state.history);
        updatedHistory.removeWhere((p) => p.clientUuid == punchResult.clientUuid);
        updatedHistory.insert(0, punchResult);

        state = state.copyWith(
          isPunching: false,
          latestPunch: punchResult,
          history: updatedHistory,
          successMessage: msg,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isPunching: false,
          latestPunch: punchResult,
          successMessage: msg,
          errorMessage: null,
        );
      }

      return punchResult;
    } catch (e) {
      final msg = e.toString().replaceAll('AppException: ', '').replaceAll('ServerException: ', '');
      debugPrint('[AttendanceViewModel] Lỗi chấm công: $msg');
      state = state.copyWith(
        isPunching: false,
        errorMessage: msg,
      );
      return null;
    }
  }

  /// Gửi lượt chấm công thật kèm ảnh (§3 & §4)
  /// Chỉ lưu vào lịch sử khi gửi lượt chấm công thật thành công
  Future<bool> submitPunchWithPhotos({
    required Position position,
    File? frontPhoto,
    File? backPhoto,
    void Function(double progress, String status)? onProgress,
  }) async {
    state = state.copyWith(
      isPunching: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      onProgress?.call(0.15, 'Đang ghi nhận lượt chấm công...');

      // 1. Gửi lượt chấm công lên server (§3) - không lưu vào lịch sử trước
      final clickUuid = const Uuid().v4();
      final punchResult = await punchUseCase(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        isMockLocation: position.isMocked,
        clientUuid: clickUuid,
      );

      // 2. Tải lần lượt từng ảnh lên (§4.1)
      if (frontPhoto != null) {
        onProgress?.call(0.45, 'Đang tải lên ảnh chân dung...');
        try {
          await uploadPhotoUseCase(
            punchId: punchResult.id,
            file: frontPhoto,
            photoType: 'front',
            lat: position.latitude,
            lng: position.longitude,
            parentUuid: punchResult.clientUuid,
          );
        } catch (photoErr) {
          debugPrint('[AttendanceViewModel] Lỗi tải ảnh trước: $photoErr');
        }
      }

      if (backPhoto != null) {
        onProgress?.call(0.75, 'Đang tải lên ảnh khung cảnh...');
        try {
          await uploadPhotoUseCase(
            punchId: punchResult.id,
            file: backPhoto,
            photoType: 'back',
            lat: position.latitude,
            lng: position.longitude,
            parentUuid: punchResult.clientUuid,
          );
        } catch (photoErr) {
          debugPrint('[AttendanceViewModel] Lỗi tải ảnh sau: $photoErr');
        }
      }

      onProgress?.call(0.90, 'Đang cập nhật lịch sử chấm công...');

      // 3. Làm mới lịch sử từ server (§5) và config để cập nhật today.next_action_label (§2)
      final refreshedHistory = await getHistoryUseCase(days: state.selectedDays);
      AttendanceConfigEntity? refreshedConfig;
      try {
        refreshedConfig = await getConfigUseCase(
          lat: position.latitude,
          lng: position.longitude,
        );
      } catch (_) {}

      onProgress?.call(1.0, 'Đã chấm công thành công!');

      final msg = punchResult.duplicate
          ? 'Lượt chấm này đã có trên hệ thống trước đó.'
          : 'Đã ghi nhận chấm công lúc ${punchResult.timeFormatted}.';

      state = state.copyWith(
        isPunching: false,
        config: refreshedConfig ?? state.config,
        latestPunch: punchResult,
        history: refreshedHistory,
        successMessage: msg,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('AppException: ', '').replaceAll('ServerException: ', '');
      debugPrint('[AttendanceViewModel] Lỗi gửi lượt chấm thật: $msg');
      state = state.copyWith(
        isPunching: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  /// Tải ảnh camera cho lượt chấm (§4)
  Future<AttendancePunchPhotoEntity?> uploadPunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    double? lat,
    double? lng,
  }) async {
    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);

    try {
      final photo = await uploadPhotoUseCase(
        punchId: punchId,
        file: file,
        photoType: photoType,
        takenAt: DateTime.now(),
        lat: lat,
        lng: lng,
      );

      // Cập nhật lượt chấm hiện tại
      if (state.latestPunch != null && state.latestPunch!.id == punchId) {
        final currentPhotos = List<AttendancePunchPhotoEntity>.from(state.latestPunch!.photos);
        currentPhotos.removeWhere((p) => p.photoType == photoType);
        currentPhotos.add(photo);

        final hasFront = currentPhotos.any((p) => p.photoType == 'front');
        final hasBack = currentPhotos.any((p) => p.photoType == 'back');

        final updatedRequirements = AttendanceRequirementsEntity(
          photoCount: currentPhotos.length,
          minPhotos: state.config?.photo.minPhotos ?? 2,
          maxPhotos: state.config?.photo.maxPhotos ?? 10,
          needFront: !hasFront,
          needBack: !hasBack,
          requireBoth: true,
          satisfied: hasFront && hasBack,
        );

        final updatedPunch = AttendancePunchEntity(
          id: state.latestPunch!.id,
          punchAt: state.latestPunch!.punchAt,
          clientUuid: state.latestPunch!.clientUuid,
          lat: state.latestPunch!.lat,
          lng: state.latestPunch!.lng,
          accuracyM: state.latestPunch!.accuracyM,
          geofenceId: state.latestPunch!.geofenceId,
          geofenceName: state.latestPunch!.geofenceName,
          isOutsideGeofence: state.latestPunch!.isOutsideGeofence,
          isMockLocation: state.latestPunch!.isMockLocation,
          isTimeTampered: state.latestPunch!.isTimeTampered,
          duplicate: state.latestPunch!.duplicate,
          photos: currentPhotos,
          requirements: updatedRequirements,
        );

        state = state.copyWith(latestPunch: updatedPunch);
      }

      // Làm mới lịch sử
      final refreshedHistory = await getHistoryUseCase(days: state.selectedDays);
      state = state.copyWith(
        isUploadingPhoto: false,
        history: refreshedHistory,
      );

      return photo;
    } catch (e) {
      final msg = e.toString().replaceAll('AppException: ', '').replaceAll('ServerException: ', '');
      debugPrint('[AttendanceViewModel] Lỗi tải ảnh: $msg');
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: msg,
      );
      return null;
    }
  }

  /// Tương thích ngược
  Future<void> loadAttendance() async {
    await loadInitialData();
  }

  Future<void> toggleAttendance() async {
    if (state.currentPosition != null) {
      await punch(position: state.currentPosition!);
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}

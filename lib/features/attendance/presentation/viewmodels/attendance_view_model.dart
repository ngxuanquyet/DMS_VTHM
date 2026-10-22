import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/sync/sync_service.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
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

final getMobileShiftsUseCaseProvider = Provider<GetMobileShiftsUseCase>((ref) {
  return GetMobileShiftsUseCase(ref.read(attendanceRepositoryProvider));
});

final getMobileDaysUseCaseProvider = Provider<GetMobileDaysUseCase>((ref) {
  return GetMobileDaysUseCase(ref.read(attendanceRepositoryProvider));
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
    getMobileShiftsUseCase: ref.read(getMobileShiftsUseCaseProvider),
    getMobileDaysUseCase: ref.read(getMobileDaysUseCaseProvider),
    attendanceRepository: ref.read(attendanceRepositoryProvider),
    syncService: ref.read(syncServiceProvider),
  );
});

class AttendanceViewModel extends StateNotifier<AttendanceState> {
  final GetAttendanceConfigUseCase getConfigUseCase;
  final PunchAttendanceUseCase punchUseCase;
  final UploadPunchPhotoUseCase uploadPhotoUseCase;
  final GetAttendanceHistoryUseCase getHistoryUseCase;
  final GetAttendanceDetailUseCase getAttendanceDetailUseCase;
  final ToggleAttendanceUseCase toggleAttendanceUseCase;
  final GetMobileShiftsUseCase? getMobileShiftsUseCase;
  final GetMobileDaysUseCase? getMobileDaysUseCase;
  final AttendanceRepository? attendanceRepository;
  final SyncService? syncService;

  Timer? _clockTimer;

  AttendanceViewModel({
    required this.getConfigUseCase,
    required this.punchUseCase,
    required this.uploadPhotoUseCase,
    required this.getHistoryUseCase,
    required this.getAttendanceDetailUseCase,
    required this.toggleAttendanceUseCase,
    this.getMobileShiftsUseCase,
    this.getMobileDaysUseCase,
    this.attendanceRepository,
    this.syncService,
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

      // 4. Tải lịch ca làm việc (§8: GET /attendance/mobile/shifts?days=7)
      List<AttendanceShiftScheduleEntity> shiftsList = [];
      try {
        if (getMobileShiftsUseCase != null) {
          shiftsList = await getMobileShiftsUseCase!(days: 7);
        }
      } catch (shiftErr) {
        debugPrint('[AttendanceViewModel] Không tải được lịch ca tuần: $shiftErr');
      }

      // Nhắc vào/ra ca: CHỈ push của server theo ca thật (21/10/2026) — app không tự đặt lịch nhắc cục bộ nữa.

      // Lựa chọn địa điểm chấm công: giữ lựa chọn cũ hoặc chọn địa điểm gần nhất
      AttendanceLocationItemEntity? activeLoc = state.selectedLocation;
      if (activeLoc != null) {
        final match = config.locations.where((l) => l.id == activeLoc!.id).firstOrNull;
        activeLoc = match ?? config.closestLocation;
      } else {
        activeLoc = config.closestLocation;
      }

      state = state.copyWith(
        status: AttendanceStatus.loaded,
        config: config,
        selectedLocation: activeLoc,
        history: history,
        latestPunch: latest,
        liveWorkDurationSeconds: workDuration,
        detail: legacyDetail,
        shifts: shiftsList,
        errorMessage: null,
      );
      unawaited(loadMonthResults());
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi load dữ liệu: $e');
      state = state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  /// Tháng lịch chấm công đang xem — lần tải lại toàn màn (`loadInitialData`) giữ đúng tháng này, không nhảy về tháng hiện tại.
  DateTime _viewedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Số thứ tự lượt tải gần nhất — lượt cũ về muộn (bấm chuyển tháng liên tục) bị bỏ, không đè tháng đang xem.
  int _monthRequest = 0;

  /// Tải kết quả bảng công (vào muộn / ra sớm) của một tháng cho lịch chấm công — server đã tính, app không tự đếm.
  /// GET /attendance/mobile/days?month=yyyy-MM (§8.4). Người nhiều mã NV có thể ra nhiều dòng một ngày ⇒ giữ TỪNG dòng.
  Future<void> loadMonthResults([DateTime? month]) async {
    if (getMobileDaysUseCase == null) return;
    if (month != null) _viewedMonth = DateTime(month.year, month.month, 1);
    final req = ++_monthRequest;
    try {
      final monthKey = DateFormat('yyyy-MM').format(_viewedMonth);
      final rows = await getMobileDaysUseCase!(monthKey);
      if (req != _monthRequest || !mounted) return;
      final results = <String, List<AttendanceDayResultEntity>>{};
      for (final r in rows) {
        results.putIfAbsent(r.workDate, () => []).add(r);
      }
      // copyWith xoá thông báo khi không truyền — giữ nguyên để lần tải chạy ngầm này không nuốt câu báo vừa hiện.
      state = state.copyWith(
        dayResults: results,
        dayResultsMonth: monthKey,
        errorMessage: state.errorMessage,
        successMessage: state.successMessage,
      );
    } catch (e) {
      debugPrint('[AttendanceViewModel] Không tải được kết quả công tháng: $e');
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

      AttendanceLocationItemEntity? activeLoc = state.selectedLocation;
      if (activeLoc != null) {
        final match = updatedConfig.locations.where((l) => l.id == activeLoc!.id).firstOrNull;
        activeLoc = match ?? updatedConfig.closestLocation;
      } else {
        activeLoc = updatedConfig.closestLocation;
      }

      state = state.copyWith(
        config: updatedConfig,
        selectedLocation: activeLoc,
      );
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi refresh config theo vị trí: $e');
    }
  }

  /// Người dùng chủ động chọn địa điểm chấm công
  void selectLocation(AttendanceLocationItemEntity location) {
    state = state.copyWith(selectedLocation: location);
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
  /// Tối ưu UX: Ghi nhận lượt chấm nhanh, chuyển ảnh vào hàng đợi upload nền SyncService,
  /// cập nhật giao diện lập tức (Optimistic UI) giúp người dùng không phải chờ đợi.
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
      onProgress?.call(0.20, 'Đang ghi nhận lượt chấm công...');

      // 1. Gửi lượt chấm công lên server (§3) hoặc lưu offline nếu mất mạng
      final clickUuid = const Uuid().v4();
      final punchResult = await punchUseCase(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        isMockLocation: position.isMocked,
        clientUuid: clickUuid,
      );

      final List<AttendancePunchPhotoEntity> attachedPhotos = [];

      // 2. Chuyển ảnh vào hàng đợi nền và gắn ngay vào bản ghi chấm công cục bộ
      if (frontPhoto != null && attendanceRepository != null) {
        onProgress?.call(0.50, 'Đang lưu ảnh chân dung...');
        final frontEntity = await attendanceRepository!.enqueuePunchPhoto(
          punchId: punchResult.id,
          file: frontPhoto,
          photoType: 'front',
          lat: position.latitude,
          lng: position.longitude,
          parentUuid: punchResult.clientUuid,
        );
        attachedPhotos.add(frontEntity);
      }

      if (backPhoto != null && attendanceRepository != null) {
        onProgress?.call(0.80, 'Đang lưu ảnh khung cảnh...');
        final backEntity = await attendanceRepository!.enqueuePunchPhoto(
          punchId: punchResult.id,
          file: backPhoto,
          photoType: 'back',
          lat: position.latitude,
          lng: position.longitude,
          parentUuid: punchResult.clientUuid,
        );
        attachedPhotos.add(backEntity);
      }

      // Kích hoạt tiến trình đồng bộ ảnh chạy nền
      syncService?.syncQueue();

      onProgress?.call(1.0, 'Đã chấm công thành công!');

      final updatedRequirements = AttendanceRequirementsEntity(
        photoCount: attachedPhotos.length,
        minPhotos: state.config?.photo.minPhotos ?? 2,
        maxPhotos: state.config?.photo.maxPhotos ?? 10,
        needFront: !attachedPhotos.any((p) => p.photoType == 'front'),
        needBack: !attachedPhotos.any((p) => p.photoType == 'back'),
        requireBoth: true,
        satisfied: true,
      );

      final livePunchWithPhotos = AttendancePunchEntity(
        id: punchResult.id,
        punchAt: punchResult.punchAt,
        clientUuid: punchResult.clientUuid,
        lat: punchResult.lat,
        lng: punchResult.lng,
        accuracyM: punchResult.accuracyM,
        geofenceId: punchResult.geofenceId,
        geofenceName: punchResult.geofenceName,
        isOutsideGeofence: punchResult.isOutsideGeofence,
        isMockLocation: punchResult.isMockLocation,
        isTimeTampered: punchResult.isTimeTampered,
        duplicate: punchResult.duplicate,
        photos: attachedPhotos,
        requirements: updatedRequirements,
      );

      final updatedHistory = List<AttendancePunchEntity>.from(state.history);
      updatedHistory.removeWhere((p) => p.clientUuid == punchResult.clientUuid);
      updatedHistory.insert(0, livePunchWithPhotos);

      // Làm mới lịch sử từ server nếu có
      List<AttendancePunchEntity> finalHistory = updatedHistory;
      try {
        final refreshedHistory = await getHistoryUseCase(days: state.selectedDays);
        if (refreshedHistory.isNotEmpty) {
          finalHistory = refreshedHistory;
        }
      } catch (_) {}

      final msg = punchResult.duplicate
          ? 'Lượt chấm này đã có trên hệ thống trước đó.'
          : 'Đã ghi nhận chấm công lúc ${punchResult.timeFormatted}.';

      state = state.copyWith(
        isPunching: false,
        latestPunch: livePunchWithPhotos,
        history: finalHistory,
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

  /// Tải ảnh camera bổ sung cho lượt chấm (§4) - Chạy nền và cập nhật UI ngay lập tức
  Future<AttendancePunchPhotoEntity?> uploadPunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    double? lat,
    double? lng,
  }) async {
    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);

    try {
      AttendancePunchPhotoEntity photo;
      if (attendanceRepository != null) {
        photo = await attendanceRepository!.enqueuePunchPhoto(
          punchId: punchId,
          file: file,
          photoType: photoType,
          takenAt: DateTime.now(),
          lat: lat,
          lng: lng,
          parentUuid: state.latestPunch?.clientUuid,
        );
        syncService?.syncQueue();
      } else {
        photo = await uploadPhotoUseCase(
          punchId: punchId,
          file: file,
          photoType: photoType,
          takenAt: DateTime.now(),
          lat: lat,
          lng: lng,
        );
      }

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

        final updatedHistory = List<AttendancePunchEntity>.from(state.history);
        final idx = updatedHistory.indexWhere((p) => p.id == punchId);
        if (idx >= 0) {
          updatedHistory[idx] = updatedPunch;
        }

        state = state.copyWith(
          isUploadingPhoto: false,
          latestPunch: updatedPunch,
          history: updatedHistory,
        );
      } else {
        state = state.copyWith(isUploadingPhoto: false);
      }

      return photo;
    } catch (e) {
      debugPrint('[AttendanceViewModel] Lỗi upload ảnh chấm công: $e');
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
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

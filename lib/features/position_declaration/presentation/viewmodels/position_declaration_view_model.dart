import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/map/goong_api_service.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/position_declaration_entity.dart';
import '../../domain/entities/position_reason_entity.dart';
import '../../domain/repositories/position_declaration_repository.dart';
import '../../data/repositories/position_declaration_repository_impl.dart';
import '../states/position_declaration_state.dart';

final positionDeclarationViewModelProvider = StateNotifierProvider<
    PositionDeclarationViewModel, PositionDeclarationState>((ref) {
  return PositionDeclarationViewModel(
    repository: ref.read(positionDeclarationRepositoryProvider),
    locationService: ref.read(locationServiceProvider),
  );
});

class PositionDeclarationViewModel
    extends StateNotifier<PositionDeclarationState> {
  final PositionDeclarationRepository _repository;
  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();
  final GoongApiService _goongApiService = GoongApiService();

  PositionDeclarationViewModel({
    required PositionDeclarationRepository repository,
    required LocationService locationService,
  })  : _repository = repository,
        _locationService = locationService,
        super(const PositionDeclarationState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      loadReasons(),
      loadHistory(),
    ]);
  }

  /// Tải danh mục lý do đang bật (§2)
  Future<void> loadReasons({bool forceRefresh = false}) async {
    state = state.copyWith(status: PositionDeclarationStatus.loading);
    try {
      final reasons =
          await _repository.getActiveReasons(forceRefresh: forceRefresh);
      state = state.copyWith(
        status: PositionDeclarationStatus.initial,
        reasons: reasons,
        selectedReason: state.selectedReason ??
            (reasons.isNotEmpty ? reasons.first : null),
      );
    } catch (e) {
      state = state.copyWith(
        status: PositionDeclarationStatus.initial,
        errorMessage: 'Không thể tải danh mục lý do. Đang dùng dữ liệu sẵn có.',
      );
    }
  }

  /// Tải danh sách lịch sử các lượt khai báo vị trí lưu trong máy (§8)
  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final history = await _repository.getLocalDeclarations();
      state = state.copyWith(
        history: history,
        isLoadingHistory: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  /// Chọn lý do khai báo
  void selectReason(PositionReasonEntity reason) {
    state = state.copyWith(selectedReason: reason);
  }

  /// Lấy vị trí GPS hiện tại của nhân viên
  Future<void> fetchCurrentLocation(BuildContext? context) async {
    state = state.copyWith(isFetchingLocation: true);
    try {
      final pos = context != null
          ? await _locationService.checkAndGetLocation(context)
          : LocationService.currentCachedPosition;

      if (pos != null) {
        state = state.copyWith(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracyM: pos.accuracy,
          isFetchingLocation: false,
        );

        // Dò địa chỉ giải mã ngược từ Goong
        _resolveAddress(pos.latitude, pos.longitude);
      } else {
        state = state.copyWith(
          isFetchingLocation: false,
          errorMessage: 'Chưa thể lấy vị trí GPS. Vui lòng bật định vị trên máy.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isFetchingLocation: false,
        errorMessage: 'Lỗi khi lấy vị trí: $e',
      );
    }
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    try {
      final place = await _goongApiService.reverseGeocode(lat, lng);
      if (place != null && place.formattedAddress.isNotEmpty) {
        state = state.copyWith(address: place.formattedAddress);
      }
    } catch (_) {}
  }

  /// Cập nhật vị trí và địa chỉ từ bản đồ
  void setLocation({
    required double lat,
    required double lng,
    String? address,
    double? accuracyM,
  }) {
    state = state.copyWith(
      lat: lat,
      lng: lng,
      address: address ?? state.address,
      accuracyM: accuracyM ?? state.accuracyM,
      isFetchingLocation: false,
    );
    if (address == null || address.isEmpty) {
      _resolveAddress(lat, lng);
    }
  }

  /// Xoá vị trí
  void clearLocation() {
    state = state.copyWith(
      lat: null,
      lng: null,
      accuracyM: null,
      address: null,
    );
  }

  /// Chụp ảnh hiện trường: BẮT BUỘC CHỈ TỪ CAMERA (theo §3)
  /// Tự động nén và mã hoá JPEG để tránh lỗi định dạng HEIC của iOS
  Future<bool> takePhotoFromCamera() async {
    if (state.photos.length >= 10) {
      state = state.copyWith(
        errorMessage: 'Mỗi lượt khai báo gửi kèm tối đa 10 ảnh.',
      );
      return false;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (picked != null) {
        final file = File(picked.path);
        final updatedPhotos = List<File>.from(state.photos)..add(file);
        state = state.copyWith(
          photos: updatedPhotos,
          errorMessage: null,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể mở máy ảnh hoặc chụp ảnh: $e',
      );
    }
    return false;
  }

  /// Xoá ảnh đã chụp
  void removePhoto(int index) {
    if (index >= 0 && index < state.photos.length) {
      final updatedPhotos = List<File>.from(state.photos)..removeAt(index);
      state = state.copyWith(photos: updatedPhotos);
    }
  }

  /// Cập nhật địa chỉ thủ công nếu cần
  void updateAddress(String address) {
    state = state.copyWith(address: address);
  }

  /// Gửi khai báo vị trí (§4)
  Future<(bool success, String? message)> submitDeclaration({
    String? title,
    String? note,
  }) async {
    if (state.selectedReason == null) {
      const msg = 'Hãy chọn một lý do trong danh mục.';
      state = state.copyWith(errorMessage: msg);
      return (false, msg);
    }

    if (state.lat == null || state.lng == null) {
      const msg = 'Vui lòng xác định vị trí GPS trước khi gửi khai báo.';
      state = state.copyWith(errorMessage: msg);
      return (false, msg);
    }

    state = state.copyWith(
      status: PositionDeclarationStatus.submitting,
      errorMessage: null,
      successMessage: null,
    );

    // Sinh UUID v4 duy nhất một lần lúc bấm (§4.3)
    final clientUuid = const Uuid().v4();
    final now = DateTime.now();
    final clientTimeIso = now.toIso8601String();

    final declaration = PositionDeclarationEntity(
      clientUuid: clientUuid,
      reasonId: state.selectedReason!.id,
      reasonCode: state.selectedReason!.code,
      reasonName: state.selectedReason!.name,
      reasonColor: state.selectedReason!.color,
      lat: state.lat!,
      lng: state.lng!,
      accuracyM: state.accuracyM,
      address: state.address,
      title: title?.trim().isNotEmpty == true ? title!.trim() : null,
      note: note?.trim().isNotEmpty == true ? note!.trim() : null,
      localPhotoPaths: state.photos.map((f) => f.path).toList(),
      clientTime: clientTimeIso,
      createdAtMs: now.millisecondsSinceEpoch,
      syncStatus: 'pending',
    );

    try {
      final result = await _repository.submitDeclaration(declaration);
      await loadHistory();

      if (result.isSynced) {
        final successMsg = 'Khai báo vị trí thành công lúc ${result.declaredAt ?? "vừa xong"}!';
        state = state.copyWith(
          status: PositionDeclarationStatus.success,
          successMessage: successMsg,
          lastSubmitted: result,
          photos: [], // Reset form
          clearSelectedReason: false,
        );
        return (true, successMsg);
      } else {
        // Đã lưu hàng đợi ngoại tuyến
        const offlineMsg = 'Đã lưu khai báo vào hàng đợi ngoại tuyến. Hệ thống sẽ tự động đồng bộ khi có kết nối mạng.';
        state = state.copyWith(
          status: PositionDeclarationStatus.success,
          successMessage: offlineMsg,
          lastSubmitted: result,
          photos: [], // Reset form
        );
        return (true, offlineMsg);
      }
    } on DioException catch (dioErr) {
      final msg = _extractDioErrorMessage(dioErr);
      state = state.copyWith(
        status: PositionDeclarationStatus.error,
        errorMessage: msg,
      );
      await loadHistory();
      return (false, msg);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        status: PositionDeclarationStatus.error,
        errorMessage: msg,
      );
      await loadHistory();
      return (false, msg);
    }
  }

  /// Đổi lý do và gửi lại bản ghi lỗi (khi gặp 422: Lý do đã ngừng sử dụng theo §5.3)
  Future<(bool success, String? message)> retryDeclarationWithNewReason(
    PositionDeclarationEntity failedDeclaration,
    PositionReasonEntity newReason,
  ) async {
    final updated = failedDeclaration.copyWith(
      reasonId: newReason.id,
      reasonCode: newReason.code,
      reasonName: newReason.name,
      reasonColor: newReason.color,
      syncStatus: 'pending',
      syncError: null,
    );

    try {
      final result = await _repository.submitDeclaration(updated);
      await loadHistory();
      if (result.isSynced) {
        return (true, 'Đã cập nhật lý do và gửi thành công!');
      } else {
        return (true, 'Đã đưa vào hàng đợi đồng bộ với lý do mới.');
      }
    } catch (e) {
      await loadHistory();
      return (false, 'Không thể gửi lại: $e');
    }
  }

  void clearMessage() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  String _extractDioErrorMessage(DioException dioErr) {
    if (dioErr.response?.data is Map<String, dynamic>) {
      final data = dioErr.response!.data as Map<String, dynamic>;
      if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
        return data['message'].toString().trim();
      }
    }
    return dioErr.message ?? 'Đã xảy ra lỗi khi gửi khai báo vị trí';
  }
}

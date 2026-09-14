import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../location/location_provider.dart';
import 'goong_api_service.dart';
import 'goong_models.dart';

final goongApiServiceProvider = Provider<GoongApiService>((ref) {
  return GoongApiService();
});

/// Toạ độ GPS thực tế của máy.
/// Trả về `null` nếu chưa bật GPS hoặc chưa cấp quyền (KHÔNG trả toạ độ giả định).
/// Tự động cập nhật lại ngay khi người dùng bật GPS hoặc cấp quyền.
final currentPointProvider = FutureProvider<GoongLatLng?>((ref) async {
  final isReady = ref.watch(locationProvider.select((s) => s.isReady));
  if (!isReady) {
    return null;
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return GoongLatLng(position.latitude, position.longitude);
  } catch (_) {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      return GoongLatLng(lastKnown.latitude, lastKnown.longitude);
    }
    return null;
  }
});

/// Địa chỉ của một toạ độ, có nhớ kết quả.
///
/// `.family` + `keepAlive` mặc định của Riverpod đủ để hai màn cùng hỏi một điểm chỉ tốn một lượt gọi.
final reverseGeocodeProvider =
    FutureProvider.family<GoongPlace?, GoongLatLng>((ref, point) async {
  return ref.watch(goongApiServiceProvider).reverseGeocode(point.lat, point.lng);
});

/// Gợi ý địa chỉ cho ô tìm kiếm, có **chống gõ dồn**.
///
/// 🔴 Không có `debounce` thì mỗi phím gõ là một lượt gọi Goong: gõ "Nguyễn Văn Linh" = 15 lượt cho một
/// lần tìm. Hạn mức là của cả công ty, và Goong tính tiền theo lượt.
class GoongAutocomplete extends AutoDisposeAsyncNotifier<List<GoongPrediction>> {
  Timer? _debounce;
  GoongLatLng? _near;

  static const Duration _wait = Duration(milliseconds: 350);

  @override
  Future<List<GoongPrediction>> build() async {
    ref.onDispose(() => _debounce?.cancel());

    return const [];
  }

  /// Đặt điểm neo để xếp gợi ý theo khoảng cách — gọi khi đã có GPS.
  void anchorAt(GoongLatLng? near) => _near = near;

  /// Gõ tới đâu gọi tới đó, nhưng chỉ thật sự gọi khi người dùng ngừng gõ [_wait].
  void search(String input) {
    _debounce?.cancel();

    final query = input.trim();
    if (query.length < 2) {
      // 1 ký tự thì gợi ý vô nghĩa mà vẫn tốn lượt gọi.
      state = const AsyncData([]);

      return;
    }

    _debounce = Timer(_wait, () async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref.read(goongApiServiceProvider).autocomplete(query, near: _near),
      );
    });
  }

  void clear() {
    _debounce?.cancel();
    state = const AsyncData([]);
  }
}

final goongAutocompleteProvider = AsyncNotifierProvider.autoDispose<
    GoongAutocomplete, List<GoongPrediction>>(GoongAutocomplete.new);

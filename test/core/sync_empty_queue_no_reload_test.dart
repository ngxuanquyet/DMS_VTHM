import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';

import '../customer_sync_online_offline_test.dart' show MockSyncDioAdapter;

/// Lượt đồng bộ định kỳ 60s / đổi mạng / màn gọi đồng bộ mà hàng đợi RỖNG thì KHÔNG được tải lại danh sách điểm bán
/// (29/10/2026: trước đây mỗi phút ép tải lại 1.090 điểm ≈ 11 lượt API ⇒ màn Tuyến giật theo chu kỳ).
class _CountingAdapter extends MockSyncDioAdapter {
  final List<String> paths = [];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    paths.add(options.path);
    return super.fetch(options, requestStream, cancelFuture);
  }
}

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hàng đợi rỗng ⇒ syncQueue không gọi API tải điểm bán / tuyến', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    final adapter = _CountingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => _Online()),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final result = await container.read(syncServiceProvider).syncQueue();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(result.successCount, 0);
    expect(adapter.paths.where((p) => p.contains('customers/mine') || p.contains('routes/mine')), isEmpty);
  });
}

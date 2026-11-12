import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';

/// Rà soát offline 12/11/2026 — gói check-out / huỷ lượt trong hàng đợi:
/// 1. Check-out tới lượt ĐÃ BỊ HUỶ (huỷ từ máy khác, #24895) ⇒ xong (spec §7), không thành "lỗi đồng bộ".
/// 2. Chỉ lỗi NGHIỆP VỤ 422 mới được dò chữ "đã check-out rồi / đã huỷ" — 403/5xx mang cụm đó KHÔNG được coi là xong.

/// Máy chủ trả đúng một mã + câu lỗi cho mọi request.
class _Adapter implements HttpClientAdapter {
  final int status;
  final String message;
  _Adapter(this.status, this.message);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: {'success': false, 'message': message},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> run(String op, int status, String message) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = _Adapter(status, message);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
    ]);
    addTearDown(container.dispose);
    final id = await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit',
      op: op,
      clientUuid: '$op-1',
      parentUuid: const Value('visit-uuid'),
      payload: jsonEncode({'visit_id': 901}),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    await container.read(syncServiceProvider).syncQueue(force: true);
    return (await db.getEntryById(id))?.state;
  }

  test('check-out lượt đã bị huỷ (422) ⇒ xong, không thành lỗi đồng bộ', () async {
    expect(await run('checkout', 422, 'Lượt viếng thăm này đã bị huỷ, không check-out được.'), 'done');
  });

  test('check-out lượt đã check-out rồi (422) ⇒ xong', () async {
    expect(await run('checkout', 422, 'Lượt viếng thăm này đã check-out rồi.'), 'done');
  });

  test('check-out gặp 503 mang cụm "đã đóng" ⇒ KHÔNG xong (vẫn chờ gửi lại)', () async {
    expect(await run('checkout', 503, 'Cổng đã đóng để bảo trì'), isNot('done'));
  });

  test('huỷ lượt đã check-out (422) ⇒ xong', () async {
    expect(await run('cancel', 422, 'Lượt viếng thăm này đã check-out rồi, không huỷ được nữa.'), 'done');
  });

  test('huỷ gặp 403 mang cụm "đã huỷ" ⇒ KHÔNG xong', () async {
    expect(await run('cancel', 403, 'Quyền huỷ lượt đã huỷ bỏ khỏi vai của bạn'), isNot('done'));
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';

/// Rà soát #24698 nhóm 2 (mất dữ liệu): lỗi 1 (chấm công tính vùng khi mất mạng), 8 (sửa lúc lô đang chạy), 9 (uuid
/// tạo điểm bán dùng chung giữa lần gửi trực tuyến và hàng đợi).

class _Adapter implements HttpClientAdapter {
  final void Function(RequestOptions o) onRequest;
  final List<RequestOptions> calls = [];
  _Adapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    onRequest(o);
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': <String, dynamic>{}}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void handleNetworkDisconnection() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('lỗi 1 — chấm công mất mạng tự tính vùng theo chỗ đứng hiện tại', () {
    const loc = AttendanceLocationItemEntity(id: 1, code: 'VP', name: 'Văn phòng', lat: 21.0, lng: 105.8, radiusM: 100);
    const cfg = AttendanceConfigEntity(
      canPunch: true,
      group: AttendanceGroupEntity(code: 'G', name: 'G', enforceGeofence: true),
      photo: AttendancePhotoConfigEntity(),
      locations: [loc], // distance_m rỗng như bản đệm tải không kèm toạ độ
    );

    test('đứng cách tâm ~50 m ⇒ trong vùng (bản đệm rỗng khoảng cách vẫn tính được)', () {
      expect(cfg.isWithinAnyGeofence(), isFalse, reason: 'lỗi cũ: bản đệm không có khoảng cách ⇒ chặn oan');
      final c = cfg.withDistancesFrom(21.0 + 50 / 111195, 105.8);
      expect(c.locations.single.distanceM, closeTo(50, 2));
      expect(c.isWithinAnyGeofence(), isTrue);
    });

    test('đứng cách ~1 km ⇒ ngoài vùng (không cho chấm rồi bị server từ chối lúc đồng bộ)', () {
      final c = cfg.withDistancesFrom(21.0 + 1000 / 111195, 105.8);
      expect(c.isWithinAnyGeofence(), isFalse);
    });
  });

  group('lỗi 8/9 — điểm bán', () {
    late AppDatabase db;
    late ProviderContainer container;
    late _Adapter adapter;

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    void boot(void Function(RequestOptions o) onRequest) {
      db = AppDatabase(NativeDatabase.memory(), 1);
      adapter = _Adapter(onRequest);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
        connectivityProvider.overrideWith((ref) => _Online()),
      ]);
    }

    test('lỗi 9: tạo ngoại tuyến DÙNG LẠI client_uuid nơi gọi đưa (lần gửi trực tuyến vừa hỏng)', () async {
      boot((_) {});
      await db.setOwner(7);
      final e = await CustomerLocalDataSource(db).createCustomerOffline({
        'client_uuid': '11111111-2222-4333-8444-555555555555',
        'name': 'Điểm bán A',
        'phone': '0909000111',
        'address': 'Hà Nội',
      });
      expect(e.clientUuid, '11111111-2222-4333-8444-555555555555', reason: 'lỗi cũ: sinh uuid mới ⇒ server tạo trùng');
      final rows = await db.select(db.syncQueueEntries).get();
      expect(rows.single.clientUuid, '11111111-2222-4333-8444-555555555555');
    });

    test('lỗi 8: phần sửa gộp vào dòng CHỜ trong lúc lô đang chạy mục trước ⇒ lô gửi bản MỚI, không gửi bản trong RAM',
        () async {
      late int second;
      var patched = false;
      boot((o) {
        // Lô đã nạp cả hai mục; đúng lúc gửi mục đầu, người dùng gộp phần sửa vào mục sau.
        if (!patched && o.path == '/crm/customers/1') {
          patched = true;
          db.updatePayload(second, jsonEncode({'name': 'Tên MỚI'}));
        }
      });
      await db.setOwner(7);
      Future<int> upd(String uuid, int serverId, String name) => db.enqueue(SyncQueueEntriesCompanion.insert(
            entity: 'customer',
            op: 'update',
            clientUuid: uuid,
            serverId: Value(serverId),
            payload: jsonEncode({'name': name}),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            createdElapsed: SystemClock.nowMonotonicMs,
            bootId: SystemClock.bootId,
          ));
      await upd('c1', 1, 'A');
      second = await upd('c2', 2, 'Tên CŨ');

      await container.read(syncServiceProvider).syncQueue();

      final sent = adapter.calls.firstWhere((c) => c.path == '/crm/customers/2').data as Map;
      expect(sent['name'], 'Tên MỚI', reason: 'lỗi cũ: gửi payload nạp sẵn trong RAM rồi markDone ⇒ mất phần sửa');
    });
  });
}

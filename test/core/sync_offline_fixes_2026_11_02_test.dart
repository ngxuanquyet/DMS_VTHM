import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';

/// Rà soát luồng offline 02/11/2026 — mỗi nhóm tái hiện một lỗi đã vá (phiên hết hạn, 408/429, huỷ lượt khi check-in
/// đang gửi, sửa điểm bán khi dòng tạo đang gửi, ảnh điểm bán mất tệp).

typedef _Handler = (int, Map<String, dynamic>)? Function(RequestOptions o);

class _Adapter implements HttpClientAdapter {
  final _Handler handler;
  final bool networkDown;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler, {this.networkDown = false});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    if (networkDown) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError, message: 'mất mạng');
    }
    final r = handler(o) ?? (200, {'success': true, 'data': <String, dynamic>{}});
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}

  Iterable<String> get paths => calls.map((c) => c.path);
}

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async {
    state = const ConnectivityState(isOnline: true);
    return true;
  }

  @override
  void handleNetworkDisconnection() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _Adapter adapter;
  late ProviderContainer container;

  void boot(_Handler handler) {
    db = AppDatabase(NativeDatabase.memory(), 1);
    adapter = _Adapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => _Online()),
    ]);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> enqueue(String entity, String op, String uuid,
          {String? parent, String payload = '{}', int? serverId, String state = 'pending', int? nextAttemptAt}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: payload,
        serverId: Value(serverId),
        state: Value(state),
        nextAttemptAt: Value(nextAttemptAt),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  Future<SyncQueueEntry> row(int id) => (db.select(db.syncQueueEntries)..where((t) => t.id.equals(id))).getSingle();

  group('#1 phiên hết hạn KHÔNG làm hỏng mục chờ gửi', () {
    test('401 ⇒ mục giữ pending, cả lô dừng (mục sau không bị gửi bằng phiên hỏng)', () async {
      boot((o) => (401, {'success': false, 'message': 'Phiên đăng nhập hết hạn'}));
      final a = await enqueue('declaration', 'create', 'd1', payload: '{"reason_id":1,"lat":1,"lng":1}');
      final b = await enqueue('declaration', 'create', 'd2', payload: '{"reason_id":1,"lat":1,"lng":1}');

      final result = await container.read(syncServiceProvider).syncQueue(force: true);

      expect(result.deadErrors, isEmpty, reason: 'lỗi cũ: 401 ⇒ dead, chỉ xoá được');
      expect((await row(a)).state, 'pending');
      expect((await row(b)).state, 'pending');
      expect(adapter.calls.length, 1, reason: 'lỗi cũ: mục sau cũng gửi rồi cũng dead');
      expect(await db.countDeadSync(), 0);
    });

    test('403 DMS_APP_FORBIDDEN ⇒ giữ pending', () async {
      boot((o) => (403, {'success': false, 'code': 'DMS_APP_FORBIDDEN', 'message': 'chưa được cấp quyền dùng app DMS'}));
      final a = await enqueue('declaration', 'create', 'd1', payload: '{"reason_id":1,"lat":1,"lng":1}');

      await container.read(syncServiceProvider).syncQueue(force: true);

      expect((await row(a)).state, 'pending');
    });

    test('403 quyền thường vẫn là lỗi vĩnh viễn (dead)', () async {
      boot((o) => (403, {'success': false, 'message': 'Không có quyền'}));
      final a = await enqueue('declaration', 'create', 'd1', payload: '{"reason_id":1,"lat":1,"lng":1}');

      await container.read(syncServiceProvider).syncQueue(force: true);

      expect((await row(a)).state, 'dead');
    });
  });

  group('#4 408 / 429 là lỗi tạm', () {
    for (final code in [408, 429]) {
      test('$code ⇒ thử lại, không dead', () async {
        boot((o) => (code, {'success': false, 'message': 'tạm'}));
        final a = await enqueue('declaration', 'create', 'd1', payload: '{"reason_id":1,"lat":1,"lng":1}');

        final result = await container.read(syncServiceProvider).syncQueue(force: true);

        expect(result.deadErrors, isEmpty);
        final r = await row(a);
        expect(r.state, 'pending');
        expect(r.attempts, 1);
      });
    }
  });

  group('#2 huỷ lượt khi check-in còn đang gửi', () {
    test('check-in chưa có mã server ⇒ lệnh huỷ CHỜ (không đánh dấu xong); có mã rồi thì huỷ đúng lượt', () async {
      boot((o) => null);
      final future = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final create = await enqueue('visit', 'create', 'visitA', payload: '{"customer_id":10}', nextAttemptAt: future);
      final cancel = await enqueue('visit', 'cancel', 'cancel-1', parent: 'visitA', payload: '{"visit_id":0}');
      final sync = container.read(syncServiceProvider);

      await sync.syncQueue();

      expect((await row(cancel)).state, 'pending', reason: 'lỗi cũ: đánh dấu xong ⇒ lượt treo trên server');
      expect(adapter.paths.where((p) => p.contains('/cancel')), isEmpty);

      await db.markDone(create, serverId: 900);
      await sync.syncQueue(force: true);

      expect(adapter.paths, contains('/dms/visits/900/cancel'));
      expect((await row(cancel)).state, 'done');
    });

    test('check-in đã bị từ chối (dead) ⇒ không có gì trên server, lệnh huỷ xong luôn', () async {
      boot((o) => null);
      await enqueue('visit', 'create', 'visitA', payload: '{"customer_id":10}', state: 'dead');
      final cancel = await enqueue('visit', 'cancel', 'cancel-1', parent: 'visitA', payload: '{"visit_id":0}');

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(cancel)).state, 'done');
      expect(adapter.calls, isEmpty);
    });

    test('deletePendingVisitQueue(keepVisitCreate) giữ dòng tạo đang gửi, xoá ảnh / check-out chờ', () async {
      boot((o) => null);
      final create = await enqueue('visit', 'create', 'visitA', state: 'sending');
      final photo = await enqueue('visit_photo', 'upload', 'p1', parent: 'visitA');
      final checkout = await enqueue('visit', 'checkout', 'co', parent: 'visitA');

      await db.deletePendingVisitQueue('visitA', keepVisitCreate: true);

      final left = (await db.select(db.syncQueueEntries).get()).map((e) => e.id).toSet();
      expect(left, contains(create));
      expect(left.contains(photo), isFalse);
      expect(left.contains(checkout), isFalse);
    });
  });

  group('#3 sửa điểm bán khi dòng tạo đang gửi', () {
    Future<void> seedCustomer(String uuid) => db.insertOrUpdateCustomer(LocalCustomersCompanion(
          clientUuid: Value(uuid),
          name: const Value('Điểm bán A'),
          nameUnaccent: const Value('diem ban a'),
          phone: const Value('0909000111'),
          address: const Value('Hà Nội'),
          contactPerson: const Value('Chủ'),
          syncStatus: const Value('pending'),
        ));

    test('dòng tạo đang gửi ⇒ phần sửa thành lệnh SỬA riêng, không gộp vào dòng đang gửi', () async {
      boot((o) => null);
      await db.setOwner(7);
      await seedCustomer('cust-1');
      final create = await enqueue('customer', 'create', 'cust-1', payload: '{"name":"Điểm bán A"}', state: 'sending');

      await CustomerLocalDataSource(db).updateCustomerOffline('cust-1', {'name': 'Điểm bán A sửa'});

      final c = await row(create);
      expect(jsonDecode(c.payload)['name'], 'Điểm bán A', reason: 'lỗi cũ: gộp vào dòng đang gửi, markDone đè mất');
      expect(c.state, 'sending');
      final updates = await (db.select(db.syncQueueEntries)..where((t) => t.op.equals('update'))).get();
      expect(updates.length, 1);
      expect(jsonDecode(updates.single.payload)['name'], 'Điểm bán A sửa');
    });

    test('lệnh sửa chưa có mã server ⇒ chờ dòng tạo; dòng tạo có mã rồi thì PATCH đúng điểm bán', () async {
      boot((o) => null);
      // Dòng tạo chưa lên server (đang chờ thử lại) — 'sending' thì SyncService hồi phục về pending lúc khởi tạo.
      final later = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final create = await enqueue('customer', 'create', 'cust-1', nextAttemptAt: later);
      final update = await enqueue('customer', 'update', 'cust-1', payload: '{"name":"B"}', serverId: 0);
      final sync = container.read(syncServiceProvider);

      await sync.syncQueue();
      expect((await row(update)).state, 'pending', reason: 'lỗi cũ: đánh dấu xong ⇒ mất phần sửa');
      expect(adapter.paths, isEmpty);

      await db.markDone(create, serverId: 77);
      await sync.syncQueue(force: true);
      expect(adapter.paths, contains('/crm/customers/77'));
      expect((await row(update)).state, 'done');
    });

    test('lệnh sửa không còn dòng tạo, không có mã ⇒ báo lỗi (dead), không đánh dấu xong im lặng', () async {
      boot((o) => null);
      final update = await enqueue('customer', 'update', 'cust-orphan', payload: '{"name":"B"}');

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(update)).state, 'dead');
    });
  });

  test('#5 ảnh điểm bán mất tệp ⇒ báo lỗi (dead), không tạo điểm bán thiếu ảnh', () async {
    boot((o) => null);
    final tmp = await Directory.systemTemp.createTemp('dms_photo_');
    final missing = 'file://${tmp.path}/offline_customer_photos/khong_con.jpg';
    final id = await enqueue('customer', 'create', 'cust-photo',
        payload: jsonEncode({'name': 'A', 'local_photo_paths': [missing]}));

    await container.read(syncServiceProvider).syncQueue();

    expect((await row(id)).state, 'dead');
    expect(adapter.paths.contains('/crm/customers'), isFalse);
    await tmp.delete(recursive: true);
  });

  test('#5b chuỗi bắt đầu bằng "/" mà KHÔNG nằm trong vùng lưu của app (vd /media/...) giữ nguyên, không 410', () async {
    boot((o) => o.path == '/crm/customers' ? (201, {'success': true, 'data': {'id': 9}}) : null);
    final id = await enqueue('customer', 'create', 'cust-media',
        payload: jsonEncode({'name': 'A', 'data': {'anh_cu': '/media/crm/abc.jpg'}}));

    await container.read(syncServiceProvider).syncQueue();

    expect((await row(id)).state, 'done');
  });

  group('review vòng 1 — đua giữa huỷ lượt và lô đồng bộ', () {
    test('dòng bị xoá sau lúc lô nạp vào RAM ⇒ markSending false, không gửi', () async {
      boot((o) => null);
      final id = await enqueue('visit', 'create', 'visitA', payload: '{"customer_id":10}');
      expect(await db.markSending(id), isTrue);
      await db.deletePendingVisitQueue('visitA');
      expect(await db.markSending(id), isFalse);
    });

    test('deleteUnsentVisit từ chối khi dòng tạo đang gửi, xoá khi còn chờ', () async {
      boot((o) => null);
      final create = await enqueue('visit', 'create', 'visitA', state: 'sending');
      expect(await db.deleteUnsentVisit('visitA'), isFalse);
      expect((await row(create)).state, 'sending');
      await db.reschedule(create, nextAttemptAt: 0, attempts: 0);
      expect(await db.deleteUnsentVisit('visitA'), isTrue);
      expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    });

    test('lệnh huỷ mà check-in đã xong nhưng thiếu mã server ⇒ báo lỗi (dead), không đánh dấu xong', () async {
      boot((o) => null);
      await enqueue('visit', 'create', 'visitA', state: 'done');
      final cancel = await enqueue('visit', 'cancel', 'cancel-1', parent: 'visitA', payload: '{"visit_id":0}');

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(cancel)).state, 'dead');
    });
  });

  group('review vòng 1 — sửa điểm bán', () {
    Future<void> seed(String uuid, {int? id}) => db.insertOrUpdateCustomer(LocalCustomersCompanion(
          id: Value(id),
          clientUuid: Value(uuid),
          name: const Value('Điểm bán A'),
          nameUnaccent: const Value('diem ban a'),
          phone: const Value('0909000111'),
          address: const Value('Hà Nội'),
          contactPerson: const Value('Chủ'),
          syncStatus: const Value('pending'),
        ));

    test('lệnh sửa cũ còn chờ + dòng tạo bị từ chối rồi sửa tiếp ⇒ lệnh sửa cũ mang giá trị MỚI', () async {
      boot((o) => null);
      await db.setOwner(7);
      await seed('cust-1');
      await enqueue('customer', 'create', 'cust-1', payload: '{"name":"Điểm bán A"}', state: 'dead');
      final u1 = await enqueue('customer', 'update', 'cust-1', payload: '{"name":"X"}', serverId: 0);
      await db.update(db.syncQueueEntries).write(const SyncQueueEntriesCompanion(ownerUserId: Value(7)));

      await CustomerLocalDataSource(db).updateCustomerOffline('cust-1', {'name': 'Y'});

      expect(jsonDecode((await row(u1)).payload)['name'], 'Y', reason: 'lỗi: U1 chạy sau dòng tạo, đè X lên Y');
    });

    test('sửa có danh sách ảnh ⇒ bỏ đường dẫn ảnh cũ (local_photo_paths) khỏi dòng tạo', () async {
      boot((o) => null);
      await db.setOwner(7);
      await seed('cust-1');
      final create = await enqueue('customer', 'create', 'cust-1',
          payload: jsonEncode({'name': 'A', 'local_photo_paths': ['/x/mat.jpg'], 'photo': '/x/mat.jpg'}), state: 'dead');
      await db.update(db.syncQueueEntries).write(const SyncQueueEntriesCompanion(ownerUserId: Value(7)));

      await CustomerLocalDataSource(db).updateCustomerOffline('cust-1', {
        'photo_tokens': ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'],
      });

      final p = jsonDecode((await row(create)).payload) as Map;
      expect(p.containsKey('local_photo_paths'), isFalse);
      expect(p.containsKey('photo'), isFalse);
      expect(p['photo_tokens'], ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa']);
      expect((await row(create)).state, 'pending');
    });

    test('dòng tạo đã bị dọn, điểm bán có mã server ⇒ xếp lệnh SỬA, không tạo lại dòng TẠO', () async {
      boot((o) => null);
      await db.setOwner(7);
      await seed('cust-1', id: 55);

      await CustomerLocalDataSource(db).updateCustomerOffline('cust-1', {'name': 'B'});

      final rows = await db.select(db.syncQueueEntries).get();
      expect(rows.single.op, 'update');
      expect(rows.single.serverId, 55);
    });
  });

  group('review vòng 2', () {
    test('lệnh sửa chưa có mã (serverId 0) của hai điểm bán KHÔNG bị gộp vào nhau', () async {
      boot((o) => null);
      await db.setOwner(7);
      final ds = CustomerLocalDataSource(db);
      await ds.enqueueCustomerUpdate(serverId: 0, clientUuid: 'A', changes: {'name': 'Tên A'}, nowMs: 1);
      await ds.enqueueCustomerUpdate(serverId: 0, clientUuid: 'B', changes: {'name': 'Tên B'}, nowMs: 2);

      final rows = await (db.select(db.syncQueueEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(rows.map((r) => r.clientUuid).toList(), ['A', 'B']);
      expect(jsonDecode(rows.first.payload)['name'], 'Tên A');
    });

    test('huỷ lượt có check-in bị từ chối ⇒ xoá trọn (dòng tạo dead + phiếu), không để phiếu nổi lỗi', () async {
      boot((o) => null);
      await enqueue('visit', 'create', 'visitA', state: 'dead');
      await enqueue('form_submission', 'create', 'f1', parent: 'visitA');

      expect(await db.deleteUnsentVisit('visitA'), isTrue);
      expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    });

    test('đường dẫn ảnh CŨ của app (thư mục iOS trước cập nhật) mất tệp ⇒ vẫn báo lỗi 410', () async {
      boot((o) => null);
      final id = await enqueue('customer', 'create', 'cust-ios', payload: jsonEncode({
        'name': 'A',
        'local_photo_paths': ['/var/mobile/Containers/Data/Application/OLD-UUID/Documents/offline_customer_photos/x.jpg'],
      }));

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(id)).state, 'dead');
    });
  });

  test('#24618 lượt chấm công từ hàng đợi gửi kèm is_offline_sync + queued_seconds', () async {
    boot((o) => o.path == '/attendance/mobile/punch' ? (201, {'success': true, 'data': {'id': 5}}) : null);
    await enqueue('attendance_punch', 'create', '11111111-1111-4111-8111-111111111111',
        payload: '{"client_uuid":"11111111-1111-4111-8111-111111111111","lat":"1","lng":"1"}');

    await container.read(syncServiceProvider).syncQueue();

    final sent = adapter.calls.singleWhere((c) => c.path == '/attendance/mobile/punch').data as Map;
    expect(sent['is_offline_sync'], '1');
    expect(sent['queued_seconds'], isA<int>());
  });

  group('nhóm 1 (rà soát 02/11) — check-in lượt sau không chết vì check-out lượt trước chưa tới', () {
    test('check-out lượt A còn chờ ⇒ check-in lượt B ĐỨNG CHỜ, không gửi; A gửi xong thì B đi', () async {
      final later = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      boot((o) => o.path == '/dms/visits' ? (201, {'success': true, 'data': {'id': 902}}) : null);
      final coA = await enqueue('visit', 'checkout', 'coA', parent: 'visitA', payload: '{"visit_id":901}', nextAttemptAt: later);
      final createB = await enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}');
      final sync = container.read(syncServiceProvider);

      await sync.syncQueue();
      expect(adapter.paths.contains('/dms/visits'), isFalse, reason: 'lỗi cũ: B gửi trước khi A check-out ⇒ 422 ⇒ dead');
      expect((await row(createB)).state, 'pending');

      await db.markDone(coA);
      await sync.syncQueue();
      expect(adapter.paths, contains('/dms/visits'));
      expect((await row(createB)).state, 'done');
    });

    test('server trả DMS_VISIT_STILL_OPEN cho check-in ⇒ giữ chờ (lượt trước sẽ được check-out/huỷ), KHÔNG dead', () async {
      boot((o) => o.path == '/dms/visits'
          ? (422, {'success': false, 'code': openVisitErrorCode, 'message': 'Bạn còn một lượt viếng thăm chưa check-out.'})
          : null);
      final createB = await enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}');

      final result = await container.read(syncServiceProvider).syncQueue();

      expect(result.deadErrors, isEmpty);
      expect((await row(createB)).state, 'pending');
    });

    test('lệnh HUỶ lượt A còn chờ cũng giữ check-in B; check-out mồ côi "sending" thì không giữ', () async {
      boot((o) => null);
      final later = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      await enqueue('visit', 'cancel', 'cxA', parent: 'visitA', payload: '{"visit_id":901}', nextAttemptAt: later);
      final b = await row(await enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}'));
      expect(await db.isVisitCreateHeld(b), isTrue);

      await db.delete(db.syncQueueEntries).go();
      await enqueue('visit', 'checkout', 'coA', parent: 'visitA', state: 'sending');
      final b2 = await row(await enqueue('visit', 'create', 'visitB2', payload: '{"customer_id":10}'));
      expect(await db.isVisitCreateHeld(b2), isFalse);
    });

    test('DMS_VISIT_STILL_OPEN quá trần số lần ⇒ báo lỗi (dead), không thử mãi', () async {
      boot((o) => o.path == '/dms/visits'
          ? (422, {'success': false, 'code': openVisitErrorCode, 'message': 'Bạn còn một lượt viếng thăm chưa check-out.'})
          : null);
      final createB = await enqueue('visit', 'create', 'visitB',
          payload: jsonEncode({'customer_id': 10, openVisitCountKey: openVisitMaxAttempts - 1}));

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(createB)).state, 'dead');
      final sent = adapter.calls.firstWhere((c) => c.path == '/dms/visits').data as Map;
      expect(sent.containsKey(openVisitCountKey), isFalse, reason: 'khoá nội bộ không được gửi lên server');
    });

    test('bộ đếm STILL_OPEN không tính lỗi mạng trước đó và không bị "Đồng bộ ngay" xoá', () async {
      boot((o) => o.path == '/dms/visits'
          ? (422, {'success': false, 'code': openVisitErrorCode, 'message': 'còn lượt'})
          : null);
      final createB = await enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}');
      await (db.update(db.syncQueueEntries)..where((t) => t.id.equals(createB)))
          .write(const SyncQueueEntriesCompanion(attempts: Value(50)));

      await container.read(syncServiceProvider).syncQueue(force: true);
      await container.read(syncServiceProvider).syncQueue(force: true);

      final r = await row(createB);
      expect(r.state, 'pending', reason: 'lỗi mạng cũ (attempts 50) không được tính vào trần');
      expect(jsonDecode(r.payload)[openVisitCountKey], 2);
    });

    test('422 khác của check-in vẫn là lỗi vĩnh viễn', () async {
      boot((o) => o.path == '/dms/visits' ? (422, {'success': false, 'message': 'Ngoài vùng điểm bán'}) : null);
      final createB = await enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}');

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(createB)).state, 'dead');
    });
  });

  group('#1 AuthInterceptor chỉ xoá phiên khi máy chủ TỪ CHỐI phiên làm mới', () {
    late _Adapter main;

    Future<void> seedTokens() => SharedPreferences.getInstance().then((p) async {
          await p.setString(AppConstants.keyAccessToken, 'old');
          await p.setString(AppConstants.keyRefreshToken, 'refresh-old');
        });

    ApiClient client(_Adapter refresh) {
      main = _Adapter((o) => o.headers['Authorization'] == 'Bearer new'
          ? (422, {'success': false, 'message': 'Lượt viếng thăm này đã check-out rồi.'})
          : (401, {'success': false, 'message': 'hết hạn'}));
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = main;
      dio.interceptors.add(AuthInterceptor(dio, refreshDio: () => Dio()..httpClientAdapter = refresh));
      return ApiClient(dio);
    }

    setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
    setUp(() => container = ProviderContainer());

    test('mất mạng lúc xin phiên mới ⇒ GIỮ phiên, trả lỗi mạng (hàng đợi thử lại)', () async {
      await seedTokens();
      final api = client(_Adapter((_) => null, networkDown: true));

      await expectLater(api.post('/dms/visits', data: {}), throwsA(isA<NetworkException>()));
      expect((await SharedPreferences.getInstance()).getString(AppConstants.keyRefreshToken), 'refresh-old',
          reason: 'lỗi cũ: sóng chập là bị đăng xuất');
    });

    test('/auth/refresh trả 429 (proxy quá tải) ⇒ GIỮ phiên', () async {
      await seedTokens();
      final api = client(_Adapter((_) => (429, {'success': false})));

      await expectLater(api.post('/dms/visits', data: {}), throwsA(isA<AppException>()));
      expect((await SharedPreferences.getInstance()).getString(AppConstants.keyRefreshToken), 'refresh-old');
    });

    test('máy chủ từ chối phiên làm mới (401) ⇒ xoá phiên', () async {
      await seedTokens();
      final api = client(_Adapter((_) => (401, {'success': false})));

      await expectLater(api.post('/dms/visits', data: {}), throwsA(isA<AppException>()));
      expect((await SharedPreferences.getInstance()).getString(AppConstants.keyRefreshToken), isNull);
    });

    test('làm mới xong, lần gửi lại bị 422 ⇒ trả đúng 422, GIỮ phiên mới', () async {
      await seedTokens();
      final api = client(_Adapter((_) => (200, {
            'success': true,
            'data': {'access_token': 'new', 'refresh_token': 'refresh-new'},
          })));

      await expectLater(
        api.post('/dms/visits', data: {}),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 422)),
      );
      expect((await SharedPreferences.getInstance()).getString(AppConstants.keyRefreshToken), 'refresh-new',
          reason: 'lỗi cũ: lỗi của lần gửi lại cũng xoá phiên');
    });
  });
}

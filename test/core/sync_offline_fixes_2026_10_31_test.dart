import 'dart:convert';
import 'dart:io';

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
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/core/sync/sync_entity_group.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

/// Rà soát luồng offline 31/10/2026 — mỗi nhóm tái hiện một lỗi đã vá trong SyncService / AppDatabase.

typedef _Handler = (int, Map<String, dynamic>)? Function(RequestOptions o);

class _Adapter implements HttpClientAdapter {
  final _Handler handler;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    final r = handler(o) ?? (200, {'success': true, 'data': <dynamic>[]});
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
          {String? parent,
          String payload = '{}',
          String? localPath,
          int? serverId,
          String state = 'pending',
          int? nextAttemptAt}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: payload,
        localPath: Value(localPath),
        serverId: Value(serverId),
        state: Value(state),
        nextAttemptAt: Value(nextAttemptAt),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  Future<SyncQueueEntry> row(int id) => (db.select(db.syncQueueEntries)..where((t) => t.id.equals(id))).getSingle();

  test('#1 đồng bộ check-in lượt A KHÔNG gán mã server của A cho lượt offline B đang mở', () async {
    boot((o) => o.path == '/dms/visits' ? (201, {'success': true, 'data': {'id': 501}}) : null);
    final repo = container.read(visitRepositoryProvider);
    final now = DateTime.now();
    final a = VisitEntity(id: -1000, customerId: 10, checkinAt: now.subtract(const Duration(hours: 1)), clientUuid: 'visitA');
    final b = VisitEntity(id: -2000, customerId: 20, checkinAt: now, clientUuid: 'visitB');
    await repo.saveLocalVisit(a);
    await repo.saveLocalVisit(b);
    await repo.saveActiveVisit(b);
    await enqueue('visit', 'create', 'visitA', payload: jsonEncode({'customer_id': 10}));

    await container.read(syncServiceProvider).syncQueue();

    final all = await repo.getAllLocalVisits();
    expect(all.firstWhere((v) => v.clientUuid == 'visitA').id, 501);
    expect(all.firstWhere((v) => v.clientUuid == 'visitB').id, -2000, reason: 'lỗi cũ: B nhận mã 501 của A');
    expect((await repo.getActiveVisit())!.id, -2000);
  });

  group('#2 check-out nhường ảnh / phiếu / vật tư chưa gửi của cùng lượt', () {
    setUp(() => boot((_) => null));

    for (final child in ['visit_photo', 'form_submission', 'visit_material']) {
      test('$child đang chờ thử lại ⇒ check-out bị giữ; dead thì thôi giữ', () async {
        final childId = await enqueue(child, 'x', 'c-$child', parent: 'visitA');
        final checkoutId = await enqueue('visit', 'checkout', 'co', parent: 'visitA');
        final checkout = await row(checkoutId);
        expect(await db.isCheckoutHeld(checkout), isTrue);
        await db.markDead(childId, 'lỗi');
        expect(await db.isCheckoutHeld(checkout), isFalse);
      });
    }

    test('ảnh/phiếu gửi hỏng lặp quá trần thì thôi giữ; chuỗi nguội không tính; vật tư vẫn giữ', () async {
      boot((_) => null);
      // 12 lần hỏng cách nhau 4 phút; mặc định lần cuối cách hiện tại 1 phút (chuỗi còn nóng).
      final freshStart = DateTime.now().millisecondsSinceEpoch - 45 * 60 * 1000;
      final oldStart = DateTime(2026, 10, 1, 8).millisecondsSinceEpoch;
      String failed(int n, {required bool serverError, int? start}) {
        var p = '{"visit_id":77}';
        for (var i = 0; i < n; i++) {
          p = recordVisitMaterialFailure(p, serverError: serverError, nowMs: (start ?? freshStart) + i * 4 * 60 * 1000).$1;
        }
        return p;
      }

      final checkout = await row(await enqueue('visit', 'checkout', 'co', parent: 'visitA'));
      const released = SyncService.releasesCheckout;

      // Chuỗi đủ trần nhưng đã nguội (lần hỏng cuối lâu rồi, máy ngoại tuyến) ⇒ không thả.
      await enqueue('visit_photo', 'upload', 'p1', parent: 'visitA', payload: failed(12, serverError: true, start: oldStart));
      expect(await db.isCheckoutHeld(checkout, released: released), isTrue, reason: 'chuỗi nguội không được thả check-out');

      await db.delete(db.syncQueueEntries).go();
      final co2 = await row(await enqueue('visit', 'checkout', 'co', parent: 'visitA'));
      await enqueue('form_submission', 'create', 'f1', parent: 'visitA', payload: failed(12, serverError: true));
      expect(await db.isCheckoutHeld(co2, released: released), isFalse);

      await enqueue('visit_material', 'save', 'm1', parent: 'visitA', payload: failed(12, serverError: true));
      expect(await db.isCheckoutHeld(co2, released: released), isTrue, reason: 'vật tư có lối thoát riêng (dead)');
    });

    test('ảnh của lượt KHÁC không giữ check-out', () async {
      await enqueue('visit_photo', 'upload', 'p1', parent: 'visitB');
      final checkout = await row(await enqueue('visit', 'checkout', 'co', parent: 'visitA'));
      expect(await db.isCheckoutHeld(checkout), isFalse);
    });

    test('vòng gửi: ảnh lỗi 5xx ⇒ check-out cùng lượt KHÔNG được gửi', () async {
      container.dispose();
      await db.close();
      boot((o) => o.path.contains('/photos') ? (500, {'success': false, 'message': 'lỗi'}) : null);
      final dir = await Directory.systemTemp.createTemp('sync_fix');
      final f = File('${dir.path}/a.jpg')..writeAsBytesSync(List.filled(10, 1));
      await enqueue('visit_photo', 'upload', 'p1', parent: 'visitA', payload: jsonEncode({'visit_id': 77}), localPath: f.path);
      final checkoutId = await enqueue('visit', 'checkout', 'co', parent: 'visitA', payload: jsonEncode({'visit_id': 77}));

      await container.read(syncServiceProvider).syncQueue();

      expect(adapter.paths.where((p) => p.endsWith('/checkout')), isEmpty);
      expect((await row(checkoutId)).state, 'pending');
    });
  });

  test('huỷ lượt ĐÃ lên server KHÔNG xoá phiếu khảo sát đã nộp; lượt CHƯA lên server thì xoá cả phiếu', () async {
    boot((_) => null);
    await enqueue('visit_photo', 'upload', 'p1', parent: 'visitA');
    final formId = await enqueue('form_submission', 'create', 'f1', parent: 'visitA');
    await db.deletePendingVisitQueue('visitA');
    expect((await db.select(db.syncQueueEntries).get()).map((e) => e.id), [formId]);

    await enqueue('visit', 'create', 'visitB');
    await enqueue('form_submission', 'create', 'f2', parent: 'visitB');
    await db.deletePendingVisitQueue('visitB');
    expect((await db.select(db.syncQueueEntries).get()).map((e) => e.id), [formId]);
  });

  test('ảnh lỗi quá giờ / chờ lượt cha: quá giờ đếm vào chuỗi, chờ lượt cha thì không', () async {
    boot((o) => o.path.contains('/photos') ? (500, {'success': false, 'message': 'lỗi'}) : null);
    final dir = await Directory.systemTemp.createTemp('sync_fix');
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync(List.filled(10, 1));
    final waiting = await enqueue('visit_photo', 'upload', 'pw', parent: 'visitZ', localPath: f.path);
    await enqueue('visit', 'create', 'visitZ', state: 'done'); // cha đã gửi nhưng thiếu serverId ⇒ chờ
    final failing = await enqueue('visit_photo', 'upload', 'pf', payload: jsonEncode({'visit_id': 77}), localPath: f.path);
    await container.read(syncServiceProvider).syncQueue(force: true);
    expect(visitMaterialServerFailures((await row(waiting)).payload), 0);
    expect(visitMaterialServerFailures((await row(failing)).payload), 1);
  });

  test('ảnh khai báo vị trí mất tệp ⇒ dead, không gửi thiếu ảnh', () async {
    boot((_) => null);
    final id = await enqueue('declaration', 'create', 'dc', payload: jsonEncode({
      'reason_id': 1,
      'lat': 21.0,
      'lng': 105.0,
      'local_photo_paths': ['/khong/co/d.jpg'],
    }));
    await container.read(syncServiceProvider).syncQueue();
    expect(adapter.paths, isNot(contains('/dms/position-declarations')));
    expect((await row(id)).state, 'dead');
  });

  test('phiếu khảo sát lượt offline: visit_id lấy từ lượt cha theo parentUuid, khoá nội bộ không lên server', () async {
    boot((o) => o.path == '/dms/form-submissions' ? (201, {'success': true, 'data': {'id': 9}}) : null);
    await enqueue('visit', 'create', 'visitA', serverId: 501, state: 'done');
    final payload = recordVisitMaterialFailure(jsonEncode({'config_id': 1, 'visit_id': -123, 'answers': {}}),
            serverError: true, nowMs: 1)
        .$1;
    final id = await enqueue('form_submission', 'create', 'f1', parent: 'visitA', payload: payload);
    await container.read(syncServiceProvider).syncQueue();
    final body = adapter.calls.firstWhere((c) => c.path == '/dms/form-submissions').data as Map<String, dynamic>;
    expect(body['visit_id'], 501);
    expect(body.keys.where((k) => k.startsWith('_server_failure')), isEmpty);
    expect((await row(id)).state, 'done');
  });

  test('#3 ảnh chấm công có lượt cha chưa đồng bộ ⇒ CHỜ, không gắn vào lượt chấm cũ', () async {
    boot((_) => null);
    await enqueue('attendance_punch', 'create', 'oldPunch', serverId: 77, state: 'done');
    // Lượt chấm cha từng lỗi, đang chờ thử lại ⇒ vòng này chỉ thấy ảnh.
    final later = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
    await enqueue('attendance_punch', 'create', 'newPunch',
        payload: jsonEncode({'client_uuid': 'newPunch'}), nextAttemptAt: later);
    final dir = await Directory.systemTemp.createTemp('sync_fix');
    final f = File('${dir.path}/p.jpg')..writeAsBytesSync(List.filled(10, 1));
    final photoId = await enqueue('attendance_photo', 'upload', 'ph', parent: 'newPunch', localPath: f.path);

    await container.read(syncServiceProvider).syncQueue();

    expect(adapter.paths.where((p) => p.contains('/punches/77/photos')), isEmpty, reason: 'lỗi cũ: ảnh đổ vào lượt 77');
    expect((await row(photoId)).state, 'pending');
  });

  test('#4 tải ảnh phiếu lỗi ⇒ phiếu KHÔNG được nộp thiếu ảnh, mục chờ thử lại', () async {
    boot((o) => o.path == '/dms/form-photos' ? (500, {'success': false, 'message': 'lỗi'}) : null);
    final dir = await Directory.systemTemp.createTemp('sync_fix');
    final f = File('${dir.path}/f.jpg')..writeAsBytesSync(List.filled(10, 1));
    final id = await enqueue('form_submission', 'create', 'fs', payload: jsonEncode({
      'config_id': 1,
      'answers': {'anh': [f.path]},
      '_local_photo_paths': {'anh': [f.path]},
    }));

    await container.read(syncServiceProvider).syncQueue();

    expect(adapter.paths, isNot(contains('/dms/form-submissions')));
    expect((await row(id)).state, 'pending');
  });

  test('#4 tải ảnh khai báo vị trí lỗi ⇒ không gửi khai báo thiếu ảnh', () async {
    boot((o) => o.path == '/dms/position-photos' ? (500, {'success': false, 'message': 'lỗi'}) : null);
    final dir = await Directory.systemTemp.createTemp('sync_fix');
    final f = File('${dir.path}/d.jpg')..writeAsBytesSync(List.filled(10, 1));
    final id = await enqueue('declaration', 'create', 'dc', payload: jsonEncode({
      'reason_id': 1,
      'lat': 21.0,
      'lng': 105.0,
      'local_photo_paths': [f.path],
    }));

    await container.read(syncServiceProvider).syncQueue();

    expect(adapter.paths, isNot(contains('/dms/position-declarations')));
    expect((await row(id)).state, 'pending');
  });

  group('#5 không tự đánh dấu "đã gửi" khi chưa gửi', () {
    test('loại mục lạ ⇒ dead', () async {
      boot((_) => null);
      final id = await enqueue('la_lam', 'create', 'u1');
      await container.read(syncServiceProvider).syncQueue();
      expect((await row(id)).state, 'dead');
    });

    test('ảnh viếng thăm mất tệp ⇒ dead', () async {
      boot((_) => null);
      final id = await enqueue('visit_photo', 'upload', 'p1',
          payload: jsonEncode({'visit_id': 77}), localPath: '/khong/co/tep.jpg');
      await container.read(syncServiceProvider).syncQueue();
      expect((await row(id)).state, 'dead');
    });

    test('ảnh của phiếu mất tệp ⇒ dead, không nộp phiếu thiếu ảnh', () async {
      boot((_) => null);
      final id = await enqueue('form_submission', 'create', 'fs', payload: jsonEncode({
        'config_id': 1,
        'answers': {'anh': ['/khong/co/a.jpg']},
        '_local_photo_paths': {'anh': ['/khong/co/a.jpg']},
      }));
      await container.read(syncServiceProvider).syncQueue();
      expect(adapter.paths, isNot(contains('/dms/form-submissions')));
      expect((await row(id)).state, 'dead');
    });

    test('422 chứa "đã đóng" ở mục KHÔNG phải check-out ⇒ dead, không nuốt', () async {
      boot((o) => o.path == '/dms/form-submissions' ? (422, {'success': false, 'message': 'Tuyến đã đóng.'}) : null);
      final id = await enqueue('form_submission', 'create', 'fs', payload: jsonEncode({'config_id': 1, 'answers': {}}));
      await container.read(syncServiceProvider).syncQueue();
      expect((await row(id)).state, 'dead');
    });

    test('422 "đã check-out rồi" ở check-out ⇒ vẫn coi là xong', () async {
      boot((o) => o.path.endsWith('/checkout') ? (422, {'success': false, 'message': 'Lượt đã check-out rồi.'}) : null);
      final id = await enqueue('visit', 'checkout', 'co', parent: 'visitA', payload: jsonEncode({'visit_id': 77}));
      await container.read(syncServiceProvider).syncQueue();
      expect((await row(id)).state, 'done');
    });
  });

  group('#6 lượt check-in của điểm bán tạo offline', () {
    test('check-in mang customer_client_uuid: nhận đúng serverId của điểm bán cha sau khi điểm bán lên server', () async {
      boot((o) {
        if (o.method == 'POST' && o.path == '/crm/customers') {
          return (201, {'success': true, 'data': {'id': 99, 'code': 'DB99'}});
        }
        if (o.path == '/dms/visits') {
          final body = o.data is Map ? o.data as Map : jsonDecode(o.data.toString()) as Map;
          expect(body['customer_id'], 99, reason: 'Phải nhận đúng serverId của điểm bán cha');
          return (201, {'success': true, 'data': {'id': 501}});
        }
        return null;
      });

      final custId = await enqueue('customer', 'create', 'custA', payload: jsonEncode({'name': 'Đại lý A'}));
      final visitId = await enqueue('visit', 'create', 'visitA', payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': 'custA'}));

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(custId)).state, 'done');
      expect((await row(visitId)).state, 'done');
      expect(adapter.paths, contains('/crm/customers'));
      expect(adapter.paths, contains('/dms/visits'));
    });

    test('check-in mang customer_id <= 0 nhưng thiếu cả parentUuid và customer_client_uuid ⇒ dead (422), không gửi 0 lên server', () async {
      boot((_) => null);
      final visitId = await enqueue('visit', 'create', 'visitNoParent', payload: jsonEncode({'customer_id': 0}));

      await container.read(syncServiceProvider).syncQueue();

      expect((await row(visitId)).state, 'dead');
      expect(adapter.paths, isNot(contains('/dms/visits')));
    });

    test('performCheckin ghi customer_client_uuid vào payload khi customerId <= 0', () async {
      boot((o) => throw DioException.connectionError(requestOptions: o, reason: 'Mất kết nối mạng'));
      final vm = container.read(checkInViewModelProvider.notifier);

      const customer = CustomerEntity(
        id: 0,
        code: 'PENDING_ABC',
        name: 'Đại lý Offline Mới',
        clientUuid: 'cust_offline_uuid_888',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Hà Nội',
        contactPerson: 'Nguyễn Văn A',
        phone: '0901234567',
        status: 'active',
        approvalStatus: 'pending',
        syncStatus: 'pending',
      );

      const dealer = DealerEntity(
        id: '0',
        order: '01',
        name: 'Đại lý Offline Mới',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        customer: customer,
      );

      vm.initCheckinWithDealer(dealer);
      final error = await vm.performCheckin(customerId: 0);

      expect(error, isNull);
      final entries = await db.getAllPendingQueueEntries();
      final visitEntry = entries.firstWhere((e) => e.entity == 'visit' && e.op == 'create');

      final payload = jsonDecode(visitEntry.payload) as Map<String, dynamic>;
      expect(payload['customer_client_uuid'], 'cust_offline_uuid_888');
      expect(visitEntry.parentUuid, isNull, reason: 'parentUuid của visit/create để rỗng để gom nhóm theo clientUuid của lượt');
    });

    test('deletePendingCustomer dọn sạch cả lượt viếng thăm và các mục con (ảnh, check-out)', () async {
      boot((_) => null);
      const custUuid = 'cust_delete_tree_uuid';
      const visitUuid = 'visit_session_tree_uuid';

      await enqueue('customer', 'create', custUuid, payload: jsonEncode({'name': 'Đại lý chuẩn bị xoá'}));
      await enqueue('visit', 'create', visitUuid, payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': custUuid}));
      await enqueue('visit_photo', 'upload', 'p1', parent: visitUuid, payload: jsonEncode({'visit_id': -1}));
      await enqueue('visit', 'checkout', 'co1', parent: visitUuid, payload: jsonEncode({'visit_id': -1}));

      final before = await db.getAllPendingQueueEntries();
      expect(before.length, 4);

      await db.deletePendingCustomer(custUuid);

      final after = await db.getAllPendingQueueEntries();
      expect(after, isEmpty, reason: 'Tất cả các mục con (visit, photo, checkout) phải được dọn sạch, không để lại mồ côi');
    });

    test('SyncEntityGroupHelper không tách đôi lượt viếng thăm của điểm bán offline', () async {
      boot((_) => null);
      const custUuid = 'cust_group_uuid';
      const visitUuid = 'visit_group_uuid';

      final eVisit = SyncQueueEntry(
        id: 1,
        entity: 'visit',
        op: 'create',
        clientUuid: visitUuid,
        parentUuid: null,
        payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': custUuid, 'dealer_name': 'Tạp hoá Lan Rừng'}),
        state: 'pending',
        attempts: 0,
        createdAt: 1000,
        createdElapsed: 1000,
        bootId: 'b1',
      );

      final ePhoto = SyncQueueEntry(
        id: 2,
        entity: 'visit_photo',
        op: 'upload',
        clientUuid: 'photo_1',
        parentUuid: visitUuid,
        payload: jsonEncode({'visit_id': -1}),
        state: 'pending',
        attempts: 0,
        createdAt: 2000,
        createdElapsed: 2000,
        bootId: 'b1',
      );

      final eCheckout = SyncQueueEntry(
        id: 3,
        entity: 'visit',
        op: 'checkout',
        clientUuid: 'co_1',
        parentUuid: visitUuid,
        payload: jsonEncode({'visit_id': -1}),
        state: 'pending',
        attempts: 0,
        createdAt: 3000,
        createdElapsed: 3000,
        bootId: 'b1',
      );

      final groups = SyncEntityGroupHelper.groupEntries([eVisit, ePhoto, eCheckout]);
      expect(groups.length, 1, reason: 'Tất cả các mục của lượt viếng thăm phải được gom vào cùng 1 nhóm duy nhất');
      expect(groups.first.title, contains('Tạp hoá Lan Rừng'));
      expect(groups.first.subtitle, contains('Đã check-out'));
      expect(groups.first.subtitle, contains('Kèm 1 ảnh'));
    });
  });

  group('#7 xoá ảnh offline và huỷ ảnh khi đang tải', () {
    test('vm.deletePhoto dọn sạch ảnh offline trong state và bảng sync_queue_entries', () async {
      boot((o) => throw DioException.connectionError(requestOptions: o, reason: 'Mất kết nối mạng'));
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Đại lý 101',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);

      final dir = await Directory.systemTemp.createTemp('photo_del_test');
      final f = File('${dir.path}/test_del.jpg')..writeAsBytesSync(List.filled(20, 5));

      final res = await vm.uploadPhoto(
        f,
        photoType: 'store_front',
        lat: 21.0,
        lng: 105.0,
      );
      expect(res.$1, isTrue);

      final photosBefore = vm.state.photos;
      expect(photosBefore, hasLength(1));
      final photo = photosBefore.first;

      final queueEntriesBefore = await db.getAllPendingQueueEntries();
      final photoQueue = queueEntriesBefore.where((e) => e.entity == 'visit_photo').toList();
      expect(photoQueue, hasLength(1));

      // Xoá ảnh qua ViewModel
      final delRes = await vm.deletePhoto(photo.id);
      expect(delRes.$1, isTrue);
      expect(vm.state.photos, isEmpty);

      final queueEntriesAfter = await db.getAllPendingQueueEntries();
      expect(queueEntriesAfter.where((e) => e.entity == 'visit_photo'), isEmpty,
          reason: 'deletePhoto phải xoá sạch dòng hàng đợi visit_photo');
    });

    test('phiên online: ảnh bị xoá trước khi upload thất bại ⇒ không đưa vào hàng đợi offline', () async {
      // Giả lập online: checkin thành công
      boot((o) {
        if (o.path == '/dms/visits') {
          return (201, {'success': true, 'data': {'id': 701}});
        }
        if (o.path == '/dms/visits/701/photos') {
          // Upload ảnh bị lỗi mạng
          throw DioException.connectionError(requestOptions: o, reason: 'Timeout');
        }
        return null;
      });

      final vm = container.read(checkInViewModelProvider.notifier);
      const dealer = DealerEntity(
        id: '202',
        order: '01',
        name: 'Đại lý 202',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 202);
      expect(vm.state.visitId, 701);

      final dir = await Directory.systemTemp.createTemp('in_flight_test');
      final f = File('${dir.path}/inflight.jpg')..writeAsBytesSync(List.filled(20, 5));

      // Xoá tệp trước khi upload hoàn thành để giả lập người dùng xoá ảnh giữa chừng
      f.deleteSync();

      final res = await vm.uploadPhoto(
        f,
        photoType: 'store_front',
        lat: 21.0,
        lng: 105.0,
      );
      expect(res.$1, isFalse);

      final queueEntries = await db.getAllPendingQueueEntries();
      expect(queueEntries.where((e) => e.entity == 'visit_photo'), isEmpty,
          reason: 'Ảnh đã bị xoá tệp không được đưa vào hàng đợi offline, tránh lỗi 410');
    });
  });
}

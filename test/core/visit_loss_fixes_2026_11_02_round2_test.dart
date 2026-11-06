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
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

/// Rà soát offline vòng 2 (02/11/2026, #24698): 2 lỗi nặng + 3 lỗi mất lượt — mỗi nhóm tái hiện một lỗi đã vá.

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



  CustomerEntity offlineCustomer(String uuid, String name) => CustomerEntity(
        id: 0,
        code: 'PENDING_$uuid',
        name: name,
        clientUuid: uuid,
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Hà Nội',
        contactPerson: 'A',
        phone: '0901234567',
        status: 'active',
        approvalStatus: 'pending',
        syncStatus: 'pending',
      );

  DealerEntity dealerOf(CustomerEntity c) => DealerEntity(
        id: c.id.toString(),
        order: '01',
        name: c.name,
        address: c.address,
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        customer: c,
      );

  group('H1 điểm bán tạo ngoại tuyến (id 0) không gộp lượt', () {
    test('isAtCustomer: id server so id; id 0 so client_uuid; thiếu uuid thì không coi là cùng', () {
      boot((_) => null);
      const a = VisitEntity(id: -1, customerId: 0, customerClientUuid: 'cA');
      expect(a.isAtCustomer(0, 'cA'), isTrue);
      expect(a.isAtCustomer(0, 'cB'), isFalse, reason: 'lỗi cũ: 0 == 0 ⇒ lượt A hiện ở điểm B');
      expect(a.isAtCustomer(123, 'cA'), isTrue, reason: 'điểm bán vừa đồng bộ, lượt còn mang uuid');
      expect(a.isAtCustomer(0, null), isFalse);
      // Lượt CŨ (bản app trước: customerId 0, không uuid) giữ cách so cũ để còn vào lại / check-out được.
      const legacy = VisitEntity(id: 9, customerId: 0);
      expect(legacy.isAtCustomer(0), isTrue);
      expect(legacy.isAtCustomer(5), isFalse);
      const online = VisitEntity(id: 5, customerId: 7);
      expect(online.isAtCustomer(7), isTrue);
      expect(online.isAtCustomer(8), isFalse);
    });

    test('bản lưu lượt đang mở ở điểm bán ngoại tuyến được GIỮ (trước đây getActiveVisit xoá vì id ≤ 0)', () async {
      boot((_) => null);
      final repo = container.read(visitRepositoryProvider);
      await repo.saveActiveVisit(
          VisitEntity(id: -9, customerId: 0, customerClientUuid: 'cA', clientUuid: 'v1', checkinAt: DateTime.now()));
      expect((await repo.getActiveVisit())?.customerClientUuid, 'cA');
      await repo.saveActiveVisit(const VisitEntity(id: -9, customerId: 0, clientUuid: 'v2'));
      expect(await repo.getActiveVisit(), isNull, reason: 'bản lưu hỏng (không id, không điểm bán) vẫn bỏ');
    });

    test('check-in điểm A (id 0) khi CÓ MẠNG đi hàng đợi kèm customer_client_uuid; sang điểm B (id 0) bị chặn', () async {
      boot((_) => null);
      final vm = container.read(checkInViewModelProvider.notifier);
      final a = offlineCustomer('cA', 'Điểm A');
      vm.initCheckinWithDealer(dealerOf(a));
      expect(await vm.performCheckin(customerId: 0), isNull);
      expect(adapter.paths.where((p) => p == '/dms/visits'), isEmpty, reason: 'server không mở lượt cho id 0');
      final create = (await db.getAllPendingQueueEntries()).firstWhere((e) => e.entity == 'visit' && e.op == 'create');
      expect(jsonDecode(create.payload)['customer_client_uuid'], 'cA');
      final active = await container.read(visitRepositoryProvider).getActiveVisit();
      expect(active?.customerClientUuid, 'cA');

      // Điểm B (cũng id 0): KHÔNG được coi là điểm đang mở lượt — lỗi cũ: 0 == 0 ⇒ "quay lại đúng điểm đang mở", lượt A
      // phục hồi dưới tên B. Phiên A giữ nguyên (initCheckinWithDealer bỏ qua dealer khác).
      final b = offlineCustomer('cB', 'Điểm B');
      expect(active!.isAtCustomer(b.id, b.clientUuid), isFalse);
      vm.initCheckinWithDealer(dealerOf(b));
      expect(container.read(checkInViewModelProvider).visitEntity?.customerClientUuid, 'cA');
      expect(container.read(checkInViewModelProvider).customer, a);
    });

    test('điểm id 0 không nhận diện được (không uuid) ⇒ báo lỗi, KHÔNG xếp hàng lượt không khoá điểm bán', () async {
      boot((_) => null);
      final vm = container.read(checkInViewModelProvider.notifier);
      const c = CustomerEntity(
        id: 0,
        code: 'X',
        name: 'Điểm lạ',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Hà Nội',
        contactPerson: 'A',
        phone: '0901234567',
        status: 'active',
      );
      vm.initCheckinWithDealer(dealerOf(c));
      expect(await vm.performCheckin(customerId: 0), contains('Không xác định được điểm bán'));
      expect(await db.getAllPendingQueueEntries(), isEmpty);
    });

    test('đồng bộ check-in: lượt nhận id server của điểm bán cha (không còn customerId 0)', () async {
      boot((o) => o.path == '/dms/visits' ? (201, {'success': true, 'data': {'id': 501}}) : null);
      final repo = container.read(visitRepositoryProvider);
      final v = VisitEntity(id: -1, customerId: 0, customerClientUuid: 'cA', clientUuid: 'vA', checkinAt: DateTime.now());
      await repo.saveLocalVisit(v);
      await repo.saveActiveVisit(v);
      await enqueue('customer', 'create', 'cA', serverId: 777, state: 'done');
      await enqueue('visit', 'create', 'vA', payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': 'cA'}));

      await container.read(syncServiceProvider).syncQueue();

      final active = await repo.getActiveVisit();
      expect(active?.id, 501);
      expect(active?.customerId, 777);
      expect((await repo.getAllLocalVisits()).firstWhere((x) => x.clientUuid == 'vA').customerId, 777);
    });
  });

  test('H2 check-in trực tuyến CHỜ lệnh lượt trước còn trong hàng đợi (gửi trước), không mở lượt mới trước nó', () async {
    final order = <String>[];
    boot((o) {
      order.add('${o.method} ${o.path}');
      if (o.path == '/dms/visits' && o.method == 'POST') {
        final body = o.data is Map ? o.data as Map : jsonDecode(o.data.toString()) as Map;
        return (201, {'success': true, 'data': {'id': body['client_uuid'] == 'vA' ? 501 : 502, 'customer_id': body['customer_id']}});
      }
      if (o.path.endsWith('/checkout')) return (200, {'success': true, 'data': {'id': 501}});
      return null;
    });
    // Lượt A làm lúc mất mạng: check-in + check-out còn chờ.
    await enqueue('visit', 'create', 'vA', payload: jsonEncode({'customer_id': 10}));
    await enqueue('visit', 'checkout', 'coA', parent: 'vA', payload: jsonEncode({'visit_id': -1}));

    final vm = container.read(checkInViewModelProvider.notifier);
    const c = CustomerEntity(
      id: 20,
      code: 'KH20',
      name: 'Điểm 20',
      type: 'Đại lý',
      route: 'Tuyến 1',
      address: 'Hà Nội',
      contactPerson: 'A',
      phone: '0901234567',
      status: 'active',
    );
    vm.initCheckinWithDealer(dealerOf(c));
    expect(await vm.performCheckin(customerId: 20), isNull);

    final posts = order.where((e) => e.startsWith('POST')).toList();
    expect(posts.indexWhere((e) => e.endsWith('/checkout')), lessThan(posts.lastIndexOf('POST /dms/visits')),
        reason: 'check-out của A phải lên trước check-in của B');
    expect(await db.hasOpenVisitLifecycleEntries(), isFalse);
  });

  test('H2 chuỗi lượt của điểm bán ngoại tuyến bị server từ chối KHÔNG đẩy mọi check-in về sau xuống hàng đợi', () async {
    boot((_) => null);
    final custId = await enqueue('customer', 'create', 'cX');
    await db.markDead(custId, 'Điểm bán bị từ chối');
    await enqueue('visit', 'create', 'vX', payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': 'cX'}));
    await enqueue('visit', 'checkout', 'coX', parent: 'vX');
    expect(await db.hasOpenVisitLifecycleEntries(), isFalse);
    await enqueue('visit', 'checkout', 'coY', parent: 'vY');
    expect(await db.hasOpenVisitLifecycleEntries(), isTrue, reason: 'lượt khác còn lệnh chờ thì vẫn phải chờ');
  });

  test('H2 lượt kẹt (điểm bán bị từ chối) không giữ dòng tạo lượt sau trong hàng đợi; lệnh SỬA bị từ chối không làm kẹt', () async {
    boot((_) => null);
    final custId = await enqueue('customer', 'create', 'cX');
    await db.markDead(custId, 'Điểm bán bị từ chối');
    await enqueue('visit', 'create', 'vX', payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': 'cX'}));
    await enqueue('visit', 'checkout', 'coX', parent: 'vX');
    final yId = await enqueue('visit', 'create', 'vY', payload: jsonEncode({'customer_id': 20}));
    expect(await db.isVisitCreateHeld(await (db.select(db.syncQueueEntries)..where((t) => t.id.equals(yId))).getSingle()),
        isFalse);

    // Điểm bán cZ đã tạo xong, lệnh SỬA bị từ chối: lượt ở cZ vẫn đi tiếp được ⇒ vẫn phải chờ nó.
    await enqueue('customer', 'create', 'cZ', state: 'done', serverId: 55);
    final upd = await enqueue('customer', 'update', 'cZ');
    await db.markDead(upd, 'Sửa bị từ chối');
    await enqueue('visit', 'create', 'vZ', payload: jsonEncode({'customer_id': 0, 'customer_client_uuid': 'cZ'}));
    expect(await db.hasOpenVisitLifecycleEntries(), isTrue);
  });

  test('H2 không có lệnh lượt nào ⇒ check-in KHÔNG chờ lượt đồng bộ đang chạy', () async {
    boot((_) => null);
    await enqueue('visit_photo', 'upload', 'p1', parent: 'vDone');
    final sw = Stopwatch()..start();
    expect(await container.read(syncServiceProvider).flushVisitLifecycle(timeout: const Duration(seconds: 5)), isTrue);
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(adapter.calls, isEmpty);
  });

  test('H2 lịch thử lại được tôn trọng: mục chưa tới lượt không bị đẩy (check-in mới đi hàng đợi)', () async {
    boot((_) => null);
    await enqueue('visit', 'checkout', 'coA',
        parent: 'vA', nextAttemptAt: DateTime.now().add(const Duration(minutes: 3)).millisecondsSinceEpoch);
    expect(await db.getPendingVisitLifecycleEntries(), isEmpty);
    expect(await container.read(syncServiceProvider).flushVisitLifecycle(), isFalse);
    expect(adapter.calls, isEmpty);
  });

  test('M1 đồng bộ lệnh HUỶ lượt A không xoá bản lưu lượt đang mở B', () async {
    boot((_) => (200, {'success': true, 'data': {}}));
    final repo = container.read(visitRepositoryProvider);
    final b = VisitEntity(id: 600, customerId: 20, clientUuid: 'vB', checkinAt: DateTime.now());
    await repo.saveActiveVisit(b);
    await enqueue('visit', 'cancel', 'cxA', parent: 'vA', payload: jsonEncode({'visit_id': 501}));

    await container.read(syncServiceProvider).syncQueue();

    expect((await repo.getActiveVisit())?.clientUuid, 'vB', reason: 'lỗi cũ: clearActiveVisit() vô điều kiện');

    // Huỷ ĐÚNG lượt đang mở thì vẫn bỏ bản lưu.
    await enqueue('visit', 'cancel', 'cxB', parent: 'vB', payload: jsonEncode({'visit_id': 600}));
    await container.read(syncServiceProvider).syncQueue();
    expect(await repo.getActiveVisit(), isNull);
  });

  // M2 (lượt vắt qua nửa đêm bị bỏ khỏi máy) — KIỂM CHỨNG LÀ BÁO NHẦM: getVisitsByDate(hôm nay) luôn ghép lượt đang mở
  // lưu trên máy vào danh sách hôm nay ⇒ nhánh bỏ bản lưu "ngày khác" không tới được. Test giữ hành vi đó. Lượt đã lên
  // server thì server phải còn trả nó là mở — server không còn thì tuyến dọn (stale_saved_visit_not_open_test.dart).
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  for (final (label, saved) in [
    ('đã lên server', VisitEntity(id: 700, customerId: 20, clientUuid: 'v7', checkinAt: yesterday, checkinAtRaw: yesterday.toIso8601String())),
    ('chưa gửi (id ≤ 0)', VisitEntity(id: -5, customerId: 20, clientUuid: 'v8', checkinAt: yesterday, checkinAtRaw: yesterday.toIso8601String())),
  ]) {
    test('M2 lượt check-in hôm qua còn mở ($label) vẫn còn sau khi nạp tuyến', () async {
      boot((o) => (200, {
            'success': true,
            'data': saved.id > 0 && o.uri.toString().contains('open_only=1') ? [saved.toJson()] : <dynamic>[],
            'meta': {'total': 0, 'currentPage': 1, 'pageCount': 1},
          }));
      await container.read(visitRepositoryProvider).saveActiveVisit(saved);
      // Provider autoDispose — giữ sống suốt lượt nạp.
      final sub = container.listen(routeViewModelProvider, (_, __) {});
      await container.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
      expect((await container.read(visitRepositoryProvider).getActiveVisit())?.clientUuid, saved.clientUuid);
      expect(container.read(routeViewModelProvider).activeVisit?.clientUuid, saved.clientUuid);
      sub.close();
    });
  }

  test('M3 check-out trực tuyến đẩy ẢNH / phiếu đang chờ của lượt trước (DB chọn đúng mục con)', () async {
    boot((_) => null);
    await enqueue('visit_photo', 'upload', 'p1', parent: 'vA');
    await enqueue('form_submission', 'create', 'f1', parent: 'vA');
    await enqueue('visit_material', 'save', 'm1', parent: 'vA');
    await enqueue('visit_photo', 'upload', 'p2', parent: 'vB');
    await enqueue('visit', 'checkout', 'coA', parent: 'vA');
    final kids = await db.getPendingCheckoutChildren('vA');
    expect(kids.map((e) => e.clientUuid), ['p1', 'f1', 'm1']);
    expect(await db.getOpenCheckoutChildren('vA'), hasLength(3));
    expect(await db.getOpenCheckoutChildren('vC'), isEmpty);
  });

  test('M3 flushVisitCheckoutChildren gửi ảnh của lượt rồi mới trả true', () async {
    final dir = await Directory.systemTemp.createTemp('m3');
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    boot((o) => o.path == '/dms/visits/501/photos' ? (201, {'success': true, 'data': {'id': 1}}) : null);
    await enqueue('visit_photo', 'upload', 'p1', parent: 'vA', localPath: f.path, payload: jsonEncode({'visit_id': 501}));
    expect(await container.read(syncServiceProvider).flushVisitCheckoutChildren('vA'), isTrue);
    expect(adapter.paths, contains('/dms/visits/501/photos'));
    await dir.delete(recursive: true);
  });
}

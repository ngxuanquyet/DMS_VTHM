import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:vthm_dms/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';

/// Rà soát offline vòng 3 (03/11/2026, #24698) — nhóm A: mỗi test tái hiện một lỗi đã vá.

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

  Iterable<String> get paths => calls.map((c) => '${c.method} ${c.path}');
}

/// Cờ mạng điều khiển được — mô phỏng lần kiểm định kỳ báo "offline" trong khi mạng thật vẫn chạy.
class _Flag extends ConnectivityNotifier {
  _Flag() {
    state = const ConnectivityState(isOnline: true);
  }

  void set(bool online) => state = ConnectivityState(isOnline: online);

  @override
  Future<bool> checkConnectivity() async => state.isOnline;

  @override
  void handleNetworkDisconnection() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _Adapter adapter;
  late ProviderContainer container;
  late _Flag flag;

  void boot(_Handler handler) {
    db = AppDatabase(NativeDatabase.memory(), 1);
    adapter = _Adapter(handler);
    flag = _Flag();
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => flag),
    ]);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> enqueue(String entity, String op, String uuid,
          {String payload = '{}', int? serverId, String state = 'pending', int? nextAttemptAt}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        payload: payload,
        serverId: Value(serverId),
        state: Value(state),
        nextAttemptAt: Value(nextAttemptAt),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  Future<SyncQueueEntry> row(int id) => (db.select(db.syncQueueEntries)..where((t) => t.id.equals(id))).getSingle();

  const customer = CustomerEntity(
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
  const dealer = DealerEntity(
    id: '20',
    order: '01',
    name: 'Điểm 20',
    address: 'Hà Nội',
    status: DealerVisitStatus.pending,
    statusLabel: 'Chưa ghé',
    isVip: false,
    customer: customer,
  );

  group('V1 cờ mạng báo offline nhưng server vẫn trả lời', () {
    test('lượt trước còn lệnh chờ ⇒ check-in đi hàng đợi, KHÔNG gửi (không lách cổng đẩy lượt trước)', () async {
      boot((_) => null);
      await enqueue('visit', 'checkout', 'coA', payload: jsonEncode({'visit_id': -1}));
      flag.set(false);
      final vm = container.read(checkInViewModelProvider.notifier);
      vm.initCheckinWithDealer(dealer);
      expect(await vm.performCheckin(customerId: 20), isNull);
      expect(adapter.paths.where((p) => p == 'POST /dms/visits'), isEmpty);
      expect((await db.getAllPendingQueueEntries()).where((e) => e.entity == 'visit' && e.op == 'create'), hasLength(1));
    });

    test('xoá ảnh gặp 404 (đã xoá trên server) ⇒ coi như xong', () async {
      boot((o) {
        if (o.method == 'POST' && o.path == '/dms/visits') {
          return (201, {'success': true, 'data': {'id': 501, 'customer_id': 20}});
        }
        if (o.method == 'DELETE') return (404, {'success': false, 'message': 'Không tìm thấy'});
        return null;
      });
      final vm = container.read(checkInViewModelProvider.notifier);
      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 20);
      final (ok, _) = await vm.deletePhoto(999);
      expect(ok, isTrue);
    });

    test('lỗi 4xx thật của server KHÔNG bị coi là mất mạng (xoá ảnh bị từ chối ⇒ báo lỗi, không xoá trong máy)', () async {
      boot((o) {
        if (o.method == 'POST' && o.path == '/dms/visits') {
          return (201, {'success': true, 'data': {'id': 501, 'customer_id': 20}});
        }
        if (o.method == 'DELETE') return (422, {'success': false, 'message': 'Lượt đã đóng'});
        return null;
      });
      final vm = container.read(checkInViewModelProvider.notifier);
      vm.initCheckinWithDealer(dealer);
      expect(await vm.performCheckin(customerId: 20), isNull);
      expect(container.read(checkInViewModelProvider).visitId, 501);

      flag.set(false);
      final (ok, msg) = await vm.deletePhoto(999);
      expect(ok, isFalse, reason: 'lỗi cũ: cờ offline ⇒ mọi lỗi là "mất mạng" ⇒ coi như xoá xong');
      expect(msg, contains('Lượt đã đóng'));
    });
  });

  test('V1 lỗi máy chủ TẠM (504) khi check-in ⇒ lưu ngoại tuyến (cùng client_uuid), không báo lỗi cứng', () async {
    boot((o) => o.method == 'POST' && o.path == '/dms/visits' ? (504, {'success': false, 'message': 'Gateway'}) : null);
    final vm = container.read(checkInViewModelProvider.notifier);
    vm.initCheckinWithDealer(dealer);
    expect(await vm.performCheckin(customerId: 20), isNull);
    final create = (await db.getAllPendingQueueEntries()).singleWhere((e) => e.entity == 'visit' && e.op == 'create');
    expect(queueMaybeOnServer(create.payload), isTrue, reason: '504: server có thể đã mở lượt');
  });

  test('V1 xoá ảnh gặp lỗi máy chủ (502) ⇒ báo lỗi, không coi là đã xoá (xoá ảnh không xếp hàng)', () async {
    boot((o) {
      if (o.method == 'POST' && o.path == '/dms/visits') {
        return (201, {'success': true, 'data': {'id': 501, 'customer_id': 20}});
      }
      if (o.method == 'DELETE') return (502, {'success': false, 'message': 'Bad gateway'});
      return null;
    });
    final vm = container.read(checkInViewModelProvider.notifier);
    vm.initCheckinWithDealer(dealer);
    await vm.performCheckin(customerId: 20);
    final (ok, _) = await vm.deletePhoto(999);
    expect(ok, isFalse);
  });

  test('V1 cờ mạng báo offline, lượt KHÔNG còn ảnh/phiếu chờ ⇒ check-out vẫn thử gửi trực tuyến', () async {
    boot((o) {
      if (o.method == 'POST' && o.path == '/dms/visits') {
        return (201, {'success': true, 'data': {'id': 501, 'customer_id': 20}});
      }
      if (o.path.endsWith('/checkout')) return (422, {'success': false, 'message': 'Chưa đủ thời gian'});
      return null;
    });
    final vm = container.read(checkInViewModelProvider.notifier);
    vm.initCheckinWithDealer(dealer);
    await vm.performCheckin(customerId: 20);
    flag.set(false);
    final (ok, msg) = await vm.checkout(forceCheckout: true);
    expect(adapter.paths, contains('POST /dms/visits/501/checkout'));
    expect(ok, isFalse, reason: 'từ chối thật ⇒ báo ngay, không xếp hàng rồi chết');
    expect(msg?.toLowerCase(), contains('chưa đủ thời gian'));
    expect((await db.getAllPendingQueueEntries()).where((e) => e.op == 'checkout'), isEmpty);
  });

  group('V2 màn check-in chỉ coi lượt là "đã huỷ trên server" khi server XÁC NHẬN', () {
    final visit = VisitEntity(id: 501, customerId: 20, clientUuid: 'vY', checkinAt: DateTime.now());

    test('lượt còn trong danh sách lượt mở ⇒ giữ (không huỷ)', () async {
      boot((o) => o.path.startsWith('/dms/visits/mine')
          ? (200, {'success': true, 'data': [{'id': 501, 'customer_id': 20, 'client_uuid': 'vY'}]})
          : null);
      expect(await serverConfirmsVisitNotOpen(container.read(visitRepositoryProvider), visit), isFalse);
    });

    test('không tra được (lỗi mạng/máy chủ) ⇒ giữ', () async {
      boot((o) => (500, {'success': false, 'message': 'x'}));
      expect(await serverConfirmsVisitNotOpen(container.read(visitRepositoryProvider), visit), isFalse);
    });

    test('server trả danh sách không có lượt ⇒ mới coi là không còn mở', () async {
      boot((o) => o.path.startsWith('/dms/visits/mine') ? (200, {'success': true, 'data': <dynamic>[]}) : null);
      expect(await serverConfirmsVisitNotOpen(container.read(visitRepositoryProvider), visit), isTrue);
    });
  });

  group('C1 sửa điểm bán mà dòng tạo CÓ THỂ đã lên server', () {
    test('dòng tạo có dấu ⇒ xếp lệnh SỬA riêng (không gộp); không dấu ⇒ gộp như cũ', () async {
      boot((_) => null);
      await db.setOwner(7);
      final local = CustomerLocalDataSource(db);
      await local.createCustomerOffline({'name': 'A', 'client_uuid': 'uuid-aaaa-1', queueMaybeOnServerKey: true});
      await local.createCustomerOffline({'name': 'B', 'client_uuid': 'uuid-bbbb-2'});

      await local.updateCustomerOffline('uuid-aaaa-1', {'name': 'A mới'});
      await local.updateCustomerOffline('uuid-bbbb-2', {'name': 'B mới'});

      final rows = await db.getAllPendingQueueEntries();
      final a = rows.where((r) => r.clientUuid == 'uuid-aaaa-1').toList();
      expect(a.map((r) => r.op), containsAll(['create', 'update']),
          reason: 'lỗi cũ: gộp vào dòng tạo ⇒ server trả bản cũ theo client_uuid, phần sửa mất im lặng');
      expect(jsonDecode(a.firstWhere((r) => r.op == 'create').payload)['name'], 'A');
      final b = rows.where((r) => r.clientUuid == 'uuid-bbbb-2').toList();
      expect(b.map((r) => r.op), ['create']);
      expect(jsonDecode(b.single.payload)['name'], 'B mới');
    });

    test('dòng tạo bị từ chối (dead) được sửa ⇒ bỏ dấu, lần sửa sau lại gộp vào nó', () async {
      boot((_) => null);
      await db.setOwner(7);
      final local = CustomerLocalDataSource(db);
      await local.createCustomerOffline({'name': 'A', 'client_uuid': 'uuid-dead-1', queueMaybeOnServerKey: true});
      final create = (await db.getAllPendingQueueEntries()).single;
      await db.markDead(create.id, 'SĐT sai');
      await local.updateCustomerOffline('uuid-dead-1', {'phone': '0901234567'});
      await local.updateCustomerOffline('uuid-dead-1', {'name': 'A2'});
      final rows = (await db.getAllPendingQueueEntries()).where((r) => r.clientUuid == 'uuid-dead-1').toList();
      expect(rows.map((r) => r.op), ['create'], reason: 'lỗi review: dấu còn ⇒ lần sửa 2 thành lệnh SỬA chờ dòng tạo hỏng');
      expect(jsonDecode(rows.single.payload)['name'], 'A2');
    });

    test('đồng bộ đánh dấu dòng tạo TRƯỚC khi gửi — gửi hỏng giữa chừng thì dấu còn lại', () async {
      boot((o) => o.path == '/crm/customers' ? (503, {'success': false, 'message': 'tạm'}) : null);
      final id = await enqueue('customer', 'create', 'cA', payload: jsonEncode({'name': 'A', 'route_ids': [1]}));
      await container.read(syncServiceProvider).syncQueue();
      expect(adapter.paths, contains('POST /crm/customers'));
      expect(queueMaybeOnServer((await row(id)).payload), isTrue);
      final sent = adapter.calls.firstWhere((c) => c.path == '/crm/customers').data as Map;
      expect(sent.containsKey(queueMaybeOnServerKey), isFalse, reason: 'khoá nội bộ không được lọt lên server');
    });
  });

  test('C1 dấu nội bộ KHÔNG lọt vào `data` gửi server / ô động trong máy; điểm bán mang dấu không xoá được', () async {
    boot((o) => o.path == '/crm/customers' ? (503, {'success': false, 'message': 'tạm'}) : null);
    await db.setOwner(7);
    final local = CustomerLocalDataSource(db);
    await local.createCustomerOffline({'name': 'A', 'client_uuid': 'uuid-mark-1', 'route_ids': [1], queueMaybeOnServerKey: true});
    final create = (await db.getAllPendingQueueEntries()).single;
    expect((jsonDecode(create.payload)['data'] as Map?)?.containsKey(queueMaybeOnServerKey) ?? false, isFalse);
    expect(queueMaybeOnServer(create.payload), isTrue);

    await container.read(syncServiceProvider).syncQueue();
    final sent = adapter.calls.lastWhere((c) => c.path == '/crm/customers').data as Map;
    expect(sent.containsKey(queueMaybeOnServerKey), isFalse);
    expect((sent['data'] as Map?)?.containsKey(queueMaybeOnServerKey) ?? false, isFalse,
        reason: 'lỗi review: helper chép khoá gốc lạ vào data ⇒ server 422 ô động lạ ⇒ dead');

    expect(await db.deletePendingCustomer('uuid-mark-1'), isFalse, reason: 'server có thể đã có ⇒ xoá thì nó quay lại');
  });

  test('C1 đồng bộ không kết nối được (chắc chắn chưa gửi) ⇒ gỡ dấu, dòng tạo còn xoá / gộp sửa được', () async {
    boot((o) {
      if (o.path == '/crm/customers') {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError, error: const SocketException('refused'));
      }
      return null;
    });
    final id = await enqueue('customer', 'create', 'cN', payload: jsonEncode({'name': 'N', 'route_ids': [1]}));
    await container.read(syncServiceProvider).syncQueue();
    expect(adapter.paths, contains('POST /crm/customers'));
    expect(queueMaybeOnServer((await row(id)).payload), isFalse);
  });

  test('V1 lỗi 500 khi check-in ⇒ báo lỗi (không xếp hàng thử lại mãi)', () async {
    boot((o) => o.method == 'POST' && o.path == '/dms/visits' ? (500, {'success': false, 'message': 'Lỗi máy chủ'}) : null);
    final vm = container.read(checkInViewModelProvider.notifier);
    vm.initCheckinWithDealer(dealer);
    expect(await vm.performCheckin(customerId: 20), isNotNull);
    expect((await db.getAllPendingQueueEntries()).where((e) => e.entity == 'visit'), isEmpty);
  });

  test('C1 đồng bộ tạo điểm bán bị 401 (server chưa ghi) ⇒ gỡ dấu', () async {
    boot((o) => o.path == '/crm/customers' ? (401, {'success': false, 'message': 'hết phiên'}) : null);
    final id = await enqueue('customer', 'create', 'cU', payload: jsonEncode({'name': 'U', 'route_ids': [1]}));
    await container.read(syncServiceProvider).syncQueue();
    expect(queueMaybeOnServer((await row(id)).payload), isFalse);
  });

  group('C2 lệnh sửa điểm bán đi đúng thứ tự nhập', () {
    test('lệnh sau CHỜ lệnh trước còn chờ / đang gửi; lệnh trước xong thì đi', () async {
      boot((_) => null);
      final first = await enqueue('customer', 'update', 'server_55', serverId: 55,
          nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch);
      final second = await enqueue('customer', 'update', 'server_55', serverId: 55);
      final other = await enqueue('customer', 'update', 'server_56', serverId: 56);
      expect(await db.isCustomerUpdateHeld(await row(second)), isTrue);
      expect(await db.isCustomerUpdateHeld(await row(other)), isFalse);
      await db.markDone(first);
      expect(await db.isCustomerUpdateHeld(await row(second)), isFalse);
    });

    test('đồng bộ: lệnh trước bị lùi lịch thì lệnh sau KHÔNG gửi trước nó', () async {
      boot((_) => (200, {'success': true, 'data': {'id': 55}}));
      await enqueue('customer', 'update', 'server_55', serverId: 55, payload: jsonEncode({'name': 'cũ'}),
          nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch);
      await enqueue('customer', 'update', 'server_55', serverId: 55, payload: jsonEncode({'name': 'mới'}));
      await container.read(syncServiceProvider).syncQueue();
      expect(adapter.calls.where((c) => c.path.contains('/crm/customers/55')), isEmpty);
    });

    test('lần sửa mới chỉ gộp vào lệnh MỚI NHẤT chưa xong (dòng mới nhất đang gửi ⇒ xếp dòng mới)', () async {
      boot((_) => null);
      await db.setOwner(7);
      final local = CustomerLocalDataSource(db);
      final older = await enqueue('customer', 'update', 'server_55', serverId: 55, payload: jsonEncode({'name': 'A'}));
      await enqueue('customer', 'update', 'server_55', serverId: 55, payload: jsonEncode({'name': 'B'}), state: 'sending');
      await local.enqueueCustomerUpdate(serverId: 55, clientUuid: 'server_55', changes: {'name': 'C'}, nowMs: 0);
      expect(jsonDecode((await row(older)).payload)['name'], 'A',
          reason: 'lỗi cũ: gộp C vào dòng cũ A ⇒ dòng B gửi sau đè C');
      final rows = await (db.select(db.syncQueueEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(jsonDecode(rows.last.payload)['name'], 'C');
      expect(await local.hasUnsentCustomerUpdate(55, null), isTrue);
      expect(await local.hasUnsentCustomerUpdate(56, 'server_56'), isFalse);
    });
  });

  test('S1 mục bị hoãn KHÔNG lấp kín lô — mục phía sau (ngoài 50 dòng đầu) vẫn được gửi', () async {
    boot((_) => (200, {'success': true, 'data': {'id': 99}}));
    // Lệnh đầu bị lùi lịch ⇒ 55 lệnh sau cùng điểm bán đều bị hoãn mà luôn tới hạn.
    await enqueue('customer', 'update', 'server_55', serverId: 55,
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch);
    for (var i = 0; i < 55; i++) {
      await enqueue('customer', 'update', 'server_55', serverId: 55);
    }
    final last = await enqueue('customer', 'update', 'server_99', serverId: 99, payload: jsonEncode({'name': 'X'}));
    await container.read(syncServiceProvider).syncQueue();
    expect(adapter.calls.where((c) => c.path.contains('/crm/customers/99')), isNotEmpty,
        reason: 'lỗi cũ: lô chỉ đọc 50 dòng đầu (toàn mục hoãn) ⇒ mục sau không bao giờ được gửi');
    expect((await row(last)).state, 'done');
  });

  group('A1 chấm công: địa điểm TỰ chọn theo địa điểm gần nhất, không bị giữ cứng', () {
    // Trạng thái sau lần nạp đầu (chưa có GPS): không có khoảng cách ⇒ địa điểm đầu theo tên được TỰ chọn.
    Future<AttendanceViewModel> afterFirstLoad() async {
      final repo = _AttRepo();
      final vm = _attendanceVm(repo);
      await Future<void>.delayed(Duration.zero);
      final config = await repo.getConfig();
      // ignore: invalid_use_of_protected_member
      vm.state = vm.state.copyWith(config: config, selectedLocation: config.closestLocation);
      return vm;
    }

    test('có GPS thì chuyển sang địa điểm đang đứng trong', () async {
      final vm = await afterFirstLoad();
      expect(vm.state.selectedLocation?.id, 1);
      await vm.updateUserLocation(_pos());
      expect(vm.state.selectedLocation?.id, 2, reason: 'lỗi cũ: giữ cứng địa điểm 1 ⇒ chặn oan "ngoài vùng"');
      expect(vm.state.isBlockedByGeofence, isFalse);
    });

    test('địa điểm tự chọn bị gỡ khỏi cấu hình ⇒ thôi coi là tự chọn, theo địa điểm gần nhất', () async {
      final vm = await afterFirstLoad();
      vm.selectLocation(const AttendanceLocationItemEntity(id: 9, code: 'L9', name: 'Đã gỡ'));
      await vm.updateUserLocation(_pos());
      expect(vm.state.selectedLocation?.id, 2);
      expect(vm.state.locationPickedByUser, isFalse);
    });

    test('người dùng TỰ chọn địa điểm ⇒ giữ qua lần cập nhật vị trí', () async {
      final vm = await afterFirstLoad();
      vm.selectLocation(vm.state.config!.locations.first);
      await vm.updateUserLocation(_pos());
      expect(vm.state.selectedLocation?.id, 1);
    });
  });
}

/// Kho chấm công giả: cấu hình 2 địa điểm — có toạ độ thì người dùng đứng trong địa điểm 2; còn lại lỗi (màn bỏ qua).
class _AttRepo implements AttendanceRepository {
  @override
  Future<AttendanceConfigEntity> getConfig({double? lat, double? lng}) async {
    AttendanceLocationItemEntity loc(int id, int? distance) =>
        AttendanceLocationItemEntity(id: id, code: 'L$id', name: 'Địa điểm $id', radiusM: 100, distanceM: distance);
    return AttendanceConfigEntity(
      canPunch: true,
      group: const AttendanceGroupEntity(code: 'G', name: 'G', enforceGeofence: true),
      photo: const AttendancePhotoConfigEntity(minPhotos: 0, maxPhotos: 2),
      locations: [loc(1, lat == null ? null : 5000), loc(2, lat == null ? null : 20)],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AttendanceViewModel _attendanceVm(AttendanceRepository repo) => AttendanceViewModel(
      getConfigUseCase: GetAttendanceConfigUseCase(repo),
      punchUseCase: PunchAttendanceUseCase(repo),
      uploadPhotoUseCase: UploadPunchPhotoUseCase(repo),
      getHistoryUseCase: GetAttendanceHistoryUseCase(repo),
      getAttendanceDetailUseCase: GetAttendanceDetailUseCase(repo),
      attendanceRepository: repo,
    );

Position _pos() => Position(
      latitude: 21,
      longitude: 105.8,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

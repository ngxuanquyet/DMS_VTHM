import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';

/// Rà soát offline vòng 2 (02/11/2026, #24698) — nhóm 1 "mất dữ liệu": mỗi test tái hiện một đường mất dữ liệu đã vá.

/// Máy chủ chấm công trả [error] cho mọi lệnh ghi.
class _FailingApiClient implements ApiClient {
  final Object error;
  _FailingApiClient(this.error);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.error(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 1);
    await db.setOwner(7);
  });
  tearDown(() async => db.close());

  Future<int> enqueue(String entity, String op, String uuid, {String payload = '{}', String state = 'pending', int? serverId}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        payload: payload,
        state: Value(state),
        serverId: Value(serverId),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  group('chấm công trực tuyến gặp lỗi máy chủ TẠM ⇒ vào hàng đợi (không mất lượt chấm)', () {
    for (final (label, err) in [
      ('500', const ServerException('Lỗi máy chủ', 500)),
      ('429', const ServerException('Quá tải', 429)),
      ('không mã (lỗi kết nối/TLS)', const ServerException('CONNECTION_ERROR')),
    ]) {
      test(label, () async {
        final repo = AttendanceRepositoryImpl(AttendanceApiService(_FailingApiClient(err)), database: db);
        final punch = await repo.punch(lat: 21, lng: 105.8, clientUuid: 'p-$label');
        expect(punch.clientUuid, 'p-$label');
        final rows = await db.getAllPendingQueueEntries();
        expect(rows.where((r) => r.entity == 'attendance_punch').map((r) => r.clientUuid), ['p-$label'],
            reason: 'lỗi cũ: ServerException nào cũng ném ra ⇒ không xếp hàng');
      });
    }

    test('422 (ngoài vùng…) vẫn báo thẳng, KHÔNG xếp hàng', () async {
      final repo = AttendanceRepositoryImpl(
          AttendanceApiService(_FailingApiClient(const ServerException('Ngoài vùng chấm công', 422))),
          database: db);
      await expectLater(repo.punch(lat: 21, lng: 105.8, clientUuid: 'p422'), throwsA(isA<ServerException>()));
      expect(await db.getAllPendingQueueEntries(), isEmpty);
    });

    test('bấm lại cùng uuid mà lượt đã bị máy chủ từ chối (dead) ⇒ báo lỗi, không trả "đã chấm"', () async {
      final repo =
          AttendanceRepositoryImpl(AttendanceApiService(_FailingApiClient(const ServerException('x', 503))), database: db);
      await repo.punch(lat: 21, lng: 105.8, clientUuid: 'dd');
      final row = await db.getEntryByClientUuid('dd');
      await db.markDead(row!.id, 'Ngoài vùng chấm công');
      await expectLater(repo.punch(lat: 21, lng: 105.8, clientUuid: 'dd'), throwsA(isA<AppException>()));
    });

    test('lượt có địa điểm TỰ chọn vào hàng đợi KHÔNG mang geofence_id (chọn sai ⇒ 422 ⇒ mục chết, mất lượt)', () async {
      final repo =
          AttendanceRepositoryImpl(AttendanceApiService(_FailingApiClient(const ServerException('x', 503))), database: db);
      await repo.punch(lat: 21, lng: 105.8, clientUuid: 'gf', geofenceId: 7);
      final row = await db.getEntryByClientUuid('gf');
      expect((jsonDecode(row!.payload) as Map).containsKey('geofence_id'), isFalse);
    });

    test('bấm lại CÙNG client_uuid (lần trước lưu ảnh lỗi) không xếp thêm dòng', () async {
      final repo =
          AttendanceRepositoryImpl(AttendanceApiService(_FailingApiClient(const ServerException('x', 503))), database: db);
      await repo.punch(lat: 21, lng: 105.8, clientUuid: 'same');
      await repo.punch(lat: 21, lng: 105.8, clientUuid: 'same');
      expect((await db.getAllPendingQueueEntries()).where((r) => r.clientUuid == 'same'), hasLength(1));
    });
  });

  group('xoá điểm bán chờ gửi', () {
    test('dòng tạo đang gửi / đã gửi ⇒ KHÔNG xoá (server vẫn tạo ⇒ điểm bán "sống lại")', () async {
      for (final st in ['sending', 'done']) {
        await enqueue('customer', 'create', 'c-$st', state: st);
        expect(await db.deletePendingCustomer('c-$st'), isFalse, reason: st);
        expect(await db.getEntryByClientUuid('c-$st'), isNotNull);
      }
    });

    test('dòng tạo bị máy chủ từ chối (dead) ⇒ xoá được', () async {
      final id = await enqueue('customer', 'create', 'cD', payload: jsonEncode({'name': 'A'}));
      await db.markDead(id, 'Thiếu ô bắt buộc');
      expect(await db.deletePendingCustomer('cD'), isTrue);
    });

    test('dòng tạo còn chờ ⇒ xoá được, kèm lượt viếng thăm của nó', () async {
      await enqueue('customer', 'create', 'cP');
      await enqueue('visit', 'create', 'vP', payload: jsonEncode({'customer_client_uuid': 'cP'}));
      expect(await db.deletePendingCustomer('cP'), isTrue);
      expect(await db.getEntryByClientUuid('cP'), isNull);
      expect(await db.getEntryByClientUuid('vP'), isNull);
    });
  });

  test('sửa điểm bán (đã lên server) lúc mất mạng hai lần: ô động lần 1 KHÔNG bị lần 2 đè mất', () async {
    final ds = CustomerLocalDataSource(db);
    await ds.enqueueCustomerUpdate(
        serverId: 55, clientUuid: 'c55', changes: {'data': {'a': 1}}, nowMs: DateTime.now().millisecondsSinceEpoch);
    await ds.enqueueCustomerUpdate(
        serverId: 55, clientUuid: 'c55', changes: {'data': {'b': 2}}, nowMs: DateTime.now().millisecondsSinceEpoch);
    final rows = (await db.getAllPendingQueueEntries()).where((r) => r.op == 'update').toList();
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.payload)['data'], {'a': 1, 'b': 2}, reason: 'lỗi cũ: {...cũ, ...mới} ⇒ mất ô a');
  });

  test('persistOfflinePhotos: ảnh tạm được chép sang thư mục lưu lâu dài; token và tệp mất giữ nguyên', () async {
    final tmp = await Directory.systemTemp.createTemp('g1');
    final docs = await Directory.systemTemp.createTemp('g1docs');
    const channel = 'plugins.flutter.io/path_provider';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(channel),
      (call) async => docs.path,
    );
    final src = File('${tmp.path}/cam.jpg')..writeAsBytesSync([1, 2, 3]);
    const token = '0123456789abcdef0123456789abcdef';
    final out = await CustomerLocalDataSource(db).persistOfflinePhotos([src.path, token, '/khong/con.jpg'], 'cX');
    expect(out[0], startsWith('${docs.path}/offline_customer_photos/'));
    expect(File(out[0]).readAsBytesSync(), [1, 2, 3]);
    expect(out.sublist(1), [token, '/khong/con.jpg']);
    // Gọi lại với đường dẫn đã lưu lâu dài ⇒ không chép thêm bản nữa.
    expect(await CustomerLocalDataSource(db).persistOfflinePhotos([out[0]], 'cX'), [out[0]]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel), null);
    await tmp.delete(recursive: true);
    await docs.delete(recursive: true);
  });

  test('isPermanentRejection: 4xx từ chối hẳn; phiên đăng nhập / tạm / đã có thì không', () {
    expect(isPermanentRejection(const ServerException('x', 422)), isTrue);
    expect(isPermanentRejection(const ServerException('x', 400)), isTrue);
    for (final c in [401, 408, 409, 429, 500]) {
      expect(isPermanentRejection(ServerException('x', c)), isFalse, reason: '$c');
    }
    expect(isPermanentRejection(const DmsAppForbiddenException()), isFalse);
    expect(isPermanentRejection(const NetworkException()), isFalse);
    expect(isPermanentRejection(Exception('x')), isFalse);
  });
}

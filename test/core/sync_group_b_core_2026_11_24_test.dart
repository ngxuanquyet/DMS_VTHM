import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';

/// Rà soát 24/11/2026 (#25868, nhóm B — lõi đồng bộ):
/// 1. Lỗi MẠNG của ảnh/phiếu không đếm vào chuỗi lỗi thả check-out (5xx vẫn đếm).
/// 2. Quá giờ nhận/gửi không lật cờ "mất mạng" — chỉ nhờ dò lại; chưa kết nối được mới lật.
/// 3. Payload hỏng ⇒ dead kèm câu rõ, không thử lại mãi.
/// 4. `queued_seconds` của phiếu tính NGAY TRƯỚC lệnh gửi (sau khi tải ảnh).
/// 5. Ô chọn nhiều không làm phiếu tải lại ảnh.
/// 6. Xoá tệp ảnh viếng thăm sau gửi chừa tệp dòng khác còn trỏ tới.
/// 8. Phiếu khảo sát ở điểm bán tạo ngoại tuyến: id điểm bán trong máy đổi sang id server.
/// 9. Trang không phải API là lỗi tạm.

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions o) handle;
  final List<RequestOptions> calls = [];
  _Adapter(this.handle);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    calls.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

Never _status(RequestOptions o, int status) => throw DioException(
      requestOptions: o,
      response: Response(requestOptions: o, statusCode: status, data: {'success': false, 'message': 'lỗi $status'}),
      type: DioExceptionType.badResponse,
    );

class _FakeConn extends ConnectivityNotifier {
  int lost = 0;
  int checks = 0;

  @override
  void handleNetworkDisconnection() => lost++;

  @override
  Future<bool> checkConnectivity() async {
    checks++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  Future<_Adapter> setUpSync(Future<ResponseBody> Function(RequestOptions o) handle) async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    final adapter = _Adapter(handle);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
    ]);
    addTearDown(container.dispose);
    return adapter;
  }

  Future<int> enqueue(String entity, String op, String uuid, Object payload,
          {String? parent, String state = 'pending', int? serverId, String? localPath, int agoMs = 0}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: payload is String ? payload : jsonEncode(payload),
        state: Value(state),
        serverId: Value(serverId),
        localPath: Value(localPath),
        createdAt: DateTime.now().millisecondsSinceEpoch - agoMs,
        createdElapsed: SystemClock.nowMonotonicMs - agoMs,
        bootId: SystemClock.bootId,
      ));

  Future<void> sync() => container.read(syncServiceProvider).syncQueue(force: true);

  Map<String, dynamic> payloadOf(SyncQueueEntry e) => jsonDecode(e.payload) as Map<String, dynamic>;

  Future<File> tempPhoto(String dirName) async {
    final dir = Directory('${(await Directory.systemTemp.createTemp('grpb')).path}/$dirName')..createSync();
    addTearDown(() => dir.parent.deleteSync(recursive: true));
    // Tên mang dấu đã đóng watermark + .jpg nhỏ ⇒ prepareImageForUpload trả nguyên tệp.
    return File('${dir.path}/wm_anh.jpg')..writeAsBytesSync(List.filled(64, 1));
  }

  group('1. chuỗi lỗi thả check-out của phiếu', () {
    test('quá giờ nhận (lỗi mạng) KHÔNG đếm', () async {
      await setUpSync((o) async => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout));
      final id = await enqueue('form_submission', 'create', 'f1', {'config_id': 1, 'visit_id': 901, 'answers': {}});
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'pending');
      expect(payloadOf(row).containsKey('_server_failures'), isFalse);
    });

    test('503 vẫn đếm', () async {
      await setUpSync((o) async => _status(o, 503));
      final id = await enqueue('form_submission', 'create', 'f1', {'config_id': 1, 'visit_id': 901, 'answers': {}});
      await sync();
      expect(payloadOf((await db.getEntryById(id))!)['_server_failures'], 1);
    });
  });

  group('2. cờ mất mạng của ApiClient', () {
    Future<_FakeConn> call(DioExceptionType type) async {
      final conn = _FakeConn();
      addTearDown(conn.dispose);
      conn.checks = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((o) async => throw DioException(requestOptions: o, type: type));
      await expectLater(ApiClient(dio, connectivityNotifier: conn).get('/x'), throwsA(isA<NetworkException>()));
      return conn;
    }

    test('quá giờ nhận / gửi ⇒ chỉ dò lại, không lật cờ', () async {
      for (final t in [DioExceptionType.receiveTimeout, DioExceptionType.sendTimeout]) {
        final conn = await call(t);
        expect(conn.lost, 0, reason: '$t');
        expect(conn.checks, 1, reason: '$t');
      }
    });

    test('quá giờ kết nối ⇒ lật cờ mất mạng', () async {
      final conn = await call(DioExceptionType.connectionTimeout);
      expect(conn.lost, 1);
      expect(conn.checks, 0);
    });
  });

  test('3. payload hỏng ⇒ dead kèm câu rõ', () async {
    await setUpSync((o) async => _json({'success': true}));
    final id = await enqueue('form_submission', 'create', 'f1', 'không phải json');
    await sync();
    final row = (await db.getEntryById(id))!;
    expect(row.state, 'dead');
    expect(row.lastError, contains('Dữ liệu hỏng'));
  });

  test('4 + 5. queued_seconds tính sau khi tải ảnh; ô chọn nhiều không gây tải lại', () async {
    final photo = await tempPhoto('offline_form_photos');
    final bodies = <Map<String, dynamic>>[];
    final adapter = await setUpSync((o) async {
      if (o.path.contains('form-photos')) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        return _json({'data': {'token': 'a' * 32}});
      }
      bodies.add(Map<String, dynamic>.from(o.data as Map));
      return _json({'success': true, 'data': {'id': 1}});
    });
    await enqueue(
      'form_submission',
      'create',
      'f1',
      {
        'config_id': 1,
        'answers': {'anh': [photo.path], 'chon': ['a', 'b']},
        '_local_photo_paths': {'anh': [photo.path]},
      },
      agoMs: 5000,
    );
    await sync();
    expect(bodies.single['answers']['anh'], ['a' * 32]);
    expect(bodies.single['queued_seconds'], greaterThanOrEqualTo(6), reason: 'tính SAU 1,5 s tải ảnh');

    // Ảnh đã là token, ô chọn nhiều có chuỗi ngắn ⇒ không tải ảnh lại.
    adapter.calls.clear();
    await enqueue('form_submission', 'create', 'f2', {
      'config_id': 1,
      'answers': {'anh': ['b' * 32], 'chon': ['a', 'b']},
      '_local_photo_paths': {'anh': [photo.path]},
    });
    await sync();
    expect(adapter.calls.where((o) => o.path.contains('form-photos')), isEmpty);
  });

  test('5. formAnswersNeedPhotoUpload chỉ xét ô ảnh', () {
    expect(formAnswersNeedPhotoUpload({'anh': ['a' * 32], 'chon': ['x']}, ['anh']), isFalse);
    expect(formAnswersNeedPhotoUpload({'anh': ['/d/x.jpg']}, ['anh']), isTrue);
    expect(
        formAnswersNeedPhotoUpload({
          'sos': {
            'photos': {'t1': ['/d/y.jpg']}
          }
        }, ['sos::t1']),
        isTrue);
    expect(formAnswersNeedPhotoUpload({'chon': ['/d/x.jpg']}, ['anh']), isFalse, reason: 'ô ẩn / không có chỗ ảnh');
  });

  test('6. xoá tệp ảnh viếng thăm sau gửi chừa tệp dòng khác còn trỏ tới', () async {
    final photo = await tempPhoto('offline_visit_photos');
    await setUpSync((o) async => _json({'success': true, 'data': {'id': 5}}));
    await enqueue('visit_photo', 'upload', 'p0', {'visit_id': 901}, localPath: photo.path, state: 'dead');
    final id = await enqueue('visit_photo', 'upload', 'p1', {'visit_id': 901}, localPath: photo.path);
    await sync();
    expect((await db.getEntryById(id))!.state, 'done');
    expect(photo.existsSync(), isTrue);
  });

  test('8. phiếu khảo sát ở điểm bán tạo ngoại tuyến gửi id server của điểm bán', () async {
    final bodies = <Map<String, dynamic>>[];
    await setUpSync((o) async {
      bodies.add(Map<String, dynamic>.from(o.data as Map));
      return _json({'success': true, 'data': {'id': 1}});
    });
    await enqueue('customer', 'create', 'c1', {'name': 'x'}, state: 'done', serverId: 777);
    await enqueue('visit', 'create', 'v1', {'customer_client_uuid': 'c1', 'customer_id': 0}, state: 'done', serverId: 901);
    await enqueue('form_submission', 'create', 'f1', {
      'config_id': 1,
      'visit_id': -3,
      'customer_id': 0,
      'answers': {'customer_id': 0, 'so_luong': 0},
    }, parent: 'v1');
    await sync();
    final body = bodies.single;
    expect(body['visit_id'], 901);
    expect(body['outlet_id'], 777, reason: 'hợp đồng điểm bán mới: gửi outlet_id');
    expect(body.containsKey('customer_id'), isFalse);
    expect(body['answers'], {'customer_id': 777, 'so_luong': 0});
  });

  test('9. trang không phải API là lỗi tạm', () {
    expect(isTemporaryServerError(const ServerException('x', 403, nonApiResponseCode)), isTrue);
    expect(isTemporaryServerError(const ServerException('x', 403, 'FORBIDDEN')), isFalse);
  });
}

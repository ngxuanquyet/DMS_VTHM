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

/// Hàng đợi app DMS không còn mục thử lại vĩnh viễn (24/11/2026):
/// - #24401: 409 của dòng tạo không đánh dấu "xong" thiếu mã; con của cha "xong mà không có mã" (bản cũ) báo lỗi; ảnh chấm
///   công đời cũ gắn ĐÚNG lượt chấm xếp trước nó, không "lượt đã gửi gần nhất".
/// - #25875: phản hồi 200 không có mã bản ghi (Wi-Fi đòi đăng nhập) không đánh dấu xong; ô điểm bán mã lạ của phiếu đổi id.
/// - #25874: trần cho lỗi lặp lại tất định (trang không phải API) — chỉ loại gửi lại được.

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

/// Trang đăng nhập của Wi-Fi công cộng / WAF: thân HTML.
ResponseBody _html([int status = 200]) => ResponseBody.fromString('<html><body>Đăng nhập Wi-Fi</body></html>', status,
    headers: {
      Headers.contentTypeHeader: ['text/html'],
    });

Never _status(RequestOptions o, int status) => throw DioException(
      requestOptions: o,
      response: Response(requestOptions: o, statusCode: status, data: {'success': false, 'message': 'lỗi $status'}),
      type: DioExceptionType.badResponse,
    );

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
          {String? parent, String state = 'pending', int? serverId, String? localPath}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: payload is String ? payload : jsonEncode(payload),
        state: Value(state),
        serverId: Value(serverId),
        localPath: Value(localPath),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  Future<void> sync() => container.read(syncServiceProvider).syncQueue(force: true);

  Map<String, dynamic> payloadOf(SyncQueueEntry e) => jsonDecode(e.payload) as Map<String, dynamic>;

  Future<File> tempPhoto() async {
    final dir = await Directory.systemTemp.createTemp('stuck');
    addTearDown(() => dir.deleteSync(recursive: true));
    return File('${dir.path}/wm_anh.jpg')..writeAsBytesSync(List.filled(64, 1));
  }

  group('#25875 — 200 không có mã bản ghi', () {
    for (final (entity, path, payload) in [
      ('visit', '/dms/visits', {'customer_id': 5}),
      ('attendance_punch', '/attendance/mobile/punch', {'lat': 1, 'lng': 2}),
    ]) {
      test('$entity: trang HTML 200 ⇒ còn chờ, không xong thiếu mã; mục con vẫn chờ', () async {
        final adapter = await setUpSync((o) async => _html());
        final id = await enqueue(entity, 'create', 'p1', payload);
        final child = entity == 'visit'
            ? await enqueue('visit', 'checkout', 'k1', {'visit_id': -1}, parent: 'p1')
            : await enqueue('attendance_photo', 'upload', 'k1', {'punch_id': -1}, parent: 'p1');
        await sync();
        final row = (await db.getEntryById(id))!;
        expect(row.state, 'pending');
        expect(row.serverId, isNull);
        // Loại không "Gửi lại" được ⇒ không đếm trần (thử lại tới khi đổi mạng).
        expect(payloadOf(row).containsKey(stuckFailuresKey), isFalse);
        expect((await db.getEntryById(child))!.state, 'pending');
        expect(adapter.calls.where((c) => c.path.endsWith(path)), hasLength(1));
      });
    }

    test('điểm bán: phản hồi JSON không có id ⇒ còn chờ', () async {
      await setUpSync((o) async => _json({'success': true, 'data': {}}));
      final id = await enqueue('customer', 'create', 'c1', {'name': 'Tạp hoá A', 'lat': 21.0, 'lng': 105.8});
      await sync();
      expect((await db.getEntryById(id))!.state, 'pending');
    });
  });

  group('#24401 — 409', () {
    test('dòng tạo lượt nhận 409 ⇒ thử lại (không xong thiếu mã, không chết)', () async {
      await setUpSync((o) async => _status(o, 409));
      final id = await enqueue('visit', 'create', 'v1', {'customer_id': 5});
      await sync();
      expect((await db.getEntryById(id))!.state, 'pending');
    });

    test('dòng tạo điểm bán nhận 409 ⇒ thử lại, KHÔNG đếm trần (có thể đã lên server — không cho chết)', () async {
      await setUpSync((o) async => _status(o, 409));
      final id = await enqueue('customer', 'create', 'c1', {'name': 'Tạp hoá A', 'lat': 21.0, 'lng': 105.8});
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'pending');
      expect(payloadOf(row).containsKey(stuckFailuresKey), isFalse);
    });

    test('mục không phải dòng tạo cha nhận 409 ⇒ vẫn coi là xong', () async {
      await setUpSync((o) async => _status(o, 409));
      final id = await enqueue('form_submission', 'create', 'f1', {'config_id': 1, 'visit_id': 901, 'answers': {}});
      await sync();
      expect((await db.getEntryById(id))!.state, 'done');
    });

    test('cha "xong" mà không có mã (bản app cũ) ⇒ mục con báo lỗi, không chờ mãi', () async {
      await setUpSync((o) async => _json({'success': true, 'data': {'id': 1}}));
      await enqueue('visit', 'create', 'v1', {'customer_id': 5}, state: 'done');
      final child = await enqueue('visit', 'checkout', 'k1', {'visit_id': -1}, parent: 'v1');
      await sync();
      final row = (await db.getEntryById(child))!;
      expect(row.state, 'dead');
      expect(row.lastError, contains('mục cha không còn hoặc không thể đồng bộ'));
    });
  });

  test('#25875 — ảnh viếng thăm nhận trang HTML 200 ⇒ KHÔNG đánh dấu đã gửi (không xoá tệp), có đếm trần', () async {
    final photo = await tempPhoto();
    await setUpSync((o) async => _html());
    final id = await enqueue('visit_photo', 'upload', 'ph1', {'visit_id': 901, 'photo_type': 'front'}, localPath: photo.path);
    await sync();
    final row = (await db.getEntryById(id))!;
    expect(row.state, 'pending');
    expect(payloadOf(row)[stuckFailuresKey], 1);
    expect(photo.existsSync(), isTrue);
  });

  test('#24401 — điểm bán cha "xong" mà thiếu mã (bản cũ) ⇒ check-in CHỜ (danh sách tải sau gắn được id), không chết',
      () async {
    await setUpSync((o) async => _json({'success': true, 'data': {'id': 1}}));
    await enqueue('customer', 'create', 'c1', {'name': 'x'}, state: 'done');
    final v = await enqueue('visit', 'create', 'v1', {'customer_client_uuid': 'c1', 'customer_id': 0}, parent: 'c1');
    await sync();
    expect((await db.getEntryById(v))!.state, 'pending');
  });

  group('#24401 — ảnh chấm công đời cũ (không parentUuid)', () {
    test('gắn lượt chấm xếp NGAY TRƯỚC ảnh, không phải lượt đã gửi gần nhất', () async {
      final photo = await tempPhoto();
      final adapter = await setUpSync((o) async => _json({'success': true, 'data': {'id': 1}}));
      await enqueue('attendance_punch', 'create', 'p-vao', {}, state: 'done', serverId: 77);
      final id = await enqueue('attendance_photo', 'upload', 'a1', {'punch_id': -1}, localPath: photo.path);
      // Lượt chấm gửi xong SAU ảnh (id lớn hơn) — bản cũ gắn nhầm ảnh vào đây.
      await enqueue('attendance_punch', 'create', 'p-ra', {}, state: 'done', serverId: 88);
      await sync();
      expect((await db.getEntryById(id))!.state, 'done');
      expect(adapter.calls.single.path, '/attendance/mobile/punches/77/photos');
    });

    test('lượt chấm trước ảnh chưa gửi ⇒ ảnh chờ, không gắn sang lượt khác', () async {
      final photo = await tempPhoto();
      final adapter = await setUpSync((o) async =>
          o.path.endsWith('/punch') ? Future.error(DioException(requestOptions: o, type: DioExceptionType.connectionError)) : _json({'success': true, 'data': {'id': 1}}));
      await enqueue('attendance_punch', 'create', 'p-cu', {}, state: 'done', serverId: 55);
      await enqueue('attendance_punch', 'create', 'p-vao', {});
      final id = await enqueue('attendance_photo', 'upload', 'a1', {'punch_id': -1}, localPath: photo.path);
      await sync();
      expect((await db.getEntryById(id))!.state, 'pending');
      expect(adapter.calls.where((c) => c.path.contains('/photos')), isEmpty);
    });

    test('lượt chấm trước ảnh cách quá ${AppDatabase.punchPhotoMaxGap.inMinutes} phút (lượt thật đã bị dọn) ⇒ báo lỗi, không gắn nhầm', () async {
      final photo = await tempPhoto();
      final adapter = await setUpSync((o) async => _json({'success': true, 'data': {'id': 1}}));
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'attendance_punch',
        op: 'create',
        clientUuid: 'p-hom-qua',
        payload: '{}',
        state: const Value('done'),
        serverId: const Value(66),
        createdAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        createdElapsed: 0,
        bootId: SystemClock.bootId,
      ));
      final id = await enqueue('attendance_photo', 'upload', 'a1', {'punch_id': -1}, localPath: photo.path);
      await sync();
      expect((await db.getEntryById(id))!.state, 'dead');
      expect(adapter.calls, isEmpty);
    });

    test('không có lượt chấm nào trước ảnh ⇒ báo lỗi', () async {
      final photo = await tempPhoto();
      await setUpSync((o) async => _json({'success': true, 'data': {'id': 1}}));
      final id = await enqueue('attendance_photo', 'upload', 'a1', {'punch_id': -1}, localPath: photo.path);
      await sync();
      expect((await db.getEntryById(id))!.state, 'dead');
    });
  });

  group('#25874 — trần lỗi lặp lại tất định', () {
    Map<String, dynamic> nearCap({required Duration since, Duration lastAgo = const Duration(minutes: 5)}) => {
          'config_id': 1,
          'visit_id': 901,
          'answers': {},
          stuckFailuresKey: stuckMaxFailures - 1,
          stuckFirstMsKey: DateTime.now().subtract(since).millisecondsSinceEpoch,
          stuckLastMsKey: DateTime.now().subtract(lastAgo).millisecondsSinceEpoch,
        };

    test('đủ lần VÀ quá thời gian ⇒ dead kèm câu rõ, còn "Gửi lại" được', () async {
      await setUpSync((o) async => _html(403));
      final id = await enqueue('form_submission', 'create', 'f1', nearCap(since: stuckGiveUpAfter + const Duration(minutes: 1)));
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'dead');
      expect(row.lastError, contains('đã dừng tự gửi'));
      expect(AppDatabase.canRetryDead(row), isTrue);
    });

    test('đủ lần nhưng chưa đủ thời gian ⇒ vẫn chờ', () async {
      await setUpSync((o) async => _html(403));
      final id = await enqueue('form_submission', 'create', 'f1', nearCap(since: const Duration(hours: 1)));
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'pending');
      expect(payloadOf(row)[stuckFailuresKey], stuckMaxFailures);
    });

    test('chuỗi đứt (lần lỗi trước quá ${stuckChainGap.inMinutes} phút) ⇒ đếm lại từ 1, không chết', () async {
      await setUpSync((o) async => _html(403));
      final id = await enqueue('form_submission', 'create', 'f1',
          nearCap(since: const Duration(days: 2), lastAgo: stuckChainGap + const Duration(minutes: 1)));
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'pending');
      expect(payloadOf(row)[stuckFailuresKey], 1);
    });

    test('loại không "Gửi lại" được (check-in, chấm công) KHÔNG bị cho chết — chết là mất bản ghi', () async {
      await setUpSync((o) async => _html(403));
      final over = {
        stuckFailuresKey: stuckMaxFailures + 5,
        stuckFirstMsKey: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        stuckLastMsKey: DateTime.now().millisecondsSinceEpoch,
      };
      final v = await enqueue('visit', 'create', 'v1', {'customer_id': 5, ...over});
      final p = await enqueue('attendance_punch', 'create', 'p1', {'lat': 1, ...over});
      await sync();
      expect((await db.getEntryById(v))!.state, 'pending');
      expect((await db.getEntryById(p))!.state, 'pending');
    });

    test('lỗi mạng (kể cả đứt giữa chừng) ⇒ KHÔNG đếm — không phân biệt được với sóng yếu', () async {
      final photo = await tempPhoto();
      await setUpSync((o) async => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError, error: const HttpException('Connection closed')));
      final p = await enqueue('visit_photo', 'upload', 'ph1', {'visit_id': 901, 'photo_type': 'front'}, localPath: photo.path);
      await sync();
      expect(payloadOf((await db.getEntryById(p))!).containsKey(stuckFailuresKey), isFalse);
    });

    test('lệnh ghi nhận thân 2xx không phải JSON (chữ thường) ⇒ không "đã gửi", có đếm', () async {
      await setUpSync((o) async => ResponseBody.fromString('Access denied', 200, headers: {
            Headers.contentTypeHeader: ['text/plain'],
          }));
      final id = await enqueue('form_submission', 'create', 'f1', {'config_id': 1, 'visit_id': 901, 'answers': {}});
      await sync();
      final row = (await db.getEntryById(id))!;
      expect(row.state, 'pending');
      expect(payloadOf(row)[stuckFailuresKey], 1);
    });

    test('recordStuckFailure: payload hỏng giữ nguyên', () {
      expect(recordStuckFailure('x', nowMs: 1), ('x', false));
    });
  });

  group('#25875 — ApiClient: thân 2xx của lệnh ghi', () {
    ApiClient client(ResponseBody Function() body) =>
        ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = _Adapter((o) async => body()));

    test('trang HTML 200 ⇒ lỗi tạm mang mã 200 — đường trực tuyến xếp hàng (isTemporaryServerError)', () async {
      for (final call in <Future<dynamic> Function(ApiClient)>[
        (c) => c.post('/x', data: {}),
        (c) => c.patch('/x', data: {}),
        (c) => c.delete('/x'),
      ]) {
        try {
          await call(client(_html));
          fail('phải ném lỗi');
        } on AppException catch (e) {
          expect(e.statusCode, 200);
          expect(e.code, nonApiResponseCode);
          expect(isTemporaryServerError(e), isTrue);
        }
      }
    });

    test('JSON object / mảng / thân rỗng vẫn là thành công', () async {
      expect(await client(() => _json({'success': true})).post('/x'), {'success': true});
      expect(await client(() => _json([1])).post('/x'), [1]);
      // Chuỗi JSON trần ("ok") khai application/json — Dio giải ra chuỗi — vẫn là của API.
      expect(await client(() => _json('ok')).post('/x'), 'ok');
      // JSON mang content-type khác (proxy đổi header) ⇒ trả bản đã giải.
      expect(
          await client(() => ResponseBody.fromString('{"data":{"id":7}}', 200, headers: {
                Headers.contentTypeHeader: ['text/plain'],
              })).post('/x'),
          {'data': {'id': 7}});
      expect(await client(() => ResponseBody.fromString('', 204)).delete('/x'), anyOf(isNull, ''));
    });
  });

  test('#25875 — ô điểm bán mã lạ của phiếu (ghi lúc xếp hàng) đổi sang id server', () async {
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
      'answers': {'diem_ban_cua_toi': 0, 'so_luong': 0},
      '_outlet_codes': ['diem_ban_cua_toi'],
    }, parent: 'v1');
    await sync();
    final body = bodies.single;
    expect(body['answers'], {'diem_ban_cua_toi': 777, 'so_luong': 0});
    expect(body.containsKey('_outlet_codes'), isFalse);
  });
}

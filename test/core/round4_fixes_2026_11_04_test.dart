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
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';

/// Rà soát offline vòng 4 (04/11/2026, #24698) — mỗi test tái hiện một lỗi đã vá: ô ma trận ẩn sống lại khi đồng bộ (F1),
/// dọn ảnh điểm bán xoá tệp lệnh sau còn cần (C2), xoá dòng check-out lỗi làm lượt sau mất miễn trần (V3).

typedef _Handler = (int, Map<String, dynamic>)? Function(RequestOptions o);

class _Adapter implements HttpClientAdapter {
  final _Handler handler;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    final r = handler(o) ?? (200, {'success': true, 'data': <String, dynamic>{}});
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1,
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
          {String? parent, String payload = '{}', int? serverId, String state = 'pending'}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: payload,
        serverId: Value(serverId),
        state: Value(state),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  Future<SyncQueueEntry> row(int id) => (db.select(db.syncQueueEntries)..where((t) => t.id.equals(id))).getSingle();

  group('F1 ảnh của ô đang ẩn không dựng lại ô khi gửi phiếu', () {
    test('applyPhotoList chỉ thay danh sách đã có trong answers', () {
      boot((o) => null);
      final answers = <String, dynamic>{
        'sos': {
          'counts': {'vthm': {'ke': 2}},
          'photos': {'ke': ['/tmp/a.jpg']},
        },
      };
      applyPhotoList(answers, 'an::ke', ['a' * 32]); // ô ma trận đang ẩn
      applyPhotoList(answers, 'sos::bo_qua', ['b' * 32]); // loại không chụp ảnh (đã lọc khỏi answers)
      applyPhotoList(answers, 'anh_an', ['c' * 32]); // ô ảnh đang ẩn
      applyPhotoList(answers, 'sos::ke', ['d' * 32]);
      expect(answers.keys, ['sos'], reason: 'lỗi cũ: dựng mới ô vắng mặt với counts rỗng ⇒ server xoá trắng SOS');
      expect(answers['sos']['photos'], {'ke': ['d' * 32]});
      expect(hasPhotoSlot(answers, 'sos::ke'), isTrue);
      expect(hasPhotoSlot(answers, 'an::ke'), isFalse);
    });

    test('phiếu chờ gửi: ảnh ô ẩn (tệp đã mất) không làm hỏng phiếu, không gửi ô ẩn', () async {
      boot((o) => null);
      final payload = {
        'config_id': 3,
        'answers': {'ghi_chu': 'ok'},
        '_local_photo_paths': {
          'an::ke': ['/khong/con/tep.jpg'],
        },
      };
      final id = await enqueue('form_submission', 'create', 'f1', payload: jsonEncode(payload));

      await container.read(syncServiceProvider).syncQueue(force: true);

      expect((await row(id)).state, 'done', reason: 'lỗi cũ: tải ảnh ô ẩn ⇒ 410 dead cả phiếu');
      final post = adapter.calls.singleWhere((c) => c.path == '/dms/form-submissions');
      expect((post.data as Map)['answers'], {'ghi_chu': 'ok'});
    });
  });

  group('C2 dọn ảnh điểm bán chỉ xoá tệp không còn ai trỏ tới', () {
    test('referencedFilePaths(unfinishedOnly, exceptId): dòng chưa xong khác + điểm bán trong máy; bỏ chính dòng đó và dòng đã xong', () async {
      boot((o) => null);
      final dir = await Directory.systemTemp.createTemp('r4_');
      addTearDown(() => dir.delete(recursive: true));
      final p1 = '${dir.path}/offline_customer_photos/m1.jpg';
      final p2 = '${dir.path}/offline_customer_photos/m2.jpg';
      final p3 = '${dir.path}/offline_customer_photos/m3.jpg';
      final own = await enqueue('customer', 'update', 'c1', serverId: 5, state: 'sending', payload: jsonEncode({
        'data': {'sos': {'photos': {'ke': [p1, p2, p3]}}},
      }));
      await enqueue('customer', 'update', 'c1', serverId: 5, payload: jsonEncode({
        'data': {'sos': {'photos': {'ke': [p1]}}},
      }));
      await enqueue('customer', 'update', 'c9', serverId: 9, state: 'done', payload: jsonEncode({
        'data': {'sos': {'photos': {'ke': [p2]}}},
      }));

      final needed = await db.referencedFilePaths(unfinishedOnly: true, exceptId: own);
      expect(needed.contains(p1), isTrue, reason: 'lệnh sửa đứng sau còn trỏ ⇒ xoá là 410, mất cả lần sửa');
      expect(needed.contains(p2), isFalse);
      expect(needed.contains(p3), isFalse);
    });
  });

  group('V3 không xoá được dòng check-out lỗi đang giữ lượt sau', () {
    Future<int> seed() async {
      await enqueue('visit', 'create', 'visitA', state: 'done', serverId: 901, payload: '{"customer_id":9}');
      await enqueue('visit', 'checkout', 'coA', parent: 'visitA', state: 'dead');
      return enqueue('visit', 'create', 'visitB', payload: '{"customer_id":10}');
    }

    Future<int> deadClose() async =>
        (await (db.select(db.syncQueueEntries)..where((t) => t.clientUuid.equals('coA'))).getSingle()).id;

    test('Xoá tất cả / xoá từng mục giữ lại dòng đó; lượt sau vẫn chờ không đếm trần', () async {
      boot((o) => null);
      final b = await seed();
      final dead = await enqueue('visit_photo', 'create', 'px', parent: 'visitZ', state: 'dead');

      await db.clearDeadEntries();
      expect(await db.deleteEntry(await deadClose()), isFalse);

      expect(await db.hasDeadVisitCloseBefore(await row(b)), isTrue, reason: 'lỗi cũ: mất miễn ⇒ B dead sau ~2 giờ');
      expect(await (db.select(db.syncQueueEntries)..where((t) => t.id.equals(dead))).getSingleOrNull(), isNull,
          reason: 'mục lỗi khác vẫn xoá như thường');
    });

    test('lệnh đóng lỗi KHÁC (lượt chưa lên server) vẫn xoá được dù lượt sau đang được giữ', () async {
      boot((o) => null);
      await seed();
      await enqueue('visit', 'create', 'visitX', state: 'dead', payload: '{"customer_id":7}');
      final coX = await enqueue('visit', 'checkout', 'coX', parent: 'visitX', state: 'dead');
      await enqueue('visit', 'create', 'visitC', payload: '{"customer_id":11}');
      expect(await db.deleteEntry(coX), isTrue);
      expect(await db.deleteEntry(await deadClose()), isFalse);
    });

    test('lượt cũ đã được đóng lại ⇒ xoá được', () async {
      boot((o) => null);
      await seed();
      await enqueue('visit', 'checkout', 'coA2', parent: 'visitA', state: 'done');
      expect(await db.deleteEntry(await deadClose()), isTrue);
    });

    test('không có lượt sau đang chờ ⇒ xoá được', () async {
      boot((o) => null);
      final b = await seed();
      await (db.update(db.syncQueueEntries)..where((t) => t.id.equals(b)))
          .write(const SyncQueueEntriesCompanion(state: Value('done')));
      expect(await db.clearDeadEntries(), 0, reason: 'không còn mục nào bị giữ');
      expect(await db.countDeadSync(), 0);
    });
  });

  test('#24792 lệnh SỬA chờ gửi: ảnh ô chụp ảnh tự khai đổi ra token trước khi PATCH', () async {
    boot((o) => o.path == '/crm/customer-photos' ? (200, {'success': true, 'data': {'token': 'f' * 32}}) : null);
    final dir = await Directory.systemTemp.createTemp('r4_');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/quay_ke.jpg')..writeAsBytesSync([1, 2, 3]);
    final id = await enqueue('customer', 'update', 'server_77', serverId: 77, payload: jsonEncode({
      'data': {'anh_quay_ke': [f.path, 'a' * 32], 'muc_do': ['cao']},
    }));

    await container.read(syncServiceProvider).syncQueue(force: true);

    expect((await row(id)).state, 'done');
    final patch = adapter.calls.singleWhere((c) => c.path == '/crm/customers/77');
    expect((patch.data as Map)['data'], {
      'anh_quay_ke': ['f' * 32, 'a' * 32],
      'muc_do': ['cao'],
    }, reason: 'lỗi cũ: gửi nguyên đường dẫn máy ⇒ server từ chối, lệnh sửa chết');
  });
}

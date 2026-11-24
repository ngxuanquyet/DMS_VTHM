import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/services/local_history_retention.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/account_key.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';


/// #24728 — bộ đệm lượt viếng thăm (lượt đang mở + lịch sử, có toạ độ) tách theo tài khoản, kể cả lần ghi xong SAU khi đổi
/// tài khoản; tự đăng xuất dọn bộ đệm của mình. #24456 — bộ đệm cấu hình / lịch ca chấm công không rơi về khoá chung.

const _active = VisitLocalStore.activeKey;
const _list = VisitLocalStore.listKey;

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

ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

class _AttApi extends Fake implements AttendanceApiService {
  Completer<AttendanceConfigModel>? gate;
  bool offline = false;
  final called = Completer<void>();

  @override
  Future<AttendanceConfigModel> getConfig({double? lat, double? lng}) {
    if (!called.isCompleted) called.complete();
    if (offline) return Future.error(Exception('mất mạng'));
    return gate?.future ?? Future.value(AttendanceConfigModel.fromJson(const {'can_punch': false, 'blocked_reason': 'X'}));
  }
}

String _user(int id) => jsonEncode({'id': id, 'username': 'U$id'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('#24728 bộ đệm lượt theo tài khoản', () {
    test('ghi xong SAU khi đổi tài khoản (chủ chốt trước await) ⇒ vào ngăn người bấm, không vào bộ đệm người mới', () async {
      SharedPreferences.setMockInitialValues({VisitLocalStore.ownerKey: 7});
      final prefs = await SharedPreferences.getInstance();
      final storeA = await VisitLocalStore.current();

      await VisitLocalStore.switchOwner(8);
      await storeA.saveVisit(const VisitEntity(id: 55, customerId: 1, clientUuid: 'a1'));
      await storeA.saveActive(const VisitEntity(id: 55, customerId: 1, clientUuid: 'a1'));

      expect(await const VisitLocalStore().getAll(), isEmpty, reason: 'lỗi cũ: lượt của A rơi vào bộ đệm của B');
      expect(await const VisitLocalStore().getActive(), isNull);
      expect(prefs.getString('${_list}_u7'), contains('"a1"'));

      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getAll()).single.id, 55, reason: 'A vào lại thấy lượt của mình');
      expect((await const VisitLocalStore().getActive())?.id, 55);
    });

    test('tự đăng xuất dọn bộ đệm của mình; người khác vào sau không thấy, ngăn cất của người khác giữ nguyên', () async {
      SharedPreferences.setMockInitialValues({
        VisitLocalStore.ownerKey: 7,
        _list: '[{"id":1,"customer_id":1}]',
        _active: '{"id":1,"customer_id":1}',
        '${_list}_u9': '[{"id":9,"customer_id":1}]',
      });
      final prefs = await SharedPreferences.getInstance();

      await VisitLocalStore.clearCurrentOwner();
      expect(prefs.getString(_list), isNull);
      expect(prefs.getString(_active), isNull);
      expect(prefs.getInt(VisitLocalStore.ownerKey), 0, reason: 'mốc «không ai»');
      // Lần ghi muộn của người vừa rời (chủ chốt trước — tải tuyến / gửi lượt về muộn) bị BỎ: không dựng lại ngăn vừa xoá.
      await const VisitLocalStore(7).saveVisits(const [VisitEntity(id: 77, customerId: 1)]);
      await const VisitLocalStore(7).saveActive(const VisitEntity(id: 77, customerId: 1));
      expect(prefs.getString(_list), isNull);
      expect(prefs.getString('${_list}_u7'), isNull, reason: 'lỗi review: ghi muộn dựng lại ngăn người vừa tự xoá');
      expect(prefs.getString('${_active}_u7'), isNull);
      // Người khác đăng nhập SAU đó mà kết quả của người vừa tự xoá mới về ⇒ vẫn bỏ (lỗi review vòng 3).
      await VisitLocalStore.switchOwner(8);
      await const VisitLocalStore(7).saveVisits(const [VisitEntity(id: 78, customerId: 1)]);
      expect(prefs.getString('${_list}_u7'), isNull);
      expect(await const VisitLocalStore().getAll(), isEmpty);
      expect(prefs.getKeys().where((k) => k.endsWith('_u0')), isEmpty);
      // Người đó đăng nhập lại ⇒ hết bị bỏ.
      await VisitLocalStore.switchOwner(7);
      await const VisitLocalStore(7).saveVisit(const VisitEntity(id: 79, customerId: 1));
      expect((await const VisitLocalStore().getAll()).single.id, 79);

      await VisitLocalStore.switchOwner(8);
      expect(await const VisitLocalStore().getAll(), isEmpty);
      await VisitLocalStore.switchOwner(9);
      expect((await const VisitLocalStore().getAll()).single.id, 9);
    });

    test('«chưa ai» sau tự đăng xuất ⇒ ghi không bị bỏ; ngăn của người cụ thể vào ngăn cất của họ', () async {
      SharedPreferences.setMockInitialValues({VisitLocalStore.ownerKey: 0});
      final store = await VisitLocalStore.current();
      await store.saveVisit(const VisitEntity(id: 5, customerId: 1));
      expect((await const VisitLocalStore().getAll()).single.id, 5, reason: 'ngăn không chốt chủ ⇒ khoá chung');
      // Ngăn của người cụ thể (lượt về muộn của B) ⇒ ngăn cất của B, B đăng nhập lại là thấy (lỗi review vòng cuối).
      await const VisitLocalStore(8).saveActive(const VisitEntity(id: 6, customerId: 1));
      expect(await const VisitLocalStore().getActive(), isNull);
      await VisitLocalStore.switchOwner(8);
      expect((await const VisitLocalStore().getActive())?.id, 6);
    });

    test('vừa tự đăng xuất mà người đăng nhập có ngăn đã cất ⇒ lấy lại ngăn đó', () async {
      SharedPreferences.setMockInitialValues({VisitLocalStore.ownerKey: 0, '${_list}_u7': '[{"id":3,"customer_id":1}]'});
      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getAll()).single.id, 3);
    });

    test('nâng cấp từ bản app cũ (chưa ghi chủ, chưa có ngăn cất) ⇒ người đăng nhập đầu tiên giữ bộ đệm cũ', () async {
      SharedPreferences.setMockInitialValues({_active: '{"id":-2,"customer_id":1}'});
      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getActive())?.id, -2, reason: 'không mất lượt đang mở của chính người dùng');
    });

    test('danh sách người đã tự xoá giữ tối đa 50 người MỚI NHẤT', () async {
      SharedPreferences.setMockInitialValues({
        VisitLocalStore.ownerKey: 999,
        VisitLocalStore.clearedKey: [for (var i = 1; i <= 50; i++) '$i'],
      });
      final prefs = await SharedPreferences.getInstance();
      await VisitLocalStore.clearCurrentOwner();
      final cleared = prefs.getStringList(VisitLocalStore.clearedKey)!;
      expect(cleared.length, 50);
      expect(cleared.last, '999', reason: 'người vừa rời phải còn trong danh sách');
      expect(cleared.first, '2');
    });

    test('máy chưa ghi chủ (bản cũ) ⇒ người đăng nhập đầu tiên giữ khoá chung, không bị ngăn cất đè', () async {
      SharedPreferences.setMockInitialValues({
        _active: '{"id":-2,"customer_id":1}',
        '${_active}_u7': '{"id":44,"customer_id":1}',
      });
      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getActive())?.id, -2);
    });

    test('đổi tài khoản chen giữa đọc và ghi ⇒ không mất bản ghi, không ghi nhầm ngăn (thao tác chạy tuần tự)', () async {
      SharedPreferences.setMockInitialValues({VisitLocalStore.ownerKey: 7, _list: '[{"id":1,"customer_id":1}]'});
      const storeA = VisitLocalStore(7);
      await Future.wait([
        storeA.saveVisit(const VisitEntity(id: 2, customerId: 1)),
        VisitLocalStore.switchOwner(8),
        storeA.saveVisit(const VisitEntity(id: 3, customerId: 1)),
      ]);
      expect(await const VisitLocalStore().getAll(), isEmpty);
      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getAll()).map((v) => v.id).toSet(), {1, 2, 3});
    });

    test('huỷ lượt qua ngăn đã chốt sau khi đổi chủ ⇒ ghi đúng ngăn người đó', () async {
      SharedPreferences.setMockInitialValues({
        VisitLocalStore.ownerKey: 7,
        _list: '[{"id":5,"customer_id":1,"client_uuid":"a5"}]',
      });
      final storeA = await VisitLocalStore.current();
      await VisitLocalStore.switchOwner(8);
      await storeA.markCancelled(5, clientUuid: 'a5');
      expect(await const VisitLocalStore().getAll(), isEmpty, reason: 'không chèn lượt đã huỷ của A vào bộ đệm của B');
      await VisitLocalStore.switchOwner(7);
      expect((await const VisitLocalStore().getAll()).single.isCancelled, isTrue);
    });

    test('dọn 60 ngày áp cả ngăn đã cất của người khác (người không quay lại máy)', () async {
      final old = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      final fresh = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
        '${_list}_u7': jsonEncode([
          {'id': 1, 'customer_id': 1, 'checkin_at': old, 'checkout_at': old},
        ]),
        '${_list}_u9': jsonEncode([
          {'id': 2, 'customer_id': 1, 'checkin_at': old, 'checkout_at': old},
          {'id': 3, 'customer_id': 1, 'checkin_at': fresh, 'checkout_at': fresh},
        ]),
        '${_active}_u7': jsonEncode({'id': 1, 'customer_id': 1, 'checkin_at': old}),
        '${_active}_u9': jsonEncode({'id': -4, 'customer_id': 1, 'checkin_at': old}),
      });
      final prefs = await SharedPreferences.getInstance();
      await LocalHistoryRetention.prune();
      expect(prefs.getString('${_list}_u7'), isNull, reason: 'ngăn chỉ còn lượt quá hạn ⇒ xoá');
      expect(prefs.getString('${_list}_u9'), allOf(contains('"id":3'), isNot(contains('"id":2'))));
      expect(prefs.getString('${_active}_u7'), isNull, reason: 'lượt đã lên server, quá hạn');
      expect(prefs.getString('${_active}_u9'), isNotNull, reason: 'lượt chưa gửi (id ≤ 0) giữ');
    });

    test('dọn 60 ngày: ngăn hỏng không chặn ngăn khác; lượt «còn mở» đã lên server trong ngăn cất quá hạn bị dọn', () async {
      final old = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      SharedPreferences.setMockInitialValues({
        '${_list}_u5': '[{"id":', // ghi dở
        '${_list}_u7': jsonEncode([
          {'id': 1, 'customer_id': 1, 'checkin_at': old}, // còn mở (không check-out) — đã lên server
          {'id': -3, 'customer_id': 1, 'checkin_at': old}, // chưa gửi
        ]),
        _list: jsonEncode([
          {'id': 2, 'customer_id': 1, 'checkin_at': old}, // chủ hiện tại: còn mở ⇒ giữ
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      await LocalHistoryRetention.prune();
      expect(prefs.getString('${_list}_u7'), allOf(contains('"id":-3'), isNot(contains('"id":1,'))));
      expect(prefs.getString(_list), contains('"id":2'));
    });

    test('hàng đợi: check-in của A lên server SAU khi B đăng nhập ⇒ mã server ghi vào ngăn của A, B không nhận lượt',
        () async {
      SharedPreferences.setMockInitialValues({
        VisitLocalStore.ownerKey: 7,
        _list: jsonEncode([
          {'id': -5, 'customer_id': 5, 'client_uuid': 'v1'}
        ]),
        _active: jsonEncode({'id': -5, 'customer_id': 5, 'client_uuid': 'v1'}),
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory(), 1);
      addTearDown(db.close);
      await db.setOwner(7);
      final gate = Completer<void>();
      final sent = Completer<void>();
      final adapter = _Adapter((o) async {
        if (!sent.isCompleted) sent.complete();
        await gate.future;
        return _json({
          'success': true,
          'data': {'id': 901}
        });
      });
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(
            ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter)),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ]);
      addTearDown(container.dispose);
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        ownerUserId: const Value(7),
        entity: 'visit',
        op: 'create',
        clientUuid: 'v1',
        payload: jsonEncode({'customer_id': 5}),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

      final run = container.read(syncServiceProvider).syncQueue(force: true);
      await sent.future;
      // B đăng nhập trong lúc check-in của A đang chờ phản hồi.
      await VisitLocalStore.switchOwner(8);
      await db.setOwner(8);
      gate.complete();
      await run;

      expect(await const VisitLocalStore().getAll(), isEmpty, reason: 'lỗi cũ: lượt của A ghi vào bộ đệm của B');
      expect(await const VisitLocalStore().getActive(), isNull);
      expect(prefs.getString('${_active}_u7'), contains('901'));
      expect(prefs.getString('${_list}_u7'), contains('901'));
    });
  });

  group('#24456 bộ đệm cấu hình chấm công', () {
    test('chưa rõ tài khoản ⇒ không đọc khoá chung cũ, không ghi khoá chung', () async {
      SharedPreferences.setMockInitialValues({
        attendanceConfigCachePrefix: jsonEncode({'can_punch': true, 'blocked_reason': 'CỦA NGƯỜI TRƯỚC'}),
      });
      final prefs = await SharedPreferences.getInstance();
      final api = _AttApi()..offline = true;
      final config = await AttendanceRepositoryImpl(api).getConfig();
      expect(config.blockedReason, isNot('CỦA NGƯỜI TRƯỚC'), reason: 'lỗi cũ: rơi về khoá chung, đọc cấu hình người trước');

      api.offline = false;
      await AttendanceRepositoryImpl(api).getConfig();
      expect(prefs.getKeys().where((k) => k.startsWith(attendanceConfigCachePrefix)), [attendanceConfigCachePrefix],
          reason: 'không ghi thêm khoá nào khi chưa rõ tài khoản');
    });

    test('đổi tài khoản trong lúc chờ mạng ⇒ cấu hình của người trước không ghi vào bộ đệm', () async {
      SharedPreferences.setMockInitialValues({AppConstants.keyUserData: _user(7)});
      final prefs = await SharedPreferences.getInstance();
      final api = _AttApi()..gate = Completer();
      final pending = AttendanceRepositoryImpl(api).getConfig();
      await api.called.future; // repo đã chốt tài khoản và đang chờ mạng
      await prefs.setString(AppConstants.keyUserData, _user(8));
      api.gate!.complete(AttendanceConfigModel.fromJson(const {'can_punch': false, 'blocked_reason': 'A'}));
      await pending;
      expect(prefs.getString('${attendanceConfigCachePrefix}_7'), isNull);
      expect(prefs.getString('${attendanceConfigCachePrefix}_8'), isNull);
    });

    test('cùng tài khoản ⇒ ghi bộ đệm theo tài khoản, mất mạng đọc lại được', () async {
      SharedPreferences.setMockInitialValues({AppConstants.keyUserData: _user(7)});
      final api = _AttApi();
      await AttendanceRepositoryImpl(api).getConfig();
      api.offline = true;
      expect((await AttendanceRepositoryImpl(api).getConfig()).blockedReason, 'X');
    });

    test('khoá chung kiểu cũ (cả lịch ca) bị dọn lúc khởi động', () async {
      SharedPreferences.setMockInitialValues({
        attendanceConfigCachePrefix: '{}',
        '${attendanceConfigCachePrefix}_shifts': '[]',
        '${attendanceConfigCachePrefix}_7': '{}',
      });
      final prefs = await SharedPreferences.getInstance();
      await removeLegacySharedCaches(prefs);
      expect(prefs.getKeys(), {'${attendanceConfigCachePrefix}_7'});
    });
  });
}

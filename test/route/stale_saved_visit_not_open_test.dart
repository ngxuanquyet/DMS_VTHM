import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import '../route_filter_day_of_week_test.dart' show MockCustomerRepository, FakeGetRouteDetailUseCase;

/// Sự cố 06/11/2026 (#24893): lượt #48474 check-in 05/11 14:18, huỷ trên server 16:29 — sáng hôm sau mở app vẫn hiện
/// "đang mở", đồng hồ 21:40. Bản lưu "lượt đang mở" trong máy bị `getVisitsByDate` ghép vào danh sách lượt hôm nay ⇒ tuyến
/// chọn nó làm lượt đang mở và bỏ qua bước dọn bản lưu. Kèm #24894 (lượt ngày cũ không giữ) và #24895 (lượt hôm nay huỷ ở
/// máy khác).

class _Adapter implements HttpClientAdapter {
  final (int, Map<String, dynamic>)? Function(RequestOptions o) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final r = handler(o) ?? (200, {'success': true, 'data': <dynamic>[]});
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
  Future<bool> checkConnectivity() async => true;

  @override
  void handleNetworkDisconnection() {}
}

const _activeKey = 'dms_active_visit_session_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [saved] = bản lưu "lượt đang mở" trong máy; [serverVisits] = server trả cho cả danh sách hôm nay lẫn lượt còn mở;
  /// [serverDown] = mọi lệnh gọi trả 500.
  Future<RouteViewModel> load(VisitEntity saved, {List<Map<String, dynamic>> serverVisits = const [],
      bool serverDown = false,
      List<Map<String, dynamic>> Function(int openCall)? openOnly,
      bool settleFirst = false,
      List<VisitEntity> cached = const []}) async {
    var openCalls = 0;
    SharedPreferences.setMockInitialValues({
      'vthm_user_data': '{"id":1}',
      if (!settleFirst) _activeKey: jsonEncode(saved.toJson()),
      if (cached.isNotEmpty) 'dms_visits_local_cache_v2': jsonEncode(cached.map((v) => v.toJson()).toList()),
    });
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
      ..httpClientAdapter = _Adapter((o) {
        if (serverDown) return (500, {'success': false, 'message': 'x'});
        if (openOnly != null && o.uri.toString().contains('open_only=1')) {
          return (200, {'success': true, 'data': openOnly(++openCalls)});
        }
        if (o.path.startsWith('/dms/visits/mine')) return (200, {'success': true, 'data': serverVisits});
        return null;
      });
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      connectivityProvider.overrideWith((ref) => _Online()),
    ]);
    addTearDown(container.dispose);
    final provider = Provider<RouteViewModel>((ref) {
      final repo = ref.read(visitRepositoryProvider);
      return RouteViewModel(
        customerRepository: MockCustomerRepository(),
        getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
        getTodayVisitsUseCase: GetTodayVisitsUseCase(repo),
        visitRepository: repo,
        ref: ref,
      );
    });
    final vm = container.read(provider);
    if (settleFirst) {
      // Cho lượt nạp của constructor xong hẳn rồi mới đặt bản lưu + đếm lần gọi ⇒ lượt nạp dưới chạy MỘT MÌNH, thứ tự
      // gọi xác định: lần 1 = ảnh chụp, lần 2 = hỏi lại.
      await vm.loadRouteDetail();
      await pumpEventQueue(times: 200);
      await (await SharedPreferences.getInstance()).setString(_activeKey, jsonEncode(saved.toJson()));
      openCalls = 0;
    }
    await vm.loadRouteDetail();
    return vm;
  }

  Future<String?> savedRaw() async => (await SharedPreferences.getInstance()).getString(_activeKey);

  final now = DateTime.now();
  // Mốc cố định đầu ngày — "bây giờ trừ N phút" chạy lúc 00:15 rơi sang hôm qua, test nhầm nhánh.
  final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 1);
  VisitEntity visit(int id, DateTime checkinAt) => VisitEntity(
        id: id,
        customerId: 8986,
        clientUuid: 'uuid-$id',
        checkinAt: checkinAt,
        checkinAtRaw: checkinAt.toIso8601String(),
      );

  test('lượt hôm qua đã huỷ trên server ⇒ không hiện đang mở, bản lưu bị dọn (sự cố #48474)', () async {
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 10));
    final vm = await load(visit(48474, yesterday));
    expect(vm.state.activeVisit, isNull, reason: 'lỗi cũ: bản lưu ngày cũ được ghép vào lượt hôm nay');
    expect(vm.state.todayVisits.where((v) => v.id == 48474), isEmpty);
    expect(await savedRaw(), isNull);
  });

  // #24894 (chủ hệ thống chốt 06/11/2026): lượt NGÀY CŨ đã có mã KHÔNG giữ làm lượt đang mở — cron đánh dấu "Chưa check-out".
  test('lượt hôm qua CÒN MỞ trên server (vắt qua nửa đêm) ⇒ không giữ làm lượt đang mở (#24894)', () async {
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(minutes: 10));
    final v = visit(700, yesterday);
    final vm = await load(v, serverVisits: [v.toJson()]);
    expect(vm.state.activeVisit, isNull);
    expect(await savedRaw(), isNull);
  });

  test('lượt hôm qua, server không tra được ⇒ cũng không giữ (#24894)', () async {
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 10));
    final vm = await load(visit(48474, yesterday), serverDown: true);
    expect(vm.state.activeVisit, isNull);
  });

  test('lượt ngoại tuyến hôm qua chưa lên server (id âm) ⇒ giữ — bỏ là mất lượt', () async {
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(minutes: 10));
    final vm = await load(visit(-7, yesterday));
    expect(vm.state.activeVisit?.id, -7);
    expect(await savedRaw(), isNotNull);
  });

  // #24895: lượt HÔM NAY huỷ ở máy khác — server bỏ lượt đã huỷ khỏi mọi danh sách.
  test('lượt hôm nay đã huỷ ở máy khác (server không trả) ⇒ không hiện đang mở, bản lưu bị dọn (#24895)', () async {
    final v = visit(501, startOfToday);
    final vm = await load(v, cached: [v]);
    expect(vm.state.activeVisit, isNull, reason: 'lỗi cũ: bản lưu ghép vào danh sách hôm nay');
    expect(vm.state.todayVisits.where((x) => x.id == 501), isEmpty);
    expect(await savedRaw(), isNull);
  });

  test('bản "mở" chỉ còn trong bộ đệm lượt của máy (không có bản lưu đang mở) ⇒ không vào danh sách hôm nay (#24895)', () async {
    final v = visit(502, startOfToday);
    // Bản lưu hỏng (không mã, không điểm bán) ⇒ getActiveVisit coi như không có.
    final vm = await load(const VisitEntity(id: 0, customerId: 0), cached: [v]);
    expect(vm.state.todayVisits.where((x) => x.id == 502), isEmpty);
    expect(vm.state.activeVisit?.id, isNot(502));
  });

  test('vừa check-in, ảnh chụp server chưa có lượt ⇒ hỏi lại server, giữ (không dọn nhầm)', () async {
    final v = visit(503, startOfToday);
    // Danh sách hôm nay + ảnh chụp lượt mở (lần 1) chưa thấy, lần hỏi lại (lần 2) đã thấy.
    final vm = await load(v, settleFirst: true, openOnly: (n) => n <= 1 ? <Map<String, dynamic>>[] : [v.toJson()]);
    expect(vm.state.activeVisit?.id, 503);
    expect(await savedRaw(), isNotNull);
  });

  test('lượt hôm nay còn mở trên server ⇒ vẫn là lượt đang mở', () async {
    final at = startOfToday;
    final vm = await load(visit(501, at), serverVisits: [
      {'id': 501, 'customer_id': 8986, 'client_uuid': 'uuid-501', 'checkin_at': at.toIso8601String()},
    ]);
    expect(vm.state.activeVisit?.id, 501);
  });

  test('không tra được server ⇒ giữ lượt hôm nay trong máy', () async {
    final v = visit(501, startOfToday);
    final vm = await load(v, serverDown: true, cached: [v]);
    expect(vm.state.activeVisit?.id, 501);
    expect(await savedRaw(), isNotNull);
  });

  test('lượt ngoại tuyến chưa lên server (id âm) ⇒ giữ dù server trả rỗng', () async {
    final vm = await load(visit(-5, startOfToday));
    expect(vm.state.activeVisit?.id, -5);
  });

  group('getVisitsByDate — lượt trong máy mà danh sách server thiếu (#24895)', () {
    late bool down;
    late List<Map<String, dynamic>> open;
    late VisitRepositoryImpl repo;

    Future<void> boot(List<VisitEntity> cached) async {
      down = false;
      open = [];
      SharedPreferences.setMockInitialValues({
        'vthm_user_data': '{"id":1}',
        'dms_visits_local_cache_v2': jsonEncode(cached.map((v) => v.toJson()).toList()),
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((o) {
          if (down) return (500, {'success': false, 'message': 'x'});
          if (o.uri.toString().contains('open_only=1')) return (200, {'success': true, 'data': open});
          return null; // danh sách theo ngày: rỗng
        });
      repo = VisitRepositoryImpl(VisitApiService(ApiClient(dio)));
    }

    test('server xác nhận không còn mở ⇒ bỏ bản sao khỏi bộ đệm (KHÔNG ghi huỷ — là suy luận) — mất mạng sau đó KHÔNG hiện lại là đang mở', () async {
      await boot([visit(502, startOfToday)]);
      expect((await repo.getVisitsByDate(now)).where((v) => v.isOpen), isEmpty);
      down = true;
      expect((await repo.getVisitsByDate(now)).where((v) => v.isOpen), isEmpty,
          reason: 'lỗi: chỉ ẩn khi có mạng, bộ đệm còn bản "mở"');
    });

    test('danh sách theo ngày thiếu (vừa check-in / cắt trang) mà lượt còn mở ⇒ giữ', () async {
      final v = visit(503, startOfToday);
      await boot([v]);
      open = [v.toJson()];
      expect((await repo.getVisitsByDate(now)).map((x) => x.id), contains(503));
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/dynamic_form/repeat_group.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/daily_report/presentation/viewmodels/visit_report_view_model.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';

/// Rà soát 24/11/2026 (#25868) — nhóm B: điểm bán, biểu mẫu, báo cáo ngày. Mỗi test tái hiện một lỗi đã vá.

class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions o) handler;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    return ResponseBody.fromString(jsonEncode(handler(o)), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

/// Ghi máy hỏng SAU khi server đã tạo điểm bán (vd SQLite đầy / khoá).
class _CacheHong extends CustomerLocalDataSource {
  _CacheHong(super.db);

  @override
  Future<void> cacheRemoteCustomers(
    List<CustomerEntity> remoteList, {
    bool reconcile = false,
    Set<int>? syncedIdsBeforeFetch,
    Future<bool> Function()? isStale,
    bool localEdit = false,
  }) async =>
      throw StateError('SqliteException: database is locked');
}

class _VisitRepo implements VisitRepository {
  final List<VisitEntity> local;
  _VisitRepo(this.local);

  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async =>
      throw Exception('mất mạng');

  @override
  Future<List<VisitEntity>> getAllLocalVisits() async => local;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late _Adapter adapter;
  var online = true;
  final dong = <Future<void> Function()>[];
  tearDown(() async {
    for (final f in dong) {
      await f();
    }
    dong.clear();
  });

  CustomerRepositoryImpl boot(Map<String, dynamic> Function(RequestOptions o) handler,
      {CustomerLocalDataSource Function(AppDatabase db)? local}) {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 1);
    adapter = _Adapter(handler);
    online = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final api = ApiClient(dio);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(api),
      connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
    ]);
    final dbNay = db, cNay = container;
    dong.add(() async {
      cNay.dispose();
      await dbNay.close();
    });
    return CustomerRepositoryImpl(CustomerApiService(api), (local ?? CustomerLocalDataSource.new)(db),
        container.read(syncServiceProvider), null, () => online);
  }

  Map<String, dynamic> taoOk(RequestOptions o, {bool created = true}) => o.path == '/crm/customers' && o.method == 'POST'
      ? {
          'success': true,
          'data': {'id': 8888, 'code': '08190163', 'created': created, 'route_ids': [5]},
        }
      : {'success': true, 'data': <dynamic>[]};

  Map<String, dynamic> input() => {'name': 'Cửa hàng A', 'region_id': 12, 'route_ids': [5], 'phone': '0988888888'};

  group('1. Xoá trắng ô của điểm bán CHƯA đồng bộ', () {
    test('bản trong máy và dòng tạo chờ gửi không còn giá trị đã xoá', () async {
      boot((o) => {'success': true});
      await db.setOwner(7);
      final local = CustomerLocalDataSource(db);
      await local.createCustomerOffline({
        'name': 'A',
        'client_uuid': 'uuid-xoa-1',
        'phone': '0901234567',
        'contact_name': 'Anh Ba',
        'contact_title': 'Chủ',
        'email': 'a@b.vn',
        'address': '1 Lê Lợi',
      });
      // Màn sửa gửi `null` cho ô vừa xoá trắng.
      final e = await local.updateCustomerOffline(
          'uuid-xoa-1', {'phone': null, 'contact_name': null, 'contact_title': null, 'email': null});

      expect(e.phone, '', reason: 'lỗi cũ: `null ?? cũ` ⇒ SĐT đã xoá vẫn nằm trong máy');
      expect(e.contactPerson, '');
      expect(e.contactTitle, isNull);
      expect(e.email, isNull);
      expect(e.address, '1 Lê Lợi', reason: 'ô không đụng tới giữ nguyên');

      final p = jsonDecode((await db.getAllPendingQueueEntries()).single.payload) as Map<String, dynamic>;
      for (final k in ['phone', 'contact_name', 'contact_title', 'email']) {
        expect(p.containsKey(k), isFalse, reason: 'lỗi cũ: gộp bỏ qua ô trống ⇒ dòng tạo vẫn gửi $k cũ');
      }
      expect(p['address'], '1 Lê Lợi');
    });

    test('điểm bán đã có trên server, sửa ngoại tuyến: thực thể trả về không giữ giá trị đã xoá', () async {
      final repo = boot(taoOk);
      await db.setOwner(7);
      await repo.createCustomer({...input(), 'email': 'a@b.vn', 'contact_name': 'Anh Ba'});
      online = false;
      final e = await repo.updateCustomer(id: 8888, changes: {'phone': null, 'email': null, 'contact_name': null});
      expect(e.phone, '');
      expect(e.email, '');
      expect(e.contactPerson, '');
    });
  });

  group('2. Ghi sổ sau POST tạo THÀNH CÔNG', () {
    test('ghi máy hỏng ⇒ vẫn trả điểm bán đã tạo, không báo lỗi, không xếp hàng', () async {
      final repo = boot(taoOk, local: _CacheHong.new);
      await db.setOwner(7);
      final e = await repo.createCustomer(input());
      expect(e.id, 8888, reason: 'lỗi cũ: lỗi SQLite rơi vào nhánh bắt lỗi gửi ⇒ ném ra dù server đã tạo');
      expect(await db.getAllPendingQueueEntries(), isEmpty);
      expect(adapter.calls.where((c) => c.method == 'POST' && c.path == '/crm/customers'), hasLength(1));
    });
  });

  group('5. Lưu lại cùng client_uuid mà server đã tạo ở lần trước', () {
    test('created=false ⇒ thực thể mang dấu alreadyCreated; created=true ⇒ không', () async {
      var repo = boot((o) => taoOk(o, created: false));
      await db.setOwner(7);
      expect((await repo.createCustomer(input())).alreadyCreated, isTrue);

      repo = boot(taoOk);
      await db.setOwner(7);
      expect((await repo.createCustomer(input())).alreadyCreated, isFalse);
    });

    test('câu báo người dùng', () {
      expect(addCustomerAlreadyCreatedMessage, contains('đã được tạo ở lần lưu trước'));
    });
  });

  group('4. Ô chọn CON của bảng lặp mang lựa chọn admin đã gỡ', () {
    Map<String, dynamic> cot(String code, String type, {bool other = false}) => {
          'ref': code,
          'required': false,
          'resolved': {
            'code': code,
            'label': code,
            'input_type': type,
            'config': {
              'options': [
                {'value': 'A', 'label': 'A'},
                {'value': 'B', 'label': 'B'},
              ],
              if (other) 'allow_other': true,
            },
          },
        };
    final nhom = {
      'type': 'group',
      'ref': 'nhom',
      'required': false,
      'resolved': {
        'code': 'nhom',
        'name': 'Nhóm',
        'kind': 'table',
        'config': {'min_rows': 0, 'max_rows': 5},
        'items': [
          {
            'ref': 'ten',
            'required': false,
            'resolved': {'code': 'ten', 'label': 'Tên', 'input_type': 'text', 'config': {}},
          },
          cot('mot', 'select'),
          cot('nhieu', 'multiselect'),
          cot('khac', 'select', other: true),
        ],
      },
    };

    test('đặc tả: bỏ giá trị lạ ở ô chọn một / nhiều; ô cho «Khác…» giữ; không đổi ⇒ giữ tham chiếu', () {
      final r = nhom['resolved'] as Map;
      final spec = RepeatGroupSpec.fromEngineItems(r['items'], r['config']);
      final rows = [
        {'line_id': 'a', 'ten': 'X', 'mot': 'C', 'nhieu': ['A', 'C'], 'khac': 'Tự gõ'},
      ];
      final kept = spec.dropRemovedOptions(rows);
      expect(kept.single.containsKey('mot'), isFalse);
      expect(kept.single['nhieu'], ['A']);
      expect(kept.single['khac'], 'Tự gõ');
      final sach = [
        {'line_id': 'b', 'mot': 'A', 'nhieu': ['B']},
      ];
      expect(identical(spec.dropRemovedOptions(sach), sach), isTrue);
    });

    testWidgets('MarketFormRenderer: câu trả lời dựng sẵn ⇒ bản nộp không mang lựa chọn đã gỡ', (tester) async {
      final block = MarketFormBlockModel.fromJson(Map<String, dynamic>.from(nhom)).toEntity();
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFormRenderer(key: key, blocks: [block], initialAnswers: const {
              'nhom': [
                {'line_id': 'a1b2c3d4e5f60718', 'ten': 'X', 'mot': 'C', 'nhieu': ['A', 'C']},
              ],
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final answers = key.currentState!.validateAndGetAnswers();
      expect(answers, isNotNull);
      final row = (answers!['nhom'] as List).single as Map;
      expect(row.containsKey('mot'), isFalse, reason: 'lỗi cũ: chỉ xét ô cấp một ⇒ server từ chối «ngoài danh sách»');
      expect(row['nhieu'], ['A']);
      expect(row['ten'], 'X');
    });
  });

  group('6. Báo cáo ngày', () {
    test('lỗi API ⇒ chỉ hiện lượt trong máy của NGÀY đang chọn', () async {
      final now = DateTime.now();
      final homQua = now.subtract(const Duration(days: 1));
      final c = ProviderContainer(overrides: [
        visitRepositoryProvider.overrideWithValue(_VisitRepo([
          VisitEntity(id: 1, customerId: 1, checkinAt: now),
          VisitEntity(id: 2, customerId: 2, checkinAt: homQua),
          VisitEntity(id: 3, customerId: 3, visitDate: '2020-01-01'),
        ])),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(visitReportViewModelProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().visits.map((v) => v.id), [1], reason: 'lỗi cũ: getAllLocalVisits() mọi ngày');
    });

    test('provider autoDispose: đóng màn rồi mở lại ⇒ trạng thái mới (ngày mặc định tính lại)', () async {
      final c = ProviderContainer(overrides: [visitRepositoryProvider.overrideWithValue(_VisitRepo(const []))]);
      addTearDown(c.dispose);
      final sub = c.listen(visitReportViewModelProvider.notifier, (_, __) {});
      final truoc = sub.read();
      truoc.setDate(DateTime(2020, 1, 1));
      sub.close();
      await c.pump();
      final sau = c.read(visitReportViewModelProvider);
      expect(sau.selectedDate.year, DateTime.now().year, reason: 'lỗi cũ: provider giữ mãi ⇒ ngày đứng ở lần trước');
    });
  });
}

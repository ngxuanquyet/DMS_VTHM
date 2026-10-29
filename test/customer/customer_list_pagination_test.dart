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
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';

/// Giả máy chủ `/crm/customers/mine` có [total] điểm bán, chặn `per-page` tối đa 200 như `CustomerSearch`.
class PagedCustomersAdapter implements HttpClientAdapter {
  int total;
  final List<int> requestedPages = [];
  final List<int> requestedPerPage = [];

  /// Số lần gọi tới còn phải trả lỗi 500 (giả mạng hỏng).
  int failNext = 0;

  /// Chạy GIỮA lúc server đang trả trang — giả lập việc khác ghi SQLite (hoặc server đổi dữ liệu) khi app đang tải.
  Future<void> Function(int page)? duringFetch;

  PagedCustomersAdapter(this.total);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final page = int.parse(options.queryParameters['page'].toString());
    final perPage = int.parse(options.queryParameters['per-page'].toString()).clamp(1, 200);
    requestedPages.add(page);
    requestedPerPage.add(perPage);
    if (duringFetch != null) await duringFetch!(page);
    if (failNext > 0) {
      failNext--;
      return ResponseBody.fromString('{"success":false}', 500, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final pageCount = (total / perPage).ceil();
    final from = (page - 1) * perPage;
    final to = (from + perPage).clamp(0, total);
    final res = {
      'success': true,
      'data': [
        for (var i = from; i < to; i++)
          {'id': i + 1, 'code': 'DMS${i + 1}', 'name': 'Điểm bán ${i + 1}', 'status': 'active'},
      ],
      'meta': {'total': total, 'currentPage': page, 'pageSize': perPage, 'pageCount': pageCount},
    };
    return ResponseBody.fromString(
      jsonEncode(res),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 1);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  /// Repository dựng qua provider để có `Ref` thật — lượt tải ngầm báo màn qua [customerCacheVersionProvider].
  CustomerRepositoryImpl buildRepo(PagedCustomersAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);
    final repoProvider = Provider<CustomerRepositoryImpl>(
      (ref) => CustomerRepositoryImpl(
        CustomerApiService(apiClient),
        CustomerLocalDataSource(db),
        ref.read(syncServiceProvider),
        ref,
        () => true,
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ],
    );
    return container.read(repoProvider);
  }

  /// Chờ lượt tải ngầm báo xong (bộ đếm tăng).
  Future<void> waitBackgroundRefresh() {
    final done = Completer<void>();
    final sub = container.listen(customerCacheVersionProvider, (_, __) {
      if (!done.isCompleted) done.complete();
    });
    return done.future.timeout(const Duration(seconds: 10)).whenComplete(sub.close);
  }

  test('người phụ trách hơn 200 điểm bán nhận ĐỦ mọi trang, mỗi lần gọi 100 dòng', () async {
    final adapter = PagedCustomersAdapter(450);
    final repo = buildRepo(adapter);

    final customers = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1, 2, 3, 4, 5]);
    expect(adapter.requestedPerPage.toSet(), {100});
    expect(customers.length, 450);
  });

  test('máy còn bản cũ 199 điểm, server 1.090: trả ngay bản máy, tải ngầm xong thì BÁO màn và bản máy đủ 1.090', () async {
    final adapter = PagedCustomersAdapter(199);
    await buildRepo(adapter).getCustomers(forceRefresh: true);
    // Mở app lần sau: SQLite còn 199 điểm, repository mới (chưa có mốc tải gần nhất).
    container.dispose();
    final repo = buildRepo(adapter);

    adapter
      ..total = 1090
      ..requestedPages.clear();
    final refreshed = waitBackgroundRefresh();
    final first = await repo.getCustomers();
    expect(first.length, 199); // bản trong máy, trả ngay
    await refreshed;

    expect(adapter.requestedPages.length, 11);
    // Màn nạp lại sau khi được báo: lấy từ máy, đủ 1.090, KHÔNG mở thêm lượt tải ngầm (chặn vòng lặp).
    adapter.requestedPages.clear();
    final again = await repo.getCustomers();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again.length, 1090);
    expect(adapter.requestedPages, isEmpty);
  });

  test('đổi tài khoản trong 5 phút vẫn tải ngầm cho tài khoản mới; cùng tài khoản thì không', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: '{"id": 1}'});
    final adapter = PagedCustomersAdapter(120);
    final repo = buildRepo(adapter);
    await repo.getCustomers(forceRefresh: true);

    adapter.requestedPages.clear();
    await repo.getCustomers();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.requestedPages, isEmpty); // cùng tài khoản, vừa tải xong ⇒ không tải ngầm

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserData, '{"id": 2}');
    final refreshed = waitBackgroundRefresh();
    await repo.getCustomers();
    await refreshed;
    expect(adapter.requestedPages, [1, 2]);
  });

  test('kéo làm mới khi đang có lượt tải ngầm ⇒ chờ lượt đó, không tải song song', () async {
    final adapter = PagedCustomersAdapter(199);
    await buildRepo(adapter).getCustomers(forceRefresh: true);
    container.dispose();
    final repo = buildRepo(adapter);
    adapter
      ..total = 450
      ..requestedPages.clear();

    await repo.getCustomers(); // mở tải ngầm
    final forced = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1, 2, 3, 4, 5]); // một lượt duy nhất
    expect(forced.length, 450);
  });

  test('kéo làm mới khi lượt tải ngầm đang chạy mà HỎNG ⇒ đi chung lượt đó (không tải song song), trả bản trong máy', () async {
    final adapter = PagedCustomersAdapter(199);
    await buildRepo(adapter).getCustomers(forceRefresh: true);
    container.dispose();
    final repo = buildRepo(adapter);
    adapter
      ..total = 450
      ..failNext = 1 // lượt ngầm hỏng ngay trang 1
      ..requestedPages.clear();

    await repo.getCustomers(); // mở tải ngầm (sẽ hỏng)
    final forced = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1]);
    expect(forced.length, 199);
  });

  test('tài khoản KHÔNG có điểm bán nào: tải xong báo màn, màn nạp lại KHÔNG tải tiếp (không lặp vô tận)', () async {
    final adapter = PagedCustomersAdapter(0);
    final repo = buildRepo(adapter);
    var bumps = 0;
    container.listen(customerCacheVersionProvider, (_, __) => bumps++);

    expect(await repo.getCustomers(), isEmpty); // máy trống ⇒ tải
    expect(bumps, 1);
    adapter.requestedPages.clear();

    expect(await repo.getCustomers(), isEmpty); // màn nạp lại sau khi được báo
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.requestedPages, isEmpty);
    expect(bumps, 1);
  });

  test('đổi tài khoản GIỮA lúc tải ⇒ không ghi danh sách của tài khoản cũ vào máy', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: '{"id": 1}'});
    final adapter = PagedCustomersAdapter(150);
    final repo = buildRepo(adapter);
    adapter.duringFetch = (page) async {
      if (page == 2) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyUserData, '{"id": 2}');
      }
    };

    await repo.getCustomers(forceRefresh: true).catchError((_) => <CustomerEntity>[]);

    expect(await db.getAllLocalCustomers(), isEmpty);
  });

  test('vừa tải đủ (50 điểm) rồi bảng bị xoá (đăng xuất → vào lại) ⇒ mở màn vẫn TẢI LẠI, không trả rỗng', () async {
    final adapter = PagedCustomersAdapter(50);
    final repo = buildRepo(adapter);
    await repo.getCustomers(forceRefresh: true);
    await db.delete(db.localCustomers).go();
    adapter.requestedPages.clear();

    final again = await repo.getCustomers();

    expect(adapter.requestedPages, [1]);
    expect(again.length, 50);
  });

  test('server thêm/xoá điểm bán GIỮA hai trang (total đổi) ⇒ không reconcile, không xoá nhầm dòng bị sót', () async {
    final adapter = PagedCustomersAdapter(300);
    final repo = buildRepo(adapter);
    await repo.getCustomers(forceRefresh: true);

    adapter.duringFetch = (page) async {
      if (page == 2) adapter.total = 299;
    };
    await repo.getCustomers(forceRefresh: true);

    expect((await db.getAllLocalCustomers()).length, 300);
  });

  test('điểm bán thành "đã đồng bộ" GIỮA lúc tải danh sách không bị reconcile xoá nhầm; điểm server đã bỏ vẫn bị xoá', () async {
    final adapter = PagedCustomersAdapter(150);
    final repo = buildRepo(adapter);
    await repo.getCustomers(forceRefresh: true);

    // Điểm bán tạo offline đang chờ đẩy lên.
    await db.insertOrUpdateCustomer(
      LocalCustomersCompanion(
        clientUuid: const Value('offline-1'),
        name: const Value('Điểm tạo offline'),
        nameUnaccent: const Value('diem tao offline'),
        address: const Value('Hà Nội'),
        phone: const Value('0900000000'),
        contactPerson: const Value('A'),
        syncStatus: const Value('pending'),
      ),
    );

    // Lượt tải tiếp: server đã bỏ điểm 150; trong lúc trả trang, hàng đợi đẩy điểm offline lên thành công (id 9001),
    // nhưng danh sách server vừa chụp chưa có 9001.
    adapter
      ..total = 149
      ..duringFetch = (_) => db.markCustomerSynced('offline-1', 9001);
    final customers = await repo.getCustomers(forceRefresh: true);

    final ids = customers.map((c) => c.id).toSet();
    expect(ids, contains(9001));
    expect(ids, isNot(contains(150)));
    expect(customers.length, 150); // 149 của server + điểm vừa đồng bộ
  });

  test('ít hơn một trang thì chỉ gọi một lần', () async {
    final adapter = PagedCustomersAdapter(80);
    final repo = buildRepo(adapter);

    final customers = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1]);
    expect(customers.length, 80);
  });
}

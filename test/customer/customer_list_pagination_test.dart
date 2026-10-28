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
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';

/// Giả máy chủ `/crm/customers/mine` có [total] điểm bán, chặn `per-page` tối đa 200 như `CustomerSearch`.
class PagedCustomersAdapter implements HttpClientAdapter {
  final int total;
  final List<int> requestedPages = [];

  PagedCustomersAdapter(this.total);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final page = int.parse(options.queryParameters['page'].toString());
    final perPage = int.parse(options.queryParameters['per-page'].toString()).clamp(1, 200);
    requestedPages.add(page);
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

  CustomerRepositoryImpl buildRepo(PagedCustomersAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ],
    );
    return CustomerRepositoryImpl(
      CustomerApiService(apiClient),
      CustomerLocalDataSource(db),
      container.read(syncServiceProvider),
      null,
      () => true,
    );
  }

  test('người phụ trách hơn 200 điểm bán nhận ĐỦ mọi trang, không cụt ở trang 1', () async {
    final adapter = PagedCustomersAdapter(450);
    final repo = buildRepo(adapter);

    final customers = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1, 2, 3]);
    expect(customers.length, 450);
  });

  test('ít hơn một trang thì chỉ gọi một lần', () async {
    final adapter = PagedCustomersAdapter(150);
    final repo = buildRepo(adapter);

    final customers = await repo.getCustomers(forceRefresh: true);

    expect(adapter.requestedPages, [1]);
    expect(customers.length, 150);
  });
}

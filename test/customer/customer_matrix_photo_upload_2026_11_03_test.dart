import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';

/// Máy chủ giả: tải ảnh điểm bán thành công/lỗi theo cờ; ghi lại thân request tạo điểm bán.
class _Adapter implements HttpClientAdapter {
  bool uploadFails = false;
  Map? created;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    ResponseBody ok(Object body, [int code = 200]) =>
        ResponseBody.fromString(jsonEncode(body), code, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    if (o.path == '/crm/customer-photos') {
      return uploadFails ? ok({'success': false, 'message': 'lỗi máy chủ'}, 500) : ok({'success': true, 'data': {'token': 'e' * 32}});
    }
    if (o.path == '/crm/customers' && o.method == 'POST') {
      created = o.data is Map ? o.data as Map : null;
      return ok({'success': true, 'data': {'id': 9001, 'code': 'DMS0001', 'created': true}}, 201);
    }
    return ok({'success': true, 'data': []});
  }

  @override
  void close({bool force = false}) {}
}

/// Ảnh theo loại của ô Ma trận trưng bày khi TẠO điểm bán có mạng (#24773):
///  - tải ảnh lỗi giữa chừng ⇒ cả lượt tạo rơi về hàng đợi (không gửi đường dẫn máy cho server từ chối);
///  - tải được ⇒ gửi token trong `data`, và bản chép lâu dài trên máy được dọn.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _Adapter adapter;
  late ProviderContainer container;
  late CustomerRepositoryImpl repo;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(), 1);
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(apiClient),
      connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
    ]);
    repo = CustomerRepositoryImpl(
      CustomerApiService(apiClient),
      CustomerLocalDataSource(db),
      container.read(syncServiceProvider),
      null,
      () => true,
    );
    tmp = await Directory.systemTemp.createTemp('matrix_');
  });

  tearDown(() async {
    await db.close();
    container.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> anh() async {
    final dir = Directory('${tmp.path}/offline_customer_photos')..createSync(recursive: true);
    return File('${dir.path}/ke_${DateTime.now().microsecondsSinceEpoch}.jpg')..writeAsBytesSync([1, 2, 3]);
  }

  Map<String, dynamic> input(String path) => {
        'name': 'Điểm bán SOS',
        'region_id': 1,
        'route_ids': [1],
        'sos': {
          'counts': {'vthm': {'ke': 2}},
          'photos': {'ke': [path]},
        },
      };

  test('tải ảnh ma trận lỗi ⇒ rơi về hàng đợi, không POST đường dẫn máy', () async {
    adapter.uploadFails = true;
    final f = await anh();
    await repo.createCustomer(input(f.path));
    expect(adapter.created, isNull, reason: 'không gửi điểm bán kèm đường dẫn máy');
    expect(await db.countPendingSync(), greaterThanOrEqualTo(1));
    expect(await f.exists(), isTrue, reason: 'giữ ảnh cho lượt đồng bộ');
  });

  test('tải ảnh ma trận được ⇒ gửi token, dọn bản chép trên máy', () async {
    final f = await anh();
    await repo.createCustomer(input(f.path));
    final data = adapter.created?['data'] as Map?;
    expect(data?['sos']['photos']['ke'], ['e' * 32]);
    expect(await f.exists(), isFalse);
    expect(matrixLocalPaths({'x': {'photos': {'k': ['e' * 32, '/a/b.jpg']}}}), ['/a/b.jpg']);
  });
}

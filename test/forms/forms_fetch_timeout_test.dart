import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/forms/data/repositories/forms_repository_impl.dart';
import 'package:vthm_dms/features/forms/data/services/forms_api_service.dart';

/// Biểu mẫu thị trường chờ server có TRẦN (29/10/2026, tham số `forms.fetch_timeout_seconds`): mạng yếu thì mở ngay
/// bản đã lưu + làm mới ngầm, thay vì đứng chờ tới hết quá giờ 15 giây.
class _SlowFormsAdapter implements HttpClientAdapter {
  Duration delay = Duration.zero;
  String name = 'Mẫu mới';
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    await Future<void>.delayed(delay);
    final body = {
      'success': true,
      'data': [
        {'config_id': 1, 'form_id': 1, 'code': 'F1', 'name': name, 'kind': 'collect'},
      ],
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SlowFormsAdapter adapter;
  late FormsRepositoryImpl repo;
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: '{"id": 7}'});
    adapter = _SlowFormsAdapter();
    db = AppDatabase(NativeDatabase.memory(), 7);
    final api = ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter);
    repo = FormsRepositoryImpl(FormsApiService(api), db, fetchTimeout: () => const Duration(milliseconds: 100));
  });
  tearDown(() => db.close());

  test('mạng nhanh ⇒ lấy bản mới từ server và lưu lại', () async {
    final forms = await repo.getAvailableForms(kind: 'collect', customerId: 5);
    expect(forms.single.name, 'Mẫu mới');
  });

  test('mạng chậm + CÓ bản lưu ⇒ mở bản lưu ngay; lượt tải chạy tiếp ngầm rồi ghi đè bản lưu', () async {
    adapter.name = 'Mẫu cũ';
    await repo.getAvailableForms(kind: 'collect', customerId: 5); // tạo bản lưu

    adapter
      ..name = 'Mẫu mới'
      ..delay = const Duration(milliseconds: 400);
    final sw = Stopwatch()..start();
    final forms = await repo.getAvailableForms(kind: 'collect', customerId: 5);
    sw.stop();
    expect(forms.single.name, 'Mẫu cũ');
    expect(sw.elapsedMilliseconds, lessThan(350)); // không chờ tới khi server trả

    await Future<void>.delayed(const Duration(milliseconds: 500)); // lượt tải ngầm xong
    adapter.delay = const Duration(seconds: 1); // lần sau lại chậm ⇒ đọc bản lưu (đã được làm mới)
    final again = await repo.getAvailableForms(kind: 'collect', customerId: 5);
    expect(again.single.name, 'Mẫu mới');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
  });

  test('mạng chậm + CHƯA có bản lưu ⇒ chờ tiếp tới khi server trả', () async {
    adapter.delay = const Duration(milliseconds: 300);
    final forms = await repo.getAvailableForms(kind: 'collect', customerId: 9);
    expect(forms.single.name, 'Mẫu mới');
  });

  test('mở hai lần cùng lúc khi mạng chậm ⇒ chỉ MỘT lượt tải lên server (dùng chung lượt đang chạy)', () async {
    adapter.delay = const Duration(milliseconds: 300);
    final results = await Future.wait([
      repo.getAvailableForms(kind: 'collect', customerId: 11),
      repo.getAvailableForms(kind: 'collect', customerId: 11),
    ]);
    expect(adapter.calls, 1);
    expect(results.every((r) => r.single.name == 'Mẫu mới'), isTrue);
  });
}

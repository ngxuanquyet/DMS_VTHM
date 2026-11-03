import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/data/repositories/forms_repository_impl.dart';
import 'package:vthm_dms/features/forms/data/services/forms_api_service.dart';

/// Rà soát offline vòng 3 (03/11/2026, #24698) — nhóm B: mỗi test tái hiện một lỗi đã vá.

/// API giả: ghi lại mọi lời gọi; [onCall] chạy trước khi trả lỗi / kết quả.
class _Api implements ApiClient {
  final Object? error;
  final Future<void> Function()? onCall;
  final calls = <Symbol>[];
  _Api({this.error, this.onCall});

  @override
  dynamic noSuchMethod(Invocation invocation) async {
    calls.add(invocation.memberName);
    await onCall?.call();
    if (error != null) throw error!;
    return {'success': true, 'data': {'id': 1}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 7})});
    db = AppDatabase(NativeDatabase.memory(), 1);
    await db.setOwner(7);
  });
  tearDown(() async => db.close());

  test('S2 chấm công gặp phiên bị máy chủ từ chối giữa chừng (hồ sơ bị xoá) ⇒ vẫn xếp hàng, không báo "đổi tài khoản"', () async {
    final api = _Api(
      error: const ServerException('hết phiên', 401),
      onCall: () async => (await SharedPreferences.getInstance()).remove(AppConstants.keyUserData),
    );
    final repo = AttendanceRepositoryImpl(AttendanceApiService(api), database: db);
    final punch = await repo.punch(lat: 21, lng: 105.8, clientUuid: 'p-401');
    expect(punch.clientUuid, 'p-401');
    final rows = await db.getAllPendingQueueEntries();
    expect(rows.where((r) => r.entity == 'attendance_punch').single.ownerUserId, 7,
        reason: 'lỗi cũ: báo "Tài khoản đăng nhập đã thay đổi" và mất lượt chấm');
  });

  test('S2 phiên bị từ chối giữa chừng ⇒ ảnh của lượt chấm vẫn xếp hàng được (không báo "đổi tài khoản")', () async {
    final api = _Api(
      error: const ServerException('hết phiên', 401),
      onCall: () async => (await SharedPreferences.getInstance()).remove(AppConstants.keyUserData),
    );
    final repo = AttendanceRepositoryImpl(AttendanceApiService(api), database: db);
    final punch = await repo.punch(lat: 21, lng: 105.8, clientUuid: 'p-ph');
    final tmp = await Directory.systemTemp.createTemp('ph');
    final f = File('${tmp.path}/a.jpg')..writeAsBytesSync([1]);
    await repo.uploadPunchPhoto(punchId: punch.id, file: f, photoType: 'front', parentUuid: 'p-ph');
    expect((await db.getAllPendingQueueEntries()).where((r) => r.entity == 'attendance_photo'), hasLength(1));
  });

  test('S2 người dùng TỰ đăng xuất kèm xoá dữ liệu trong lúc chấm ⇒ KHÔNG xếp lại lượt chấm vào máy', () async {
    final api = _Api(
      error: const ServerException('tạm', 503),
      onCall: () async {
        expect(await db.clearUserData(), isTrue);
        await db.setOwner(null);
        await (await SharedPreferences.getInstance()).remove(AppConstants.keyUserData);
      },
    );
    final repo = AttendanceRepositoryImpl(AttendanceApiService(api), database: db);
    await expectLater(repo.punch(lat: 21, lng: 105.8, clientUuid: 'p-out'), throwsA(isA<AppException>()));
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
  });

  test('S2 chấm công khi người KHÁC đã đăng nhập giữa chừng ⇒ vẫn báo đổi tài khoản', () async {
    final api = _Api(
      error: const ServerException('tạm', 503),
      onCall: () async =>
          (await SharedPreferences.getInstance()).setString(AppConstants.keyUserData, jsonEncode({'id': 8})),
    );
    final repo = AttendanceRepositoryImpl(AttendanceApiService(api), database: db);
    await expectLater(repo.punch(lat: 21, lng: 105.8, clientUuid: 'p-x'), throwsA(isA<AppException>()));
    expect(await db.getAllPendingQueueEntries(), isEmpty);
  });

  group('phiếu khảo sát', () {
    test('V3 lượt check-in ngoại tuyến chưa lên server (mã âm) ⇒ phiếu đi hàng đợi, KHÔNG gửi thẳng', () async {
      final api = _Api();
      final repo = FormsRepositoryImpl(FormsApiService(api), db);
      await repo.submitForm(MarketFormSubmissionModel(
        configId: 1,
        visitId: -5,
        customerId: 20,
        answers: {'q1': 'a'},
        parentUuid: 'vOffline',
      ));
      expect(api.calls, isEmpty, reason: 'lỗi cũ: gửi thẳng visit_id âm ⇒ 422, báo lỗi, kẹt cổng phiếu');
      final row = (await db.getAllPendingQueueEntries()).single;
      expect(row.entity, 'form_submission');
      expect(row.parentUuid, 'vOffline');
    });

    test('V4 ô chọn nhiều (danh sách chuỗi) KHÔNG bị coi là ảnh chưa tải ⇒ gửi thẳng', () async {
      final api = _Api();
      final repo = FormsRepositoryImpl(FormsApiService(api), db);
      await repo.submitForm(MarketFormSubmissionModel(
        configId: 1,
        visitId: 501,
        customerId: 20,
        answers: {'nhan_hang': ['Có/Không', 'opt_2']},
      ));
      expect(api.calls, isNotEmpty, reason: 'lỗi cũ: mọi phần tử không dài 32 ký tự ⇒ "ảnh chưa tải" ⇒ hàng đợi');
      expect(await db.getAllPendingQueueEntries(), isEmpty);
    });

    test('ô ảnh còn mang đường dẫn trên máy ⇒ vẫn đi hàng đợi', () async {
      final api = _Api();
      final repo = FormsRepositoryImpl(FormsApiService(api), db);
      await repo.submitForm(MarketFormSubmissionModel(
        configId: 1,
        visitId: 501,
        customerId: 20,
        answers: {'anh': ['/tmp/a.jpg']},
        localPhotoPaths: {'anh': ['/tmp/a.jpg']},
      ));
      expect(api.calls, isEmpty);
      expect((await db.getAllPendingQueueEntries()).single.entity, 'form_submission');
    });
  });

  group('điểm bán', () {
    CustomerEntity server(int id, String name) => CustomerEntity(
          id: id,
          code: 'KH$id',
          name: name,
          clientUuid: 'server_$id',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'A',
          phone: '0901234567',
          status: 'active',
          syncStatus: 'synced',
        );

    Future<String> localName(int id) async =>
        (await (db.select(db.localCustomers)..where((t) => t.id.equals(id))).getSingle()).name;

    test('C3 còn lệnh SỬA chờ gửi ⇒ lần tải danh sách KHÔNG đè phần sửa; gửi xong thì đè được', () async {
      final local = CustomerLocalDataSource(db);
      await local.cacheRemoteCustomers([server(55, 'Cũ')]);
      // Sửa ngoại tuyến: bản sửa vào máy + lệnh SỬA chờ gửi.
      await local.cacheRemoteCustomers([server(55, 'Mới')], localEdit: true);
      await local.enqueueCustomerUpdate(serverId: 55, clientUuid: 'server_55', changes: {'name': 'Mới'}, nowMs: 0);

      await local.cacheRemoteCustomers([server(55, 'Cũ')]);
      expect(await localName(55), 'Mới', reason: 'lỗi cũ: bản server cũ đè phần sửa ngoại tuyến');

      final upd = (await db.getAllPendingQueueEntries()).single;
      await db.markDone(upd.id);
      await local.cacheRemoteCustomers([server(55, 'Server')]);
      expect(await localName(55), 'Server');
    });

    test('C5 ảnh vật tư khai lúc tạo ngoại tuyến được chép ra thư mục lưu lâu dài', () async {
      final tmp = await Directory.systemTemp.createTemp('mat');
      final src = File('${tmp.path}/cam.jpg')..writeAsBytesSync([1, 2, 3]);
      final docs = await Directory.systemTemp.createTemp('docs');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => docs.path);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      final local = CustomerLocalDataSource(db);
      await local.createCustomerOffline({
        'name': 'A',
        'client_uuid': 'uuid-mat-0001',
        'materials': [
          {
            'material_type_id': 3,
            'photos': [src.path],
            'details': {'anh_bien': [src.path], 'ghi_chu': ['x']},
            'detail_photo_fields': ['anh_bien'],
          }
        ],
      });
      final op = (jsonDecode((await db.getAllPendingQueueEntries()).single.payload)['materials'] as List).single as Map;
      final photo = (op['photos'] as List).single as String;
      expect(photo, startsWith('${docs.path}/offline_customer_photos/'), reason: 'lỗi cũ: giữ đường dẫn thư mục tạm');
      expect(File(photo).existsSync(), isTrue);
      expect(((op['details'] as Map)['anh_bien'] as List).single, startsWith('${docs.path}/offline_customer_photos/'));
      expect((op['details'] as Map)['ghi_chu'], ['x'], reason: 'ô không phải ảnh giữ nguyên');
    });
  });
}

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';

/// Rà soát offline vòng 2 (#24698), nhóm 4 — lịch sử chấm công báo "Thiếu ảnh" cho lượt mà ảnh đang chờ gửi.
class _OfflineApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.error(const NetworkException());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lịch sử: lượt đã có trên server mà ảnh còn chờ gửi ⇒ hiện đủ ảnh, không "Thiếu ảnh"; bộ đệm không bị ghi ảnh tạm',
      () async {
    final key = 'dms_attendance_history_cache_v2_7';
    final serverPunch = {
      'id': 50,
      'punch_at': '2026-11-03 08:00:00',
      'client_uuid': 'srv',
      'lat': 21.0,
      'lng': 105.8,
      'photos': <dynamic>[],
      'requirements': {'photo_count': 0, 'min_photos': 2, 'need_front': true, 'need_back': true, 'satisfied': false},
    };
    SharedPreferences.setMockInitialValues({
      'vthm_user_data': jsonEncode({'id': 7}),
      key: jsonEncode([serverPunch]),
    });
    final db = AppDatabase(NativeDatabase.memory(), 7);
    addTearDown(db.close);
    for (final (uuid, type) in [('ph-f', 'front'), ('ph-b', 'back')]) {
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'attendance_photo',
        op: 'upload',
        clientUuid: uuid,
        parentUuid: const Value('srv'),
        localPath: Value('/tmp/$uuid.jpg'),
        payload: jsonEncode({'punch_id': 50, 'photo_type': type}),
        createdAt: type == 'front' ? 1 : 2,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));
    }

    final repo = AttendanceRepositoryImpl(AttendanceApiService(_OfflineApi()), database: db);
    final history = await repo.getHistory();

    final p = history.singleWhere((e) => e.clientUuid == 'srv');
    expect(p.photos.map((x) => x.photoType), unorderedEquals(['front', 'back']));
    expect(p.requirements.satisfied, isTrue, reason: 'lỗi cũ: ảnh chờ gửi chỉ ghép vào lượt CHƯA lên server');
    final cached = jsonDecode((await SharedPreferences.getInstance()).getString(key)!) as List;
    expect((cached.single as Map)['photos'], isEmpty);
  });

  test('một ảnh chờ gửi: cờ thiếu loại đó tắt, loại kia vẫn báo; ảnh cùng loại thay ảnh cũ (không đếm hai)', () async {
    final key = 'dms_attendance_history_cache_v2_7';
    SharedPreferences.setMockInitialValues({
      'vthm_user_data': jsonEncode({'id': 7}),
      key: jsonEncode([
        {
          'id': 60,
          'punch_at': '2026-11-03 08:00:00',
          'client_uuid': 'srv2',
          'photos': [
            {'id': 55, 'url': 'a', 'photo_type': 'front', 'photo_type_label': 'x'},
          ],
          'requirements': {'photo_count': 1, 'need_front': false, 'need_back': true, 'satisfied': false},
        },
      ]),
    });
    final db = AppDatabase(NativeDatabase.memory(), 7);
    addTearDown(db.close);
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'attendance_photo',
      op: 'upload',
      clientUuid: 'ph-f2',
      parentUuid: const Value('srv2'),
      localPath: const Value('/tmp/f2.jpg'),
      payload: jsonEncode({'punch_id': 60, 'photo_type': 'front'}),
      createdAt: 3,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    final p = (await AttendanceRepositoryImpl(AttendanceApiService(_OfflineApi()), database: db).getHistory())
        .singleWhere((e) => e.clientUuid == 'srv2');
    expect(p.photos.where((x) => x.photoType == 'front'), hasLength(1));
    expect((p.requirements.needFront, p.requirements.needBack, p.requirements.satisfied), (false, true, false));
  });
}

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/utils/account_key.dart';
import 'package:vthm_dms/features/position_declaration/data/repositories/position_declaration_repository_impl.dart';
import 'package:vthm_dms/features/position_declaration/data/services/position_declaration_api_service.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_declaration_entity.dart';

/// Rà soát offline 12/11/2026 — khai báo vị trí:
/// 1. Lịch sử khai báo trong máy TÁCH theo tài khoản (bản cũ một khoá chung, đăng xuất không xoá ⇒ người sau thấy toạ độ /
///    địa chỉ / ảnh của người trước).
/// 2. Gửi trực tuyến gặp 401 / 408 / 429 / `DMS_APP_FORBIDDEN` ⇒ xếp hàng gửi lại, KHÔNG đánh "lỗi" vĩnh viễn; 422 thì vẫn báo lỗi.

/// Máy chủ trả [error] cho mọi lệnh.
class _FailingApiClient implements ApiClient {
  final Object error;
  _FailingApiClient(this.error);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.error(error);
}

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async => true;
}

PositionDeclarationEntity _decl(String uuid) => PositionDeclarationEntity(
      clientUuid: uuid,
      reasonId: 1,
      lat: 21.0,
      lng: 105.8,
      address: '1 Lê Lợi',
      clientTime: '2026-11-12T09:00:00+07:00',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 7})});
    db = AppDatabase(NativeDatabase.memory(), 1);
    await db.setOwner(7);
  });
  tearDown(() async => db.close());

  PositionDeclarationRepositoryImpl repoWith(Object error) {
    final provider = Provider((ref) => PositionDeclarationRepositoryImpl(
          apiService: PositionDeclarationApiService(_FailingApiClient(error)),
          database: db,
          ref: ref,
        ));
    final container = ProviderContainer(overrides: [connectivityProvider.overrideWith((ref) => _Online())]);
    addTearDown(container.dispose);
    return container.read(provider);
  }

  group('lịch sử khai báo tách theo tài khoản', () {
    test('người đăng nhập sau KHÔNG thấy lịch sử của người trước', () async {
      final repo = repoWith(Exception('không dùng'));
      await repo.saveLocalDeclaration(_decl('d-a'));
      expect((await repo.getLocalDeclarations()).map((e) => e.clientUuid), ['d-a']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': 8}));
      expect(await repo.getLocalDeclarations(), isEmpty, reason: 'tài khoản 8 đọc được lịch sử của tài khoản 7');
    });

    test('chưa rõ tài khoản ⇒ không đọc / ghi ngăn dùng chung', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserData);
      final repo = repoWith(Exception('không dùng'));
      await repo.saveLocalDeclaration(_decl('d-x'));
      expect(prefs.getKeys().where((k) => k.startsWith(declarationsListPrefix)), isEmpty);
    });

    test('khoá dùng chung kiểu cũ bị xoá khi khởi động', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(declarationsListPrefix, '[]');
      await removeLegacySharedCaches(prefs);
      expect(prefs.containsKey(declarationsListPrefix), isFalse);
    });
  });

  group('gửi trực tuyến lỗi PHIÊN / TẠM ⇒ xếp hàng, không đánh lỗi vĩnh viễn', () {
    for (final (label, err) in [
      ('401 hết phiên', const UnauthorizedException()),
      ('403 DMS_APP_FORBIDDEN', const AppException('Bị thu quyền app', 403, 'DMS_APP_FORBIDDEN')),
      ('408', const ServerException('Hết giờ', 408)),
      ('429', const ServerException('Quá tải', 429)),
      ('500', const ServerException('Lỗi máy chủ', 500)),
    ]) {
      test(label, () async {
        final repo = repoWith(err);
        final out = await repo.submitDeclaration(_decl('q-$label'));

        expect(out.syncStatus, 'pending');
        final row = await db.getEntryByClientUuid('q-$label');
        expect(row, isNotNull, reason: 'không có dòng hàng đợi ⇒ khai báo không bao giờ được gửi lại');
        final local = (await repo.getLocalDeclarations()).single;
        expect(local.syncStatus, isNot('error'));
      });
    }

    test('422 (bị từ chối hẳn) ⇒ báo lỗi, KHÔNG xếp hàng', () async {
      final repo = repoWith(const ServerException('Lý do đã bị tắt', 422));
      await expectLater(repo.submitDeclaration(_decl('r-422')), throwsA(isA<AppException>()));
      expect(await db.getEntryByClientUuid('r-422'), isNull);
      expect((await repo.getLocalDeclarations()).single.syncStatus, 'error');
    });
  });
}

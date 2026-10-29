import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/map/goong_providers.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/core/utils/string_utils.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_card.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/widgets/route_dealer_timeline.dart';

/// Tuyến / danh sách điểm bán có thể 1–2.000 điểm bán (28/10/2026) — các phép đo dưới đây giữ cho màn không giật.

class _FakeRulesNotifier extends MobileRulesNotifier {
  _FakeRulesNotifier(super.apiClient);
  @override
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async => state;
}

/// Bản bỏ dấu CŨ (trước 28/10/2026) — làm chuẩn đối chiếu: bản một lượt quét phải cho kết quả y hệt.
String _oldUnaccent(String? input) {
  const map = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'A': 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'éèẻẽẹêếềểễệ',
    'E': 'ÉÈẺẼẸÊẾỀỂỄỆ',
    'i': 'íìỉĩị',
    'I': 'ÍÌỈĨỊ',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'O': 'ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ',
    'u': 'úùủũụưứừửữự',
    'U': 'ÚÙỦŨỤƯỨỪỬỮỰ',
    'y': 'ýỳỷỹỵ',
    'Y': 'ÝỲỶỸỴ',
  };
  if (input == null || input.trim().isEmpty) return '';
  var result = input;
  map.forEach((replacement, chars) {
    for (var i = 0; i < chars.length; i++) {
      result = result.replaceAll(chars[i], replacement);
    }
  });
  result = result.replaceAll(RegExp(r'[̣̀́̃̉ˆ̛̆]'), '');
  return result.toLowerCase().trim();
}

CustomerEntity _customer(int i) => CustomerEntity(
      id: i + 1,
      code: 'DMS${i + 1}',
      name: 'Cửa hàng Tạp hoá Nguyễn Văn ${i + 1}',
      type: 'Tạp hóa',
      route: 'Tuyến ${i % 7}',
      address: 'Số ${i + 1} đường Hoàng Quốc Việt, Cầu Giấy, Hà Nội',
      phone: '0988${i.toString().padLeft(6, '0')}',
      contactPerson: 'Chị Hằng',
      status: 'active',
      lat: 21.0 + i / 10000,
      lng: 105.8 + i / 10000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bỏ dấu một lượt quét cho kết quả Y HỆT bản cũ (mọi ký tự có dấu, chữ hoa)', () {
    final samples = [
      'Nguyễn Thị Bình',
      'ĐẶNG VĂN LÂM',
      'áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ',
      'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬĐÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴ',
      '  Số 12 — Hà Nội 😀  ',
      'abc XYZ 0988',
      '',
      '   ',
    ];
    for (final s in samples) {
      expect(StringUtils.toUnaccentedLower(s), _oldUnaccent(s), reason: s);
    }
    expect(StringUtils.toUnaccentedLower(null), '');
  });

  test('bỏ dấu chuỗi dạng tổ hợp NFD (dán từ iOS/macOS) — kể cả dấu mũ U+0302 bản cũ bỏ sót', () {
    expect(StringUtils.toUnaccentedLower('Nguye\u0302\u0303n Va\u0306n Linh'), 'nguyen van linh');
    expect(StringUtils.toUnaccentedLower('Pho\u031B\u0300 Ho\u0302\u0300'), 'pho ho');
  });

  test('ghi cache 2.000 điểm bán (nhiều lô) đủ dòng, ghi lại lần hai không nhân đôi, reconcile bỏ điểm đã mất', () async {
    final db = AppDatabase(NativeDatabase.memory(), 1);
    final local = CustomerLocalDataSource(db);
    final list = List.generate(2000, _customer);

    await local.cacheRemoteCustomers(list, reconcile: true);
    await local.cacheRemoteCustomers(list, reconcile: true);
    expect((await local.getLocalCustomers()).length, 2000);

    await local.cacheRemoteCustomers(list.sublist(0, 1500), reconcile: true);
    expect((await local.getLocalCustomers()).length, 1500);
    await db.close();
  });

  test('tra điểm bán theo id và mã khi ghi cache DÙNG index (không quét cả bảng mỗi dòng)', () async {
    final db = AppDatabase(NativeDatabase.memory(), 1);
    Future<String> plan(String where) async {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN SELECT * FROM local_customers WHERE $where').get();
      return rows.map((r) => r.data['detail'].toString()).join(' | ');
    }

    expect(await plan('id = 5'), contains('idx_local_customers_id'));
    expect(await plan("code = 'DMS5'"), contains('idx_local_customers_code'));
    await db.close();
  });

  test('máy đang ở schema 2 nâng lên 3 thì có index (giữ nguyên dữ liệu)', () async {
    final dir = Directory.systemTemp.createTempSync('dms_schema_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/dms.sqlite');
    var db = AppDatabase(NativeDatabase(file), 1);
    addTearDown(() => db.close());
    await CustomerLocalDataSource(db).cacheRemoteCustomers([_customer(0)]);
    // Đưa DB về đúng dạng bản app cũ: chưa có index, user_version = 2.
    await db.customStatement('DROP INDEX idx_local_customers_id');
    await db.customStatement('DROP INDEX idx_local_customers_code');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    db = AppDatabase(NativeDatabase(file), 1);
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'local_customers'")
        .get();
    expect(rows.map((r) => r.read<String>('name')), containsAll(['idx_local_customers_id', 'idx_local_customers_code']));
    expect((await CustomerLocalDataSource(db).getLocalCustomers()).length, 1);
  });

  testWidgets('danh sách tuyến 2.000 điểm bán chỉ dựng thẻ trong khung nhìn (cuộn lười)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = ApiClient(Dio());
    final controller = ScrollController();
    final dealers = List.generate(2000, (i) {
      final c = _customer(i);
      return DealerEntity(
        id: c.id.toString(),
        order: '${i + 1}',
        name: c.name,
        code: c.code,
        address: c.address,
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: c.lat,
        lng: c.lng,
        customer: c,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          mobileRulesProvider.overrideWith((ref) => _FakeRulesNotifier(apiClient)),
          currentPointProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: MaterialApp(home: Scaffold(body: RouteDealerTimeline(dealers: dealers, controller: controller))),
      ),
    );
    await tester.pump();

    final built = find.byType(CustomerCard, skipOffstage: false).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(50));

    // Cuộn tới cuối vẫn tới được điểm bán cuối cùng.
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final names = tester.widgetList<CustomerCard>(find.byType(CustomerCard, skipOffstage: false)).map((c) => c.name);
    expect(names, contains('Cửa hàng Tạp hoá Nguyễn Văn 2000'));
    expect(find.byType(CustomerCard, skipOffstage: false).evaluate().length, lessThan(50));
  });
}

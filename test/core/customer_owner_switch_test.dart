import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';

/// Rà soát offline vòng 2 (#24698), nhóm 3: đổi tài khoản trên cùng máy (đăng xuất cưỡng bức giữ dữ liệu) — người đăng
/// nhập sau KHÔNG thấy điểm bán trong máy của người trước; điểm bán chờ gửi của người trước còn nguyên chờ họ quay lại.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
  tearDown(() => db.close());

  Future<void> add(String uuid, {String sync = 'pending', int? id}) => db.insertOrUpdateCustomer(
        LocalCustomersCompanion.insert(
          clientUuid: uuid,
          id: Value(id),
          name: 'Điểm bán $uuid',
          nameUnaccent: 'diem ban $uuid',
          address: 'HN',
          contactPerson: 'A',
          phone: '0900000000',
          syncStatus: Value(sync),
        ),
      );

  Future<List<String>> visible() async => (await db.getAllLocalCustomers()).map((c) => c.clientUuid).toList();

  test('người B đăng nhập: không thấy điểm bán của A (liệt kê, tìm, đếm); A quay lại thấy lại điểm bán chờ gửi', () async {
    await add('a-pending');
    await add('a-synced', sync: 'synced', id: 11);
    expect(await visible(), unorderedEquals(['a-pending', 'a-synced']));

    await db.setOwner(2);
    expect(await visible(), isEmpty, reason: 'lỗi cũ: bảng không theo chủ ⇒ B thấy điểm bán của A');
    expect(await db.searchLocalCustomers('diem'), isEmpty);
    expect(await db.countLocalCustomers(), 0);
    expect(await db.syncedCustomerIds(), isEmpty);

    await add('b-synced', sync: 'synced', id: 22);
    expect(await visible(), ['b-synced']);

    await db.setOwner(1);
    expect(await visible(), ['a-pending'],
        reason: 'một chủ một lúc: điểm bán chờ gửi của A còn nguyên; bộ đệm đã đồng bộ của người khác bị bỏ (tải lại)');
  });

  test('B đăng xuất chủ động chỉ xoá điểm bán của B, không đụng điểm bán chờ gửi của A', () async {
    await add('a-pending');
    await db.setOwner(2);
    await add('b-pending');

    expect(await db.clearUserData(), isTrue);
    await db.setOwner(1);
    expect(await visible(), ['a-pending']);
  });

  test('B tải danh sách máy chủ có điểm bán trùng client_uuid với dòng chờ gửi của A ⇒ KHÔNG ghi đè dòng của A', () async {
    await add('shared-uuid');
    await db.setOwner(2);
    await CustomerLocalDataSource(db).cacheRemoteCustomers([
      CustomerEntity(
          id: 77, clientUuid: 'shared-uuid', code: 'KH77', name: 'X', type: '', route: '', address: 'HN',
          contactPerson: 'B', phone: '1'),
    ]);
    expect(await visible(), isEmpty, reason: 'không ghi đè dòng chờ gửi của A');

    await db.setOwner(1);
    final a = await db.getAllLocalCustomers();
    expect(a.map((c) => (c.clientUuid, c.syncStatus)), [('shared-uuid', 'pending')],
        reason: 'lỗi: B chiếm dòng của A (đổi thành synced, chủ B) rồi A đăng nhập lại thì bị xoá');
  });

  test('A sửa ngoại tuyến điểm bán chung tuyến (server_77, chờ gửi); B tải danh sách cùng điểm ⇒ không ghi đè', () async {
    await add('server_77', sync: 'pending', id: 77);
    await db.setOwner(2);
    await CustomerLocalDataSource(db).cacheRemoteCustomers([
      CustomerEntity(
          id: 77, code: 'KH77', name: 'X', type: '', route: '', address: 'HN', contactPerson: 'B', phone: '1'),
    ]);
    expect(await visible(), isEmpty);
    await db.setOwner(1);
    expect((await db.getAllLocalCustomers()).map((c) => (c.clientUuid, c.syncStatus)), [('server_77', 'pending')]);
  });

  test('ghi khi chưa rõ chủ: giữ chủ cũ của dòng đã đồng bộ, không đụng dòng chờ gửi; bộ đệm vô chủ giao người kế tiếp',
      () async {
    final noOwner = AppDatabase(NativeDatabase.memory());
    addTearDown(noOwner.close);
    LocalCustomersCompanion row(String uuid, String name, {String sync = 'synced', int? owner}) =>
        LocalCustomersCompanion.insert(
          clientUuid: uuid,
          name: name,
          nameUnaccent: name,
          address: 'HN',
          contactPerson: 'A',
          phone: '1',
          syncStatus: Value(sync),
          ownerUserId: owner == null ? const Value.absent() : Value(owner),
        );
    await noOwner.insertOrUpdateCustomer(row('s', 'cu', owner: 5));
    await noOwner.insertOrUpdateCustomer(row('p', 'cu', sync: 'pending', owner: 5));
    await noOwner.insertOrUpdateCustomer(row('s', 'moi').copyWith(ownerUserId: const Value(null)));
    await noOwner.insertOrUpdateCustomer(row('p', 'moi', sync: 'pending'));
    await noOwner.insertOrUpdateCustomer(row('n', 'vo chu'));
    final all = {for (final c in await noOwner.select(noOwner.localCustomers).get()) c.clientUuid: c};
    expect((all['s']!.name, all['s']!.ownerUserId), ('moi', 5));
    expect((all['p']!.name, all['p']!.ownerUserId), ('cu', 5));
    expect(all['n']!.ownerUserId, isNull);
    await noOwner.setOwner(4);
    expect((await noOwner.getAllLocalCustomers()).map((c) => c.clientUuid), ['n']);
  });

  test('dòng của bản app cũ (chưa có chủ) giao cho người đăng nhập kế tiếp', () async {
    await add('legacy');
    await (db.update(db.localCustomers)..where((t) => t.clientUuid.equals('legacy')))
        .write(const LocalCustomersCompanion(ownerUserId: Value(-1)));
    await db.setOwner(3);
    expect(await visible(), ['legacy']);
  });
}

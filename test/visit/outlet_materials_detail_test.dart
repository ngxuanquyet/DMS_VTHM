import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';
import 'package:vthm_dms/features/visit/data/services/visit_material_api_service.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/features/visit/data/models/outlet_material_view_model.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/presentation/widgets/material_card.dart';

class _Online extends ConnectivityNotifier {
  _Online(bool online) : super() {
    state = ConnectivityState(isOnline: online);
  }

  void set(bool online) => state = state.copyWith(isOnline: online);
}

/// API giả: [view] / [history] ném lỗi khi là [AppException], còn lại trả thân JSON.
class _FakeApi extends Fake implements VisitMaterialApiService {
  Object view = <String, dynamic>{'items': [], 'conditions': {}};
  Object history = <String, dynamic>{'data': [], 'meta': {'currentPage': 1, 'pageCount': 1}};
  final List<Map<String, dynamic>> historyCalls = [];

  @override
  Future<(Map<String, dynamic>, OutletMaterialsSnapshot)> getOutletMaterials(int customerId) async {
    final v = view;
    if (v is AppException) throw v;
    final m = v as Map<String, dynamic>;
    return (m, OutletMaterialsSnapshot.fromJson(m));
  }

  @override
  Future<(Map<String, dynamic>, OutletMaterialHistoryPage)> getOutletMaterialHistory(
    int customerId, {
    required int materialTypeId,
    int page = 1,
  }) async {
    historyCalls.add({'type': materialTypeId, 'page': page});
    final v = history;
    if (v is AppException) throw v;
    final m = v as Map<String, dynamic>;
    return (m, OutletMaterialHistoryPage.fromJson(m));
  }
}

/// Mục Vật tư ở màn chi tiết điểm bán (#24707) — đọc phản hồi `GET /dms/customers/{id}/materials` + `material-history`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hiện trạng: loại gọn, tình trạng dạng map, nhãn ô, người kiểm, dòng ẩn', () {
    final s = OutletMaterialsSnapshot.fromJson({
      'items': [
        {
          'id': 5,
          'material_type': {'id': 3, 'code': 'KE', 'name': 'Kệ trưng bày', 'unit': 'cái', 'deleted': false},
          'condition_counts': {'good': 4, 'minor': 1},
          'quantity': 5,
          'details': {'vi_tri': 'Mặt tiền'},
          'detail_labels': {'vi_tri': 'Vị trí'},
          'as_of': '2026-10-30 12:10:03+07',
          'last_visit_id': 99,
          'last_user': {'id': 7, 'name': 'Nguyễn Văn A'},
          'hidden': false,
        },
        {
          'id': 6,
          'material_type': {'id': 4, 'code': null, 'name': null, 'unit': null, 'deleted': true},
          'condition_counts': [],
          'quantity': 0,
          'details': null,
          'detail_labels': [],
          'as_of': null,
          'last_visit_id': null,
          'last_user': null,
          'hidden': true,
        },
      ],
      'conditions': {
        'good': {'name': 'Tốt', 'color': 'success', 'is_present': true},
        'lost': {'name': 'Mất', 'color': 'dark', 'is_present': false},
      },
    });
    expect(s.items, hasLength(2));
    final a = s.items.first;
    expect(a.type.id, 3);
    expect(a.type.name, 'Kệ trưng bày');
    expect(a.conditionCounts, {'good': 4, 'minor': 1});
    expect(a.detailLabels['vi_tri'], 'Vị trí');
    expect(a.lastUserName, 'Nguyễn Văn A');
    final b = s.items.last;
    expect(b.type.name, '#4');
    expect(b.type.isActive, isFalse);
    expect(b.conditionCounts, isEmpty);
    expect(b.hidden, isTrue);
    expect(s.conditions.map((c) => c.code), ['good', 'lost']);
    expect(s.conditions.last.isPresent, isFalse);

    // Không có schema: nhãn ô lấy theo detail_labels của server thay vì mã ô.
    const strings = AppStrings(AppLanguage.vi);
    final rows = materialDetailRows(a.type, a.details, strings, labels: a.detailLabels);
    expect(rows.single.key, 'Vị trí');
  });

  test('lịch sử: thay đổi cũ → mới, ảnh, phân trang', () {
    final page = OutletMaterialHistoryPage.fromJson({
      'data': [
        {
          'id': 11,
          'material_type': {'id': 3, 'name': 'Kệ', 'unit': 'cái'},
          'action': 'update',
          'action_label': 'Cập nhật',
          'action_color': 'primary',
          'condition_counts': {'good': 0, 'minor': 2},
          'quantity': 2,
          'details': {'so': 6},
          'detail_labels': {'so': 'Số mặt hàng'},
          'changes': {
            'counts': {'good': [1, 0], 'minor': [1, 2]},
            'details': {'so': [5, 6]},
          },
          'reason': '  ',
          'photos': [
            {'token': 'abc', 'url': '/dms/form-photos/public/abc'},
          ],
          'visit_id': 99,
          'user': {'id': 7, 'name': 'B'},
          'recorded_at': '2026-11-01 08:00:00+07',
        },
        {
          'id': 10,
          'material_type': {'id': 3, 'name': 'Kệ'},
          'action': 'confirm',
          'changes': null,
          'photos': [],
          'visit_id': null,
          'user': null,
        },
      ],
      'meta': {'total': 25, 'currentPage': 1, 'pageSize': 20, 'pageCount': 2},
    });
    expect(page.hasMore, isTrue);
    final e = page.items.first;
    expect(e.countChanges, {'good': (1, 0), 'minor': (1, 2)});
    expect(e.detailChanges['so'], (5, 6));
    expect(e.reason, isNull);
    expect(e.photos.single.url, '/dms/form-photos/public/abc');
    expect(e.userName, 'B');
    final c = page.items.last;
    expect(c.countChanges, isEmpty);
    expect(c.actionLabel, 'confirm');
    expect(c.visitId, isNull);
  });

  test('nhãn chờ đồng bộ: chỉ thao tác trong cache còn nằm hàng đợi pending/sending', () {
    final entry = {
      'visit_client_uuid': 'v1',
      'data': null,
      'ops': [
        {'visit': 'v1', 'op': {'client_uuid': 'a', 'material_type_id': 3}, 'ok': false},
        {'visit': 'v1', 'op': {'client_uuid': 'b', 'material_type_id': 4}, 'ok': true},
        {'visit': 'v0', 'op': {'client_uuid': 'c', 'material_type_id': 5}, 'ok': false},
        'rác',
      ],
    };
    expect(pendingMaterialTypeIds(entry, {'a', 'c'}), {3, 5});
    expect(pendingMaterialTypeIds(entry, const {}), isEmpty);
    expect(pendingMaterialTypeIds(null, {'a'}), isEmpty);
  });

  test('giờ ngắn dùng chung', () {
    expect(shortMaterialDateTime('2026-10-30 12:10:03+07'), '30/10 12:10');
    expect(shortMaterialDateTime('2026-10-30'), '30/10');
  });

  test('lịch sử: ô ảnh bỏ, lựa chọn ra nhãn theo schema danh mục; tên/đơn vị giữ theo server', () {
    final catalog = OutletMaterialType.fromJson({
      'id': 3,
      'name': 'Tên cũ',
      'unit': 'chiếc',
      'schema': {
        'blocks': [
          {
            'type': 'field',
            'ref': 'vi_tri',
            'required': false,
            'resolved': {
              'code': 'vi_tri',
              'label': 'Vị trí',
              'input_type': 'select',
              'options': [
                {'value': 'cua', 'label': 'Cửa hàng'},
              ],
            },
          },
          {'type': 'field', 'ref': 'anh', 'required': false, 'resolved': {'code': 'anh', 'label': 'Ảnh', 'input_type': 'image'}},
        ],
      },
    });
    const server = OutletMaterialType(id: 3, name: 'Kệ trưng bày', unit: 'cái');
    final t = withCatalogSchema(server, catalog);
    expect(t.name, 'Kệ trưng bày');
    expect(t.unit, 'cái');
    expect(t.schema, isNotNull);
    expect(withCatalogSchema(server, null), same(server));

    const s = AppStrings(AppLanguage.vi);
    expect(materialDetailValue(t, 'vi_tri', 'cua', s), 'Cửa hàng');
    expect(materialDetailValue(t, 'anh', ['0123456789abcdef0123456789abcdef'], s), isNull);
    expect(materialDetailValue(t, 'vi_tri', null, s), '');
    // Không schema: danh sách ảnh không thành chữ; chuỗi đơn dài 32 ký tự GIỮ (không phân biệt được với chữ).
    expect(materialDetailValue(server, 'x', ['0123456789abcdef0123456789abcdef'], s), isNull);
    expect(materialDetailValue(server, 'x', 'Biển hiệu đặt trước cửa hàng ABC', s), 'Biển hiệu đặt trước cửa hàng ABC');
    expect(materialDetailValue(server, 'so', 5.0, s), '5');
    // Thẻ: nhãn server thắng nhãn schema (schema có thể cũ); ô ảnh / ô nội bộ không thành dòng.
    final rows = materialDetailRows(t, {'vi_tri': 'cua', 'anh': 'x', '_meta': 1}, s, labels: {'vi_tri': 'Vị trí (mới)'});
    expect(rows.map((r) => '${r.key}=${r.value}'), ['Vị trí (mới)=Cửa hàng']);
  });

  group('repository: bản lưu ngoại tuyến + luật bỏ bản lưu', () {
    late _FakeApi api;
    late _Online net;
    late ProviderContainer c;
    late VisitMaterialRepository repo;
    const item = {
      'material_type': {'id': 3, 'name': 'Kệ'},
      'condition_counts': {'good': 1},
      'quantity': 1,
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = _FakeApi();
      net = _Online(true);
      c = ProviderContainer(overrides: [
        visitMaterialApiServiceProvider.overrideWithValue(api),
        connectivityProvider.overrideWith((ref) => net),
        appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory(), 1)),
      ]);
      repo = c.read(visitMaterialRepositoryProvider);
    });
    tearDown(() => c.dispose());

    Future<void> seed() async {
      api.view = {
        'items': [item],
        'conditions': {},
      };
      api.history = {
        'data': [
          {'id': 1, 'material_type': {'id': 3}, 'action': 'update'},
        ],
        'meta': {'currentPage': 1, 'pageCount': 2},
      };
      expect((await repo.loadOutletView(9)).snapshot!.items, hasLength(1));
      expect((await repo.loadOutletHistory(9, 3)).page!.items, hasLength(1));
    }

    test('mất mạng ⇒ bản lưu (hiện trạng + trang 1 lịch sử); trang sau báo cần mạng', () async {
      await seed();
      net.set(false);
      final v = await repo.loadOutletView(9);
      expect(v.fromCache, isTrue);
      expect(v.snapshot!.items.single.type.id, 3);
      final h = await repo.loadOutletHistory(9, 3);
      expect(h.fromCache, isTrue);
      expect(h.page!.hasMore, isFalse, reason: 'bản lưu chỉ có trang 1');
      expect((await repo.loadOutletHistory(9, 3, page: 2)).offline, isTrue);
    });

    test('lịch sử gọi đúng loại + trang', () async {
      await seed();
      expect(api.historyCalls.last, {'type': 3, 'page': 1});
    });

    test('403 lịch sử chỉ bỏ bản lưu LỊCH SỬ — hiện trạng vẫn xem được khi mất mạng', () async {
      await seed();
      api.history = const AppException('Không có quyền', 403);
      expect((await repo.loadOutletHistory(9, 3)).forbidden, isTrue);
      net.set(false);
      expect((await repo.loadOutletView(9)).snapshot, isNotNull);
      expect((await repo.loadOutletHistory(9, 3)).page, isNull);
    });

    test('403 hiện trạng ⇒ ẩn, nhớ cả khi mất mạng; lịch sử đã lưu giữ nguyên; GET thành công thì quên cờ', () async {
      await seed();
      api.view = const AppException('Không có quyền', 403);
      expect((await repo.loadOutletView(9)).forbidden, isTrue);
      net.set(false);
      expect((await repo.loadOutletView(9)).forbidden, isTrue);
      expect((await repo.loadOutletHistory(9, 3)).page, isNotNull);
      net.set(true);
      api.view = {'items': [], 'conditions': {}};
      expect((await repo.loadOutletView(9)).forbidden, isFalse);
    });

    test('404 (ngoài phạm vi / đã xoá) ⇒ báo lỗi, bỏ CẢ HAI bản lưu', () async {
      await seed();
      api.view = const AppException('Không tìm thấy điểm bán', 404);
      final v = await repo.loadOutletView(9);
      expect(v.snapshot, isNull);
      expect(v.error, 'Không tìm thấy điểm bán');
      net.set(false);
      expect((await repo.loadOutletView(9)).snapshot, isNull);
      expect((await repo.loadOutletHistory(9, 3)).page, isNull);
    });

    test('4xx tạm (429) / 5xx ⇒ GIỮ bản lưu; 429 kèm câu lỗi, 5xx im lặng', () async {
      await seed();
      api.view = const AppException('Quá nhiều yêu cầu', 429);
      final a = await repo.loadOutletView(9);
      expect(a.fromCache, isTrue);
      expect(a.error, 'Quá nhiều yêu cầu');
      api.view = const AppException('Lỗi máy chủ', 502);
      final b = await repo.loadOutletView(9);
      expect(b.fromCache, isTrue);
      expect(b.error, isNull);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/visit/data/models/material_create_rules.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';

/// GĐ1b (#24526) — vật tư khai lúc TẠO điểm bán: khớp luật tại máy + payload POST /crm/customers.
void main() {
  Map<String, dynamic> catalogJson({List<Map<String, dynamic>> rules = const []}) => {
        'catalog': {
          'types': [
            {'id': 1, 'name': 'Kệ', 'unit': 'cái', 'is_active': true},
            {'id': 2, 'name': 'Biển hiệu', 'unit': 'cái', 'is_active': true, 'require_photo': true},
            {'id': 3, 'name': 'Standee', 'unit': 'cái', 'is_active': true},
            {'id': 4, 'name': 'Loại tắt', 'unit': '', 'is_active': false},
          ],
          'conditions': [
            {'code': 'good', 'name': 'Tốt', 'color': 'success', 'is_present': true},
          ],
        },
        'create_rules': rules,
      };

  Map<String, dynamic> rule(
    int id, {
    List<int>? types,
    List<int>? customerTypes,
    List<int>? regions,
    List<int>? channels,
    List<String>? territories,
  }) =>
      {
        'id': id,
        'material_type_ids': types,
        'customer_type_ids': customerTypes,
        'region_ids': regions,
        'sales_channel_ids': channels,
        'territory_codes': territories,
      };

  MaterialCreateRule r(Map<String, dynamic> json) => MaterialCreateRule.fromJson(json);

  group('Khớp trục điểm bán tại máy', () {
    test('luật không giới hạn trục nào ⇒ luôn áp', () {
      expect(ruleAppliesToNewOutlet(r(rule(1, types: [1]))), isTrue);
    });

    test('loại điểm bán / khu vực: trục khác null phải CHỨA giá trị; điểm bán chưa chọn ⇒ không áp', () {
      final x = r(rule(1, types: [1], customerTypes: [10, 11], regions: [5]));
      expect(ruleAppliesToNewOutlet(x, customerTypeId: 10, regionId: 5), isTrue);
      expect(ruleAppliesToNewOutlet(x, customerTypeId: 12, regionId: 5), isFalse);
      expect(ruleAppliesToNewOutlet(x, customerTypeId: 10, regionId: 6), isFalse);
      expect(ruleAppliesToNewOutlet(x, regionId: 5), isFalse, reason: 'chưa chọn loại ⇒ không biết thì không đòi');
    });

    test('[] ở cột trục = không giới hạn (như null)', () {
      expect(ruleAppliesToNewOutlet(r(rule(1, customerTypes: [], regions: [])), customerTypeId: 99), isTrue);
    });

    test('không biết cặp server sẽ lấp (meta cũ) ⇒ luật giới hạn kênh/tuyến coi như TRÚNG (đòi thừa, không đòi thiếu)', () {
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7])), pairsUnknown: true), isTrue);
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7], customerTypes: [10])), customerTypeId: 11, pairsUnknown: true), isFalse,
          reason: 'trục loại/khu vực vẫn khớp bình thường');
    });

    test('kênh × tuyến: điểm bán mới chưa có cặp ⇒ CHỈ luật mà cả hai cột null áp', () {
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7]))), isFalse);
      expect(ruleAppliesToNewOutlet(r(rule(1, territories: ['MB1']))), isFalse);
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7], territories: ['MB1']))), isFalse);
      expect(ruleAppliesToNewOutlet(r(rule(1))), isTrue);
    });

    test('kênh × tuyến khớp theo CẶP, không theo hai tập rời', () {
      final pairs = [
        const OutletChannelTerritoryPair(7, 'MN2'),
        const OutletChannelTerritoryPair(8, 'MB1'),
      ];
      // KPP(7)·MN2 + KBL(8)·MB1 KHÔNG trúng "kênh 7, tuyến MB1".
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7], territories: ['MB1'])), pairs: pairs), isFalse);
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [8], territories: ['MB1'])), pairs: pairs), isTrue);
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7])), pairs: pairs), isTrue, reason: 'tuyến null');
      expect(ruleAppliesToNewOutlet(r(rule(1, territories: ['MN2'])), pairs: pairs), isTrue, reason: 'kênh null');
    });

    test('vế cặp null chỉ lọt qua cột null', () {
      final onlyChannel = [const OutletChannelTerritoryPair(7, null)];
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7])), pairs: onlyChannel), isTrue);
      expect(ruleAppliesToNewOutlet(r(rule(1, channels: [7], territories: ['MB1'])), pairs: onlyChannel), isFalse);
    });

  });

  group('Lấp kênh/tuyến trống y như server trước khi khớp (§4.1)', () {
    String show(List<OutletChannelTerritoryPair> ps) => ps.map((p) => '${p.channelId}·${p.territoryCode}').join(',');

    test('chọn đủ kênh + tuyến ⇒ dùng đúng giá trị gửi (bỏ trùng kênh)', () {
      expect(
        show(serverFilledPairs(sentChannelIds: [7, '8', 7], sentTerritoryCode: 'MB1', defaultChannelIds: [1], defaultTerritoryCode: 'MN2')),
        '7·MB1,8·MB1',
      );
      expect(show(serverFilledPairs(sentChannelIds: 7, sentTerritoryCode: 'MB1')), '7·MB1', reason: 'ô Kênh chọn một');
    });

    test('kênh rỗng (ô ẩn / khoá trống / không gửi) ⇒ kênh mặc định của phòng', () {
      expect(
        show(serverFilledPairs(sentChannelIds: null, sentTerritoryCode: 'MB1', defaultChannelIds: [1, 2], defaultTerritoryCode: 'MN2')),
        '1·MB1,2·MB1',
        reason: 'chỉ gửi tuyến ⇒ kênh của phòng (app lấy mọi kênh mặc định — tập ⊇ server, chỉ đòi thừa)',
      );
      expect(
        show(serverFilledPairs(sentChannelIds: [], sentTerritoryCode: '', defaultChannelIds: [1], defaultTerritoryCode: 'MN2')),
        '1·MN2',
      );
    });

    test('tuyến rỗng ⇒ tuyến mặc định của phòng', () {
      expect(
        show(serverFilledPairs(sentChannelIds: [7], sentTerritoryCode: '  ', defaultChannelIds: [1], defaultTerritoryCode: 'MN2')),
        '7·MN2',
      );
    });

    test('giữ giá trị điền sẵn (app không gửi kênh/tuyến) ⇒ đúng bộ mặc định server tự gán', () {
      expect(
        show(serverFilledPairs(defaultChannelIds: [1, 2], defaultTerritoryCode: 'MN2')),
        '1·MN2,2·MN2',
      );
    });

    test('"Toàn kênh" (_ALL) ở ô hoặc ở mặc định ⇒ không tuyến', () {
      expect(show(serverFilledPairs(sentChannelIds: [7], sentTerritoryCode: '_ALL', defaultTerritoryCode: 'MN2')), '7·null');
      expect(show(serverFilledPairs(defaultChannelIds: [1], defaultTerritoryCode: '_ALL')), '1·null');
    });

    test('không có gì cả (phòng không có mặc định) ⇒ không cặp ⇒ chỉ luật kênh/tuyến null áp', () {
      expect(serverFilledPairs(), isEmpty);
      expect(show(serverFilledPairs(sentTerritoryCode: 'MB1')), 'null·MB1');
    });

    test('luật kênh × tuyến TRÚNG nhờ lấp mặc định (bản cũ chỉ dùng ô trống ⇒ đòi thiếu)', () {
      final x = r(rule(1, channels: [1], territories: ['MN2']));
      expect(ruleAppliesToNewOutlet(x), isFalse);
      expect(
        ruleAppliesToNewOutlet(x, pairs: serverFilledPairs(defaultChannelIds: [1], defaultTerritoryCode: 'MN2')),
        isTrue,
      );
    });
  });

  group('Loại bắt buộc = hợp các luật áp', () {
    test('hợp material_type_ids của các luật áp; luật không áp bị bỏ; loại tắt bị bỏ', () {
      final c = MaterialCreateCatalog.fromJson(catalogJson(rules: [
        rule(1, types: [1]),
        rule(2, types: [2, 4], regions: [5]),
        rule(3, types: [3], customerTypes: [99]),
      ]));
      expect(c.requiredTypesFor(regionId: 5).map((t) => t.id), [1, 2]);
      expect(c.requiredTypesFor(regionId: 6).map((t) => t.id), [1], reason: 'đổi khu vực ⇒ tính lại');
      expect(c.requiredTypesFor(regionId: 5, customerTypeId: 99).map((t) => t.id), [1, 2, 3]);
    });

    test('material_type_ids null = mọi loại ĐANG BẬT', () {
      final c = MaterialCreateCatalog.fromJson(catalogJson(rules: [rule(1)]));
      expect(c.requiredTypesFor().map((t) => t.id), [1, 2, 3]);
    });

    test('không có luật ⇒ không bắt buộc gì', () {
      expect(MaterialCreateCatalog.fromJson(catalogJson()).requiredTypesFor(), isEmpty);
    });

    test('khai SL 0 vẫn tính là đã khai; thiếu thì nêu đúng loại', () {
      final c = MaterialCreateCatalog.fromJson(catalogJson(rules: [rule(1, types: [1, 2])]));
      final req = c.requiredTypesFor();
      final ops = [
        const MaterialOperation(clientUuid: 'a', materialTypeId: 1, action: MaterialAction.add, conditionCounts: {}),
      ];
      expect(missingCreateMaterials(req, ops).map((t) => t.name), ['Biển hiệu']);
      expect(
        missingCreateMaterials(req, [
          ...ops,
          const MaterialOperation(clientUuid: 'b', materialTypeId: 2, action: MaterialAction.add, conditionCounts: {}),
        ]),
        isEmpty,
      );
    });
  });

  group('Payload POST /crm/customers có materials', () {
    const ops = [
      MaterialOperation(
        clientUuid: '0b9a0f6e-7d6e-4c55-9b0a-6a1e2c3d4e5f',
        materialTypeId: 2,
        action: MaterialAction.add,
        conditionCounts: {'good': 1},
        details: {'kich_thuoc': '2m'},
        photos: ['ffffffffffffffffffffffffffffffff'],
        detailPhotoFields: ['anh'],
        clickedAtServerMs: 123,
      ),
      MaterialOperation(clientUuid: '1c9a0f6e-7d6e-4c55-9b0a-6a1e2c3d4e5f', materialTypeId: 1, action: MaterialAction.add, conditionCounts: {}),
    ];

    test('materials ở GỐC thân, khuôn §2 (client_uuid, add, {} là object), không lọt vào data, bỏ khoá nội bộ', () {
      final payload = CustomerPayloadHelper.buildCustomerApiPayload(
        sourceData: {
          'name': 'Tạp hoá A',
          'region_id': 5,
          'route_ids': [3],
          'customer_type_id': 10,
          'materials': ops.map((o) => o.toJson()).toList(),
        },
        clientUuid: 'cust-uuid',
      );
      final materials = payload['materials'] as List;
      expect(materials, hasLength(2));
      expect(materials.first, {
        'client_uuid': '0b9a0f6e-7d6e-4c55-9b0a-6a1e2c3d4e5f',
        'material_type_id': 2,
        'action': 'add',
        'condition_counts': {'good': 1},
        'details': {'kich_thuoc': '2m'},
        'photos': ['ffffffffffffffffffffffffffffffff'],
      });
      expect(jsonEncode((materials.last as Map)['condition_counts']), '{}');
      expect((payload['data'] as Map?)?.containsKey('materials') ?? false, isFalse);
      expect(payload['client_uuid'], 'cust-uuid');
    });

    test('không khai vật tư ⇒ không gửi khoá materials; thao tác khác add bị bỏ', () {
      final none = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {'name': 'A', 'region_id': 5});
      expect(none.containsKey('materials'), isFalse);
      final confirmOnly = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {
        'name': 'A',
        'materials': [const MaterialOperation(clientUuid: 'x', materialTypeId: 1, action: MaterialAction.confirm).toJson()],
      });
      expect(confirmOnly.containsKey('materials'), isFalse);
    });

    test('ảnh trên máy đổi ra token trước khi dựng (resolveCreateMaterials), ô chọn nhiều giữ nguyên', () async {
      final raw = [
        const MaterialOperation(
          clientUuid: 'u',
          materialTypeId: 2,
          action: MaterialAction.add,
          conditionCounts: {'good': 1},
          details: {'loai': ['a', 'b']},
          photos: ['/khong/con/tren/may.jpg', 'ffffffffffffffffffffffffffffffff'],
        ).toJson(),
      ];
      final resolved = await resolveCreateMaterials(raw, (_) async => 'x');
      final op = MaterialOperation.fromJson(resolved.single);
      expect(op.photos, ['ffffffffffffffffffffffffffffffff'], reason: 'tệp không còn bị bỏ, token giữ');
      expect(op.details, {'loai': ['a', 'b']});
      expect(op.clientUuid, 'u');
    });
  });

  test('cache điểm bán vừa tạo: lượt đầu thấy vật tư đã khai, chưa "đã kiểm", loại bắt buộc viếng thăm = chưa biết', () {
    final cat = catalogJson()['catalog'] as Map<String, dynamic>;
    final entry = createdOutletCacheEntry(cat, const [
      MaterialOperation(clientUuid: 'a', materialTypeId: 2, action: MaterialAction.add, conditionCounts: {'good': 3}),
    ]);
    final c = materialsFromCache(outletEntry: jsonDecode(jsonEncode(entry)) as Map<String, dynamic>, visitClientUuid: 'v1')!;
    final bh = c.data.items.single;
    expect(bh.materialTypeId, 2);
    expect(bh.quantity, 3);
    expect(bh.checkedInVisit, isFalse);
    expect(c.requiredFromOtherOutlet, isTrue);
    expect(c.data.missingAfterLocal, isEmpty);
  });

  group('Ảnh vật tư bị /dms/form-photos từ chối khi đồng bộ lượt tạo ngoại tuyến', () {
    test('4xx ⇒ bỏ ảnh đó, thao tác + điểm bán vẫn đi tiếp; 5xx / mạng ⇒ ném để thử lại', () async {
      final dir = await Directory.systemTemp.createTemp('vat_tu_tao');
      addTearDown(() => dir.delete(recursive: true));
      final bad = File('${dir.path}/bad.jpg')..writeAsBytesSync([1]);
      final good = File('${dir.path}/good.jpg')..writeAsBytesSync([2]);
      final raw = [
        MaterialOperation(
          clientUuid: 'u',
          materialTypeId: 2,
          action: MaterialAction.add,
          conditionCounts: const {'good': 1},
          photos: [bad.path, good.path],
        ).toJson(),
      ];

      final resolved = await resolveCreateMaterials(
        raw,
        skipRejectedMaterialPhotos((f) async {
          if (f.path == bad.path) throw const AppException('Tệp không hợp lệ.', 422);
          return 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        }),
      );
      final op = MaterialOperation.fromJson(resolved.single);
      expect(op.photos, ['eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee']);
      expect(op.clientUuid, 'u');

      await expectLater(
        resolveCreateMaterials(
          raw,
          skipRejectedMaterialPhotos((_) async => throw const AppException('Lỗi máy chủ', 503)),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        resolveCreateMaterials(raw, skipRejectedMaterialPhotos((_) async => throw const NetworkException())),
        throwsA(isA<NetworkException>()),
      );
      // 401 / 408 / 429 là lỗi TẠM ⇒ ném để thử lại, không bỏ ảnh vĩnh viễn.
      for (final code in [401, 408, 429]) {
        await expectLater(
          resolveCreateMaterials(raw, skipRejectedMaterialPhotos((_) async => throw AppException('Tạm', code))),
          throwsA(isA<AppException>()),
        );
      }
    });
  });
}

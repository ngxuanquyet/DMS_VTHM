import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/core/services/anti_fraud_service.dart';
import 'package:vthm_dms/core/sync/sync_entity_group.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/presentation/widgets/material_card.dart';

/// Vật tư tại điểm bán trong lượt viếng thăm (#24522) — hợp đồng API-VAT-TU-MOBILE-2026-10-30.
void main() {
  // Phản hồi thật (đã cắt gọn) của GET /dms/visits/{id}/materials trong tài liệu API.
  Map<String, dynamic> getBody() => jsonDecode('''
{
  "success": true,
  "data": {
    "catalog": {
      "types": [
        {"id": 73, "code": "ZZAPI_KE", "name": "Kệ trưng bày", "unit": "cái", "require_photo": false, "is_active": true,
         "schema": {"blocks": [{"ref": "so_ma_hang", "type": "field", "required": false,
            "resolved": {"code": "so_ma_hang", "label": "Số mã hàng", "input_type": "number"}}]}},
        {"id": 74, "code": "BH", "name": "Biển hiệu", "unit": "cái", "require_photo": true, "is_active": true, "schema": null},
        {"id": 75, "code": "ST", "name": "Standee", "unit": "cái", "require_photo": false, "is_active": true, "schema": null},
        {"id": 76, "code": "OLD", "name": "Loại cũ", "unit": "", "require_photo": false, "is_active": false, "schema": null}
      ],
      "conditions": [
        {"code": "good", "name": "Tốt", "color": "success", "is_present": true},
        {"code": "minor", "name": "Hỏng nhẹ", "color": "warning", "is_present": true},
        {"code": "lost", "name": "Mất", "color": "dark", "is_present": false}
      ]
    },
    "items": [
      {"id": 40, "material_type_id": 73, "type": {"id": 73, "code": "ZZAPI_KE", "name": "Kệ trưng bày", "unit": "cái",
       "require_photo": false, "is_active": true},
       "condition_counts": {"good": 4, "minor": 1}, "quantity": 5, "details": {"so_ma_hang": 32},
       "as_of": "2026-10-30 12:10:03+07", "last_user": {"id": 12798, "name": "Nguyễn Văn A"},
       "last_photos": [{"token": "0123456789abcdef0123456789abcdef", "url": "/dms/form-photos/public/x"}],
       "is_required": false, "checked_in_visit": true},
      {"id": 41, "material_type_id": 75, "type": {"id": 75, "name": "Standee"},
       "condition_counts": {}, "quantity": 0, "details": null, "as_of": "2026-10-12 09:00:00+07", "last_user": null,
       "last_photos": [], "is_required": false, "checked_in_visit": false},
      {"id": null, "material_type_id": 74, "type": {"id": 74, "name": "Biển hiệu"},
       "condition_counts": null, "quantity": null, "details": null, "as_of": null, "last_user": null, "last_photos": [],
       "is_required": true, "checked_in_visit": false}
    ],
    "required_type_ids": [74],
    "missing_required": [{"material_type_id": 74, "name": "Biển hiệu"}]
  }
}
''') as Map<String, dynamic>;

  VisitMaterialsData parse() => VisitMaterialsData.fromJson(getBody()['data'] as Map<String, dynamic>);

  group('Phân tích GET materials', () {
    test('condition_counts: {} là Map rỗng, null (dòng trống) là null, [] coi như {}', () {
      final d = parse();
      expect(d.items[0].conditionCounts, {'good': 4, 'minor': 1});
      expect(d.items[1].conditionCounts, isNotNull);
      expect(d.items[1].conditionCounts, isEmpty);
      expect(d.items[2].conditionCounts, isNull);
      expect(parseConditionCounts(<dynamic>[]), isEmpty);
      expect(parseConditionCounts({'good': '3'}), {'good': 3});
    });

    test('dòng trống, dòng SL 0, cờ bắt buộc / đã kiểm, người + ảnh lần trước', () {
      final d = parse();
      expect(d.items[2].isBlank, isTrue);
      expect(d.items[2].isRequired, isTrue);
      expect(d.items[1].isEmptyQuantity, isTrue);
      expect(d.items[0].isEmptyQuantity, isFalse);
      expect(d.items[0].checkedInVisit, isTrue);
      expect(d.items[0].lastUserName, 'Nguyễn Văn A');
      expect(d.items[0].lastPhotos.single.token, '0123456789abcdef0123456789abcdef');
      expect(d.items[0].details, {'so_ma_hang': 32});
    });

    test('danh mục: schema chi tiết đọc bằng bộ đọc biểu mẫu thị trường; null = không có chi tiết', () {
      final d = parse();
      expect(d.conditions.map((c) => c.code), ['good', 'minor', 'lost']);
      expect(d.conditions.last.isPresent, isFalse);
      final ke = d.typeById(73)!;
      expect(ke.detailBlocks.single.resolved.code, 'so_ma_hang');
      expect(ke.detailBlocks.single.resolved.inputType, 'number');
      expect(d.typeById(74)!.detailBlocks, isEmpty);
      // Bản trả cũ chỉ có `require_photo` ⇒ tối thiểu 1, tối đa mặc định 10.
      expect(d.typeById(74)!.minPhotos, 1);
      expect(d.typeById(74)!.maxPhotos, 10);
      final moi = OutletMaterialType.fromJson({'id': 1, 'name': 'x', 'min_photos': 2, 'max_photos': 3});
      expect([moi.minPhotos, moi.maxPhotos], [2, 3]);
      final lech = OutletMaterialType.fromJson({'id': 2, 'name': 'y', 'min_photos': 5, 'max_photos': 2});
      expect(lech.minPhotos, 2, reason: 'tối thiểu kẹp ≤ tối đa — không thì form không bao giờ lưu được');
    });

    test('thẻ vật tư: chi tiết theo thứ tự biểu mẫu, lựa chọn ra NHÃN, bỏ ô trống/ô ảnh; ảnh token vs tệp máy', () {
      final t = OutletMaterialType.fromJson({
        'id': 9,
        'name': 'Tủ',
        'schema': {
          'blocks': [
            {'type': 'field', 'ref': 'vi_tri', 'required': false, 'resolved': {'code': 'vi_tri', 'label': 'Vị trí', 'input_type': 'select',
              'config': {'options': [{'value': 'mt', 'label': 'Mặt tiền'}]}}},
            {'type': 'field', 'ref': 'anh', 'required': false, 'resolved': {'code': 'anh', 'label': 'Ảnh', 'input_type': 'image'}},
            {'type': 'field', 'ref': 'ok', 'required': false, 'resolved': {'code': 'ok', 'label': 'Đúng hàng', 'input_type': 'checkbox'}},
            {'type': 'field', 'ref': 'trong', 'required': false, 'resolved': {'code': 'trong', 'label': 'Trống', 'input_type': 'text'}},
          ]
        }
      });
      const s = AppStrings(AppLanguage.vi);
      final rows = materialDetailRows(t, {'ok': true, 'vi_tri': 'mt', 'anh': ['x'], 'trong': '', 'cu': 5}, s);
      expect(rows.map((r) => '${r.key}=${r.value}'), ['Vị trí=Mặt tiền', 'Đúng hàng=Có', 'cu=5']);

      // Loại đã gỡ khỏi danh mục (không schema): danh sách ảnh không thành dòng chi tiết; số 5.0 ra "5".
      final mo = materialDetailRows(const OutletMaterialType(id: 1, name: 'x'),
          {'anh': ['0123456789abcdef0123456789abcdef'], 'so': 5.0, 'kt': ['60x90/cm']}, s);
      expect(mo.map((r) => '${r.key}=${r.value}'), ['so=5', 'kt=60x90/cm']);
      final cb = materialDetailRows(t, {'ok': 'true'}, s);
      expect(cb.single.value, 'Có');

      final tok = MaterialPhoto.fromRaw('0123456789abcdef0123456789abcdef');
      expect(tok.url, '/dms/form-photos/public/0123456789abcdef0123456789abcdef');
      expect(MaterialPhoto.fromRaw('/data/user/0/cache/a.jpg').localPath, '/data/user/0/cache/a.jpg');
    });

    test('lưu cục bộ: ảnh = ảnh của CHÍNH lần ghi (rỗng thì rỗng), người/giờ cũ bỏ đi', () {
      final d = parse();
      final before = d.items.firstWhere((i) => i.materialTypeId == 73);
      expect(before.lastPhotos, isNotEmpty);
      final next = applyMaterialOperation(
        d,
        const MaterialOperation(clientUuid: 'u', materialTypeId: 73, action: MaterialAction.update, conditionCounts: {'good': 1}),
        trusted: true,
      );
      final after = next.items.firstWhere((i) => i.materialTypeId == 73);
      expect(after.lastPhotos, isEmpty);
      expect(after.asOf, isNull);
      expect(after.lastUserName, isNull);
    });

    test('"+ Thêm loại" = loại đang bật trừ loại đã có dòng (có id); dòng trống vẫn thêm được', () {
      expect(parse().addableTypes.map((t) => t.id), [74]);
    });

    test('missing_required + requirements.missing_materials', () {
      final d = parse();
      expect(d.missingRequired.single.materialTypeId, 74);
      expect(d.missingAfterLocal.single.name, 'Biển hiệu');

      final req = VisitRequirementsEntity.fromJson({
        'satisfied': false,
        'missing_materials': [
          {'material_type_id': 74, 'name': 'Biển hiệu'}
        ],
        'blockers': ['Chưa kiểm vật tư bắt buộc: Biển hiệu'],
      });
      expect(req.missingMaterials.single.materialTypeId, 74);
      expect(req.materialsOk(false), isFalse);
      expect(req.materialsOk(true), isTrue, reason: 'lượt đóng cửa bỏ qua cổng vật tư');
      expect(VisitRequirementsEntity.fromJson(req.toJson()).missingMaterials.single.name, 'Biển hiệu');
      expect(VisitRequirementsEntity.fromJson(const {}).missingMaterials, isEmpty);
    });
  });

  group('Dựng payload POST', () {
    const uuid = '0b9a0f6e-7d6e-4c55-9b0a-6a1e2c3d4e5f';

    test('confirm chỉ gửi material_type_id + client_uuid', () {
      final m = const MaterialOperation(clientUuid: uuid, materialTypeId: 73, action: MaterialAction.confirm)
          .toItemJson();
      expect(m, {'client_uuid': uuid, 'material_type_id': 73, 'action': 'confirm'});
    });

    test('add với {} mã hoá ra object rỗng, không phải mảng', () {
      final m = const MaterialOperation(
        clientUuid: uuid,
        materialTypeId: 74,
        action: MaterialAction.add,
        conditionCounts: {},
      ).toItemJson();
      expect(jsonEncode(m['condition_counts']), '{}');
      expect(m.containsKey('details'), isFalse);
      expect(m.containsKey('photos'), isFalse);
    });

    test('update gửi counts + details + photos', () {
      final m = const MaterialOperation(
        clientUuid: uuid,
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: {'good': 3, 'minor': 2},
        details: {'so_ma_hang': 32},
        photos: ['0123456789abcdef0123456789abcdef'],
      ).toItemJson();
      expect(m['action'], 'update');
      expect(m['condition_counts'], {'good': 3, 'minor': 2});
      expect(m['details'], {'so_ma_hang': 32});
      expect(m['photos'], ['0123456789abcdef0123456789abcdef']);
    });

    test('remove gửi reason + photos', () {
      final m = const MaterialOperation(
        clientUuid: uuid,
        materialTypeId: 75,
        action: MaterialAction.remove,
        reason: 'Đại lý trả tủ',
        photos: ['0123456789abcdef0123456789abcdef'],
      ).toItemJson();
      expect(m['reason'], 'Đại lý trả tủ');
      expect(m['photos'], hasLength(1));
      expect(m.containsKey('condition_counts'), isFalse);
    });

    test('lô trực tuyến: is_offline_sync=false, queued_seconds=null; hàng đợi: queued_seconds ở lô và phần tử', () {
      const op = MaterialOperation(clientUuid: uuid, materialTypeId: 73, action: MaterialAction.confirm);
      final online = buildMaterialsRequest([op.toItemJson()], isOfflineSync: false, queuedSeconds: 99);
      expect(online['is_offline_sync'], isFalse);
      expect(online['queued_seconds'], isNull);
      expect((online['items'] as List).single['client_uuid'], uuid);
      expect(online['client_time'], isA<String>());

      final offline = buildMaterialsRequest(
        [op.toItemJson(isOfflineSync: true, queuedSeconds: 125)],
        isOfflineSync: true,
        queuedSeconds: 125,
      );
      expect(offline['is_offline_sync'], isTrue);
      expect(offline['queued_seconds'], 125);
      final item = (offline['items'] as List).single as Map;
      expect(item['is_offline_sync'], isTrue);
      expect(item['queued_seconds'], 125);

      // Máy khởi động lại giữa chừng ⇒ queued_seconds RỖNG (null), vẫn gửi khoá.
      final rebooted = op.toItemJson(isOfflineSync: true, queuedSeconds: null);
      expect(rebooted.containsKey('queued_seconds'), isTrue);
      expect(rebooted['queued_seconds'], isNull);
    });

    test('payload hàng đợi giữ nguyên client_uuid qua toJson/fromJson', () {
      const op = MaterialOperation(
        clientUuid: uuid,
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: {},
        photos: ['/data/user/0/app/cache/a.jpg'],
      );
      final payload = jsonEncode({'visit_id': -5, 'dealer_name': 'A', 'op': op.toJson()});
      final back = materialOperationFromQueuePayload(payload)!;
      expect(back.clientUuid, uuid);
      expect(back.action, MaterialAction.update);
      expect(back.conditionCounts, isEmpty);
      expect(back.hasLocalPhotos, isTrue);
      expect(materialOperationFromQueuePayload('{hỏng'), isNull);
    });
  });

  group('Đọc results từng phần tử', () {
    test('ok/không ok theo từng phần tử + requirements đi kèm', () {
      final res = MaterialSaveResponse.fromJson(jsonDecode('''
{"success": true, "data": {
  "results": [
    {"client_uuid": "u1", "ok": true, "log_id": 52, "outlet_material_id": 40},
    {"client_uuid": null, "ok": false, "error": "Gỡ vật tư cần ghi lý do và chụp ít nhất một ảnh."}
  ],
  "requirements": {"satisfied": false, "missing_materials": [], "blockers": ["Bạn cần chụp thêm 2 ảnh nữa."]}
}}'''));
      expect(res.results, hasLength(2));
      final r1 = res.resultFor('u1', 0)!;
      expect(r1.ok, isTrue);
      expect(r1.logId, 52);
      expect(r1.outletMaterialId, 40);
      // client_uuid null ⇒ rơi về vị trí phần tử.
      final r2 = res.resultFor('u2', 1)!;
      expect(r2.ok, isFalse);
      expect(r2.error, 'Gỡ vật tư cần ghi lý do và chụp ít nhất một ảnh.');
      expect(res.requirements!.missingMaterials, isEmpty);
      expect(res.requirements!.blockers.single, 'Bạn cần chụp thêm 2 ảnh nữa.');
    });

    test('phản hồi thiếu data/results không ném lỗi', () {
      final res = MaterialSaveResponse.fromJson({'success': true});
      expect(res.results, isEmpty);
      expect(res.requirements, isNull);
      expect(res.resultFor('x', 0), isNull);
    });
  });

  group('Áp thao tác trên máy (cổng check-out ngoại tuyến)', () {
    test('add cho dòng trống ⇒ có id tạm, SL = tổng, hết thiếu bắt buộc', () {
      final d = applyMaterialOperation(
        parse(),
        const MaterialOperation(clientUuid: 'a', materialTypeId: 74, action: MaterialAction.add, conditionCounts: {}),
      );
      final row = d.items.firstWhere((i) => i.materialTypeId == 74);
      expect(row.isBlank, isFalse);
      expect(row.quantity, 0);
      expect(row.checkedInVisit, isTrue);
      expect(d.missingAfterLocal, isEmpty);
    });

    test('update gộp details, remove về 0, confirm chỉ đánh dấu đã kiểm', () {
      var d = applyMaterialOperation(
        parse(),
        const MaterialOperation(
          clientUuid: 'b',
          materialTypeId: 73,
          action: MaterialAction.update,
          conditionCounts: {'good': 2, 'minor': 1},
          details: {'phan_tram': 70},
        ),
      );
      var ke = d.items.firstWhere((i) => i.materialTypeId == 73);
      expect(ke.quantity, 3);
      expect(ke.details, {'so_ma_hang': 32, 'phan_tram': 70});

      d = applyMaterialOperation(
        d,
        const MaterialOperation(clientUuid: 'c', materialTypeId: 73, action: MaterialAction.remove, reason: 'x'),
      );
      ke = d.items.firstWhere((i) => i.materialTypeId == 73);
      expect(ke.quantity, 0);
      expect(ke.conditionCounts, isEmpty);

      d = applyMaterialOperation(
        d,
        const MaterialOperation(clientUuid: 'd', materialTypeId: 75, action: MaterialAction.confirm),
      );
      final st = d.items.firstWhere((i) => i.materialTypeId == 75);
      expect(st.checkedInVisit, isTrue);
      expect(st.quantity, 0);
    });

    test('cache của lượt trước dùng cho lượt mới: bỏ cờ đã kiểm, mọi loại bắt buộc lại thiếu', () {
      final fresh = applyMaterialOperation(
        parse(),
        const MaterialOperation(clientUuid: 'e', materialTypeId: 74, action: MaterialAction.add, conditionCounts: {}),
      ).copyWith();
      final next = VisitMaterialsData(
        types: fresh.types,
        conditions: fresh.conditions,
        items: fresh.items,
        requiredTypeIds: fresh.requiredTypeIds,
        missingRequired: const [],
      ).resetForNewVisit();
      expect(next.items.any((i) => i.checkedInVisit), isFalse);
      expect(next.missingRequired.single.name, 'Biển hiệu');
    });
  });

  group('Ảnh trên máy đổi ra token trước khi gửi', () {
    test('photos + ô ảnh trong details; token sẵn giữ nguyên; tệp mất thì bỏ', () async {
      final dir = await Directory.systemTemp.createTemp('vat_tu_test');
      addTearDown(() => dir.delete(recursive: true));
      final f1 = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      final f2 = File('${dir.path}/b.jpg')..writeAsBytesSync([4]);
      const token = 'ffffffffffffffffffffffffffffffff';
      final uploaded = <String>[];

      final op = MaterialOperation(
        clientUuid: 'u',
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: const {'good': 1},
        details: {
          'anh_ke': [f2.path],
          'so_ma_hang': 3,
          'loai_hang': ['gach_op', 'gach_lat'],
        },
        photos: [token, f1.path, '${dir.path}/khong-co.jpg'],
        detailPhotoFields: const ['anh_ke'],
      );
      final out = await resolveOperationPhotos(op, (file) async {
        uploaded.add(file.path);
        return 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa${uploaded.length}';
      });
      expect(uploaded, [f1.path, f2.path]);
      expect(out.photos, [token, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1']);
      expect(out.details!['anh_ke'], ['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2']);
      expect(out.details!['so_ma_hang'], 3);
      expect(out.details!['loai_hang'], ['gach_op', 'gach_lat'], reason: 'ô chọn nhiều KHÔNG phải ảnh');
      expect(out.clientUuid, 'u');
      expect(out.hasLocalPhotos, isFalse);
    });

    test('lỗi tải ảnh được ném ra (hàng đợi thử lại, không gửi thiếu ảnh)', () async {
      final dir = await Directory.systemTemp.createTemp('vat_tu_test');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
      final op = MaterialOperation(
        clientUuid: 'u',
        materialTypeId: 75,
        action: MaterialAction.remove,
        reason: 'x',
        photos: [f.path],
      );
      await expectLater(
        resolveOperationPhotos(op, (_) async => throw const SocketException('mất mạng')),
        throwsA(isA<SocketException>()),
      );
      expect(isRetryableMaterialError(const SocketException('x')), isTrue);
    });
  });

  test('hàng đợi: thao tác vật tư gom vào lượt viếng thăm của nó', () {
    SyncQueueEntry e(int id, String entity, String op, String uuid, String? parent, Map<String, dynamic> p) =>
        SyncQueueEntry(
          id: id,
          entity: entity,
          op: op,
          clientUuid: uuid,
          parentUuid: parent,
          payload: jsonEncode(p),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: id,
          createdElapsed: id,
          bootId: 'boot',
          serverId: null,
        );
    final groups = SyncEntityGroupHelper.groupEntries([
      e(1, 'visit', 'create', 'v1', null, {'dealer_name': 'Tạp hoá A'}),
      e(2, 'visit_material', 'save', 'm1', 'v1', {'visit_id': -1, 'dealer_name': 'Tạp hoá A', 'op': {}}),
      e(3, 'visit_material', 'save', 'm2', 'v1', {'visit_id': -1, 'dealer_name': 'Tạp hoá A', 'op': {}}),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.entityType, 'visit');
    expect(groups.single.subtitle, contains('2 thao tác vật tư'));
  });

  group('#2 ô chọn nhiều trong details không bị coi là ảnh', () {
    test('List<String> ở ô không phải ảnh ⇒ không có ảnh trên máy, giữ nguyên giá trị khi gửi', () async {
      const op = MaterialOperation(
        clientUuid: 'u',
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: {'good': 1},
        details: {
          'loai_hang': ['gach_op', 'gach_lat'],
        },
      );
      expect(op.hasLocalPhotos, isFalse);
      var uploads = 0;
      final out = await resolveOperationPhotos(op, (_) async {
        uploads++;
        return 'x';
      });
      expect(uploads, 0);
      expect(out.toItemJson()['details'], {
        'loai_hang': ['gach_op', 'gach_lat'],
      });
    });

    test('detail_photo_fields + clicked_at_server_ms đi qua payload hàng đợi, KHÔNG lên API', () {
      const op = MaterialOperation(
        clientUuid: 'u',
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: {},
        details: {
          'anh_ke': ['/data/a.jpg'],
        },
        detailPhotoFields: ['anh_ke'],
        clickedAtServerMs: 1234,
      );
      final back = materialOperationFromQueuePayload(jsonEncode({'op': op.toJson()}))!;
      expect(back.detailPhotoFields, ['anh_ke']);
      expect(back.clickedAtServerMs, 1234);
      expect(back.hasLocalPhotos, isTrue);
      final item = back.toItemJson();
      expect(item.containsKey('detail_photo_fields'), isFalse);
      expect(item.containsKey('clicked_at_server_ms'), isFalse);
    });
  });

  group('#1 thứ tự hàng đợi: check-out nhường thao tác vật tư của cùng lượt', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
    tearDown(() => db.close());

    Future<int> enqueue(String entity, String op, String uuid, String? parent, {int? nextAttemptAt}) =>
        db.enqueue(SyncQueueEntriesCompanion.insert(
          entity: entity,
          op: op,
          clientUuid: uuid,
          parentUuid: Value(parent),
          payload: '{}',
          createdAt: 0,
          createdElapsed: 0,
          bootId: 'b',
          nextAttemptAt: Value(nextAttemptAt),
        ));

    test('vật tư đang chờ thử lại (backoff) ⇒ vòng FIFO chỉ thấy check-out, nhưng check-out bị giữ', () async {
      final future = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      final matId = await enqueue('visit_material', 'save', 'm1', 'visitA', nextAttemptAt: future);
      await enqueue('visit', 'checkout', 'c1', 'visitA');

      final due = await db.getPendingQueueEntries();
      expect(due.map((e) => e.entity), ['visit'], reason: 'lịch thử lại cho check-out vượt lên — chính là lỗi cũ');
      expect(await db.isCheckoutHeldByMaterials(due.single), isTrue);

      await db.markDone(matId);
      expect(await db.isCheckoutHeldByMaterials(due.single), isFalse);
    });

    test('mục vật tư bị từ chối (dead) không giữ check-out mãi; vật tư lượt khác không liên quan', () async {
      final matId = await enqueue('visit_material', 'save', 'm1', 'visitA');
      await enqueue('visit_material', 'save', 'm2', 'visitB');
      await enqueue('visit', 'checkout', 'c1', 'visitA');
      final checkout = (await db.getPendingQueueEntries()).firstWhere((e) => e.entity == 'visit');
      expect(await db.isCheckoutHeldByMaterials(checkout), isTrue);
      await db.markDead(matId, 'Lượt viếng thăm này đã check-out.');
      expect(await db.isCheckoutHeldByMaterials(checkout), isFalse);
      expect(await db.hasOpenVisitMaterials('visitB'), isTrue);
    });

    test('mục không phải check-out không bao giờ bị giữ', () async {
      await enqueue('visit_material', 'save', 'm1', 'visitA');
      await enqueue('visit_photo', 'upload', 'p1', 'visitA');
      final photo = (await db.getPendingQueueEntries()).firstWhere((e) => e.entity == 'visit_photo');
      expect(await db.isCheckoutHeldByMaterials(photo), isFalse);
    });
  });

  group('#3/#4 cache sau khi gửi + khi chưa có cache điểm bán', () {
    Map<String, dynamic> outletEntry(String visit) =>
        {'visit_client_uuid': visit, 'data': getBody()['data'], 'ops': const []};

    test('gửi trực tuyến xong ghi thêm vào cache ⇒ mất mạng, mở lại cùng lượt vẫn "đã kiểm", cổng ④ đủ', () {
      final entry = appendOpToCacheEntry(
        outletEntry('visitA'),
        'visitA',
        const MaterialOperation(clientUuid: 'x1', materialTypeId: 74, action: MaterialAction.add, conditionCounts: {}),
      );
      final c = materialsFromCache(outletEntry: entry, visitClientUuid: 'visitA')!;
      expect(c.data.missingAfterLocal, isEmpty);
      expect(c.data.items.firstWhere((i) => i.materialTypeId == 74).checkedInVisit, isTrue);
      expect(c.requiredFromOtherOutlet, isFalse);

      // Gửi lại cùng uuid không nhân đôi.
      final again = appendOpToCacheEntry(
        entry,
        'visitA',
        const MaterialOperation(clientUuid: 'x1', materialTypeId: 74, action: MaterialAction.add, conditionCounts: {}),
      );
      expect((again['ops'] as List), hasLength(1));
    });

    test('lượt MỚI dùng cache lượt trước: hiện trạng giữ, cờ đã kiểm xoá, loại bắt buộc lại thiếu', () {
      final entry = appendOpToCacheEntry(
        outletEntry('visitA'),
        'visitA',
        const MaterialOperation(
          clientUuid: 'x1',
          materialTypeId: 74,
          action: MaterialAction.add,
          conditionCounts: {'good': 2},
        ),
      );
      final c = materialsFromCache(outletEntry: entry, visitClientUuid: 'visitB')!;
      final bh = c.data.items.firstWhere((i) => i.materialTypeId == 74);
      expect(bh.quantity, 2);
      expect(bh.checkedInVisit, isFalse);
      expect(c.data.missingAfterLocal.single.materialTypeId, 74);
    });

    test('thao tác trong hàng đợi bị server từ chối (dead) không được tính là đã kiểm', () {
      final entry = appendOpToCacheEntry(
        outletEntry('visitA'),
        'visitA',
        const MaterialOperation(clientUuid: 'x1', materialTypeId: 74, action: MaterialAction.confirm),
      );
      final dead = SyncQueueEntry(
        id: 1,
        entity: 'visit_material',
        op: 'save',
        clientUuid: 'x1',
        parentUuid: 'visitA',
        payload: '{}',
        state: 'dead',
        attempts: 0,
        nextAttemptAt: null,
        lastError: null,
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
        serverId: null,
      );
      final c = materialsFromCache(outletEntry: entry, visitClientUuid: 'visitA', queueEntries: [dead])!;
      expect(c.data.missingAfterLocal.single.materialTypeId, 74);
    });

    test('#3 danh mục của điểm bán KHÁC chỉ để cảnh báo: gắn cờ, KHÔNG đòi loại bắt buộc nào; không có gì ⇒ null', () {
      final data = getBody()['data'] as Map<String, dynamic>;
      final c = materialsFromCache(
        lastCatalog: {'catalog': data['catalog'], 'required_type_ids': data['required_type_ids']},
        visitClientUuid: 'visitC',
      )!;
      expect(c.requiredFromOtherOutlet, isTrue);
      expect(c.data.items, isEmpty, reason: 'không dựng dòng trống ép "+ Thêm" loại có thể không áp dụng');
      expect(c.data.missingAfterLocal, isEmpty, reason: 'luật theo loại điểm bán ⇒ không chặn cứng check-out');
      expect(c.data.addableTypes.map((t) => t.id), containsAll([73, 74, 75]), reason: 'danh mục vẫn dùng được');
      expect(materialsFromCache(visitClientUuid: 'visitC'), isNull);
    });

    test('#5 op lượt TRƯỚC bị server từ chối (dead) không áp vào hiện trạng', () {
      final entry = appendOpToCacheEntry(
        outletEntry('visitA'),
        'visitA',
        const MaterialOperation(
          clientUuid: 'bad',
          materialTypeId: 73,
          action: MaterialAction.update,
          conditionCounts: {'good': 99},
        ),
      );
      final ok = materialsFromCache(outletEntry: entry, visitClientUuid: 'visitB')!;
      expect(ok.data.items.firstWhere((i) => i.materialTypeId == 73).quantity, 99);
      final dead = materialsFromCache(outletEntry: entry, visitClientUuid: 'visitB', deadUuids: {'bad'})!;
      expect(dead.data.items.firstWhere((i) => i.materialTypeId == 73).quantity, 5);
    });
  });

  group('#5 lớp phủ không đè dữ liệu GET mới hơn', () {
    test('as_of server dạng "+07" đọc được', () {
      expect(parseAsOf('2026-10-30 12:10:03+07')!.toUtc(), DateTime.utc(2026, 10, 30, 5, 10, 3));
      expect(parseAsOf(null), isNull);
      expect(parseAsOf('rác'), isNull);
    });

    test('thao tác bấm TRƯỚC as_of chỉ đánh dấu đã kiểm, bấm SAU thì đè số', () {
      final asOf = parseAsOf('2026-10-30 12:10:03+07')!.millisecondsSinceEpoch;
      SyncQueueEntry pending(String uuid, int clickedAt) => SyncQueueEntry(
            id: 1,
            entity: 'visit_material',
            op: 'save',
            clientUuid: uuid,
            parentUuid: 'v',
            payload: jsonEncode({
              'op': MaterialOperation(
                clientUuid: uuid,
                materialTypeId: 73,
                action: MaterialAction.update,
                conditionCounts: const {'good': 1},
                clickedAtServerMs: clickedAt,
              ).toJson(),
            }),
            state: 'pending',
            attempts: 0,
            nextAttemptAt: null,
            lastError: null,
            createdAt: clickedAt,
            createdElapsed: 0,
            bootId: 'b',
            serverId: null,
          );

      final older = overlayPendingQueue(parse(), [pending('o', asOf - 60000)]);
      final keOld = older.items.firstWhere((i) => i.materialTypeId == 73);
      expect(keOld.quantity, 5, reason: 'người khác cập nhật sau mình — giữ số server');
      expect(keOld.checkedInVisit, isTrue);

      final newer = overlayPendingQueue(parse(), [pending('n', asOf + 60000)]);
      expect(newer.items.firstWhere((i) => i.materialTypeId == 73).quantity, 1);
    });

    test('#2 giờ máy lệch: thao tác server đã nhận (trusted) luôn hiện; mốc 0 (chưa biết giờ máy chủ) không so', () {
      final asOf = parseAsOf('2026-10-30 12:10:03+07')!.millisecondsSinceEpoch;
      // Máy chạy CHẬM 1 giờ: mốc bấm (nếu lấy giờ máy) trông như trước as_of dù bấm sau.
      final skewed = MaterialOperation(
        clientUuid: 's',
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: const {'good': 2},
        clickedAtServerMs: asOf - 3600 * 1000,
      );
      final trusted = applyMaterialOperation(parse(), skewed, trusted: true);
      expect(trusted.items.firstWhere((i) => i.materialTypeId == 73).quantity, 2);

      // Cache: thao tác gửi trực tuyến xong (ok) được áp thẳng khi dựng lại, kể cả mốc "trước" as_of.
      final entry = appendOpToCacheEntry(
        {'visit_client_uuid': 'v', 'data': getBody()['data'], 'ops': const []},
        'v',
        skewed,
        serverOk: true,
      );
      final c = materialsFromCache(outletEntry: entry, visitClientUuid: 'v')!;
      expect(c.data.items.firstWhere((i) => i.materialTypeId == 73).quantity, 2);

      final unknownClock = applyMaterialOperation(
        parse(),
        const MaterialOperation(
          clientUuid: 'u',
          materialTypeId: 73,
          action: MaterialAction.update,
          conditionCounts: {'good': 3},
        ),
      );
      expect(unknownClock.items.firstWhere((i) => i.materialTypeId == 73).quantity, 3);
    });

    test('#2 mốc bấm lấy theo GIỜ MÁY CHỦ (header Date + đồng hồ đơn điệu), không theo giờ máy', () {
      final server = DateTime.utc(2020, 1, 1, 8);
      AntiFraudService.recordServerTime(server);
      final ms = serverClockNowMs();
      expect(ms, greaterThanOrEqualTo(server.millisecondsSinceEpoch));
      expect(ms - server.millisecondsSinceEpoch, lessThan(5000), reason: 'giờ máy năm 2026 không lọt vào mốc');
    });

    test('số 0 tường minh (tình trạng đã tắt) không thành huy hiệu', () {
      final d = applyMaterialOperation(
        parse(),
        const MaterialOperation(
          clientUuid: 'z',
          materialTypeId: 73,
          action: MaterialAction.update,
          conditionCounts: {'good': 2, 'old_code': 0},
        ),
      );
      final ke = d.items.firstWhere((i) => i.materialTypeId == 73);
      expect(ke.conditionCounts, {'good': 2});
      expect(ke.quantity, 2);
      expect(
        const MaterialOperation(
          clientUuid: 'z',
          materialTypeId: 73,
          action: MaterialAction.update,
          conditionCounts: {'good': 2, 'old_code': 0},
        ).toItemJson()['condition_counts'],
        {'good': 2, 'old_code': 0},
        reason: 'gửi 0 tường minh để server xoá số ở mã đã tắt',
      );
    });
  });

  group('#1 lối thoát: thao tác vật tư lỗi máy chủ lặp lại không giữ check-out mãi', () {
    final basePayload = jsonEncode({
      'visit_id': 5,
      'op': const MaterialOperation(clientUuid: 'm', materialTypeId: 73, action: MaterialAction.confirm).toJson(),
    });
    const t0 = 1_000_000_000;
    const minute = 60 * 1000;

    (String, bool) failN(String p, int n, {required int startMs, int stepMs = 1000}) {
      var cur = p;
      var stop = false;
      for (var i = 0; i < n; i++) {
        (cur, stop) = recordVisitMaterialFailure(cur, serverError: true, nowMs: startMs + i * stepMs);
      }
      return (cur, stop);
    }

    test('#3 đủ số lần nhưng CHƯA đủ 30 phút (ép đồng bộ liên tục lúc API 502) ⇒ chưa bỏ cuộc', () {
      final (p, stop) = failN(basePayload, visitMaterialMaxServerFailures + 5, startMs: t0);
      expect(stop, isFalse);
      expect(visitMaterialServerFailures(p), visitMaterialMaxServerFailures + 5);
      expect(materialOperationFromQueuePayload(p)!.clientUuid, 'm', reason: 'payload còn nguyên thao tác');
      expect(jsonDecode(p)['visit_id'], 5);
    });

    test('#3 đủ 30 phút nhưng CHƯA đủ số lần ⇒ chưa bỏ cuộc; đủ CẢ HAI ⇒ bỏ cuộc', () {
      // Lỗi cách nhau 4 phút (trong khoảng "liên tiếp"): 9 lần trải 32 phút ⇒ đủ thời gian, thiếu số lần.
      var (p, stop) = failN(basePayload, visitMaterialMaxServerFailures - 1, startMs: t0, stepMs: 4 * minute);
      expect(visitMaterialServerFailures(p), visitMaterialMaxServerFailures - 1);
      expect(stop, isFalse);
      (p, stop) = recordVisitMaterialFailure(p, serverError: true, nowMs: t0 + 36 * minute);
      expect(stop, isTrue);
    });

    test('#3 khoảng nghỉ dài giữa hai lỗi (ngoại tuyến / tắt máy) ⇒ chuỗi mới, không tính thành "đã lỗi 30 phút"', () {
      // 2 lỗi lúc 10:00, máy ngoại tuyến 5 giờ, rồi 8 lỗi 502 dồn trong 1 phút lúc triển khai.
      var (p, _) = failN(basePayload, 2, startMs: t0);
      final (p2, stop) = failN(p, visitMaterialMaxServerFailures - 2, startMs: t0 + 300 * minute, stepMs: 5000);
      expect(stop, isFalse);
      expect(visitMaterialServerFailures(p2), visitMaterialMaxServerFailures - 2, reason: 'chuỗi cũ bị cắt');
      expect(jsonDecode(p2)['_server_failure_first_ms'], t0 + 300 * minute);
      expect(visitMaterialFailureChainGap > const Duration(minutes: 5), isTrue, reason: 'lớn hơn trần lịch thử lại');
      p = p2;
    });

    test('#3 lỗi mạng xen giữa ⇒ cắt chuỗi, đếm lại từ đầu (cả mốc lỗi đầu)', () {
      var (p, _) = failN(basePayload, visitMaterialMaxServerFailures - 1, startMs: t0);
      (p, _) = recordVisitMaterialFailure(p, serverError: false, nowMs: t0 + 31 * minute);
      expect(visitMaterialServerFailures(p), 0);
      expect(jsonDecode(p).containsKey('_server_failure_first_ms'), isFalse);
      final (p2, stop) = recordVisitMaterialFailure(p, serverError: true, nowMs: t0 + 32 * minute);
      expect(stop, isFalse);
      expect(jsonDecode(p2)['_server_failure_first_ms'], t0 + 32 * minute);
      // Lỗi mạng khi chưa có chuỗi lỗi ⇒ payload giữ nguyên (không ghi DB thừa).
      expect(recordVisitMaterialFailure(basePayload, serverError: false, nowMs: t0).$1, basePayload);
      expect(recordVisitMaterialFailure('{hỏng', serverError: true, nowMs: t0), ('{hỏng', false));
    });

    test('#3 payload từ bản app trước (có mốc đầu, thiếu mốc gần nhất) ⇒ chuỗi mới, không bỏ cuộc ngay', () {
      final old = jsonEncode({
        ...jsonDecode(basePayload) as Map<String, dynamic>,
        '_server_failures': visitMaterialMaxServerFailures - 1,
        '_server_failure_first_ms': t0,
      });
      final (p, stop) = recordVisitMaterialFailure(old, serverError: true, nowMs: t0 + 300 * minute);
      expect(stop, isFalse);
      expect(visitMaterialServerFailures(p), 1);
      expect(jsonDecode(p)['_server_failure_last_ms'], t0 + 300 * minute);
    });

    test('trần có giới hạn hợp lý', () {
      expect(visitMaterialMaxServerFailures, inInclusiveRange(3, 20));
      expect(visitMaterialGiveUpAfter.inMinutes, inInclusiveRange(10, 120));
      expect(visitMaterialFlushTimeout.inSeconds, inInclusiveRange(5, 60));
    });

    test('bỏ cuộc (dead) ⇒ check-out được thả; DB ghi lại payload bộ đếm', () async {
      final db = AppDatabase(NativeDatabase.memory(), 1);
      addTearDown(db.close);
      final matId = await db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'visit_material',
        op: 'save',
        clientUuid: 'm1',
        parentUuid: const Value('visitA'),
        payload: '{"visit_id":5,"op":{}}',
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
      ));
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'visit',
        op: 'checkout',
        clientUuid: 'c1',
        parentUuid: const Value('visitA'),
        payload: '{}',
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
      ));
      final checkout = (await db.getPendingQueueEntries()).firstWhere((e) => e.entity == 'visit');
      expect(await db.isCheckoutHeldByMaterials(checkout), isTrue);

      final (bumped, _) = recordVisitMaterialFailure('{"visit_id":5,"op":{}}', serverError: true, nowMs: t0);
      await db.updatePayload(matId, bumped);
      final mat = (await db.getVisitMaterialEntries('visitA')).single;
      expect(visitMaterialServerFailures(mat.payload), 1);

      await db.markDead(matId, 'Máy chủ lỗi 10 lần liên tiếp');
      expect(await db.isCheckoutHeldByMaterials(checkout), isFalse);
      expect(await db.getDeadVisitMaterialUuids(), {'m1'});
    });
  });

  group('Vòng ba: op bị từ chối không sống lại + reset cờ khi cache chưa có data', () {
    const opJson = {'client_uuid': 'bad', 'material_type_id': 74, 'action': 'confirm'};

    test('#1 removeOpFromCacheEntry gỡ đúng op, không đổi thì null', () {
      final entry = {
        'visit_client_uuid': 'v',
        'data': null,
        'ops': [
          {'visit': 'v', 'op': opJson, 'ok': false},
          {
            'visit': 'v',
            'op': {'client_uuid': 'good', 'material_type_id': 73, 'action': 'confirm'},
            'ok': true,
          },
        ],
      };
      final next = removeOpFromCacheEntry(entry, 'bad')!;
      expect((next['ops'] as List).map((o) => (o as Map)['op']['client_uuid']), ['good']);
      expect(removeOpFromCacheEntry(next, 'bad'), isNull);
    });

    test('#1 đánh dead ⇒ gỡ op khỏi cache MỌI điểm bán; xoá dòng lỗi sau đó op không sống lại', () async {
      final data = getBody()['data'];
      SharedPreferences.setMockInitialValues({
        '${visitMaterialsCachePrefix}7': jsonEncode({
          'visit_client_uuid': 'v',
          'data': data,
          'ops': [
            {'visit': 'v', 'op': opJson, 'ok': false},
          ],
        }),
        visitMaterialsLastCatalogKey: jsonEncode({'catalog': (data as Map)['catalog']}),
        'khoa_khac': 'x',
      });
      // Trước khi gỡ: op confirm Biển hiệu làm cổng ④ tưởng đã kiểm.
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> entry() =>
          Map<String, dynamic>.from(jsonDecode(prefs.getString('${visitMaterialsCachePrefix}7')!) as Map);
      expect(materialsFromCache(outletEntry: entry(), visitClientUuid: 'v')!.data.missingAfterLocal, isEmpty);

      await forgetCachedMaterialOp('bad');

      // Không truyền deadUuids (dòng dead đã bị NV xoá) mà op vẫn không còn.
      final c = materialsFromCache(outletEntry: entry(), visitClientUuid: 'v')!;
      expect(c.data.missingAfterLocal.single.materialTypeId, 74);
      expect(prefs.getString('khoa_khac'), 'x');
      expect(prefs.getString(visitMaterialsLastCatalogKey), isNotNull);
    });

    test('#2 cache {data:null, ops} (điểm bán chưa từng GET): cờ "đã kiểm" của lượt TRƯỚC không lọt sang lượt mới', () {
      final data = getBody()['data'] as Map<String, dynamic>;
      final entry = appendOpToCacheEntry(
        null,
        'visitA',
        const MaterialOperation(clientUuid: 'a1', materialTypeId: 73, action: MaterialAction.add, conditionCounts: {'good': 1}),
      );
      final c = materialsFromCache(
        outletEntry: entry,
        lastCatalog: {'catalog': data['catalog'], 'required_type_ids': data['required_type_ids']},
        visitClientUuid: 'visitB',
      )!;
      expect(c.requiredFromOtherOutlet, isTrue);
      final ke = c.data.items.firstWhere((i) => i.materialTypeId == 73);
      expect(ke.quantity, 1, reason: 'hiện trạng từ op lượt trước vẫn giữ');
      expect(ke.checkedInVisit, isFalse, reason: 'nhưng không tính là đã kiểm ở lượt mới');
      expect(c.data.missingAfterLocal, isEmpty, reason: 'withoutRequired: không đòi loại bắt buộc');

      // Cùng lượt thì vẫn "đã kiểm".
      final same = materialsFromCache(
        outletEntry: appendOpToCacheEntry(
          null,
          'visitB',
          const MaterialOperation(clientUuid: 'b1', materialTypeId: 73, action: MaterialAction.confirm),
        ),
        lastCatalog: {'catalog': data['catalog']},
        visitClientUuid: 'visitB',
      )!;
      expect(same.data.items.firstWhere((i) => i.materialTypeId == 73).checkedInVisit, isTrue);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/sync/sync_entity_group.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';

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
      expect(d.typeById(74)!.requirePhoto, isTrue);
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

    test('detail_photo_fields + clicked_at_ms đi qua payload hàng đợi, KHÔNG lên API', () {
      const op = MaterialOperation(
        clientUuid: 'u',
        materialTypeId: 73,
        action: MaterialAction.update,
        conditionCounts: {},
        details: {
          'anh_ke': ['/data/a.jpg'],
        },
        detailPhotoFields: ['anh_ke'],
        clickedAtMs: 1234,
      );
      final back = materialOperationFromQueuePayload(jsonEncode({'op': op.toJson()}))!;
      expect(back.detailPhotoFields, ['anh_ke']);
      expect(back.clickedAtMs, 1234);
      expect(back.hasLocalPhotos, isTrue);
      final item = back.toItemJson();
      expect(item.containsKey('detail_photo_fields'), isFalse);
      expect(item.containsKey('clicked_at_ms'), isFalse);
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

    test('điểm bán chưa có cache ⇒ loại bắt buộc theo lần tải gần nhất (gắn cờ); không có gì ⇒ null', () {
      final data = getBody()['data'] as Map<String, dynamic>;
      final c = materialsFromCache(
        lastCatalog: {'catalog': data['catalog'], 'required_type_ids': data['required_type_ids']},
        visitClientUuid: 'visitC',
      )!;
      expect(c.requiredFromOtherOutlet, isTrue);
      expect(c.data.items, isEmpty);
      expect(c.data.missingAfterLocal.single.name, 'Biển hiệu');
      expect(materialsFromCache(visitClientUuid: 'visitC'), isNull);
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
                clickedAtMs: clickedAt,
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
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/forms/data/services/form_draft_store.dart';

/// Nháp phiếu khảo sát trong lượt viếng thăm (chốt 19/11/2026): lưu cả ảnh, gắn lượt + phiếu, bỏ khi nộp / kết thúc lượt.
class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

void main() {
  late Directory docs;
  late Directory camera;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('draft_docs');
    camera = Directory.systemTemp.createTempSync('draft_cam');
    PathProviderPlatform.instance = _Paths(docs);
  });

  tearDown(() {
    docs.deleteSync(recursive: true);
    camera.deleteSync(recursive: true);
  });

  File shot(String name) => File('${camera.path}/$name')..writeAsBytesSync([1, 2, 3]);

  test('lưu rồi tải lại đúng lượt + phiếu; ảnh chép vào thư mục nháp, còn khi ảnh gốc bị dọn', () async {
    final a = shot('a.jpg');
    final m = shot('m.jpg');
    const token = '0123456789abcdef0123456789abcdef';
    await FormDraftStore.save(
      visitId: -5,
      clientUuid: 'uuid-1',
      configId: 7,
      answers: {
        'ghi_chu': 'xin chào',
        'anh': [a.path, token],
        'ma_tran': {
          'counts': {'r1:c1': 2},
          'photos': {
            'c1': [m.path],
          },
        },
      },
      photoMemo: {},
    );
    a.deleteSync();
    m.deleteSync();

    // Lượt ngoại tuyến đã lên server: id đổi, uuid giữ nguyên.
    final d = await FormDraftStore.load(visitId: 99, clientUuid: 'uuid-1', configId: 7);
    expect(d, isNotNull);
    expect(d!.answers['ghi_chu'], 'xin chào');
    final anh = d.answers['anh'] as List;
    expect(anh[1], token);
    expect(anh[0], contains('/${FormDraftStore.photoDir}/'));
    expect(File(anh[0] as String).existsSync(), isTrue);
    final mt = ((d.answers['ma_tran'] as Map)['photos'] as Map)['c1'] as List;
    expect(File(mt.first as String).existsSync(), isTrue);

    expect(await FormDraftStore.load(visitId: 99, clientUuid: 'uuid-1', configId: 8), isNull);
    expect(await FormDraftStore.load(visitId: 100, clientUuid: 'uuid-2', configId: 7), isNull);
  });

  test('nộp xong (remove) bỏ nháp phiếu đó cùng ảnh, phiếu khác giữ nguyên', () async {
    await FormDraftStore.save(
      visitId: 1,
      clientUuid: 'u',
      configId: 1,
      answers: {
        'anh': [shot('x.jpg').path],
      },
      photoMemo: {},
    );
    await FormDraftStore.save(visitId: 1, clientUuid: 'u', configId: 2, answers: {'so': 3}, photoMemo: {});
    final f = ((await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1))!.answers['anh'] as List).first;

    await FormDraftStore.remove(visitId: 1, clientUuid: 'u', configId: 1);
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1), isNull);
    expect(File(f as String).existsSync(), isFalse);
    expect((await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 2))!.answers['so'], 3);
  });

  test('kết thúc lượt (clearVisit) chỉ xoá nháp + tệp của ĐÚNG lượt đó', () async {
    expect(
      await FormDraftStore.save(
        visitId: 1,
        clientUuid: 'u',
        configId: 1,
        answers: {
          'anh': [shot('y.jpg').path],
        },
        photoMemo: {},
      ),
      isTrue,
    );
    final f = ((await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1))!.answers['anh'] as List).first;

    // resetSession ở đường không đóng lượt đang mở: state là lượt khác ⇒ giữ nguyên.
    await FormDraftStore.clearVisit(visitId: 2, clientUuid: 'khac');
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1), isNotNull);

    await FormDraftStore.clearVisit(visitId: 1, clientUuid: 'u');
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1), isNull);
    expect(File(f as String).existsSync(), isFalse);
  });

  test('ghi hỏng (giá trị không mã hoá được) ⇒ save trả false', () async {
    expect(
      await FormDraftStore.save(visitId: 1, clientUuid: 'u', configId: 1, answers: {'x': Object()}, photoMemo: {}),
      isFalse,
    );
  });

  test('lưu cho lượt KHÁC bỏ nháp của lượt cũ cùng ảnh', () async {
    await FormDraftStore.save(
      visitId: 1,
      clientUuid: 'u1',
      configId: 1,
      answers: {
        'anh': [shot('z.jpg').path],
      },
      photoMemo: {},
    );
    final f = ((await FormDraftStore.load(visitId: 1, clientUuid: 'u1', configId: 1))!.answers['anh'] as List).first;
    await FormDraftStore.save(visitId: 2, clientUuid: 'u2', configId: 1, answers: {'so': 1}, photoMemo: {});
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u1', configId: 1), isNull);
    expect(File(f as String).existsSync(), isFalse);
  });

  test('tuổi nháp tính từ lần lưu ĐẦU (token ảnh không già hơn nháp): quá maxAge thì bỏ dù vừa lưu lại', () async {
    final now = DateTime.now();
    final cu = now.subtract(FormDraftStore.maxAge + const Duration(hours: 1)).millisecondsSinceEpoch;
    final dem = now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch;
    final vua = now.millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'form_drafts_v1':
          '{"visit_id":1,"client_uuid":"u","drafts":{'
          '"1":{"created_at":$cu,"saved_at":$vua,"answers":{"a":1}},'
          '"2":{"created_at":$dem,"saved_at":$dem,"answers":{"a":2}}}}',
    });
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1), isNull);
    expect((await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 2))!.answers['a'], 2);

    // Lưu lại phiếu 2 KHÔNG làm trẻ lại created_at.
    await FormDraftStore.save(visitId: 1, clientUuid: 'u', configId: 2, answers: {'a': 3}, photoMemo: {});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('form_drafts_v1'), contains('"created_at":$dem'));
  });

  test('lưu đè nháp ĐÃ quá maxAge ⇒ nháp mới khôi phục được (không kế thừa created_at hết hạn)', () async {
    final cu = DateTime.now().subtract(FormDraftStore.maxAge + const Duration(hours: 1)).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'form_drafts_v1':
          '{"visit_id":1,"client_uuid":"u","drafts":{"1":{"created_at":$cu,"saved_at":$cu,"answers":{"a":1}}}}',
    });
    expect(await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1), isNull);
    await FormDraftStore.save(visitId: 1, clientUuid: 'u', configId: 1, answers: {'a': 2}, photoMemo: {});
    expect((await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1))!.answers['a'], 2);
  });

  test('nháp khôi phục lưu sang uuid lượt MỚI: tệp nháp đang dùng KHÔNG bị xoá', () async {
    await FormDraftStore.save(
      visitId: -3,
      clientUuid: 'cu',
      configId: 1,
      answers: {
        'anh': [shot('k.jpg').path],
      },
      photoMemo: {},
    );
    final restored = (await FormDraftStore.load(visitId: -3, clientUuid: 'cu', configId: 1))!.answers;
    final f = (restored['anh'] as List).first as String;
    await FormDraftStore.save(visitId: 9, clientUuid: 'moi', configId: 1, answers: restored, photoMemo: {});
    expect(File(f).existsSync(), isTrue);
    expect((await FormDraftStore.load(visitId: 9, clientUuid: 'moi', configId: 1))!.answers['anh'], [f]);
  });

  test('lưu nhiều lần cùng một ảnh không chép thêm bản mới (memo)', () async {
    final a = shot('a.jpg');
    final memo = <String, String>{};
    for (var i = 0; i < 3; i++) {
      await FormDraftStore.save(
        visitId: 1,
        clientUuid: 'u',
        configId: 1,
        answers: {
          'anh': [a.path],
          'i': i,
        },
        photoMemo: memo,
      );
    }
    expect(Directory('${docs.path}/${FormDraftStore.photoDir}').listSync(), hasLength(1));
  });

  test('ảnh đã có token: giữ TỆP GỐC (token_files) cho lúc token hết hạn; ảnh đã xoá khỏi câu trả lời thì bỏ tệp', () async {
    const t1 = '0123456789abcdef0123456789abcdef';
    const t2 = 'fedcba9876543210fedcba9876543210';
    final a = shot('t1.jpg');
    final b = shot('t2.jpg');
    await FormDraftStore.save(
      visitId: 1,
      clientUuid: 'u',
      configId: 1,
      answers: {
        'anh': [t1],
      },
      photoMemo: {},
      tokenFiles: {t1: a.path, t2: b.path},
    );
    a.deleteSync();
    final d = (await FormDraftStore.load(visitId: 1, clientUuid: 'u', configId: 1))!;
    expect(d.answers['anh'], [t1]);
    expect(d.tokenFiles.keys, [t1], reason: 't2 không còn trong câu trả lời');
    expect(d.tokenFiles[t1], contains('/${FormDraftStore.photoDir}/'));
    expect(File(d.tokenFiles[t1]!).existsSync(), isTrue);

    await FormDraftStore.remove(visitId: 1, clientUuid: 'u', configId: 1);
    expect(File(d.tokenFiles[t1]!).existsSync(), isFalse);
  });
}

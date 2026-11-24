import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/forms/data/services/form_draft_store.dart';
import 'package:vthm_dms/features/forms/data/services/form_suggest_store.dart';
import 'package:vthm_dms/features/forms/data/services/forms_api_service.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

import '../helpers/fake_inter_fonts.dart';

/// Chốt 20/11/2026: (1) ô chữ «Gợi ý từ các phiếu đã nộp» — chỉ hiện khi bắt đầu gõ, lọc không dấu, mất mạng dùng bản lưu
/// + giá trị chính máy vừa nộp; (2) nháp phiếu THU THẬP — mỗi biểu mẫu một nháp, ngăn riêng theo tài khoản.
class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

class _Api extends Fake implements FormsApiService {
  Map<String, List<String>>? server;
  Map<String, Map<String, Map<String, dynamic>>> fills = {};
  int calls = 0;

  @override
  Future<FormSuggestions> getSuggestions(int formId) async {
    calls++;
    final s = server;
    if (s == null) throw const SocketException('mất mạng');
    return (fields: s, fills: fills);
  }
}

void main() {
  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 42})});
    docs = Directory.systemTemp.createTempSync('suggest_docs');
    PathProviderPlatform.instance = _Paths(docs);
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('FormSuggestStore', () {
    test('có mạng ⇒ lấy server + lưu; mất mạng ⇒ bản lưu + giá trị vừa nộp đứng đầu; server đã có thì rời nhóm', () async {
      final api = _Api()..server = {'ten': ['Nguyễn Văn A', 'Trần Thị B']};
      final store = FormSuggestStore(api);
      expect(await store.load(9), {'ten': ['Nguyễn Văn A', 'Trần Thị B']});

      api.server = null; // mất mạng
      await store.remember(9, {'ten': '  Lê Văn C ', 'khac': 'x'}, {'ten'});
      expect(await store.load(9), {'ten': ['Lê Văn C', 'Nguyễn Văn A', 'Trần Thị B']});

      api.server = {'ten': ['lê văn c', 'Nguyễn Văn A']}; // phiếu đã đồng bộ
      expect(await store.load(9), {'ten': ['lê văn c', 'Nguyễn Văn A']});
      api.server = null;
      expect(await store.load(9), {'ten': ['lê văn c', 'Nguyễn Văn A']}, reason: 'giá trị đã lên server rời nhóm máy');
    });

    test('cached() đọc bản lưu NGAY, không gọi mạng', () async {
      final api = _Api()..server = {'ten': ['A']};
      final store = FormSuggestStore(api);
      await store.load(9);
      api.calls = 0;
      expect(await store.cached(9), {'ten': ['A']});
      expect(api.calls, 0);
    });

    test('fillFor: câu trả lời của giá trị đã chọn (so không phân biệt hoa thường), mất mạng vẫn đọc bản lưu', () async {
      final api = _Api()
        ..server = {'ten': ['NPP Một']}
        ..fills = {
          'ten': {
            'NPP Một': {'ten': 'NPP Một', 'sdt': '0909', 'toa_do': {'lat': 21.0, 'lng': 105.0}},
          },
        };
      final store = FormSuggestStore(api);
      await store.load(9);
      api.server = null; // mất mạng
      expect(await store.fillFor(9, 'ten', 'npp một'), {'ten': 'NPP Một', 'sdt': '0909', 'toa_do': {'lat': 21.0, 'lng': 105.0}});
      expect(await store.fillFor(9, 'ten', 'NPP Khác'), isNull);
      expect(await store.fillFor(9, 'o_khac', 'NPP Một'), isNull);
      expect(await store.fillFor(8, 'ten', 'NPP Một'), isNull, reason: 'biểu mẫu khác');
    });

    test('chưa rõ tài khoản ⇒ không đọc/ghi gì', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FormSuggestStore(_Api()..server = {'ten': ['A']});
      expect(await store.load(9), isEmpty);
    });

    test('chỉ ô text bật cờ mới có gợi ý', () {
      MarketFormBlockEntity o(String code, String type, Map<String, dynamic> cfg) => MarketFormBlockEntity(
            ref: code,
            type: 'field',
            required: false,
            resolved: MarketFormResolvedEntity(code: code, label: code, inputType: type, config: cfg),
          );
      expect(
        FormSuggestStore.enabledCodes([
          o('a', 'text', {'suggest_from_history': true}),
          o('b', 'textarea', {'suggest_from_history': true}),
          o('c', 'text', {}),
        ]),
        {'a'},
      );
    });
  });

  testWidgets('ô gợi ý: trống không hiện; gõ không dấu ⇒ hiện giá trị khớp; chạm ⇒ điền vào ô và câu trả lời', (tester) async {
    const block = MarketFormBlockEntity(
      ref: 'ten',
      type: 'field',
      required: true,
      resolved: MarketFormResolvedEntity(
        code: 'ten',
        label: 'Tên ứng viên NPP',
        inputType: 'text',
        config: {'suggest_from_history': true},
      ),
    );
    fakeInterFonts();
    final key = GlobalKey<MarketFormRendererState>();
    final daChon = <String>[];
    Widget app(Map<String, List<String>> goiY) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: const [block],
                suggestions: goiY,
                onSuggestionSelected: (code, value) => daChon.add('$code=$value'),
              ),
            ),
          ),
        );
    // Gợi ý chưa về (mạng chậm): gõ trước, gợi ý về sau ⇒ ô KHÔNG bị dựng lại (giữ focus + chữ đang gõ).
    await tester.pumpWidget(app(const {}));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), ' ');
    await tester.pumpWidget(app(const {'ten': ['Nguyễn Văn An', 'Trần Thị Bình', 'Nguyễn Thị Cúc']}));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue, reason: 'gợi ý về muộn không làm mất focus');
    expect(find.byKey(const ValueKey('suggest_ten')), findsNothing, reason: 'chỉ dấu cách = chưa gõ gì');

    await tester.enterText(find.byType(TextFormField), 'nguyen');
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Nguyễn Thị Cúc'), findsOneWidget);
    expect(find.text('Trần Thị Bình'), findsNothing);

    expect(daChon, isEmpty, reason: 'gõ tay không phải chọn gợi ý');
    await tester.tap(find.text('Nguyễn Thị Cúc'));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndGetAnswers(), containsPair('ten', 'Nguyễn Thị Cúc'));
    expect(daChon, ['ten=Nguyễn Thị Cúc'], reason: 'chạm gợi ý ⇒ báo màn chứa để tự điền cả phiếu');
  });

  group('nháp phiếu thu thập', () {
    test('ngăn theo tài khoản, không đụng ngăn lượt viếng thăm', () async {
      await FormDraftStore.save(
        visitId: 5,
        clientUuid: 'u5',
        configId: 7,
        answers: {'ghi_chu': 'khảo sát'},
        photoMemo: {},
      );
      final a = FormDraftStore.collectSlot('42');
      await FormDraftStore.save(
        visitId: FormDraftStore.collectVisitId,
        clientUuid: FormDraftStore.collectUuid,
        configId: 7,
        answers: {'ten': 'Nguyễn Văn A'},
        photoMemo: {},
        slotKey: a,
      );
      Future<Map<String, dynamic>?> thuThap(String slot) async => (await FormDraftStore.load(
            visitId: FormDraftStore.collectVisitId,
            clientUuid: FormDraftStore.collectUuid,
            configId: 7,
            slotKey: slot,
          ))
              ?.answers;

      expect(await thuThap(a), {'ten': 'Nguyễn Văn A'});
      expect(await thuThap(FormDraftStore.collectSlot('99')), isNull, reason: 'tài khoản khác không thấy');
      expect((await FormDraftStore.load(visitId: 5, clientUuid: 'u5', configId: 7))?.answers, {'ghi_chu': 'khảo sát'});

      // Kết thúc lượt viếng thăm không xoá nháp thu thập; nộp phiếu thu thập thì xoá đúng nháp đó.
      await FormDraftStore.clearVisit(visitId: 5, clientUuid: 'u5');
      expect(await thuThap(a), {'ten': 'Nguyễn Văn A'});
      await FormDraftStore.remove(
        visitId: FormDraftStore.collectVisitId,
        clientUuid: FormDraftStore.collectUuid,
        configId: 7,
        slotKey: a,
      );
      expect(await thuThap(a), isNull);
    });

    test('đăng xuất (clearAccountDrafts) xoá ngăn thu thập + ảnh nháp, giữ ngăn lượt viếng thăm', () async {
      final cam = Directory('${docs.path}/cam')..createSync();
      final anh = File('${cam.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      final a = FormDraftStore.collectSlot('42');
      await FormDraftStore.save(
        visitId: FormDraftStore.collectVisitId,
        clientUuid: FormDraftStore.collectUuid,
        configId: 7,
        answers: {'anh': [anh.path]},
        photoMemo: {},
        slotKey: a,
      );
      await FormDraftStore.save(visitId: 5, clientUuid: 'u5', configId: 7, answers: {'x': 'y'}, photoMemo: {});
      final draftDir = Directory('${docs.path}/${FormDraftStore.photoDir}');
      expect(draftDir.listSync(), isNotEmpty);

      await FormDraftStore.clearAccountDrafts();
      expect((await SharedPreferences.getInstance()).getString(a), isNull);
      expect(draftDir.listSync(), isEmpty, reason: 'ảnh nháp thu thập phải xoá theo');
      expect((await FormDraftStore.load(visitId: 5, clientUuid: 'u5', configId: 7))?.answers, {'x': 'y'});
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';

/// #25390: check-in bị 422 DMS_VISIT_STILL_OPEN ⇒ app khớp ĐÚNG lượt server chỉ ra (`data.open_visit_id` /
/// `open_visit_client_uuid`) trong danh sách lượt còn mở, không đoán; server cũ (không có `data`) ⇒ không khớp gì.
class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic>? stillOpenData;
  final List<Map<String, dynamic>> openVisits;
  int openListCalls = 0;
  _Adapter({this.stillOpenData, this.openVisits = const []});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final (int, Object) r;
    if (o.method == 'POST' && o.path.endsWith('/dms/visits')) {
      r = (422, {
        'success': false,
        'code': 'DMS_VISIT_STILL_OPEN',
        'message': 'Bạn còn một lượt viếng thăm chưa check-out.',
        if (stillOpenData != null) 'data': stillOpenData,
      });
    } else if (o.path.contains('/dms/visits/mine')) {
      openListCalls++;
      r = (200, {'success': true, 'data': openVisits});
    } else {
      r = (200, {'success': true, 'data': <String, dynamic>{}});
    }
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _visit(int id, String uuid, String name) => {
      'id': id,
      'client_uuid': uuid,
      'customer_id': id + 1000,
      'customer_name': name,
      'checkin_at': DateTime.now().toIso8601String(),
      'status': 'open',
    };

Future<(Object, VisitRepositoryImpl)> _checkinError(_Adapter adapter) async {
  final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio()..httpClientAdapter = adapter)));
  try {
    await repo.checkin(CheckinRequestModel(customerId: 1, clientUuid: 'moi'));
  } catch (e) {
    return (e, repo);
  }
  fail('check-in phải bị từ chối');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final open = [_visit(76, 'v-76', 'Điểm A'), _visit(77, 'v-77', 'Điểm B')];

  test('422 mang data ⇒ ngoại lệ giữ data, khớp đúng lượt theo id', () async {
    final adapter = _Adapter(stillOpenData: {'open_visit_id': 77, 'open_visit_client_uuid': null}, openVisits: open);
    final (e, repo) = await _checkinError(adapter);
    expect(e, isA<AppException>());
    expect((e as AppException).data?['open_visit_id'], 77);
    final v = await findBlockingOpenVisit(repo, e);
    expect(v?.id, 77);
    expect(v?.customerName, 'Điểm B');
  });

  test('khớp theo client_uuid khi không có id', () async {
    final adapter = _Adapter(stillOpenData: {'open_visit_client_uuid': 'v-76'}, openVisits: open);
    final (e, repo) = await _checkinError(adapter);
    expect((await findBlockingOpenVisit(repo, e))?.id, 76);
  });

  test('server cũ (không có data) ⇒ null, không gọi danh sách lượt mở', () async {
    final adapter = _Adapter(openVisits: open);
    final (e, repo) = await _checkinError(adapter);
    expect(await findBlockingOpenVisit(repo, e), isNull);
    expect(adapter.openListCalls, 0);
  });

  test('lượt server chỉ ra không còn trong danh sách mở ⇒ null (không đoán lượt khác)', () async {
    final adapter = _Adapter(stillOpenData: {'open_visit_id': 99, 'open_visit_client_uuid': 'v-99'}, openVisits: open);
    final (e, repo) = await _checkinError(adapter);
    expect(await findBlockingOpenVisit(repo, e), isNull);
  });

  test('mã lỗi khác ⇒ null', () async {
    final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio())));
    const e = ServerException('x', 422, 'OTHER', null, {'open_visit_id': 77});
    expect(await findBlockingOpenVisit(repo, e), isNull);
  });
}

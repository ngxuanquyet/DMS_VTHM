import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/models/error_record.dart';
import 'package:vthm_dms/core/services/error_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorTrackerService Tests', () {
    test('1. generateErrorId sinh mã lỗi đúng chuẩn ERR-[MODULE]-[STATUS]-[HEX]', () {
      final service = ErrorTrackerService.instance;
      final id1 = service.generateErrorId('VISIT', 422);
      expect(id1, startsWith('ERR-VISIT-422-'));
      expect(id1.length, equals(18)); // ERR-VISIT-422-XXXX (18 ký tự)

      final id2 = service.generateErrorId('AUTH', 403);
      expect(id2, startsWith('ERR-AUTH-403-'));

      final id3 = service.generateErrorId('NET', null);
      expect(id3, startsWith('ERR-NET-000-'));
    });

    test('2. detectModule nhận diện đúng phân hệ từ URL path và DioExceptionType', () {
      final service = ErrorTrackerService.instance;

      expect(service.detectModule('/auth/login'), equals('AUTH'));
      expect(service.detectModule('/auth/refresh'), equals('AUTH'));
      expect(service.detectModule('/dms/visits/123/checkout'), equals('VISIT'));
      expect(service.detectModule('/crm/customer/form-schema'), equals('CUST'));
      expect(service.detectModule('/attendance/mobile/punches'), equals('ATTEND'));
      expect(service.detectModule('/dms/location/ping'), equals('LOC'));
      expect(service.detectModule('/unknown/path'), equals('SYS'));

      // Timeout hoặc lỗi mạng
      expect(
        service.detectModule('/any/path', dioType: DioExceptionType.connectionTimeout),
        equals('NET'),
      );
      expect(
        service.detectModule(null, dioType: DioExceptionType.receiveTimeout),
        equals('NET'),
      );
    });

    test('2b. accountLabelFromJson ghép tên tài khoản kèm mã cho tin báo lỗi', () {
      expect(
        ErrorTrackerService.accountLabelFromJson(
            '{"display_name":"Nguyễn Văn A","username":"vtg926","employee_code":"VTG926"}'),
        equals('Nguyễn Văn A (TK: vtg926, mã NV: VTG926)'),
      );
      // Hồ sơ kiểu cũ chỉ có khoá legacy
      expect(
        ErrorTrackerService.accountLabelFromJson('{"name":"Trần B","employeeId":"VPL12"}'),
        equals('Trần B (mã NV: VPL12)'),
      );
      expect(ErrorTrackerService.accountLabelFromJson('{"username":"partner1"}'), equals('TK: partner1'));
      expect(ErrorTrackerService.accountLabelFromJson(null), isNull);
      expect(ErrorTrackerService.accountLabelFromJson('{}'), isNull);
      expect(ErrorTrackerService.accountLabelFromJson('không phải json'), isNull);
    });

    test('3. AppException đính kèm errorId và format userMessage chính xác', () {
      const ex1 = AppException('Lỗi nghiệp vụ', 422, 'VALIDATION_ERROR', 'ERR-VISIT-422-A1B2');
      expect(ex1.errorId, equals('ERR-VISIT-422-A1B2'));
      expect(ex1.userMessage, equals('Lỗi nghiệp vụ\n(Mã lỗi: ERR-VISIT-422-A1B2)'));
      expect(ex1.toString(), contains('(Mã lỗi: ERR-VISIT-422-A1B2)'));

      const forbidden = DmsAppForbiddenException('Tài khoản chưa có quyền', 'ERR-AUTH-403-F9E0');
      expect(forbidden.errorId, equals('ERR-AUTH-403-F9E0'));
      expect(forbidden.statusCode, equals(403));
      expect(forbidden.code, equals('DMS_APP_FORBIDDEN'));
      expect(forbidden.userMessage, contains('(Mã lỗi: ERR-AUTH-403-F9E0)'));

      const netEx = NetworkException('Mất mạng', 'ERR-NET-000-7C3D');
      expect(netEx.errorId, equals('ERR-NET-000-7C3D'));
    });

    test('4. toUploadJson khớp form máy chủ, không gửi tên/TK và toạ độ', () {
      final record = ErrorRecord(
        id: 'ERR-VISIT-422-TEST',
        timestamp: DateTime(2026, 10, 15, 16, 30, 0),
        module: 'VISIT',
        statusCode: 422,
        serverCode: 'VALIDATION_ERROR',
        message: 'Bạn cần ở lại thêm 5 phút nữa mới check-out được.',
        endpoint: 'https://api-app.vthmgroup.vn/dms/visits/135808/checkout',
        method: 'POST',
        requestData: {'client_uuid': 'uuid-123'},
        responseData: {'errors': {'seconds_remaining': [300]}},
        curlCommand: "curl -X POST 'https://api-app.vthmgroup.vn/dms/visits/135808/checkout'",
        username: 'VTG920',
        deviceInfo: 'Android 14',
        lat: 21.028,
        lng: 105.834,
      );

      final json = ErrorTrackerService.toUploadJson(record);

      // Khoá đúng tên `ClientErrorReportForm::toRows()` đọc.
      for (final k in ['id', 'timestamp', 'module', 'statusCode', 'serverCode', 'message', 'endpoint', 'method',
        'requestData', 'responseData', 'curlCommand', 'deviceInfo', 'appVersion']) {
        expect(json.containsKey(k), isTrue, reason: k);
      }
      expect(json['id'], equals('ERR-VISIT-422-TEST'));
      expect(json['statusCode'], equals(422));
      // Người gặp lỗi lấy từ phiên đăng nhập phía máy chủ; toạ độ là dữ liệu nhạy cảm — không gửi.
      expect(json.containsKey('username'), isFalse);
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lng'), isFalse);
    });

    test('4b. shouldUpload bỏ 401/404 và lỗi của chính lời gọi gửi lỗi', () {
      ErrorRecord r(int? status, String endpoint) =>
          ErrorRecord(id: 'X', timestamp: DateTime(2026), module: 'SYS', statusCode: status, message: 'm', endpoint: endpoint);

      expect(ErrorTrackerService.shouldUpload(r(500, 'https://api-app.vthmgroup.vn/dms/visits')), isTrue);
      expect(ErrorTrackerService.shouldUpload(r(null, '')), isTrue);
      expect(ErrorTrackerService.shouldUpload(r(401, 'https://api-app.vthmgroup.vn/dms/visits')), isFalse);
      expect(ErrorTrackerService.shouldUpload(r(404, 'https://api-app.vthmgroup.vn/dms/visits')), isFalse);
      expect(ErrorTrackerService.shouldUpload(r(500, 'https://api-app.vthmgroup.vn/dms/client-errors')), isFalse);
    });

    test('4c. isQueuedFor chỉ gửi lỗi của chính người đăng nhập (hoặc lỗi trước đăng nhập)', () {
      ErrorRecord r(String? owner, {bool sent = false}) => ErrorRecord(
          id: 'X', timestamp: DateTime(2026), module: 'SYS', message: 'm', ownerAccountKey: owner, sentToServer: sent);

      expect(ErrorTrackerService.isQueuedFor(r('12'), '12'), isTrue);
      expect(ErrorTrackerService.isQueuedFor(r(null), '12'), isTrue);
      // Máy dùng chung: lỗi của tài khoản 7 không được gửi dưới phiên của 12.
      expect(ErrorTrackerService.isQueuedFor(r('7'), '12'), isFalse);
      expect(ErrorTrackerService.isQueuedFor(r('12', sent: true), '12'), isFalse);
    });

    test('4d. bản ghi của app cũ (chưa có sentToServer) coi như đã gửi', () {
      final legacy = ErrorRecord.fromJson({'id': 'ERR-OLD', 'message': 'm', 'sentToTelegram': true});
      expect(legacy.sentToServer, isTrue);
    });

    test('5. trackDioError tự động che giấu mật khẩu và token nhạy cảm', () {
      final service = ErrorTrackerService.instance;
      final requestOptions = RequestOptions(
        path: '/auth/login',
        method: 'POST',
        data: {
          'username': 'VTG920',
          'password': 'SuperSecretPassword123!',
          'token': 'secret_token',
        },
        headers: {
          'Authorization': 'Bearer my_access_token_123',
        },
      );

      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'message': 'Tài khoản không hợp lệ'},
        ),
      );

      final record = service.trackDioError(dioError, currentUsername: 'VTG920');

      expect(record.module, equals('AUTH'));
      expect(record.statusCode, equals(400));
      expect(record.id, startsWith('ERR-AUTH-400-'));

      // Kiểm tra dữ liệu data đã bị mask
      final maskedReq = record.requestData as Map;
      expect(maskedReq['password'], equals('******'));
      expect(maskedReq['token'], equals('******'));
      expect(maskedReq['username'], equals('VTG920'));

      // Kiểm tra cURL không chứa password thật
      expect(record.curlCommand, isNot(contains('SuperSecretPassword123!')));
      expect(record.curlCommand, contains('******'));
      expect(record.curlCommand, contains('<masked_token>'));
    });
  });
}

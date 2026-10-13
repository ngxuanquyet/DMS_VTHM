import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/app_notification_service.dart';
import 'package:vthm_dms/features/employee_tracking/data/datasources/employee_tracking_api_service.dart';
import 'package:vthm_dms/features/employee_tracking/data/datasources/employee_tracking_local_storage.dart';
import 'package:vthm_dms/features/employee_tracking/data/models/location_access_log_model.dart';
import 'package:vthm_dms/features/employee_tracking/data/models/location_pending_request_model.dart';
import 'package:vthm_dms/features/employee_tracking/data/models/location_ping_point_model.dart';
import 'package:vthm_dms/features/employee_tracking/data/models/location_ping_response_model.dart';
import 'package:vthm_dms/features/employee_tracking/domain/entities/employee_tracking_state.dart';
import 'package:vthm_dms/features/employee_tracking/presentation/screens/location_access_log_screen.dart';
import 'package:vthm_dms/features/employee_tracking/presentation/services/employee_tracking_service.dart';
import 'package:vthm_dms/features/employee_tracking/presentation/widgets/location_sharing_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Employee Tracking Spec Tests (API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md)', () {
    test('§2 LocationPingPointModel serializes to required JSON structure', () {
      final point = LocationPingPointModel(
        lat: 21.0285,
        lng: 105.8542,
        accuracyM: 12.5,
        isMockLocation: false,
        batteryPct: 76,
        source: 'auto',
        clientTime: '2026-10-09T10:00:00+07:00',
        clientUuid: '11111111-1111-4111-8111-111111111111',
        appVersion: '1.4.0',
      );

      final json = point.toJson();
      expect(json['lat'], 21.0285);
      expect(json['lng'], 105.8542);
      expect(json['accuracy_m'], 12.5);
      expect(json['is_mock_location'], false);
      expect(json['battery_pct'], 76);
      expect(json['source'], 'auto');
      expect(json['client_time'], '2026-10-09T10:00:00+07:00');
      expect(json['client_uuid'], '11111111-1111-4111-8111-111111111111');
      expect(json['app_version'], '1.4.0');
    });

    test('§2 LocationPingPointModel for requested source includes request_id', () {
      final point = LocationPingPointModel.create(
        lat: 20.998,
        lng: 105.821,
        source: 'requested',
        requestId: 42,
        customUuid: '22222222-2222-4222-8222-222222222222',
      );

      final json = point.toJson();
      expect(json['source'], 'requested');
      expect(json['request_id'], 42);
      expect(json['client_uuid'], '22222222-2222-4222-8222-222222222222');
    });

    test('§2 LocationPingResponseModel parses real sample response', () {
      const jsonStr = '''
      {
        "success": true,
        "message": "Đã nhận vị trí.",
        "data": {
          "saved": 2,
          "duplicated": 0,
          "answered_request_id": null,
          "next_interval_sec": 180,
          "pending_request": null
        }
      }
      ''';

      final model = LocationPingResponseModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(model.success, isTrue);
      expect(model.saved, 2);
      expect(model.duplicated, 0);
      expect(model.answeredRequestId, isNull);
      expect(model.nextIntervalSec, 180);
      expect(model.pendingRequest, isNull);
    });

    test('§3 LocationPendingResponseModel parses real pending response with pending_request', () {
      const jsonStr = '''
      {
        "success": true,
        "data": {
          "enabled": true,
          "next_interval_sec": 300,
          "pending_request": {
            "id": 1,
            "requested_by": "Nguyễn Văn A",
            "requested_at": "2026-10-09 16:39:11+07",
            "expires_at": "2026-10-09 16:49:11+07",
            "status": "delivered",
            "status_label": "App đã nhận, chưa có vị trí",
            "is_open": true,
            "reason": "Kiểm tra tuyến sáng nay"
          }
        }
      }
      ''';

      final model = LocationPendingResponseModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(model.success, isTrue);
      expect(model.enabled, isTrue);
      expect(model.nextIntervalSec, 300);
      expect(model.pendingRequest, isNotNull);
      expect(model.pendingRequest!.id, 1);
      expect(model.pendingRequest!.requestedBy, 'Nguyễn Văn A');
      expect(model.pendingRequest!.reason, 'Kiểm tra tuyến sáng nay');
      expect(model.pendingRequest!.status, 'delivered');
    });

    test('§3 LocationPendingRequestModel handles expiry check properly', () {
      final req = LocationPendingRequestModel(
        id: 1,
        requestedBy: 'Trưởng nhóm',
        requestedAt: '2026-10-09T10:00:00Z',
        expiresAt: '2026-10-09T10:10:00Z',
        status: 'pending',
        statusLabel: 'Chờ',
      );

      final beforeExpiry = DateTime.parse('2026-10-09T10:05:00Z');
      final afterExpiry = DateTime.parse('2026-10-09T10:15:00Z');

      expect(req.isExpired(beforeExpiry), isFalse);
      expect(req.isExpired(afterExpiry), isTrue);
    });

    test('§4 EmployeeTrackingLocalStorage enqueues, deduplicates by UUID, and batches up to 200', () async {
      final storage = EmployeeTrackingLocalStorage();

      final p1 = LocationPingPointModel.create(lat: 21.0, lng: 105.0, customUuid: 'uuid-1');
      final p2 = LocationPingPointModel.create(lat: 21.1, lng: 105.1, customUuid: 'uuid-2');
      final p1Duplicate = LocationPingPointModel.create(lat: 21.0, lng: 105.0, customUuid: 'uuid-1');

      await storage.enqueuePoints([p1, p2, p1Duplicate]);

      final all = await storage.getAllPoints();
      expect(all.length, 2);
      expect(all.map((e) => e.clientUuid).toSet(), {'uuid-1', 'uuid-2'});

      // Remove uuid-1 after successful send
      await storage.removeByClientUuids(['uuid-1']);
      final remaining = await storage.getAllPoints();
      expect(remaining.length, 1);
      expect(remaining.first.clientUuid, 'uuid-2');

      await storage.clearQueue();
      expect(await storage.getPendingCount(), 0);
    });

    test('§5 LocationAccessLogResponseModel parses real access log data', () {
      const jsonStr = '''
      {
        "success": true,
        "data": [
          {
            "id": 1,
            "requested_by_name": "Nguyễn Văn A",
            "requested_at": "2026-10-09 16:39:11+07",
            "status": "answered",
            "status_label": "Đã có vị trí",
            "reason": "Kiểm tra tuyến sáng nay",
            "answered_ping_id": 3
          }
        ],
        "meta": { "total": 1, "currentPage": 1, "pageSize": 20, "pageCount": 1 }
      }
      ''';

      final res = LocationAccessLogResponseModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(res.success, isTrue);
      expect(res.items.length, 1);
      expect(res.items.first.requestedByName, 'Nguyễn Văn A');
      expect(res.items.first.status, 'answered');
      expect(res.items.first.answeredPingId, 3);
      expect(res.meta.total, 1);
    });

    test('EmployeeTrackingState computes isSharing accurately', () {
      const state1 = EmployeeTrackingState(
        isEnabledByServer: true,
        isPermissionGranted: true,
        isFeatureBlockedByRule: false,
        isPermissionForbidden: false,
      );
      expect(state1.isSharing, isTrue);

      const state2 = EmployeeTrackingState(
        isEnabledByServer: true,
        isPermissionGranted: false, // User denied permission
      );
      expect(state2.isSharing, isFalse);

      const state3 = EmployeeTrackingState(
        isEnabledByServer: true,
        isPermissionGranted: true,
        isFeatureBlockedByRule: true, // 422 LOCATION_RULE received
      );
      expect(state3.isSharing, isFalse);

      const state4 = EmployeeTrackingState(
        isEnabledByServer: true,
        isPermissionGranted: true,
        isPermissionForbidden: true, // 403 received
      );
      expect(state4.isSharing, isFalse);
    });
  });

  group('LocationSharingBadge & Access Log Widget Tests', () {
    testWidgets('LocationSharingBadge renders active state when isSharing = true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeTrackingProvider.overrideWith((ref) => FakeTrackingNotifier(
              const EmployeeTrackingState(
                isEnabledByServer: true,
                isPermissionGranted: true,
                nextIntervalSec: 180,
              ),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LocationSharingBadge(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(LocationSharingBadge), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
    });

    testWidgets('LocationSharingBadge opens bottom sheet on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeTrackingProvider.overrideWith((ref) => FakeTrackingNotifier(
              const EmployeeTrackingState(
                isEnabledByServer: true,
                isPermissionGranted: true,
                nextIntervalSec: 180,
                pendingPointsCount: 0,
              ),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LocationSharingBadge(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(LocationSharingBadge));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Theo dõi vị trí nhân viên'), findsOneWidget);
      expect(find.text('180 giây (server điều khiển)'), findsOneWidget);
      expect(find.text('AI ĐÃ XEM VỊ TRÍ CỦA TÔI'), findsOneWidget);
    });

    testWidgets('LocationAccessLogScreen displays access log cards without Law 91/2025 banner', (tester) async {
      final mockApiService = MockEmployeeTrackingApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeTrackingApiServiceProvider.overrideWithValue(mockApiService),
          ],
          child: const MaterialApp(
            home: LocationAccessLogScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Nhật ký xem vị trí'), findsOneWidget);
      expect(find.text('Quyền riêng tư & Luật BVDLCN 91/2025'), findsNothing);
      expect(find.text('Lê Quản Lý'), findsOneWidget);
      expect(find.text('Lý do: Kiểm tra tuyến đột xuất'), findsOneWidget);
      expect(find.text('Đã có vị trí'), findsOneWidget);
      expect(find.text('Mã bản ghi toạ độ: #99'), findsOneWidget);
    });
  });

  group('EmployeeTrackingApiService Error Classification Tests (§1 & §2)', () {
    test('Throws LocationPermissionDeniedException on HTTP 403', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 403),
          ));
        },
      ));

      final api = EmployeeTrackingApiService(dio);
      expect(
        () => api.getPendingRequest(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('Throws LocationTrackingDisabledException on HTTP 422 LOCATION_RULE', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 422,
              data: {
                'code': 'LOCATION_RULE',
                'message': 'Tính năng theo dõi vị trí đang tắt.',
              },
            ),
          ));
        },
      ));

      final api = EmployeeTrackingApiService(dio);
      expect(
        () => api.pingLocations([
          LocationPingPointModel.create(lat: 21.0, lng: 105.0),
        ]),
        throwsA(isA<LocationTrackingDisabledException>()),
      );
    });

    test('Throws LocationValidationException on HTTP 422 VALIDATION_ERROR', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 422,
              data: {
                'code': 'VALIDATION_ERROR',
                'message': 'Tọa độ không hợp lệ',
              },
            ),
          ));
        },
      ));

      final api = EmployeeTrackingApiService(dio);
      expect(
        () => api.pingLocations([
          LocationPingPointModel.create(lat: 21.0, lng: 105.0),
        ]),
        throwsA(isA<LocationValidationException>()),
      );
    });
  });
}

class MockEmployeeTrackingApiService extends EmployeeTrackingApiService {
  MockEmployeeTrackingApiService() : super(Dio());

  @override
  Future<LocationAccessLogResponseModel> getMyAccessLog({int page = 1, int perPage = 20}) async {
    return const LocationAccessLogResponseModel(
      success: true,
      items: [
        LocationAccessLogItemModel(
          id: 1,
          requestedByName: 'Lê Quản Lý',
          requestedAt: '2026-10-12 09:30:00+07',
          status: 'answered',
          statusLabel: 'Đã có vị trí',
          reason: 'Kiểm tra tuyến đột xuất',
          answeredPingId: 99,
        ),
      ],
      meta: LocationAccessLogPaginationMeta(
        total: 1,
        currentPage: 1,
        pageSize: 20,
        pageCount: 1,
      ),
    );
  }
}

class FakeTrackingNotifier extends EmployeeTrackingNotifier {
  FakeTrackingNotifier(EmployeeTrackingState initialState)
      : super(
          apiService: EmployeeTrackingApiService(Dio()),
          storage: EmployeeTrackingLocalStorage(),
          notifService: AppNotificationService(),
        ) {
    state = initialState;
  }
}

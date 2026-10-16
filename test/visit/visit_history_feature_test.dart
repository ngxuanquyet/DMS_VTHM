import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';
import 'package:vthm_dms/features/visit/presentation/widgets/customer_visit_history_widget.dart';

class MockGetCustomerVisitHistoryUseCase implements GetCustomerVisitHistoryUseCase {
  final Future<CustomerVisitHistoryResponse> Function(int customerId, {int page, int perPage}) handler;
  MockGetCustomerVisitHistoryUseCase(this.handler);

  @override
  Future<CustomerVisitHistoryResponse> call(int customerId, {int page = 1, int perPage = 20}) =>
      handler(customerId, page: page, perPage: perPage);
}

class MockGetCustomerVisitHistoryDetailUseCase implements GetCustomerVisitHistoryDetailUseCase {
  final Future<VisitHistoryDetailEntity> Function(int customerId, int visitId) handler;
  MockGetCustomerVisitHistoryDetailUseCase(this.handler);

  @override
  Future<VisitHistoryDetailEntity> call(int customerId, int visitId) => handler(customerId, visitId);
}

void main() {
  group('SPEC 16/10/2026 Customer Visit History Entities Test', () {
    test('1. VisitHistoryItemEntity parses JSON correctly and formats duration', () {
      final json = {
        'id': 1001,
        'visit_date': '2026-10-16',
        'checkin_at': '2026-10-16 08:30:00+07',
        'checkout_at': '2026-10-16 08:45:15+07',
        'duration_seconds': 915,
        'user_id': 20,
        'employee_name': 'Nguyễn Văn A',
        'customer_id': 5378,
        'customer_code': 'DB-001',
        'customer_name': 'Đại lý Minh Phát',
        'visit_result': 'visited',
        'visit_result_label': 'Điểm bán mở cửa',
        'visit_result_color': 'success',
        'closed_note': null,
        'note': 'Gặp chủ tiệm trao đổi CTKM',
        'is_first_visit': true,
        'photo_count': 2,
        'form_count': 1,
      };

      final item = VisitHistoryItemEntity.fromJson(json);

      expect(item.id, equals(1001));
      expect(item.employeeName, equals('Nguyễn Văn A'));
      expect(item.customerId, equals(5378));
      expect(item.customerCode, equals('DB-001'));
      expect(item.customerName, equals('Đại lý Minh Phát'));
      expect(item.isFirstVisit, isTrue);
      expect(item.isClosedStore, isFalse);
      expect(item.isOpen, isFalse);
      expect(item.formattedDuration, equals('15 phút 15 giây'));
      expect(item.photoCount, equals(2));
      expect(item.formCount, equals(1));

      // Test short duration (< 60s)
      final shortDurationItem = VisitHistoryItemEntity.fromJson({
        ...json,
        'duration_seconds': 45,
      });
      expect(shortDurationItem.formattedDuration, equals('45 giây'));

      // Test open visit (no checkout)
      final openItem = VisitHistoryItemEntity.fromJson({
        ...json,
        'checkout_at': null,
        'duration_seconds': null,
      });
      expect(openItem.isOpen, isTrue);
      expect(openItem.formattedDuration, equals('Đang mở'));

      // Roundtrip toJson
      final map = item.toJson();
      expect(map['id'], equals(1001));
      expect(map['customer_code'], equals('DB-001'));
    });

    test('2. VisitHistoryDetailEntity & URL formatting for §11.5', () {
      final detailJson = {
        'id': 1002,
        'visit_date': '2026-10-16',
        'checkin_at': '2026-10-16 09:00:00+07',
        'checkout_at': '2026-10-16 09:10:00+07',
        'duration_seconds': 600,
        'employee_name': 'Trần Văn B',
        'customer_id': 5378,
        'customer_name': 'Cửa hàng Hoa Sen',
        'visit_result': 'closed',
        'visit_result_label': 'Điểm bán đóng cửa',
        'visit_result_color': 'warning',
        'closed_note': 'Cửa hàng nghỉ trưa sớm',
        'photo_urls': [
          'https://mobiwork.cdn.vn/photos/photo1.jpg',
          '/dms/visit-photos/public/photo2.jpg',
          'dms/visit-photos/public/photo3.jpg',
        ],
        'forms': [
          {
            'id': 501,
            'form_id': 12,
            'form_name': 'Khảo sát trưng bày',
            'kind': 'survey',
            'submitted_at': '2026-10-16 09:05:00+07',
            'answers': {
              'q_posm': 'Có tủ trưng bày',
              'q_stock': 25,
            },
            'form_schemaSnapshot': null,
          }
        ],
      };

      final detail = VisitHistoryDetailEntity.fromJson(detailJson);
      expect(detail.item.id, equals(1002));
      expect(detail.item.isClosedStore, isTrue);
      expect(detail.item.closedNote, equals('Cửa hàng nghỉ trưa sớm'));
      expect(detail.forms.length, equals(1));
      expect(detail.forms.first.formName, equals('Khảo sát trưng bày'));
      expect(detail.forms.first.answers['q_posm'], equals('Có tủ trưng bày'));

      // Verify §11.5 URL resolution
      final fullUrls = detail.fullPhotoUrls;
      expect(fullUrls.length, equals(3));
      expect(fullUrls[0], equals('https://mobiwork.cdn.vn/photos/photo1.jpg'));
      expect(fullUrls[1], equals('${AppConstants.baseUrl}/dms/visit-photos/public/photo2.jpg'));
      expect(fullUrls[2], equals('${AppConstants.baseUrl}/dms/visit-photos/public/photo3.jpg'));
    });

    test('3. CustomerVisitHistoryResponse parses pagination meta and data list', () {
      final listJson = {
        'success': true,
        'data': [
          {
            'id': 101,
            'customer_id': 5378,
            'employee_name': 'NV 1',
            'visit_date': '2026-10-15',
            'duration_seconds': 300,
            'visit_result': 'visited',
          },
          {
            'id': 102,
            'customer_id': 5378,
            'employee_name': 'NV 2',
            'visit_date': '2026-10-16',
            'duration_seconds': 450,
            'visit_result': 'visited',
          }
        ],
        'meta': {
          'total': 2,
          'currentPage': 1,
          'pageSize': 20,
          'pageCount': 1,
          'date_from': '2026-10-01',
          'date_to': '2026-10-16',
        }
      };

      final response = CustomerVisitHistoryResponse.fromJson(listJson);
      expect(response.total, equals(2));
      expect(response.currentPage, equals(1));
      expect(response.pageSize, equals(20));
      expect(response.items.length, equals(2));
      expect(response.items.first.id, equals(101));
      expect(response.items.last.id, equals(102));
    });
  });

  group('CustomerVisitHistoryWidget Tests', () {
    testWidgets('Renders empty state when no visit history exists', (tester) async {
      final container = ProviderContainer(
        overrides: [
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(items: [], total: 0),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CustomerVisitHistoryWidget(customerId: 5378),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lịch sử viếng thăm'), findsOneWidget);
      expect(find.text('Chưa có lượt viếng thăm nào trong 2 tháng gần đây'), findsOneWidget);
    });

    testWidgets('Renders visit history items and opens detail sheet when tapped', (tester) async {
      const mockItem = VisitHistoryItemEntity(
        id: 1001,
        visitDate: '2026-10-16',
        checkinAt: '2026-10-16 08:30:00+07',
        checkoutAt: '2026-10-16 08:45:00+07',
        durationSeconds: 900,
        employeeName: 'Nguyễn Văn Sales',
        customerId: 5378,
        customerName: 'Tạp hóa Bác Ba',
        visitResult: 'visited',
        visitResultLabel: 'Điểm bán mở cửa',
        visitResultColor: 'success',
        photoCount: 1,
        formCount: 1,
      );

      final container = ProviderContainer(
        overrides: [
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(
                items: [mockItem],
                total: 1,
              ),
            ),
          ),
          getCustomerVisitHistoryDetailUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryDetailUseCase(
              (customerId, visitId) async => const VisitHistoryDetailEntity(
                item: mockItem,
                photoUrls: [],
                forms: [
                  VisitHistoryFormEntity(
                    id: 1,
                    formId: 10,
                    formName: 'Đánh giá trưng bày',
                    answers: {'Hàng hóa': 'Đầy đủ'},
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CustomerVisitHistoryWidget(customerId: 5378),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lịch sử viếng thăm'), findsOneWidget);
      expect(find.text('Nguyễn Văn Sales'), findsOneWidget);
      expect(find.text('Điểm bán mở cửa'), findsOneWidget);
      expect(find.text('15 phút 0 giây'), findsOneWidget);
      expect(find.text('1 ảnh'), findsOneWidget);
      expect(find.text('1 phiếu'), findsOneWidget);

      // Tap on item to open VisitHistoryDetailSheet
      await tester.tap(find.text('Nguyễn Văn Sales'));
      await tester.pumpAndSettle();

      // Verify sheet is displayed
      expect(find.text('Chi tiết lượt viếng thăm'), findsOneWidget);
      expect(find.text('Tạp hóa Bác Ba'), findsWidgets);
      expect(find.text('Đánh giá trưng bày'), findsOneWidget);
      expect(find.text('Hàng hóa'), findsOneWidget);
      expect(find.text('Đầy đủ'), findsOneWidget);
    });

    testWidgets('Displays notes and closed reasons both in list preview and detail sheet', (tester) async {
      const mockItemWithNote = VisitHistoryItemEntity(
        id: 1002,
        visitDate: '2026-10-16',
        checkinAt: '2026-10-16 10:00:00+07',
        checkoutAt: '2026-10-16 10:20:00+07',
        durationSeconds: 1200,
        employeeName: 'Lê Văn Sales',
        customerId: 5378,
        customerName: 'Đại lý Thành Công',
        visitResult: 'visited',
        visitResultLabel: 'Điểm bán mở cửa',
        visitResultColor: 'success',
        note: 'Chủ tiệm đồng ý nhập thêm 10 thùng nước ngọt',
      );

      final container = ProviderContainer(
        overrides: [
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(
                items: [mockItemWithNote],
                total: 1,
              ),
            ),
          ),
          getCustomerVisitHistoryDetailUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryDetailUseCase(
              (customerId, visitId) async => const VisitHistoryDetailEntity(
                item: mockItemWithNote,
                photoUrls: [],
                forms: [],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CustomerVisitHistoryWidget(customerId: 5378),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify list preview shows note
      expect(find.text('Ghi chú: Chủ tiệm đồng ý nhập thêm 10 thùng nước ngọt'), findsOneWidget);

      // Tap on item to open sheet
      await tester.tap(find.text('Lê Văn Sales'));
      await tester.pumpAndSettle();

      // Verify detail sheet shows notes section
      expect(find.text('Ghi chú chuyến ghé'), findsOneWidget);
      expect(find.text('Ghi chú của NVBH:'), findsOneWidget);
      expect(find.text('Chủ tiệm đồng ý nhập thêm 10 thùng nước ngọt'), findsOneWidget);
    });
  });
}


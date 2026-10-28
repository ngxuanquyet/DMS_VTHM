import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/presentation/screens/rejected_customers_screen.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_circular_menu.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/route/presentation/widgets/route_circular_menu.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/rejected_read_status_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRouteApiService extends Fake implements RouteApiService {
  @override
  Future<List<UserRouteEntity>> getMyRoutes({bool forceRefresh = false}) async => [];
}

class MockCustomerRepository extends Fake implements CustomerRepository {
  final List<CustomerEntity> customers;
  MockCustomerRepository(this.customers);

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async => customers;

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async => [];

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async =>
      const CustomerMetaData();
}

class MockVisitRepository extends Fake implements VisitRepository {
  final List<VisitEntity> visits;
  MockVisitRepository(this.visits);

  @override
  Future<List<VisitEntity>> getAllLocalVisits() async => visits;

  @override
  Future<List<VisitEntity>> getTodayVisits() async => visits;

  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async =>
      visits;
}

void main() {
  group('RejectedCustomersScreen Tests', () {
    const rejectedCustomer = CustomerEntity(
      id: 89187,
      code: '08650170',
      name: 'Đại lý Thành Hậu (Từ chối)',
      type: 'Đại lý',
      route: 'Tuyến số 1',
      address: '123 Đường ABC, Hà Nội',
      contactPerson: 'Anh Hậu',
      phone: '0988112233',
      approvalStatus: 'rejected',
      approvalLabel: 'Bị từ chối',
      approvalColor: 'danger',
      approvalNote: 'Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ',
      approvalAt: '2026-10-15 16:47:49.039594+07',
    );

    const normalCustomer = CustomerEntity(
      id: 89188,
      code: '08650171',
      name: 'Đại lý Mai Linh (Hợp lệ)',
      type: 'Đại lý',
      route: 'Tuyến số 1',
      address: '456 Đường XYZ, Hà Nội',
      contactPerson: 'Chị Linh',
      phone: '0988445566',
      approvalStatus: 'approved',
      approvalLabel: 'Đã duyệt',
    );

    final attachedVisit = VisitEntity(
      id: 42169,
      customerId: 89187,
      customerCode: '08650170',
      customerName: 'Đại lý Thành Hậu (Từ chối)',
      customerAddress: '123 Đường ABC, Hà Nội',
      customerApprovalStatus: 'rejected',
      checkinAt: DateTime(2026, 10, 15, 8, 30),
      checkoutAt: DateTime(2026, 10, 15, 9, 0),
      durationSeconds: 1800,
      visitResult: 'visited',
      photoCount: 4,
      formCount: 2,
    );

    testWidgets('1. Renders rejected customer and its attached visits together in 1 card',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockCustRepo = MockCustomerRepository([rejectedCustomer]);
      final mockVisitRepo = MockVisitRepository([attachedVisit]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockCustRepo),
            routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
            visitRepositoryProvider.overrideWithValue(mockVisitRepo),
          ],
          child: const MaterialApp(
            home: RejectedCustomersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('Điểm bán bị từ chối'), findsOneWidget);

      // Kiểm tra thông tin điểm bán
      expect(find.text('Đại lý Thành Hậu (Từ chối)'), findsOneWidget);
      expect(find.text('08650170'), findsOneWidget);
      expect(find.text('Bị từ chối'), findsWidgets);

      // Kiểm tra hộp lý do từ chối
      expect(
        find.text('Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ'),
        findsOneWidget,
      );

      // Kiểm tra khối lượt viếng thăm đi kèm ở ngay bên dưới (không tách màn)
      expect(find.textContaining('LƯỢT VIẾNG THĂM ĐI KÈM (1)'), findsOneWidget);
      expect(find.text('Chưa tính KPI'), findsNothing);
      expect(find.text('4 ảnh'), findsOneWidget);
      expect(find.text('2 biểu mẫu'), findsOneWidget);
      expect(find.text('30 phút'), findsOneWidget);

      // Kiểm tra các nút hành động cho điểm bán (không cho phép sửa lại điểm bán bị từ chối)
      expect(find.text('Sửa điểm bán'), findsNothing);
      expect(find.text('Xem chi tiết điểm bán'), findsOneWidget);
    });

    testWidgets('2. Displays empty state when there are no rejected customers',
        (tester) async {
      const approvedCustomer = CustomerEntity(
        id: 101,
        code: 'KH101',
        name: 'Đại lý Đã Duyệt',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Địa chỉ 1',
        contactPerson: 'A',
        phone: '0901',
        approvalStatus: 'approved',
      );

      final mockCustRepo = MockCustomerRepository([approvedCustomer]);
      final mockVisitRepo = MockVisitRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockCustRepo),
            routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
            visitRepositoryProvider.overrideWithValue(mockVisitRepo),
          ],
          child: const MaterialApp(
            home: RejectedCustomersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Không có điểm bán bị từ chối'), findsOneWidget);
      expect(
        find.text('Tuyệt vời! Hiện tại bạn không có điểm bán hoặc lượt viếng thăm nào bị từ chối phê duyệt.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Filters rejected list using search query', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockCustRepo = MockCustomerRepository([rejectedCustomer]);
      final mockVisitRepo = MockVisitRepository([attachedVisit]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockCustRepo),
            routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
            visitRepositoryProvider.overrideWithValue(mockVisitRepo),
          ],
          child: const MaterialApp(
            home: RejectedCustomersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Đại lý Thành Hậu (Từ chối)'), findsOneWidget);

      // Gõ từ khoá không khớp
      await tester.enterText(find.byType(TextField), 'TuKhoaKhongTonTai123');
      await tester.pumpAndSettle();

      expect(find.text('Đại lý Thành Hậu (Từ chối)'), findsNothing);
      expect(find.text('Không tìm thấy kết quả phù hợp'), findsOneWidget);

      // Gõ từ khoá khớp với lý do từ chối
      await tester.enterText(find.byType(TextField), 'Trùng với điểm bán');
      await tester.pumpAndSettle();

      expect(find.text('Đại lý Thành Hậu (Từ chối)'), findsOneWidget);
    });

    testWidgets('4. CustomerCircularMenu displays rejected item and triggers onOpenRejected', (WidgetTester tester) async {
      bool openedRejected = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CustomerCircularMenu(
                      onAddCustomer: () {},
                      onSync: () {},
                      onSendOfflineData: () {},
                      onRefreshGps: () {},
                      onSortByDistance: () {},
                      onOpenRejected: () {
                        openedRejected = true;
                      },
                      rejectedCount: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Main FAB has badge with 3
      expect(find.text('3'), findsOneWidget);

      // Tap main FAB to open circular radial menu
      await tester.tap(find.byIcon(Icons.widgets_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check that the rejected menu item is visible
      expect(find.text('Bị từ chối (3)'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      // Tap the rejected menu item
      await tester.tap(find.text('Bị từ chối (3)'));
      await tester.pumpAndSettle();

      expect(openedRejected, isTrue);
    });

    test('5. filteredCustomersProvider and CustomerState exclude rejected customers from customer list', () async {
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(
            MockCustomerRepository([rejectedCustomer, normalCustomer]),
          ),
          routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
        ],
      );
      addTearDown(container.dispose);

      // Load customers
      await container.read(customerViewModelProvider.notifier).loadCustomers();

      final state = container.read(customerViewModelProvider);
      // allCustomers retains all (for rejected count)
      expect(state.allCustomers.length, 2);
      // but totalCount excludes rejected customer
      expect(state.totalCount, 1);
      // rejectedCount has 1
      expect(state.rejectedCount, 1);

      // filteredCustomersProvider excludes rejected customers
      final filtered = container.read(filteredCustomersProvider);
      expect(filtered.length, 1);
      expect(filtered.first.customer.id, normalCustomer.id);
      expect(filtered.any((c) => c.customer.id == rejectedCustomer.id), isFalse);
    });

    test('6. RouteViewModel excludes rejected customers from routeDetail and dealer counts', () async {
      final db = AppDatabase(NativeDatabase.memory(), 1);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          customerRepositoryProvider.overrideWithValue(
            MockCustomerRepository([rejectedCustomer, normalCustomer]),
          ),
          routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
          visitRepositoryProvider.overrideWithValue(MockVisitRepository([])),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final routeVm = container.read(routeViewModelProvider.notifier);
      await routeVm.loadRouteDetail();

      final routeState = container.read(routeViewModelProvider);
      // Total dealers in routeDetail should only contain normalCustomer
      expect(routeState.routeDetail?.totalDealers, 1);
      expect(routeState.routeDetail?.dealers.length, 1);
      expect(routeState.routeDetail?.dealers.first.code, normalCustomer.code);
      expect(routeState.routeDetail?.dealers.any((d) => d.code == rejectedCustomer.code), isFalse);

      // getDealerCountForDay should exclude rejectedCustomer
      expect(routeVm.getDealerCountForDay(null), 1);
    });

    testWidgets('7. RouteCircularMenu displays rejected item and triggers onOpenRejected', (WidgetTester tester) async {
      bool openedRejected = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: RouteCircularMenu(
                      onSortByDistance: () {},
                      onSync: () {},
                      onSendOfflineData: () {},
                      onAddCustomer: () {},
                      onRefreshGps: () {},
                      onOpenRejected: () {
                        openedRejected = true;
                      },
                      hasUnreadRejected: true,
                      rejectedCount: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open circular radial menu
      await tester.tap(find.byIcon(Icons.widgets_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check that the rejected menu item is visible
      expect(find.text('Bị từ chối (2)'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      // Tap the rejected menu item
      await tester.tap(find.text('Bị từ chối (2)'));
      await tester.pumpAndSettle();

      expect(openedRejected, isTrue);
    });

    testWidgets('8. Notification red dot shows when unread and clears when entering RejectedCustomersScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(
            MockCustomerRepository([rejectedCustomer]),
          ),
          routeApiServiceProvider.overrideWithValue(MockRouteApiService()),
          visitRepositoryProvider.overrideWithValue(MockVisitRepository([])),
        ],
      );
      addTearDown(container.dispose);

      // Load customers in CustomerViewModel
      await container.read(customerViewModelProvider.notifier).loadCustomers();

      // Initial state: 1 unread rejected customer
      expect(container.read(unreadRejectedCountProvider), 1);
      expect(container.read(hasUnreadRejectedProvider), isTrue);

      // Verify RouteCircularMenu renders red dot on FAB when unread
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: RouteCircularMenu(
                      onSortByDistance: () {},
                      onSync: () {},
                      onSendOfflineData: () {},
                      onAddCustomer: () {},
                      onRefreshGps: () {},
                      onOpenRejected: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check red dot is rendered: Container with red color (0xFFDC2626) and width 10 (dot)
      final redDotFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == const Color(0xFFDC2626) &&
            widget.constraints?.minWidth == 10,
      );
      expect(redDotFinder, findsOneWidget);

      // Now navigate to / open RejectedCustomersScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RejectedCustomersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Once RejectedCustomersScreen is visited, customer should be marked as read!
      expect(container.read(unreadRejectedCountProvider), 0);
      expect(container.read(hasUnreadRejectedProvider), isFalse);

      // Return to Route screen with RouteCircularMenu
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: RouteCircularMenu(
                      onSortByDistance: () {},
                      onSync: () {},
                      onSendOfflineData: () {},
                      onAddCustomer: () {},
                      onRefreshGps: () {},
                      onOpenRejected: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Now the red dot on RouteCircularMenu should be gone!
      expect(redDotFinder, findsNothing);
    });
  });
}


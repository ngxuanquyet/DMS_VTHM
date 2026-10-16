import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/presentation/screens/customer_detail_screen.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

class FakeRouteApiService extends Fake implements RouteApiService {
  @override
  Future<List<UserRouteEntity>> getMyRoutes({bool forceRefresh = false}) async => [];
}

class MockGetCustomerVisitHistoryUseCase implements GetCustomerVisitHistoryUseCase {
  final Future<CustomerVisitHistoryResponse> Function(int customerId, {int page, int perPage}) handler;
  MockGetCustomerVisitHistoryUseCase(this.handler);

  @override
  Future<CustomerVisitHistoryResponse> call(int customerId, {int page = 1, int perPage = 20}) =>
      handler(customerId, page: page, perPage: perPage);
}

class MockCustomerRepository implements CustomerRepository {
  final CustomerEntity mockCustomer;

  MockCustomerRepository(this.mockCustomer);

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async => [mockCustomer];

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async => [
        const CustomerDynamicColumn(
          code: 'ma_so_thue',
          label: 'Mã số thuế doanh nghiệp',
          inputType: 'text',
          source: 'own',
        ),
      ];

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async =>
      CustomerMetaData(
        dynamicColumns: [
          const CustomerDynamicColumn(
            code: 'ma_so_thue',
            label: 'Mã số thuế doanh nghiệp',
            inputType: 'text',
            source: 'own',
          ),
        ],
      );

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async => mockCustomer;

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async => mockCustomer;

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async => mockCustomer;

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => {};

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(
    String filePath, {
    String? locationName,
    double? lat,
    double? lng,
  }) async => {};

  @override
  Future<bool> deleteCustomer(int id) async => true;

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async => true;
}

void main() {
  testWidgets('CustomerDetailScreen renders customer identity, photo carousel, contact, and action buttons', (tester) async {
    const testCustomer = CustomerEntity(
      id: 999,
      code: 'KH00999',
      name: 'Tạp Hóa Hương Sen',
      type: 'Đại lý cấp 1',
      channelName: 'Kênh GT',
      route: 'Tuyến Bắc Từ Liêm',
      address: 'Số 123 Đường Cầu Diễn, Bắc Từ Liêm, Hà Nội',
      wardName: 'Phúc Diễn',
      provinceName: 'Hà Nội',
      contactPerson: 'Bà Nguyễn Thị Hương',
      contactTitle: 'Chủ tiệm',
      phone: '0988776655',
      email: 'huongsen@gmail.com',
      lat: 21.0456,
      lng: 105.7654,
      geofenceRadiusM: 60,
      photoUrl: '/crm/customer-photos/public/token_a',
      photoUrls: [
        '/crm/customer-photos/public/token_a',
        '/crm/customer-photos/public/token_b',
      ],
      dynamicFields: {
        'ma_so_thue': '0101234567',
        'loai_bien_hieu': 'Biển bạt Hiflex',
      },
    );

    final mockRepo = MockCustomerRepository(testCustomer);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(mockRepo),
          routeApiServiceProvider.overrideWithValue(FakeRouteApiService()),
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(items: [], total: 0),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customer: testCustomer),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Customer Name
    expect(find.text('Chi tiết điểm bán'), findsOneWidget);
    expect(find.text('Tạp Hóa Hương Sen'), findsOneWidget);

    // Verify Code & Badges
    expect(find.text('KH00999'), findsOneWidget);
    expect(find.text('Đại lý cấp 1'), findsOneWidget);
    expect(find.text('Kênh GT'), findsAtLeastNWidgets(1));
    expect(find.text('Tuyến Bắc Từ Liêm'), findsAtLeastNWidgets(1));

    // Verify Photo count pill (2 ảnh)
    expect(find.text('1/2 ảnh'), findsOneWidget);
    expect(find.text('Ảnh đại diện'), findsOneWidget);

    // Verify Contact Info
    expect(find.text('Bà Nguyễn Thị Hương'), findsOneWidget);
    expect(find.text('0988776655'), findsOneWidget);
    expect(find.text('huongsen@gmail.com'), findsOneWidget);

    // Verify Address & Goong Map (bán kính và text "Đã ghim vị trí" đã được bỏ, thay bằng Goong Map với các chế độ xem)
    expect(find.text('Số 123 Đường Cầu Diễn, Bắc Từ Liêm, Hà Nội'), findsOneWidget);
    expect(find.text('Phúc Diễn'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('Đã ghim vị trí'), findsNothing);
    expect(find.textContaining('Bán kính:'), findsNothing);
    expect(find.text('Đường phố'), findsOneWidget);
    expect(find.text('Vệ tinh'), findsOneWidget);
    expect(find.text('Giao thông'), findsOneWidget);

    // Verify Dynamic fields
    expect(find.text('0101234567'), findsOneWidget);
    expect(find.text('Mã số thuế doanh nghiệp'), findsOneWidget);
    expect(find.text('Biển bạt Hiflex'), findsOneWidget);

    // Verify Action buttons in Bottom Bar (Calls and Directions only, edit buttons removed)
    expect(find.text('Gọi điện'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byTooltip('Chỉnh sửa điểm bán'), findsNothing);
    expect(find.byTooltip('Sửa thông tin'), findsNothing);
  });

  testWidgets('CustomerDetailScreen displays region name instead of raw ID in Quản trị & Tuyến bán hàng', (tester) async {
    const customerWithRegion = CustomerEntity(
      id: 888,
      code: '08290619',
      name: 'test0810',
      type: 'Đại lý',
      route: 'Chưa phân tuyến',
      channelName: 'MB1',
      regionId: 3,
      regionName: '03 - Phú Thọ',
      address: 'Phú Thọ',
      contactPerson: 'Chưa cập nhật',
      phone: 'Chưa có SĐT',
      lat: 21.39507,
      lng: 105.59340,
    );

    final mockRepo = MockCustomerRepository(customerWithRegion);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(mockRepo),
          routeApiServiceProvider.overrideWithValue(FakeRouteApiService()),
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(items: [], total: 0),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customer: customerWithRegion),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Phải hiển thị nhãn "Khu vực" và tên "03 - Phú Thọ"
    expect(find.text('Khu vực'), findsOneWidget);
    expect(find.text('03 - Phú Thọ'), findsOneWidget);

    // 2. TUYỆT ĐỐI không hiển thị "Khu vực (Region ID)" hoặc "#3"
    expect(find.text('Khu vực (Region ID)'), findsNothing);
    expect(find.text('#3'), findsNothing);
  });

  testWidgets('CustomerDetailScreen resolves route name from userAssignedRoutesProvider when routeIds is present', (tester) async {
    const customerWithRouteId = CustomerEntity(
      id: 777,
      code: 'KH00777',
      name: 'Đại lý Kim Quy',
      type: 'Đại lý',
      route: 'Chưa phân tuyến',
      routes: [],
      routeIds: [12],
      channelName: 'GT',
      address: 'Số 10 Phố Huế, Hà Nội',
      contactPerson: 'Bác Tư',
      phone: '0912345678',
      lat: 21.0123,
      lng: 105.8500,
    );

    final mockRepo = MockCustomerRepository(customerWithRouteId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(mockRepo),
          routeApiServiceProvider.overrideWithValue(
            FakeRouteApiService(),
          ),
          userAssignedRoutesProvider.overrideWith(
            (ref) async => [
              const UserRouteEntity(
                id: 12,
                name: 'Tuyến Hoàn Kiếm - Thứ 2',
                code: 'HK-T2',
                visitDayOfWeek: 2,
              ),
            ],
          ),
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(items: [], total: 0),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customer: customerWithRouteId),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tuyến bán hàng displays resolved name instead of 'Chưa phân tuyến'
    expect(find.text('Tuyến Hoàn Kiếm - Thứ 2'), findsAtLeastNWidgets(1));
    expect(find.text('Chưa phân tuyến'), findsNothing);
  });

  testWidgets('CustomerDetailScreen displays creator and last updater in audit card', (tester) async {
    const customerWithAudit = CustomerEntity(
      id: 501,
      code: 'KH00501',
      name: 'Đại Lý Tiến Phát',
      type: 'Đại lý',
      route: 'Tuyến 1',
      address: '100 Giải Phóng, Hà Nội',
      contactPerson: 'Nguyễn Tiến',
      phone: '0901234567',
      createdByName: 'Nguyễn Văn Admin (VTG001)',
      updatedByName: 'Trần Thị Quản Lý (VTG002)',
      createdAt: '2026-10-01T08:30:00Z',
      updatedAt: '2026-10-15T14:20:00Z',
    );

    final mockRepo = MockCustomerRepository(customerWithAudit);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(mockRepo),
          routeApiServiceProvider.overrideWithValue(FakeRouteApiService()),
          getCustomerVisitHistoryUseCaseProvider.overrideWithValue(
            MockGetCustomerVisitHistoryUseCase(
              (customerId, {page = 1, perPage = 20}) async =>
                  const CustomerVisitHistoryResponse(items: [], total: 0),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customer: customerWithAudit),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trạng thái & Lịch sử chỉnh sửa'), findsOneWidget);
    expect(find.text('Người tạo'), findsOneWidget);
    expect(find.text('Nguyễn Văn Admin (VTG001)'), findsOneWidget);
    expect(find.text('Người cập nhật lần cuối'), findsOneWidget);
    expect(find.text('Trần Thị Quản Lý (VTG002)'), findsOneWidget);
  });
}


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

class FakeRouteApiService extends Fake implements RouteApiService {
  @override
  Future<List<UserRouteEntity>> getMyRoutes() async => [];
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
  }) async => mockCustomer;

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async => mockCustomer;

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async => mockCustomer;

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => {};

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) async => {};

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

    // Verify Address & GPS
    expect(find.text('Số 123 Đường Cầu Diễn, Bắc Từ Liêm, Hà Nội'), findsOneWidget);
    expect(find.text('Phúc Diễn'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('21.04560, 105.76540'), findsOneWidget);
    expect(find.text('Bán kính: 60m'), findsOneWidget);

    // Verify Dynamic fields
    expect(find.text('0101234567'), findsOneWidget);
    expect(find.text('Mã số thuế doanh nghiệp'), findsOneWidget);
    expect(find.text('Biển bạt Hiflex'), findsOneWidget);

    // Verify Action buttons in Bottom Bar
    expect(find.text('Gọi điện'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
  });
}

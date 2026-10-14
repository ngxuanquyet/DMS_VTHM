import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/map/app_map_location_card.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/presentation/screens/edit_customer_screen.dart';

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
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async => [];

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async =>
      const CustomerMetaData();

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async => mockCustomer;

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async => mockCustomer;

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async => mockCustomer;

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(
    String filePath, {
    String? locationName,
    double? lat,
    double? lng,
  }) async =>
      {'token': 'test_token'};

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => {};

  @override
  Future<bool> deleteCustomer(int id) async => true;

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async => true;
}

void main() {
  const dummyCustomer = CustomerEntity(
    id: 101,
    code: 'VTHM-001',
    name: 'Đại lý Tạp Hóa Minh Anh',
    type: 'Đại lý cấp 1',
    route: 'Tuyến Đống Đa',
    address: '123 Đường Láng, Đống Đa, Hà Nội',
    phone: '0987654321',
    contactPerson: 'Nguyễn Văn Minh',
    lat: 21.012345,
    lng: 105.812345,
    geofenceRadiusM: 100,
  );

  testWidgets('EditCustomerScreen renders as independent screen with map and no geofence/coords text', (tester) async {
    final mockRepo = MockCustomerRepository(dummyCustomer);

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
        ],
        child: const MaterialApp(
          home: EditCustomerScreen(
            customer: dummyCustomer,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Phải là màn hình riêng biệt có AppBar "Sửa thông tin điểm bán"
    expect(find.text('Sửa thông tin điểm bán'), findsOneWidget);
    expect(find.text('VTHM-001 • Đại lý Tạp Hóa Minh Anh'), findsOneWidget);

    // 2. Phải có AppMapLocationCard
    expect(find.byType(AppMapLocationCard), findsOneWidget);

    // 3. Không được hiển thị chuỗi text thông số tọa độ kinh/vĩ độ dạng chữ
    expect(find.textContaining('Tọa độ:'), findsNothing);

    // 4. Bán kính geofence bị loại bỏ khỏi giao diện, nhân viên không được can thiệp
    expect(find.textContaining('Bán kính Geofence'), findsNothing);
    expect(find.textContaining('geofence_radius_m'), findsNothing);

    // 5. Phải có nút hành động cập nhật thông tin điểm bán
    expect(find.text('CẬP NHẬT THÔNG TIN ĐIỂM BÁN'), findsOneWidget);
  });

  testWidgets('EditCustomerScreen filters technical keys from dynamic fields and renders route & photos properly', (tester) async {
    const customerWithLeakedData = CustomerEntity(
      id: 202,
      code: '08290619',
      name: 'test0810',
      type: 'Đại lý',
      route: 'TEST-QUYETNX',
      routes: ['TEST-QUYETNX'],
      routeIds: [1],
      address: 'Phú Thọ',
      phone: '0981112233',
      contactPerson: 'Nguyễn Văn Quyết',
      photoUrl: '/crm/customer-photos/public/53e96e0b',
      photoUrls: ['/crm/customer-photos/public/53e96e0b'],
      dynamicFields: {
        'Vinlux': 'Vinlux VIP',
        'routes': ['TEST-QUYETNX'],
        'route_ids': [1],
        'photo_url': '/crm/customer-photos/public/53e96e0b',
        'photo_urls': ['/crm/customer-photos/public/53e96e0b'],
      },
    );

    final mockRepo = MockCustomerRepository(customerWithLeakedData);

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
        ],
        child: const MaterialApp(
          home: EditCustomerScreen(
            customer: customerWithLeakedData,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Phải có dropdown Tuyến bán hàng và hiển thị đúng tuyến hiện tại TEST-QUYETNX
    expect(find.text('Tuyến bán hàng'), findsOneWidget);
    expect(find.text('TEST-QUYETNX'), findsOneWidget);

    // 2. Trường thông tin mở rộng chỉ hiển thị Vinlux, TUYỆT ĐỐI không hiển thị các trường hệ thống
    expect(find.text('Vinlux'), findsOneWidget);
    expect(find.text('routes'), findsNothing);
    expect(find.text('route_ids'), findsNothing);
    expect(find.text('photo_url'), findsNothing);
    expect(find.text('photo_urls'), findsNothing);
    expect(find.text('[TEST-QUYETNX]'), findsNothing);
    expect(find.text('[1]'), findsNothing);

    // 3. Phần hình ảnh hiển thị đúng ảnh và nhãn Đại diện, cùng nút Thêm ảnh inline
    expect(find.text('Đại diện'), findsOneWidget);
    expect(find.text('Thêm ảnh'), findsWidgets);
  });

  testWidgets('EditCustomerScreen renders select dynamic fields as Dropdown and filters region_name', (tester) async {
    const customerWithSelectFields = CustomerEntity(
      id: 303,
      code: '08430113',
      name: 'Đại Thắng',
      type: 'Đại lý',
      route: 'Tuyến Đà Nẵng',
      address: 'Đà Nẵng',
      phone: '0905123456',
      contactPerson: 'Đại Thắng',
      dynamicFields: {
        'khach_hang_vthm': '1 - KH VTHM',
        'nhan_1': '',
        'nhan_2': '',
        'nhan_3': 'Maximos',
        'region_name': 'Thành phố Đà Nẵng',
      },
    );

    final mockRepo = MockCustomerRepository(customerWithSelectFields);

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
        ],
        child: const MaterialApp(
          home: EditCustomerScreen(
            customer: customerWithSelectFields,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. region_name TUYỆT ĐỐI không xuất hiện ở mục trường thông tin mở rộng
    expect(find.text('region_name'), findsNothing);

    // 2. Các trường select được hiển thị kèm badge "Danh sách chọn"
    expect(find.text('Khách hàng VTHM'), findsOneWidget);
    expect(find.text('Nhãn 1'), findsOneWidget);
    expect(find.text('Nhãn 2'), findsOneWidget);
    expect(find.text('Nhãn 3'), findsOneWidget);
    expect(find.text('Danh sách chọn'), findsWidgets);

    // 3. Giá trị hiện tại được chọn sẵn trong Dropdown
    expect(find.text('1 - KH VTHM'), findsOneWidget);
    expect(find.text('Maximos'), findsOneWidget);
    expect(find.text('(Chưa chọn)'), findsWidgets); // cho nhãn 1 và nhãn 2
  });
}


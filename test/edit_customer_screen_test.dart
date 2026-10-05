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
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) async =>
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
}

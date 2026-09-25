import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:drift/native.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

void main() {
  group('API Điểm bán (22/09/2026) Spec Tests', () {
    test('DynamicFormField.fromJson parses max_files from schema correctly', () {
      final json = {
        'kind': 'dynamic',
        'code': 'anh_mat_tien',
        'label': 'Ảnh mặt tiền',
        'input_type': 'image',
        'required': true,
        'read_only': false,
        'max_files': 3,
      };

      final field = DynamicFormField.fromJson(json);
      expect(field.code, 'anh_mat_tien');
      expect(field.type, DynamicFormFieldType.photo);
      expect(field.maxPhotos, 3);
      expect(field.isRequired, true);
      expect(field.kind, 'dynamic');
    });

    test('DynamicFormField.fromJson parses photo_file_id with max 10 correctly', () {
      final json = {
        'code': 'photo_file_id',
        'label': 'Ảnh điểm bán',
        'input_type': 'image',
        'max': 10,
        'required': false,
        'read_only': false,
      };

      final field = DynamicFormField.fromJson(json);
      expect(field.code, 'photo_file_id');
      expect(field.type, DynamicFormFieldType.photo);
      expect(field.maxPhotos, 10);
      expect(field.section, 'Hình ảnh điểm bán');
    });

    test('kDefaultCustomerFormSchema includes photo_file_id with maxPhotos 10', () {
      final fieldsJson = (kDefaultCustomerFormSchema['data'] as Map)['fields'] as List;
      final photoFieldJson = fieldsJson.cast<dynamic>().firstWhere(
        (f) => f['code'] == 'photo_file_id',
        orElse: () => null,
      );
      expect(photoFieldJson, isNotNull);
      final field = DynamicFormField.fromJson(photoFieldJson as Map<String, dynamic>);
      expect(field.code, 'photo_file_id');
      expect(field.type, DynamicFormFieldType.photo);
      expect(field.maxPhotos, 10);
    });

    test('createCustomerOffline conforms strictly to spec: no code, no status, has route_ids [int], photo_token, and data map', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      final inputData = {
        'name': 'Cửa hàng VLXD Minh Tâm',
        'region_id': 12,
        'route_ids': [5],
        'phone': '0912345678',
        'address': '12 Trần Phú, Hải Châu, Đà Nẵng',
        'lat': '16.0678',
        'lng': '108.2208',
        'photo_token': '9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b',
        // Client might pass status or code by accident
        'status': 'active',
        'code': 'SHOULD_NOT_BE_SENT',
        // Dynamic fields
        'so_ke_hang': 4,
        'anh_mat_tien': ['9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b'],
      };

      final entity = await dataSource.createCustomerOffline(inputData);
      expect(entity.name, 'Cửa hàng VLXD Minh Tâm');

      // Check the payload enqueued in sync_queue
      final entries = await db.select(db.syncQueueEntries).get();
      expect(entries.length, 1);
      final enqueuedPayload = jsonDecode(entries.first.payload) as Map<String, dynamic>;

      // 1. MUST NOT have 'code' (causes 422)
      expect(enqueuedPayload.containsKey('code'), isFalse);

      // 2. MUST NOT have 'status' (server defaults to active, causes 422 if sent)
      expect(enqueuedPayload.containsKey('status'), isFalse);

      // 3. MUST have 'route_ids' as a List of ints
      expect(enqueuedPayload['route_ids'], [5]);
      expect(enqueuedPayload['route_ids'], isA<List>());

      // 4. MUST have 'photo_token' at top level
      expect(enqueuedPayload['photo_token'], '9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b');

      // 5. MUST place dynamic fields inside 'data' map
      expect(enqueuedPayload['data'], isA<Map<String, dynamic>>());
      final dataMap = enqueuedPayload['data'] as Map<String, dynamic>;
      expect(dataMap['so_ke_hang'], 4);
      expect(dataMap['anh_mat_tien'], ['9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b']);

      await db.close();
    });

    test('createCustomerOffline handles route_id single int and wraps into route_ids list', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      final inputData = {
        'name': 'Đại lý An Nhiên',
        'region_id': 8,
        'route_id': 3,
      };

      await dataSource.createCustomerOffline(inputData);
      final entries = await db.select(db.syncQueueEntries).get();
      final enqueuedPayload = jsonDecode(entries.first.payload) as Map<String, dynamic>;

      expect(enqueuedPayload['route_ids'], [3]);
      expect(enqueuedPayload.containsKey('code'), isFalse);
      expect(enqueuedPayload.containsKey('status'), isFalse);

      await db.close();
    });

    test('UserRouteEntity parses real GET /dms/routes/mine cURL response correctly', () {
      final curlJson = {
        'success': true,
        'data': [
          {
            'id': 5,
            'code': 'Vũ Tùng Dương - T2',
            'name': 'Vũ Tùng Dương - T2',
            'visit_day_of_week': 1,
            'sale_group_id': 12
          },
          {
            'id': 7,
            'code': 'Vũ Tùng Dương - T3',
            'name': 'Vũ Tùng Dương - T3',
            'visit_day_of_week': 2,
            'sale_group_id': 12
          }
        ],
        'message': 'Thành công'
      };

      final list = curlJson['data'] as List;
      final routes = list.map((e) => UserRouteEntity.fromJson(e as Map<String, dynamic>)).toList();
      expect(routes.length, 2);
      expect(routes[0].id, 5);
      expect(routes[0].name, 'Vũ Tùng Dương - T2');
      expect(routes[0].code, 'Vũ Tùng Dương - T2');
      expect(routes[0].visitDayOfWeek, 1);
      expect(routes[0].dayOfWeekName, 'Thứ 2');
      expect(routes[0].saleGroupId, 12);
      expect(routes[0].isActive, isTrue);

      expect(routes[1].id, 7);
      expect(routes[1].name, 'Vũ Tùng Dương - T3');
      expect(routes[1].visitDayOfWeek, 2);
      expect(routes[1].dayOfWeekName, 'Thứ 3');
      expect(routes[1].saleGroupId, 12);
      expect(routes[1].isActive, isTrue);

      // Verify mapping to DynamicFormOption for AddCustomerScreen
      final options = routes.map((r) => DynamicFormOption(
        label: r.name.isNotEmpty ? r.name : (r.code ?? 'Tuyến ${r.id}'),
        value: r.id,
      )).toList();
      expect(options.length, 2);
      expect(options[0].label, 'Vũ Tùng Dương - T2');
      expect(options[0].value, 5);
      expect(options[1].label, 'Vũ Tùng Dương - T3');
      expect(options[1].value, 7);
    });

    testWidgets('DynamicFormBuilder preserves user input across rebuilds and isSubmitting toggles', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          isRequired: true,
        ),
        const DynamicFormField(
          code: 'phone',
          label: 'Số điện thoại',
          type: DynamicFormFieldType.text,
        ),
      ];

      final formKey = GlobalKey<DynamicFormBuilderState>();

      // A test parent widget that can trigger setState and toggle isSubmitting
      late StateSetter parentSetState;
      bool isSubmitting = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return DynamicFormBuilder(
                  key: formKey,
                  fields: fields,
                  isSubmitting: isSubmitting,
                  initialData: const {'route_ids': 5},
                );
              },
            ),
          ),
        ),
      );

      // Verify TextField rendered
      final nameFinder = find.byType(TextField).first;
      expect(nameFinder, findsOneWidget);

      // Enter text into 'name' field
      await tester.enterText(nameFinder, 'Đại lý Bia Nước Ngọt Thành Đạt');
      await tester.pump();

      expect(formKey.currentState!.getFormData()['name'], 'Đại lý Bia Nước Ngọt Thành Đạt');

      // Simulate submit triggering parent rebuild: isSubmitting = true
      parentSetState(() {
        isSubmitting = true;
      });
      await tester.pump();

      // Form data MUST NOT be cleared
      expect(formKey.currentState!.getFormData()['name'], 'Đại lý Bia Nước Ngọt Thành Đạt');
      expect(find.text('Đại lý Bia Nước Ngọt Thành Đạt'), findsOneWidget);

      // Simulate submit error returning: isSubmitting = false
      parentSetState(() {
        isSubmitting = false;
      });
      await tester.pump();

      // Form data MUST STILL BE INTACT
      expect(formKey.currentState!.getFormData()['name'], 'Đại lý Bia Nước Ngọt Thành Đạt');
      expect(find.text('Đại lý Bia Nước Ngọt Thành Đạt'), findsOneWidget);
    });

    test('Safe conversion of route_ids to List<int> without type cast exception', () {
      List<int> parseRouteIds(dynamic raw) {
        List<int> ids = [];
        if (raw is List) {
          ids = raw.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
        } else if (raw != null) {
          final parsed = int.tryParse(raw.toString());
          if (parsed != null) ids = [parsed];
        }
        if (ids.isEmpty) {
          ids = [5];
        }
        return ids;
      }

      // Case 1: already List<int>
      expect(parseRouteIds([5]), [5]);

      // Case 2: List<String> (which caused the crash: type 'List<String>' is not a subtype of type 'List<int>')
      expect(parseRouteIds(['5', '7']), [5, 7]);

      // Case 3: single integer
      expect(parseRouteIds(5), [5]);

      // Case 4: single string
      expect(parseRouteIds('7'), [7]);

      // Case 5: null or empty fallback
      expect(parseRouteIds(null), [5]);
      expect(parseRouteIds([]), [5]);
    });

    test('cacheRemoteCustomers with reconcile: true automatically purges customers deleted on server', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      CustomerEntity makeCustomer(int id, String name, String route) {
        return CustomerEntity(
          id: id,
          code: 'C$id',
          name: name,
          type: 'Đại lý',
          route: route,
          address: 'Địa chỉ $id',
          contactPerson: 'Người liên hệ $id',
          phone: '090123456$id',
        );
      }

      // 1. Initial sync: 3 customers from server (ID 10, 20, 30)
      final initialServerList = [
        makeCustomer(10, 'Khách 10', 'T2'),
        makeCustomer(20, 'Khách 20', 'T2'),
        makeCustomer(30, 'Khách 30', 'T3'),
      ];
      await dataSource.cacheRemoteCustomers(initialServerList, reconcile: true);

      var localList = await dataSource.getLocalCustomers();
      expect(localList.length, 3);
      expect(localList.map((c) => c.id).toSet(), {10, 20, 30});

      // 2. Server deletes Customer 20. Refresh returns only [10, 30]
      final updatedServerList = [
        makeCustomer(10, 'Khách 10', 'T2'),
        makeCustomer(30, 'Khách 30', 'T3'),
      ];
      await dataSource.cacheRemoteCustomers(updatedServerList, reconcile: true);

      localList = await dataSource.getLocalCustomers();
      // Customer 20 MUST BE REMOVED!
      expect(localList.length, 2);
      expect(localList.map((c) => c.id).toSet(), {10, 30});
      expect(localList.any((c) => c.id == 20), isFalse);

      // 3. User creates an offline customer (pending sync)
      await dataSource.createCustomerOffline({
        'name': 'Khách offline mới',
        'route_ids': [5],
      });

      localList = await dataSource.getLocalCustomers();
      expect(localList.length, 3); // 2 synced + 1 pending

      // 4. Server deletes Customer 30. Refresh returns only [10]
      await dataSource.cacheRemoteCustomers([
        makeCustomer(10, 'Khách 10', 'T2'),
      ], reconcile: true);

      localList = await dataSource.getLocalCustomers();
      // Customer 30 is purged, but offline pending customer is preserved!
      expect(localList.length, 2);
      expect(localList.any((c) => c.id == 10), isTrue);
      expect(localList.any((c) => c.id == 30), isFalse);
      expect(localList.any((c) => c.syncStatus == 'pending'), isTrue);

      await db.close();
    });

    test('CustomerDto.fromJson parses photo_url and photo_urls according to spec 23/09/2026', () {
      final json = {
        'id': 60383,
        'code': '08650170',
        'name': 'Tạp hoá Cô Ba',
        'address': '123 Đường Test',
        'phone': '0901234567',
        'photo_url': '/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1',
        'photo_urls': [
          '/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1',
          '/crm/customer-photos/public/2937ebd0d864a09b353405d9ba303d4a',
        ],
      };

      final dto = CustomerDto.fromJson(json);
      expect(dto.photoUrl, '/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1');
      expect(dto.photoUrls.length, 2);
      expect(dto.photoUrls[0], '/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1');
      expect(dto.photoUrls[1], '/crm/customer-photos/public/2937ebd0d864a09b353405d9ba303d4a');

      final entity = dto.toEntity();
      expect(entity.photoUrl, '/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1');
      expect(entity.photoUrls.length, 2);
      expect(entity.fullPhotoUrl, '${AppConstants.baseUrl}/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1');
      expect(entity.fullPhotoUrls[1], '${AppConstants.baseUrl}/crm/customer-photos/public/2937ebd0d864a09b353405d9ba303d4a');
    });

    test('CustomerDto.fromJson falls back to [photo_url] when photo_urls is empty', () {
      final json = {
        'id': 100,
        'code': '08650100',
        'name': 'Đại lý Cũ',
        'address': 'Địa chỉ',
        'phone': '0901111111',
        'photo_url': '/crm/customer-photos/public/avatar_token',
      };

      final dto = CustomerDto.fromJson(json);
      expect(dto.photoUrl, '/crm/customer-photos/public/avatar_token');
      expect(dto.photoUrls, ['/crm/customer-photos/public/avatar_token']);

      final entity = dto.toEntity();
      expect(entity.fullPhotoUrl, '${AppConstants.baseUrl}/crm/customer-photos/public/avatar_token');
      expect(entity.fullPhotoUrls, ['${AppConstants.baseUrl}/crm/customer-photos/public/avatar_token']);
    });

    test('createCustomerOffline enqueues photo_tokens list and sets photo_token', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      final inputData = {
        'name': 'Tạp hoá Cô Ba',
        'region_id': 39,
        'route_ids': [6825],
        'photo_tokens': [
          '4d6841b9e2645aab0c64f1877a4135b1',
          '2937ebd0d864a09b353405d9ba303d4a',
        ],
      };

      final entity = await dataSource.createCustomerOffline(inputData);
      expect(entity.photoUrls.length, 2);
      expect(entity.photoUrl, '4d6841b9e2645aab0c64f1877a4135b1');

      final entries = await db.select(db.syncQueueEntries).get();
      final enqueuedPayload = jsonDecode(entries.first.payload) as Map<String, dynamic>;

      // Root level MUST contain photo_tokens array according to spec 23/09/2026
      expect(enqueuedPayload['photo_tokens'], [
        '4d6841b9e2645aab0c64f1877a4135b1',
        '2937ebd0d864a09b353405d9ba303d4a',
      ]);
      // First token in photo_token for backward compatibility
      expect(enqueuedPayload['photo_token'], '4d6841b9e2645aab0c64f1877a4135b1');

      // Neither photo_tokens nor photo_token should leak into data
      if (enqueuedPayload.containsKey('data')) {
        final dataMap = enqueuedPayload['data'] as Map;
        expect(dataMap.containsKey('photo_tokens'), isFalse);
        expect(dataMap.containsKey('photo_token'), isFalse);
      }

      await db.close();
    });

    test('cacheRemoteCustomers preserves photoUrl and photoUrls in SQLite', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      const customer = CustomerEntity(
        id: 777,
        code: '08190777',
        name: 'Đại lý Nhiều Ảnh',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Hà Nội',
        contactPerson: 'Anh Bảy',
        phone: '0977777777',
        photoUrl: '/crm/customer-photos/public/token_main',
        photoUrls: [
          '/crm/customer-photos/public/token_main',
          '/crm/customer-photos/public/token_secondary',
        ],
      );

      await dataSource.cacheRemoteCustomers([customer], reconcile: true);

      final localList = await dataSource.getLocalCustomers();
      expect(localList.length, 1);
      final cached = localList.first;
      expect(cached.photoUrl, '/crm/customer-photos/public/token_main');
      expect(cached.photoUrls.length, 2);
      expect(cached.fullPhotoUrl, '${AppConstants.baseUrl}/crm/customer-photos/public/token_main');

      await db.close();
    });

    test('CustomerDto.fromJson parses routes[] object list, route_ids, and never falls back to regionName', () {
      final json = {
        'id': 3472,
        'code': '08880149',
        'name': 'Cửa hàng Test',
        'region_id': 62,
        'region_name': 'Tỉnh Vĩnh Phúc', // MUST NOT BE USED AS ROUTE!
        'province_name': 'Tỉnh Phú Thọ',
        'routes': [
          {'id': 5, 'name': 'Vũ Tùng Dương - T2', 'code': 'T2'},
          {'id': 7, 'name': 'Vũ Tùng Dương - T3', 'code': 'T3'},
        ],
        'route_ids': [5, 7],
      };

      final dto = CustomerDto.fromJson(json);
      expect(dto.routes.length, 2);
      expect(dto.routes, containsAll(['Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3']));
      expect(dto.routeIds, containsAll([5, 7]));

      final entity = dto.toEntity();
      expect(entity.routes, containsAll(['Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3']));
      expect(entity.routeIds, containsAll([5, 7]));
      // Must NOT be 'Tỉnh Vĩnh Phúc' or 'Tỉnh Phú Thọ'
      expect(entity.route, isNot(contains('Tỉnh Vĩnh Phúc')));
      expect(entity.route, isNot(contains('Tỉnh Phú Thọ')));
      expect(entity.route, 'Vũ Tùng Dương - T2');
    });

    test('CustomerLocalDataSource caches and restores customer routes and routeIds', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      const customer = CustomerEntity(
        id: 888,
        code: '08190888',
        name: 'Đại lý Tuyến Chuẩn',
        type: 'Đại lý',
        route: 'Vũ Tùng Dương - T2',
        routes: ['Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3'],
        routeIds: [5, 7],
        address: 'Hà Nội',
        contactPerson: 'Anh Tám',
        phone: '0988888888',
      );

      await dataSource.cacheRemoteCustomers([customer], reconcile: true);

      final localList = await dataSource.getLocalCustomers();
      expect(localList.length, 1);
      final cached = localList.first;
      expect(cached.route, 'Vũ Tùng Dương - T2');
      expect(cached.routes, containsAll(['Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3']));
      expect(cached.routeIds, containsAll([5, 7]));

      await db.close();
    });
  });
}


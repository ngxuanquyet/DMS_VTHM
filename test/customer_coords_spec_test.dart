import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/map/app_map_location_card.dart';
import 'package:vthm_dms/core/widgets/location_field_widget.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Coords Specification 15/10/2026 Tests', () {
    test('DynamicFormField recognizes fixed coords field from schema', () {
      final json = {
        'kind': 'fixed',
        'code': 'coords',
        'label': 'Toạ độ',
        'input_type': 'location',
        'required': true,
      };

      final field = DynamicFormField.fromJson(json);
      expect(field.code, equals('coords'));
      expect(field.label, equals('Toạ độ'));
      expect(field.type, equals(DynamicFormFieldType.location));
      expect(field.isRequired, isTrue);
      expect(field.isCoordsField, isTrue);
      expect(field.section, equals('Vị trí trên bản đồ'));
    });

    test('CustomerPayloadHelper packages coords object and excludes flat lat/lng', () {
      final source = {
        'name': 'Đại lý ABC',
        'region_id': 2,
        'route_ids': [10],
        'address': '123 Phố Huế',
        'coords': {
          'lat': 21.028512345,
          'lng': 105.8542000,
          'accuracy': 7.94,
          'mock': false,
        },
      };

      final payload = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: source);

      expect(payload.containsKey('coords'), isTrue);
      expect(payload['coords'], isA<Map<String, dynamic>>());
      final coordsMap = payload['coords'] as Map<String, dynamic>;
      expect(coordsMap['lat'], equals(21.0285123)); // 7 decimals
      expect(coordsMap['lng'], equals(105.8542));
      expect(coordsMap['accuracy'], equals(7.9)); // 1 decimal
      expect(coordsMap['mock'], isFalse);

      // QUAN TRỌNG: Tuyệt đối không gửi flat lat và lng để tránh lỗi 422
      expect(payload.containsKey('lat'), isFalse);
      expect(payload.containsKey('lng'), isFalse);
    });

    test('CustomerPayloadHelper sets coords: null when coords is null (delete coordinates)', () {
      final source = {
        'name': 'Đại lý ABC',
        'region_id': 2,
        'route_ids': [10],
        'coords': null,
      };

      final payload = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: source);

      expect(payload.containsKey('coords'), isTrue);
      expect(payload['coords'], isNull);
      expect(payload.containsKey('lat'), isFalse);
      expect(payload.containsKey('lng'), isFalse);
    });

    test('CustomerPayloadHelper strips flat lat/lng when coords object is passed alongside them', () {
      final source = {
        'name': 'Đại lý ABC',
        'region_id': 2,
        'route_ids': [10],
        'lat': 21.0285,
        'lng': 105.8542,
        'coords': {
          'lat': 21.0285,
          'lng': 105.8542,
          'mock': true,
        },
      };

      final payload = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: source);

      expect(payload.containsKey('coords'), isTrue);
      final coordsMap = payload['coords'] as Map<String, dynamic>;
      expect(coordsMap['lat'], equals(21.0285));
      expect(coordsMap['lng'], equals(105.8542));
      expect(coordsMap['mock'], isTrue);

      // QUAN TRỌNG: CẢ coords và lat/lng cùng gửi thì bị lỗi 422, nên lat/lng phẳng phải bị lược bỏ
      expect(payload.containsKey('lat'), isFalse);
      expect(payload.containsKey('lng'), isFalse);
    });

    test('CustomerDto parses coords object and mock flag from API response', () {
      final json = {
        'id': 1234,
        'code': 'KH001',
        'name': 'Cửa hàng Minh Khai',
        'address': '250 Minh Khai',
        'coords': {
          'lat': 20.9987654,
          'lng': 105.8456789,
          'mock': true,
        },
        'lat': 20.9987654, // fallback legacy flat keys
        'lng': 105.8456789,
      };

      final dto = CustomerDto.fromJson(json);
      expect(dto.lat, equals(20.9987654));
      expect(dto.lng, equals(105.8456789));
      expect(dto.coordsMock, isTrue);

      final entity = dto.toEntity();
      expect(entity.lat, equals(20.9987654));
      expect(entity.lng, equals(105.8456789));
      expect(entity.coordsMock, isTrue);
    });

    testWidgets('LocationFieldWidget hides address input when showAddressInput is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationFieldWidget(
                label: 'Toạ độ',
                showAddressInput: false, // For coords field
                value: const {
                  'address': '123 Phố Huế',
                  'lat': 21.028512,
                  'lng': 105.8542,
                },
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Badge says 'Toạ độ GPS'
      expect(find.text('Toạ độ GPS'), findsOneWidget);

      // Address TextField should NOT be rendered
      expect(find.byType(TextField), findsNothing);

      // Coordinates display should be visible
      expect(find.textContaining('21.028512, 105.854200'), findsOneWidget);
    });

    testWidgets('LocationFieldWidget removes outer card wrapping when showBorderContainer is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationFieldWidget(
                label: 'Toạ độ',
                showAddressInput: false,
                showBorderContainer: false,
                value: const {
                  'lat': 21.028512,
                  'lng': 105.8542,
                },
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // The field content should be rendered without an outer Container with padding: 14
      final locWidget = tester.widget<LocationFieldWidget>(find.byType(LocationFieldWidget));
      expect(locWidget.showBorderContainer, isFalse);
      expect(find.text('Toạ độ GPS'), findsOneWidget);
      expect(find.textContaining('21.028512, 105.854200'), findsOneWidget);
    });

    testWidgets('DynamicFormBuilder renders AppMapLocationCard for coords without outer section card, matching EditCustomerScreen', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          section: 'Thông tin chung',
        ),
        const DynamicFormField(
          code: 'address',
          label: 'Địa chỉ giao dịch',
          type: DynamicFormFieldType.text,
          section: 'Địa chỉ giao dịch',
        ),
        const DynamicFormField(
          code: 'coords',
          label: 'Vị trí điểm bán trên bản đồ',
          type: DynamicFormFieldType.location,
          isRequired: true,
          section: 'Vị trí trên bản đồ',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicFormBuilder(
                  fields: fields,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Section Header row for Vị trí trên bản đồ exists
      expect(find.text('Vị trí trên bản đồ'), findsOneWidget);
      expect(find.text('Bắt buộc'), findsOneWidget);

      // Verify AppMapLocationCard is rendered with title 'Vị trí điểm bán trên bản đồ'
      expect(find.byType(AppMapLocationCard), findsOneWidget);
      expect(find.text('Vị trí điểm bán trên bản đồ'), findsOneWidget);

      // Verify button 'LẤY VỊ TRÍ HIỆN TẠI' exists (matching EditCustomerScreen)
      expect(find.text('LẤY VỊ TRÍ HIỆN TẠI'), findsOneWidget);
    });
  });
}


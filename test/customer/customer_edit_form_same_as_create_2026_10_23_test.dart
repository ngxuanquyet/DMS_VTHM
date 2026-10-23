import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Form SỬA điểm bán dùng đúng bộ ô của form TẠO (chủ hệ thống 23/10/2026): không đắp khoá dữ liệu (erp_linked,
/// created_by_name…) thành ô; Kênh/Tuyến tự khai chỉ có lúc tạo.
void main() {
  final schema = {
    'data': {
      'scope_fields': true,
      'fields': [
        {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'required': true},
        {'code': 'h_lh', 'label': 'Liên hệ', 'input_type': 'heading'},
        {'code': 'phone', 'label': 'SĐT', 'input_type': 'text'},
        {'code': 'own_channel_ids', 'label': 'Kênh', 'input_type': 'select'},
        {'code': 'territory_code', 'label': 'Tuyến', 'input_type': 'select'},
      ],
    },
  };
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];

  test('sửa: không có ô erp_linked / created_by_name / khoá động ngoài cấu hình, không có Kênh/Tuyến tự khai', () {
    const c = CustomerEntity(
      id: 1,
      code: 'DMS0800001',
      name: 'Tạp hoá A',
      type: 'Đại lý',
      route: 'Tuyến A',
      address: 'HN',
      phone: '0900000000',
      contactPerson: 'A',
      dynamicFields: {'erp_linked': false, 'created_by_name': 'Nguyễn Văn A', 'mw_nhan_1': 'X'},
    );
    final f = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, editing: c);
    final codes = f.map((x) => x.code).toList();
    expect(codes, isNot(contains('erp_linked')));
    expect(codes, isNot(contains('created_by_name')));
    expect(codes, isNot(contains('mw_nhan_1')));
    expect(codes, isNot(contains('own_channel_ids')));
    expect(codes, isNot(contains('territory_code')));
    expect(codes, isNot(contains('h_lh')));
    expect(f.firstWhere((x) => x.code == 'phone').section, 'Liên hệ');
  });

  test('tạo và sửa cùng thứ tự ô (trừ Kênh/Tuyến tự khai)', () {
    final tao = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5)
        .map((x) => x.code)
        .where((c) => c != 'own_channel_ids' && c != 'territory_code')
        .toList();
    const c = CustomerEntity(
        id: 1, code: 'X', name: 'A', type: '', route: '', address: '', phone: '', contactPerson: '');
    final sua = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, editing: c)
        .map((x) => x.code)
        .toList();
    expect(sua, tao);
  });

  test('sửa: giữ loại/khu vực hiện tại trong lựa chọn, không áp `default` của schema; tạo thì áp', () {
    final s = {
      'data': {
        'fields': [
          {'code': 'name', 'label': 'Tên', 'input_type': 'text'},
          {'code': 'ghi_chu', 'label': 'Ghi chú', 'input_type': 'text', 'default': 'mặc định'},
        ],
      },
    };
    const c = CustomerEntity(
      id: 1, code: 'X', name: 'A', type: 'Loại cũ', route: '', address: '', phone: '', contactPerson: '',
      customerTypeId: 77, regionId: 88, regionName: 'KV cũ');
    final sua = buildCustomerFormFields(s, meta: const CustomerMetaData(), routeOptions: routes, editing: c);
    expect(sua.firstWhere((x) => x.code == 'customer_type_id').options.map((o) => o.value), contains(77));
    expect(sua.firstWhere((x) => x.code == 'region_id').options.map((o) => o.value), contains(88));
    expect(sua.firstWhere((x) => x.code == 'ghi_chu').initialValue, isNull);

    final tao = buildCustomerFormFields(s, meta: const CustomerMetaData(), routeOptions: routes);
    expect(tao.firstWhere((x) => x.code == 'ghi_chu').initialValue, 'mặc định');
    expect(tao.firstWhere((x) => x.code == 'customer_type_id').options.map((o) => o.value), [1]);
  });

  test('schema rỗng vẫn có ô Tên điểm bán', () {
    final f = buildCustomerFormFields({'data': {'fields': []}}, meta: const CustomerMetaData(), routeOptions: routes);
    expect(f.first.code, 'name');
  });
}

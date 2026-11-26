import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/network/outlet_contract.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/visit/data/models/material_create_rules.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';

/// Hợp đồng API điểm bán mới (One #25946 bước 2, 27/11/2026): app gửi `outlet_*`, đọc `outlet_*` (lùi về `customer_*` của
/// bộ đệm / hàng đợi bản cũ), schema đổi tên ô cứng `outlet_type_id` → mã nội bộ `customer_type_id`.
void main() {
  group('toWire', () {
    test('đổi khoá tầng trên cùng, giữ mã ô biểu mẫu bên trong', () {
      final out = OutletContract.toWire({
        'customer_id': 5,
        'customer_client_uuid': 'u',
        'customer_type_id': 3,
        'customerTypes': [],
        'visit_id': 9,
        'answers': {'customer_id': 5, 'customer_name': 'A'},
        'data': {'customer_note': 'x'},
      });
      expect(out, {
        'outlet_id': 5,
        'outlet_client_uuid': 'u',
        'outlet_type_id': 3,
        'outletTypes': [],
        'visit_id': 9,
        'answers': {'customer_id': 5, 'customer_name': 'A'},
        'data': {'customer_note': 'x'},
      });
    });

    test('có cả hai tên thì giữ tên mới (không gửi hai tên khác giá trị → 422)', () {
      expect(OutletContract.toWire({'customer_id': 1, 'outlet_id': 2}), {'outlet_id': 2});
      expect(OutletContract.toWire({'outlet_id': 2, 'customer_id': 1}), {'outlet_id': 2});
    });

    test('khoá không bắt đầu bằng customer giữ nguyên', () {
      expect(OutletContract.toWire({'distance_to_customer_m': 1, 'customerx': 2}),
          {'distance_to_customer_m': 1, 'customerx': 2});
    });
  });

  test('read: tên mới trước, lùi tên cũ', () {
    expect(OutletContract.read({'outlet_id': 1, 'customer_id': 2}, '_id'), 1);
    expect(OutletContract.read({'customer_id': 2}, '_id'), 2);
    expect(OutletContract.read({'outletTypes': [1]}, 'Types'), [1]);
  });

  test('schema: ô CỨNG outlet_type_id về mã nội bộ, ô động giữ nguyên', () {
    final fixed = DynamicFormField.fromJson({'kind': 'fixed', 'code': 'outlet_type_id', 'catalog': 'outlet_type', 'label': 'Loại'});
    expect(fixed.code, 'customer_type_id');
    expect(fixed.catalog, 'customer_type');
    final dyn = DynamicFormField.fromJson({'kind': 'dynamic', 'code': 'outlet_type_id', 'label': 'X'});
    expect(dyn.code, 'outlet_type_id');
  });

  test('điểm bán + meta đọc tên mới', () {
    final dto = CustomerDto.fromJson({'id': 7, 'name': 'A', 'code': 'C', 'outlet_type_id': 3, 'outlet_type_name': 'Tạp hoá'});
    expect(dto.customerTypeId, 3);
    expect(dto.toEntity().type, 'Tạp hoá');
    final meta = CustomerMetaData.fromJson({
      'data': {
        'outletTypes': [
          {'id': 3, 'code': 'TH', 'name': 'Tạp hoá'},
        ],
      },
    });
    expect(meta.customerTypes.single.id, 3);
    final res = CustomerApiResponse.fromJson({
      'success': true,
      'data': [
        {'id': 7, 'name': 'A', 'outlet_type_id': 3},
      ],
      'meta': {
        'outletTypes': [
          {'id': 3, 'name': 'Tạp hoá'},
        ],
      },
    });
    expect(res.data.single.type, 'Tạp hoá');
  });

  test('lượt viếng thăm / lịch sử / phiếu / luật vật tư đọc tên mới', () {
    final v = VisitEntity.fromJson({
      'id': 1,
      'outlet_id': 5,
      'outlet_name': 'A',
      'outlet_code': 'C',
      'outlet_client_uuid': 'u',
      'outlet_approval_status': 'pending',
    });
    expect([v.customerId, v.customerName, v.customerCode, v.customerClientUuid, v.customerApprovalStatus],
        [5, 'A', 'C', 'u', 'pending']);
    // Bộ đệm máy ghi từ bản trước (tên cũ) vẫn đọc được.
    expect(VisitEntity.fromJson({'id': 1, 'customer_id': 6}).customerId, 6);

    final h = VisitHistoryItemEntity.fromJson({'id': 1, 'outlet_id': 5, 'outlet_name': 'A', 'outlet_approval_status': 'rejected'});
    expect([h.customerId, h.customerName, h.customerApprovalStatus], [5, 'A', 'rejected']);

    expect(MarketFormSubmissionDetailModel.fromJson({'id': 1, 'config_id': 2, 'outlet_id': 5}).customerId, 5);
    expect(MaterialCreateRule.fromJson({'id': 1, 'outlet_type_ids': [3]}).customerTypeIds, [3]);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/daily_report/presentation/viewmodels/visit_report_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';

void main() {
  group('Quy trình Phê duyệt điểm bán (API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15)', () {
    test('1. CustomerDto.fromJson parses 4 approval keys correctly', () {
      final json = {
        'id': 89187,
        'code': '08650170',
        'name': 'Đại lý Thành Hậu',
        'status': 'active',
        'approval_status': 'rejected',
        'approval_label': 'Bị từ chối',
        'approval_color': 'danger',
        'approval_note': 'Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ',
        'approval_at': '2026-10-15 16:47:49.039594+07',
        'address': '123 Đường ABC, Hà Nội',
        'phone': '0912345678',
      };

      final dto = CustomerDto.fromJson(json);
      expect(dto.id, 89187);
      expect(dto.approvalStatus, 'rejected');
      expect(dto.approvalLabel, 'Bị từ chối');
      expect(dto.approvalColor, 'danger');
      expect(dto.approvalNote, 'Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ');
      expect(dto.approvalAt, '2026-10-15 16:47:49.039594+07');

      final entity = dto.toEntity();
      expect(entity.approvalStatus, 'rejected');
      expect(entity.isRejectedApproval, isTrue);
      expect(entity.isPendingApproval, isFalse);
      expect(entity.isApproved, isFalse);
      expect(entity.displayApprovalLabel, 'Bị từ chối');
      expect(entity.approvalBadgeColor, const Color(0xFFEF4444));
      expect(entity.approvalNote, 'Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ');
    });

    test('2. CustomerEntity fallback labels & colors when server fields are omitted', () {
      const pendingEntity = CustomerEntity(
        id: 1,
        code: 'KH01',
        name: 'Điểm bán mới',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Địa chỉ 1',
        contactPerson: 'A',
        phone: '0901',
        approvalStatus: 'pending',
      );
      expect(pendingEntity.isPendingApproval, isTrue);
      expect(pendingEntity.isApproved, isFalse);
      expect(pendingEntity.displayApprovalLabel, 'Chờ duyệt');
      expect(pendingEntity.approvalBadgeColor, const Color(0xFFF59E0B));

      const approvedEntity = CustomerEntity(
        id: 2,
        code: 'KH02',
        name: 'Điểm bán cũ',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Địa chỉ 2',
        contactPerson: 'B',
        phone: '0902',
        approvalStatus: 'approved',
      );
      expect(approvedEntity.isApproved, isTrue);
      expect(approvedEntity.isPendingApproval, isFalse);
      expect(approvedEntity.displayApprovalLabel, 'Đã duyệt');
      expect(approvedEntity.approvalBadgeColor, const Color(0xFF10B981));
    });

    test('3. CustomerPayloadHelper forbids approval_status from POST payload', () {
      final inputData = {
        'name': 'Cửa hàng Mới',
        'region_id': 1,
        'route_ids': [1],
        'phone': '0988776655',
        'address': 'Hà Nội',
        'approval_status': 'approved', // Bị cấm gửi lên server
      };

      final payload = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: inputData);
      expect(payload.containsKey('approval_status'), isFalse);
      expect(kForbiddenCustomerKeys.contains('approval_status'), isTrue);
    });

    test('4. VisitEntity parses customer_approval_status, customer_approval_note and reports according to §3c chốt 16/10/2026', () {
      final visitApprovedJson = {
        'id': 101,
        'customer_id': 1,
        'customer_name': 'Khách A',
        'visit_result': 'visited',
        'checkout_at': '2026-10-15 10:00:00',
        'customer_approval_status': 'approved',
      };
      final visitPendingJson = {
        'id': 102,
        'customer_id': 2,
        'customer_name': 'Khách B',
        'visit_result': 'visited',
        'checkout_at': '2026-10-15 11:00:00',
        'customer_approval_status': 'pending',
      };
      final visitRejectedJson = {
        'id': 103,
        'customer_id': 3,
        'customer_name': 'Khách C',
        'visit_result': 'visited',
        'checkout_at': '2026-10-15 12:00:00',
        'customer_approval_status': 'rejected',
        'customer_approval_note': 'Sai vị trí GPS thực tế',
      };

      final v1 = VisitEntity.fromJson(visitApprovedJson);
      final v2 = VisitEntity.fromJson(visitPendingJson);
      final v3 = VisitEntity.fromJson(visitRejectedJson);

      expect(v1.isCustomerApproved, isTrue);
      expect(v2.isCustomerApproved, isFalse);
      expect(v3.isCustomerApproved, isFalse);
      expect(v3.customerApprovalNote, 'Sai vị trí GPS thực tế');

      final reportState = VisitReportState(
        selectedDate: DateTime.now(),
        visits: [v1, v2, v3],
      );

      // Theo §3c (chốt 16/10/2026):
      // - visits đếm MỌI lượt đã check-out (ở đây cả 3 lượt đều được tính)
      // - Khách hàng tách 3 nhóm: 1 hợp lệ, 1 chờ duyệt, 1 bị từ chối
      expect(reportState.totalVisits, 3);
      expect(reportState.visitedCount, 3);
      expect(reportState.approvedCustomerCount, 1);
      expect(reportState.pendingCustomerCount, 1);
      expect(reportState.rejectedCustomerCount, 1);
      expect(reportState.totalCustomerCount, 3);
    });

    test('5. Section 5b: Requirements for newly opened/pending store waives minimum duration', () {
      final reqJson = {
        'satisfied': true,
        'seconds_remaining': 0, // Server sends 0 for newly opened store first visit (§5b)
        'photos_missing': 0,
        'missing_forms': <String>[],
        'blockers': <String>[],
      };
      final req = VisitRequirementsEntity.fromJson(reqJson);
      expect(req.secondsRemaining, 0);
      expect(req.satisfied, isTrue);
      expect(req.photosMissing, 0);
      expect(req.missingForms, isEmpty);
      expect(req.blockers, isEmpty);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/daily_report/presentation/widgets/visit_report_card.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';

/// Nghiệp vụ 21/10/2026: tạo điểm bán mới = server tự ghi MỘT lượt viếng thăm đã đóng
/// (`visit_kind = new_outlet`, thời gian ở lại 0), không qua check-in/check-out.
void main() {
  group('VisitEntity — visit_kind', () {
    test('Parse lượt new_outlet: nhãn, màu info, đã đóng, tính là hoàn tất', () {
      final v = VisitEntity.fromJson({
        'id': 501,
        'customer_id': 77,
        'customer_name': 'Tạp hoá Mới',
        'visit_date': '2026-10-21',
        'checkin_at': '2026-10-21 09:15:00+07',
        'checkout_at': '2026-10-21 09:15:00+07',
        'duration_seconds': 0,
        'customer_approval_status': 'rejected',
        'visit_kind': 'new_outlet',
        'visit_kind_label': 'Tạo điểm bán',
        'visit_kind_color': 'info',
      });

      expect(v.visitKind, kVisitKindNewOutlet);
      expect(v.isNewOutlet, isTrue);
      expect(v.visitKindLabel, 'Tạo điểm bán');
      expect(v.visitKindBootstrapColor, const Color(0xFF0284C7));
      expect(v.isOpen, isFalse);
      expect(v.isCompleted, isTrue);
      // Điểm bán bị từ chối thì lượt vẫn tính, chỉ gắn cờ
      expect(v.customerApprovalStatus, 'rejected');
    });

    test('Lượt new_outlet thiếu checkout_at vẫn KHÔNG coi là đang mở (không hiện check-out/huỷ)', () {
      final v = VisitEntity.fromJson({
        'id': 502,
        'customer_id': 78,
        'checkin_at': '2026-10-21 10:00:00+07',
        'visit_kind': 'new_outlet',
      });
      expect(v.isOpen, isFalse);
      expect(v.isCompleted, isTrue);
    });

    test('Thiếu visit_kind (bản cache cũ / server cũ) ⇒ mặc định checkin, hành vi cũ giữ nguyên', () {
      final v = VisitEntity.fromJson({
        'id': 503,
        'customer_id': 79,
        'checkin_at': '2026-10-21 10:00:00+07',
      });
      expect(v.visitKind, kVisitKindCheckin);
      expect(v.isNewOutlet, isFalse);
      expect(v.isOpen, isTrue);
    });

    test('toJson/fromJson giữ nguyên visit_kind (cache cục bộ)', () {
      const v = VisitEntity(
        id: 504,
        customerId: 80,
        visitKind: kVisitKindNewOutlet,
        visitKindLabel: 'Tạo điểm bán',
        visitKindColor: 'info',
      );
      final back = VisitEntity.fromJson(v.toJson());
      expect(back.isNewOutlet, isTrue);
      expect(back.visitKindLabel, 'Tạo điểm bán');
      expect(back.visitKindColor, 'info');
      expect(v.copyWith(customerName: 'X').isNewOutlet, isTrue);
    });

    test('bootstrapColorOf dùng chung cho màu kết quả lẫn màu loại lượt', () {
      expect(VisitEntity.bootstrapColorOf('secondary'), const Color(0xFF6B7280));
      expect(VisitEntity.bootstrapColorOf('INFO'), const Color(0xFF0284C7));
      expect(VisitEntity.bootstrapColorOf(null), isNull);
      const v = VisitEntity(id: 1, customerId: 1, visitResultColor: 'success');
      expect(v.resultBootstrapColor, const Color(0xFF16A34A));
    });
  });

  group('VisitHistoryItemEntity — visit_kind', () {
    test('Parse lượt new_outlet trong lịch sử điểm bán: đã đóng, thời gian ở lại hiện "—"', () {
      final item = VisitHistoryItemEntity.fromJson({
        'id': 601,
        'customer_id': 77,
        'employee_name': 'Nguyễn Văn A',
        'checkin_at': '2026-10-21 09:15:00',
        'duration_seconds': 0,
        'visit_kind': 'new_outlet',
        'visit_kind_label': 'Tạo điểm bán',
        'visit_kind_color': 'info',
      });
      expect(item.isNewOutlet, isTrue);
      expect(item.isOpen, isFalse);
      expect(item.formattedDuration, '—');
      expect(item.visitKindBootstrapColor, const Color(0xFF0284C7));
      expect(item.toJson()['visit_kind'], 'new_outlet');
    });

    test('Lượt check-in thường: mặc định checkin', () {
      final item = VisitHistoryItemEntity.fromJson({
        'id': 602,
        'customer_id': 77,
        'employee_name': 'B',
        'checkin_at': '2026-10-21 09:15:00',
        'checkout_at': '2026-10-21 09:30:00',
        'duration_seconds': 900,
      });
      expect(item.isNewOutlet, isFalse);
      expect(item.visitKind, kVisitKindCheckin);
    });
  });

  group('Hiển thị', () {
    testWidgets('Thẻ "Lượt viếng thăm của tôi" hiện nhãn Tạo điểm bán + cờ duyệt, không hiện "0 phút"',
        (tester) async {
      final v = VisitEntity.fromJson({
        'id': 701,
        'customer_id': 77,
        'customer_name': 'Tạp hoá Mới',
        'checkin_at': '2026-10-21 09:15:00+07',
        'checkout_at': '2026-10-21 09:15:00+07',
        'duration_seconds': 0,
        'customer_approval_status': 'pending',
        'visit_kind': 'new_outlet',
        'visit_kind_label': 'Tạo điểm bán',
        'visit_kind_color': 'info',
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: VisitReportCard(visit: v))),
      ));

      expect(find.text('Tạo điểm bán'), findsOneWidget);
      expect(find.text('Chờ duyệt ĐB'), findsOneWidget);
      expect(find.text('0 phút'), findsNothing);
      expect(find.text('Đang viếng thăm'), findsNothing);
    });

    test('Thông báo sau khi tạo điểm bán nói rõ đã ghi nhận lượt viếng thăm', () {
      expect(addCustomerSuccessMessage(hasPending: false), 'Đã tạo điểm bán và ghi nhận lượt viếng thăm.');
      expect(addCustomerSuccessMessage(hasPending: true), contains('ngoại tuyến'));
      expect(addCustomerSuccessMessage(hasPending: true), isNot(contains('màn viếng thăm')));
      expect(addCustomerSuccessMessage(hasPending: false), isNot(contains('màn viếng thăm')));
    });
  });
}

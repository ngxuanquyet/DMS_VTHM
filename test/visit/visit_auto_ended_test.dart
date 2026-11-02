import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';

/// #24701 — lượt quên check-out được server (cron đầu ngày) kết thúc tự động: KHÔNG còn mở (không chặn check-in, không
/// hiện "Vào lượt đang mở"), nhãn "Chưa check-out".
void main() {
  final base = {
    'id': 7,
    'visit_date': '2026-11-01',
    'checkin_at': '2026-11-01T09:00:00+07:00',
    'checkout_at': null,
    'customer_id': 3,
    'customer_name': 'A',
  };

  test('auto_ended_at ⇒ không còn mở, isAutoEnded', () {
    final v = VisitEntity.fromJson({...base, 'auto_ended_at': '2026-11-02T00:05:00+07:00'});
    expect(v.isOpen, isFalse, reason: 'lỗi: lượt đã được hệ thống kết thúc vẫn chặn check-in');
    expect(v.isAutoEnded, isTrue);
    expect(VisitEntity.fromJson(v.toJson()).isAutoEnded, isTrue, reason: 'bản lưu máy phải giữ dấu');
  });

  test('không có auto_ended_at ⇒ vẫn mở như cũ', () {
    final v = VisitEntity.fromJson(base);
    expect(v.isOpen, isTrue);
    expect(v.isAutoEnded, isFalse);
  });

  test('lịch sử điểm bán cũng nhận dấu', () {
    final h = VisitHistoryItemEntity.fromJson({...base, 'employee_name': 'B', 'auto_ended_at': '2026-11-02T00:05:00+07:00'});
    expect(h.isOpen, isFalse);
    expect(h.isAutoEnded, isTrue);
  });
}

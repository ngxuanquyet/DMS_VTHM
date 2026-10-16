import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';

void main() {
  group('SPEC 2026-10-15 Visit Changes Tests', () {
    test('1. VisitEntity parses is_checkout_other_day correctly', () {
      final jsonOtherDay = {
        'id': 135808,
        'customer_id': 5378,
        'visit_date': '2026-10-15',
        'checkin_at': '2026-10-15 11:27:50+07',
        'checkout_at': '2026-10-16 08:05:00+07',
        'duration_seconds': 74590,
        'is_checkout_other_day': true,
      };

      final visit1 = VisitEntity.fromJson(jsonOtherDay);
      expect(visit1.isCheckoutOtherDay, isTrue);
      expect(visit1.toJson()['is_checkout_other_day'], isTrue);

      final jsonSameDay = {
        'id': 135807,
        'customer_id': 5378,
        'visit_date': '2026-10-15',
        'checkin_at': '2026-10-15 11:27:49+07',
        'checkout_at': '2026-10-15 11:37:49+07',
        'duration_seconds': 600,
        'is_checkout_other_day': false,
      };

      final visit2 = VisitEntity.fromJson(jsonSameDay);
      expect(visit2.isCheckoutOtherDay, isFalse);
      expect(visit2.toJson()['is_checkout_other_day'], isFalse);

      // Default when key missing
      final jsonNoKey = {
        'id': 135809,
        'customer_id': 5378,
      };
      final visit3 = VisitEntity.fromJson(jsonNoKey);
      expect(visit3.isCheckoutOtherDay, isFalse);
    });

    test('2. MobileRules auto_close_after_hours defaults to 0 and parses 0', () {
      const defaultRules = VisitRules();
      expect(defaultRules.autoCloseAfterHours, equals(0));

      final jsonWith0 = {
        'require_geofence': true,
        'default_radius_m': 100,
        'auto_close_after_hours': 0,
      };
      final parsed = VisitRules.fromJson(jsonWith0);
      expect(parsed.autoCloseAfterHours, equals(0));
    });

    test('3. Dealer with completed visit can be represented with DealerVisitStatus.completed', () {
      final dealer = DealerEntity(
        id: '5378',
        name: 'Đại lý Test',
        address: 'Hà Nội',
        order: '1',
        status: DealerVisitStatus.completed,
        statusLabel: 'Đã ghé',
        isVip: false,
        visitedTime: '08:30 - 08:45',
      );

      expect(dealer.status, equals(DealerVisitStatus.completed));
      expect(dealer.visitedTime, equals('08:30 - 08:45'));
    });
  });
}

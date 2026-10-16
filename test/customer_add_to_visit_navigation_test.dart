import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

void main() {
  group('Quy trình Tạo điểm bán mới -> Chuyển vào màn viếng thăm', () {
    test('Điểm bán mới tạo có visitStatus là pending (chưa viếng thăm)', () {
      final newCustomer = CustomerEntity(
        id: 8190163,
        code: '08190163',
        name: 'Đại lý Tạp hoá Hoàng Gia',
        phone: '0987654321',
        contactPerson: 'Nguyễn Văn A',
        type: 'Đại lý cấp 2',
        route: 'Tuyến số 01',
        address: '123 Đường Giải Phóng, Hà Nội',
        lat: 20.9712,
        lng: 105.7891,
        approvalStatus: 'pending',
        visitStatus: CustomerVisitStatus.pending,
      );

      // Điểm bán mới tạo CHƯA ĐƯỢC ghi nhận viếng thăm
      expect(newCustomer.visitStatus, equals(CustomerVisitStatus.pending));
      expect(newCustomer.visitStatus != CustomerVisitStatus.visited, isTrue);
    });

    test('Chuyển đổi CustomerEntity mới tạo thành DealerEntity để mở màn viếng thăm (/check-in)', () {
      final newCustomer = CustomerEntity(
        id: 8190163,
        code: '08190163',
        name: 'Đại lý Tạp hoá Hoàng Gia',
        phone: '0987654321',
        contactPerson: 'Nguyễn Văn A',
        type: 'Đại lý cấp 2',
        route: 'Tuyến số 01',
        address: '123 Đường Giải Phóng, Hà Nội',
        lat: 20.9712,
        lng: 105.7891,
        geofenceRadiusM: 100,
        approvalStatus: 'pending',
        visitStatus: CustomerVisitStatus.pending,
      );

      final dealer = DealerEntity(
        id: newCustomer.id.toString(),
        order: '01',
        name: newCustomer.name,
        code: newCustomer.code.isNotEmpty ? newCustomer.code : null,
        phone: newCustomer.phone.isNotEmpty ? newCustomer.phone : null,
        contactPerson: newCustomer.contactPerson.isNotEmpty ? newCustomer.contactPerson : null,
        type: newCustomer.type.isNotEmpty ? newCustomer.type : null,
        address: newCustomer.address,
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: newCustomer.lat,
        lng: newCustomer.lng,
        geofenceRadiusM: newCustomer.geofenceRadiusM,
        customer: newCustomer,
      );

      // Trạng thái ban đầu trên màn viếng thăm là pending ("Chưa ghé")
      expect(dealer.status, equals(DealerVisitStatus.pending));
      expect(dealer.statusLabel, equals('Chưa ghé'));
      expect(dealer.id, equals('8190163'));
      expect(dealer.lat, equals(20.9712));
      expect(dealer.lng, equals(105.7891));
      expect(dealer.visit, isNull);
    });
  });
}

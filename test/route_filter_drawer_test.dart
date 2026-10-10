import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/route/presentation/widgets/route_filter_drawer.dart';

void main() {
  group('RouteState Filter Logic Tests', () {
    test('activeFiltersCount and hasActiveFilter work correctly', () {
      const stateEmpty = RouteState();
      expect(stateEmpty.activeFiltersCount, 0);
      expect(stateEmpty.hasActiveFilter, false);

      final stateWithRoute = stateEmpty.copyWith(selectedRoute: 'Tuyến Quận 1');
      expect(stateWithRoute.activeFiltersCount, 1);
      expect(stateWithRoute.hasActiveFilter, true);

      final stateWithAll = stateWithRoute.copyWith(
        selectedVisitStatus: 'completed',
        selectedCustomerStatus: 'active',
        selectedCustomerType: 'Đại lý',
      );
      expect(stateWithAll.activeFiltersCount, 4);
      expect(stateWithAll.hasActiveFilter, true);

      // Default strings should not count as active filters
      final stateReset = stateWithAll.copyWith(
        selectedRoute: 'Tất cả tuyến',
        clearVisitStatus: true,
        clearCustomerStatus: true,
        clearCustomerType: true,
      );
      expect(stateReset.activeFiltersCount, 0);
      expect(stateReset.hasActiveFilter, false);
    });
  });

  group('RouteFilterDrawer Widget Tests', () {
    testWidgets('renders all 4 filter sections and interactively applies', (tester) async {
      final dealers = [
        const DealerEntity(
          id: '1',
          order: '01',
          name: 'Đại lý An Phát',
          address: '123 Nguyễn Trãi',
          status: DealerVisitStatus.completed,
          statusLabel: 'Đã ghé',
          isVip: false,
          customer: CustomerEntity(
            id: 1,
            code: 'KH01',
            name: 'Đại lý An Phát',
            address: '123 Nguyễn Trãi',
            route: 'Tuyến Q1',
            status: 'active',
            type: 'Đại lý',
            contactPerson: 'Nguyễn Văn A',
            phone: '0901234567',
          ),
        ),
        const DealerEntity(
          id: '2',
          order: '02',
          name: 'Tạp hóa Bình An',
          address: '456 Lê Lợi',
          status: DealerVisitStatus.pending,
          statusLabel: 'Chưa ghé',
          isVip: false,
          customer: CustomerEntity(
            id: 2,
            code: 'KH02',
            name: 'Tạp hóa Bình An',
            address: '456 Lê Lợi',
            route: 'Tuyến Q2',
            status: 'inactive',
            type: 'Tạp hóa',
            contactPerson: 'Trần Thị B',
            phone: '0909876543',
          ),
        ),
      ];

      final container = ProviderContainer();
      final sub = container.listen(routeViewModelProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final vm = container.read(routeViewModelProvider.notifier);

      final state = RouteState(
        routeDetail: RouteDetailEntity(
          id: '1',
          title: 'Tuyến Hà Nội',
          totalDealers: 2,
          completedDealers: 1,
          pendingDealers: 1,
          progressPercent: 0.5,
          dealers: dealers,
        ),
        availableRoutes: const ['Tất cả tuyến', 'Tuyến Q1', 'Tuyến Q2'],
        availableCustomerTypes: const ['Tất cả loại', 'Đại lý', 'Tạp hóa'],
        availableCustomerStatuses: const ['Tất cả', 'Đang hoạt động', 'Ngừng hoạt động'],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              endDrawer: RouteFilterDrawer(state: state, vm: vm),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Verify Drawer Title
      expect(find.text('Bộ lọc lộ trình'), findsOneWidget);

      // Verify Section 1: Trạng thái viếng thăm
      expect(find.text('Trạng thái viếng thăm'), findsOneWidget);
      expect(find.text('Đã ghé'), findsOneWidget);
      expect(find.text('Chưa ghé'), findsOneWidget);

      // Verify Section 2: Tuyến bán hàng
      expect(find.text('Tuyến bán hàng'), findsOneWidget);

      // Verify Section 3: Trạng thái khách hàng
      expect(find.text('Trạng thái khách hàng'), findsOneWidget);
      expect(find.text('Đang hoạt động'), findsOneWidget);

      // Verify Section 4: Loại khách hàng
      expect(find.text('Loại khách hàng'), findsOneWidget);

      // Verify Buttons
      expect(find.text('Đặt lại'), findsOneWidget);
      expect(find.text('Áp dụng'), findsOneWidget);

      // Tap 'Đã ghé' chip
      await tester.tap(find.text('Đã ghé'));
      await tester.pumpAndSettle();

      // Tap 'Áp dụng'
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      // Verify drawer closed
      expect(find.text('Bộ lọc lộ trình'), findsNothing);
    });
  });
}

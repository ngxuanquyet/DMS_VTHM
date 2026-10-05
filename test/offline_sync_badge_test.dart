import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/widgets/offline_sync_badge.dart';

class FakeConnectivityNotifier extends ConnectivityNotifier {
  FakeConnectivityNotifier({required bool isOnline}) {
    state = ConnectivityState(isOnline: isOnline);
  }

  @override
  Future<bool> checkConnectivity() async => state.isOnline;
}

void main() {
  group('OfflineSyncBadge Widget Tests', () {
    testWidgets('Renders empty/shrink when online and 0 pending items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            deadSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            connectivityProvider.overrideWith((ref) => FakeConnectivityNotifier(isOnline: true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineSyncBadge(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('Renders badge with count when pendingCount > 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(3)),
            deadSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            connectivityProvider.overrideWith((ref) => FakeConnectivityNotifier(isOnline: true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineSyncBadge(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('3 chờ'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

      // Tap badge to open modal
      await tester.tap(find.text('3 chờ'));
      await tester.pumpAndSettle();

      expect(find.text('Dữ liệu ngoại tuyến'), findsOneWidget);
      expect(find.text('Đang chờ gửi'), findsOneWidget);
    });

    testWidgets('Renders offline warning when device is offline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            deadSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            connectivityProvider.overrideWith((ref) => FakeConnectivityNotifier(isOnline: false)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineSyncBadge(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Ngoại tuyến'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('Modal accurately identifies customer entity as "Thêm khách hàng mới" and not check-in', (tester) async {
      final customerEntry = SyncQueueEntry(
        id: 1,
        entity: 'customer',
        op: 'create',
        clientUuid: 'test-uuid-123',
        parentUuid: null,
        payload: '{"name":"Đại lý Sơn Hà","address":"123 Nguyễn Huệ","route":"Tuyến 1"}',
        localPath: null,
        state: 'pending',
        attempts: 0,
        nextAttemptAt: null,
        lastError: null,
        createdAt: 1000,
        createdElapsed: 1000,
        bootId: 'boot1',
        serverId: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(1)),
            deadSyncCountProvider.overrideWith((ref) => Stream.value(0)),
            allPendingQueueEntriesProvider.overrideWith((ref) => Stream.value([customerEntry])),
            connectivityProvider.overrideWith((ref) => FakeConnectivityNotifier(isOnline: false)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineSyncBadge(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1 chờ'), findsOneWidget);

      await tester.tap(find.text('1 chờ'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm khách hàng mới: Đại lý Sơn Hà'), findsOneWidget);
      expect(find.textContaining('Tuyến: Tuyến 1'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      expect(find.textContaining('Lượt check-in & toạ độ'), findsNothing);
    });
  });
}

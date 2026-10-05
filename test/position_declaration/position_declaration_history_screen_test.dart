import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_declaration_entity.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_reason_entity.dart';
import 'package:vthm_dms/features/position_declaration/presentation/screens/position_declaration_history_screen.dart';
import 'package:vthm_dms/features/position_declaration/presentation/states/position_declaration_state.dart';
import 'package:vthm_dms/features/position_declaration/presentation/viewmodels/position_declaration_view_model.dart';

class MockPositionDeclarationViewModel
    extends StateNotifier<PositionDeclarationState>
    implements PositionDeclarationViewModel {
  MockPositionDeclarationViewModel(super.state);

  bool loadHistoryCalled = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> loadReasons({bool forceRefresh = false}) async {}

  @override
  Future<void> loadHistory() async {
    loadHistoryCalled = true;
  }

  @override
  void clearMessage() {}

  @override
  void selectReason(PositionReasonEntity reason) {}

  @override
  Future<void> fetchCurrentLocation(BuildContext? context) async {}

  @override
  void setLocation({
    required double lat,
    required double lng,
    String? address,
    double? accuracyM,
  }) {}

  @override
  void clearLocation() {}

  @override
  Future<bool> takePhotoFromCamera() async => false;

  @override
  void removePhoto(int index) {}

  @override
  void updateAddress(String address) {}

  @override
  void setPhotoRequiredError() {}

  @override
  Future<(bool success, String? message)> submitDeclaration({
    String? title,
    String? note,
  }) async =>
      (true, null);

  @override
  Future<(bool success, String? message)> retryDeclarationWithNewReason(
    dynamic failedDeclaration,
    PositionReasonEntity newReason,
  ) async =>
      (true, null);
}

void main() {
  group('PositionDeclarationHistoryScreen Tests', () {
    testWidgets('Renders empty state when history is empty', (tester) async {
      final mockVm = MockPositionDeclarationViewModel(
        const PositionDeclarationState(history: []),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            positionDeclarationViewModelProvider.overrideWith((ref) => mockVm),
          ],
          child: const MaterialApp(
            home: PositionDeclarationHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lịch sử khai báo vị trí'), findsOneWidget);
      expect(find.text('Chưa có lượt khai báo vị trí nào'), findsOneWidget);
      expect(find.text('Khai báo vị trí ngay'), findsOneWidget);
      expect(find.text('Tổng số lượt'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Renders history list with correct data and filter chips',
        (tester) async {
      final declarations = [
        const PositionDeclarationEntity(
          id: 101,
          clientUuid: 'uuid-1',
          reasonId: 1,
          reasonCode: 'GAP_KH',
          reasonName: 'Gặp khách hàng phát sinh',
          reasonColor: '#0D9488',
          lat: 10.7725,
          lng: 106.6980,
          accuracyM: 5.0,
          address: '123 Lê Lợi, Quận 1, TP.HCM',
          title: 'Khảo sát thêm quầy',
          note: 'Gặp anh Nam trao đổi',
          clientTime: '2026-10-03T08:30:00.000',
          createdAtMs: 1790991000000,
          syncStatus: 'synced',
        ),
        const PositionDeclarationEntity(
          id: null,
          clientUuid: 'uuid-2',
          reasonId: 2,
          reasonCode: 'SUA_XE',
          reasonName: 'Hỏng xe trên đường',
          reasonColor: '#F59E0B',
          lat: 10.7800,
          lng: 106.7000,
          accuracyM: 12.0,
          address: '456 Hai Bà Trưng, Quận 3',
          title: 'Vá xăm xe',
          clientTime: '2026-10-03T10:15:00.000',
          createdAtMs: 1790998000000,
          syncStatus: 'pending',
        ),
      ];

      final mockVm = MockPositionDeclarationViewModel(
        PositionDeclarationState(history: declarations),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            positionDeclarationViewModelProvider.overrideWith((ref) => mockVm),
          ],
          child: const MaterialApp(
            home: PositionDeclarationHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check summary
      expect(find.text('2'), findsWidgets); // Total 2
      expect(find.text('1'), findsWidgets); // 1 synced, 1 pending

      // Check card 1
      expect(find.text('[GAP_KH] Gặp khách hàng phát sinh'), findsOneWidget);
      expect(find.text('123 Lê Lợi, Quận 1, TP.HCM'), findsOneWidget);
      expect(find.text('Đã đồng bộ (#101)'), findsOneWidget);
      expect(find.text('Khảo sát thêm quầy'), findsOneWidget);

      // Check card 2
      expect(find.text('[SUA_XE] Hỏng xe trên đường'), findsOneWidget);
      expect(find.text('456 Hai Bà Trưng, Quận 3'), findsOneWidget);
      expect(find.text('Chờ đồng bộ'), findsWidgets);

      // Tap card 1 to open detail bottom sheet
      await tester.tap(find.text('[GAP_KH] Gặp khách hàng phát sinh'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết lượt khai báo'), findsOneWidget);
      expect(find.text('uuid-1'), findsOneWidget);
      expect(find.text('Độ chính xác GPS'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test filter: Tap "Chờ gửi (1)"
      await tester.tap(find.text('Chờ gửi (1)'));
      await tester.pumpAndSettle();

      expect(find.text('[SUA_XE] Hỏng xe trên đường'), findsOneWidget);
      expect(find.text('[GAP_KH] Gặp khách hàng phát sinh'), findsNothing);
    });
  });
}

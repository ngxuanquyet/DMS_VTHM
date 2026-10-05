import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_reason_entity.dart';
import 'package:vthm_dms/features/position_declaration/presentation/screens/position_declaration_screen.dart';
import 'package:vthm_dms/features/position_declaration/presentation/states/position_declaration_state.dart';
import 'package:vthm_dms/features/position_declaration/presentation/viewmodels/position_declaration_view_model.dart';

class FakePositionDeclarationViewModel
    extends StateNotifier<PositionDeclarationState>
    implements PositionDeclarationViewModel {
  FakePositionDeclarationViewModel(super.state);

  bool submitCalled = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> loadReasons({bool forceRefresh = false}) async {}

  @override
  void clearMessage() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  @override
  void selectReason(PositionReasonEntity reason) {
    state = state.copyWith(selectedReason: reason);
  }

  @override
  Future<void> fetchCurrentLocation(BuildContext? context) async {}

  @override
  void setLocation({
    required double lat,
    required double lng,
    String? address,
    double? accuracyM,
  }) {
    state = state.copyWith(lat: lat, lng: lng, address: address);
  }

  @override
  void clearLocation() {
    state = state.copyWith(lat: null, lng: null, address: null);
  }

  @override
  Future<bool> takePhotoFromCamera() async => false;

  @override
  void removePhoto(int index) {}

  @override
  void updateAddress(String address) {}

  @override
  void setPhotoRequiredError() {
    state = state.copyWith(
      errorMessage:
          'Vui lòng chụp ít nhất 1 ảnh chứng minh trước khi gửi khai báo.',
    );
  }

  @override
  Future<(bool success, String? message)> submitDeclaration({
    String? title,
    String? note,
  }) async {
    if (state.photos.isEmpty) {
      const msg =
          'Vui lòng chụp ít nhất 1 ảnh chứng minh trước khi gửi khai báo.';
      state = state.copyWith(errorMessage: msg);
      return (false, msg);
    }
    submitCalled = true;
    return (true, 'Thành công');
  }

  @override
  Future<(bool success, String? message)> retryDeclarationWithNewReason(
    dynamic failedDeclaration,
    PositionReasonEntity newReason,
  ) async =>
      (true, null);

  @override
  Future<void> loadHistory() async {}
}

void main() {
  testWidgets(
      'PositionDeclarationScreen displays "Ảnh chụp chứng minh" and requires photo on submit',
      (tester) async {
    final fakeVm = FakePositionDeclarationViewModel(
      const PositionDeclarationState(
        selectedReason: PositionReasonEntity(
          id: 1,
          code: '001',
          name: 'Công tác ngoại tỉnh',
        ),
        lat: 10.7725,
        lng: 106.6980,
        address: 'Quận 1, TP.HCM',
        photos: [], // Không có ảnh nào
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          positionDeclarationViewModelProvider.overrideWith((ref) => fakeVm),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PositionDeclarationScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề: Phải là "3. Ảnh chụp chứng minh", KHÔNG CÒN "Ảnh chụp hiện trường"
    expect(find.text('3. Ảnh chụp chứng minh'), findsOneWidget);
    expect(find.textContaining('Ảnh chụp hiện trường'), findsNothing);

    // 2. Kiểm tra gợi ý bắt buộc ảnh
    expect(
      find.text('Bắt buộc chụp ít nhất 1 ảnh\nchứng minh tại địa điểm'),
      findsOneWidget,
    );

    // 3. Cuộn xuống nút "GỬI KHAI BÁO VỊ TRÍ" và nhấn gửi khi chưa có ảnh
    final submitButtonFinder = find.text('GỬI KHAI BÁO VỊ TRÍ');
    await tester.ensureVisible(submitButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitButtonFinder);
    await tester.pumpAndSettle();

    // 4. Phải báo lỗi yêu cầu chụp ảnh, KHÔNG ĐƯỢC submit
    expect(fakeVm.submitCalled, isFalse);
    expect(
      find.text('Vui lòng chụp ít nhất 1 ảnh chứng minh trước khi gửi khai báo.'),
      findsWidgets,
    );
  });
}

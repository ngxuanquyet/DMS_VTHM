import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/auth/domain/entities/user_entity.dart';
import 'package:vthm_dms/features/forms/domain/entities/form_entity.dart';
import 'package:vthm_dms/main.dart';

void main() {
  testWidgets('VthmApp renders and pumps splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VthmApp(),
      ),
    );

    expect(find.byType(VthmApp), findsOneWidget);
    // Allow splash timer to complete
    await tester.pump(const Duration(seconds: 3));
  });

  test('UserEntity initializes correctly', () {
    const user = UserEntity(
      id: '1',
      name: 'Nguyen Van An',
      employeeId: 'NV00128',
      role: 'Sales Rep',
      region: 'Vinh Phuc',
      avatarUrl: AppConstants.userAvatarUrl,
      email: 'an.nv@vthm.vn',
      phone: '0912345678',
    );

    expect(user.name, 'Nguyen Van An');
    expect(user.employeeId, 'NV00128');
  });

  test('FormItemEntity initializes correctly', () {
    const form = FormItemEntity(
      id: 'FORM-01',
      title: 'Khảo sát điểm bán',
      dealerName: 'Đại lý Thành Công',
      deadline: '17:00',
      status: FormStatusType.todo,
      statusLabel: 'Chưa thực hiện',
      questionsCount: 8,
      answeredCount: 0,
      progressPercent: 0.0,
    );

    expect(form.questionsCount, 8);
    expect(form.status, FormStatusType.todo);
  });
}

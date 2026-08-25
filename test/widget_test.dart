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
      id: '2461',
      username: 'VTG926',
      employeeCode: 'VTG926',
      displayName: 'Nguyễn Xuân Quyết',
      jobTitle: 'Nhân viên Quản lý Hệ thống thông tin (MIS)',
      avatarUrl: AppConstants.userAvatarUrl,
      email: 'quyetnx@vthmgroup.vn',
    );

    expect(user.name, 'Nguyễn Xuân Quyết');
    expect(user.employeeId, 'VTG926');
    expect(user.username, 'VTG926');
    expect(user.displayName, 'Nguyễn Xuân Quyết');
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

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../services/home_api_service.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeApiService _apiService;

  HomeRepositoryImpl(this._apiService);

  @override
  Future<DashboardEntity> getDashboardData() async {
    final model = await _apiService.getDashboardData();
    var entity = model.toEntity();

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.keyUserData);
    if (userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(map);
        final displayName = user.displayName.isNotEmpty ? user.displayName : user.username;
        final role = user.jobTitle.isNotEmpty ? user.jobTitle : 'Nhân viên';

        if (displayName.isNotEmpty) {
          entity = DashboardEntity(
            greeting: DashboardGreetingEntity(
              userName: displayName,
              role: role,
              currentDate: entity.greeting.currentDate,
            ),
            attendance: entity.attendance,
            routeSummary: entity.routeSummary,
            formSummary: entity.formSummary,
            recentActivities: entity.recentActivities,
          );
        }
      } catch (_) {}
    }

    return entity;
  }
}

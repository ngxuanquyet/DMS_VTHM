import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/visit_entity.dart';
import '../../domain/entities/visit_photo_entity.dart';
import '../../domain/entities/visit_requirements_entity.dart';
import '../../domain/repositories/visit_repository.dart';
import '../models/checkin_request_model.dart';
import '../models/checkout_request_model.dart';
import '../services/visit_api_service.dart';

final visitApiServiceProvider = Provider<VisitApiService>((ref) {
  return VisitApiService(ref.watch(apiClientProvider));
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepositoryImpl(ref.watch(visitApiServiceProvider));
});

class VisitRepositoryImpl implements VisitRepository {
  final VisitApiService _apiService;
  static const String _activeVisitKey = 'dms_active_visit_session_v1';

  VisitRepositoryImpl(this._apiService);

  @override
  Future<List<VisitEntity>> getTodayVisits() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _apiService.getMyVisits(
      dateFrom: today,
      dateTo: today,
      perPage: 100,
    );
  }

  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) async {
    final visit = await _apiService.checkin(request);
    await saveActiveVisit(visit);
    return visit;
  }

  @override
  Future<VisitRequirementsEntity> getRequirements(
    int visitId, {
    String? visitResult,
  }) {
    return _apiService.getRequirements(visitId, visitResult: visitResult);
  }

  @override
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) {
    return _apiService.uploadPhoto(
      visitId: visitId,
      file: file,
      photoType: photoType,
      takenAt: takenAt,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<VisitRequirementsEntity> deletePhoto({
    required int visitId,
    required int photoId,
  }) {
    return _apiService.deletePhoto(visitId: visitId, photoId: photoId);
  }

  @override
  Future<VisitEntity> checkout({
    required int visitId,
    required CheckoutRequestModel request,
  }) async {
    final result = await _apiService.checkout(
      visitId: visitId,
      request: request,
    );
    await clearActiveVisit();
    return result;
  }

  @override
  Future<void> cancelVisit(int visitId) async {
    await _apiService.cancelVisit(visitId);
    await clearActiveVisit();
  }

  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeVisitKey, jsonEncode(visit.toJson()));
    } catch (_) {}
  }

  @override
  Future<VisitEntity?> getActiveVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeVisitKey);
      if (raw != null && raw.isNotEmpty) {
        return VisitEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearActiveVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeVisitKey);
    } catch (_) {}
  }
}

import 'dart:io';
import '../../data/models/checkin_request_model.dart';
import '../../data/models/checkout_request_model.dart';
import '../entities/visit_entity.dart';
import '../entities/visit_photo_entity.dart';
import '../entities/visit_requirements_entity.dart';

abstract class VisitRepository {
  /// Lấy danh sách lượt viếng thăm hôm nay (§2.3)
  Future<List<VisitEntity>> getTodayVisits();

  /// Thực hiện check-in (§3)
  Future<VisitEntity> checkin(CheckinRequestModel request);

  /// Lấy danh sách yêu cầu check-out hiện tại (§6)
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult});

  /// Tải ảnh lên cho lượt viếng thăm (§4.1)
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  });

  /// Xoá ảnh chụp lỗi của lượt viếng thăm (§4.2)
  Future<VisitRequirementsEntity> deletePhoto({
    required int visitId,
    required int photoId,
  });

  /// Check-out đóng lượt viếng thăm (§7)
  Future<VisitEntity> checkout({
    required int visitId,
    required CheckoutRequestModel request,
  });

  /// Huỷ lượt viếng thăm (§3.4 HUY-LUOT-VIENG-THAM-2026-09-30)
  Future<void> cancelVisit(int visitId, {String? clientUuid});

  /// Xoá lượt viếng thăm khỏi bộ nhớ máy (khi huỷ lượt offline chưa đồng bộ)
  Future<void> removeLocalVisit(int visitId, {String? clientUuid});

  /// Quản lý phiên viếng thăm cục bộ (chống mất khi restart app)
  Future<void> saveActiveVisit(VisitEntity visit);
  Future<VisitEntity?> getActiveVisit();
  Future<void> clearActiveVisit();

  /// Lấy danh sách lượt viếng thăm theo ngày (hỗ trợ offline-first và đồng bộ)
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false});

  /// Lấy toàn bộ lượt viếng thăm lưu trong bộ nhớ máy
  Future<List<VisitEntity>> getAllLocalVisits();

  /// Lưu hoặc cập nhật 1 lượt viếng thăm vào bộ nhớ máy
  Future<void> saveLocalVisit(VisitEntity visit);

  /// Lưu danh sách lượt viếng thăm vào bộ nhớ máy
  Future<void> saveLocalVisits(List<VisitEntity> visits);
}

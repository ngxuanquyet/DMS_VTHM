import '../../data/models/market_form_submission_model.dart';
import '../entities/market_form_entity.dart';

abstract class FormsRepository {
  /// Lấy danh sách biểu mẫu khả dụng (hỗ trợ online và offline cache fallback)
  Future<List<MarketFormConfigEntity>> getAvailableForms({
    required String kind,
    int? customerId,
  });

  /// Nộp phiếu biểu mẫu thị trường (nếu offline thì ghi nhận vào SQLite SyncQueueEntries)
  Future<MarketFormSubmitResult> submitForm(
    MarketFormSubmissionModel submission, {
    bool isOffline = false,
  });

  /// Tải 1 tấm ảnh lên nhận token 32-hex theo đặc tả §2 (POST /dms/form-photos)
  Future<dynamic> uploadPhoto(dynamic file);
}

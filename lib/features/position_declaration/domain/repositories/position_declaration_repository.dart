import 'dart:io';
import '../entities/position_reason_entity.dart';
import '../entities/position_declaration_entity.dart';

abstract class PositionDeclarationRepository {
  /// Lấy danh mục lý do đang bật (§2) - có cache cục bộ khi offline
  Future<List<PositionReasonEntity>> getActiveReasons({bool forceRefresh = false});

  /// Tải 1 ảnh lên máy chủ (§3) - trả về token 32-hex
  Future<String> uploadPhoto(File file);

  /// Gửi khai báo vị trí (§4) - tự động lưu hàng đợi offline nếu mất mạng/sự cố
  Future<PositionDeclarationEntity> submitDeclaration(
    PositionDeclarationEntity declaration,
  );

  /// Lấy danh sách lịch sử khai báo vị trí lưu trên máy (§8)
  Future<List<PositionDeclarationEntity>> getLocalDeclarations();

  /// Lưu hoặc cập nhật một bản ghi khai báo trên máy
  Future<void> saveLocalDeclaration(PositionDeclarationEntity declaration);

  /// Cập nhật trạng thái đồng bộ cho bản ghi khai báo
  Future<void> updateLocalDeclarationStatus(
    String clientUuid, {
    required String syncStatus,
    int? serverId,
    String? declaredAt,
    String? declaredDate,
    String? error,
  });
}

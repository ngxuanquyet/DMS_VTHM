import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/position_declaration/data/models/position_declaration_request_model.dart';
import 'package:vthm_dms/features/position_declaration/data/models/position_photo_response_model.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_declaration_entity.dart';
import 'package:vthm_dms/features/position_declaration/domain/entities/position_reason_entity.dart';

void main() {
  group('PositionReasonEntity Spec Tests (§2)', () {
    test('Correctly parses active reasons from backend JSON', () {
      final json = {
        "id": 1,
        "code": "001",
        "name": "Công tác ngoại tỉnh",
        "color": "primary"
      };

      final reason = PositionReasonEntity.fromJson(json);

      expect(reason.id, 1);
      expect(reason.code, "001");
      expect(reason.name, "Công tác ngoại tỉnh");
      expect(reason.color, "primary");
      expect(reason.displayName, "[001] Công tác ngoại tỉnh");
    });

    test('Handles null color and maps Bootstrap colors properly', () {
      final json = {
        "id": 2,
        "code": "002",
        "name": "Phối hợp giải quyết công việc ngoài tuyến",
        "color": null
      };

      final reason = PositionReasonEntity.fromJson(json);
      expect(reason.id, 2);
      expect(reason.color, isNull);
      expect(reason.displayName, "[002] Phối hợp giải quyết công việc ngoài tuyến");
      expect(reason.colorValue, isNotNull);
    });
  });

  group('PositionPhotoResponseModel Spec Tests (§3)', () {
    test('Parses photo upload response accurately', () {
      final json = {
        "token": "26602804093aa75356b8613f6c5629c7",
        "name": "anh1.jpg",
        "ext": "jpg",
        "size": 709,
        "mime": "image/jpeg",
        "url": "/dms/position-photos/public/26602804093aa75356b8613f6c5629c7"
      };

      final photo = PositionPhotoResponseModel.fromJson(json);

      expect(photo.token, "26602804093aa75356b8613f6c5629c7");
      expect(photo.name, "anh1.jpg");
      expect(photo.ext, "jpg");
      expect(photo.size, 709);
      expect(photo.mime, "image/jpeg");
      expect(photo.url, "/dms/position-photos/public/26602804093aa75356b8613f6c5629c7");
    });
  });

  group('PositionDeclarationRequestModel Spec Tests (§4.1)', () {
    test('Serializes request body matching exact server schema with NO km_declared', () {
      const request = PositionDeclarationRequestModel(
        reasonId: 1,
        lat: 10.7725,
        lng: 106.6980,
        photoTokens: ["26602804093aa75356b8613f6c5629c7"],
        title: "Công tác chi nhánh Cần Thơ",
        address: "123 Đường 3/2, Cần Thơ",
        accuracyM: 8.5,
        note: "Ghi chú công việc",
        isMockLocation: false,
        clientUuid: "c56a4180-65aa-42ec-a945-5fd21dec0538",
        clientTime: "2026-10-01T10:27:49.000+07:00",
        isOfflineSync: false,
      );

      final json = request.toJson();

      expect(json['reason_id'], 1);
      expect(json['lat'], 10.7725);
      expect(json['lng'], 106.6980);
      expect(json['photo_tokens'], ["26602804093aa75356b8613f6c5629c7"]);
      expect(json['title'], "Công tác chi nhánh Cần Thơ");
      expect(json['address'], "123 Đường 3/2, Cần Thơ");
      expect(json['note'], "Ghi chú công việc");
      expect(json['is_mock_location'], false);
      expect(json['client_uuid'], "c56a4180-65aa-42ec-a945-5fd21dec0538");
      expect(json['client_time'], "2026-10-01T10:27:49.000+07:00");
      expect(json['is_offline_sync'], isNull);

      // 🔴 BẢO ĐẢM GỬI accuracy_m ĐÚNG BẢNG §4.1 VÀ TUYỆT ĐỐI KHÔNG CÓ km_declared
      expect(json['accuracy_m'], 8.5);
      expect(json.containsKey('km_declared'), isFalse);
    });

    test('Includes offline sync parameters when queued offline (§5.1)', () {
      const request = PositionDeclarationRequestModel(
        reasonId: 2,
        lat: 10.0452,
        lng: 105.7469,
        photoTokens: ["token1"],
        clientUuid: "uuid-offline-1",
        clientTime: "2026-10-01T09:00:00.000+07:00",
        isOfflineSync: true,
        queuedSeconds: 5400,
        clientBootId: "boot-id-1234",
      );

      final json = request.toJson();

      expect(json['is_offline_sync'], isTrue);
      expect(json['queued_seconds'], 5400);
      expect(json['client_boot_id'], "boot-id-1234");
      expect(json.containsKey('km_declared'), isFalse);
    });
  });

  group('Offline Monotonic Clock & Boot ID Tests (§5.1)', () {
    test('Calculates queued_seconds using monotonic clock when same bootId', () {
      final currentBootId = SystemClock.bootId;
      final monotonicNow = SystemClock.nowMonotonicMs;
      final createdElapsedMs = monotonicNow - 60000; // 60 giây trước

      final queued = SystemClock.calculateQueuedSeconds(
        createdElapsedMs: createdElapsedMs,
        entryBootId: currentBootId,
      );

      expect(queued, isNotNull);
      expect(queued, inInclusiveRange(59, 62));
    });

    test('Sends queued_seconds as null (empty) if device rebooted (different bootId)', () {
      final differentBootId = "different-boot-id-5678";
      final monotonicNow = SystemClock.nowMonotonicMs;
      final createdElapsedMs = monotonicNow - 60000;

      final queued = SystemClock.calculateQueuedSeconds(
        createdElapsedMs: createdElapsedMs,
        entryBootId: differentBootId,
      );

      // Theo §5.1: Nếu reboot máy thì gửi RỖNG (null) để server không dựng sai mốc
      expect(queued, isNull);
    });
  });

  group('PositionDeclarationEntity & History Serialization (§8)', () {
    test('PositionDeclarationEntity converts to and from JSON preserving all fields', () {
      const entity = PositionDeclarationEntity(
        id: 20157,
        clientUuid: "uuid-test-999",
        reasonId: 1,
        reasonCode: "001",
        reasonName: "Công tác ngoại tỉnh",
        reasonColor: "primary",
        lat: 10.7725,
        lng: 106.6980,
        accuracyM: 5.0,
        address: "Quận 1, TP.HCM",
        title: "Họp ban giám đốc",
        note: "Đã hoàn thành",
        photoTokens: ["token123"],
        localPhotoPaths: ["/path/to/photo.jpg"],
        isMockLocation: false,
        clientTime: "2026-10-01T10:27:49.000+07:00",
        declaredAt: "2026-10-01 10:27:49+07",
        declaredDate: "2026-10-01",
        syncStatus: "synced",
        createdAtMs: 1727772469000,
      );

      final json = entity.toJson();
      final restored = PositionDeclarationEntity.fromJson(json);

      expect(restored.id, 20157);
      expect(restored.clientUuid, "uuid-test-999");
      expect(restored.reasonId, 1);
      expect(restored.reasonCode, "001");
      expect(restored.reasonName, "Công tác ngoại tỉnh");
      expect(restored.reasonDisplay, "[001] Công tác ngoại tỉnh");
      expect(restored.lat, 10.7725);
      expect(restored.lng, 106.6980);
      expect(restored.accuracyM, 5.0);
      expect(restored.address, "Quận 1, TP.HCM");
      expect(restored.title, "Họp ban giám đốc");
      expect(restored.note, "Đã hoàn thành");
      expect(restored.photoTokens, ["token123"]);
      expect(restored.localPhotoPaths, ["/path/to/photo.jpg"]);
      expect(restored.clientTime, "2026-10-01T10:27:49.000+07:00");
      expect(restored.declaredAt, "2026-10-01 10:27:49+07");
      expect(restored.declaredDate, "2026-10-01");
      expect(restored.syncStatus, "synced");
      expect(restored.isSynced, isTrue);
      expect(restored.isPending, isFalse);
      expect(restored.hasError, isFalse);
    });

    test('Handles error status and reason discontinued replacement (§5.3)', () {
      const failed = PositionDeclarationEntity(
        clientUuid: "uuid-failed-1",
        reasonId: 3,
        reasonCode: "003",
        reasonName: "Thăm viếng khách hàng",
        lat: 10.7725,
        lng: 106.6980,
        clientTime: "2026-10-01T10:00:00.000+07:00",
        syncStatus: "error",
        syncError: 'Lý do "Thăm viếng khách hàng" đã ngừng sử dụng. Hãy chọn lý do khác.',
        createdAtMs: 1727772000000,
      );

      expect(failed.hasError, isTrue);
      expect(failed.syncError, contains('đã ngừng sử dụng'));

      // Đổi sang lý do mới đang bật
      const newReason = PositionReasonEntity(
        id: 1,
        code: "001",
        name: "Công tác ngoại tỉnh",
      );

      final updated = failed.copyWith(
        reasonId: newReason.id,
        reasonCode: newReason.code,
        reasonName: newReason.name,
        syncStatus: "pending",
        clearSyncError: true,
      );

      expect(updated.reasonId, 1);
      expect(updated.reasonCode, "001");
      expect(updated.reasonName, "Công tác ngoại tỉnh");
      expect(updated.syncStatus, "pending");
      expect(updated.syncError, isNull);
    });
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../rules/mobile_rules_service.dart';
import '../utils/system_clock.dart';
import '../widgets/anti_fraud_warning_dialog.dart';

enum RiskSeverity { normal, warning, critical }

enum AntiFraudActionType {
  attendance,
  visitCheckin,
  visitCheckout,
  positionDeclaration,
  offlineSync,
}

class ComplianceRiskItem {
  final String title;
  final String description;
  final RiskSeverity severity;
  final String ruleReference;

  const ComplianceRiskItem({
    required this.title,
    required this.description,
    required this.severity,
    required this.ruleReference,
  });

  bool get isNormal => severity == RiskSeverity.normal;
}

class ComplianceReport {
  final bool isCompliant;
  final bool hasMockGps;
  final bool hasClockSkew;
  final int clockSkewMinutes;
  final List<ComplianceRiskItem> risks;

  const ComplianceReport({
    required this.isCompliant,
    required this.hasMockGps,
    required this.hasClockSkew,
    this.clockSkewMinutes = 0,
    required this.risks,
  });
}

class FraudCheckResult {
  final bool isAllowed;
  final bool hasMockGps;
  final bool hasClockSkew;
  final int clockSkewMinutes;
  final String? errorMessage;
  final String? warningMessage;

  const FraudCheckResult({
    required this.isAllowed,
    this.hasMockGps = false,
    this.hasClockSkew = false,
    this.clockSkewMinutes = 0,
    this.errorMessage,
    this.warningMessage,
  });

  bool get isClean => !hasMockGps && !hasClockSkew;
}

final antiFraudServiceProvider = Provider<AntiFraudService>((ref) {
  return AntiFraudService(ref);
});

/// Dịch vụ quản trị rủi ro & chống gian lận thị trường
/// Tuân thủ quy tắc §1 GET /dms/mobile-rules (API-THAY-DOI-CHO-MOBILE-2026-10-01.md)
class AntiFraudService {
  final Ref _ref;

  AntiFraudService(this._ref);

  // ===========================================================================
  // 1. QUẢN LÝ MỐC THỜI GIAN MÁY CHỦ (SERVER TIME) & ĐO CLOCK SKEW
  // ===========================================================================

  static DateTime? _lastServerTimeUtc;
  static int? _lastServerTimeMonotonicMs;
  static bool _hasWarnedOnCurrentSession = false;

  /// Đặt lại trạng thái đã cảnh báo trong phiên làm việc
  static void resetSessionWarning() {
    _hasWarnedOnCurrentSession = false;
  }

  /// Ghi nhận mốc thời gian máy chủ từ HTTP header Date hoặc phản hồi API
  static void recordServerTime(DateTime serverTime) {
    _lastServerTimeUtc = serverTime.toUtc();
    _lastServerTimeMonotonicMs = SystemClock.nowMonotonicMs;
  }

  /// Lấy mốc thời gian máy chủ đã ghi nhận gần nhất
  static DateTime? get lastServerTimeUtc => _lastServerTimeUtc;

  /// Tính toán độ lệch đồng hồ máy so với máy chủ (tính bằng phút)
  /// Sử dụng đồng hồ đơn điệu Monotonic Stopwatch để không bị ảnh hưởng khi user đổi giờ máy.
  static int getEstimatedClockSkewMinutes() {
    if (_lastServerTimeUtc == null || _lastServerTimeMonotonicMs == null) {
      return 0; // Chưa có mốc đối chiếu máy chủ
    }

    final elapsedMs = SystemClock.nowMonotonicMs - _lastServerTimeMonotonicMs!;
    if (elapsedMs < 0) return 0;

    // Thời gian máy chủ ước tính ở hiện tại
    final estimatedServerTimeUtc = _lastServerTimeUtc!.add(Duration(milliseconds: elapsedMs));
    final currentClientTimeUtc = DateTime.now().toUtc();

    final diffMs = currentClientTimeUtc.difference(estimatedServerTimeUtc).inMilliseconds;
    return (diffMs / 60000).round();
  }

  /// Kiểm tra xem hiện tại đồng hồ máy có bị lệch quá ngưỡng không
  bool isClockSkewExceeded() {
    final rules = _ref.read(mobileRulesProvider);
    final toleranceMinutes = rules.clock.skewToleranceMinutes;
    final skewMinutes = getEstimatedClockSkewMinutes();
    return skewMinutes.abs() > toleranceMinutes;
  }

  // ===========================================================================
  // 2. KIỂM TRA TOÀN DIỆN TÍNH TOÀN VẸN THIẾT BỊ
  // ===========================================================================

  /// Kiểm tra toàn diện tính toàn vẹn của thiết bị và toạ độ
  Future<ComplianceReport> checkDeviceCompliance({Position? position}) async {
    final rules = _ref.read(mobileRulesProvider);
    final risks = <ComplianceRiskItem>[];

    // 1. Kiểm tra GPS giả lập (Mock Location)
    bool hasMock = false;
    if (position != null && position.isMocked) {
      hasMock = true;
      final isBlocked = rules.visit.blockOnMockLocation || rules.position.blockOnMockLocation;
      risks.add(ComplianceRiskItem(
        title: 'Phát hiện toạ độ giả lập (Mock Location)',
        description: isBlocked
            ? 'Thiết bị đang bật phần mềm giả lập GPS. Hệ thống sẽ TỪ CHỐI ghi nhận lượt viếng thăm/khai báo.'
            : 'Thiết bị đang bật toạ độ giả lập. Bản ghi sẽ bị gắn cờ kiểm toán nghi vấn.',
        severity: isBlocked ? RiskSeverity.critical : RiskSeverity.warning,
        ruleReference: 'block_on_mock_location: $isBlocked',
      ));
    } else {
      risks.add(const ComplianceRiskItem(
        title: 'Toạ độ GPS (Mock Location)',
        description: 'Bình thường - Không phát hiện ứng dụng can thiệp toạ độ',
        severity: RiskSeverity.normal,
        ruleReference: 'position.isMocked: false',
      ));
    }

    // 2. Kiểm tra lệch đồng hồ máy (Clock Skew)
    final toleranceMinutes = rules.clock.skewToleranceMinutes;
    final skewMinutes = getEstimatedClockSkewMinutes();
    bool hasSkew = skewMinutes.abs() > toleranceMinutes;

    if (hasSkew) {
      risks.add(ComplianceRiskItem(
        title: 'Lệch giờ hệ thống (Clock Skew)',
        description: 'Đồng hồ thiết bị lệch $skewMinutes phút (vượt ngưỡng cho phép $toleranceMinutes phút). Bản ghi sẽ bị gắn cờ nghi vấn.',
        severity: RiskSeverity.warning,
        ruleReference: 'clock.skew_tolerance_minutes: $toleranceMinutes',
      ));
    } else {
      final skewDesc = skewMinutes == 0
          ? 'Chuẩn xác - Đồng bộ theo múi giờ mạng và máy chủ'
          : 'Bình thường - Lệch $skewMinutes phút (trong ngưỡng cho phép $toleranceMinutes phút)';
      risks.add(ComplianceRiskItem(
        title: 'Đồng hồ thiết bị (Clock Skew)',
        description: skewDesc,
        severity: RiskSeverity.normal,
        ruleReference: 'skew_tolerance_minutes: $toleranceMinutes',
      ));
    }

    // 3. Kiểm tra trần hàng đợi ngoại tuyến (Offline max queue hours)
    final maxQueueHours = rules.clock.offlineMaxQueueHours;
    risks.add(ComplianceRiskItem(
      title: 'Hàng đợi ngoại tuyến (Offline Queue Cap)',
      description: 'Trần lưu giữ tối đa $maxQueueHours giờ trước khi tự động cắt về mốc cho phép',
      severity: RiskSeverity.normal,
      ruleReference: 'offline_max_queue_hours: $maxQueueHours',
    ));

    final isCompliant = !hasMock && !hasSkew;

    return ComplianceReport(
      isCompliant: isCompliant,
      hasMockGps: hasMock,
      hasClockSkew: hasSkew,
      clockSkewMinutes: skewMinutes,
      risks: risks,
    );
  }

  // ===========================================================================
  // 3. KIỂM TRA VÀ CẢNH BÁO KHI NHÂN VIÊN VÀO APP
  // ===========================================================================

  /// Kiểm tra và hiển thị cảnh báo ngay khi nhân viên vào ứng dụng (HomeScreen)
  /// Tránh spam người dùng bằng cờ `_hasWarnedOnCurrentSession`
  Future<ComplianceReport> checkAndWarnOnAppEntry(
    BuildContext context, {
    bool forceShow = false,
  }) async {
    // Lấy toạ độ vị trí nhanh nếu có quyền
    Position? pos;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        pos = await Geolocator.getLastKnownPosition();
      }
    } catch (_) {}

    final report = await checkDeviceCompliance(position: pos);

    // Nếu phát hiện gian lận/lệch giờ và chưa cảnh báo trong phiên này
    if ((!report.isCompliant || forceShow) &&
        (!_hasWarnedOnCurrentSession || forceShow) &&
        context.mounted) {
      _hasWarnedOnCurrentSession = true;
      await AntiFraudWarningDialog.showAppEntryWarning(context, report: report);
    }

    return report;
  }

  // ===========================================================================
  // 4. KIỂM TRA TRƯỚC KHI GỬI CÁC REQUEST LIÊN QUAN VỊ TRÍ & THỜI GIAN
  // ===========================================================================

  /// Kiểm tra tính hợp lệ trước khi gửi các request liên quan vị trí, time lên server:
  /// - Chấm công (`POST /attendance/mobile/punch`)
  /// - Check-in viếng thăm (`POST /dms/visits`)
  /// - Check-out viếng thăm (`POST /dms/visits/{id}/checkout`)
  /// - Khai báo vị trí (`POST /dms/position-declarations`)
  ///
  /// Trả về `FraudCheckResult`:
  /// - `isAllowed`: true nếu được phép tiếp tục gửi lên hệ thống; false nếu bị chặn hoặc người dùng huỷ.
  /// - `hasMockGps`: cờ báo toạ độ giả lập.
  /// - `hasClockSkew`: cờ báo lệch giờ máy.
  Future<FraudCheckResult> validateAction(
    BuildContext context, {
    Position? position,
    required AntiFraudActionType actionType,
    required String actionTitle,
  }) async {
    final rules = _ref.read(mobileRulesProvider);

    // 1. Xác định quy tắc chặn theo module
    bool blockOnMock = false;
    switch (actionType) {
      case AntiFraudActionType.attendance:
      case AntiFraudActionType.visitCheckin:
      case AntiFraudActionType.visitCheckout:
        blockOnMock = rules.visit.blockOnMockLocation;
        break;
      case AntiFraudActionType.positionDeclaration:
        blockOnMock = rules.position.blockOnMockLocation;
        break;
      case AntiFraudActionType.offlineSync:
        blockOnMock = rules.visit.blockOnMockLocation || rules.position.blockOnMockLocation;
        break;
    }

    final hasMock = position != null && position.isMocked;
    final skewMinutes = getEstimatedClockSkewMinutes();
    final toleranceMinutes = rules.clock.skewToleranceMinutes;
    final hasSkew = skewMinutes.abs() > toleranceMinutes;

    // A. TRƯỜNG HỢP BỊ CHẶN CỨNG DO MOCK GPS VÀ LUẬT BLOCK BẬT
    if (hasMock && blockOnMock) {
      if (context.mounted) {
        await AntiFraudWarningDialog.showActionBlocked(
          context,
          actionTitle: actionTitle,
          reason: 'Hệ thống phát hiện thiết bị đang sử dụng phần mềm giả lập vị trí (Fake GPS / Mock Location). '
              'Theo quy định vận hành của công ty, thao tác $actionTitle bị TỪ CHỐI.',
          resolution: 'Vui lòng tắt phần mềm giả lập toạ độ hoặc tắt tùy chọn Mock Location trong Cài đặt nhà phát triển trên máy.',
        );
      }
      return FraudCheckResult(
        isAllowed: false,
        hasMockGps: true,
        hasClockSkew: hasSkew,
        clockSkewMinutes: skewMinutes,
        errorMessage: 'Bị từ chối do bật Mock Location',
      );
    }

    // B. TRƯỜNG HỢP CÓ RỦI RO (MOCK GPS NHƯNG KHÔNG CHẶN CỨNG HOẶC LỆCH GIỜ)
    if (hasMock || hasSkew) {
      if (context.mounted) {
        final shouldProceed = await AntiFraudWarningDialog.showActionWarning(
          context,
          actionTitle: actionTitle,
          hasMockGps: hasMock,
          hasClockSkew: hasSkew,
          skewMinutes: skewMinutes,
          toleranceMinutes: toleranceMinutes,
        );

        if (!shouldProceed) {
          return FraudCheckResult(
            isAllowed: false,
            hasMockGps: hasMock,
            hasClockSkew: hasSkew,
            clockSkewMinutes: skewMinutes,
            warningMessage: 'Người dùng đã huỷ thao tác sau khi nhận cảnh báo rủi ro.',
          );
        }
      }
    }

    // C. HỢP LỆ HOẶC ĐÃ XÁC NHẬN CHẤP NHẬN GẮN CỜ GỬI LÊN HỆ THỐNG
    return FraudCheckResult(
      isAllowed: true,
      hasMockGps: hasMock,
      hasClockSkew: hasSkew,
      clockSkewMinutes: skewMinutes,
    );
  }
}

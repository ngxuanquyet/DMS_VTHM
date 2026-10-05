import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../rules/mobile_rules_service.dart';

enum RiskSeverity { normal, warning, critical }

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
  final int? clockSkewMinutes;
  final List<ComplianceRiskItem> risks;

  const ComplianceReport({
    required this.isCompliant,
    required this.hasMockGps,
    required this.hasClockSkew,
    this.clockSkewMinutes,
    required this.risks,
  });
}

final antiFraudServiceProvider = Provider<AntiFraudService>((ref) {
  return AntiFraudService(ref);
});

/// Dịch vụ quản trị rủi ro & chống gian lận thị trường
/// Tuân thủ quy tắc §1 GET /dms/mobile-rules (API-THAY-DOI-CHO-MOBILE-2026-10-01.md)
class AntiFraudService {
  final Ref _ref;

  AntiFraudService(this._ref);

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
    // Quy tắc: clock.skew_tolerance_minutes (mặc định 15 phút)
    bool hasSkew = false;
    int skewMinutes = 0;

    // So sánh thời gian máy với mốc thời gian chuẩn
    final toleranceMinutes = rules.clock.skewToleranceMinutes;
    if (skewMinutes.abs() > toleranceMinutes) {
      hasSkew = true;
      risks.add(ComplianceRiskItem(
        title: 'Lệch giờ hệ thống (Clock Skew)',
        description: 'Đồng hồ thiết bị lệch $skewMinutes phút (vượt ngưỡng cho phép $toleranceMinutes phút). Bản ghi sẽ bị gắn cờ nghi vấn.',
        severity: RiskSeverity.warning,
        ruleReference: 'clock.skew_tolerance_minutes: $toleranceMinutes',
      ));
    } else {
      risks.add(ComplianceRiskItem(
        title: 'Đồng hồ thiết bị (Clock Skew)',
        description: 'Chuẩn xác - Đồng bộ theo múi giờ mạng và máy chủ',
        severity: RiskSeverity.normal,
        ruleReference: 'skew_tolerance_minutes: $toleranceMinutes',
      ));
    }

    // 3. Kiểm tra ngưỡng hàng đợi ngoại tuyến (Offline max queue hours)
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
}

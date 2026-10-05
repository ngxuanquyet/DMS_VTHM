import '../rules/mobile_rules_model.dart';
import '../../features/customer/domain/entities/customer_entity.dart';

/// Tiện ích phân giải quy tắc Geofence động (không fix cứng tham số)
/// Đọc từ cache quy tắc thị trường (dms_mobile_rules_cache_v1) và cấu hình riêng của điểm bán
class GeofenceRuleHelper {
  GeofenceRuleHelper._();

  /// Phân giải bán kính Geofence tối đa (mét) theo phân cấp ưu tiên:
  /// 1. Ưu tiên 1: geofenceRadiusM riêng của Điểm bán / Khách hàng (> 0)
  /// 2. Ưu tiên 2: defaultRadiusM từ Cache quy tắc hệ thống (MobileRules)
  /// 3. Fallback tối hậu: 100 mét khi app vừa cài đặt chưa kịp đọc cache
  static int resolveAllowedRadius({
    dynamic dealer,
    int? dealerRadius,
    CustomerEntity? customer,
    int? explicitRadius,
    required MobileRules? rules,
  }) {
    if (explicitRadius != null && explicitRadius > 0) {
      return explicitRadius;
    }
    if (dealerRadius != null && dealerRadius > 0) {
      return dealerRadius;
    }
    if (dealer != null) {
      try {
        final dynamic d = dealer;
        final r = d.geofenceRadiusM;
        if (r is int && r > 0) return r;
      } catch (_) {}
    }
    final cRadius = customer?.geofenceRadiusM;
    if (cRadius != null && cRadius > 0) {
      return cRadius;
    }
    final defaultRadius = rules?.visit.defaultRadiusM;
    if (defaultRadius != null && defaultRadius > 0) {
      return defaultRadius;
    }
    return 100;
  }

  /// Kiểm tra xem hệ thống có bắt buộc bật Geofence hay không từ cache luật
  static bool isGeofenceRequired(MobileRules? rules) {
    return rules?.visit.requireGeofence ?? true;
  }
}

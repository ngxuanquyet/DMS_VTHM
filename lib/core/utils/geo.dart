import 'dart:math' as math;

/// Khoảng cách đường chim bay (m) — CÙNG công thức haversine + bán kính 6 371 000 m với server
/// (`common/helpers/GeoHelper::distanceMeters`), để phép xét vùng trên máy ra đúng số server sẽ ra. Dùng công thức khác
/// (Vincenty của `Geolocator.distanceBetween`) lệch ~1 m ở biên bán kính là app cho qua rồi server trả 422 sau khi người
/// dùng đã chụp ảnh. Toạ độ không hữu hạn (GPS giả / giả lập) ⇒ `double.nan` — người gọi tự quyết, KHÔNG `.round()` thẳng.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  if (!lat1.isFinite || !lng1.isFinite || !lat2.isFinite || !lng2.isFinite) return double.nan;
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = phi2 - phi1;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final a = (math.sin(dPhi / 2) * math.sin(dPhi / 2) +
          math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2))
      .clamp(0.0, 1.0);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

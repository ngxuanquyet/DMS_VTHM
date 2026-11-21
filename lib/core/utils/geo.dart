import 'dart:math' as math;

/// Khoảng cách đường chim bay (m) — CÙNG công thức haversine + bán kính 6 371 000 m với server
/// (`common/helpers/GeoHelper::distanceMeters`), để phép xét vùng trên máy ra đúng số server sẽ ra. `Geolocator.distanceBetween`
/// là haversine với R = 6 378 137 m (dài hơn ~0,11 %) ⇒ lệch ở biên bán kính: chặn oan check-in, hoặc app cho qua rồi server
/// trả 422 (bán kính tính tròn). MỌI phép so với bán kính server dùng hàm này (#25026); `Geolocator.distanceBetween` chỉ còn ở
/// chỗ hiển thị / sắp xếp / gợi ý gần. Toạ độ không hữu hạn (GPS giả / giả lập) ⇒ `double.nan` — người gọi tự quyết, KHÔNG `.round()` thẳng.
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

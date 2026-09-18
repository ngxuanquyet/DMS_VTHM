/// Cấu hình truy cập Goong Maps REST API v2.
class GoongConfig {
  GoongConfig._();

  /// Gốc của REST API. Goong tách hai dịch vụ: `rsapi` (REST) và `tiles` (bản đồ nền).
  /// Tệp này CHỈ dùng REST.
  static const String baseUrl = 'https://rsapi.goong.io';

  /// Khoá REST API.
  ///
  /// 🔴 Khoá này **nằm trong file cài đặt của app** — mọi khoá bản đồ dùng ở phía client đều vậy, kể cả
  /// Google Maps: ai giải nén được APK là đọc được. Che nó đi không phải là cách bảo vệ. Cách bảo vệ
  /// THẬT là giới hạn khoá ở bảng điều khiển Goong (`https://account.goong.io`): khoá chỉ được gọi từ
  /// package `vn.vthmgroup.dms` (Android) / bundle id (iOS), và đặt trần số lượt gọi mỗi ngày.
  /// Chừng nào chưa đặt giới hạn thì khoá bị lấy = người khác tiêu hết hạn mức của công ty.
  ///
  /// Bản build CI có thể đè bằng `--dart-define=GOONG_API_KEY=...` mà không phải sửa mã nguồn.
  static const String apiKey = String.fromEnvironment(
    'GOONG_API_KEY',
    defaultValue: 'CyaAjiJP8c9HJz89X1dUFsn4n6GsZcr0JqkWN1CF',
  );

  /// Gốc của dịch vụ BẢN ĐỒ NỀN. Khác host với REST — và khác cả KHOÁ.
  static const String tilesUrl = 'https://tiles.goong.io';

  /// Khoá Maptiles (bản đồ nền).
  ///
  /// 🔴 **Đây là khoá KHÁC với [apiKey].** Goong bán hai dịch vụ rời nhau: REST (`rsapi.goong.io`, tìm
  /// địa chỉ / đo đường) và Maptiles (`tiles.goong.io`, vẽ bản đồ). Dùng nhầm khoá thì phía kia trả
  /// **403 `API_KEY_UNAUTHORIZED`** — đã đo cả hai chiều ngày 12/09/2026, không phải suy đoán.
  /// Giới hạn khoá và trần lượt gọi phải đặt RIÊNG cho từng khoá ở `https://account.goong.io`.
  static const String mapTilesKey = String.fromEnvironment(
    'GOONG_MAPTILES_KEY',
    defaultValue: 'RYX1DoMTpdC51GoSy9iGWFtwjDKpj7wWjvSNOydo',
  );

  /// Style Mapbox GL v8 của Goong — `MapLibreMap.styleString` nhận thẳng chuỗi này.
  ///
  /// Bên trong tệp style, Goong đã nhúng sẵn khoá vào mọi đường dẫn con (nguồn vector, font, sprite),
  /// nên chỉ cần truyền khoá đúng MỘT lần ở đây.
  static String get mapStyleUrl =>
      '$tilesUrl/assets/goong_map_web.json?api_key=$mapTilesKey';

  /// Kích thước mặc định của ảnh bản đồ tĩnh (điểm ảnh).
  ///
  /// ⚠️ Goong nhận `width`/`height`, **KHÔNG** nhận `size=600x400` — truyền `size` thì nó im lặng bỏ qua
  /// và luôn trả 600×400. Đã đo 12/09/2026.
  static const int staticMapWidth = 600;
  static const int staticMapHeight = 400;

  /// Mức phóng khi mở bản đồ quanh một điểm bán — đủ thấy mặt phố, chưa tới mức thấy từng số nhà.
  static const double defaultZoom = 16.0;

  /// Toạ độ neo cho gợi ý tìm kiếm khi chưa lấy được GPS (trung tâm Hà Nội).
  /// Goong xếp kết quả theo khoảng cách tới điểm này, thiếu nó thì gõ "Vitto" ra cửa hàng ở đầu kia đất nước.
  static const double fallbackLat = 21.028511;
  static const double fallbackLng = 105.804817;

  static bool get hasKey => apiKey.isNotEmpty;

  static bool get hasMapTilesKey => mapTilesKey.isNotEmpty;
}

/// Các kiểu giao diện bản đồ Goong hỗ trợ
enum GoongMapStyle {
  /// Bản đồ đường phố tiêu chuẩn (Standard Vector)
  standard('goong_map_web', 'Đường phố'),

  /// Bản đồ ảnh vệ tinh kết hợp đường phố & địa danh (Satellite Hybrid - Cực kỳ chi tiết)
  satellite('goong_satellite', 'Vệ tinh'),

  /// Bản đồ điều hướng giao thông chi tiết (Navigation Day)
  navigation('navigation_day', 'Giao thông'),

  /// Bản đồ chế độ tối (Dark Mode)
  dark('goong_map_dark', 'Ban đêm');

  final String styleName;
  final String label;

  const GoongMapStyle(this.styleName, this.label);

  String get url =>
      '${GoongConfig.tilesUrl}/assets/$styleName.json?api_key=${GoongConfig.mapTilesKey}';
}

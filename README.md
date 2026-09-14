# vthm_dms

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Bản đồ — Goong Maps REST API v2

Mã tích hợp nằm ở `lib/core/map/`:

| Tệp | Nội dung |
|---|---|
| `goong_config.dart` | **hai khoá** + gốc REST và gốc bản đồ nền |
| `goong_models.dart` | `GoongPlace` · `GoongPrediction` · `GoongDistance` · `GoongLatLng` |
| `goong_api_service.dart` | 6 hàm gọi API |
| `goong_providers.dart` | provider Riverpod, kèm chống gõ dồn cho ô tìm kiếm |
| `goong_map_view.dart` | widget `GoongMapView` — bản đồ ĐỘNG (kéo/phóng được), chấm đánh dấu, vòng geofence |
| `goong_static_map.dart` | widget `GoongStaticMap` — ẢNH bản đồ, nhẹ, dùng cho thẻ xem trước |

### Dùng thế nào

```dart
final goong = ref.read(goongApiServiceProvider);

// Toạ độ → địa chỉ (điền địa chỉ lúc check-in)
final place = await goong.reverseGeocode(pos.latitude, pos.longitude);
place?.formattedAddress;      // '117 Lý Thường Kiệt, Minh Phụng, Hồ Chí Minh'
place?.compound.commune;      // 'Minh Phụng'
place?.compound.province;     // 'Hồ Chí Minh'

// Gợi ý địa chỉ khi mở điểm bán mới
ref.read(goongAutocompleteProvider.notifier)
  ..anchorAt(GoongLatLng(pos.latitude, pos.longitude))
  ..search(text);

// Có place_id rồi mới lấy được toạ độ
final detail = await goong.placeDetail(prediction.placeId);
```

### Ba điều dễ vấp

1. **Goong v2 chỉ trả HAI cấp hành chính** — `commune` (xã/phường) và `province` (tỉnh/thành), theo bộ
   đơn vị hành chính mới. **Không có** cấp quận/huyện, đừng chờ `district`.
2. **`autocomplete` không trả toạ độ.** Muốn lat/lng phải gọi tiếp `placeDetail(placeId)`.
3. **`distance()` là khoảng cách ĐƯỜNG THẬT**, không phải đường chim bay. Kiểm tra nhân viên có đứng
   trong bán kính điểm bán hay không thì tính cục bộ, đừng gọi API — vừa tốn lượt vừa sai ngữ nghĩa.

### Hiển thị bản đồ

```dart
GoongMapView(
  center: GoongLatLng(...) // → LatLng của maplibre
  markers: [LatLng(dealer.lat, dealer.lng)],
  geofenceRadiusMeters: 100,
  showMyLocation: true,
)
```

Goong phát hành style theo chuẩn **Mapbox GL v8**, nên gói `maplibre_gl` vẽ thẳng được bằng
`styleString: GoongConfig.mapStyleUrl`. **Không dùng SDK Flutter của Goong** — nó là bản rẽ nhánh của
`mapbox_gl` 0.16 (2022), yêu cầu Dart `<3.0` trong khi dự án chạy Dart `^3.13`.

⚠️ Vòng geofence trên bản đồ là **hình trang trí**, bán kính quy đổi theo mức phóng ban đầu. Quyết định
"nhân viên có đứng trong bán kính điểm bán không" phải tính ở tầng nghiệp vụ, không đọc từ hình vẽ.

### Hai khoá API — KHÔNG dùng lẫn

Goong bán hai dịch vụ rời nhau, mỗi cái một khoá. Dùng nhầm thì bên kia trả **403 `API_KEY_UNAUTHORIZED`**.

| Dịch vụ | Host | Hằng số | Biến build |
|---|---|---|---|
| REST (tìm địa chỉ, đo đường) | `rsapi.goong.io` | `GoongConfig.apiKey` | `GOONG_API_KEY` |
| Maptiles (vẽ bản đồ) | `tiles.goong.io` | `GoongConfig.mapTilesKey` | `GOONG_MAPTILES_KEY` |

```bash
flutter build apk \
  --dart-define=GOONG_API_KEY=<khoá REST> \
  --dart-define=GOONG_MAPTILES_KEY=<khoá Maptiles>
```

### Ảnh bản đồ tĩnh

```dart
GoongStaticMap(center: point)                        // bản đồ một điểm, ghim đỏ giữa ảnh
GoongStaticMap(center: from, destination: to)        // vẽ tuyến giữa hai điểm
```

🔴 **Goong chỉ có MỘT endpoint ảnh tĩnh: `/staticmap/route`, và nó vẽ TUYẾN.** Không có endpoint bản đồ
một điểm. Mẹo dùng: đặt `destination = origin` thì Goong trả bản đồ sạch có ghim đỏ ở giữa — `GoongStaticMap`
tự làm việc đó khi bỏ trống `destination`.

Đã dò và đo ngày 12/09/2026 — `/staticmap`, `/staticmap/center`, `/staticmap/marker`, `/staticmap/markers`,
`/staticmap/path` và 4 dạng tileserver chuẩn **đều 404**; `static.goong.io` không phân giải được DNS.

Ba cái bẫy của endpoint này:

| | |
|---|---|
| Khoá | Dùng **khoá REST**. Khoá Maptiles trả **403** |
| Kích thước | Nhận `width` + `height`. `size=600x400` **bị bỏ qua im lặng**, luôn ra 600×400 |
| Kiểu ảnh | Header ghi `image/png` nhưng thân là **JPEG**. Flutter tự nhận dạng nên không sao; chỗ nào đặt đuôi tệp theo `Content-Type` sẽ đặt sai |

Cần file PNG thật (đính kèm bản ghi check-in, xuất báo cáo) thì chụp từ bản đồ động:

```dart
await controller.waitUntilMapTilesAreLoaded();
final Uint8List png = await controller.takeSnapshot(width: 600, height: 300);
```

🔴 **Khoá bản đồ dùng ở phía client thì luôn nằm trong file cài đặt** — Google Maps cũng vậy; ai giải nén
được APK là đọc được, giấu đi không phải cách bảo vệ. Cách bảo vệ thật là vào `https://account.goong.io`
giới hạn khoá theo package name (`vn.vthmgroup.dms`) / bundle id và đặt trần số lượt gọi mỗi ngày.
Chưa đặt giới hạn thì khoá bị lấy = người khác tiêu hết hạn mức của công ty.

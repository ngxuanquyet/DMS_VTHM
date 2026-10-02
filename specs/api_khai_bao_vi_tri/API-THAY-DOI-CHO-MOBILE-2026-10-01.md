# Thay đổi API ngày 01/10/2026 — gửi đội mobile

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 01/10/2026** và app cần làm gì. Mọi JSON dưới đây là
phản hồi thật đã gọi bằng `curl` trên bản sao dữ liệu (`app_test`) cùng ngày.

> 🟢 **KHÔNG có breaking change.** App đang chạy không phải sửa gì để tiếp tục hoạt động. Mọi thay đổi đều
> là **thêm**: một endpoint mới, ba khoá mới trong một phản hồi cũ, một module mới.

| # | Thay đổi | Loại | Module |
|---|---|---|---|
| 1 | `GET /dms/mobile-rules` — đọc **ngưỡng** của luồng thị trường | **MỚI** | dùng chung |
| 2 | `GET /dms/routes/customers` trả thêm `lat` · `lng` · `geofence_radius_m` | **THÊM KHOÁ** | **viếng thăm** |
| 3 | Luồng **khai báo vị trí** — 4 endpoint | **MỚI** | khai báo vị trí |

---

## 1. MỚI — `GET /dms/mobile-rules`

### Vì sao có

Mọi ngưỡng của luồng thị trường (bán kính check-in, thời gian tối thiểu, số ảnh, ngưỡng lệch giờ) do người
vận hành chỉnh ở màn cấu hình của One, **không phát hành app mới**. Trước ngày 01/10 app **không có đường nào
đọc chúng**, nên chỉ biết ngưỡng *sau khi* bị từ chối bằng 422 — nhân viên đứng giữa đường không biết phải
lại gần bao nhiêu mét.

### Phản hồi

```
GET /dms/mobile-rules
```

```json
{"success":true,"message":"Luật thị trường cho app di động.","data":{
  "visit":{
    "require_geofence":true,
    "default_radius_m":100,
    "block_on_mock_location":false,
    "min_duration_minutes":5,
    "min_photos":2,
    "closed_min_photos":1,
    "route_scope":"assigned",
    "auto_close_after_hours":12
  },
  "position":{"min_photos":1,"block_on_mock_location":false},
  "clock":{"skew_tolerance_minutes":15,"offline_max_queue_hours":24}
}}
```

| Khoá | Nghĩa |
|---|---|
| `visit.require_geofence` | `true` = đứng ngoài bán kính thì **từ chối** check-in; `false` = vẫn cho, chỉ gắn cờ |
| `visit.default_radius_m` | bán kính áp cho điểm bán **không khai riêng** — xem §2 |
| `visit.min_duration_minutes` | phải ở lại điểm bán đủ chừng này mới check-out được (lượt đóng cửa được miễn) |
| `visit.min_photos` / `closed_min_photos` | số ảnh tối thiểu khi check-out, lượt mở cửa / lượt ghi nhận đóng cửa |
| `visit.route_scope` | `assigned` = mọi điểm bán thuộc tuyến được giao · `today` = chỉ điểm có lịch hôm nay · `off` = không giới hạn |
| `visit.auto_close_after_hours` | sau chừng này giờ, cron đóng hộ lượt còn treo (`0` = tắt) |
| `position.min_photos` | số ảnh tối thiểu của một lượt **khai báo vị trí** |
| `*.block_on_mock_location` | có chặn khi máy báo giả lập vị trí không (hai luồng cấu hình riêng) |
| `clock.skew_tolerance_minutes` | lệch giờ máy quá chừng này thì bản ghi bị **gắn cờ nghi vấn** (không bị chặn) |
| `clock.offline_max_queue_hours` | trần khoảng nằm chờ của bản ghi ngoại tuyến; khai vượt thì bị **cắt về trần** |

**Đơn vị nằm trong tên khoá** (`*_m`, `*_minutes`, `*_hours`) — không bên nào phải đoán.

### App dùng thế nào

* **Gọi một lần lúc đăng nhập, giữ bản sao trong máy.** Các giá trị này đổi vài lần một năm, và giữ bản sao
  là cách duy nhất để app còn làm mờ nút được **khi mất sóng**.
* Gọi lại khi vào màn đồng bộ, hoặc khi nhận một lượt 422 nói về ngưỡng mà app tưởng mình đã thoả — đó là
  dấu hiệu admin vừa đổi.
* 🔴 **Đây là để app NÓI TRƯỚC, không phải hàng rào.** Server kiểm lại toàn bộ; app chỉ dùng để vẽ giao diện
  cho đúng (làm mờ nút, hiện "còn 3 phút nữa", "bạn cần lại gần trong 100 m").
* Quyền: `/dms/mobile-rule/index`, **đã cấp sẵn** cho vai `crm_customer_self` — không cần làm gì thêm.

Đã đo: admin đổi bán kính 100 → 150 thì endpoint trả 150 **ngay lượt gọi kế tiếp**; trả về 100 thì trả 100.

---

## 2. ĐỔI — `GET /dms/routes/customers` (module VIẾNG THĂM)

Đây là **thay đổi duy nhất chạm API viếng thăm**.

### Trước

```json
{"success":true,"data":{"items":[
  {"id":1139,"code":"08670102","name":"195 LONG XUYÊN","address":"Mỹ bình Long Xuyên An Giang"}
],"truncated":false}}
```

### Từ 01/10/2026

```json
{"success":true,"data":{"items":[
  {"id":2348,"code":"08180024","name":"Đại Việt",
   "address":"Quầy thuốc Đỗ Dung, Mỹ Hưng, Mỹ Lộc, Nam Định",
   "lat":"20.4427685","lng":"106.1307546","geofence_radius_m":null}
],"truncated":false}}
```

**Ba khoá thêm vào, không khoá nào bị đổi hay bỏ** — app cũ bỏ qua chúng vẫn chạy y như cũ.

| Khoá | Ghi chú |
|---|---|
| `lat` · `lng` | toạ độ điểm bán, **dạng chuỗi** (`numeric(10,7)` của DB). Ép `float` làm tròn chữ số thứ 7 — không đáng kể cho bản đồ, nhưng đủ để hai bên tính ra hai con số khoảng cách hơi khác nhau rồi tranh nhau xem ai đúng |
| `geofence_radius_m` | bán kính **khai riêng** của điểm bán. `null` = dùng `visit.default_radius_m` ở §1. Đo prod 01/10: **8.734/8.735 điểm để trống** ⇒ trên thực tế gần như luôn là con số chung |

### App dùng thế nào

Đây là thứ cho phép app **tự đo khoảng cách trước khi gửi check-in**, thay vì để nhân viên bấm rồi mới biết
mình đứng xa:

```
bán_kính_áp_dụng = điểm_bán.geofence_radius_m ?? rules.visit.default_radius_m
khoảng_cách      = haversine(vị_trí_hiện_tại, (điểm_bán.lat, điểm_bán.lng))

nếu rules.visit.require_geofence và khoảng_cách > bán_kính_áp_dụng:
    làm mờ nút check-in, hiện "Bạn đang cách cửa hàng {khoảng_cách} m,
    cần vào trong {bán_kính_áp_dụng} m"
```

⚠️ **Điểm bán chưa có toạ độ** (`lat`/`lng` = `null`) thì **không có gì để so** — server luôn cho qua ở ca
này, nên app cũng phải cho qua, đừng chặn.

⚠️ Server vẫn kiểm lại và vẫn là nơi nói không. Câu từ chối giữ nguyên:
`Bạn đang cách điểm bán {N}m. Hãy lại gần hơn rồi check-in.`

Đo thật trên một tài khoản đi tuyến: 15 điểm bán, **15/15 có toạ độ**, 0 điểm khai bán kính riêng.

---

## 3. MỚI — luồng KHAI BÁO VỊ TRÍ

Module mới hoàn toàn, **không ảnh hưởng gì tới luồng viếng thăm**. Hợp đồng đầy đủ ở
[`API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md`](API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md); đây chỉ là tóm tắt.

Khai báo vị trí là lượt nhân viên khai *mình đang ở đâu và vì sao* khi **không ở điểm bán nào** (công tác
ngoại tỉnh, họp, xử lý khiếu nại): **một mốc duy nhất**, không check-out, không thời lượng, **không hỏi km**,
và **lý do bắt buộc** chọn từ danh mục admin quản trị.

| Endpoint | Việc |
|---|---|
| `GET /dms/position-reasons/active` | danh mục lý do đang bật (giữ bản sao để chọn khi mất sóng) |
| `POST /dms/position-photos` | tải **một tấm** ảnh, nhận `token` |
| `POST /dms/position-declarations` | gửi khai báo kèm `photo_tokens[]` — bắt buộc **lý do + GPS + ảnh** |
| `GET /dms/position-photos/public/{token}` | xem lại ảnh, không cần header |

Thứ tự ảnh-trước-bản-ghi-sau là **bắt buộc**: bản ghi chỉ sinh ra khi đã đủ ảnh, và **gửi rồi thì không sửa,
không xoá**.

Quyền `/dms/position-declaration/create` và `/dms/position-reason/active` **đã cấp sẵn** cho vai
`crm_customer_self`.

---

## 4. KHÔNG đổi — để app khỏi phải rà lại

* Mọi endpoint viếng thăm khác giữ nguyên hợp đồng: `/dms/visits` (check-in), `/dms/visits/{id}/checkout`,
  `/dms/visits/{id}/cancel`, `/dms/visits/{id}/requirements`, `/dms/visits/mine`, `/dms/visits/{id}/photos`.
* **Ảnh viếng thăm vẫn ở đường cũ** `/dms/visit-photos/public/{token}` — bên trong có đổi cách dựng chuỗi
  (để phân biệt với ảnh khai báo vị trí), nhưng kết quả **giống hệt**; phép kiểm tự động khẳng định đúng
  chuỗi đó vẫn được trả về.
* Mã lỗi, hình dạng envelope (`success` · `message` · `data` · `errors`), cơ chế token: không đổi.

🔴 **Ba luồng ảnh dùng ba ngữ cảnh RIÊNG, không tải chéo được**: ảnh điểm bán
(`/crm/customer-photos/...`) · ảnh viếng thăm (`/dms/visit-photos/...`) · ảnh khai báo vị trí
(`/dms/position-photos/...`). Gọi nhầm cửa trả **404** (đã đo). Mỗi luồng dùng đúng cặp endpoint của nó.

---

## 5. Việc app nên làm, theo thứ tự

| # | Việc | Mức |
|---|---|---|
| 1 | **Convert ảnh sang JPEG trước khi tải lên** | 🔴 chặn iOS |
| 2 | Gọi `GET /dms/mobile-rules` lúc đăng nhập, giữ bản sao, dùng để làm mờ nút + báo trước | nên làm sớm |
| 3 | Dùng `lat`/`lng`/`geofence_radius_m` của `/dms/routes/customers` để tự đo khoảng cách | nên làm sớm |
| 4 | Dựng luồng khai báo vị trí (§3) | tính năng mới |
| 5 | Rà lại hàng đợi ngoại tuyến: gửi `queued_seconds` (đồng hồ đơn điệu) + `client_time` là **giờ lúc bấm** | 🔴 ảnh hưởng số liệu |

**Hai cái bẫy đã đo được, nói rõ để khỏi mất một vòng phát hành:**

1. **Server không nhận `heic/heif`** (chỉ `jpg · jpeg · png · gif · webp · bmp`, trần **10 MB**), mà iPhone
   mặc định chụp HEIC ⇒ mọi lượt chụp trên iOS bị từ chối với
   `Tệp "x.heic" có định dạng không được phép — chỉ nhận ảnh.`
2. **`client_time` phải là giờ LÚC BẤM, không phải lúc đồng bộ.** Gửi sai làm bản ghi bị gắn cờ *"nghi đổi
   giờ máy"* và nó hiện lên báo cáo của người quản lý như một dấu hỏi về nhân viên. Đo thật: gửi lệch 72 phút
   → `is_time_tampered = true`.

---

## 6. Liên hệ khi vướng

Mọi lời từ chối của server đều kèm **câu tiếng Việt viết cho nhân viên đọc** — hiện thẳng câu đó lên là đủ.
Phân biệt: **422** = người dùng làm thiếu bước (cho họ sửa); **5xx** = sự cố (giữ trong hàng đợi, thử lại sau,
đừng bắt nhập lại).

Hai thứ **chưa có**, nếu cần thì báo để mở:

* `GET /dms/position-declarations/mine` — lịch sử khai báo của chính mình (app đang tự giữ trong máy);
* đường sửa/xoá một khai báo đã gửi — hiện là append-only theo quyết định nghiệp vụ.

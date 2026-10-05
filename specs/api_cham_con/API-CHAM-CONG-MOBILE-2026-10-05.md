# API module CHẤM CÔNG BẰNG APP — cho app di động DMS

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>` ·
viết 05/10/2026.

Tài liệu này là **hợp đồng đủ để làm trọn một lượt chấm công bằng app**: lấy cấu hình, gửi lượt chấm, chụp
hai ảnh bắt buộc, đọc lịch sử. Mọi endpoint dưới đây đã được gọi thật bằng `curl` trên bản sao dữ liệu
(`app_test`) ngày 05/10/2026; các đoạn JSON là **phản hồi thật đã cắt gọn**, không phải ví dụ dựng tay.

> 🔴 **Luật nghiệp vụ nằm ở SERVER, app không phải là hàng rào.** App kiểm để làm mờ nút và báo trước còn
> thiếu gì; server kiểm lại tất cả và là nơi nói không. Mọi lời từ chối đều kèm **câu tiếng Việt viết cho
> người lao động đọc** — hiện thẳng câu đó lên là đủ, đừng dịch lại.

> 🔴 **ĐỌC TRƯỚC KHI LÊN LỊCH TÍCH HỢP:** trên **prod hiện chưa khai địa điểm chấm công nào**
> (`att_geofence` = 0 dòng, đo 05/10/2026). Nhóm luật đang bật (`MARKET`) **chặn cứng ngoài vùng**, nên
> *mọi* lượt gửi lên prod hôm nay đều nhận `422` kèm câu *"Chưa khai địa điểm chấm công nào — liên hệ nhân
> sự…"*. Đó **không phải lỗi app**. Việc khai địa điểm là của nhân sự/quản trị (màn SPA
> *Chấm công → Địa điểm chấm công*); app thử nghiệm được ngay khi có dòng đầu tiên.

---

## 0. Một lượt chấm công gồm những bước nào

| # | Việc | Endpoint |
|---|---|---|
| 1 | Đăng nhập | `POST /auth/login` |
| 2 | Lấy **cấu hình + danh sách địa điểm** (kèm khoảng cách tới chỗ đang đứng) | `GET /attendance/mobile/config` |
| 3 | **Gửi lượt chấm** | `POST /attendance/mobile/punch` |
| 4 | Chụp **ảnh camera trước** (bắt buộc) | `POST /attendance/mobile/punches/{id}/photos` · `photo_type=front` |
| 5 | Chụp **ảnh camera sau** (bắt buộc) | `POST /attendance/mobile/punches/{id}/photos` · `photo_type=back` |
| 6 | Lịch sử chấm của chính mình (hiện màn danh sách) | `GET /attendance/mobile/history?days=7` |
| — | Xem lại ảnh trong thẻ `<img>` | `GET /attendance/punch-photos/public/{token}` |

Bước 3 trả về `id` của lượt; bước 4–5 gắn ảnh vào đúng `id` đó. **Ảnh gửi sau, không gửi kèm lượt chấm** —
xem §4.1.

⚠️ **Không có endpoint `POST /attendance/mobile/punch-photo`.** Bảng API ở §6.1 của spec
`docs/specs/hr/SPEC-CHAM-CONG-APP-2026-10-01.md` ghi đường đó từ bản nháp; đường đang chạy là
`POST /attendance/mobile/punches/{id}/photos` (đã sửa lại trong spec cùng ngày với tài liệu này).

---

## 1. Xác thực và quyền

```
POST /auth/login     {"username":"VTG920","password":"…"}   → access_token + refresh_token
POST /auth/refresh   (refresh token)                        → cặp token mới
GET  /auth/me                                               → hồ sơ người đang đăng nhập
```

Phản hồi đăng nhập (cắt gọn, gọi thật 05/10/2026):

```json
{"success":true,"message":"Đăng nhập thành công.","data":{
  "access_token":"<JWT access token>",
  "token_type":"Bearer","expires_in":3600,
  "refresh_token":"<refresh token>",
  "refresh_expires_in":7776000,
  "user":{"id":12798,"username":"TEST001","user_type":1}}}
```

`expires_in` = **3600 giây**; `refresh_expires_in` = **7.776.000 giây (90 ngày)**. App đi tuyến nên dựa vào
refresh token, đừng bắt người dùng đăng nhập lại mỗi giờ.

### 1.1 Ba chuỗi quyền

| Chuỗi quyền | Mở cửa nào |
|---|---|
| `/attendance/mobile/config` | cấu hình + danh sách địa điểm |
| `/attendance/mobile/punch` | gửi lượt chấm · **tải ảnh lên** |
| `/attendance/mobile/history` | lịch sử của mình · tải ảnh qua đường Bearer |

Cả ba đã gán cho vai **`employee`** trên prod (đo 05/10/2026), tức **ai đăng nhập được vào One là chấm được**
— đợt này **cố ý không siết theo tài khoản** (chủ hệ thống chốt 01/10/2026). Hàng rào duy nhất là **địa
điểm**. Thiếu quyền ⇒ `403`; không gửi token ⇒ `401` với `"Your request was made with invalid credentials."`.

🔴 Tải ảnh dùng **chính quyền chấm công** (`/attendance/mobile/punch`), không có chuỗi quyền riêng.

### 1.2 Tài khoản chưa có mã nhân viên thì không chấm được

`att_punch` đòi mã nhân viên. Tài khoản chưa gắn mã (đo 01/10: 4/99 nhân viên DMS) nhận:

* `GET …/config` → `can_punch: false` + `blocked_reason` = *"Tài khoản của bạn chưa có mã nhân viên — liên hệ
  nhân sự để chấm công được."* ⇒ **app ẩn/làm mờ nút chấm và hiện đúng câu đó**;
* `POST …/punch` → `422` cùng câu trên.

---

## 2. `GET /attendance/mobile/config` — vẽ màn chấm công

App gọi **mỗi lần mở màn** (và nên gọi lại sau khi có toạ độ mới), vì tham số ảnh và danh sách địa điểm do
người vận hành đổi được mà không phát hành bản app mới.

| Tham số (query) | Bắt buộc | Ghi chú |
|---|---|---|
| `lat`, `lng` | không | Có thì `locations` **sắp theo khoảng cách tăng dần** và mỗi dòng có `distance_m`; không có thì sắp theo tên và `distance_m = null` |

```
GET /attendance/mobile/config?lat=21.0280000&lng=105.8345000
```

```json
{"success":true,"message":"Thành công","data":{
  "can_punch": true,
  "blocked_reason": null,
  "group": {"code":"MARKET","name":"Khối thị trường","enforce_geofence":true},
  "photo": {"min_photos":2,"max_photos":10,"require_both":true},
  "locations": [
    {"id":6,"code":"TESTCC-DOC1","name":"[TEST-CC] Văn phòng tài liệu mobile",
     "lat":21.0277644,"lng":105.8341598,"radius_m":200,"distance_m":44}
  ]}}
```

| Khoá | Ý nghĩa cho app |
|---|---|
| `can_punch` | `false` ⇒ **không gửi lượt nào**, hiện `blocked_reason` |
| `group.enforce_geofence` | `true` (giá trị đang chạy) ⇒ ngoài vùng là **chặn cứng**, app nên làm mờ nút khi `distance_m > radius_m` của mọi địa điểm |
| `photo.min_photos` · `max_photos` · `require_both` | Đang là **2 · 10 · true** ⇒ màn ảnh phải có **đúng hai nút chụp**: camera trước + camera sau. **Đọc từ đây, đừng hardcode** |
| `locations[]` | Danh sách để người bị chặn **biết phải đi đâu** — hiện tên + khoảng cách; `radius_m` nằm trong 20–5000 m |
| `locations: []` | Chưa khai địa điểm nào (tình trạng prod hôm nay) ⇒ hiện câu chỉ sang nhân sự, đừng để màn hình trống một nút không ăn |

Địa điểm được lọc theo **đơn vị** (`branch_code` của hồ sơ nhân sự) và theo nhóm; điểm khai chung toàn tập
đoàn thì ai cũng thấy. App không cần biết luật lọc, chỉ hiện những gì server trả về.

---

## 3. `POST /attendance/mobile/punch` — gửi một lượt chấm

Body JSON (hoặc `multipart`, server nhận cả hai):

| Trường | Bắt buộc | Kiểu | Ghi chú |
|---|---|---|---|
| `client_uuid` | ✅ | UUID | 🔴 **Sinh lúc BẤM, không phải lúc gửi** — xem §3.2 |
| `lat` | ✅ | số (−90…90) | Vĩ độ chỗ đứng |
| `lng` | ✅ | số (−180…180) | Kinh độ chỗ đứng |
| `accuracy_m` | không | số (0…100000) | Sai số GPS máy báo; > 100 m sẽ bị gắn cờ xem lại nhưng **không bị từ chối** |
| `client_time` | không | ISO-8601, ≤ 64 ký tự | Giờ máy **lúc bấm**; chỉ để đo lệch |
| `is_mock_location` | không | `"1"`/`"0"` | Chỉ gắn cờ, **không chặn** |
| `is_rooted_device` | không | `"1"`/`"0"` | Chỉ gắn cờ |
| `device_info` | không | object | Tuỳ app (`os`, `model`, `app_version`…) — để đối chiếu khi có tranh chấp |

```bash
curl -X POST https://api-app.vthmgroup.vn/attendance/mobile/punch \
  -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"client_uuid":"11111111-2222-4333-8444-555555550003",
       "lat":21.0280000,"lng":105.8345000,"accuracy_m":"12.5",
       "client_time":"2026-10-05T13:30:19+07:00",
       "is_mock_location":"0","is_rooted_device":"0",
       "device_info":{"os":"Android 14","model":"Redmi Note 12","app_version":"1.4.0"}}'
```

`201 Created`:

```json
{"success":true,"message":"Đã ghi nhận chấm công lúc 13:30.","data":{
  "id":8723,
  "punch_at":"2026-10-05 13:30:19+07",
  "client_uuid":"11111111-2222-4333-8444-555555550003",
  "lat":21.028,"lng":105.8345,"accuracy_m":12.5,
  "geofence_id":6,"geofence_name":"[TEST-CC] Văn phòng tài liệu mobile",
  "is_outside_geofence":false,"is_mock_location":false,"is_time_tampered":false,
  "photos":[],
  "requirements":{"photo_count":0,"min_photos":2,"max_photos":10,
                  "need_front":true,"need_back":true,"require_both":true,"satisfied":false},
  "duplicate":false}}
```

App lấy `data.id` để tải ảnh, và đọc `data.requirements` để biết còn thiếu ảnh gì. **`punch_at` là giờ
SERVER** — xem §3.3.

### 3.1 Ngoài vùng = chặn cứng, không ghi dòng nào

```
HTTP 422
{"success":false,
 "message":"Bạn đang cách [TEST-CC] Văn phòng tài liệu mobile khoảng 5956m. Hãy tới gần hơn rồi chấm công.",
 "errors":null,"data":null}
```

Chưa khai địa điểm nào:

```
HTTP 422
{"success":false,"message":"Chưa khai địa điểm chấm công nào — liên hệ nhân sự trước khi chấm công bằng app.",
 "errors":null,"data":null}
```

🔴 **Đợt này KHÔNG có cửa xin chấm bù.** Bị chặn là mất lượt đó, nên app **phải** hiện khoảng cách và danh
sách địa điểm (§2) thay vì chỉ báo "chấm công thất bại"; và **đừng bỏ lượt vào hàng đợi gửi lại** khi lý do
là ngoài vùng — gửi lại từ chỗ cũ chỉ nhận đúng câu đó.

### 3.2 Gửi trùng là bình thường, không phải lỗi

Gửi lại **cùng `client_uuid`** trả `200` kèm **lượt CŨ** và `duplicate: true`; DB vẫn đúng một dòng
(đã đo):

```json
{"success":true,"message":"Lượt chấm này đã được ghi nhận trước đó.",
 "data":{"id":8723,…,"duplicate":true}}
```

⇒ Hàng đợi offline cứ gửi lại tới khi nhận `2xx`. Hai điều kiện để cơ chế này đúng:

1. **UUID sinh lúc người bấm nút**, lưu cùng bản ghi trong hàng đợi — sinh lúc gửi thì mỗi lần thử lại là
   một lượt chấm mới;
2. **`duplicate: true` thì đừng hiện "đã chấm công thành công" như lượt mới** (dễ làm người dùng tưởng vừa
   chấm thêm lần nữa); coi nó là *"lượt này đã có trên hệ thống"* và xoá khỏi hàng đợi.

Cùng `client_uuid` đã tồn tại thì **không bị kiểm vùng lại** — lượt đã được chấp nhận không bị từ chối chỉ
vì người đó nay đã đi khỏi đó.

### 3.3 Giờ công là giờ SERVER

`punch_at` và `server_received_at` do server đặt. `client_time` chỉ dùng để tính lệch:

* lệch quá **15 phút** (tham số `app_punch_clock_skew_tolerance_minutes`) ⇒ `is_time_tampered: true`;
* 🔴 Lượt nằm trong hàng đợi offline vài giờ rồi mới gửi **cũng ra lệch lớn** — đó là lý do cờ này **chỉ là
  tín hiệu cho người xem**, không bao giờ làm lượt bị từ chối. Trong lần đo của tài liệu này, gửi
  `client_time` 09:00 trong khi server 13:30 vẫn `201`, chỉ `is_time_tampered: true`.

### 3.4 Chấm nhiều lần trong ngày — được

Không có giới hạn số lượt/ngày. Bảng công lấy **lượt đầu** làm giờ Vào, **lượt cuối** làm giờ Ra; các lượt
giữa hiển thị thành dòng con trong báo cáo. App không phải chọn "vào" hay "ra" — **không có trường nào như
thế** và server không suy ra chiều.

### 3.5 Lỗi hình dạng dữ liệu

```
HTTP 422
{"success":false,"message":"Lat không được để trống.",
 "errors":{"lat":["Lat không được để trống."],
           "client_uuid":["client_uuid phải là UUID hợp lệ do app sinh lúc bấm chấm công."]},
 "code":"VALIDATION_ERROR"}
```

Hiện `message` cho người dùng; `errors` dùng để tô đỏ ô nào sai (hữu ích khi gỡ lỗi app, người dùng cuối
không thấy ô nào cả).

---

## 4. Ảnh của lượt chấm

### 4.1 `POST /attendance/mobile/punches/{id}/photos` — một lượt gọi mỗi tấm

`multipart/form-data`:

| Phần | Bắt buộc | Ghi chú |
|---|---|---|
| `file` | ✅ | **Tên phần phải đúng là `file`**. Chỉ ảnh: `jpg jpeg png gif webp bmp`. Trần **10 MB**/tấm |
| `photo_type` | ✅ | `front` (camera trước) · `back` (camera sau) · `extra` (tấm bối cảnh thêm) |
| `taken_at` | không | ISO-8601, ≤ 64 ký tự — chỉ để hiển thị |
| `lat`, `lng` | không | Toạ độ lúc chụp; gửi thì phải gửi **cả cặp** |

```bash
curl -X POST "https://api-app.vthmgroup.vn/attendance/mobile/punches/8723/photos" \
  -H "Authorization: Bearer $T" \
  -F "file=@front.jpg" -F "photo_type=front" \
  -F "taken_at=2026-10-05T13:30:25+07:00" -F "lat=21.0280000" -F "lng=105.8345000"
```

`201 Created`:

```json
{"success":true,"message":"Đã tải ảnh lên. Lượt chấm này hiện có 1 ảnh.","data":{
  "id":9,"file_id":15647,
  "token":"<token-32-hex>",
  "url":"/attendance/punch-photos/public/<token-32-hex>",
  "photo_type":"front","photo_type_label":"Ảnh chân dung","photo_type_color":"primary",
  "taken_at":"2026-10-05 13:30:25+07","sort_order":0,
  "duplicate":false,"photo_count":1,
  "requirements":{"photo_count":1,"min_photos":2,"max_photos":10,
                  "need_front":false,"need_back":true,"require_both":true,"satisfied":false}}}
```

Sau khi gửi tấm `back`, `requirements.satisfied` thành `true` — đó là tín hiệu duy nhất app nên dùng để
đóng màn chụp ảnh. **Đừng tự đếm ảnh trong app**: số ảnh bắt buộc là tham số vận hành.

🔴 **Thiếu ảnh KHÔNG làm mất lượt chấm.** Lượt đã ghi từ bước §3; mất mạng giữa chừng thì ảnh gửi sau vẫn
gắn được vào đúng `id` đó (miễn còn trong hạn lưu). Lượt thiếu ảnh chỉ bị gắn cờ *"chưa đủ ảnh"* cho quản lý
đòi. Vì vậy: **ghi lượt trước, ảnh vào hàng đợi riêng.**

### 4.2 Gửi lại cùng loại ảnh — trả ảnh cũ, không thêm bản sao

`front` và `back` bị khoá **một tấm cho mỗi loại**. Gửi tấm `front` thứ hai:

```json
{"success":true,"message":"Ảnh này đã có trong lượt chấm — không thêm bản sao.",
 "data":{"id":9,…,"duplicate":true,"photo_count":2,"requirements":{…,"satisfied":true}}}
```

`201` + `duplicate: true` + `photo_count` **không tăng**. App phải hiểu điều này, nếu không người dùng bấm
chụp lại mãi mà số ảnh không nhúc nhích. Muốn **thay** ảnh đã gửi thì phải xoá ở màn quản trị — đợt này app
không có đường xoá ảnh.

`extra` **không bị khoá**: gửi bao nhiêu tấm cũng thành dòng mới, tới khi đủ trần `max_photos` (10).
Vượt trần:

```
HTTP 422  {"success":false,"message":"Lượt chấm này đã có tối đa 10 ảnh.","data":null}
```

Trần được soi **trước khi** đọc nội dung tệp — app không tiêu dữ liệu di động cho một tấm sẽ bị từ chối.

⚠️ **Hai câu lỗi về TỆP hiện đang là tiếng Anh** (thiếu bản dịch ở category `attendance`, đo 05/10/2026):

```
HTTP 422  {"message":"File \"big.png\" (11264 KB) exceeds maximum size limit 10240 KB."}
HTTP 422  {"message":"Invalid file extension \"x.pdf\"."}
```

Hai ca này app **nên tự viết câu tiếng Việt** (và tốt nhất là chặn trước khi gửi: nén ảnh xuống dưới 10 MB,
chỉ cho chọn đuôi ảnh). Đã báo backend bổ sung bản dịch; khi có, `message` đổi sang tiếng Việt mà hình dạng
phản hồi không đổi — đừng so khớp chuỗi để nhận biết lỗi, hãy dùng mã `422`.

### 4.3 Lượt không phải của mình ⇒ 404

```
HTTP 404  {"success":false,"message":"Không tìm thấy lượt quẹt.","code":"NOT_FOUND"}
```

Cố ý `404` chứ không `403`: nói *"bạn không có quyền với lượt #12"* đã là tiết lộ lượt #12 có thật. App chỉ
gắn ảnh vào `id` do chính nó vừa nhận ở §3.

### 4.4 Xem lại ảnh

| Đường | Dùng khi | Xác thực |
|---|---|---|
| `GET /attendance/punch-photos/public/{token}` | thẻ `<img>` / `Image.network` | **không cần** đăng nhập |
| `GET /attendance/punch-photos/{token}` | tải bằng HTTP client | **cần** Bearer |

Đường công khai trả `200 image/*` kèm `Cache-Control: public, max-age=2592000, immutable` (30 ngày) — token
bất biến nên cache dài là an toàn. Dùng trực tiếp `data.url` mà server trả về, **đừng tự ghép chuỗi đường
dẫn**.

Token của module khác (ảnh điểm bán, tệp phản hồi…) trả **404** ở cửa này — đã đo.

⚠️ **Mô hình đã chốt và biết giá:** ai có link là xem được, không thu hồi được trừ khi xoá ảnh. Ảnh chấm công
là **ảnh chân dung người lao động** — dữ liệu cá nhân nhạy cảm theo Luật 91/2025. App **không được** đưa link
này ra ngoài app (chia sẻ, log, bên thứ ba). Hạn lưu: **90 ngày**, sau đó cron dọn ảnh (lượt chấm và bảng
công giữ nguyên số, chỉ mất ảnh) ⇒ ảnh đã dọn thì đường trên trả 404, màn lịch sử phải chịu được ca đó.

---

## 5. `GET /attendance/mobile/history` — lịch sử của chính mình

| Tham số | Mặc định | Ghi chú |
|---|---|---|
| `days` | `7` | Kẹp **1–31**; `days=40` cũng chỉ trả 31 ngày. Trần 200 lượt |

```
GET /attendance/mobile/history?days=7
```

```json
{"success":true,"message":"Thành công","data":[
 {"id":8723,"punch_at":"2026-10-05 13:30:19+07","client_uuid":"…0003",
  "lat":21.028,"lng":105.8345,"accuracy_m":12.5,
  "geofence_id":6,"geofence_name":"[TEST-CC] Văn phòng tài liệu mobile",
  "is_outside_geofence":false,"is_mock_location":false,"is_time_tampered":true,
  "photos":[
    {"id":9,"file_id":15647,"token":"<token-32-hex>","url":"/attendance/punch-photos/public/<token-32-hex>",
     "photo_type":"front","photo_type_label":"Ảnh chân dung","photo_type_color":"primary",
     "taken_at":"2026-10-05 13:30:25+07","sort_order":0},
    {"id":10,…,"photo_type":"back","photo_type_label":"Ảnh khung cảnh","sort_order":1}],
  "requirements":{"photo_count":2,"min_photos":2,"max_photos":10,
                  "need_front":false,"need_back":false,"require_both":true,"satisfied":true}}]}
```

* Mới nhất trước; **chỉ lượt nguồn `app`**, không trộn lượt quẹt máy chấm công;
* **Một lượt chấm có cùng bộ khoá ở cả hai nơi** (phản hồi `POST punch` và `history`) ⇒ app dùng **một kiểu
  dữ liệu duy nhất**, parse một lần;
* `geofence_name` có thể `null` cho lượt cũ nếu địa điểm đã bị xoá — hiển thị phải chịu được `null`;
* `days=abc` ⇒ `400` *"Dữ liệu của tham số "days" không hợp lệ."*

---

## 6. Bảng mã trả về

| Mã | Khi nào | App làm gì |
|---|---|---|
| `200` | Gửi lại lượt đã có (`duplicate: true`) | Xoá khỏi hàng đợi, **không** báo "đã chấm công" |
| `201` | Ghi lượt mới · tải ảnh thành công | Đi bước tiếp theo |
| `400` | Tham số `days` sai kiểu | Lỗi app, không phải lỗi người dùng |
| `401` | Thiếu/hết `access_token` | Refresh token rồi gọi lại |
| `403` | Thiếu quyền (tài khoản chưa được cấp vai) | Hiện câu chỉ sang IT/nhân sự |
| `404` | Lượt không phải của mình · token ảnh sai/đã dọn | Không thử lại |
| `422` | **Ngoài vùng** · chưa khai địa điểm · chưa có mã nhân viên · vượt trần ảnh · tệp quá lớn / sai đuôi · dữ liệu sai hình dạng | Hiện `message` **nguyên văn** (trừ hai câu lỗi tệp còn tiếng Anh — §4.2); chỉ đưa vào hàng đợi gửi lại khi lý do là lỗi mạng, không phải lỗi luật |

Envelope luôn là `{success, message, errors?, data?, code?}` — không có endpoint nào trả mảng trần.

---

## 7. Những cờ server gắn mà app nên biết

| Cờ | Điều kiện | Có chặn? |
|---|---|---|
| `is_outside_geofence` | Toạ độ nằm ngoài bán kính địa điểm gần nhất | Lượt bị **từ chối** khi nhóm `enforce_geofence` (đang bật) ⇒ cờ này chỉ thấy ở dữ liệu lịch sử cũ |
| `is_mock_location` | App báo đang giả lập vị trí | ❌ chỉ gắn cờ — iOS không có cách phát hiện chính thức, Android báo nhầm; chặn là khoá oan người làm thật |
| `is_rooted_device` | Máy root/jailbreak | ❌ chỉ gắn cờ (không trả ra trong phản hồi, chỉ lưu) |
| `is_time_tampered` | \|`client_time` − giờ server\| > 15 phút | ❌ chỉ gắn cờ |
| sai số GPS | `accuracy_m` > 100 m | ❌ chỉ gắn cờ cho người xem |

🔴 App **vẫn phải gửi trung thực** `is_mock_location`/`is_rooted_device`. Không gửi thì cờ im lặng là `false`
và phần đối chiếu khi có tranh chấp mất sạch dữ liệu.

---

## 8. Checklist tích hợp cho app DMS

1. [ ] Gọi `config` khi mở màn **và** sau khi có toạ độ; vẽ nút theo `can_punch`, `photo.*`, `locations`.
2. [ ] Sinh `client_uuid` (UUID v4) **tại thời điểm bấm**, lưu vào hàng đợi cùng `lat/lng/accuracy_m/client_time`.
3. [ ] Gửi lượt; nhận `id`. Lỗi mạng ⇒ gửi lại **cùng uuid**. `422` vì luật ⇒ **không** gửi lại, hiện `message`.
4. [ ] Chụp **front** + **back**, mỗi tấm một lượt gọi; nén xuống dưới 10 MB; dừng khi `requirements.satisfied`.
5. [ ] Ảnh thất bại ⇒ hàng đợi **riêng** theo `punch_id`, không làm lại lượt chấm.
6. [ ] Màn lịch sử đọc `history?days=7`, hiện ảnh bằng `photos[].url` (ghép với base URL của API), chịu được
       `null` ở `geofence_name` và ảnh đã bị dọn sau 90 ngày.
7. [ ] Hiện mọi `message` của server **nguyên văn tiếng Việt**, đừng thay bằng câu chung "có lỗi xảy ra".
8. [ ] Không gửi lượt chấm cho **người khác**: không endpoint nào nhận tham số người, mọi cửa đều là "của
       chính tôi".

### 8.1 Những thứ server **không** làm trong đợt này

* ❌ Không có **chấm bù / xin điều chỉnh** — bị chặn là mất lượt;
* ❌ Không chấm tại **điểm bán trong tuyến** — chỉ địa điểm công ty khai (`att_geofence`);
* ❌ Không so khớp **khuôn mặt** (ảnh chỉ là bằng chứng, `verify_method` ghi `any`);
* ❌ Không phân biệt **vào/ra**; không có trạng thái "đang trong giờ làm";
* ❌ Không có đường **xoá ảnh** hay **xoá lượt** từ app;
* ❌ Không phân biệt ảnh **chụp trực tiếp** với ảnh **chọn từ thư viện** — ràng buộc "phải mở camera" là
  việc của app, server không kiểm được điều đó.

---

## 9. Tham số vận hành đang áp (đổi được mà không cần bản app mới)

| Tham số (`/system/settings/attendance`) | Giá trị 05/10/2026 | App đọc ở đâu |
|---|---|---|
| Số ảnh bắt buộc mỗi lượt | **2** | `config.photo.min_photos` |
| Trần ảnh mỗi lượt | **10** | `config.photo.max_photos` |
| Bắt buộc đủ cả camera trước + sau | **bật** | `config.photo.require_both` |
| Ngưỡng lệch giờ gắn cờ | **15 phút** | — (server) |
| Ngưỡng sai số GPS gắn cờ | **100 m** | — (server) |
| Hạn lưu ảnh | **90 ngày** | — (server) |
| Bán kính gợi ý khi khai địa điểm mới | **200 m** | — (quản trị) |
| Ca áp cho mọi người | **HC 08:00–17:30**, dung sai trễ **0 phút** | — (bảng công) |

⇒ **Đừng hardcode một con số nào ở bảng trên vào app**, trừ các trần kỹ thuật (10 MB/ảnh, đuôi tệp).

---

## 10. Tình trạng phía server (05/10/2026)

| Hạng mục | Trạng thái |
|---|---|
| 4 endpoint mobile + ống ảnh | ✅ đã lên prod (01/10/2026) |
| 3 quyền + gán vai `employee` | ✅ có trên prod |
| Nhóm luật `MARKET`, chặn cứng ngoài vùng | ✅ 1 dòng, đang bật |
| Ca `HC` + lịch làm việc | ✅ có |
| **Địa điểm chấm công (`att_geofence`)** | 🔴 **0 dòng** ⇒ mọi lượt prod bị `422`; nhân sự phải khai trước |
| Lượt chấm app trên prod | 0 dòng — chưa ai chấm thật |
| Cron tính lại bảng công / dọn ảnh | ⏳ `is_enabled = false`, bật khi có lượt thật |
| Bảng công tự tính sau mỗi lượt | ✅ tính ngay trong lượt gọi `punch` (cron chỉ là lưới an toàn) |
| **Cửa quản trị xem bằng chứng** | ✅ từ 05/10/2026 — màn *Chấm công → Lượt quẹt* của One hiện **địa điểm, toạ độ (mở được bản đồ), sai số GPS, cờ nghi vấn và ẢNH** của từng lượt app |

Khi app gửi được lượt thật, giờ Vào/Ra và số Trễ xuất hiện ngay ở màn *Chấm công → Bảng công* của One, không
phải chờ cron.

⚠️ **Hợp đồng của bốn endpoint mobile KHÔNG đổi ở đợt 05/10** — phần vừa thêm nằm trọn ở cửa quản trị
(`GET /attendance/punches`, chỉ SPA gọi). Nhưng nó đổi một điều về thực tế vận hành đáng để đội mobile biết:
**mọi thứ app gửi lên nay đều có người xem** — ảnh mờ/che mặt, toạ độ lệch, cờ `is_mock_location`, lệch giờ
lớn đều hiện thành một ô trên lưới của nhân sự, và lượt thiếu ảnh bị nhìn thấy là thiếu. Vì vậy hai việc ở
§8 (nén ảnh nhưng đừng nén tới mức không nhận ra người, và gửi trung thực hai cờ máy) không còn là chi tiết
nội bộ của app.

---

## 11. Phụ lục — chuỗi curl đã chạy để viết tài liệu này

Chạy trên API test (`127.0.0.1:8899` → DB `app_test`) ngày 05/10/2026, tài khoản `TEST001`, địa điểm
`[TEST-CC] Văn phòng tài liệu mobile` (21.0277644 / 105.8341598, bán kính 200 m):

| Phép thử | Kết quả thật |
|---|---|
| `config` có toạ độ | `200`, 1 địa điểm, `distance_m: 44` |
| `punch` cách 5.956 m | `422` *"Bạn đang cách … khoảng 5956m…"* |
| `punch` khi chưa khai địa điểm | `422` *"Chưa khai địa điểm chấm công nào…"* |
| `punch` trong vùng | `201`, `id: 8723`, `satisfied: false` |
| `punch` gửi lại cùng uuid | `200`, `duplicate: true`, DB vẫn 1 dòng |
| `punch` với `client_time` lệch 4,5 giờ | `201`, `is_time_tampered: true` (không bị từ chối) |
| `punch` lần 2 cùng ngày, `is_mock_location=1` | `201`, `is_mock_location: true` |
| ảnh `front` → `back` | `201` · `201`, `satisfied: true` |
| gửi lại `front` | `201`, `duplicate: true`, `photo_count` giữ 2 |
| hai tấm `extra` | `201` · `201`, `photo_count` lên 4 |
| `photo_type=selfie` | `422` *"Photo Type không hợp lệ."* |
| ảnh 11 MB | `422` *"File "big.png" (11264 KB) exceeds maximum size limit 10240 KB."* (⇒ trần đúng 10 MB) |
| tệp đuôi `.pdf` | `422` *"Invalid file extension "x.pdf"."* |
| ảnh vào lượt `99999999` | `404` *"Không tìm thấy lượt quẹt."* |
| `punch` thiếu `lat`, uuid sai dạng | `422` + `errors` theo ô |
| `config` không gửi token | `401` |
| xem ảnh qua đường công khai | `200 image/png`, `Cache-Control: …max-age=2592000, immutable` |
| xem ảnh qua đường Bearer | `200 image/png` |
| token ảnh của module khác qua cửa chấm công | `404` |
| `history?days=40` | kẹp 31 ngày |
| `history?days=abc` | `400` |

---

## 12. Tài liệu liên quan

* [`docs/specs/hr/SPEC-CHAM-CONG-APP-2026-10-01.md`](../../specs/hr/SPEC-CHAM-CONG-APP-2026-10-01.md) — 8 quyết định nghiệp vụ, thiết kế đầy đủ
* [`API-VIENG-THAM-MOBILE-2026-09-29.md`](./API-VIENG-THAM-MOBILE-2026-09-29.md) — module viếng thăm (cùng khuôn GPS + ảnh + hàng đợi offline)
* [`API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md`](./API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md) · [`API-THAY-DOI-CHO-MOBILE-2026-10-01.md`](./API-THAY-DOI-CHO-MOBILE-2026-10-01.md)

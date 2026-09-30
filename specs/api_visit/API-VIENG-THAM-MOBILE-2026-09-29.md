# API module VIẾNG THĂM ĐIỂM BÁN — cho app di động

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>` ·
viết 29/09/2026.

Tài liệu này là **hợp đồng đủ để làm trọn một lượt viếng thăm**: từ lấy danh sách điểm bán, check-in, chụp
ảnh, nộp biểu mẫu, tới check-out. Mọi endpoint dưới đây đã được gọi thật bằng `curl` trên bản sao dữ liệu
(`app_test`) ngày 29/09/2026; các đoạn JSON là **phản hồi thật đã cắt gọn**, không phải ví dụ dựng tay.

> 🔴 **Luật nghiệp vụ nằm ở SERVER, app không phải là hàng rào.** App kiểm để làm mờ nút và báo còn thiếu
> gì; server kiểm lại tất cả và là nơi nói không. Vì vậy đừng "tối ưu" bằng cách bỏ một lượt gọi kiểm —
> nhưng cũng đừng sợ bị lỗi: mọi lời từ chối đều kèm **câu tiếng Việt viết cho nhân viên đọc**, hiện thẳng
> câu đó lên là đủ.

---

## 0. Một lượt viếng thăm gồm những bước nào

| # | Việc | Endpoint |
|---|---|---|
| 1 | Đăng nhập | `POST /auth/login` |
| 2 | Lấy điểm bán thuộc tuyến của mình | `GET /dms/routes/customers` |
| 3 | Đánh dấu điểm bán **đã ghé hôm nay** | `GET /dms/visits/mine?date_from=<hôm nay>&date_to=<hôm nay>` |
| 4 | **Check-in** tại điểm bán | `POST /dms/visits` |
| 5 | Chụp ảnh (1 lượt gọi mỗi tấm) | `POST /dms/visits/{id}/photos` |
| 6 | Lấy biểu mẫu khảo sát của điểm bán | `GET /dms/forms/available?kind=survey&customer_id=` |
| 7 | Nộp phiếu | `POST /dms/form-submissions` |
| 8 | Soi "còn thiếu gì mới ra được" | `GET /dms/visits/{id}/requirements` |
| 9 | **Check-out** (gửi kèm toạ độ) | `POST /dms/visits/{id}/checkout` |

Bước 5–8 lặp lại tuỳ ý trong khi lượt còn mở. Bước 3 không cần cột trạng thái nào và **tự reset theo ngày**
— xem §2.3.

---

## 1. Xác thực và quyền

```
POST /auth/login          {"username":"VTG920","password":"…"}   → access_token + refresh_token
POST /auth/refresh        (refresh token)                        → cặp token mới
GET  /auth/me                                                    → hồ sơ người đang đăng nhập
POST /notification/device-token  {"token":"<FCM>", …}            → nhận thông báo đẩy
```

Tài khoản đi tuyến phải giữ vai **`crm_customer_self`**. Vai đó đang có đủ các chuỗi quyền mà tài liệu này
dùng tới:

| Chuỗi quyền | Mở cửa nào |
|---|---|
| `/dms/route/mine` · `/dms/route/mine-customers` | tuyến và điểm bán của mình |
| `/dms/visit/create` | check-in · **tải ảnh** · **xoá ảnh** |
| `/dms/visit/mine` | danh sách lượt của mình · xem ảnh qua đường Bearer |
| `/dms/visit/requirements` · `/dms/visit/checkout` | soi điều kiện · đóng lượt |
| `/dms/form/available` · `/dms/form-submission/create` | biểu mẫu và nộp phiếu |
| `/crm/customer/mine` | sổ điểm bán của mình (nguồn duy nhất có **toạ độ**, xem §11) |

Thiếu quyền ⇒ **403**. Tài khoản không phải nhân sự nội bộ (đối tác) bị chặn ở mọi endpoint viếng thăm.

---

## 2. Điểm bán phải ghé

### 2.1 Tuyến của tôi

```
GET /dms/routes/mine
```

```json
{"success":true,"data":[
  {"id":6706,"code":"…","name":"Phan Thanh Lộc - Thứ 5","visit_day_of_week":5,"sale_group_id":12}
]}
```

`visit_day_of_week`: **0 = Chủ nhật, 1 = Thứ Hai … 6 = Thứ Bảy** (ràng buộc `CHECK … BETWEEN 0 AND 6` ở DB);
`null` = tuyến không gắn thứ — đo prod 29/09/2026: 70 tuyến đang ở trạng thái này. Trần 200 tuyến một lượt gọi.

⚠️ Giá trị này **suy ra từ TÊN tuyến** lúc di trú ("… - Thứ 5"), không phải dữ liệu gốc của hệ cũ. Dùng nó
để sắp xếp và gợi ý thì được; đừng dùng làm hàng rào chặn nhân viên đi bù sang ngày khác — hàng rào thật
nằm ở luật check-in ① (§3), và mặc định của nó (`assigned`) **cho phép** đi bù.

### 2.2 Điểm bán trong mọi tuyến đang bật của tôi

```
GET /dms/routes/customers
```

```json
{"success":true,"data":{"items":[
  {"id":1139,"code":"08670102","name":"195 LONG XUYÊN","address":"Mỹ bình Long Xuyên An Giang"}
],"truncated":false}}
```

* Danh sách **phẳng**, đã khử trùng (một điểm bán nằm ở nhiều tuyến vẫn chỉ ra một dòng).
* Trần **2.000** điểm bán; chạm trần thì `truncated = true` — app phải nói ra thay vì lặng lẽ thiếu điểm
  bán. Đo trên prod 29/09/2026: người nhiều nhất có **1.518** điểm bán ⇒ hiện chưa ai chạm trần.
* ⚠️ **Không có `lat`/`lng`** ở đây. Cần toạ độ để dẫn đường thì lấy qua `GET /crm/customers/mine` (xem §11).

### 2.3 Điểm bán nào ĐÃ GHÉ HÔM NAY

```
GET /dms/visits/mine?date_from=2026-09-29&date_to=2026-09-29&per-page=100
```

```json
{"success":true,"meta":{"total":1,"page":1,"pageSize":100},"data":[
  {"id":127954,"visit_date":"2026-09-29","checkin_at":"2026-09-29 16:17:05+07",
   "checkout_at":"2026-09-29 16:24:18+07","duration_seconds":420,
   "customer_id":3315,"customer_name":"…","visit_result":"visited","photo_count":2,"form_count":1}
]}
```

Cách dùng: gọi một lượt lúc mở app (và sau mỗi lần check-out), rồi đánh dấu mọi `customer_id` xuất hiện
trong kết quả là **đã ghé**. `checkout_at = null` nghĩa là lượt **đang mở** (chưa hoàn thành).

🔴 **Không cần cơ chế reset.** Cờ này là truy vấn theo ngày, nên sang ngày mới danh sách tự rỗng. Và nếu app
có vẽ cờ sai thì server vẫn chặn: check-in lần hai vào cùng điểm bán trong ngày nhận **422 "Hôm nay bạn đã
viếng thăm điểm bán này rồi."**

Bộ lọc dùng được: `date_from` · `date_to` (định dạng `YYYY-MM-DD`, so theo `visit_date`) · `customer_id` ·
`route_id` · `visit_result` · `open_only=1` · `q` · `page` · `per-page` · `sort`.

* `q` tìm **không dấu** trên tên điểm bán, và so thẳng trên **mã điểm bán** + **mã nhân viên** (gõ `nguyen`
  ra `Nguyễn`).
* `per-page` mặc định 20 và **nhận thẳng giá trị client gửi** — xin vài trăm dòng một lượt là tự làm chậm
  chính mình; một ngày đi tuyến hiếm khi quá 40 lượt.
* Màn "của tôi" **không** trả toạ độ, số điện thoại hay người liên hệ của điểm bán (dữ liệu cá nhân) — xem §11.

---

## 3. Check-in — mở một lượt

```
POST /dms/visits
Content-Type: application/json
```

| Tham số | Bắt buộc | Ý nghĩa |
|---|---|---|
| `customer_id` | **có** | Điểm bán đang đứng |
| `lat` · `lng` | nên gửi | Toạ độ lúc check-in. Thiếu ⇒ server **không kết luận được** trong/ngoài vùng và cho qua |
| `accuracy_m` | không | Sai số định vị máy báo (mét) |
| `address` | không | Địa chỉ app giải mã được từ toạ độ (tối đa 1.000 ký tự) |
| `is_mock_location` | không | `true` khi máy báo đang giả lập vị trí |
| `client_uuid` | **nên gửi** | UUID app sinh — khoá chống gửi trùng, xem §9 |
| `client_time` | **nên gửi** | Giờ trên máy (ISO-8601) — dùng để đo lệch đồng hồ, **không** để tính giờ |
| `queued_seconds` | **bắt buộc khi `is_offline_sync=true`** | Bản ghi đã nằm chờ bao nhiêu **giây** trong hàng đợi, đo bằng **bộ đếm phần cứng**. Server dựng `checkin_at` từ đây — xem §9.1 |
| `client_boot_id` | nên gửi | Định danh phiên khởi động của máy — để đối soát, xem §9.1 |
| `km_declared` | không | Quãng đường tự khai tới điểm bán này (km) |
| `note` | không | Ghi chú của nhân viên |
| `device_info` | không | Object tự do: máy, hệ điều hành, phiên bản app |
| `is_offline_sync` | không | `true` khi bản ghi đến từ hàng đợi ngoại tuyến |

```json
{"success":true,"message":"Đã tạo thành công.","data":{
  "id":127954,"checkin_at":"2026-09-29 16:17:05.154136+07","route_id":6706,"is_on_route":true,
  "requirements":{"satisfied":false,"seconds_remaining":300,"photos_missing":2,"missing_forms":[],
    "blockers":["Bạn cần ở lại thêm 5 phút nữa mới check-out được.","Bạn cần chụp thêm 2 ảnh nữa."]}}}
```

### Năm luật check-in (server từ chối bằng **422** kèm câu tiếng Việt)

| Luật | Câu từ chối |
|---|---|
| ① Điểm bán phải thuộc **tuyến được giao** cho mình | "Điểm bán này không thuộc tuyến nào được giao cho bạn." (hoặc "…không nằm trong tuyến đi hôm nay của bạn." nếu admin siết về chế độ `today`) |
| ② Một điểm bán, **một ngày, một lượt** | "Hôm nay bạn đã viếng thăm điểm bán này rồi." |
| ③ Không mở lượt mới khi **còn lượt treo** | "Bạn còn một lượt viếng thăm chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới." |
| ④ Đứng **ngoài bán kính** điểm bán | "Bạn đang cách điểm bán 137m. Hãy lại gần hơn rồi check-in." |
| ⑤ **Giả lập vị trí**: mặc định vẫn cho qua, chỉ gắn cờ đỏ vào báo cáo | (không chặn — trừ khi admin bật công tắc) |

Điểm bán không có toạ độ trong hồ sơ ⇒ không có gì để so ⇒ luật ④ **luôn cho qua**.

---

## 4. Ảnh của lượt

### 4.1 Tải một tấm lên

```
POST /dms/visits/{id}/photos
Content-Type: multipart/form-data
```

| Trường | Bắt buộc | Ý nghĩa |
|---|---|---|
| `file` | **có** | Tệp ảnh. Chỉ nhận `jpg, jpeg, png, gif, webp, bmp`; trần **10 MB/tấm** (đo 29/09/2026; admin đổi được ở cấu hình hệ thống). Ảnh bitmap được server tự thu về chuẩn HD và nén lại |
| `photo_type` | không | `display` (trưng bày) · `store_front` (mặt tiền) · `posm` · `document` · `other`. Mặc định `other` |
| `taken_at` | không | Giờ chụp theo máy (ISO-8601) — chỉ để hiển thị |
| `lat` · `lng` | không | Toạ độ lúc chụp |

```json
{"success":true,"message":"Đã tải ảnh lên. Lượt viếng thăm hiện có 1 ảnh.","data":{
  "id":191,"file_id":11917,"token":"fb3214388b3b66970baf3296de3e0da0",
  "url":"/dms/visit-photos/public/fb3214388b3b66970baf3296de3e0da0",
  "photo_type":"display","photo_type_label":"Ảnh trưng bày","photo_type_color":"primary",
  "taken_at":"2026-09-29 15:40:00+07","sort_order":0,
  "duplicate":false,"photo_count":1,
  "requirements":{"satisfied":false,"seconds_remaining":0,"photos_missing":1,"missing_forms":[],
    "blockers":["Bạn cần chụp thêm 1 ảnh nữa."]}}}
```

Bốn điều phải biết:

1. **Một lượt gọi = một tấm.** Chụp 2 tấm thì gọi 2 lần. Phản hồi luôn kèm `photo_count` và `requirements`
   mới nhất nên app **không cần** gọi thêm để cập nhật checklist.
2. 🔴 **Gửi lại đúng một tấm KHÔNG sinh ảnh thứ hai.** Server so nội dung tệp (SHA-1) trong phạm vi lượt đó;
   lượt gửi lại trả về ảnh cũ với `"duplicate": true` và câu *"Ảnh này đã có trong lượt viếng thăm, không
   thêm gì thêm."* — hãy hiện đúng câu đó, đừng hiện "đã tải lên" trong khi `photo_count` không tăng.
3. **`url` là đường xem công khai theo token** — dùng thẳng trong thẻ ảnh, không cần header. Ghép với host:
   `https://api-app.vthmgroup.vn/dms/visit-photos/public/<token>`. Ảnh được cache 30 ngày (nội dung một
   token là bất biến). Có sẵn đường đòi Bearer cho HTTP client: `GET /dms/visit-photos/{token}`.
4. **Trần 20 ảnh một lượt** (chống hàng đợi ngoại tuyến đẩy vài trăm tấm). Đủ trần ⇒ 422 *"Lượt viếng thăm
   này đã đủ 20 ảnh — mức tối đa hệ thống nhận."*

Camera bắt buộc (cấm chọn từ thư viện) là **việc của app**: server không phân biệt được hai nguồn đó.

### 4.2 Xoá một tấm chụp lỗi

```
DELETE /dms/visits/{id}/photos/{photoId}
```

```json
{"success":true,"message":"Đã xoá ảnh. Lượt viếng thăm hiện có 1 ảnh.","data":{
  "id":192,"photo_count":1,
  "requirements":{"satisfied":false,"photos_missing":1,"seconds_remaining":0,"missing_forms":[],
    "blockers":["Bạn cần chụp thêm 1 ảnh nữa."]}}}
```

Chỉ xoá được khi **lượt chưa check-out**. Sau khi đóng lượt: 422 *"Không xoá được ảnh của lượt đã
check-out."* — ảnh là bằng chứng mà cổng ③ đã phán quyết dựa trên đó.

---

## 5. Biểu mẫu khảo sát trong lượt

### 5.1 Lấy biểu mẫu còn hiệu lực

```
GET /dms/forms/available?kind=survey&customer_id=3315
```

`kind=survey` = biểu mẫu hiện **trong luồng check-in** (bắt buộc kèm `customer_id`) ·
`kind=collect` = biểu mẫu ở **menu chính** (không gắn lượt).

Mỗi phần tử mang `config_id`, `form_id`, `name`, `is_required`, `sort_order` và **`schema` trọn cây ô** —
app vẽ được ngay, không phải gọi thêm. Chi tiết hình dạng `schema` và danh sách loại ô app phải vẽ:
[`API-BIEU-MAU-THI-TRUONG-2026-09-23.md`](API-BIEU-MAU-THI-TRUONG-2026-09-23.md) và
[`API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md`](API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md).

### 5.2 Nộp phiếu

```
POST /dms/form-submissions
Content-Type: application/json
```

| Tham số | Bắt buộc | Ý nghĩa |
|---|---|---|
| `config_id` | **có** | Lấy từ `available` |
| `answers` | **có** | Object `{mã ô: giá trị}` |
| `visit_id` | với `survey` | Lượt đang mở. Phiếu `collect` **không** được gắn lượt |
| `customer_id` | nên gửi | Điểm bán của phiếu |
| `client_uuid` | **nên gửi** | Khoá chống gửi trùng, xem §9 |
| `submit_lat` · `submit_lng` · `submit_address` | không | Vị trí lúc nộp |
| `client_time` · `is_offline_sync` | **nên gửi** | Như ở check-in |
| `queued_seconds` · `client_boot_id` | **bắt buộc khi `is_offline_sync=true`** | Như ở check-in — server dựng `submitted_at` từ đây, xem §9.1. Thiếu thì phiếu nộp lúc 9h sáng bị đóng dấu giờ gửi, lệch với chính lượt viếng thăm chứa nó |

```json
lần 1 → {"success":true,"message":"Đã nộp 1 câu trả lời.","data":{"id":442,"duplicate":false}}
lần 2 → {"success":true,"message":"Phiếu này đã được ghi nhận trước đó, không thêm gì thêm.",
         "data":{"id":442,"duplicate":true}}
```

🔴 **Từ 29/09/2026 nộp phiếu là idempotent theo `client_uuid`** — gửi lại bao nhiêu lần cũng chỉ một phiếu.
Trước đó lượt gửi lại nhận lỗi ràng buộc DB, nên **hàng đợi ngoại tuyến bắt buộc phải gửi kèm
`client_uuid`** và giữ nguyên mã đó qua mọi lần thử lại.

Hai câu từ chối cần xử riêng:

| Tình huống | Câu trả về |
|---|---|
| Nộp lại biểu mẫu **khác uuid** cho cùng lượt | "Lượt viếng thăm này đã nộp biểu mẫu khảo sát đó rồi." (một lượt chỉ một phiếu cho mỗi biểu mẫu khảo sát) |
| `client_uuid` trùng một phiếu **đã bị xoá** | "Phiếu mang mã gửi này đã bị xoá. Hãy gửi lại với một mã `client_uuid` mới." ⇒ app phải **sinh uuid mới**, thử lại cùng mã sẽ lặp mãi |

---

## 6. Soi điều kiện check-out (không đóng lượt)

```
GET /dms/visits/{id}/requirements
GET /dms/visits/{id}/requirements?visit_result=closed     # soi theo luật của lượt ĐÓNG CỬA
```

```json
{"success":true,"data":{"satisfied":true,"seconds_remaining":0,"photos_missing":0,
  "missing_forms":[],"blockers":[]}}
```

| Khoá | Ý nghĩa |
|---|---|
| `satisfied` | `true` ⇒ bấm check-out sẽ thành công |
| `seconds_remaining` | Còn thiếu bao nhiêu **giây** mới đủ thời gian tối thiểu |
| `photos_missing` | Còn thiếu bao nhiêu ảnh |
| `missing_forms` | `[{"form_id":9809,"name":"Khảo sát giá tháng 9"}, …]` — biểu mẫu **bắt buộc** chưa nộp |
| `blockers` | Danh sách **câu tiếng Việt**, mỗi câu là một việc phải làm — hiện thẳng lên UI |

### Ba cổng check-out

| Cổng | Điểm bán **MỞ CỬA** (`visit_result=visited`) | Điểm bán **ĐÓNG CỬA** (`closed`) |
|---|---|---|
| ① Thời gian tối thiểu ở điểm bán | phải đủ | **bỏ qua** |
| ② Biểu mẫu khảo sát bắt buộc | phải nộp **hết** | **bỏ qua** |
| ③ Số ảnh tối thiểu | theo ngưỡng lượt mở cửa | theo ngưỡng riêng của lượt đóng cửa |

Lượt đóng cửa được miễn ① ② là **quyết định nghiệp vụ**: không ai điền được khảo sát giá của một cửa hàng
không mở. Đổi lại, **ảnh là bằng chứng duy nhất** của lượt đó.

Mốc tính thời gian là `checkin_at` **của server**, không phải giờ máy — chỉnh đồng hồ máy không mở được cổng ①.

---

## 7. Check-out — đóng lượt

```
POST /dms/visits/{id}/checkout
Content-Type: application/json
```

| Tham số | Bắt buộc | Ý nghĩa |
|---|---|---|
| `visit_result` | **có** | `visited` (mở cửa) · `closed` (đóng cửa) |
| `closed_note` | không | Ghi chú, **chỉ lưu khi** `visit_result=closed` |
| `lat` · `lng` | **nên gửi** | Vị trí lúc bấm check-out (app tự lấy rồi truyền vào) |
| `accuracy_m` | không | Sai số định vị (mét) |
| `client_time` | **nên gửi** | Giờ máy lúc bấm |
| `queued_seconds` | **bắt buộc khi lượt đến từ hàng đợi** | Khoảng chờ của **gói tin check-out này** (khác gói check-in). Server dựng `checkout_at` và tính `duration_seconds` từ đây — xem §9.1 |
| `client_boot_id` | nên gửi | Định danh phiên khởi động của máy |

```json
{"success":true,"data":{"id":127954,"checkout_at":"2026-09-29 16:24:18.301848+07",
  "duration_seconds":420,"visit_result":"visited",
  "checkout_lat":"10.7769123","checkout_lng":"106.7009456"}}
```

* `checkout_lat`/`checkout_lng` trả về là **thứ server đã ghi**, không phải thứ app vừa gửi — dùng nó để
  đối chiếu thay vì tin vào mã 200 trống.
* **Toạ độ không bắt buộc.** Máy mất GPS trong nhà, người dùng từ chối quyền vị trí, app phiên bản cũ —
  lượt vẫn đóng được. Nhưng **gửi được thì hãy gửi**: đó là dữ liệu duy nhất phân biệt "đứng trong quầy 40
  phút" với "check-in rồi đi hẳn mới bấm ra".
* **`null` không xoá giá trị đã có:** gửi lại lệnh đóng mà thiếu toạ độ thì vệt vị trí cũ vẫn còn.
* Chưa qua đủ ba cổng ⇒ **422**, `message` là các câu `blockers` nối lại.
  Lượt đã đóng ⇒ 422 *"Lượt viếng thăm này đã check-out rồi."*

---

## 8. Quy ước phản hồi và mã lỗi

Mọi phản hồi đều cùng một phong bì:

```json
{"success":true,  "message":"…", "data":{…}}
{"success":true,  "message":"…", "data":[…], "meta":{"total":42,"page":1,"pageSize":20}}
{"success":false, "message":"…", "errors":{"customer_id":["…"]}, "data":null, "code":"NOT_FOUND"}
```

| Mã | Khi nào | App nên làm gì |
|---|---|---|
| **200 / 201** | thành công | — |
| **401** | thiếu / hết hạn `access_token` | gọi `POST /auth/refresh`, thử lại |
| **403** | tài khoản không có quyền cho cửa đó | không thử lại; báo người dùng liên hệ quản trị |
| **404** | không có bản ghi, **hoặc bản ghi không phải của mình** | không thử lại |
| **422** | dữ liệu sai hình dạng (`errors` theo từng ô), **hoặc luật nghiệp vụ từ chối** (`message` là câu tiếng Việt) | hiện `message`/`errors` lên UI; chỉ thử lại sau khi người dùng sửa |
| **5xx** | lỗi máy chủ | đưa vào hàng đợi, thử lại sau |

🔴 **404 cố ý không phân biệt "không tồn tại" với "không phải của bạn"** — lượt của người khác trả 404 cho cả
tải ảnh và xoá ảnh. Đừng suy ra sự tồn tại của bản ghi từ mã lỗi.

---

## 9. Đồng bộ ngoại tuyến — `client_uuid` dùng ở đâu

| Endpoint | Idempotent? | Ghi chú |
|---|---|---|
| `POST /dms/visits` (check-in) | ✅ theo `client_uuid` | Gửi lại trả về **đúng lượt cũ**, không phải lỗi |
| `POST /dms/form-submissions` (nộp phiếu) | ✅ theo `client_uuid` (từ 29/09/2026) | Gửi lại trả `duplicate: true` + id cũ |
| `POST /dms/visits/{id}/photos` (ảnh) | ✅ theo **nội dung tệp** | Không cần uuid; cùng một tấm gửi lại không sinh dòng mới |
| `POST /dms/visits/{id}/checkout` | ❌ | Lượt đã đóng thì lần gửi sau nhận 422 — coi 422 *"đã check-out rồi"* là **thành công** khi đang dọn hàng đợi |
| `DELETE …/photos/{photoId}` | ❌ | Xoá lần hai nhận 404 — cũng coi là thành công |

Quy tắc chung cho hàng đợi: **sinh `client_uuid` một lần, giữ nguyên qua mọi lần thử lại**, và gửi
`is_offline_sync=true` + `client_time` + `queued_seconds` (§9.1).

⚠️ **Thứ tự dọn hàng đợi có ý nghĩa.** Luật ③ ("không mở lượt mới khi còn lượt treo") được soi **lúc gói tin
đến**, không phải lúc bấm. Dồn hết check-in rồi mới gửi check-out thì **lượt thứ hai bị từ chối**. Dọn theo
đúng thứ tự phát sinh của từng lượt: check-in → ảnh → phiếu → check-out, rồi mới sang lượt kế.

---

## 9.1 🔴 `queued_seconds` — đồng hồ đơn điệu, và ba chỗ làm hỏng nó IM LẶNG

**Vì sao có mục này.** Trước 30/09/2026 server ghi `checkin_at` bằng **giờ lúc gói tin đến**. Ghé lúc 9h
sáng mà 18h mới có sóng thì báo cáo ghi 18h; mất sóng qua đêm thì lượt rơi sang **ngày hôm sau**; và khi dọn
hàng đợi (check-in với check-out đến liền nhau) thì thời lượng ra vài giây nên **cổng ① từ chối check-out**
của một người đã đứng thật 20 phút.

Không chữa được bằng `client_time` — vặn đồng hồ máy là xong. Nên app gửi thêm **khoảng thời gian bản ghi
thực sự nằm chờ**, đo bằng **bộ đếm phần cứng không vặn được**, rồi server dựng mốc bằng đồng hồ CỦA NÓ:

```
checkin_at  =  giờ_server_lúc_nhận  −  queued_seconds
clock_skew  =  (giờ_server − client_time) − queued_seconds      ← lệch đồng hồ THẬT, đã trừ thời gian chờ
```

### Cách tính trong app

```
lúc TẠO bản ghi:  created_elapsed = <bộ đếm phần cứng>      (lưu vào hàng đợi cùng bản ghi)
                  created_boot_id = <định danh phiên khởi động>
lúc GỬI:          queued_seconds  = <bộ đếm hiện tại> − created_elapsed
```

### 🔴 Ba chỗ hỏng câm — không có mã lỗi nào để lần ra

**① Chọn nhầm loại đồng hồ.** Phải dùng loại **CÓ đếm thời gian máy ngủ sâu**:

| Nền tảng | Dùng | ĐỪNG dùng |
|---|---|---|
| Android | `SystemClock.elapsedRealtime()` | `SystemClock.uptimeMillis()` — **không** đếm ngủ sâu |
| iOS | neo theo `kern.boottime` (`sysctl`) | `mach_absolute_time`, `CLOCK_MONOTONIC`, `Stopwatch` của Dart — đều **dừng** khi máy ngủ |

⚠️ **Phải ĐO TRÊN MÁY THẬT trước khi chốt** (nhất là iOS): để máy ngủ 30 phút rồi so `queued_seconds` với
đồng hồ treo tường. Điện thoại nằm trong túi ở vùng mất sóng ngủ gần như liên tục, nên đây là ca **chính**,
không phải ca hiếm. Chọn sai ⇒ `queued_seconds` nhỏ hơn thật hàng giờ ⇒ server thấy lệch đồng hồ lớn và
**gắn cờ oan nhân viên làm thật**.

**② Máy khởi động lại giữa chừng.** Bộ đếm về 0, nên hiệu số qua hai phiên boot là **rác trông như số thật**.
Phải so `created_boot_id` với phiên hiện tại; khác nhau thì **gửi `queued_seconds` RỖNG**, đừng gửi 0 và
đừng đoán. Server gặp rỗng sẽ rơi về hành vi cũ (lấy giờ lúc nhận) — mất độ chính xác, nhưng không bịa ra
một mốc sai. Hết pin giữa buổi là chuyện thường ngoài thị trường.

**③ Check-in và check-out là HAI gói tin, hai khoảng chờ khác nhau.** Gửi cùng một con số cho cả hai thì
thời lượng lượt ra 0. Mỗi gói mang `queued_seconds` của chính nó.

### Server làm gì với con số đó

* **Kẹp trần.** `queued_seconds` là số app gửi nên server không tin thẳng: nó kẹp theo **khoảng thời gian
  thiết bị thực sự mất liên lạc** (suy từ lần cuối làm mới token / nhận push), và khi không tra được thì
  dùng tham số `visit_offline_max_queue_hours` (mặc định **24 giờ**).
* **Khai vượt trần ⇒ CẮT + gắn cờ, KHÔNG từ chối.** Lượt vẫn được ghi; nó chỉ vào danh sách nghi vấn của
  quản lý. Lý do phổ biến nhất của khai vượt là lỗi ① ở trên, không phải gian lận — từ chối thì nhân viên
  mất lượt vì một lỗi họ không gây ra.
* **Khai không nhất quán** (mốc ra lùi ra trước mốc vào) ⇒ server **vứt hẳn** con số của gói đó, quay về giờ
  lúc nhận, và gắn cờ.
* **Lệch đồng hồ vượt `visit_clock_skew_tolerance_minutes` (mặc định 15 phút)** sau khi đã trừ thời gian chờ
  ⇒ gắn cờ nghi can thiệp giờ.

### ⚠️ Nói thẳng giới hạn

Cơ chế này chặn **vặn đồng hồ để đổi GIỜ GHÉ**. Nó **không** chặn được app bị sửa khai khống **thời lượng**
để qua cổng ①. Chủ hệ thống đã chốt 30/09/2026: với bản ghi ngoại tuyến, **cổng "5 phút tối thiểu" là cổng
CHẤT LƯỢNG, không phải cổng chống gian lận**. Hàng rào chống gian lận là **geofence** (phải đứng ở điểm bán
mới check-in được) và **ảnh** (phải có bằng chứng tại chỗ).

---

## 10. Tham số vận hành (admin đổi được, app đừng hardcode)

Quản trị viên đổi ở `/system/settings/dms` → nhóm *"Luật viếng thăm điểm bán"*. Giá trị **đang chạy** trên
prod ngày 29/09/2026 (chưa ai đổi nên đều là mặc định):

| Tham số | Hiện tại | Ảnh hưởng tới app |
|---|---|---|
| Thời gian tối thiểu ở điểm bán | **5 phút** | cổng ① |
| Số ảnh tối thiểu (mở cửa) | **2 ảnh** | cổng ③ |
| Số ảnh tối thiểu (đóng cửa) | **1 ảnh** | cổng ③ |
| Phạm vi điểm bán được check-in | **`assigned`** (mọi điểm bán thuộc tuyến được giao) | luật ① |
| Chặn check-in ngoài bán kính | **bật** | luật ④ |
| Bán kính mặc định quanh điểm bán | **100 m** | luật ④ |
| Chặn khi máy báo giả lập vị trí | **tắt** (chỉ gắn cờ) | luật ⑤ |
| Tự đóng lượt treo sau | **12 giờ** | lượt quên bấm ra bị cron đóng, `duration_seconds = null` |
| Ngưỡng lệch giờ máy bị coi là nghi vấn | **15 phút** | chỉ gắn cờ, không chặn |

⚠️ **Đừng chép mấy con số này vào app.** Nguồn duy nhất app nên tin là `requirements` (§6): nó đã tính sẵn
"còn thiếu bao nhiêu" theo tham số hiện hành.

---

## 11. Những gì API CHƯA có (đã biết, đang chờ quyết)

1. **`GET /dms/routes/customers` không trả `lat`/`lng`.** Cần toạ độ để dẫn đường hoặc soi khoảng cách
   trước khi bấm thì lấy qua `GET /crm/customers/mine` (vai `crm_customer_self` đã có quyền) rồi ghép theo
   `id`. Đo 29/09/2026 với một tài khoản đi tuyến: 1.288 dòng, mỗi dòng có `id, code, name, lat, lng,
   address, phone, in_route, is_owned, routes`. Đó là **hai danh sách khác nhau**: `crm/customers/mine` là
   *sổ khách của tôi* (được phân công hoặc tự mở) **hợp** với *điểm bán trong tuyến của tôi* — nên nó có
   thể rộng hơn hoặc hẹp hơn `routes/customers`; khoá `in_route` cho biết dòng nào đến từ tuyến.
2. **Không có endpoint phơi bán kính geofence của từng điểm bán** và bộ ngưỡng ở §10. App vì vậy chỉ biết
   mình đứng quá xa **sau khi** server trả 422. Nếu cần khoá nút từ trước, hãy yêu cầu — sẽ thêm một endpoint
   cấu hình cho app.
3. **Vai nhân viên không xem được chi tiết một lượt** (`GET /dms/visits/{id}`) và **không xem lại được phiếu
   đã nộp** (`GET /dms/form-submissions`): hai cửa đó hiện chỉ mở cho vai quản lý. Theo phạm vi chủ hệ thống
   chốt 29/09/2026 thì app **không cần** hai cửa này; cần thì nói để mở chuỗi quyền hẹp.
4. **Không có đường xoá lượt.** Lượt viếng thăm cố ý không có thùng rác; bấm sai thì để cron tự đóng sau 12 giờ.
5. **`photo_urls` gộp CẢ HAI nguồn ảnh** (đổi 30/09/2026 — trước đó chỉ có ảnh MobiWork). Khoá này có trên
   từng dòng của `GET /dms/visits/mine`, và **trộn hai dạng đường dẫn**:
   * ảnh app tải lên → **TƯƠNG ĐỐI**: `/dms/visit-photos/public/<token>` — ghép base URL của API vào rồi
     mới dùng (`https://api-app.vthmgroup.vn` + chuỗi đó);
   * ảnh MobiWork lịch sử của 92.388 lượt cũ → URL **tuyệt đối** `https://dmsimages.mobiwork.vn/…`.

   Cứ kiểm `startsWith('http')` để phân biệt; ảnh app luôn đứng TRƯỚC trong mảng. Cột `photo_count` đếm
   **gộp hai nguồn**, ưu tiên ảnh đã tải về kho; nhưng **cổng ③ của check-out chỉ đếm ảnh app chụp** —
   một lượt cũ có 3 ảnh MobiWork vẫn phải chụp đủ ảnh mới nếu nó được mở lại.

---

## 12. Nhật ký thay đổi

| Ngày | Thay đổi |
|---|---|
| 28/09/2026 | Module viếng thăm lên sóng: check-in, requirements, check-out, báo cáo |
| **29/09/2026** | Thêm **đường tải/xoá/xem ảnh** (`/dms/visits/{id}/photos`, `/dms/visit-photos/…`) — trước đó không có cách nào qua cổng ③ · **nộp phiếu thành idempotent** theo `client_uuid` · **check-out nhận toạ độ** (`lat`/`lng`/`accuracy_m`) |
| **30/09/2026** | **`queued_seconds` + `client_boot_id`** trên check-in / check-out / nộp phiếu — server dựng mốc bấm THẬT thay vì mốc gói tin đến, xem §9.1. Trước đó lượt gửi từ hàng đợi bị ghi sai giờ, sai ngày, và bị cổng ① chặn oan |
| **30/09/2026** | `photo_urls` trên `GET /dms/visits/mine` nay **gộp cả ảnh app tải lên** (đường tương đối) lẫn ảnh MobiWork (URL tuyệt đối) — xem §11.5. Trước đó lượt do app sinh ra có `photo_count` > 0 nhưng `photo_urls` rỗng |

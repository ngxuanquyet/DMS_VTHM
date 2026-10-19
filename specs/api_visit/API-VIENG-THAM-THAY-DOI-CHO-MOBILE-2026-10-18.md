# Thay đổi API ngày 18/10/2026 — biểu mẫu "chỉ lần đầu / từ lần thứ hai" + "lượt của tôi" bỏ cờ gian lận

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi ngày 18/10/2026** và app cần làm gì. Mọi JSON dưới đây là phản hồi **thật**,
gọi bằng `curl` trên bản sao dữ liệu (`app_test`) ngày 19/10/2026 bằng tài khoản nhân viên thị trường thật (tên người,
tên điểm bán, ghi chú và link ảnh đã che bằng `…`).

Hợp đồng đầy đủ vẫn là [`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md) (viếng thăm) và
[`API-BIEU-MAU-THI-TRUONG-2026-09-23.md`](API-BIEU-MAU-THI-TRUONG-2026-09-23.md) (biểu mẫu) — file này chỉ là phần đổi.
Việc của đội app trong sổ: **#23647**.

> 🔴 **Có XOÁ KHOÁ** khỏi `GET /dms/visits/mine` (§2) — app đang hiện khoảng cách / cờ trên màn lịch sử lượt của mình
> sẽ nhận thiếu khoá. Rà §2 trước khi phát hành bản kế tiếp. Đã có hiệu lực trên prod từ 18/10/2026.

| # | Thay đổi | Loại | App phải làm |
|---|---|---|---|
| 1 | `GET /dms/forms/available` (khảo sát) trả thêm `visit_scope`; server lọc biểu mẫu theo **lượt viếng thăm** | **THÊM KHOÁ + ĐỔI HÀNH VI** | **Gọi lại danh sách biểu mẫu ngay sau check-in** (§1.3) |
| 2 | `GET /dms/visits/mine` **bỏ** cờ gian lận, khoảng cách, cảnh báo | **XOÁ KHOÁ** | Ngừng đọc / ngừng hiện các khoá ở §2.2 |
| 3 | Thu hồi hướng dẫn §3 ③ của [`…-2026-10-13.md`](API-VIENG-THAM-THAY-DOI-CHO-MOBILE-2026-10-13.md) ("hiện `checkout_distance_m` cạnh `distance_to_customer_m`") và khoá #4 của [`…-2026-10-15.md`](API-VIENG-THAM-THAY-DOI-CHO-MOBILE-2026-10-15.md) (`is_checkout_other_day`) | **THU HỒI** | Gỡ phần hiển thị đã làm theo hai mục đó |

---

## 1. Biểu mẫu khảo sát theo lượt viếng thăm (`visit_scope`)

### 1.1 Nghiệp vụ

Quản trị gán biểu mẫu khảo sát với một trong ba lựa chọn:

| `visit_scope` | Biểu mẫu hiện khi |
|---|---|
| `all` | Mọi lượt (mặc định — mọi cấu hình cũ đều là `all`) |
| `first` | Lượt **đầu tiên** của điểm bán |
| `repeat` | Từ lượt **thứ hai** trở đi |

* "Lần đầu" tính theo **ĐIỂM BÁN**, không theo nhân viên: điểm bán chưa từng có lượt nào (kể cả lịch sử MobiWork đã
  nhập; lượt đã **huỷ** không tính). Đúng cờ `is_first_visit` mà `POST /dms/visits` đã trả từ trước.
* Bỏ qua biểu mẫu `first` ở lần đầu thì nó **không hiện lại** ở lần sau. Muốn chắc có dữ liệu, quản trị bật thêm
  `is_required` — khi đó cổng check-out chặn tới khi nộp.
* Chỉ áp cho khảo sát (`kind=survey`). Biểu mẫu thu thập (`kind=collect`, mở từ menu chính) luôn là `all`.

### 1.2 Server lọc sẵn — app KHÔNG tự lọc

`GET /dms/forms/available?kind=survey&customer_id=<id>` — không thêm tham số nào. Server tự quyết lượt đang xét:

* Người gọi **đang có lượt MỞ** (chưa check-out, chưa huỷ) tại điểm bán đó ⇒ theo `is_first_visit` của chính lượt đó.
* **Chưa check-in** ⇒ theo "điểm bán đã có lượt nào chưa".

Mỗi phần tử có thêm khoá `visit_scope` (chỉ để hiện nếu muốn, ví dụ nhãn "Lần đầu"). Cùng một luật, hai điểm bán
thuộc tuyến của cùng nhân viên:

**Điểm bán CHƯA từng được ghé** — biểu mẫu `first` có mặt (đã bỏ khoá `schema` cho gọn):

```json
GET /dms/forms/available?kind=survey&customer_id=7627
{"success":true,"message":"Thành công","data":[
  {"config_id":6077,"form_id":9861,"code":"zz_testcc_chung","name":"[TEST-CC] Biểu mẫu dùng chung",
   "kind":"survey","is_required":true,"visit_scope":"first","sort_order":0,"schema":{…}},
  …
]}
```

**Điểm bán ĐÃ được ghé** — cùng luật đó KHÔNG có mặt (danh sách còn 1 biểu mẫu `all` khác):

```json
GET /dms/forms/available?kind=survey&customer_id=4724
{"success":true,"message":"Thành công","data":[ { …biểu mẫu khác, "visit_scope":"all"… } ]}
```

### 1.3 🔴 Việc app PHẢI làm: gọi lại danh sách biểu mẫu ngay sau check-in

Nếu app tải trước danh sách biểu mẫu (để dùng ngoại tuyến) rồi giữ nguyên bản đó suốt lượt:

1. 07:00 app tải trước ở điểm bán X — X chưa ai ghé ⇒ nhận biểu mẫu `first`, **không** có biểu mẫu `repeat`.
2. 09:00 đồng nghiệp ghé X và check-out.
3. 11:00 bạn check-in ở X ⇒ server đóng dấu lượt của bạn `is_first_visit = false`.
4. Cổng check-out đọc cờ của **chính lượt đó** ⇒ đòi biểu mẫu `repeat` bắt buộc mà bản cache không có ⇒
   **nhân viên kẹt ở điểm bán**, không có cách nào tự gỡ.

Vì vậy: **sau mỗi lần check-in thành công, gọi lại `/dms/forms/available`** cho điểm bán đó và vẽ theo kết quả mới.
Check-in ngoại tuyến thì gọi lại ngay khi lượt đồng bộ lên server xong. Cổng check-out (`GET /dms/visits/{id}/requirements`)
luôn là nguồn sự thật về "còn thiếu biểu mẫu nào".

---

## 2. `GET /dms/visits/mine` — bỏ cờ gian lận, khoảng cách, cảnh báo

Chủ hệ thống chốt 18/10/2026: **nhân viên không xem cờ vi phạm, cảnh báo, khoảng cách của chính lượt mình** — đó là công
cụ của quản lý (Báo cáo viếng thăm / Nghi vấn giờ & vị trí trên web). Áp cho CẢ app lẫn web One.

### 2.1 Khoá CÒN trên mỗi dòng

```json
GET /dms/visits/mine?per-page=1
{"success":true,"message":"Thành công","data":[
  {"id":43928,"visit_date":"2026-09-16",
   "checkin_at":"2026-09-16 10:09:00+07","checkout_at":"2026-09-16 13:10:00+07","duration_seconds":10860,
   "user_id":1009,"customer_id":8737,"visit_result":"visited","closed_note":null,"note":"…",
   "is_first_visit":false,"customer_code":"08500394","customer_name":"…",
   "customer_approval_status":"approved","customer_approval_note":null,
   "route_name":null,"employee_name":"…","photo_count":2,"form_count":0,
   "photo_urls":["https://dmsimages.mobiwork.vn/viewimage?url=…","https://dmsimages.mobiwork.vn/viewimage?url=…"],
   "visit_result_label":"Điểm bán mở cửa","visit_result_color":"success"}
],"meta":{"total":2271,"currentPage":1,"pageSize":1,"pageCount":2271}}
```

| Khoá | Ghi chú |
|---|---|
| `id`, `visit_date`, `checkin_at`, `checkout_at`, `duration_seconds` | như cũ |
| `user_id`, `employee_name` | người đi |
| `customer_id`, `customer_code`, `customer_name` | điểm bán |
| `route_name` | `null` với lượt di trú hệ cũ / lượt ngoài tuyến |
| `visit_result`, `visit_result_label`, `visit_result_color` | **mới**: nhãn + màu (Bootstrap) do server phát, app khỏi tự dịch |
| `closed_note`, `note`, `is_first_visit` | như cũ |
| `photo_count`, `form_count`, `photo_urls` | như cũ (`photo_urls` trộn đường tương đối + tuyệt đối, xem §11.5 hợp đồng 29/09) |
| `customer_approval_status`, `customer_approval_note` | **giữ** — trạng thái duyệt của ĐIỂM BÁN (hợp đồng 15/10) |

Tham số lọc/sắp/phân trang **không đổi** (`date_from`, `date_to`, `q`, `visit_result`, `sort`, `page`, `per-page`…).

### 2.2 Khoá ĐÃ BỎ

`distance_to_customer_m`, `is_within_geofence`, `checkout_distance_m`, `is_checkout_within_geofence`,
`is_checkout_other_day`, `is_mock_location`, `is_time_tampered`, `time_diff_seconds`, `is_on_route`, `route_id`,
`employee_code`, `checkin_address`, `device_info`, `is_offline_sync`, `km_declared`, và các cột hồ sơ điểm bán
(`customer_type`, `customer_channel`, `customer_phone`, `customer_contact`, `customer_address`…).

* Cần hồ sơ điểm bán ⇒ `GET /crm/customers/mine` (đã có).
* Lịch sử viếng thăm của MỘT điểm bán (`GET /dms/customers/{id}/visit-history`) vốn đã không có các khoá trên từ 16/10 —
  không đổi.

### 2.3 App phải làm

* Màn "lịch sử lượt của tôi": gỡ cột/nhãn khoảng cách, "ngoài vùng", "GPS giả", "lệch giờ", "ra khác ngày".
* Đọc khoá bằng cách chịu được thiếu (`json['x'] ?? null`) — đừng ép kiểu cứng làm app văng khi khoá vắng.
* Nếu cần nhãn kết quả, dùng `visit_result_label` / `visit_result_color` thay vì tự dịch `visit_result`.

---

## 3. Những gì KHÔNG đổi

* App **vẫn phải GỬI trung thực** `is_mock_location`, toạ độ check-in/check-out, `queued_seconds`… — server vẫn ghi,
  quản lý vẫn xem. Bỏ khoá ở phía ĐỌC không có nghĩa là thôi gửi.
* Luật chặn check-in (ngoài vùng; GPS giả theo cấu hình) giữ nguyên — lỗi 422 lúc bấm vẫn nói rõ lý do cho người dùng.
* `POST /dms/visits` vẫn trả `is_first_visit` như trước.
* Không endpoint mới, không tham số bắt buộc mới, không đổi quyền.

---

## 4. Kịch bản kiểm thử cho đội app (trên `app_test`)

1. Nhờ quản trị gán một biểu mẫu khảo sát `visit_scope = first`, `is_required = true`, giới hạn cho tài khoản thử.
2. Ở điểm bán **chưa từng được ghé** trong tuyến: danh sách khảo sát có biểu mẫu đó; check-in → gọi lại
   `/dms/forms/available` vẫn có; chưa nộp thì `requirements` báo thiếu, nộp xong thì check-out được.
3. Ở điểm bán **đã được ghé**: biểu mẫu đó **không** có trong danh sách; check-out không bị đòi.
4. Đổi biểu mẫu sang `repeat`: chiều ngược lại của bước 2–3.
5. Mở màn lịch sử lượt của tôi: không còn khoảng cách / cờ nào; app không văng với dòng lượt cũ.

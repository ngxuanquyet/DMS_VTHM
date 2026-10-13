# API QUÃNG ĐƯỜNG DI CHUYỂN — cho app di động DMS

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>` ·
viết 08/10/2026.

> 🔴 **App KHÔNG phải gửi thêm trường nào.** Hệ thống tự tính quãng đường từ các mốc app ĐÃ gửi sẵn. Bản app
> hiện tại chạy nguyên, không phải sửa gì để tính năng hoạt động.
>
> 🆕 **Quãng đường có NGAY sau khi check-out** (đổi 08/10/2026): bấm rời điểm bán A ⇒ km đi đến A tính liền.
> Màn hình "Quãng đường của tôi" vì thế cập nhật trong ngày, không phải chờ hôm sau.
>
> Nhưng có **hai thứ app đang gửi quyết định con số đúng hay sai** — đọc §2 trước khi làm gì khác.

Mọi đoạn JSON dưới đây là **phản hồi thật đã cắt gọn**, lấy bằng `curl` trên bản sao dữ liệu (`app_test`)
ngày 08/10/2026 — không phải ví dụ dựng tay.

> ⚠️ **Tính năng chưa bật trên prod** (tham số `dms.travel_enabled` và tác vụ định kỳ đều đang TẮT tính đến
> 08/10/2026). Ba endpoint dưới đây **đã sống và trả dữ liệu**, nhưng `road_m` sẽ là `null` ở mọi chặng cho
> tới khi quản trị bật công tắc. App làm được ngay; chỉ là số chưa có.

---

## 1. Hệ thống tính quãng đường thế nào

Mỗi **ngày công** của mỗi người được cắt thành các **chặng** (leg) nối hai mốc liên tiếp:

```
[chấm công vào] --start--> [điểm bán 1] --between--> [điểm bán 2] --between--> ... --> [điểm bán cuối]
```

* **n điểm bán ⇒ n chặng** (1 chặng `start` + n−1 chặng `between`).
* 🔴 **Chuỗi DỪNG ở điểm bán cuối.** KHÔNG có chặng từ điểm bán cuối về chỗ chấm công ra — đoạn đường về
  không phục vụ việc bán hàng nên không vào căn cứ chi công tác phí (chủ hệ thống chốt 08/10/2026).
* Quãng đường lấy theo **đường bộ thật** (dịch vụ bản đồ Goong, phương tiện mặc định `bike` — xe máy),
  không phải đường chim bay.
* 🔴 **Tính NGAY khi nhân viên check-out một điểm bán** — bấm rời điểm bán A thì quãng đường đi đến A có
  luôn, không phải chờ tới hôm sau. App **không** gọi gì thêm: chính lượt `POST /dms/visits/{id}/checkout`
  đang gửi là thứ kích hoạt việc tính, và nó chạy **sau khi response đã trả về** nên **không làm chậm thao
  tác** của nhân viên.
* Một tác vụ chạy **01:30 mỗi đêm** làm lưới an toàn (lượt do cron tự đóng, lượt đồng bộ ngoại tuyến đẩy lên
  muộn, chặng gọi hỏng cần thử lại). Nên con số có thể **đổi lại sau một đêm** — app đừng lưu đệm vĩnh viễn,
  hỏi lại server khi mở màn hình.

### Mốc lấy từ đâu

| Chặng | Mốc đầu | Mốc cuối |
|---|---|---|
| `start` | lượt **chấm công VÀO** của ngày công (`att_punch.lat/lng`) | **vị trí check-in** của lượt viếng thăm sớm nhất |
| `between` | **vị trí check-out** của lượt trước (thiếu thì lùi về vị trí check-in của chính lượt đó) | **vị trí check-in** của lượt sau |

Lượt viếng thăm **đã huỷ** (`cancelled_at`) không tham gia chuỗi.

---

## 2. 🔴 Hai thứ app gửi quyết định số km đúng hay sai

### 2.1 Toạ độ lúc RỜI điểm bán (`checkout_lat` / `checkout_lng`)

Đây là **mốc đầu của mọi chặng `between`**. App đã gửi hai trường này từ 29/09/2026 ở lượt check-out.

* **Gửi đủ** ⇒ chặng đo từ đúng chỗ nhân viên rời đi.
* **Thiếu** ⇒ hệ thống lùi về toạ độ lúc check-in của chính lượt đó. Chặng vẫn tính được, chỉ bỏ qua đoạn đi
  trong khuôn viên điểm bán — sai số nhỏ, **không** làm hỏng con số.

⇒ Đừng bỏ hai trường này để tiết kiệm. Chúng không bắt buộc về mặt kỹ thuật nhưng là thứ làm số km sát thực tế.

### 2.2 Toạ độ lúc CHẤM CÔNG (`lat` / `lng` của `POST /attendance/mobile/punch`)

Đây là **mốc đầu của chặng `start`** — đoạn từ chỗ chấm công tới điểm bán đầu tiên.

* Người **không chấm công** bằng app trong ngày ⇒ chặng `start` không có mốc ⇒ **0 km**, và nhân viên mất
  phần quãng đường đó (luật chi tiền: thiếu mốc tính bằng 0, không có cửa đề nghị điều chỉnh).

### 2.3 Thứ app KHÔNG cần làm nữa

🔴 **Đừng thêm ô cho nhân viên tự nhập số km.** Cột `dms_visit.km_declared` vẫn còn trong CSDL nhưng
**không còn đường nào đọc nó ra báo cáo** từ 08/10/2026 — số km nay do hệ thống tính. App One hiện cũng
không gửi trường này (đo prod: 28/28 lượt app One đều để trống), nên đây chỉ là lời nhắc đừng thêm vào.

---

## 3. Ba trạng thái của một con số km — CẤM gộp

Đây là phần dễ làm sai nhất khi vẽ màn hình. Mỗi chặng (và mỗi lượt viếng thăm) rơi vào đúng một trong ba:

| Giá trị | Nghĩa | Hiện thế nào | Có chốt được chưa |
|---|---|---|---|
| **số** (vd `8900`) | đã tính xong | `8.9 km` | ✅ |
| **`0`** | **thiếu mốc** — đã biết chắc không đo được | `0 km`, nên tô cảnh báo | ✅ đã chốt, chi được |
| **`null`** | **CHƯA tính** — chưa chạy tác vụ, hoặc gọi dịch vụ bản đồ hỏng | `—` | ❌ chưa chốt |

🔴 **Ép `null` thành `0` là biến "chưa biết" thành "không đi", và con số đó đi thẳng vào bảng chi công tác
phí.** Màn hình web đã phân biệt ba thứ này; app cũng phải vậy.

Đơn vị: **mọi trường `*_m` là MÉT**. Chia 1000 khi hiển thị km.

---

## 4. Endpoint

### 4.1 `GET /dms/travel/mine` — quãng đường của CHÍNH MÌNH theo ngày

Đây là endpoint app dùng. Ép lọc theo tài khoản đang đăng nhập; không có cách nào xem của người khác.

**Quyền:** `/dms/travel/mine` → vai `crm_customer_self` (đã gán sẵn trên prod).

**Tham số:** `from`, `to` (`Y-m-d`, tuỳ chọn) · `page`, `per-page` · `sort` (mặc định `-work_date`).

```
GET /dms/travel/mine?from=2026-09-01&to=2026-09-30
```

```jsonc
{
  "success": true,
  "message": "Thành công",
  "data": [
    {
      "id": 33,
      "user_id": 1193,
      "work_date": "2026-09-04",
      "road_m_total": "0.00",      // tổng ĐƯỜNG BỘ của ngày, tính bằng MÉT
      "road_km": 0,                 // đã chia 1000 và làm tròn 1 chữ số — dùng cái này để hiển thị
      "haversine_m_total": "0.00",  // đường chim bay, chỉ để đối chứng, KHÔNG dùng để chi tiền
      "leg_count": 6,               // tổng số chặng của ngày
      "leg_missing_count": 1,       // số chặng = 0 vì THIẾU MỐC (đã chốt)
      "leg_error_count": 5,         // số chặng CHƯA ra số (chưa tính / gọi hỏng)
      "is_complete": false,         // true khi leg_error_count = 0 ⇒ ngày đã chốt
      "calculated_at": "2026-10-08 09:14:23.920189+07"
    }
  ],
  "meta": { "total": 33, "currentPage": 1, "pageSize": 50, "pageCount": 1 }
}
```

🔴 **`is_complete = false` ⇒ ĐỪNG hiện `road_km` như một con số đã chốt.** Ngày đó còn chặng chưa tính, tổng
sẽ còn tăng. Hiện kèm một dòng kiểu *"còn 5 chặng chưa tính"* hoặc làm mờ con số.

⚠️ `leg_missing_count` và `leg_error_count` **khác nhau**: cái đầu là phần đã biết chắc bằng 0 (chốt được),
cái sau là phần chưa biết (chưa chốt). Gộp hai cái thành một con số là mất đúng thông tin người duyệt cần.

### 4.2 `GET /dms/travel/legs/{userId}/{workDate}` — chi tiết từng chặng của một ngày

Dùng khi nhân viên bấm vào một ngày để xem đi những đoạn nào.

🆕 **13/10/2026: mỗi chặng có thêm `from` và `to`** — nói rõ chặng đi **từ chấm công vào → điểm bán A** hay
**từ điểm bán A → điểm bán B**, kèm mã, tên và giờ. App không phải gọi thêm endpoint nào để lấy tên điểm bán.
Các trường cũ giữ nguyên.

**Quyền:** xem của **chính mình** cần `/dms/travel/mine` **hoặc** `/dms/travel/index`; xem của **người khác**
bắt buộc `/dms/travel/index`.

```
GET /dms/travel/legs/1193/2026-09-04
```

```jsonc
{
  "success": true,
  "data": [
    {
      "id": 683,
      "seq": 1,                                              // thứ tự chặng trong ngày, từ 1
      "leg_kind": "start",
      "leg_kind_label": "Chấm công vào → điểm bán đầu tiên",  // hiện thẳng, đừng tự dịch
      "status": "missing_anchor",
      "status_label": "Thiếu mốc để đo",
      "status_color": "danger",                              // mã Bootstrap: success/danger/warning/info/secondary
      "haversine_m": null,
      "road_m": "0.00",
      "from_visit_id": null,
      "to_visit_id": 42141,
      "from_punch_id": null,
      "to_punch_id": null,
      "provider": null,
      "error_note": null,
      "from": { "type": "missing", "label": "Không có chấm công vào" },
      "to": {
        "type": "visit", "visit_id": 42141, "customer_id": 8744,
        "code": "08290618", "name": "Tạp hoá Minh Anh",
        "at": "2026-09-04 07:42:00+07"                        // giờ ĐẾN điểm bán (check-in)
      }
    },
    {
      "id": 684,
      "seq": 2,
      "leg_kind": "between",
      "leg_kind_label": "Giữa hai điểm bán",
      "status": "pending",
      "status_label": "Chờ tính",
      "status_color": "secondary",
      "haversine_m": "13879.88",
      "road_m": null,                                        // CHƯA tính — hiện "—", KHÔNG hiện 0
      "from_visit_id": 42141,
      "to_visit_id": 42142,
      "from": {
        "type": "visit", "visit_id": 42141, "customer_id": 8744,
        "code": "08290618", "name": "Tạp hoá Minh Anh",
        "at": "2026-09-04 08:00:00+07"                        // giờ RỜI điểm bán (check-out)
      },
      "to": {
        "type": "visit", "visit_id": 42142, "customer_id": 8741,
        "code": "08430110", "name": "NPP Hùng Chi",
        "at": "2026-09-04 08:35:00+07"
      }
    }
  ],
  "meta": { "total": 6, "currentPage": 1, "pageSize": 100, "pageCount": 1 }
}
```

#### Hai đầu chặng: `from` / `to`

Mỗi đầu là một object, đọc `type` trước rồi mới đọc các trường còn lại:

| `type` | Đầu chặng là | Trường đi kèm |
|---|---|---|
| `punch` | lượt **chấm công vào** | `punch_id` · `code`, `name` = mã, tên **địa điểm chấm công** · `at` = giờ chấm |
| `visit` | một **điểm bán** | `visit_id` · `customer_id` · `code`, `name` = mã, tên điểm bán · `at` (xem dưới) |
| `missing` | không có mốc | chỉ có `label` — câu hiển thị sẵn (VI/EN theo ngôn ngữ đăng nhập), hiện thẳng |

Cách đọc nhanh:

* Chặng `start`: `from` là `punch` (hoặc `missing` khi hôm đó không chấm công vào — label *"Không có chấm công
  vào"*), `to` là điểm bán đầu tiên.
* Chặng `between`: `from` và `to` đều là `visit`. `to.visit_id` của chặng N **bằng** `from.visit_id` của chặng N+1
  — vẽ timeline thì nối theo `seq` là liền mạch.

⚠️ **Những trường có thể `null` — app phải có chữ thay thế:**

| Trường | `null` khi | Gợi ý hiển thị |
|---|---|---|
| `visit.at` ở **`from`** | nhân viên không bấm rời điểm bán (lượt bị hệ thống tự đóng, dữ liệu MobiWork cũ) | bỏ giờ, hoặc `—`. **Đừng** lấy giờ đến thay vào — sẽ thành giờ xuất phát sai |
| `visit.name` | lượt cũ chuyển từ MobiWork mà hồ sơ điểm bán không còn | hiện `code` |
| `visit.customer_id` | như trên | không mở được màn chi tiết điểm bán |
| `punch.code`, `punch.name` | chấm công bằng máy vân tay / khuôn mặt (không gắn địa điểm) | hiện *"Chấm công vào"* + `at` |

* `at` ở `from` = giờ **rời** điểm bán (check-out); `at` ở `to` = giờ **đến** (check-in). Định dạng giống mọi
  trường thời gian khác của API: `YYYY-MM-DD HH:MM:SS[.µs]+07`.
* Điểm bán / địa điểm bị xoá **sau** khi chặng đã tính vẫn hiện đúng tên — app không cần xử lý ca này riêng.
* 🔴 **Không có toạ độ** trong `from`/`to` (vị trí cá nhân là dữ liệu nhạy cảm theo Luật 91/2025). App cần vẽ
  bản đồ thì dùng toạ độ **điểm bán** qua API điểm bán, không đòi thêm ở đây.
* `type` có đúng **ba** giá trị trên. Gặp giá trị lạ (bản server sau thêm) thì hiện như `missing`, đừng crash.

**Năm giá trị của `status`:**

| `status` | `status_label` | Ý nghĩa cho app |
|---|---|---|
| `ok` | Đã tính | có `road_m`, hiện số |
| `skipped_short` | Quá ngắn, lấy đường chim bay | có `road_m` (dưới 50 m nên không gọi dịch vụ), hiện số |
| `missing_anchor` | Thiếu mốc để đo | `road_m = 0`, hiện `0 km` + cảnh báo |
| `pending` | Chờ tính | `road_m = null`, hiện `—` |
| `provider_error` | Lỗi gọi dịch vụ bản đồ | `road_m = null`, hiện `—`; `error_note` có câu lỗi (dành cho quản trị, đừng hiện cho nhân viên) |

🔴 **Dùng `status` để quyết định hiển thị, đừng đoán từ `road_m`.** `road_m = null` xuất hiện ở cả `pending`
lẫn `provider_error`, và hai thứ đó khác nhau về việc có nên nói "đang chờ" hay "đang lỗi".

⚠️ `leg_kind` chỉ còn **hai** giá trị: `start` và `between`. Giá trị `end` đã bị bỏ 08/10/2026 — nếu app cũ
có nhánh xử lý nó thì gỡ đi.

### 4.3 `GET /dms/travel` — quãng đường của MỌI người (quản lý)

Giống §4.1 về hình dạng dữ liệu, chỉ khác là không lọc theo người đăng nhập và có thêm tham số `user_id`.
**Quyền:** `/dms/travel/index` → vai `crm_customer_admin`. App nhân viên **không dùng endpoint này**.

### 4.4 Trường mới trong API đã có: `travel_m` ở chi tiết lượt viếng thăm

`GET /dms/visits/{id}` nay trả thêm **`travel_m`** — quãng đường đi ĐẾN điểm bán của lượt đó, tính bằng mét:

```jsonc
{
  "id": 42141,
  "visit_date": "2026-09-04",
  "checkin_at": "2026-09-04 07:42:00+07",
  "checkout_at": "2026-09-04 08:00:00+07",
  "travel_m": 0,            // 0 = thiếu mốc · null = chưa tính · số = đã tính
  "km_declared": null       // cột cũ, KHÔNG còn được dùng ở đâu
}
```

Đây là cách rẻ nhất để hiện km ngay trên màn chi tiết một lượt mà không phải gọi thêm endpoint nào.

---

## 5. Mã lỗi

| HTTP | Khi nào | App làm gì |
|---|---|---|
| `401` | token hết hạn / tài khoản chưa kích hoạt | đăng nhập lại |
| `403` | thiếu quyền `/dms/travel/mine` | **không phải lỗi app** — nhờ quản trị gán vai `crm_customer_self` |
| `404` | sai đường dẫn (thường do thiếu `userId` hoặc `workDate` ở §4.2) | kiểm lại URL |

Mọi phản hồi lỗi cùng một hình dạng: `{"success": false, "message": "<câu tiếng Việt>", "errors": null, "data": null}`
— hiện thẳng `message`, đừng dịch lại.

---

## 6. Những gì hệ thống KHÔNG làm (để khỏi hỏi lại)

* **Không ghi vị trí nền.** App không phải bật theo dõi GPS liên tục, không phải xin quyền background
  location. Toàn bộ số km tính từ các mốc nhân viên chủ động bấm.
* **Không tính đoạn về** từ điểm bán cuối tới chỗ chấm công ra.
* **Không có cửa đề nghị điều chỉnh km.** Thiếu mốc là 0 km, và đó là quyết định nghiệp vụ đã chốt — app
  đừng dựng màn khiếu nại cho việc này.
* **Không tính lại theo yêu cầu từ app.** Việc tính do tác vụ định kỳ của server làm.

---

## 7. Checklist tích hợp

- [ ] Màn "Quãng đường của tôi": gọi `GET /dms/travel/mine`, hiện `road_km` + `is_complete`.
- [ ] Phân biệt đủ **ba trạng thái** (số / `0` / `—`), không ép `null` về 0.
- [ ] Hiện `leg_missing_count` và `leg_error_count` **tách nhau**, không cộng lại.
- [ ] Màn chi tiết ngày: gọi `GET /dms/travel/legs/{userId}/{workDate}`, hiện theo `seq`, dùng
      `status_label` + `status_color` của server.
- [ ] Mỗi chặng hiện "**từ** `from` → **đến** `to`" theo `type` (`punch` / `visit` / `missing`), có chữ thay thế
      cho các trường `null` ở bảng §4.2.
- [ ] Gỡ mọi nhánh xử lý `leg_kind === 'end'` nếu có.
- [ ] Không thêm ô nhập km tự khai.
- [ ] Giữ nguyên việc gửi `checkout_lat/lng` ở check-out và `lat/lng` ở chấm công.

---

**Tài liệu liên quan:** `API-VIENG-THAM-MOBILE-2026-09-29.md` (check-in/check-out, nguồn mốc viếng thăm) ·
`API-CHAM-CONG-MOBILE-2026-10-05.md` (nguồn mốc chấm công) ·
`docs/specs/crm/QUANG-DUONG-DI-CHUYEN-2026-10-07.md` (đặc tả đầy đủ, dành cho người làm server).

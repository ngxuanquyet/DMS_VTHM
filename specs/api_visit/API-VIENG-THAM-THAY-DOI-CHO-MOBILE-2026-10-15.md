# Thay đổi API ngày 15/10/2026 — viếng thăm: ghé lại trong ngày, bỏ cron đóng hộ, cờ "Ra khác ngày"

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 15/10/2026** và app cần làm gì. Mọi JSON dưới đây là
phản hồi **thật**, gọi bằng `curl` trên bản sao dữ liệu (`app_test`) cùng ngày bằng tài khoản thử VTG926.

Hợp đồng đầy đủ của luồng viếng thăm vẫn là
[`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md) — file này chỉ là phần đổi.

> 🟡 **Không đổi hình dạng API** (không endpoint mới, không tham số mới bắt buộc, không khoá nào bị xoá),
> **nhưng ĐỔI HÀNH VI ở hai luật check-in.** App đang chạy không bị lỗi, nhưng nếu app **tự chặn** ở phía
> máy theo luật cũ thì người dùng sẽ bị chặn oan — rà §3 trước khi phát hành bản kế tiếp.

| # | Thay đổi | Loại | App phải làm |
|---|---|---|---|
| 1 | **Bỏ luật ② "một điểm bán, một ngày, một lượt"** — ghé lại cùng điểm bán trong ngày mở **lượt mới** | **ĐỔI HÀNH VI** | Gỡ chặn phía app (nếu có) |
| 2 | **Bỏ cron đóng hộ lượt treo** — lượt chưa check-out nằm mở tới khi chính nhân viên check-out hoặc huỷ | **ĐỔI HÀNH VI** | Luôn cho thấy lượt đang mở + nút Check-out / Huỷ |
| 3 | `GET /dms/mobile-rules`: `visit.auto_close_after_hours` **luôn `0`**, lỗi thời | **LỖI THỜI** | Ngừng đọc |
| 4 | `GET /dms/visits/mine` trả thêm `is_checkout_other_day` | **THÊM KHOÁ** | Không bắt buộc đọc |

---

## 1. Ghé lại cùng điểm bán trong ngày = một lượt MỚI

Trước 15/10/2026, check-in lần hai vào cùng điểm bán trong cùng ngày bị từ chối bằng
**422 *"Hôm nay bạn đã viếng thăm điểm bán này rồi."*** Từ nay server **không còn trả lỗi đó**: mỗi lần ghé là
một lượt riêng, có `id` riêng, ảnh và biểu mẫu riêng.

Các luật check-in còn lại **giữ nguyên**: ① điểm bán thuộc tuyến được giao · ③ không mở lượt mới khi còn lượt
treo · ④ đứng ngoài bán kính bị chặn · ⑤ giả lập vị trí gắn cờ (chặn hay không theo cấu hình). Số thứ tự giữ
nguyên để khỏi lệch với tài liệu cũ — chỉ ② bị bỏ.

### Bằng chứng gọi thật

Lượt đầu ở điểm bán `5378` (đã đóng), check-in lần hai **cùng điểm bán, cùng ngày**:

```
POST /dms/visits
{"customer_id":5378,"lat":"21.8208876","lng":"106.7715902","accuracy_m":"8","client_uuid":"<uuid mới>"}
```

**HTTP 201**:

```json
{"success":true,"message":"Đã tạo thành công.","data":{"id":135808,
  "checkin_at":"2026-10-15 11:27:50.088762+07","route_id":204,"is_on_route":true,
  "requirements":{"satisfied":false,"seconds_remaining":300,"photos_missing":2,
    "missing_forms":[{"form_id":9809,"name":"[TEST-CC] Khảo sát giá"}],
    "blockers":["Bạn cần ở lại thêm 5 phút nữa mới check-out được.",
      "Chưa nộp biểu mẫu khảo sát bắt buộc: [TEST-CC] Khảo sát giá","Bạn cần chụp thêm 2 ảnh nữa."]}}}
```

Lượt mới phải qua **đủ ba cổng check-out từ đầu** (thời gian · biểu mẫu · ảnh) — ảnh và phiếu của lượt trước
**không** được tính sang.

### 🔴 `client_uuid` giờ là hàng rào chống trùng DUY NHẤT

Luật ② cũ vô tình chặn luôn một ca: hàng đợi ngoại tuyến **gửi lại** một lần check-in đã xong. Bỏ luật ② thì
lần gửi lại đó sẽ tạo **lượt trùng** — trừ khi gói tin mang `client_uuid`. Server đã idempotent theo
`client_uuid` (gửi lại đúng uuid cũ ⇒ trả về chính lượt cũ, không tạo mới).

⇒ **Mọi lần check-in PHẢI gửi `client_uuid`**, sinh MỘT lần lúc người dùng bấm và giữ nguyên qua mọi lần
gửi lại. Server chưa bắt buộc trường này (để app cũ không vỡ), nhưng thiếu nó là đếm lượt sai.

---

## 2. Không còn cron đóng hộ lượt treo

Trước 15/10/2026, lượt quên check-out được cron **đóng hộ** sau 12 giờ (đánh dấu `auto_closed_at`). Cơ chế đó
**đã gỡ hẳn** — tác vụ, tham số và cột `auto_closed_at` đều đã xoá. Mọi lượt phải do **chính nhân viên** đóng:

| Muốn | Gọi |
|---|---|
| Kết thúc lượt bình thường | `POST /dms/visits/{id}/checkout` (qua đủ ba cổng) |
| Bỏ lượt bấm nhầm / không làm tiếp | `POST /dms/visits/{id}/cancel` — xem hợp đồng 29/09 §7.1 |

Hệ quả cho app: **một lượt bỏ quên sẽ khoá mọi lần check-in sau** (luật ③ — tính theo NGƯỜI, không theo điểm
bán) cho tới khi người dùng tự đóng hoặc huỷ. Không còn chuyện "để mai hệ thống tự đóng".

### Check-out sang ngày hôm sau: vẫn ĐƯỢC, nhưng bị gắn cờ

Server **không chặn** check-out muộn. Lượt check-in hôm nay mà mai mới bấm check-out vẫn đóng bình thường
(nếu qua đủ ba cổng), số liệu tính như thường, nhưng lượt đó mang cờ **"Ra khác ngày"** trên báo cáo nội bộ
để quản lý soi lại — xem §4.

---

## 3. App cần làm gì

**① Gỡ mọi chặn phía app theo luật ② cũ.** Nếu app làm mờ nút check-in / ẩn điểm bán khi `GET
/dms/visits/mine` đã có `customer_id` đó trong ngày — gỡ. Cờ "đã ghé" chỉ để **hiển thị**. Lưu ý: từ nay một
`customer_id` có thể xuất hiện **nhiều dòng** trong `visits/mine` của cùng một ngày; app đếm "đã ghé N điểm"
thì đếm `customer_id` **khác nhau**, đếm "N lượt" thì đếm dòng.

**② Luôn gửi `client_uuid` khi check-in** — xem §1.

**③ Lượt đang mở phải luôn nhìn thấy được.** Mở app mà còn lượt `checkout_at = null` thì đưa người dùng về
ngay lượt đó với hai nút **Check-out** và **Huỷ lượt**. Gặp 422 *"Bạn còn một lượt viếng thăm chưa
check-out…"* khi check-in thì đừng chỉ hiện câu lỗi — dẫn thẳng tới lượt đang mở.

**④ Ngừng đọc `visit.auto_close_after_hours`** trong `GET /dms/mobile-rules`. Khoá vẫn có mặt và **luôn
`0`** để bản app cũ không vỡ khi parse; sẽ bị xoá ở một đợt sau. Đừng hiện câu kiểu *"lượt sẽ tự đóng sau 12
giờ"* — điều đó không còn đúng.

```json
{"success":true,"message":"Luật thị trường cho app di động.","data":{
  "visit":{"require_geofence":true,"default_radius_m":100,"block_on_mock_location":false,
           "min_duration_minutes":5,"min_photos":2,"closed_min_photos":1,
           "route_scope":"assigned","auto_close_after_hours":0},
  "position":{"min_photos":1,"block_on_mock_location":false},
  "clock":{"skew_tolerance_minutes":15,"offline_max_queue_hours":24}}}
```

---

## 4. Khoá mới `is_checkout_other_day`

| Khoá | Kiểu | Ý nghĩa |
|---|---|---|
| `is_checkout_other_day` | `bool` | `true` = ngày bấm check-out (giờ VN) **khác** `visit_date`. Lượt còn mở luôn `false`. Không bao giờ `null` |

Có trong `GET /dms/visits/mine` (app đọc ở đây; `GET /dms/visits/{id}` cũng có nhưng vai nhân viên không gọi được endpoint đó). Cờ **tính lúc đọc**, nên lượt cũ cũng có giá trị
đúng ngay. Nó **chỉ là cờ**: số lượt, thời gian tại điểm bán, giờ làm đều giữ nguyên.

Bằng chứng — hai lượt cùng điểm bán `5378` cùng ngày, lượt sau check-out sáng hôm sau:

```
GET /dms/visits/mine?date_from=2026-10-15&date_to=2026-10-16
```

```json
{"success":true,"meta":{"total":2,"currentPage":1,"pageSize":20,"pageCount":1},"data":[
  {"id":135808,"customer_id":5378,"visit_date":"2026-10-15",
   "checkin_at":"2026-10-15 11:27:50.088762+07","checkout_at":"2026-10-16 08:05:00+07",
   "duration_seconds":74590,"is_checkout_other_day":true, "…": "…"},
  {"id":135807,"customer_id":5378,"visit_date":"2026-10-15",
   "checkin_at":"2026-10-15 11:27:49.867804+07","checkout_at":"2026-10-15 11:37:49.867804+07",
   "duration_seconds":600,"is_checkout_other_day":false, "…": "…"}
]}
```

*(Hai lượt thử này được đóng bằng tay trên DB `app_test` để không phải chờ đủ 5 phút + chụp ảnh, rồi đã huỷ.
Phần gọi API — hai lần check-in và lần đọc `visits/mine` — là gọi thật.)*

App **không bắt buộc** đọc khoá này. Nếu app có màn lịch sử lượt ghé của chính mình, có thể hiện một nhãn nhỏ
"Check-out khác ngày" để người dùng tự biết lượt đó sẽ bị soi lại.

---

## 5. Những gì KHÔNG đổi

* Đường dẫn, tham số, mã lỗi và phản hồi của `POST /dms/visits`, `…/checkout`, `…/cancel`, `…/requirements`.
* Ba cổng check-out (thời gian tối thiểu · biểu mẫu bắt buộc · số ảnh) — y nguyên.
* Luật ① ③ ④ ⑤ của check-in — y nguyên.
* Không có quyền RBAC mới, không phải cấp lại vai cho ai.

---

## 6. Câu hỏi đội mobile hay hỏi

**Lượt treo từ trước 15/10 thì sao?** Cron đã không còn; lượt nào đang mở sẽ nằm mở tới khi người dùng tự
check-out hoặc huỷ. Đo prod 15/10/2026: không có lượt nào do app One sinh ra đang treo.

**Ghé lại một điểm bán thì có phải nộp lại biểu mẫu không?** Có — biểu mẫu bắt buộc tính theo **lượt**, lượt
mới chưa có phiếu nào.

**Báo cáo nội bộ đếm thế nào?** Dòng tổng của báo cáo viếng thăm đếm *"N khách hàng · M lượt"* — N là số điểm
bán **khác nhau**, và cả hai số **chỉ đếm lượt đã check-out**. Lượt đang treo không vào tổng.

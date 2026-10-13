# API VỊ TRÍ NHÂN VIÊN (bản đồ theo dõi) — cho app di động

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>` ·
viết 09/10/2026.

Tính năng này trả lời đúng một câu hỏi của quản lý: **"nhân viên thị trường đang ở đâu?"** — không cần đợi
họ check-in điểm bán hay khai báo vị trí. Nó **không** thay thế và **không** cấp dữ liệu cho:

* lượt viếng thăm điểm bán ([`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md));
* khai báo vị trí ([`API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md`](API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md));
* quãng đường chi công tác phí ([`API-QUANG-DUONG-MOBILE-2026-10-08.md`](API-QUANG-DUONG-MOBILE-2026-10-08.md))
  — số km **vẫn chỉ** tính từ các mốc nghiệp vụ, tuyệt đối không tính từ điểm vị trí ở đây.

Mọi endpoint dưới đây đã được gọi thật bằng `curl` trên bản sao dữ liệu (`app_test`) ngày 09/10/2026 bằng
tài khoản thật; các đoạn JSON là **phản hồi thật đã cắt gọn**, không phải ví dụ dựng tay.

---

## 0. 🔴 Luật nền — đọc trước khi viết dòng code đầu tiên

**App chỉ gửi vị trí khi NGƯỜI DÙNG ĐANG MỞ APP.** Chủ hệ thống chốt 09/10/2026: **KHÔNG đánh thức app khi
nó đã đóng** — không silent push nền, không foreground service chạy ngầm cả ngày, không background location.
Đúng ba thời điểm app được gửi:

| Khi nào | `source` | Ghi chú |
|---|---|---|
| App đang mở, cứ mỗi `next_interval_sec` giây | `auto` | nhịp do server trả về, KHÔNG hardcode trong app |
| App chuyển nền / người dùng thoát | `app_exit` | gửi **một** điểm cuối, cố gắng gửi ngay trong vòng đời còn lại |
| Quản lý bấm "Xin vị trí ngay" và app đang mở | `requested` | xem §3 |

Hệ quả bắt buộc app phải tôn trọng:

1. **Không có nguồn thứ tư.** Server chỉ nhận ba giá trị trên; gửi giá trị khác bị từ chối 422.
2. **Nhịp đọc từ server, không đặt cứng.** Admin đổi `180 → 300` giây trên màn cấu hình thì máy nhân viên
   phải theo ngay ở lần gửi kế tiếp. Mỗi phản hồi của `POST /dms/locations/ping` đều trả `next_interval_sec`.
3. **Người dùng phải BIẾT.** Toạ độ là dữ liệu cá nhân nhạy cảm theo Luật BVDLCN 91/2025. App bắt buộc:
   * xin quyền vị trí tường minh, và hiện rõ khi nào đang gửi vị trí (biểu tượng/trạng thái trên màn hình);
   * khi nhận lệnh xin vị trí → **hiện thông báo nêu TÊN người yêu cầu** (§3), không được lấy im lặng;
   * có màn "Ai đã xem vị trí của tôi" đọc từ §5.
4. **Mất quyền vị trí ≠ lỗi hệ thống.** Người dùng từ chối quyền thì app đơn giản không gửi gì; đừng dựng
   vòng lặp thử lại, và đừng chặn các chức năng khác của app.

---

## 1. Quyền

| Chuỗi quyền | Mở cửa nào | Vai đang giữ (prod 09/10/2026) |
|---|---|---|
| `/dms/location/ping` | gửi điểm vị trí | `crm_customer_self` |
| `/dms/location/pending` | hỏi có ai đang xin vị trí mình không | `crm_customer_self` |
| `/dms/location/my-access-log` | đọc nhật ký "ai đã xem vị trí của tôi" | `crm_customer_self` |

Ba chuỗi còn lại (`map`, `track`, `request`) là **của màn quản lý trên web**, app không dùng.

Thiếu quyền ⇒ **403** (đo thật: tài khoản chỉ có vai `employee` nhận 403 ở cả ba cửa trên).

---

## 2. Gửi vị trí — `POST /dms/locations/ping`

**Luôn gửi dạng MẢNG `points`, kể cả khi chỉ có một điểm.** Một hình dạng body cho cả hai ca (gửi ngay và
gửi bù sau khi mất sóng) thì app không phải chọn đường.

```json
{
  "points": [
    {
      "lat": 21.0285,
      "lng": 105.8542,
      "accuracy_m": 12.5,
      "is_mock_location": false,
      "battery_pct": 76,
      "source": "auto",
      "client_time": "2026-10-09T10:00:00+07:00",
      "client_uuid": "11111111-1111-4111-8111-111111111111",
      "app_version": "1.4.0"
    }
  ]
}
```

| Ô | Bắt buộc | Ghi chú |
|---|---|---|
| `lat`, `lng` | ✔ | số thập phân; ngoài khoảng ±90 / ±180 ⇒ 422 |
| `source` | — | mặc định `auto`; chỉ nhận `auto` · `app_exit` · `requested` |
| `client_uuid` | — (nhưng **nên luôn có**) | UUID do app sinh cho mỗi điểm; gửi lại cùng UUID thì server BỎ QUA, không nhân đôi |
| `accuracy_m` | — | sai số máy báo (mét) |
| `battery_pct` | — | 0–100; giúp quản lý hiểu vì sao máy sắp im lặng |
| `is_mock_location` | — | máy báo đang giả lập vị trí. **Server KHÔNG chặn**, chỉ gắn cờ — app cứ gửi trung thực |
| `client_time` | — | giờ máy; chỉ để soi máy lệch giờ. Mốc hiển thị luôn là giờ server |
| `request_id` | — (**nên có** khi `source=requested`) | id lệnh app đang trả lời; xem §3 |
| `app_version` | — | ≤ 32 ký tự |

Phản hồi thật:

```json
{
  "success": true,
  "message": "Đã nhận vị trí.",
  "data": {
    "saved": 2,
    "duplicated": 0,
    "answered_request_id": null,
    "next_interval_sec": 180,
    "pending_request": null
  }
}
```

* `duplicated` — số điểm bị bỏ vì trùng `client_uuid`. **Đây không phải lỗi**: app cứ coi như đã gửi xong và
  dọn khỏi hàng đợi.
* `answered_request_id` — khác `null` nghĩa là điểm vừa gửi đã trả lời xong một lệnh xin vị trí.
* `pending_request` — lệnh còn đang chờ (xem §3); có giá trị thì app gửi tiếp một điểm `source=requested`.

**Trần kỹ thuật: tối đa 200 điểm một lượt gọi.** Hàng đợi dài hơn thì chia nhiều lượt.

🔴 **Một điểm sai làm hỏng cả lượt gửi** (422, không ghi điểm nào). Có chủ đích: bỏ qua điểm sai và nhận phần
còn lại sẽ làm app tưởng đã gửi xong trong khi hàng đợi vẫn giữ điểm chưa ai nhận.

Lỗi hay gặp:

| HTTP | `code` | Nghĩa | App làm gì |
|---|---|---|---|
| 422 | `LOCATION_RULE` | `Tính năng theo dõi vị trí đang tắt.` | **Ngừng gửi**, thử lại ở lần mở app sau. Không retry liên tục |
| 422 | `VALIDATION_ERROR` | toạ độ · nguồn · pin · `client_uuid` không đúng dạng UUID · `client_time` không đọc được | Lỗi lập trình — sửa app, đừng retry |
| 403 | — | thiếu quyền | Tắt hẳn tính năng vị trí trên máy đó |

---

## 3. Lệnh "Xin vị trí ngay"

Quản lý bấm nút trên web → server tạo một **lệnh có hạn** (mặc định 10 phút, admin cấu hình được). App biết
được lệnh qua **hai đường, dùng cả hai**:

1. **Realtime (nhanh, không đảm bảo)** — kênh cá nhân Centrifugo của chính người dùng, sự kiện
   `dms.location.request`, payload `{request_id, expires_at, requested_by, reason}`.
2. **Hỏi định kỳ (đảm bảo)** — `GET /dms/locations/pending`, và mỗi phản hồi `ping` cũng kèm
   `pending_request`. Đường này là thứ làm lệnh **không bị mất** khi máy chưa nối được WebSocket.

```
GET /dms/locations/pending
```

```json
{
  "success": true,
  "data": {
    "enabled": true,
    "next_interval_sec": 180,
    "pending_request": {
      "id": 1,
      "requested_by": "Nguyễn Văn A",
      "requested_at": "2026-10-09 16:39:11+07",
      "expires_at": "2026-10-09 16:49:11+07",
      "status": "delivered",
      "status_label": "App đã nhận, chưa có vị trí",
      "is_open": true,
      "reason": "Kiểm tra tuyến sáng nay"
    }
  }
}
```

App nhận lệnh thì làm đúng ba việc, theo thứ tự:

1. **Hiện thông báo cho nhân viên**: *"{requested_by} đã yêu cầu vị trí của bạn"* + `reason` nếu có.
2. Lấy GPS một lần.
3. `POST /dms/locations/ping` với `source: "requested"` **và `request_id` của lệnh đó**.

🔴 **Gửi kèm `request_id`.** Không có nó, server phải đoán bằng `client_time`, và một điểm cũ còn kẹt trong
hàng đợi ngoại tuyến có thể đóng nhầm một lệnh vừa mới sinh ra — quản lý đọc được "đã trả lời" kèm toạ độ
của hai tiếng trước. Server vẫn chấp nhận điểm không có `request_id` (app bản cũ), nhưng khi đó nó **từ chối
đóng lệnh** nếu `client_time` sớm hơn lúc lệnh được tạo.

🔴 **Quá `expires_at` thì ĐỪNG gửi nữa.** Server vẫn ghi nhận điểm (nó là vị trí thật) nhưng không đóng lệnh,
và `answered_request_id` sẽ là `null`. Hạn này là hàng rào bảo vệ nhân viên: không có nó thì một lệnh bấm lúc
9h sáng vẫn âm thầm lấy toạ độ khi người đó mở app lúc 8h tối.

`enabled: false` nghĩa là admin đã tắt tính năng — app ngừng mọi việc gửi vị trí cho tới lần kiểm sau.

---

## 4. Hàng đợi ngoại tuyến

Mất sóng thì app **giữ điểm trong máy** rồi gửi bù cả mẻ. Ba luật:

1. Mỗi điểm mang `client_uuid` sinh **lúc đo**, không phải lúc gửi — đó là thứ chống nhân đôi.
2. `client_time` ghi **lúc đo**. Server vẫn dùng giờ nhận để hiển thị, nên đừng cố "sửa" mốc.
3. Hàng đợi vị trí **được phép mất**: điểm cũ hơn vài giờ không còn giá trị với bản đồ. Đừng dựng cơ chế
   bền bỉ như hàng đợi viếng thăm (bên đó mất bản ghi là mất bằng chứng công việc; bên này không).

---

## 5. "Ai đã xem vị trí của tôi" — `GET /dms/locations/my-access-log`

Màn bắt buộc có trong app (nghĩa vụ thông báo của Luật 91/2025). Phân trang chuẩn như mọi lưới khác
(`?page=`, `?per-page=`).

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "requested_by_name": "Nguyễn Văn A",
      "requested_at": "2026-10-09 16:39:11+07",
      "status": "answered",
      "status_label": "Đã có vị trí",
      "reason": "Kiểm tra tuyến sáng nay",
      "answered_ping_id": 3
    }
  ],
  "meta": { "total": 1, "currentPage": 1, "pageSize": 20, "pageCount": 1 }
}
```

`status` có bốn giá trị: `pending` (app chưa nhận) · `delivered` (app nhận rồi, chưa gửi vị trí) ·
`answered` (đã gửi) · `expired` (hết hạn mà không gửi). Hiện thẳng `status_label`.

⚠️ `answered_ping_id` có thể là `null` ở bản ghi cũ — điểm toạ độ đã bị dọn sau hạn lưu 90 ngày, còn dòng nhật
ký thì giữ vĩnh viễn. Đó là đúng thiết kế, đừng hiểu là dữ liệu hỏng.

---

## 6. Tham số server điều khiển (app không hardcode cái nào)

| Tham số | Mặc định | App đọc ở đâu |
|---|---|---|
| `dms.location_enabled` | TẮT | `enabled` của §3 |
| `dms.location_ping_interval_seconds` | 180 | `next_interval_sec` của §2, §3 |
| `dms.location_request_ttl_minutes` | 10 | `expires_at` của từng lệnh |
| `dms.location_fresh_minutes` | 15 | chỉ dùng cho màn web, app không cần |
| `dms.location_retention_days` | 90 | — (cron server) |

---

## 7. Việc app phải làm — danh sách rút gọn

- [ ] Xin quyền vị trí; không có quyền thì tắt tính năng, không chặn chức năng khác.
- [ ] Khi app ở foreground: hẹn giờ gửi theo `next_interval_sec`, cập nhật lại sau MỖI phản hồi.
- [ ] Khi app vào nền/thoát: gửi một điểm `source=app_exit`.
- [ ] Mỗi nhịp (hoặc khi nhận realtime `dms.location.request`): kiểm lệnh chờ → **báo cho người dùng** → gửi
      điểm `source=requested` nếu còn trong hạn.
- [ ] Sinh `client_uuid` (**đúng dạng UUID**) cho mọi điểm, giữ hàng đợi khi mất sóng, dọn hàng đợi khi
      `saved`/`duplicated` về.
- [ ] Điểm trả lời lệnh phải mang `request_id` và `client_time` của lúc ĐO.
- [ ] Màn "Ai đã xem vị trí của tôi".
- [ ] Hiện rõ trạng thái "đang chia sẻ vị trí" trên giao diện khi app đang gửi.

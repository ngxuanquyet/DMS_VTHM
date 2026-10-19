# Nhắc chấm công vào ca / ra ca — tài liệu cho app mobile (17/10/2026)

> Đối tượng: đội app DMS (Flutter). Server: `https://api-app.vthmgroup.vn`. Đọc kèm
> [API-CHAM-CONG-MOBILE-2026-10-05.md](API-CHAM-CONG-MOBILE-2026-10-05.md) (chấm công bằng app).

## 1. Tóm tắt — app phải làm gì

**Server tự biết ca của từng người và tự gửi push nhắc.** App **không** phải đọc ca, không phải đặt hẹn giờ trong máy.
Việc của app chỉ có ba thứ:

1. Đăng ký máy nhận push bằng `POST /notification/device-token` **kèm `"app": "dms"`** (§3.4) và tạo kênh thông báo
   `vthm_alerts` (§3.5) — đây là hai thứ để push hiện được cả khi app đã TẮT.
2. Nhận ra push nhắc ca qua `data.type` (§3) ⇒ bấm vào thì mở **màn chấm công**, kể cả khi app đang tắt (§3.3).
3. Sau khi chấm công xong không cần báo gì: lượt chấm đã vào server thì lần nhắc sau tự bỏ qua người đó (§4).

---

## 2. Ca của một người lấy từ đâu (để hiểu vì sao có / không có nhắc)

Mỗi ngày, server chọn ca theo thứ tự, gặp cái nào trước thì dùng cái đó:

| Bậc | Nguồn | Ai khai | Ở đâu trên One |
|---|---|---|---|
| 1 | **Ca xếp tay** cho đúng ngày đó (đổi ca, tăng ca) | Nhân sự | Chấm công › Xếp ca tháng |
| 2 | **Lịch tuần riêng** gán cho người đó | Nhân sự | Chấm công › Xếp ca tháng |
| 3 | **Lịch tuần của PHÒNG BAN** người đó đang thuộc | Nhân sự | Cài đặt › Chấm công › Lịch theo phòng ban |
| — | Không có cả ba | — | Ngày đó **không có ca ⇒ không nhắc** |

Ví dụ: phòng Kinh doanh gán lịch "Văn phòng T2–T6" (08:00–17:00), phòng Sản xuất gán "Ca sáng T2–T7" (06:00–14:00).
Mỗi người tự nhận nhắc theo giờ của phòng mình; ai có lịch riêng hoặc ca xếp tay thì theo cái đó.

**Không có nhắc** trong các ca sau — đây là thiết kế, không phải lỗi:

* Lịch tuần chọn **nhiều ca** cho một thứ (xoay ca) — server chỉ biết người làm ca nào sau lần quẹt đầu tiên.
* Ngày nghỉ tuần (thứ đó trong lịch để trống).
* Chưa trừ ngày phép / ngày lễ — người nghỉ phép vẫn có thể nhận nhắc (nợ đã biết).

---

## 3. Push nhắc ca

### 3.1 Khi nào gửi

| Loại | `data.type` | Thời điểm (mặc định) | Tiêu đề / nội dung (ví dụ) |
|---|---|---|---|
| Nhắc **vào** ca | `att.shift_remind_in` | **15 phút** trước giờ bắt đầu ca | `Sắp vào ca: Ca sáng bắt đầu lúc 06:00` · `Ca Ca sáng (06:00–14:00) của bạn sắp bắt đầu. Mở app để chấm công vào ca.` |
| Nhắc **ra** ca | `att.shift_remind_out` | **Đúng** giờ kết thúc ca | `Nhớ chấm công ra: Ca sáng đã kết thúc lúc 14:00` · `Ca Ca sáng (06:00–14:00) của bạn đã kết thúc. Mở app để chấm công ra ca.` |

* Số phút, bật/tắt nhắc ra ca: quản trị chỉnh ở `/system/settings/attendance`. App **không** được hardcode các mốc này.
* Cron chạy 5 phút một lần ⇒ push có thể tới trễ tối đa ~5 phút so với mốc; quá 15 phút sau mốc thì bỏ, không gửi bù.
* Ca bắt đầu 00:00 được nhắc lúc 23:45 tối hôm trước. Ca qua đêm (22:00–06:00) được nhắc ra lúc 06:00 sáng hôm sau.
* Mỗi (người, ngày, loại nhắc, ca) gửi **tối đa một lần**. Người kiêm nhiệm hai ca khác nhau trong ngày nhận đủ cả hai.
* Kênh: chuông trong One + push. **Không** gửi email.

### 3.2 Gói FCM

```json
{
  "notification": { "title": "Sắp vào ca: Ca sáng bắt đầu lúc 06:00", "body": "Ca Ca sáng (06:00–14:00) của bạn sắp bắt đầu. Mở app để chấm công vào ca." },
  "data": { "type": "att.shift_remind_in" },
  "android": { "priority": "high", "notification": { "sound": "default", "channel_id": "vthm_alerts" } }
}
```

* **Không có `data.link`** — tin này không trỏ tới trang web nào. App dựa vào `data.type` để mở màn chấm công.
* Người đăng nhập nhiều tài khoản trên cùng máy: tiêu đề có thể kèm tên công ty của tài khoản nhận (như mọi push khác).
* App đang mở (foreground) thì nên hiện banner trong app và cho bấm thẳng vào nút chấm công.

### 3.3 Xử lý gợi ý trong app

Gói có khối `notification` ⇒ **Android tự hiện thông báo khi app ở nền hoặc đã tắt**, app không cần chạy. App chỉ phải
xử lý lúc người dùng BẤM vào, ở cả ba trạng thái:

```dart
void openFromPush(RemoteMessage m) {
  switch (m.data['type']) {
    case 'att.shift_remind_in':
    case 'att.shift_remind_out':
      // Mở màn chấm công (cùng màn gọi POST /attendance/mobile/punch).
      navigator.pushNamed('/attendance/punch');
  }
}

// App đã TẮT, mở lên vì bấm thông báo:
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) openFromPush(initial);
// App ở NỀN, bấm thông báo:
FirebaseMessaging.onMessageOpenedApp.listen(openFromPush);
// App đang MỞ: Android KHÔNG tự hiện — tự hiện banner trong app (hoặc flutter_local_notifications).
FirebaseMessaging.onMessage.listen(showInAppBanner);
```

### 3.4 Đăng ký máy (BẮT BUỘC kèm `app`)

```
POST /notification/device-token
{"token": "<FCM token>", "platform": "android", "app": "dms", "device_name": "Samsung SM-A155F"}
→ {"success": true, "data": {"ok": true}}
```

* Gọi sau mỗi lần đăng nhập và mỗi khi `FirebaseMessaging.instance.onTokenRefresh` báo token mới.
* **`"app": "dms"` là bắt buộc với app DMS.** Thiếu thì server coi là app One. Hệ quả: người cài cả app One lẫn app
  DMS trên cùng máy sẽ nhận tin nhắc ca HAI lần. Có `app: "dms"` thì tin nhắc ca chỉ tới app DMS, còn người chưa cài
  app DMS vẫn nhận ở app One / trình duyệt (server ưu tiên app DMS, không bỏ tin).
* Đăng xuất: `DELETE /notification/device-token` `{"token": "<FCM token>"}` — không gỡ thì máy vẫn nhận tin của người cũ.
* Xin quyền `POST_NOTIFICATIONS` (Android 13+) TRƯỚC khi lấy token; người dùng từ chối thì không có thông báo nào hiện.
* App DMS phải nằm trong **cùng Firebase project** với server (hỏi quản trị `project_id` + file `google-services.json`).
  Khác project thì FCM từ chối token, không push nào tới được.

### 3.5 Kênh thông báo Android `vthm_alerts`

Mọi push Android của server gắn `channel_id: "vthm_alerts"`. App tạo kênh này **một lần lúc khởi động**, mức quan
trọng CAO để tin hiện banner + kêu:

```dart
const channel = AndroidNotificationChannel(
  'vthm_alerts',            // KHÔNG đổi — server gửi đúng id này
  'Thông báo VTHM',
  importance: Importance.high,
);
await FlutterLocalNotificationsPlugin()
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```

Chưa tạo kênh thì Android vẫn hiện tin nhưng ở kênh mặc định "Khác" — nhiều máy để mức thấp (không kêu, không banner).

---

## 4. Khi nào KHÔNG bị nhắc dù có ca

Server kiểm lượt chấm ngay trước khi gửi — từ **mọi nguồn** (app, máy chấm công vân tay, chấm tay của nhân sự):

* **Nhắc vào:** bỏ qua nếu đã có lượt chấm trong cửa sổ vào của ca đó (ca 8/12 tiếng: từ 60′ trước giờ vào; ca hành
  chính: từ 120′ trước) tới giờ kết thúc ca. Lượt ra ca đêm hôm trước KHÔNG tính.
* **Nhắc ra:** bỏ qua nếu đã có lượt chấm từ **giữa ca** trở đi (về sớm 13:55 cho ca kết thúc 14:00 là đã chấm ra).
* Lượt chấm đã bị nhân sự huỷ (`voided`) không tính.
* Lượt chấm của mã NV khác cùng tài khoản (người kiêm nhiệm) vẫn tính.

⚠️ App chấm công **ngoại tuyến** mà gói tin chưa lên server trước mốc nhắc ⇒ người dùng vẫn nhận nhắc. Nên đẩy hàng
đợi chấm công ngay khi có mạng.

---

## 5. Người dùng tự tắt

Tin nhắc nằm ở nhóm **"Chấm công" › "Nhắc chấm công vào ca / ra ca của tôi"** trong cài đặt thông báo của One. App
nào có màn cài đặt thông báo riêng thì dùng đúng nhóm này, đừng tự thêm công tắc trong máy.

---

## 6. Trạng thái triển khai (17/10/2026)

* **Máy bị "Buộc dừng"** trong Cài đặt không nhận push tới khi mở lại app (luật Android). Máy Xiaomi/Oppo/Vivo/Realme/
  Tecno/Honor: hướng dẫn người dùng bật **Tự khởi chạy** và tắt tối ưu pin cho app DMS, nếu không ROM có thể chặn.
* Đo prod 17/10/2026: **chưa có máy nào của app DMS đăng ký push** (20 máy Android đều là app One).

* Backend + cron `attendance/shift-remind` đã LIVE trên prod, nhưng công tắc **"Nhắc chấm công" đang TẮT** — chưa ai
  nhận push cho tới khi quản trị bật ở `/system/settings/attendance`.
* Xem ca của mình: §8 (`config.today.shift` + `GET /attendance/mobile/shifts`). Đừng gọi các API quản trị
  `/attendance/shifts`, `/attendance/schedule-depts` (cần quyền nhân sự, nhân viên thường nhận 403).

## 7. Danh sách việc cho app

- [ ] **Đăng ký token kèm `"app": "dms"`**, gọi lại khi token đổi; gỡ token khi đăng xuất (§3.4).
- [ ] Xin quyền `POST_NOTIFICATIONS`; tạo kênh `vthm_alerts` mức cao lúc khởi động (§3.4, §3.5).
- [ ] Bấm thông báo khi app TẮT (`getInitialMessage`) và ở NỀN (`onMessageOpenedApp`) đều mở màn chấm công (§3.3).
- [ ] Bắt `data.type` = `att.shift_remind_in` / `att.shift_remind_out` ⇒ bấm push mở màn chấm công (§3.3).
- [ ] App đang mở: hiện banner trong app có nút chấm công (§3.2).
- [ ] Đẩy hàng đợi chấm công ngoại tuyến ngay khi có mạng để khỏi bị nhắc oan (§4).
- [ ] Không hardcode giờ nhắc, không tự đặt hẹn giờ trong máy (§1, §3.1).

---

## 8. Xem ca của tôi (17/10/2026)

> **Chốt 17/10/2026: app DMS TỰ đặt thông báo nhắc trong máy** từ dữ liệu ca dưới đây (local notification). Khi đó
> công tắc nhắc của SERVER (`/system/settings/attendance` › Nhắc chấm công, §3) phải để **TẮT** — bật cả hai là người
> dùng nhận hai lần. App nên tải lại `GET /attendance/mobile/shifts` mỗi lần mở app / đăng nhập và đặt lại toàn bộ
> lịch nhắc (nhân sự có thể đổi ca bất kỳ lúc nào); huỷ nhắc vào ca khi người dùng đã chấm (`today.punch_count > 0`).

Server tính ca theo đúng luật engine tính công (§2). Quyền `/attendance/mobile/shifts` đã cấp cho vai `employee`.

### 8.1 Ca hôm nay — đã có sẵn trong `GET /attendance/mobile/config`

```json
"today": {
  "work_date": "2026-10-19", "punch_count": 0, "next_action": "in", "next_action_label": "Vào", "...": "...",
  "shift": {
    "work_date": "2026-10-19", "status": "shift", "source": "schedule",
    "shift": {"id": 12, "code": "HC", "name": "Hành chính 08:00–17:30", "start_time": "08:00", "end_time": "17:30", "cross_midnight": false},
    "candidates": []
  }
}
```

### 8.2 Lịch ca nhiều ngày

```
GET /attendance/mobile/shifts?from=2026-10-19&days=7
→ {"success": true, "data": [ <một phần tử như today.shift>, … ]}   // đúng `days` phần tử, ngày tăng dần
```

| Tham số | Mặc định | Ghi chú |
|---|---|---|
| `from` | hôm nay | `Y-m-d`. Sai định dạng / ngày không tồn tại ⇒ hôm nay (không báo lỗi). |
| `days` | 7 | Ép về 1..31. Không phải số ⇒ **400**. |

### 8.3 Ý nghĩa `status`

| `status` | `shift` | `candidates` | App hiện |
|---|---|---|---|
| `shift` | ca đã rõ | `[]`, hoặc các ca của ngày xoay ca (khi `source = auto`) | "Ca Hành chính 08:00–17:30" |
| `multiple` | `null` | các ca có thể (xếp theo giờ vào) | "Xoay ca: Ca 1 06:00 / Ca 2 14:00 / …" — ca thật biết sau lần quẹt đầu |
| `day_off` | `null` | `[]` | "Nghỉ" |
| `no_schedule` | `null` | `[]` | "Chưa được xếp lịch — liên hệ nhân sự" |

`source` (khi `status = shift`): `override` = ca nhân sự xếp tay cho đúng ngày · `schedule` = theo lịch tuần (riêng
hoặc của phòng ban) · `auto` = ngày xoay ca, server đã chọn ca theo lần quẹt đầu.

* `cross_midnight = true` ⇒ ca kết thúc sang NGÀY HÔM SAU (ví dụ 22:00–06:00).
* Ngày lễ CHƯA trừ ở API này — ngày lễ vẫn hiện ca theo lịch tuần.
* Tài khoản không gắn mã nhân viên ⇒ mọi ngày là `no_schedule`.

- [ ] Hiện `today.shift` trên màn chấm công; màn lịch ca gọi `GET /attendance/mobile/shifts` (§8).

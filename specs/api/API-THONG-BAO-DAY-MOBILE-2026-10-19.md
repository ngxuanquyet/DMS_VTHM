# Thông báo đẩy (push) — hướng dẫn xử lý cho app DMS (19/10/2026)

> Đối tượng: đội app DMS (Flutter, Android). Server: `https://api-app.vthmgroup.vn`, xác thực
> `Authorization: Bearer <access_token>` (trừ cửa nhả máy §3.3). Tài liệu này là **nguồn chung về push** cho app; các
> tài liệu theo tính năng chỉ mô tả loại tin của mình:
> [nhắc ca](API-NHAC-CA-MOBILE-2026-10-17.md) · [duyệt điểm bán §6](API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15.md).
> Việc của đội app trong sổ: **#23647**.

## 0. Hiện trạng (đo prod 19/10/2026)

* ✅ **Firebase đúng:** `google-services.json` đang nằm trong app thuộc dự án `vthmgroup-app` (`161319260292`) và có mục
  `client` cho **`vn.vthmgroup.dms`** — khớp server, không phải đổi gì.
* ❌ **App chưa đăng ký máy:** log API từ 28/06 tới 19/10/2026 có ~24.000 lượt gọi từ app DMS (`Dart/3.13`) nhưng **0
  lượt** `POST /notification/device-token`; bảng máy nhận push chưa có dòng `app = dms` nào (chỉ app One: 18 máy Android,
  146 trình duyệt) ⇒ **app DMS hiện chưa nhận push nào.** Làm §1, §3, §4 là đủ để bắt đầu nhận.
* ❌ **App gọi sai đường danh sách thông báo:** `GET /notifications` ⇒ **404** (29 lượt). Đường đúng ở §9.
* Server gửi qua FCM HTTP v1, dự án Firebase **`vthmgroup-app`** (project number `161319260292`).

---

## 1. Việc app phải làm — danh sách kiểm

1. [ ] `google-services.json` thuộc dự án **`vthmgroup-app`**, mục `client` đúng `applicationId` của app DMS (§2).
2. [ ] Xin quyền `POST_NOTIFICATIONS` (Android 13+) **trước** khi lấy token.
3. [ ] Tạo kênh Android **`vthm_alerts`**, mức `Importance.high`, lúc khởi động (§4).
4. [ ] Đăng ký máy `POST /notification/device-token` kèm **`"platform": "android"`, `"app": "dms"`** — sau mỗi lần đăng
       nhập và mỗi lần `onTokenRefresh` (§3.1).
5. [ ] Đăng xuất / mất phiên ⇒ **nhả máy** (§3.2, §3.3).
6. [ ] Bấm vào thông báo ⇒ điều hướng theo `data.type` (§6), ở cả ba trạng thái app (§5).
7. [ ] App đang mở ⇒ tự hiện banner, **bỏ qua tin không dành cho tài khoản đang đăng nhập** (`data.uids`, §5.3).

---

## 2. Firebase: phải CÙNG dự án với server

Server ký JWT bằng service account của dự án `vthmgroup-app` rồi gọi
`https://fcm.googleapis.com/v1/projects/vthmgroup-app/messages:send`. Token do app lấy ở **dự án khác** bị FCM từ chối ở
MỌI lần gửi (`SENDER_ID_MISMATCH`) ⇒ không push nào tới được, mà phía app không thấy lỗi gì (đăng ký token vẫn trả
`ok`). Dấu hiệu duy nhất: đăng ký thành công nhưng không bao giờ nhận được tin.

Kiểm trong `android/app/google-services.json`:

```json
{ "project_info": { "project_number": "161319260292", "project_id": "vthmgroup-app", … },
  "client": [ { "client_info": { "android_client_info": { "package_name": "<applicationId của app DMS>" } }, … } ] }
```

Chưa có mục `client` cho app DMS ⇒ nhờ quản trị thêm app Android vào dự án `vthmgroup-app` trong Firebase Console, tải
lại `google-services.json`, build lại app.

---

## 3. Đăng ký và nhả máy

### 3.1 Đăng ký — `POST /notification/device-token`

```
POST /notification/device-token
Authorization: Bearer <access_token>
{"token": "<FCM token>", "platform": "android", "app": "dms", "device_name": "Samsung SM-A155F"}
→ {"success": true, "data": {"ok": true}}
```

| Khoá | Bắt buộc | Ghi chú |
|---|---|---|
| `token` | có | `FirebaseMessaging.instance.getToken()` |
| `platform` | **có** | `android` — **thiếu thì server coi là `web`** và gửi gói kiểu web (không có khối `notification`) ⇒ Android không tự hiện tin khi app tắt |
| `app` | **có** | `dms` — thiếu thì server coi là app One ⇒ người cài cả hai app nhận tin **hai lần** (§7) |
| `device_name` | không | tên máy để người dùng nhận ra trong danh sách thiết bị (≤ 200 ký tự) |

* Gọi **sau mỗi lần đăng nhập** và **mỗi khi `onTokenRefresh`** báo token mới. Gọi lặp với cùng token là an toàn
  (cập nhật chủ máy + `last_seen_at`).
* Một máy đổi tài khoản: đăng ký lại bằng tài khoản mới ⇒ token chuyển sang chủ mới.

### 3.2 Đăng xuất chủ động — `DELETE /notification/device-token`

```
DELETE /notification/device-token
Authorization: Bearer <access_token>
{"token": "<FCM token>"}
```

Gọi **trước** khi xoá access token khỏi máy. Không gỡ thì máy vẫn nhận tin của người cũ.

### 3.3 Mất phiên (không còn Bearer) — `POST /notification/device-token/release`

```
POST /notification/device-token/release
{"token": "<FCM token>"}
→ luôn trả cùng một câu, dù token có trong bảng hay không
```

* Cửa **công khai** (không Bearer) — token FCM chính là bằng chứng; chỉ tắt đúng dòng đó.
* Dùng khi refresh token bị từ chối, phiên hết hạn, hoặc người dùng đăng xuất lúc mất mạng: lưu token vào hàng chờ, gọi
  cửa này khi có mạng lại. Đăng nhập lại ⇒ §3.1 bật máy lên lại.

---

## 4. Kênh Android `vthm_alerts`

Mọi push Android của server gắn `android.notification.channel_id = "vthm_alerts"`. App tạo kênh **một lần lúc khởi động**:

```dart
const channel = AndroidNotificationChannel(
  'vthm_alerts',            // KHÔNG đổi — server gửi đúng id này (hằng số, không cấu hình được)
  'Thông báo VTHM',
  importance: Importance.high,
);
await FlutterLocalNotificationsPlugin()
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```

Chưa tạo kênh thì Android rơi về kênh mặc định "Khác" — nhiều máy để mức thấp: không kêu, không banner.

---

## 5. Gói tin FCM và cách nhận

### 5.1 Hình dạng gói (máy `platform = android`)

```json
{
  "notification": { "title": "[VTHM Miền Nam] Điểm bán đã được duyệt: …", "body": "Điểm bán 08170165 chuyển sang trạng thái \"Đã duyệt\"." },
  "data": {
    "type": "crm.customer_approved",
    "link": "/crm/my-customers?open=8455",
    "tag":  "…",
    "uids": "1009,2231"
  },
  "android": { "priority": "high", "collapse_key": "…",
               "notification": { "sound": "default", "channel_id": "vthm_alerts", "tag": "…" } }
}
```

| Khoá `data` | Luôn có? | Ý nghĩa |
|---|---|---|
| `type` | **luôn** | Loại tin — **khoá để điều hướng** (§6). Chuỗi dạng `<module>.<sự kiện>` (từ 19/10/2026 mọi push đều mang; trước đó push duyệt điểm bán thiếu khoá này) |
| `link` | không | Đường **web One** (tương đối, bắt đầu bằng `/`). Tin không gắn trang web nào (nhắc ca) thì không có |
| `tag` | không | Tin cùng `tag` **thay thế** tin cũ trên khay (và FCM chỉ giữ bản mới nhất khi máy offline) |
| `uids` | khi biết chủ máy | Danh sách `usr_user.id` (ngăn bằng dấu phẩy) được phép thấy tin trên máy này — §5.3 |

* Tiêu đề có thể có tiền tố `[Tên công ty]` khi người nhận có nhiều tài khoản (kiêm nhiệm) — chỉ để hiển thị, đừng tách chuỗi.
* Mọi giá trị trong `data` là **chuỗi** (giới hạn của FCM) — tự ép kiểu (`int.parse` cho id).
* Có khối `notification` ⇒ **Android tự hiện tin khi app ở nền hoặc đã tắt**, app không cần chạy.

### 5.2 Ba trạng thái app

```dart
Future<void> setupPush() async {
  // App đã TẮT, được mở lên vì bấm thông báo:
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) openFromPush(initial);

  // App ở NỀN, người dùng bấm thông báo:
  FirebaseMessaging.onMessageOpenedApp.listen(openFromPush);

  // App đang MỞ: Android KHÔNG tự hiện — app tự hiện banner (flutter_local_notifications, kênh vthm_alerts):
  FirebaseMessaging.onMessage.listen((m) {
    if (!isForCurrentUser(m)) return;      // §5.3
    showInAppBanner(m, onTap: () => openFromPush(m));
    refreshAfterPush(m);                   // §6: làm mới dữ liệu liên quan
  });
}
```

### 5.3 `data.uids` — chỉ hiện tin của tài khoản đang đăng nhập

```dart
bool isForCurrentUser(RemoteMessage m) {
  final raw = m.data['uids'];
  if (raw == null || raw.isEmpty) return true;            // tin cũ / không có danh sách ⇒ hiện như thường
  final me = currentUserId;                               // usr_user.id của phiên hiện tại; null = chưa đăng nhập
  return me != null && raw.split(',').contains('$me');
}
```

* Dùng ở **foreground** (§5.2) và **khi bấm** (`openFromPush`): tin không dành cho tài khoản hiện tại thì mở màn chính,
  đừng mở dữ liệu của người khác.
* Khi app ở nền, Android tự hiện khối `notification` nên **không lọc được** — vì vậy §3.2/§3.3 (nhả máy) mới là lớp chặn
  chính; `uids` là lưới sau cho máy chưa kịp nhả.

---

## 6. Điều hướng theo `data.type`

### 6.1 Các loại tin dành cho app DMS

| `data.type` | Khi nào | `link` | App nên làm khi bấm | Tới app DMS (`prefer_app = dms`) |
|---|---|---|---|---|
| `att.shift_remind_in` | 15′ trước giờ vào ca | — | Mở **màn chấm công** | có |
| `att.shift_remind_out` | Đúng giờ ra ca | — | Mở **màn chấm công** | có |
| `crm.customer_approved` | Điểm bán mình mở **được duyệt** | `/crm/my-customers?open=<id>` (quản trị: `/crm/customers?open=<id>`) | Đọc tham số **`open`** ⇒ `GET /crm/customers/{id}` ⇒ mở chi tiết điểm bán; làm mới `GET /crm/customers/mine` | có |
| `crm.customer_rejected` | Điểm bán mình mở **bị từ chối** (nội dung có lý do) | như trên | như trên — hiện rõ lý do (`approval_note`) để nhân viên sửa hồ sơ | có |

`crm.customer_pending` (điểm bán mới chờ duyệt, gửi người duyệt) **không** tới app DMS — duyệt chỉ làm trên web One
(chủ hệ thống chốt 19/10/2026); tin đó đi app One / trình duyệt + email.

Chi tiết từng loại: [nhắc ca §3](API-NHAC-CA-MOBILE-2026-10-17.md) · [duyệt điểm bán §6](API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15.md).

🔴 **Đọc tham số `open`, đừng so khớp cả đường dẫn** — `link` khác nhau theo vai người nhận và có thể đổi tiếp.

```dart
void openFromPush(RemoteMessage m) {
  if (!isForCurrentUser(m)) { navigator.pushNamed('/home'); return; }
  final type = m.data['type'] ?? '';
  final link = m.data['link'];
  switch (type) {
    case 'att.shift_remind_in':
    case 'att.shift_remind_out':
      navigator.pushNamed('/attendance/punch');
      return;
    case 'crm.customer_approved':
    case 'crm.customer_rejected':
      final id = int.tryParse(Uri.parse(link ?? '').queryParameters['open'] ?? '');
      if (id != null) { navigator.pushNamed('/customers/detail', arguments: id); return; }
      break;
  }
  openOther(type, link);   // §6.2
}
```

### 6.2 App DMS CHỈ nhận push của thị trường

Chủ hệ thống chốt 19/10/2026: **máy `app = dms` chỉ nhận đúng các loại tin ở bảng §6.1**. Thông báo khác của One (công
việc, dự án, phản hồi, tin nhắn chat, khảo sát…) **không** đẩy tới app DMS — chúng đi app One / trình duyệt, và vẫn
nằm trong danh sách thông báo (§9) + email. Người chỉ cài app DMS vì vậy không có push của One.

App vẫn nên xử lý mềm `type` lạ (mở màn chính, **không** văng): danh sách §6.1 sẽ còn tăng (vd tin `dms.*`), và danh
sách thông báo §9 trả mọi loại tin của người dùng, kể cả tin One.

Người dùng tắt từng nhóm tin (kể cả kênh push) ở **Cài đặt thông báo** trên web One; server tự tôn trọng — app không
phải lọc theo cài đặt.

### 6.3 Không phải push

**Xin vị trí** ("Xin vị trí ngay" của quản lý) **không** đi qua push — không có silent push đánh thức app. App nhận lệnh
qua WebSocket và qua `GET /dms/locations/pending` / phản hồi `ping`
([vị trí nhân viên §3](API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md)).

---

## 7. `prefer_app` — vì sao bắt buộc gửi `"app": "dms"`

Tin ở bảng §6.1 (cột cuối) server gắn `prefer_app = dms` — đây cũng chính là định nghĩa "tin DMS" ở §6.2:

* người nhận **có** máy đăng ký `app = dms` ⇒ tin **chỉ** tới các máy app DMS (cài cả app One trên cùng máy cũng không
  hiện hai lần);
* người nhận **chưa có** máy app DMS nào ⇒ tin tới mọi máy như cũ (app One, trình duyệt) — không mất tin.

* tin **không** gắn `prefer_app = dms` ⇒ **không bao giờ** tới máy `app = dms` (§6.2).

App DMS đăng ký thiếu `"app": "dms"` thì server coi máy đó là app One ⇒ app DMS nhận **mọi** tin của One và người cài
hai app nhận tin thị trường hai lần.

---

## 8. Kiểm thử (trên `app_test`)

1. Đăng nhập app bằng tài khoản thử, kiểm bảng máy có dòng `app = dms`, `platform = android` (nhờ đội One xem). Bắn
   thử một push: đội One chạy `php yii push/test --username=<mã NV> --app=dms` (thiếu `--app=dms` thì là tin của One —
   máy app DMS sẽ KHÔNG nhận, đúng luật §6.2).
2. **Nhắc ca:** nhờ nhân sự xếp một ca cho tài khoản thử bắt đầu sau ~20 phút ⇒ push `att.shift_remind_in` tới trong
   khoảng 15′ trước giờ vào (trễ tối đa ~5′ do cron). Thử ở ba trạng thái: app mở / ở nền / đã tắt.
3. **Duyệt điểm bán:** mở một điểm bán mới từ app ⇒ nhờ quản trị duyệt hoặc từ chối trên web ⇒ push
   `crm.customer_approved` / `crm.customer_rejected`; bấm vào phải mở đúng chi tiết điểm bán (`open=<id>`).
4. **Đổi tài khoản:** đăng xuất A, đăng nhập B trên cùng máy ⇒ tin của A không còn tới (§3.2); tin lọt (máy chưa kịp
   nhả) thì không được mở dữ liệu của A (§5.3).
5. **Hai app trên một máy:** cài cả app One và app DMS ⇒ tin ở bảng §6.1 chỉ hiện ở app DMS; tin One (vd giao một
   công việc cho tài khoản thử) chỉ hiện ở app One, **không** hiện ở app DMS.

---

## 9. Danh sách thông báo trong app (chuông)

Push chỉ là "cái chuông kêu"; danh sách đầy đủ đọc từ server. Mọi endpoint chỉ trả thông báo của **chính** người gọi.

| Việc | Endpoint |
|---|---|
| Danh sách (mới nhất trước, phân trang `page`, `per-page`) | `GET /notification/notifications` |
| Số chưa đọc (badge) | `GET /notification/notifications/unread-count` |
| Đánh dấu đã đọc một tin | `POST /notification/notifications/{id}/read` |
| Đánh dấu đọc hết | `POST /notification/notifications/read-all` |
| Xoá một tin / xoá hết | `DELETE /notification/notifications/{id}` · `DELETE /notification/notifications` |

⚠️ Có tiền tố module `notification/` — `GET /notifications` (app đang gọi) không tồn tại, trả **404**.

Gợi ý: nhận push ở foreground (§5.2) ⇒ tăng badge / tải lại `unread-count`; mở màn thông báo ⇒ tải danh sách; bấm một tin
⇒ `…/{id}/read` rồi điều hướng như §6 (tin trong danh sách cũng có `type` + `link`).

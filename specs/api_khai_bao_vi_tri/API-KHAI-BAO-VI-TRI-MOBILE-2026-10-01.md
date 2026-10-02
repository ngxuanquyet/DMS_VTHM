# API module KHAI BÁO VỊ TRÍ — cho app di động

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>` ·
viết 01/10/2026.

**Khai báo vị trí** là lượt nhân viên khai *mình đang ở đâu và vì sao*, khi **KHÔNG ở điểm bán nào** —
công tác ngoại tỉnh, họp, đi xử lý khiếu nại. Nó khác hẳn lượt viếng thăm điểm bán
([`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md)) ở ba chỗ, và cả ba đều là số
đo chứ không phải ý thích thiết kế (T08/2026, 1.004 lượt):

* **một mốc duy nhất** — 0% lượt có giờ ra, nên **không có check-out, không có thời lượng**;
* **lý do bắt buộc**, chọn từ danh mục do admin quản trị — lý do là toàn bộ nội dung của bản ghi;
* **không gắn điểm bán**, nên không có geofence, không có tuyến, **không hỏi số km**.

Mọi endpoint dưới đây đã được gọi thật bằng `curl` trên bản sao dữ liệu (`app_test`) ngày 01/10/2026; các
đoạn JSON là **phản hồi thật đã cắt gọn**, không phải ví dụ dựng tay.

> 🔴 **Bản ghi là APPEND-ONLY.** Gửi rồi thì **không sửa, không xoá** — nó là bằng chứng có mặt tại một chỗ
> vào một lúc. Hệ quả cho app: không có màn "sửa khai báo", và mọi điều kiện phải thoả **ngay lúc gửi**
> (khác viếng thăm, nơi còn cổng check-out để kiểm bù).

> 🔴 **Luật nghiệp vụ nằm ở SERVER.** App kiểm để làm mờ nút và báo còn thiếu gì; server kiểm lại tất cả.
> Mọi lời từ chối đều kèm **câu tiếng Việt viết cho nhân viên đọc** — hiện thẳng câu đó lên là đủ.

---

## 0. Một lượt khai báo gồm những bước nào

| # | Việc | Endpoint | Ghi chú |
|---|---|---|---|
| 1 | Đăng nhập | `POST /auth/login` | như mọi màn khác |
| 2 | Lấy danh mục **lý do đang bật** | `GET /dms/position-reasons/active` | giữ bản sao trong máy để chọn được khi mất sóng |
| 3 | Chụp ảnh → tải lên, **một lượt gọi mỗi tấm** | `POST /dms/position-photos` | nhận `token` |
| 4 | **Gửi khai báo** kèm danh sách token ảnh | `POST /dms/position-declarations` | bắt buộc: lý do + GPS + ảnh |
| — | Xem lại ảnh vừa tải | `GET /dms/position-photos/public/{token}` | không cần header, dùng thẳng trong `<img>` |

Thứ tự 3 → 4 là **bắt buộc**, không đảo được: bản ghi chỉ sinh ra khi đã đủ ảnh.

---

## 1. Quyền

Tài khoản đi thị trường phải giữ vai **`crm_customer_self`** — vai này đã có sẵn hai chuỗi quyền mà tài
liệu dùng tới:

| Chuỗi quyền | Mở cửa nào |
|---|---|
| `/dms/position-reason/active` | đọc danh mục lý do đang bật (bước 2) |
| `/dms/position-declaration/create` | **gửi khai báo** và **tải ảnh** (bước 3 + 4) |

Thiếu quyền ⇒ **403** (đo thật: tài khoản không vai nhận 403 ở cả ba endpoint). Tài khoản không phải nhân sự
nội bộ (đối tác) bị chặn ở mọi endpoint của luồng này.

⚠️ **Tải ảnh gác bằng chính quyền gửi khai báo**, không có chuỗi riêng — ai khai báo được thì chụp được. Đừng
chờ một quyền `/dms/position-photo/*`, nó không tồn tại.

---

## 2. Danh mục lý do

```
GET /dms/position-reasons/active
```

```json
{"success":true,"message":"Thành công","data":[
  {"id":1,"code":"001","name":"Công tác ngoại tỉnh","color":null},
  {"id":2,"code":"002","name":"Phối hợp giải quyết công việc ngoài tuyến","color":null},
  {"id":3,"code":"003","name":"Thăm viếng khách hàng","color":null}
]}
```

* **Không phân trang** — trả trọn danh mục đang bật, sắp sẵn theo thứ tự admin đặt. App tải một lần rồi giữ
  bản sao để chọn được khi mất sóng.
* 🔴 **CẤM đoán số dòng.** Hôm nay 17 dòng, nhưng admin thêm/tắt/xoá tự do — đọc đúng những gì API trả về.
* 🔴 **CẤM tham chiếu mã cứng** (`if (code == '001')`). Admin đổi mã hay xoá dòng là app sai **im lặng**.
  Mọi thứ app cần đều nằm trong `id`; `code` chỉ để **hiển thị cạnh tên**.
* `color` là mã màu Bootstrap (`success` · `danger` · `warning` · `info` · `primary` · `secondary` · `dark`)
  hoặc `null`. Chỉ có 7 màu cho một danh mục không giới hạn dòng ⇒ **màu không đủ phân biệt**, app phải hiện
  kèm `code`.
* Lý do admin **tắt** biến khỏi danh sách này; bản ghi cũ vẫn giữ nhãn. Xem §5 về bản ghi ngoại tuyến mang
  lý do vừa bị tắt.

---

## 3. Tải ảnh

```
POST /dms/position-photos          Content-Type: multipart/form-data, field "file"
```

```json
{"success":true,"message":"Đã tải tệp lên.","data":{
  "token":"26602804093aa75356b8613f6c5629c7",
  "name":"anh1.jpg","ext":"jpg","size":709,"mime":"image/jpeg",
  "url":"/dms/position-photos/public/26602804093aa75356b8613f6c5629c7"
}}
```

* **Một lượt gọi một tấm.** Giữ lại `token` để gửi ở bước 4; `url` là đường xem công khai (không cần header
  `Authorization`), ghép với host rồi đặt thẳng vào `<img src>` để người dùng xem lại.
* 🔴 **Chỉ nhận `jpg · jpeg · png · gif · webp · bmp` — KHÔNG nhận `heic/heif`** (đo thật trong
  `BaseFileController::EXT_IMAGES` ngày 01/10/2026). Đây là cái bẫy của iOS: iPhone mặc định chụp **HEIC**,
  nên app phải **convert/nén sang JPEG trước khi gửi**, nếu không mọi lượt chụp trên iPhone đều bị từ chối.
  Cần server nhận HEIC thì phải mở ở tầng hạ tầng dùng chung (ảnh hưởng mọi module) — báo để quyết, đừng
  chờ nó tự có.
* **Trần kích thước một tệp: 10 MB** (tham số hệ thống, người vận hành chỉnh được). Ảnh gốc 12 MPx thường
  vượt ⇒ nén trước khi gửi, vừa qua trần vừa đỡ 3G ngoài thị trường.
* 🔴 **Ảnh tải lên mà không ai gửi kèm khai báo sẽ bị dọn rác sau 1 ngày.** App giữ ảnh trong hàng đợi ngoại
  tuyến quá một ngày rồi mới gửi thì **phải tải lại ảnh**, nếu không lượt gửi thiếu ảnh và bị từ chối.
* ⚠️ **Camera bắt buộc là việc của APP.** Server không phân biệt được ảnh chụp trực tiếp với ảnh chọn từ thư
  viện — đừng trông chờ một hàng rào không tồn tại.

---

## 4. Gửi khai báo

```
POST /dms/position-declarations          Content-Type: application/json
```

### 4.1 Thân yêu cầu

| Trường | Kiểu | Bắt buộc | Ghi chú |
|---|---|---|---|
| `reason_id` | int | ✅ | `id` lấy từ §2 — phải là lý do **đang bật** |
| `lat` · `lng` | number | ✅ | −90…90 và −180…180. Thiếu ⇒ 422 |
| `photo_tokens` | string[] | ✅ (theo cấu hình) | token 32 hex từ §3; tối đa **10** tấm |
| `title` | string(500) | — | mô tả ngắn người dùng gõ ("đi họp ở CN Cần Thơ") |
| `address` | string(1000) | — | địa chỉ app giải mã từ toạ độ |
| `accuracy_m` | number | — | sai số định vị máy báo (mét) |
| `note` | string(1000) | — | ghi chú thêm |
| `is_mock_location` | bool | — | máy báo đang giả lập vị trí |
| `client_uuid` | uuid | — | **nên luôn gửi** — khoá chống trùng, xem §4.3 |
| `client_time` | ISO-8601 | — | giờ máy **LÚC BẤM**, không phải lúc gửi — xem §5.2 |
| `is_offline_sync` · `queued_seconds` · `client_boot_id` | bool · int · string(64) | — | hàng đợi ngoại tuyến, xem §5 |
| `device_info` | object | — | thiết bị + phiên bản app, lưu nguyên văn để đối soát |

🔴 **KHÔNG có trường `km_declared`.** Luồng khai báo vị trí không hỏi số km (chủ hệ thống chốt 01/10/2026) —
quãng đường chỉ thuộc lượt viếng thăm điểm bán. Gửi lên cũng bị bỏ qua.

### 4.2 Phản hồi thành công (201)

```json
{"success":true,"message":"Đã tạo thành công.","data":{
  "id":20157,
  "declared_at":"2026-10-01 10:27:49+07",
  "declared_date":"2026-10-01",
  "reason_id":1,
  "photo_count":1
}}
```

🔴 **`declared_at` là mốc SERVER đã ghi, không phải mốc app gửi** — với bản ghi ngoại tuyến nó được **dựng
lại** (xem §5). App nên hiển thị lại con số này thay vì giờ của chính mình, để người dùng thấy đúng thứ đã
vào sổ.

### 4.3 Gửi lại là an toàn (idempotent)

Gửi **cùng `client_uuid`** lần thứ hai không tạo bản ghi mới — server trả về **chính bản ghi cũ** kèm mã
201 và đúng `id`. Nhờ vậy hàng đợi ngoại tuyến cứ việc thử lại khi mạng chập chờn mà không sợ nhân đôi.

⚠️ Không gửi `client_uuid` thì mỗi lần gửi lại là **một bản ghi mới** — và vì bản ghi không xoá được, nó
nằm lại vĩnh viễn trong báo cáo. Hãy sinh UUID **một lần lúc người dùng bấm**, không phải mỗi lần retry.

---

## 5. Hàng đợi ngoại tuyến — phần dễ sai nhất

Nhân viên công tác ngoại tỉnh (lý do khai báo nhiều nhất trên dữ liệu thật) cũng là người hay mất sóng nhất.
Nếu server lấy giờ **lúc gói tin đến**, lượt khai lúc 9h sáng gửi được lúc 18h sẽ nằm sai ô trong báo cáo
tháng; mất sóng qua đêm thì nó **rơi sang ngày hôm sau**. Sai im lặng: bảng vẫn đầy số, chỉ nằm nhầm chỗ.

### 5.1 Cách đúng: gửi khoảng NẰM CHỜ, không gửi giờ máy

```
is_offline_sync = true
queued_seconds  = <số giây bản ghi đã nằm chờ trong máy, đo bằng đồng hồ ĐƠN ĐIỆU của hệ điều hành>
client_boot_id  = <định danh phiên khởi động hiện tại>
```

Server dựng lại mốc bằng đồng hồ **của chính nó**: `declared_at = giờ_server_lúc_nhận − queued_seconds`.

Đo thật 01/10/2026: gửi `queued_seconds = 5400` lúc 11:57 → server ghi `declared_at = 10:27:49`, đúng 1,5 giờ
trước. `declared_date` đi theo mốc đã dựng, nên bản ghi nằm đúng ngày người ta bấm.

🔴 **Dùng đồng hồ ĐƠN ĐIỆU** (`SystemClock.elapsedRealtime()` trên Android, `systemUptime` trên iOS), không
dùng `DateTime.now()` — ý nghĩa của nó là "máy không vặn được".

🔴 **Bộ đếm về 0 sau mỗi lần khởi động máy.** Bản ghi sống qua một lần reboot thì app **KHÔNG được đoán**:
gửi `queued_seconds` **rỗng**, và gửi `client_boot_id` khác đi. Gửi `0` thì server ghi mốc thành "vừa mới
bấm" — sai im lặng, và sai theo hướng trông rất hợp lý.

⚠️ Server **kẹp trần** `queued_seconds` theo "lần cuối thiết bị còn online" (và trần cấu hình, mặc định 24
giờ). Khai vượt thì bị **cắt về trần và gắn cờ nghi vấn**, không bị từ chối.

### 5.2 `client_time` là giờ LÚC BẤM

`client_time` chỉ để đối soát đồng hồ máy, và server so nó với mốc đã dựng. Gửi **giờ lúc đồng bộ** thay vì
giờ lúc bấm sẽ làm bản ghi bị gắn cờ "nghi đổi giờ máy" oan.

Đo thật: cùng bản ghi ở §5.1, gửi `client_time = 11:40` trong khi mốc thật là 10:27 ⇒ `time_diff_seconds =
−4331`, `is_time_tampered = true`. Cờ này **không chặn** việc gửi, nhưng nó hiện lên báo cáo của người quản
lý như một dấu hỏi về nhân viên — đừng để app tạo ra nó.

### 5.3 Lý do bị tắt giữa chừng

App giữ bản sao danh mục để dùng offline, nên bản ghi trong hàng đợi có thể mang một lý do admin vừa tắt.
Server trả **422** kèm tên lý do cụ thể:

```json
{"success":false,"message":"Lý do \"Thăm viếng khách hàng\" đã ngừng sử dụng. Hãy chọn lý do khác.",
 "errors":null,"data":null}
```

App nên **giữ bản ghi lại** và hỏi người dùng chọn lý do khác, thay vì bỏ im lặng — toạ độ và ảnh của họ vẫn
còn giá trị.

---

## 6. Bảng lỗi — câu nào hiện thẳng cho người dùng

| Mã | `message` (hiện thẳng lên app) | Nguyên nhân |
|---|---|---|
| 422 | `Vĩ độ không được để trống.` / `Kinh độ không được để trống.` | thiếu `lat`/`lng`; `errors.lat`, `errors.lng` chỉ đúng ô |
| 422 | `Bạn cần chụp thêm 1 ảnh trước khi gửi khai báo.` | chưa đủ số ảnh tối thiểu (cấu hình, mặc định 1) |
| 422 | `Hãy chọn một lý do trong danh mục.` | `reason_id` không tồn tại |
| 422 | `Lý do "X" đã ngừng sử dụng. Hãy chọn lý do khác.` | lý do đã bị tắt — xem §5.3 |
| 422 | `Trường photo_tokens phải chứa mã tệp lấy từ cửa tải ảnh lên.` | token không phải 32 hex |
| 422 | `Mỗi lượt khai báo gửi kèm tối đa 10 ảnh.` | quá trần ảnh |
| 422 | `Máy đang bật giả lập vị trí. Hãy tắt rồi thử lại.` | chỉ khi admin BẬT công tắc chặn (mặc định tắt) |
| 422 | `Tệp "x.heic" có định dạng không được phép — chỉ nhận ảnh.` | ảnh HEIC của iPhone — convert sang JPEG, xem §3 |
| 422 | `Tệp "x.jpg" (11265 KB) vượt mức tối đa 10240 KB.` | ảnh > 10 MB — nén trước khi gửi |
| 403 | `Bạn không có quyền thực hiện thao tác này.` | thiếu vai `crm_customer_self` |
| 403 | `Phiên đăng nhập chưa gắn với tài khoản nào.` | token hợp lệ nhưng không gắn người |

🔴 **Phân biệt 422 với 5xx.** 422 là *người dùng làm thiếu bước* — hiện câu tiếng Việt và cho họ sửa. 5xx là
*sự cố* — giữ bản ghi trong hàng đợi và thử lại sau, đừng bắt người dùng nhập lại.

⚠️ **Token ảnh không tra ra (đã bị dọn rác) bị bỏ qua IM LẶNG**, không báo lỗi riêng. Hệ quả: nếu vì thế mà
thiếu ảnh, câu người dùng nhận được là *"cần chụp thêm N ảnh"* — đúng việc họ phải làm.

---

## 7. Hai tham số do người vận hành chỉnh

Admin đổi ở `/system/settings/dms` (nhóm **Luật khai báo vị trí**), **không cần phát hành app mới**:

| Tham số | Mặc định | Ảnh hưởng tới app |
|---|---|---|
| Số ảnh tối thiểu mỗi lượt khai báo | **1** | 0 = không đòi ảnh; app nên đọc lỗi 422 thay vì chốt cứng con số |
| Chặn khai báo khi máy báo giả lập vị trí | **tắt** | tắt = vẫn cho gửi, chỉ gắn cờ; bật = 422 |

🔴 **Đừng hardcode "phải có đúng 1 ảnh" trong app.** Admin nâng lên 2 là app chặn sai hoặc cho qua sai. Cách
đúng: cho người dùng chụp tuỳ ý, gửi đi, và hiện câu lỗi của server nếu thiếu.

---

## 8. Thứ KHÔNG có trong đợt này

Nói rõ để đội mobile khỏi đi tìm:

* **Không có `GET /dms/position-declarations/mine`.** Lịch sử khai báo của chính mình chưa có endpoint —
  app tự giữ bản ghi đã gửi trong máy. Cần đường này thì báo để mở (phải gác quyền riêng và ép lọc theo tài
  khoản của phiên).
* **Không có sửa/xoá.** Append-only, xem đầu tài liệu.
* **Không có check-out, không có thời lượng, không có km.**
* **Không có báo cáo cho app.** Màn ma trận tháng (`/dms/position-report`) là của web, gác bằng quyền quản
  trị `crm_customer_admin`.

---

## 9. Đối chiếu nhanh với luồng viếng thăm

| | Viếng thăm điểm bán | Khai báo vị trí |
|---|---|---|
| Điểm bán | bắt buộc, có geofence | **không có** |
| Số mốc | 2 (check-in + check-out) | **1** |
| Lý do | không có | **bắt buộc, từ danh mục** |
| Ảnh | tải lên **sau khi** mở lượt (`/dms/visits/{id}/photos`) | tải **trước**, gửi kèm token |
| Km | có (hỏi lúc check-in) | **không** |
| Sửa/xoá | huỷ được lượt đang mở | **không** |
| Ngữ cảnh tệp ảnh | `dms_visit_photo` | `dms_position_photo` |

🔴 **Hai ngữ cảnh ảnh KHÔNG dùng chéo được.** Token ảnh khai báo gọi qua `/dms/visit-photos/public/{token}`
trả **404** (đã đo), và ngược lại. Mỗi luồng dùng đúng cặp endpoint của nó.

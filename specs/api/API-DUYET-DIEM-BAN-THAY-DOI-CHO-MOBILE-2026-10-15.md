# Thay đổi API ngày 15/10/2026 — điểm bán mới phải qua DUYỆT

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 15/10/2026** với luồng mở điểm bán + viếng thăm của app DMS.
JSON dưới đây là phản hồi **thật**, gọi bằng `curl` trên bản sao dữ liệu (`app_test`) cùng ngày (đã cắt gọn); riêng
bảng nội dung push ở §6 là câu mẫu dựng theo khuôn của server.

Hợp đồng đầy đủ vẫn ở các file gốc — file này chỉ là phần thêm:
[`API-TAO-DIEM-BAN-2026-09-18.md`](API-TAO-DIEM-BAN-2026-09-18.md) ·
[`API-SUA-DIEM-BAN-2026-09-16.md`](API-SUA-DIEM-BAN-2026-09-16.md) ·
[`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md). Nghiệp vụ:
[`docs/specs/crm/DUYET-DIEM-BAN-MOI-2026-10-15.md`](../../specs/crm/DUYET-DIEM-BAN-MOI-2026-10-15.md).

> 🟢 **Không vỡ gì với bản app hiện tại.** Tạo điểm bán, check-in, chụp ảnh, nộp biểu mẫu, check-out chạy y như
> cũ — điểm bán chờ duyệt / bị từ chối **KHÔNG bị chặn**. Phần app nên làm thêm chỉ là **HIỂN THỊ** trạng thái
> duyệt cho nhân viên biết, và **ngừng gửi** `approval_status` khi sửa điểm bán (nếu app đang gửi).

| # | Thay đổi | Loại | Ảnh hưởng app |
|---|---|---|---|
| 1 | Nhân viên mở điểm bán trên app ⇒ điểm bán vào trạng thái **Chờ duyệt** (`pending`) | **HÀNH VI MỚI** | Không phải sửa gì — chỉ nên hiển thị |
| 2 | Hồ sơ điểm bán có thêm 4 khoá `approval_label`, `approval_color`, `approval_note`, `approval_at` | **THÊM KHOÁ** | Nên hiện nhãn + lý do |
| 3 | `PATCH /crm/customers/{id}` **không nhận** `approval_status` nữa ⇒ 422 | **ĐỔI** | Bắt buộc nếu app đang gửi khoá này |
| 4 | Dòng lượt viếng thăm có thêm `customer_approval_status` | **THÊM KHOÁ** | Tuỳ chọn |
| 5 | Thông báo đẩy khi điểm bán của mình được duyệt / bị từ chối | **THÊM** | Nên mở đúng điểm bán khi bấm |

---

## 1. Chuyện gì đổi ở phía server

Trước 15/10/2026 mọi điểm bán mở mới đều "đã duyệt" ngay. Nay:

* **Nhân viên thị trường** (tài khoản KHÔNG có quyền xem toàn danh mục `/crm/customer/index`) mở điểm bán ⇒
  `approval_status = "pending"`. Quản trị mở hộ trên web, dữ liệu MobiWork và mọi điểm bán có từ trước vẫn là
  `"approved"`.
* Quản trị điểm bán (vai `crm_customer_admin`) **duyệt** hoặc **từ chối** trên web One. Từ chối bắt buộc có lý do.
  Quyết định đổi lại được (bị từ chối → duyệt lại, và ngược lại).
* **Một hồ sơ chung:** lượt viếng thăm không có trạng thái duyệt riêng — nó đi theo trạng thái của điểm bán.
* Chờ duyệt / bị từ chối **vẫn dùng bình thường** (check-in, ghé lại, ảnh, biểu mẫu). Khác biệt duy nhất là báo cáo
  viếng thăm **không đếm** các lượt ở điểm bán đó vào số lượt / số khách của nhân viên cho tới khi được duyệt.

Ba giá trị `approval_status`:

| Giá trị | `approval_label` | `approval_color` | Nghĩa với nhân viên |
|---|---|---|---|
| `pending` | Chờ duyệt | `warning` | Vừa mở, đang chờ quản trị xem. Lượt viếng thăm chưa được tính |
| `approved` | Đã duyệt | `success` | Bình thường |
| `rejected` | Bị từ chối | `danger` | Không được công nhận — xem `approval_note` để biết vì sao. Lượt viếng thăm không được tính |

> ⚠️ **Đừng tự map nhãn/màu trong app.** Đọc thẳng `approval_label` (đã dịch theo ngôn ngữ phiên) và
> `approval_color` (mã Bootstrap: `success` / `warning` / `danger`). Thêm trạng thái mới về sau thì app không phải
> sửa. Giá trị lạ hoặc thiếu ⇒ coi như `approved`.

---

## 2. Tạo điểm bán — `POST /crm/customers`

**Request không đổi.** App KHÔNG gửi `approval_status` — server tự quyết (gửi lên vẫn nhận 422 như trước).

**Response không đổi** (`id`, `code`, `created`, `route_ids`) — **không** kèm trạng thái duyệt. Muốn hiện nhãn
"Chờ duyệt" ngay sau khi tạo thì đọc lại hồ sơ (`GET /crm/customers/{id}`) hoặc làm mới danh sách
`GET /crm/customers/mine` như app vẫn làm sau khi tạo. Với nhân viên thị trường, điểm bán vừa mở **luôn** là
`pending`.

Lượt gửi lại cùng `client_uuid` (`created = false`) trả về bản ghi cũ, không tạo lần duyệt thứ hai.

**Check-in ngay sau khi tạo: không đổi gì.** Điểm bán chờ duyệt vẫn qua đủ luật check-in cũ (tuyến, geofence,
GPS giả) — trạng thái duyệt KHÔNG nằm trong luật check-in.

---

## 3. Đọc hồ sơ điểm bán — 4 khoá mới

Áp cho **mọi** endpoint trả hồ sơ điểm bán: `GET /crm/customers/mine`, `GET /crm/customers/{id}`,
`GET /crm/customers`.

```
GET /crm/customers/89187
Authorization: Bearer …
```

```json
{
  "success": true,
  "data": {
    "id": 89187,
    "code": "08650170",
    "name": "[TEST-CC] Toạ độ 1792031492103",
    "status": "active",
    "approval_status": "rejected",
    "approval_label": "Bị từ chối",
    "approval_color": "danger",
    "approval_note": "Trùng với điểm bán 08650001 — đề nghị kiểm tra lại địa chỉ",
    "approval_at": "2026-10-15 16:47:49.039594+07"
  }
}
```

| Khoá | Kiểu | Ghi chú |
|---|---|---|
| `approval_status` | string | Có từ trước, nay mới thật sự mang `pending` / `rejected` |
| `approval_label` | string | Nhãn hiển thị, đã dịch |
| `approval_color` | string | `success` · `warning` · `danger` |
| `approval_note` | string \| null | Lý do của quyết định **gần nhất**. Luôn có khi `rejected`; `null` khi duyệt không ghi chú |
| `approval_at` | string \| null | Thời điểm quyết định gần nhất (giờ VN, có múi giờ). `null` với điểm bán chưa ai quyết (vừa mở, hoặc có từ trước) |

**Không có** người duyệt (ai duyệt / ai từ chối) và **không có** lịch sử duyệt trong API của app — cố ý. Lịch sử chỉ
quản trị xem được trên web.

### Gợi ý hiển thị

* **Danh sách điểm bán / lịch đi tuyến:** điểm bán `approval_status ≠ "approved"` gắn một nhãn nhỏ cạnh tên, màu
  theo `approval_color`, chữ theo `approval_label`.
* **Chi tiết điểm bán:**
  * `pending` → dải cảnh báo vàng: *"Điểm bán đang chờ duyệt. Bạn vẫn viếng thăm bình thường; các lượt ở đây được
    tính vào báo cáo sau khi được duyệt."*
  * `rejected` → dải đỏ: *"Điểm bán bị từ chối. Lý do: {approval_note}"*. Không khoá nút nào — nhân viên vẫn
    check-in được (chủ hệ thống chốt: từ chối chỉ là lưu vết).
* **Màn check-in:** không chặn, không hỏi thêm. Có thể nhắc một dòng khi điểm bán đang `pending` / `rejected`.

---

## 4. Sửa điểm bán — `PATCH /crm/customers/{id}` không nhận `approval_status`

Trước đây khoá này ghi được (kể cả nhân viên với điểm bán của chính mình ⇒ tự duyệt được). Nay đổi trạng thái duyệt
**chỉ** qua nút Duyệt / Từ chối trên web của quản trị.

```
PATCH /crm/customers/89187
{"approval_status":"approved"}
```

```json
{"success":false,"message":"Trường approval_status không sửa được.","errors":{"approval_status":["Trường approval_status không sửa được."]},"data":null,"code":"VALIDATION_ERROR"}
```

HTTP **422**. 🔴 Nếu app đang gửi lại **trọn** hồ sơ khi sửa (kể cả `approval_status` đọc về từ GET) thì **mọi
lượt sửa sẽ hỏng** — phải bỏ khoá này khỏi body. App chỉ gửi đúng những ô người dùng đã đổi là cách đúng sẵn
(PATCH: ô vắng mặt = giữ nguyên).

Sửa một điểm bán đang chờ duyệt / bị từ chối **không** đưa nó về chờ duyệt lại.

---

## 5. Lượt viếng thăm — khoá `customer_approval_status`

`GET /dms/visits/mine` (và báo cáo của quản lý) — mỗi dòng có thêm:

```json
{ "id": 42169, "customer_code": "08170165", "customer_name": "Thành Hậu", "customer_approval_status": "approved", … }
```

(Dòng thật trên `app_test` — khoá do cùng một truy vấn sinh ra cho cả `/dms/visits/mine` lẫn báo cáo quản lý.)

Giá trị như §1 (`pending` / `approved` / `rejected`); lượt di trú MobiWork mất điểm bán luôn là `approved`. Ở
endpoint này **chỉ có mã trạng thái**, không có nhãn/màu — nếu muốn gắn nhãn trên lịch sử viếng thăm thì lấy
`approval_label` / `approval_color` của chính điểm bán đó từ `GET /crm/customers/mine`. Tuỳ chọn, không bắt buộc.

Nếu app tự đếm "hôm nay đã viếng thăm N điểm" thì nên đếm như báo cáo: chỉ lượt đã check-out ở điểm bán
`approved` — nếu không, con số trên app sẽ lệch với báo cáo quản lý xem.

### 5b. Lượt đầu ở điểm bán vừa mở: KHÔNG chịu thời gian tối thiểu (bổ sung 16/10/2026)

Chủ hệ thống chốt: nhân viên mở điểm bán mới trên app là viếng thăm luôn, nên **lượt đầu tiên** ở điểm bán đó được
check-out ngay, không phải chờ đủ `min_duration_minutes` của `GET /dms/mobile-rules`. Ảnh tối thiểu và biểu mẫu bắt
buộc **vẫn giữ** (người duyệt cần xem). Lượt ghé lại sau đó chịu luật như thường. Điểm bán chờ duyệt vẫn ghé được
nhiều lần, không có gì chặn.

Server đã áp luật này trong `GET /dms/visits/{id}/requirements` và `POST /dms/visits/{id}/checkout`: với lượt đó
`seconds_remaining` = `0` ngay từ đầu.

🔴 **App đừng tự đếm giờ theo `min_duration_minutes`** để khoá nút check-out. Đọc `seconds_remaining` của
`requirements` (hoặc khối `requirements` đi kèm phản hồi check-in / tải ảnh). Nếu app tự đếm thì nhân viên vẫn bị
giữ 5 phút ở lượt đầu, trong khi server đã cho ra.

---

## 6. Thông báo đẩy

Người MỞ điểm bán nhận push khi quản trị ra quyết định (người duyệt cũng là người mở thì không tự nhận):

| Sự kiện | Tiêu đề (ví dụ) | Nội dung (ví dụ) |
|---|---|---|
| Được duyệt | `Điểm bán đã được duyệt: Thành Hậu` | `Điểm bán 08170165 chuyển sang trạng thái "Đã duyệt".` |
| Bị từ chối | `Điểm bán bị từ chối: Thành Hậu` | `Điểm bán 08170165 chuyển sang trạng thái "Bị từ chối". Lý do: …` |

Khoá `data` của FCM có `link` (đường của web One) và `type` = `crm.customer_approved` | `crm.customer_rejected`.

> 🔄 **Cập nhật 19/10/2026 — `link` đổi theo người nhận:**
> * nhân viên thị trường (không có quyền màn quản trị Điểm bán) ⇒ **`/crm/my-customers?open=<id>`** (màn "Điểm bán
>   của tôi" trên web, có từ 18/10);
> * quản trị ⇒ vẫn `/crm/customers?open=<id>`.
>
> App DMS bấm vào để mở đúng điểm bán thì **chỉ đọc tham số `open`** trong `link` rồi gọi `GET /crm/customers/{id}` —
> ĐỪNG so khớp cả đường dẫn, vì nó khác nhau theo vai.

**Push tới máy nào.** Push đi qua máy app đã đăng ký bằng `POST /notification/device-token`. Từ 19/10/2026 hai tin này
mang cờ `prefer_app = dms` (cùng khuôn với push nhắc ca — [`API-NHAC-CA-MOBILE-2026-10-17.md`](API-NHAC-CA-MOBILE-2026-10-17.md)):

* người nhận **có** máy đăng ký với `app = dms` ⇒ **chỉ** các máy app DMS nhận (cài cả app One trên cùng máy cũng không
  hiện hai lần);
* người nhận **chưa có** máy app DMS nào ⇒ gửi tới mọi máy như trước (app One, trình duyệt) — không mất tin.

🔴 **App DMS phải đăng ký token với `app = dms`** thì mới nhận được push. Đo prod 19/10/2026: bảng token chưa có máy
`app = dms` nào (chỉ `one`: 18 máy Android, 146 trình duyệt) — tức app DMS hiện chưa nhận push nào. Kiểm thêm: file
`google-services.json` của app DMS phải thuộc **cùng dự án Firebase với server** (`project_id` = `vthmgroup-app`) và
có mục `client` đúng `applicationId` của app DMS; khác dự án thì FCM từ chối token và server không gửi được.

Người dùng tắt được hai loại tin này ở nhóm "Điểm bán" trong cài đặt thông báo.

Sau khi nhận push (hoặc khi app mở lại / đồng bộ ngoại tuyến) nên làm mới `GET /crm/customers/mine` — trạng thái
duyệt có thể đổi bất kỳ lúc nào, và bản sao trong máy sẽ cũ.

---

## 7. Danh sách việc cho app

- [ ] **Bắt buộc nếu đang gửi:** bỏ `approval_status` khỏi body `PATCH /crm/customers/{id}` (§4).
- [ ] Hiện nhãn trạng thái duyệt ở danh sách + chi tiết điểm bán, dùng `approval_label` / `approval_color` (§3).
- [ ] Hiện `approval_note` khi `rejected` (§3).
- [ ] Làm mới hồ sơ điểm bán sau khi tạo mới và khi nhận push duyệt / từ chối (§2, §6).
- [ ] Bấm push → mở chi tiết điểm bán theo `open=<id>` trong `link` (§6).
- [ ] (Tuỳ chọn) Số đếm viếng thăm trên app khớp báo cáo: chỉ đếm điểm bán `approved` (§5).
- [ ] **Nếu app tự đếm giờ** để khoá check-out: chuyển sang đọc `seconds_remaining` của server, vì lượt đầu ở điểm bán vừa mở được miễn thời gian tối thiểu (§5b).

Không cần đổi: luồng tạo điểm bán, check-in, ảnh, biểu mẫu, huỷ lượt. Check-out chỉ đổi ở chỗ đếm giờ (§5b).

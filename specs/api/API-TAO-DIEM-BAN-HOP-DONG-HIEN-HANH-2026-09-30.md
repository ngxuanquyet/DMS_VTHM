# `POST /crm/customers` — hợp đồng hiện hành, đo ngày 30/09/2026

Viết cho đội app DMS (Flutter) sau **hai lỗi 422 thật** gặp ngày 30/09. Mọi số liệu dưới đây **đo trực tiếp
trên `app_test` bằng tài khoản thật**, không chép lại tài liệu cũ.

**Không lặp lại hai tài liệu anh em, hãy đọc kèm:**
* `API-TAO-DIEM-BAN-2026-09-18.md` — trọn bộ luật tạo (tuyến bắt buộc, sinh mã, ai gọi được, mã lỗi).
* `API-MOBILE-TAO-KHACH-HANG-NHIEU-ANH-2026-09-23.md` — `GET /crm/customer-form/schema` + nhiều ảnh.

Bản này chỉ giải quyết **thứ hai tài liệu kia không nói thẳng** và chính là chỗ app đang vấp.

---

## 1. Một luật giải thích cả hai lỗi

`POST /crm/customers` dùng **danh sách trắng NGHIÊM NGẶT ở gốc body**
(`CustomerCreateForm::validateKhoaLa()`). Bất kỳ khoá nào ở gốc mà không nằm trong danh sách §2 đều bị từ
chối **422, nêu đích danh khoá đó**.

Đây là **thiết kế có chủ đích, không phải lỗi**: im lặng bỏ qua thì client tưởng đã đặt được mã điểm bán
hoặc đã gán được chủ sở hữu, và chỉ phát hiện khi dữ liệu đã lệch.

| Lỗi app gặp | Vì sao | Sửa |
|---|---|---|
| `Biểu mẫu điểm bán không có trường nào tên client_boot_id` | `client_boot_id` **chỉ** dùng ở 3 cửa DMS (§4), không phải phong bì chung | Đừng gắn vào request tạo điểm bán |
| `…không có trường nào tên mw_khach_hang_vthm`, `mw_nhan_1`, `mw_huyen`, `mw_nhan_2`, `mw_nhan_3` | Đây là ô **`dynamic`**, phải nằm **trong `data`**, không phải ở gốc | Xem §3 |

---

## 2. Danh sách khoá GỐC được nhận — đầy đủ, đo từ mã đang chạy

```
name  region_id  customer_type_id  customer_group_id  channel_id  status
address  delivery_address  province_name  ward_name
contact_name  contact_title  phone  email  birthday
lat  lng  geofence_radius_m
photo_file_id  photo_token  photo_tokens
client_uuid  is_offline_sync
route_ids
data
```

**Mọi khoá khác ở gốc = 422.** Gồm cả `client_boot_id`, `queued_seconds`, `client_time`, `code`,
`created_by_code`, `custom_labels`, và mọi mã ô động.

⚠️ **Danh sách này KHÁC danh sách ô trong schema.** `GET /crm/customer-form/schema` trả **18 ô `fixed`** để
app *vẽ màn nhập*; danh sách trên là thứ server *chấp nhận*. Một số khoá nhận được nhưng không có trong
schema (`customer_group_id`, `geofence_radius_m`, `photo_tokens`, `route_ids`, `client_uuid`,
`is_offline_sync`, `data`) vì chúng không phải ô người dùng gõ. **Đừng suy danh sách gửi từ schema.**

---

## 3. `fixed` gửi ở GỐC · `dynamic` gửi trong `data`

Mỗi ô trong schema có khoá `kind`:

| `kind` | Gửi ở đâu |
|---|---|
| `"fixed"` | **gốc body** — `{"name": "...", "phone": "..."}` |
| `"dynamic"` | **trong `data`** — `{"data": {"mw_huyen": "..."}}` |

Đo ngày 30/09/2026, biểu mẫu `crm_customer` (`version` `302e6a066fb1d890`) có **25 ô: 18 `fixed` + 7
`dynamic`**. Bảy ô động hiện đều là ô di trú MobiWork:

```
mw_ma_erp  mw_khach_hang_vthm  mw_nhan_1  mw_huyen  mw_hinh_anh  mw_nhan_3  mw_nhan_2
```

🔴 **Năm mã trong log lỗi của app đều nằm trong nhóm này** — app đang gửi chúng ở gốc.

Trong `data`, mã lạ cũng bị từ chối, nhưng bằng **câu khác** — dùng chính câu đó để phân biệt hai lỗi:

| Gửi ở | Câu báo lỗi |
|---|---|
| gốc | `Biểu mẫu điểm bán không có trường nào tên <mã>.` |
| trong `data` | `Không có ô động mang mã <mã>.` |

Ô `select` trong `data` vẫn bị kiểm danh sách giá trị: sai ⇒ `Nhãn 1 có giá trị ngoài danh sách cho phép.`

### ⚠️ Ô `mw_*` được lưu ở cột khác, với tên khác

Ô động có `source = "mobiwork"` **không** vào cột `data` mà vào `custom_labels`, và **tiền tố `mw_` bị cắt**:

| App gửi (trong `data`) | DB lưu (ở `custom_labels`) |
|---|---|
| `mw_huyen` | `huyen` |
| `mw_khach_hang_vthm` | `khach_hang_vthm` |

Đo thật: gửi `data: {"mw_huyen":"Nghi Lộc","mw_khach_hang_vthm":"X1"}` ⇒ `data = {}` và
`custom_labels = {"huyen":"Nghi Lộc","khach_hang_vthm":"X1"}`.

**App không phải làm gì với điều này** — cứ gửi đúng mã schema trả về. Ghi ra đây vì nhìn cột `data` rỗng
rất dễ tưởng dữ liệu bị mất (tôi đã tưởng vậy trong 10 phút).

---

## 4. `client_boot_id` / `queued_seconds` chỉ dùng ở ba cửa DMS

Hai trường của cơ chế đồng hồ đơn điệu **chỉ** được nhận ở:

```
POST /dms/visits                     (check-in)
POST /dms/visits/{id}/checkout
POST /dms/form-submissions
```

Chúng dựng lại **mốc bấm thật** cho bản ghi gửi từ hàng đợi. `POST /crm/customers` **không** nhận, và bảng
`crm_customer` cũng **chưa có cột** nào lưu chúng — nó chỉ có `client_uuid` và `is_offline_sync`.

🔴 **Đây là lỗ trong tài liệu của tôi, không phải lỗi đọc của đội mobile.** §9.1 của
`API-VIENG-THAM-MOBILE-2026-09-29.md` đặt hai trường đó trong bảng tham số của từng endpoint, nhưng **không
nói thẳng rằng các cửa khác sẽ TỪ CHỐI** nếu nhận được. Gắn vào phong bì chung của hàng đợi là cách đọc
hợp lý.

**Hệ quả cần quyết:** điểm bán tạo ngoại tuyến hiện lấy `created_at` = **giờ gói tin đến**, đúng cùng lỗi
vừa được gỡ cho lượt viếng thăm. Muốn sửa gốc thì mở hai trường này ở cửa tạo điểm bán (cần migration) —
chưa làm, ghi vào nợ.

---

## 5. Nhân viên thị trường bắt buộc gửi gì

🔴 **Đo bằng tài khoản `crm_customer_self` thật (VTG612), KHÔNG phải super admin.**

Super admin **đi đường khác**: không bị ép tuyến, không bị ép cột bắt buộc. Đo bằng tài khoản đó sẽ ra một
hợp đồng dễ dãi hơn thực tế — tôi đã vấp đúng bẫy này khi đo lần đầu bằng VTG926.

Gửi tối thiểu `{"name","region_id"}` bằng tài khoản thị trường ⇒ **422, hai lỗi cùng lúc**:

```json
{"route_ids":  ["Hãy chọn ít nhất một tuyến bán hàng cho điểm bán mới."],
 "photo_token":["Vui lòng chụp ảnh điểm bán trước khi lưu."]}
```

| Bắt buộc | Nhân viên thị trường | Quản trị (`/crm/customer/index`) |
|---|---|---|
| `name`, `region_id` | ✔ | ✔ |
| `route_ids` (tuyến CỦA CHÍNH MÌNH, đang bật — lấy ở `GET /dms/routes/mine`) | ✔ | ✖ |
| Ảnh điểm bán | ✔ | ✖ |

---

## 6. Lượt gọi ĐÚNG, đã chạy thật

```bash
# ① Tải từng ảnh, lấy token
curl -X POST https://api-app.vthmgroup.vn/crm/customer-photos \
     -H 'Authorization: Bearer <token>' -F 'file=@anh.jpg'
# → {"data":{"token":"ae2a1a671c3a92f23d87999741bc8986", "url":"/crm/customer-photos/public/ae2a…"}}

# ② Tạo điểm bán
curl -X POST https://api-app.vthmgroup.vn/crm/customers \
     -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' -d '{
  "name": "Tạp hoá Nghi Lộc",
  "region_id": 1,
  "phone": "0912345678",
  "address": "Số 1, Nghi Lộc",
  "lat": 18.82, "lng": 105.55,
  "route_ids": [6776, 6775],
  "photo_tokens": ["ae2a1a671c3a92f23d87999741bc8986", "bdc81d77c795e121c5dab974a7f0bf75"],
  "client_uuid": "0f2c…-uuid-app-sinh-1-lan",
  "is_offline_sync": true,
  "data": { "mw_huyen": "Nghi Lộc", "mw_khach_hang_vthm": "KH-TEST" }
}'
```

```json
{"success":true,"message":"Đã tạo điểm bán 08650173.",
 "data":{"id":77540,"code":"08650173","created":true,"route_ids":[6776,6775]}}
```

Kiểm trong DB sau lượt gọi trên: 2 dòng `crm_customer_photo`, `photo_file_id` trỏ tấm đầu,
`custom_labels = {"huyen":"Nghi Lộc","khach_hang_vthm":"KH-TEST"}`, `created_by_code = VTG612`,
`is_offline_sync = t`. **Mã điểm bán do server sinh — client không gửi `code`.**

---

## 7. 🔴 Luật thử lại: 422 là hỏng VĨNH VIỄN

Log cho thấy app thử lại mục #5 **đến lần thứ 25**, backoff đã giãn tới 306 giây.

Lỗi 422 là **tất định** — cùng payload đó gửi lại một nghìn lần vẫn 422. Hai hệ quả:

* **Điểm bán đó chưa bao giờ được tạo.** 422 là từ chối ở cửa validate, không ghi gì. Nhân viên đang tưởng
  nó "đang đồng bộ".
* **Nếu hàng đợi chạy tuần tự, mục hỏng chặn mọi mục sau nó** — lượt viếng thăm, ảnh, phiếu khảo sát phía
  sau đứng im theo.

Phân loại nên có:

| Mã | Xử lý |
|---|---|
| **4xx** (trừ 408, 429) | **Dừng thử lại.** Đẩy sang trạng thái "cần xử lý", hiện cho người dùng thấy |
| 408, 429, **5xx**, lỗi mạng | Thử lại có backoff |
| 200 kèm `created:false` | Đã tạo trước đó (trùng `client_uuid`) — coi là **thành công**, xoá khỏi hàng đợi |

---

## 8. Còn nợ

| # | Việc | Điều kiện đóng |
|---|---|---|
| 1 | §9.1 của `API-VIENG-THAM-MOBILE-2026-09-29.md` chưa nói rõ phạm vi của `client_boot_id`/`queued_seconds` | Bổ sung một câu: hai trường này chỉ dùng ở ba cửa DMS, cửa khác nhận được sẽ 422 |
| 2 | `POST /crm/customers` không dựng lại mốc bấm thật cho bản ghi ngoại tuyến | Mở `queued_seconds` + `client_boot_id` ở cửa này (cần migration thêm cột cho `crm_customer`) |
| 3 | Ba tài liệu cùng nói về cửa tạo điểm bán | Gộp còn một, do phiên đang giữ khối CRM quyết |
| 4 | Khối mã `POST /crm/customers` (9 file, +840 dòng) **sống trên prod từ 23/09 mà chưa vào git** | Phiên giữ khối đó commit |

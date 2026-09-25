# API điểm bán — bản rút gọn (22/09/2026)

Ba endpoint app cần: **lấy biểu mẫu** → **tải ảnh** → **tạo điểm bán**. Bản đầy đủ (mọi mã lỗi, mọi ca biên)
ở `API-BIEU-MAU-DIEM-BAN-2026-09-16.md` và `API-TAO-DIEM-BAN-2026-09-18.md`.

* Gốc: `https://api-app.vthmgroup.vn`
* Mọi lượt gọi: `Authorization: Bearer <token>` · `Content-Type: application/json`
* Envelope: `{"success": bool, "data": …, "message": "…"}`; lỗi nhập liệu trả **422** kèm
  `errors: {trường: [câu lỗi]}`

---

## 1. `GET /crm/customer-form/schema` — lấy biểu mẫu động

Quyền: `/crm/customer-form/schema`.

```json
{
  "form":    { "id": 1, "code": "crm_customer", "name": "Biểu mẫu điểm bán" },
  "version": "9f2c1ab3d5e6f708",
  "fields": [
    {
      "kind": "fixed",            // "fixed" = cột có sẵn của hồ sơ · "dynamic" = ô admin tự thêm
      "code": "name",             // KHOÁ để gửi lên ở bước tạo
      "label": "Tên điểm bán",
      "input_type": "text",
      "description": null,
      "required": true,
      "read_only": false,
      "source": "fixed",
      "legacy_key": null,
      "catalog": null,            // ô select nối bảng danh mục nào (để đồng bộ ngoại tuyến)
      "min_length": null, "max_length": 255, "min": null, "max": null,
      "options": [],              // [{value,label}] cho select/radio/checkbox
      "max_files": null           // CHỈ ô ảnh có số; mọi ô khác là null
    }
  ]
}
```

**Cần nhớ**

* `version` đổi khi cấu hình đổi → dùng để biết có phải vẽ lại biểu mẫu không.
* `input_type` hay gặp: `text` · `textarea` · `number` · `currency` · `boolean` · `date` · `select` ·
  `multiselect` · `radio` · `checkbox` · **`image`** · `file` · `heading` / `divider` / `note` (chỉ trình bày).
* Server **chỉ gửi ô dùng được**: ô hỏng tham chiếu, ô select có danh mục rỗng, ô admin đã ẩn đều bị loại —
  client không phải tự lọc.
* `code` và `status` **luôn `required: false`** — server tự điền (mã sinh tự động, trạng thái mặc định
  `active`). Gửi lên bị từ chối.
* `kind: "fixed"` → gửi ở **cấp cao nhất** của body; `kind: "dynamic"` → gửi trong khoá **`data`**.

---

## 2. `POST /crm/customer-photos` — tải ảnh lên

`multipart/form-data`, **một tệp** ở khoá **`file`**. Quyền dùng chung với lượt tạo
(`/crm/customer/create`) — không phải xin cấp thêm quyền thứ hai.

Trả **201**:

```json
{ "success": true,
  "data": {
    "token": "9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b",
    "name": "mat-tien.jpg", "ext": "jpg", "size": 248310, "mime": "image/jpeg",
    "url": "/crm/customer-photos/public/9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b"
  },
  "message": "Đã tải tệp lên." }
```

* **`token` là thứ gửi kèm biểu mẫu.** `url` chỉ để hiển thị lại ngay cho người dùng xem.
* **`url` là đường CÔNG KHAI vĩnh viễn** (chủ hệ thống chốt 21/09/2026): mở được bằng `<img src>` **không
  cần header Bearer**, ai có link là xem được, không thu hồi.
* Ảnh tải lên mang ngữ cảnh `crm_customer_photo`. Token của tệp thuộc ngữ cảnh khác (đính kèm phản hồi,
  tài liệu…) **bị từ chối** ở bước tạo, dù đúng dạng 32-hex.
* Mỗi lượt gọi **một ảnh**. Ô ảnh cho phép nhiều tấm thì gọi nhiều lượt, gom token lại.
* Ảnh đã tải mà không dùng sẽ bị cron dọn — hãy tạo điểm bán trong cùng phiên làm việc.

---

## 3. 🔴 Ô dạng ảnh: app mobile và server phối hợp thế nào

```
① GET /crm/customer-form/schema
   → gặp field { code:"anh_mat_tien", input_type:"image", max_files:3, required:true }

② App vẽ UI chụp/chọn ảnh, cho tối đa max_files tấm

③ Mỗi tấm: POST /crm/customer-photos  (multipart, khoá `file`)
   → nhận { token, url }
   → app hiện lại ảnh bằng `url` (không cần Bearer), GIỮ `token` trong bộ nhớ

④ Bấm Lưu: POST /crm/customers
   { "name": …, "region_id": …, "route_ids": [...],
     "data": { "anh_mat_tien": ["<token1>", "<token2>"] } }

⑤ Server kiểm từng token: có thật · chưa mất tệp · đuôi là ảnh · đúng ngữ cảnh
                            · số lượng ≤ max_files
   → đạt: ghi MẢNG TOKEN vào `data`
   → hỏng: 422 tại đúng mã ô, app cho chụp lại

⑥ Đọc lại hồ sơ (GET /crm/customers/{id}):
   data.anh_mat_tien  = ["<token1>", "<token2>"]        ← token, để gửi lại khi sửa
   dynamic_urls       = { "anh_mat_tien": ["/crm/customer-photos/public/<token1>", …] }
                                                        ← link, để hiển thị
```

**Bốn điều dễ làm sai**

1. **Gửi TOKEN, không gửi URL.** Server có nhận URL và tự tách token ra (để đỡ app đời cũ), nhưng URL là
   chuỗi do client tự ghép — đổi đường phục vụ là app cũ gửi sai. Token là thứ server vừa cấp.
2. **Giá trị lưu xuống LUÔN là MẢNG**, kể cả ô một ảnh (`max_files: 1`). Gửi chuỗi trần vẫn nhận, nhưng
   đọc ra luôn là mảng — đừng viết client giả định chuỗi.
3. **Đọc để hiển thị thì dùng `dynamic_urls`, đừng tự ghép đường dẫn.** Ô nào không có ảnh thì **vắng
   khoá** trong `dynamic_urls` (không phải mảng rỗng).
4. **`max_files` phải đọc từ schema trước khi cho chụp**, đừng để cứng. Cho chụp 5 tấm rồi nhận 422 lúc
   bấm Lưu là bắt người ngoài thị trường làm lại từ đầu.

**Ảnh chính của điểm bán** (cột cứng, khác ô động): cùng bước ② ③, nhưng token đặt ở **`photo_token`** cấp
cao nhất. Ảnh này phải **chưa gắn cho điểm bán nào** — gắn lại ảnh của hồ sơ khác bị từ chối. Đọc ra ở
khoá `photo_url`.

---

## 4. `POST /crm/customers` — tạo điểm bán

Quyền: `/crm/customer/create`.

```json
{
  "name": "Cửa hàng VLXD Minh Tâm",
  "region_id": 12,
  "route_ids": [5],
  "phone": "0912345678",
  "address": "12 Trần Phú, Hải Châu, Đà Nẵng",
  "lat": "16.0678", "lng": "108.2208",
  "photo_token": "9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b",
  "client_uuid": "0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0",
  "data": {
    "so_ke_hang": 4,
    "anh_mat_tien": ["9f2c1ab3d5e6f7089a0b1c2d3e4f5a6b"]
  }
}
```

**Bắt buộc**

| Trường | Vì sao |
|---|---|
| `name` | tên điểm bán |
| `region_id` | **mã điểm bán sinh từ khu vực** — 4 số khu vực + 4 số thứ tự (`08190163`) |
| `route_ids` | bắt buộc **với nhân viên thị trường**; quản trị thì không |
| ô động admin đánh dấu bắt buộc | ép ngay trong ngày admin bật cờ, app không phải đổi code |

**Trường hay dùng khác:** `customer_type_id` · `customer_group_id` · `channel_id` · `delivery_address` ·
`province_name` · `ward_name` · `contact_name` · `contact_title` · `email` · `birthday` (`Y-m-d`) ·
`geofence_radius_m` · `is_offline_sync`.

**Phản hồi 201**

```json
{ "success": true,
  "data": { "id": 8731, "code": "08190163", "created": true, "route_ids": [5] },
  "message": "Đã tạo điểm bán 08190163." }
```

**Cần nhớ**

* **`code` do server sinh** — client gửi lên là **lỗi 422**, không phải bị bỏ qua im lặng.
* **`route_ids` là MẢNG**, không phải một id: một điểm bán thuộc nhiều tuyến (đo prod: trung bình 9,81).
  Nhân viên chỉ gán được **tuyến của chính mình, đang bật** — lấy ở `GET /dms/routes/mine`.
  Quản trị gán được mọi tuyến đang bật — lấy ở `GET /dms/routes?is_active=1&q=…`.
* **`client_uuid` chống trùng khi gửi lại** (hàng đợi ngoại tuyến): cùng UUID trả **200** với
  `"created": false` và `route_ids: []` thay vì đẻ thêm hồ sơ.
* **Ô động đi trong `data`, không khai thành trường riêng** — admin thêm ô mới thì app chỉ cần đọc lại
  schema, hợp đồng endpoint không đổi.
* `lat`/`lng` phải đi **thành cặp**.
* Tài khoản **không có mã nhân viên** không tạo được (hồ sơ sẽ không có chủ) — trừ vai quản trị.

---

## 5. Bốn lỗi hay gặp

| Triệu chứng | Nguyên nhân |
|---|---|
| 422 `Region is required…` | thiếu `region_id` — không có nó thì không sinh được mã |
| 422 ở một khoá lạ | gửi ô động ở cấp cao nhất thay vì trong `data`, hoặc gửi `code` |
| 422 `Sales routes` | nhân viên gửi tuyến không phải của mình / tuyến đã tắt / thiếu `route_ids` |
| 422 `…: tệp này không tải lên cho biểu mẫu này` | token của tệp thuộc ngữ cảnh khác, hoặc không phải ảnh |

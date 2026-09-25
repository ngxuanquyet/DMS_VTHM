# Mobile: lấy biểu mẫu và tạo khách hàng kèm NHIỀU ảnh

Cho người viết app DMS (Flutter) và mọi client gọi REST. Hai việc trong một tài liệu:

1. **`GET /crm/customer-form/schema`** — lấy đặc tả để **vẽ màn nhập**, đừng hardcode danh sách ô.
2. **`POST /crm/customers` với `photo_tokens`** — tạo khách hàng kèm **nhiều ảnh** (mới từ 23/09/2026).

Mọi số liệu dưới đây **đo thật** ngày 23/09/2026 trên `app_test` bằng tài khoản người dùng thật, không phải
ví dụ bịa. Host thật: `https://api-app.vthmgroup.vn`. Mọi lượt gọi cần `Authorization: Bearer <token>`,
**trừ** đường xem ảnh công khai ở §5.

Tài liệu anh em: `API-TAO-DIEM-BAN-2026-09-18.md` (trọn bộ luật tạo, gồm tuyến bắt buộc và `client_uuid`) ·
`API-SUA-DIEM-BAN-2026-09-16.md` (sửa) · `API-BIEU-MAU-DIEM-BAN-2026-09-16.md` (biểu mẫu, bản gốc).

---

## 1. Lấy biểu mẫu: `GET /crm/customer-form/schema`

```bash
curl -H 'Authorization: Bearer <token>' \
     'https://api-app.vthmgroup.vn/crm/customer-form/schema'
```

```json
{ "success": true, "message": "Thành công",
  "data": {
    "form":    { "id": 2733, "code": "crm_customer", "name": "Hồ sơ điểm bán" },
    "version": "302e6a066fb1d890",
    "fields":  [ /* 25 ô, xem bên dưới */ ]
  } }
```

`version` là **vân tay của trọn danh sách ô**. App lưu lại; `version` đổi nghĩa là quản trị vừa sửa biểu mẫu
⇒ tải lại schema và dựng lại form. Không đổi thì dùng bản đã cache, khỏi gọi lại.

### 1.1. Mỗi ô có đúng những khoá này

```json
{
  "kind": "fixed",           // "fixed" = cột cứng, gửi ở GỐC body
                             // "dynamic" = ô động, gửi trong khoá `data`
  "code": "photo_file_id",   // mã ô — khoá để gửi giá trị lên
  "label": "Ảnh điểm bán",   // nhãn hiển thị, admin đổi được
  "input_type": "image",     // text | textarea | number | date | select | image
  "description": null,       // câu gợi ý dưới ô, có thể null
  "required": true,          // vẽ dấu sao VÀ chặn trước khi gửi
  "read_only": false,        // true ⇒ hiện nhưng khoá, đừng gửi lên
  "source": "fixed",         // fixed | mobiwork (ô di trú từ hệ cũ)
  "legacy_key": null,        // khoá gốc bên MobiWork, chỉ để đối chiếu
  "catalog": "region",       // ô select lấy lựa chọn từ bảng danh mục nào
  "min_length": null, "max_length": null,
  "min": null, "max": null,
  "options": [],             // lựa chọn cho select — xem 1.2
  "max_files": 10            // CHỈ ô ảnh: số tấm tối đa. null cho ô khác
}
```

🔴 **Đừng hardcode danh sách ô.** Quản trị bật/tắt, đổi nhãn, đổi cờ bắt buộc và thêm ô mới ngay trên web.
App vẽ theo `fields` thì mọi thay đổi đó tới nơi mà không phải phát hành bản mới.

🔴 **Ô `read_only` hoặc ô không có trong `fields` thì ĐỪNG gửi lên.** Server từ chối cả body vì một khoá lạ
(422, nêu đích danh tên khoá).

### 1.2. Ô `select`

`options` là `[{value, label, color}]`. **Gửi lên `value`**, đừng gửi `label`: đổi tên một dòng danh mục là
mọi hồ sơ hiện tên mới ngay, còn lưu label thì bản ghi cũ giữ tên cũ. `color` có thể `null`.

Đo 23/09/2026: `customer_type_id` 10 lựa chọn · `channel_id` 15 · `region_id` 63 · `status` 2 (`active` /
`inactive`) · ô động `mw_nhan_1` 6.

### 1.3. Danh sách ô hiện tại (25 ô — để hình dung, **không** để hardcode)

| kind | code | nhãn | type | bắt buộc |
|---|---|---|---|---|
| fixed | `code` | Mã khách hàng | text | — (read_only, server sinh) |
| fixed | `name` | Khách hàng | text | ✅ |
| fixed | `region_id` | Khu vực | select | ✅ |
| fixed | `photo_file_id` | Ảnh điểm bán | **image** | ✅ (`max_files: 10`) |
| fixed | `customer_type_id` · `channel_id` · `status` | Loại KH · Kênh · Trạng thái | select | — |
| fixed | `phone` · `email` · `contact_name` · `contact_title` | liên hệ | text | — |
| fixed | `birthday` | Ngày sinh nhật | date | — |
| fixed | `address` · `delivery_address` | địa chỉ | textarea | — |
| fixed | `province_name` · `ward_name` | Tỉnh/Thành · Xã/Phường | text | — |
| fixed | `lat` · `lng` | toạ độ | number | — |
| dynamic | `mw_ma_erp`, `mw_khach_hang_vthm`, `mw_nhan_1..3`, `mw_huyen`, `mw_hinh_anh` | ô di trú MobiWork | text/select | — |

⚠️ `lat`/`lng` đi **thành cặp**: gửi một cái mà thiếu cái kia ⇒ 422.

---

## 2. 🔴 Ảnh: tải lên TRƯỚC, gắn bằng token — nay là MỘT MẢNG

Ảnh **không** đi kèm trong lượt tạo. Lượt tạo là JSON có `client_uuid` để gửi lại được; nhét ảnh vào đó
nghĩa là mỗi lần gửi lại phải tải lại toàn bộ ảnh trên sóng 3G ngoài thị trường.

### Bước 1 — tải từng ảnh, nhận token

```bash
curl -X POST 'https://api-app.vthmgroup.vn/crm/customer-photos' \
  -H 'Authorization: Bearer <token>' \
  -F 'file=@bien-hieu.jpg'
```

```json
{ "success": true, "message": "Đã tải tệp lên",
  "data": { "token": "36e77600cfeb909696b905f5754e6f1e",
            "name": "bien-hieu.jpg", "ext": "png", "size": 74, "mime": "image/png",
            "url": "/crm/customer-photos/public/36e77600cfeb909696b905f5754e6f1e" } }
```

* Field multipart tên **`file`**. Chỉ ảnh: `jpg jpeg png gif webp bmp`. Gửi tệp khác ⇒
  `Đuôi tệp không hợp lệ: "x.txt".`
* Gọi **một lượt cho mỗi tấm**. Chụp 3 tấm thì 3 lượt, thu về 3 token.

### Bước 2 — tạo khách hàng, gửi **mảng token**

```bash
curl -X POST 'https://api-app.vthmgroup.vn/crm/customers' \
  -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' \
  -d '{
        "name": "Tạp hoá Cô Ba",
        "region_id": 39,
        "route_ids": [6825],
        "client_uuid": "e9f0e322-9920-4f6e-96bb-b1e72166f17a",
        "photo_tokens": [
          "4d6841b9e2645aab0c64f1877a4135b1",
          "2937ebd0d864a09b353405d9ba303d4a"
        ],
        "data": { "mw_ma_erp": "ERP-0001" }
      }'
```

```json
{ "success": true, "message": "Đã tạo điểm bán 08650170.",
  "data": { "id": 60383, "code": "08650170", "created": true, "route_ids": [6825] } }
```

**Thứ tự trong mảng là thứ tự hiển thị.** Phần tử **đầu tiên** trở thành **ảnh đại diện** — tấm hiện trên
lưới danh sách và ở khoá `photo_url`. Muốn đổi ảnh đại diện thì đảo thứ tự mảng, không có khoá riêng nào.

### Ba điều bắt buộc nhớ

1. **Trần số tấm lấy từ `max_files` của schema** (hiện 10), đừng ghi cứng trong app. Quản trị đổi được ở
   `/system/settings/crm`. Vượt trần ⇒ 422 `Mỗi điểm bán chỉ được gắn tối đa 10 ảnh.`
2. **Ảnh tải lên mà không gắn vào hồ sơ nào sẽ bị dọn rác xoá sau 1 ngày.** Giữ ảnh chờ qua đêm rồi mới gửi
   biểu mẫu là phải chụp lại.
3. **Một ảnh chỉ thuộc MỘT khách hàng.** Gửi lại token đã gắn cho hồ sơ khác ⇒ 422
   `Ảnh này đã gắn cho một điểm bán khác.` (ngoại lệ: lượt gửi lại cùng `client_uuid` — xem §6).

---

## 3. Sửa bộ ảnh: `PATCH /crm/customers/{id}`

```bash
# Đảo thứ tự + bớt còn 2 tấm (tấm không có trong mảng bị GỠ khỏi hồ sơ)
curl -X PATCH '.../crm/customers/60383' -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{"photo_tokens":["2937ebd0…","4d6841b9…"]}'
# → {"success":true,"message":"Đã cập nhật 1 trường.","data":{"changed":["photos"], …}}
```

🔴 **Ba ngữ nghĩa khác hẳn nhau, đừng trộn:**

| Body gửi lên | Server làm gì |
|---|---|
| **không có** khoá `photo_tokens` | **giữ nguyên** bộ ảnh hiện có |
| `"photo_tokens": ["a","b"]` | đặt lại trọn bộ = đúng hai tấm đó, đúng thứ tự đó |
| `"photo_tokens": []` | **xoá sạch** ảnh của hồ sơ |

Nghĩa là: một lượt PATCH chỉ đổi số điện thoại **tuyệt đối không** được kèm `"photo_tokens": []`, nếu không
nó xoá trắng ảnh của khách hàng. Chỉ gửi khoá này khi người dùng thực sự chạm vào ô ảnh.

`changed` trong phản hồi chứa `"photos"` khi bộ ảnh thực sự đổi; gửi lại y hệt danh sách cũ thì không.

---

## 4. Đọc ảnh về: `photo_urls` (mới) và `photo_url` (cũ)

Mọi endpoint trả hồ sơ điểm bán (`GET /crm/customers`, `/crm/customers/mine`, `/crm/customers/{id}`) nay có
**cả hai** khoá:

```json
{
  "photo_url":  "/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1",
  "photo_urls": [
    "/crm/customer-photos/public/4d6841b9e2645aab0c64f1877a4135b1",
    "/crm/customer-photos/public/2937ebd0d864a09b353405d9ba303d4a"
  ]
}
```

| Khoá | Nội dung | Tương lai |
|---|---|---|
| `photo_urls` | **trọn bộ**, theo thứ tự hiện; `[]` khi chưa có ảnh | dùng cái này |
| `photo_url` | **tấm đầu** của chính mảng trên; `null` khi chưa có ảnh | giữ tạm cho bản app cũ |

🔴 **Việc cần làm của bên mobile: chuyển sang `photo_urls`.** `photo_url` và cột DB `photo_file_id` đứng sau
nó sẽ bị **GỠ** ở bước 2 của đợt này — mốc gỡ phụ thuộc chính vào việc app mobile chuyển xong hay chưa (điều
kiện đóng ghi ở `docs/specs/crm/BO-ANH-NHIEU-TAM-DIEM-BAN-2026-09-23.md` §6). Trong lúc chưa gỡ, hai khoá
luôn khớp nhau, nên chuyển sớm không mất gì.

Ngoài ra, ô **động** kiểu `image` (nếu quản trị tạo thêm) đi ở cặp khoá riêng: `dynamic[<mã ô>]` giữ **token**,
`dynamic_urls[<mã ô>]` giữ **link** tương ứng cùng thứ tự.

---

## 5. Hiện ảnh lên màn hình

`GET /crm/customer-photos/public/{token}` — **không cần Bearer**, cache 30 ngày, trả `inline`. Nhét thẳng
vào `Image.network` / `<img src>` được.

🔴 **Đường dẫn trả về là TƯƠNG ĐỐI.** Phải ghép host của API vào:

```dart
final src = 'https://api-app.vthmgroup.vn' + photoUrls[i];
```

Không ghép thì ảnh vỡ **mà không có lỗi nào dễ thấy** — trên web đã xảy ra đúng ca này ngày 23/09/2026: trình
duyệt đi tìm ảnh ở origin của app, nhận về trang HTML với mã **200**, và ô ảnh chỉ hiện biểu tượng vỡ.

⚠️ Hàng rào duy nhất của đường công khai là **token 32-hex ngẫu nhiên** — ai có link là xem được, vĩnh viễn.
Đừng dán link ảnh khách hàng ra nơi công cộng. Đường có gác `GET /crm/customer-photos/{token}` (**đòi Bearer**)
vẫn chạy cho nơi gọi bằng HTTP client.

---

## 6. Ngoại tuyến và gửi lại

Giữ nguyên cơ chế cũ, không đổi gì vì bộ ảnh:

* Gửi kèm `client_uuid` (UUID app tự sinh, **một lần cho mỗi hồ sơ**, giữ nguyên qua mọi lần thử lại).
* Mạng đứt sau khi server đã tạo xong: lượt gửi lại cùng `client_uuid` trả **200** kèm `"created": false` và
  bản ghi cũ, **không** tạo trùng.
* Trong ca gửi lại đó, token ảnh đã gắn cho chính hồ sơ ấy **không** bị coi là "ảnh của điểm bán khác".

---

## 7. Lỗi hay gặp và câu chữ chính xác

| Tình huống | HTTP | Thông báo |
|---|---|---|
| Gửi quá `max_files` tấm | 422 | `Mỗi điểm bán chỉ được gắn tối đa 10 ảnh.` |
| Token không có trong kho | 422 | `Không tìm thấy ảnh vừa tải lên. Hãy tải ảnh lại.` |
| Token của module khác (đính kèm phản hồi, ảnh bài viết…) | 422 | `Tệp này không được tải lên làm ảnh điểm bán.` |
| Token đã gắn cho khách hàng khác | 422 | `Ảnh này đã gắn cho một điểm bán khác.` |
| Ô ảnh bắt buộc mà không gửi tấm nào | 422 | `Vui lòng chụp ảnh điểm bán trước khi lưu.` (neo ở `photo_token`) |
| Tải lên tệp không phải ảnh | 400 | `Đuôi tệp không hợp lệ: "x.txt".` |
| Gửi khoá không có trong biểu mẫu | 422 | `Trường {tên} không sửa được.` |

Lỗi validate trả ở `errors` dạng `{ "tên_trường": ["câu lỗi"] }` — app map vào đúng ô để tô đỏ.

---

## 8. Tương thích ngược

Đường cũ **vẫn chạy**, app chưa kịp cập nhật không gãy:

* `photo_token` (một chuỗi) — vẫn nhận. Gửi **cả** `photo_token` lẫn `photo_tokens` thì `photo_tokens` thắng.
* `photo_file_id` (id tệp, đường quản trị/di trú) — vẫn nhận, qua đúng các phép kiểm như token.
* Cả hai đường trên đều chỉ gắn được **một** tấm. Muốn nhiều ảnh thì bắt buộc dùng `photo_tokens`.
* Server nhận cả **token trần** lẫn nguyên chuỗi `url` mà bước tải lên trả về — tự tách token. Nhưng thứ ghi
  xuống DB luôn là **token**: app đừng tự lưu URL rồi gửi lại URL vào khoá khác, vì bộ quét tệp-còn-dùng tìm
  token dưới dạng trọn một chuỗi JSON, URL bọc quanh token thì nó không thấy và cron xoá ảnh sau 1 ngày.

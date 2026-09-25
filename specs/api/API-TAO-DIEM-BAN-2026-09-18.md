# API tạo điểm bán — `POST /crm/customers`

Cho người viết app DMS (Flutter) và người gọi API ngoài. Đo thật ngày 18/09/2026 trên `app_test` bằng hai
tài khoản người dùng thật (một quản trị CRM, một nhân viên thị trường).

Cặp đôi của tài liệu này: `API-BIEU-MAU-DIEM-BAN-2026-09-16.md` (biểu mẫu để vẽ màn nhập) và
`API-SUA-DIEM-BAN-2026-09-16.md` (sửa sau khi tạo).

## Gọi

```bash
curl -X POST 'https://api-app.vthmgroup.vn/crm/customers' \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{
        "name": "Tạp hoá Cô Ba",
        "region_id": 3,
        "phone": "0912345678",
        "address": "12 Ngõ Thử",
        "lat": "21.03", "lng": "105.85",
        "client_uuid": "e9f0e322-9920-4f6e-96bb-b1e72166f17a",
        "route_ids": [6825, 6826],
        "photo_token": "e80101aceab75250272284d2fb48d705",
        "data": { "mw_ma_erp": "ERP-0001" }
      }'
```

```json
{ "success": true, "message": "Đã tạo điểm bán 08290611.",
  "data": { "id": 28359, "code": "08290611", "created": true, "route_ids": [6825, 6826] } }
```

HTTP **201** khi tạo mới, **200** khi đó là lượt gửi lại (xem `client_uuid`).

## 🔴 Tuyến: BẮT BUỘC với nhân viên thị trường (từ 21/09/2026)

`route_ids` là danh sách id tuyến mà điểm bán mới sẽ nằm trong đó.

* **Nhân viên thị trường phải gửi ít nhất một tuyến** — thiếu thì 422 `route_ids`. Điểm bán không nằm
  trong tuyến nào là điểm bán không ai đi qua: nó không lên lịch đi tuyến của app, và cũng không vào
  "khách của tôi" theo tuyến.
* **Quản trị** (giữ `/crm/customer/index`) **không bị bắt** và không bị giới hạn chủ tuyến — họ mở hộ rồi
  giao lại sau.
* Chỉ nhận tuyến **của chính người gọi** và **đang hoạt động**; sai thì 422 nêu đích danh id bị từ chối.
  Lấy danh sách hợp lệ ở `GET /dms/routes/mine` (trả `[{id, code, name, visit_day_of_week, sale_group_id}]`).
* Lưu ở bảng NỐI `dms_route_stop`, **không** phải một cột trên hồ sơ khách: một điểm bán thường thuộc
  nhiều tuyến (đo prod 21/09/2026: 87,6% thuộc ≥2 tuyến, trung bình 9,81). Dòng do One tạo mang
  `legacy_source = NULL` nên **lượt đồng bộ MobiWork không xoá mất nó** (đã đo).
* `sort_order` để trống = **chưa xếp thứ tự** trong tuyến; người phụ trách tuyến xếp lại sau.

## 🔴 Ảnh điểm bán: tải lên TRƯỚC, gắn bằng token

> **Cập nhật 23/09/2026 — MỘT điểm bán mang NHIỀU ảnh.** Đường chính nay là `photo_tokens` (mảng token,
> tối đa `max_files` của schema, mặc định 10); `photo_token` bên dưới chỉ còn cho app đời cũ và chỉ gắn
> được MỘT tấm. Hướng dẫn đầy đủ cho mobile: `API-MOBILE-TAO-KHACH-HANG-NHIEU-ANH-2026-09-23.md`.

Hai bước, cố ý không nhét ảnh vào chính lượt tạo (lượt tạo là JSON + có `client_uuid` để gửi lại; gộp ảnh
vào nghĩa là mỗi lần gửi lại phải tải lại cả ảnh trên sóng 3G ngoài thị trường).

```bash
# Bước 1 — tải ảnh lên (multipart, field tên `file`, CHỈ ảnh: jpg/jpeg/png/gif/webp/bmp)
curl -X POST 'https://api-app.vthmgroup.vn/crm/customer-photos' \
  -H 'Authorization: Bearer <token>' -F 'file=@bien-hieu.jpg'
# → 201 {"data":{"token":"e801…d705","name":"bien-hieu.jpg","ext":"jpg","size":184320,
#         "mime":"image/jpeg","url":"/crm/customer-photos/public/e801…d705"}}

# Bước 2 — gửi MẢNG `photo_tokens` kèm biểu mẫu tạo (hoặc PATCH khi đổi ảnh sau này).
#          Thứ tự trong mảng = thứ tự hiện; phần tử ĐẦU là ảnh đại diện (`photo_url`).
#          Nhận CẢ token trần lẫn nguyên chuỗi `url` ở trên — server tự tách token.
#   "photo_tokens": ["e801…d705", "2937…3d4a"]
#   (`photo_token` một chuỗi vẫn nhận, nhưng chỉ gắn được MỘT tấm)
```

### Xem ảnh: link CÔNG KHAI, nhét thẳng vào `<img src>`

Từ 21/09/2026 (chủ hệ thống chốt) ảnh điểm bán phục vụ **không cần đăng nhập**:

* `GET /crm/customer-photos/public/{token}` — **không Bearer**, cache 30 ngày, trả `inline` để hiện trong
  thẻ ảnh. Đây chính là chuỗi mà bước tải lên trả ở `url` và các endpoint đọc trả ở `photo_url`.
* Hàng rào duy nhất là **token 32-hex ngẫu nhiên** — cùng mô hình avatar/logo công ty đang chạy. Nghĩa là:
  **ai có link là xem được, vĩnh viễn**. Đừng dán link ảnh điểm bán vào nơi công cộng.
* Vẫn chỉ phục vụ tệp có `context = crm_customer_photo`; mọi lý do từ chối (không có, sai ngữ cảnh, mất
  tệp vật lý) đều trả **404** giống hệt nhau.
* Đường cũ `GET /crm/customer-photos/{token}` (**đòi Bearer**) vẫn chạy, dành cho nơi gọi bằng HTTP client.

### Ảnh trả về ở chiều ĐỌC

| Khoá | Ở đâu | Nội dung |
|---|---|---|
| `photo_urls` | mỗi dòng của `GET /crm/customers`, `/mine`, `/{id}` | **TRỌN BỘ** ảnh theo thứ tự hiện; `[]` khi chưa có |
| `photo_url` | cùng chỗ | tấm ĐẦU của `photo_urls`, `null` khi chưa có. 🔴 **Sẽ bị gỡ ở bước 2** — chuyển sang `photo_urls` |
| `dynamic[<mã ô>]` | cùng chỗ | **TOKEN** của ô động kiểu `image` (mảng) — đây là thứ nằm trong DB |
| `dynamic_urls[<mã ô>]` | cùng chỗ | **LINK** tương ứng, cùng thứ tự; `{}` khi biểu mẫu không có ô ảnh |

🔴 **Lưu TOKEN, không lưu URL.** Gửi lên thì tuỳ (server nhận cả hai), nhưng thứ ghi xuống `data` luôn là
token. Nếu app tự ghép URL rồi gửi lại URL đó vào một khoá khác, ảnh sẽ **bị cron dọn rác xoá sau 1 ngày**:
bộ quét tệp-còn-dùng tìm token dưới dạng trọn một chuỗi JSON, URL bọc quanh token thì nó không thấy.

### Những điều khác giữ nguyên

* Một ảnh chỉ gắn cho **một** điểm bán; gửi lại token đã dùng ⇒ 422 (trừ lượt gửi lại cùng `client_uuid`).
  Từ 23/09/2026 phép kiểm này dò **cả** bảng nối `crm_customer_photo`, nên tấm ở vị trí thứ hai trở đi của
  hồ sơ khác cũng không mượn được.
* Token của tệp module khác (đính kèm phản hồi, ảnh bài viết…) ⇒ 422: kho `sys_file` dùng chung nên ảnh
  điểm bán được cách ly bằng `context = crm_customer_photo`.
* ⚠️ **Ảnh tải lên mà không gắn vào hồ sơ nào sẽ bị dọn rác sau 1 ngày.** App giữ ảnh chờ quá lâu rồi mới
  gửi biểu mẫu thì phải tải lại ảnh.
* `photo_file_id` (id tệp) vẫn nhận được cho đường quản trị/di trú, nhưng cũng bị kiểm đúng ba điều kiện
  như token. Gửi cả hai thì **token thắng**.
* Ô động kiểu `image`: schema trả `max_files` (mặc định 1) — app phải chặn trước khi chụp, server từ chối
  lượt vượt trần bằng 422. Ô ảnh **cột cứng** `photo_file_id` cũng có `max_files`, lấy từ tham số
  `crm.customer_max_photos` (mặc định **10**), chỉnh ở `/system/settings/crm`.

## 🔴 Hợp đồng KHÔNG đổi khi trường động đổi

Cột **cứng** gửi ở gốc body. **Mọi ô động gửi trong đúng một khoá `data`**, dạng `{mã ô: giá trị}` — mã ô
lấy từ `GET /crm/customer-form/schema`. Hệ quả:

* admin thêm / bớt / đổi thứ tự ô ở `/crm/customer-fields` ⇒ **endpoint này không đổi một dòng nào**, app
  chỉ cần đọc lại `schema` để vẽ;
* admin đánh dấu một ô là **bắt buộc** ⇒ lượt POST thiếu ô đó bị từ chối **ngay hôm ấy**, không cần ai sửa
  code. Đây là chủ đích, không phải tác dụng phụ: "bắt buộc" mà không chặn được thì chỉ là một dòng chữ.
* giá trị ô động về đâu là việc của server: ô admin tự tạo vào `crm_customer.data`, ô **nhận từ MobiWork**
  vào `custom_labels[<khoá gốc>]`. Client không cần biết, cứ gửi theo mã ô.

## Mã điểm bán — server sinh, client không gửi

**4 số khu vực + 4 số thứ tự**: khu vực Hải Phòng `0815` + điểm bán thứ 337 ⇒ `08150337`.

* `region_id` **bắt buộc** — không phải vì nghiệp vụ đòi mà vì 4 số đầu lấy từ `crm_region.code`.
* Số thứ tự là `MAX + 1` trong **dải thường** (`< 3000`) của chính khu vực đó. Hai dải `3000–5999` và
  `6000–8999` là hai lô nhập ngày 30/12/2024 chưa ai giải thích được ý nghĩa (spec 12/09 §6.3) — server
  **không** lấn sang; cạn dải thì trả lỗi đòi chốt dải mới chứ không tự tràn.
* Gửi `code` lên ⇒ **422**. Cần đặt mã riêng cho một ca bàn giao dữ liệu thì tạo xong rồi
  `PATCH /crm/customers/{id}` (đường sửa mở `code`).
* Hai lượt tạo cùng lúc trong một khu vực không đụng mã nhau: việc sinh mã chạy dưới
  `pg_advisory_xact_lock` theo prefix khu vực, trong cùng transaction với lượt ghi.

## Ô gửi được

| Nhóm | Ô |
|---|---|
| Bắt buộc | `name` · `region_id` |
| Thông tin | `address` · `delivery_address` · `province_name` · `ward_name` · `contact_name` · `contact_title` · `phone` · `email` · `birthday` |
| Vị trí | `lat` · `lng` (đủ cặp hoặc không gửi cả hai) · `geofence_radius_m` (10–5000) |
| Phân loại | `customer_type_id` · `customer_group_id` · `channel_id` · `status` (`active` mặc định) |
| Tuyến | `route_ids` (bắt buộc với nhân viên thị trường — xem mục riêng ở trên) |
| Ảnh | `photo_tokens` (mảng, **khuyến nghị**) · `photo_token` (một tấm, app đời cũ) · `photo_file_id` (quản trị/di trú) |
| Khác | `client_uuid` · `is_offline_sync` · `data` (ô động) |

**Không nhận** (gửi lên là 422, nói rõ lý do): `code` · `approval_status` · `created_by_code` ·
`created_by_name` · `mobiwork_id` · `legacy_source` · `legacy_key` · `custom_labels` · `id` ·
`created_at` · `updated_at` · `deleted_at`. Ô nào sửa được **sau khi tạo** thì xem tài liệu sửa điểm bán.

* `approval_status` luôn là `approved`: **bản MVP tạo điểm bán không cần duyệt** (chủ hệ thống chốt
  18/09/2026). Ngày có người duyệt (Đ5) thì mở cột này ở server, không phải để client tự khai.
* `created_by_code` do server đặt bằng mã NV của người gọi — đó là thứ quyết định "điểm bán của ai".

## `client_uuid` — gửi lại không đẻ thêm bản ghi

App ngoại tuyến gửi lại khi mạng chập là chuyện thường. Gửi lại **đúng** `client_uuid` đã dùng thì server
trả về bản ghi cũ:

```json
{ "success": true, "message": "Điểm bán này đã được tạo trước đó (trùng client_uuid).",
  "data": { "id": 28359, "code": "08290611", "created": false } }
```

HTTP **200**, `created = false`, và **không** sửa gì trên bản ghi cũ (tên khác trong lượt gửi lại bị bỏ
qua — đây là "đã có rồi", không phải một lượt sửa). App nên sinh `client_uuid` một lần lúc người dùng bấm
Lưu và giữ nguyên qua mọi lần thử lại.

## Ai gọi được

| Vai | Số người (prod 18/09) | Được gì |
|---|---:|---|
| `crm_customer_admin` | 1 | tạo điểm bán ở mọi khu vực |
| `crm_customer_self` | 95 | tạo điểm bán; bản ghi tự mang tên họ ở `created_by_code` |

🔴 **Tài khoản không có mã nhân viên thì không tạo được** (trừ người giữ `/crm/customer/index`). Lý do:
`created_by_code` là thứ duy nhất nối điểm bán mới với người mở nó — để trống thì họ tạo xong là **mất**
hồ sơ: nó không có trong `GET /crm/customers/mine` và chính họ nhận 403 khi sửa. Quản trị thì không bị
chặn: họ mở hộ rồi phân công, và họ thấy trọn danh mục.

Permission: `/crm/customer/create`. **Không có lớp phạm vi bản ghi ở bước tạo** — chưa có bản ghi thì
không có gì để hỏi "của ai". Người tạo trở thành chủ, nên hồ sơ vừa mở rơi đúng vào phạm vi mà họ được
sửa tiếp qua `PATCH` (đo thật 18/09: nhân viên thị trường tạo → sửa hồ sơ của mình 200, sửa hồ sơ người
khác 403).

## Mã lỗi

| Mã | Khi nào | Ví dụ thông báo |
|---|---|---|
| 201 | tạo mới xong | `Đã tạo điểm bán 08290611.` |
| 200 | lượt gửi lại cùng `client_uuid` | `Điểm bán này đã được tạo trước đó (trùng client_uuid).` |
| 422 | thiếu / sai ô cứng, gửi ô không nhận | `Phải chọn khu vực: mã điểm bán sinh từ mã khu vực.` · `Trường code không đặt được khi tạo điểm bán.` · `Biểu mẫu điểm bán không có trường nào tên phonee.` |
| 400 | ô động sai, nửa cặp toạ độ, cạn dải mã | `Ô <tên> là bắt buộc, không được để trống.` · `Vĩ độ và kinh độ phải điền cùng nhau.` |
| 400 | tài khoản chưa gắn mã nhân viên | `Tài khoản của bạn chưa gắn mã nhân viên nên điểm bán tạo ra sẽ không thuộc về ai…` |
| 403 | không giữ `/crm/customer/create` | `Bạn không có quyền thực hiện thao tác này.` |

Lỗi ràng buộc DB **không phải** trùng mã (ví dụ CHECK bán kính geofence) nổi lên đúng bản chất, **không**
bị dịch thành "mã vừa bị chiếm" — bấm thử lại chỉ tiêu số thứ tự trong dải mã mà không giải quyết gì.

⚠️ **Lỗi ô CỨNG trả 422 kèm `errors` theo từng ô; lỗi ô ĐỘNG trả 400 với một câu gộp.** Khác nhau vì luật
của ô động nằm trong cấu hình chứ không trong form: app nên hiện `message` cho nhóm 400 thay vì cố gắn
lỗi vào đúng ô.

## Cấu hình biểu mẫu không được phép làm gì

Ô **Khu vực** (`region_id`) **không ẩn được và không bỏ được cờ bắt buộc** ở `/crm/customer-fields` — cả
`{"hidden":true}` lẫn `{"required":false}` đều trả 400. Hai thứ đó đều dựng nên một bức tường vô hình: ẩn ô
thì schema thôi gửi ⇒ app không vẽ; bỏ cờ bắt buộc thì app vẽ nhưng không đánh dấu và không chặn phía
client — cả hai đường đều dẫn tới lượt POST thiếu `region_id`, nhận 422, ngay sau khi màn hình nói là không
sao.

## Còn nợ

* 🔴 **Ai cũng sửa được `created_by_code` qua `PATCH /crm/customers/{id}` — tức là tự nhận chủ sở hữu điểm
  bán.** Đường sửa mở **mọi** cột (chủ hệ thống chốt 16/09/2026 để API thay MobiWork sau cutover), và
  `created_by_code` lại chính là thứ quyết định "điểm bán của ai". Một nhân viên chỉ đang có điểm bán trên
  **tuyến** của mình có thể gán nó sang tên mình vĩnh viễn, kể cả sau khi rời tuyến. Siết lại là **đảo một
  quyết định của chủ hệ thống** nên không tự làm; chờ chủ hệ thống quyết. Điều kiện đóng: hoặc bỏ
  `created_by_code` khỏi `CustomerUpdateForm::COLUMNS` + `CustomerService::WRITABLE`, hoặc mở một đường
  **phân công** tường minh (`crm_customer_assignment` hiện KHÔNG có API nào) và để `created_by_code` lại
  đúng nghĩa "ai đã mở".
* **Điểm bán do quản trị KHÔNG có mã nhân viên tạo ra sẽ không thuộc về ai** — 1 trong 2 super admin trên
  prod đang ở diện này. Hồ sơ vẫn dùng được (quản trị thấy trọn danh mục) nhưng không nhân viên nào thấy
  trong `mine`; cách giao lại hiện nay là `PATCH` đặt `created_by_code`, đi qua đúng lỗ hổng nêu trên.
* **Chống trùng khi mở điểm bán (Đ6 của spec 12/09) CHƯA làm.** Tạo hai điểm bán cùng tên, cùng số điện
  thoại, cách nhau 5 m đều được. Cảnh báo (không chặn) khi trùng SĐT hoặc có điểm bán khác trong bán kính
  50 m là đề xuất đang chờ chủ hệ thống duyệt.
* **Không có bước duyệt** (Đ5) — xem mục `approval_status` ở trên.

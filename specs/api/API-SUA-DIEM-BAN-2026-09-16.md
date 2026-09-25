# API sửa điểm bán — `PATCH /crm/customers/{id}`

Cho người viết app DMS (Flutter) và người gọi API ngoài. Đo thật trên prod ngày 16/09/2026.

## Gọi

```bash
curl -X PATCH 'https://api-app.vthmgroup.vn/crm/customers/2351' \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{"contact_name":"Anh Ba","phone":"0912345678"}'
```

Mở mới một điểm bán thì dùng `POST /crm/customers` — xem `API-TAO-DIEM-BAN-2026-09-18.md`.

`PUT` cũng được, cùng hành vi. Chỉ gửi **những ô muốn đổi** — ô không gửi giữ nguyên giá trị cũ
(`{"phone":null}` là *xoá số điện thoại*, còn *không gửi khoá* `phone` là *đừng đụng vào*).

## Ai sửa được gì

| Người gọi | Sửa được |
|---|---|
| vai `crm_customer_self` (95 nhân viên thị trường) | **chỉ điểm bán của mình** — mình phụ trách, mình tự tạo, hoặc nằm trong **tuyến đang hoạt động** của mình |
| vai `crm_customer_admin` | mọi điểm bán trong danh mục |

Ba vế "của mình" đúng bằng tập mà `GET /crm/customers/mine` trả về — nhìn thấy thì sửa được, không thấy
thì không. Sửa điểm bán của người khác → **403** `FORBIDDEN`, DB không đổi.

Tuyến bị **khoá** (`is_active = false`) không còn cho quyền sửa, trừ khi điểm bán đó còn thuộc về nhân viên
qua phân công hoặc do chính họ tạo.

## Ô sửa được

Thông tin: `name` · `address` · `delivery_address` · `province_name` · `ward_name` · `contact_name` ·
`contact_title` · `phone` · `email` · `birthday`
Vị trí: `lat` · `lng` · `geofence_radius_m`
Phân loại: `customer_type_id` · `customer_group_id` · `channel_id` · `region_id` · `status`
Ảnh: **`photo_tokens`** (mảng token — đường chính từ 23/09/2026, một điểm bán mang nhiều ảnh) ·
`photo_token` (một token, app đời cũ) · `photo_file_id` (id tệp, đường quản trị/di trú). Gửi nhiều đường
cùng lúc thì **`photo_tokens` thắng**, sau đó tới `photo_token`. Từ 21/09/2026 mọi đường đều bị kiểm: tệp
phải có thật, phải mang `context = crm_customer_photo`, và **chưa gắn cho điểm bán khác** (gửi lại đúng ảnh
hồ sơ đang dùng thì không sao).

🔴 **Ba ngữ nghĩa của `photo_tokens` trong một lượt PATCH:** không gửi khoá = **giữ nguyên** bộ ảnh · gửi
mảng có phần tử = **đặt lại trọn bộ** đúng thứ tự đó (tấm đầu là ảnh đại diện) · gửi `[]` = **xoá sạch**.
Lượt PATCH chỉ đổi một ô khác tuyệt đối không được kèm `"photo_tokens": []`. `photo_file_id: null` cũng
vẫn là **gỡ ảnh**. Bộ ảnh đổi thì `changed` có mục `photos`.

🔴 **`photo_token` nhận CẢ nguyên chuỗi `url`** mà bước tải ảnh trả về (21/09/2026) — server tự tách token,
và thứ ghi xuống DB luôn là token. Chiều ĐỌC trả `photo_url` là **link công khai**
(`/crm/customer-photos/public/<token>`, không cần Bearer, nhét thẳng `<img src>` được — nhớ ghép host API
vào vì đường dẫn là TƯƠNG ĐỐI), và **`photo_urls`** là trọn bộ ảnh theo thứ tự; ô động kiểu `image`
trả token ở `dynamic` và link ở `dynamic_urls`. Chi tiết ở `API-TAO-DIEM-BAN-2026-09-18.md` và
`API-MOBILE-TAO-KHACH-HANG-NHIEU-ANH-2026-09-23.md`.

Khác: `data` (ô động) · `custom_labels`
Dấu vết nguồn: `code` · `approval_status` · `mobiwork_id` · `created_by_code` · `client_uuid` ·
`legacy_source` · `legacy_key` · `is_offline_sync` · `created_by_name` · `updated_by_name`

Khoá chính + mốc thời gian: `id` · `created_at` · `updated_at` · `deleted_at`

> **Không còn cột cấm nào** — API này được xây để **thay** MobiWork sau khi ngắt, không chạy song song,
> nên hệ nhận bàn giao phải ghi lại được mốc gốc và khôi phục được bản ghi đã xoá.
>
> - `PATCH {"deleted_at": null}` = **khôi phục** bản ghi đã xoá mềm. Chiều ngược lại (đặt mốc) = xoá mềm.
> - `created_at` / `updated_at` nhận `2026-09-16 10:30:00` hoặc ISO `2026-09-16T10:30:00+07:00`. Gửi
>   tường minh thì mốc của bạn được giữ; **không gửi** thì `updated_at` tự về giờ hiện tại như thường lệ.
> - `id` đổi được, nhưng chỉ khi bản ghi **chưa có dòng con** (phân công, điểm dừng tuyến, lượt ghé) —
>   khoá ngoại không CASCADE. Còn dòng con → **400** "Không đổi được: còn bản ghi khác đang trỏ tới…".
> - ⚠️ `code` cũng sửa được. Mã đã in trên chứng từ và là khoá dò của `dms_visit.legacy_customer_code` —
>   đổi mã không cập nhật những lượt ghé cũ đang trỏ mã đó.

**Khoá lạ** (gõ sai tên ô) → **422** nêu đích danh khoá đó, không im lặng bỏ qua.

## Phản hồi

```json
{ "success": true, "message": "Đã cập nhật 1 trường.",
  "data": { "id": 2351, "changed": ["contact_name"], "overwritten_on_next_sync": ["contact_name"] } }
```

- `changed` — ô **thực sự** đổi. Gửi đúng giá trị cũ ⇒ mảng rỗng, message `Không có gì thay đổi.`
- 🔴 `overwritten_on_next_sync` — ô sẽ **bị lượt đồng bộ MobiWork kế tiếp ghi đè**. Chừng nào còn kéo dữ
  liệu từ MobiWork, 31/37 cột không bền. Chỉ `data`, `geofence_radius_m`, `photo_file_id` và bộ ảnh
  (`photos`) là One làm chủ.
  App nên hiện cảnh báo này cho nhân viên, đừng để họ tưởng đã lưu vĩnh viễn.

## Mã lỗi

| Mã | Nghĩa |
|---|---|
| 200 | đã ghi (xem `changed` để biết ô nào) |
| 400 | DB từ chối — hiện chỉ một ca: đổi `id` khi còn dòng con trỏ tới |
| 403 | không có quyền, **hoặc** điểm bán không thuộc về bạn |
| 404 | không có điểm bán với id đó |
| 422 | dữ liệu sai hoặc khoá lạ — xem `errors` (`{"lat":["Vĩ độ không được lớn hơn 90."]}`) |

Ví dụ đã đo: `{"lat":91}` → 422 · `{"email":"sai-dinh-dang"}` → 422 · `{"khong_ton_tai":"x"}` → 422
"Trường khong_ton_tai không sửa được" · `{"created_at":"khong-phai-ngay"}` → 422 · `{"id":0}` → 422 ·
`{"id":999999}` trên bản ghi còn điểm dừng tuyến → 400.

## Lấy danh sách để sửa

```bash
curl 'https://api-app.vthmgroup.vn/crm/customers/mine?source=all&per-page=50' -H 'Authorization: Bearer <token>'
```

`source` = `own` (phụ trách + tự tạo) · `route` (trong tuyến) · `all` (mặc định, gộp — **mỗi điểm bán đúng
một dòng** dù nằm ở nhiều tuyến). Mỗi dòng có `is_owned`, `in_route`, `routes[]` để app biết khách đó đến
từ đâu. Nhãn cột của ô động nằm ở `meta.dynamicColumns` của cùng phản hồi — **đừng gọi `/crm/customers/meta`
rồi tự ghép**, admin đổi cấu hình giữa hai lượt gọi là app ghép nhãn cũ vào dữ liệu mới.

## Chưa có

**Tạo điểm bán mới** — `POST /crm/customers` chưa tồn tại. Nhân viên chưa mở được điểm bán từ app; luồng đó
đang vướng luật sinh mã điểm bán (xem `SPEC-CRM-CUSTOMER-TRUONG-DONG-2026-09-12.md` mục Đ4).

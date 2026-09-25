# API biểu mẫu điểm bán — `GET /crm/customer-form/schema`

Cho người viết app DMS (Flutter): **một lượt gọi, vẽ được trọn màn nhập/sửa điểm bán**. Đo thật ngày
16/09/2026 trên `app_test`.

> **Đã bổ sung sau ngày viết — mỗi ô nay còn hai khoá nữa:**
> * `catalog` — ô `select` lấy lựa chọn từ bảng danh mục nào (`customer_type` · `channel` · `region` …),
>   `null` cho ô lựa chọn tĩnh. Dùng để đồng bộ/đối chiếu ngoại tuyến.
> * `max_files` — **chỉ ô `input_type: image`**: số tấm tối đa. Ô ảnh cột cứng `photo_file_id` hiện trả
>   **10** (lấy từ tham số `crm.customer_max_photos`), ô ảnh động mặc định 1. `null` cho mọi ô khác.
>
> Bản đo lại 23/09/2026: biểu mẫu có **25 ô**, `photo_file_id` là `image` + `required: true` + `max_files: 10`.
> Cách dùng schema để vẽ form và gửi nhiều ảnh: `API-MOBILE-TAO-KHACH-HANG-NHIEU-ANH-2026-09-23.md`.

## Gọi

```bash
curl 'https://api-app.vthmgroup.vn/crm/customer-form/schema' \
  -H 'Authorization: Bearer <token>'
```

Không có tham số nào. Quyền: `/crm/customer-form/schema` — đã gán cho `crm_customer_admin` và
`crm_customer_self` (95 nhân viên thị trường). Endpoint chỉ trả **định nghĩa biểu mẫu**, không một dòng dữ
liệu điểm bán nào.

## Phản hồi

```json
{ "success": true, "data": {
  "form": { "id": 42, "code": "crm_customer", "name": "Điểm bán" },
  "version": "cbf83b74f5eb503d",
  "fields": [
    { "kind": "fixed", "code": "name", "label": "Khách hàng", "input_type": "text",
      "required": true, "read_only": false, "source": "fixed", "legacy_key": null,
      "description": null, "min_length": null, "max_length": null, "min": null, "max": null,
      "options": [] },
    { "kind": "fixed", "code": "customer_type_id", "label": "Loại khách hàng", "input_type": "select",
      "required": false, "read_only": false, "source": "fixed", "legacy_key": null,
      "options": [ { "value": 3, "label": "Nhà phân phối", "color": "primary" } ] },
    { "kind": "dynamic", "code": "mw_ma_erp", "label": "Mã ERP", "input_type": "text",
      "required": false, "read_only": true, "source": "mobiwork", "legacy_key": "ma_erp",
      "options": [] }
  ] } }
```

**`fields` đã theo đúng thứ tự cần vẽ, trên xuống dưới** — admin kéo thả ở `/crm/customer-fields`, app cứ
lặp qua mảng. Không phải sắp lại gì. Đo 16/09 trên `app_test`: **25 ô**.

| Khoá | Ý nghĩa |
|---|---|
| `kind` | `fixed` = cột thật của hồ sơ điểm bán · `dynamic` = ô admin thêm hoặc nhận từ MobiWork |
| `code` | tên ô khi **ghi**: `fixed` → gửi thẳng ở gốc body `PATCH`; `dynamic` → gửi trong `data` |
| `input_type` | `text` `textarea` `number` `currency` `boolean` `date` `select` `multiselect` `radio` `checkbox` `file` — **server chỉ cho admin chọn loại app vẽ được**, không có loại lạ |
| `required` | với cột cứng là ràng buộc `NOT NULL` thật của DB, không phải ý muốn người thiết kế |
| `read_only` | **gợi ý trình bày**: đừng vẽ ô nhập. Không phải hàng rào — xem mục dưới |
| `source` | `fixed` · `own` (admin tự tạo) · `mobiwork` (nhận từ hệ cũ, luôn chỉ đọc) |
| `options` | lựa chọn, **gửi sẵn** — không phải gọi thêm endpoint danh mục nào |
| `catalog` | ô này lấy lựa chọn từ bảng danh mục nào (`null` nếu không) — để app đồng bộ/đối chiếu ngoại tuyến. **Thêm 17/09/2026** |
| `version` | vân tay của chính nội dung `fields` |

### `version` — để app biết có phải vẽ lại không

Lưu lại, lần sau so. Khác thì vẽ lại, giống thì dùng bản đã lưu. Hash **nội dung**, không lấy `updated_at`
của biểu mẫu: đổi tên một kênh bán ở bảng `crm_channel` cũng làm biểu mẫu khác đi, mà bảng biểu mẫu không
hề bị chạm.

### `options` của cột cứng

`customer_type_id` · `customer_group_id` · `channel_id` · `region_id` đọc từ bốn bảng danh mục, **chỉ dòng
đang hoạt động**, sắp theo thứ tự admin đặt; `value` là **số** (id). `status` là danh sách đóng
(`active` / `inactive`), `value` là **chuỗi**. Ô động thì `value` là chuỗi do admin khai.

🔴 **Ô lựa chọn KHÔNG có lựa chọn nào thì không xuống app.** Ca thật: `crm_customer_group` đang rỗng ở cả
prod, nên "Nhóm khách hàng" vắng mặt trong `fields` — nếu gửi, nhân viên sẽ bấm ra một danh sách trắng.
Màn cấu hình hiện thẻ *Chưa có lựa chọn* để admin biết phải thêm danh mục trước.

### Những cột KHÔNG có trên biểu mẫu

Đây là **biểu mẫu nhân viên điền**, không phải danh sách cột của bảng. `geofence_radius_m` (tham số vận
hành), `created_by_name` · `updated_by_name` · `updated_at` (dấu vết hệ thống) **không** nằm trong `fields`.
Chúng vẫn có trong bảng và vẫn đọc/sửa được qua API điểm bán.

## Ghi giá trị

Tạo mới: `POST /crm/customers` — xem `API-TAO-DIEM-BAN-2026-09-18.md` (mã điểm bán do server sinh).
Sửa: `PATCH /crm/customers/{id}` — xem `API-SUA-DIEM-BAN-2026-09-16.md`.
Ô `kind=fixed` gửi ở gốc body, ô `kind=dynamic` gửi trong `data`:

```json
{ "name": "Tạp hoá Cô Ba", "customer_type_id": 3, "data": { "han_muc_cong_no": 5000000 } }
```

⚠️ **`read_only` không chặn ghi.** Nó nói với app "đừng vẽ ô nhập"; API sửa điểm bán vẫn nhận mọi cột
(chốt 16/09/2026 — API này được xây để **thay** MobiWork sau khi ngắt). Ô `source=mobiwork` thì khác: giá
trị nằm ở `custom_labels`, **không có đường ghi ngược**, gửi lên cũng không lưu được.

## Ai đổi được bố cục

`/crm/customer-fields` trên SPA, quyền `/crm/customer-form/update`:

- **kéo thả** đổi vị trí — trộn cột cứng và ô động trong cùng một hàng;
- **thêm / sửa / gỡ** ô động, **nhận** khoá dữ liệu gốc MobiWork vào quản trị;
- với **cột cứng**: đổi được **vị trí**, **nhãn**, cờ **bắt buộc**, và **ẩn khỏi biểu mẫu nhập**
  (`PUT /crm/customer-form/fixed/{cột}`, mở 17/09/2026) — nhưng **không gỡ** khỏi hệ thống, và không đổi
  được kiểu ô hay cờ `read_only` vì chúng phải khớp cột thật của bảng. Cột `NOT NULL` ở DB thì không ẩn
  được và luôn bắt buộc — server từ chối bằng câu nói rõ lý do.
  ⚠️ Cột cứng đã ẩn **không** có trong `fields`, y như ô động đã gỡ.
- 🔴 **`region_id` (Khu vực) không ẩn được** (từ 18/09/2026): điểm bán mở mới lấy 4 số đầu của mã từ nó, ẩn
  đi là khoá cứng cửa tạo cho toàn bộ nhân viên thị trường. Cờ `required` của nó thì vẫn đổi được.

🔴 **Không có công tắc ẩn/hiện.** Ô có mặt trong bố cục là hiện, ở mọi nơi. Bản 15/09 từng có hai công tắc
riêng cho web và app (kèm tham số `?context=web|mobile` của endpoint này); chủ hệ thống bỏ chúng ngày
16/09 — chúng mở ra loại lỗi khó lần nhất (một ô biến mất chỉ ở một phía) để đổi lấy khả năng chưa ai dùng
(đo prod: **0** ô đang tắt). Muốn một trường không xuất hiện nữa thì **gỡ nó khỏi biểu mẫu**.

## Mã lỗi

| Mã | Nghĩa |
|---|---|
| 200 | trả biểu mẫu |
| 403 | không giữ quyền `/crm/customer-form/schema` |

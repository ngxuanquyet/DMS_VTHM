# API biểu mẫu thị trường — cho app di động

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <token>` · viết 23/09/2026,
bổ sung ô **Khách hàng** 24/09/2026 (§1b + §5).

Hai endpoint app cần: **lấy biểu mẫu còn hiệu lực** và **nộp phiếu**. Định nghĩa ô nằm trong chính lượt
lấy, app không phải gọi thêm gì — **trừ** ô kiểu Khách hàng, xem §1b.

---

## 1. Lấy biểu mẫu còn hiệu lực

```
GET /dms/forms/available?kind=survey&customer_id=8338
GET /dms/forms/available?kind=collect
```

| Tham số | Bắt buộc | Ý nghĩa |
|---|---|---|
| `kind` | có | `survey` = biểu mẫu hiện **trong luồng check-in** · `collect` = biểu mẫu ở **menu chính** |
| `customer_id` | chỉ khi `kind=survey` | Điểm bán đang đứng. Thiếu ⇒ lỗi, **không** trả danh sách rỗng |

🔴 **Không nhận `user_id`.** Người hỏi luôn là người đang đăng nhập; server tự lọc theo phạm vi của họ.

### Trả về

```json
{
  "success": true,
  "data": [
    {
      "config_id": 174,
      "form_id": 9809,
      "code": "ks_gia_thang_9",
      "name": "Khảo sát giá tháng 9",
      "kind": "survey",
      "is_required": true,
      "sort_order": 1,
      "schema": {
        "blocks": [
          {
            "ref": "muc_a",
            "type": "field",
            "required": false,
            "col_span": 12,
            "resolved": {
              "code": "muc_a",
              "label": "A. Thông tin trưng bày",
              "input_type": "heading",
              "config": [],
              "description": null
            }
          },
          {
            "ref": "gia_ban",
            "type": "field",
            "required": true,
            "col_span": 12,
            "resolved": {
              "code": "gia_ban",
              "label": "Giá bán",
              "input_type": "currency",
              "config": { "validation": { "min": 0, "max": 500000 } },
              "description": null
            }
          },
          {
            "ref": "vi_tri",
            "type": "field",
            "required": false,
            "col_span": 12,
            "resolved": {
              "code": "vi_tri",
              "label": "Vị trí trưng bày",
              "input_type": "select",
              "config": {
                "options": [
                  { "value": "quay", "label": "Quầy chính" },
                  { "value": "cua",  "label": "Cửa ra vào" }
                ]
              }
            }
          }
        ]
      }
    }
  ]
}
```

### App dùng thế nào

* `is_required = true` ⇒ **chưa nộp thì không cho check-out** (chỉ có ở `kind=survey`).
* `sort_order` ⇒ thứ tự hiện trong danh sách biểu mẫu.
* `schema.blocks` theo **đúng thứ tự vẽ**; mỗi block:
  * `resolved.code` — **khoá** khi nộp (xem §2);
  * `resolved.input_type` — loại widget cần vẽ;
  * `resolved.label` — nhãn hiển thị;
  * `required` (cấp **block**, không phải trong `resolved`) — ô bắt buộc;
  * `resolved.config.options` — danh sách lựa chọn, đã kèm sẵn, **không gọi thêm endpoint nào**;
  * `resolved.config.validation` — `min` / `max` / `min_length` / `max_length`;
  * `show_if` (nếu có, cấp block) — điều kiện hiện/ẩn ô.
* 🔴 `input_type` thuộc nhóm **trình bày** (`heading`, `divider`, `note`): **chỉ vẽ, không thu dữ liệu** —
  đừng gửi giá trị cho chúng khi nộp (server bỏ qua, nhưng đừng dựa vào đó).
* Cache trọn `schema` để dùng khi mất mạng. Không có trường phiên bản: gọi lại và so nội dung.

**Loại ô app phải vẽ được (12 loại nhập liệu + 1 trình bày):** `text` · `textarea` · `number` · `currency`
· `boolean` · `checkbox` · `radio` · `select` · `multiselect` · `date` · `file` · **`ref_customer`** (mới
24/09/2026 — xem §1b) · `heading`.
Danh sách này do người vận hành chỉnh ở `/system/settings/dms`; server **từ chối** gán biểu mẫu chứa loại
ngoài danh sách, nên app không bao giờ nhận về một loại lạ.

⚠️ **App chưa vẽ được loại nào thì báo lại để người vận hành BỎ TICK loại đó** ở trang trên — một loại lọt
xuống mà app không vẽ là **ô trắng** trên tay nhân viên đang đứng ngoài thị trường.

---

## 1b. Ô **Khách hàng** (`ref_customer`) — mới 24/09/2026

Ô để nhân viên **chọn điểm bán đang thu thập thông tin**. Trong `schema.blocks` nó về như mọi ô khác:

```json
{
  "ref": "diem_ban_khao_sat",
  "type": "field",
  "required": true,
  "col_span": 12,
  "resolved": {
    "code": "diem_ban_khao_sat",
    "label": "Điểm bán khảo sát",
    "input_type": "ref_customer",
    "config": [],
    "description": null
  }
}
```

🔴 **`config` RỖNG — danh sách KHÔNG đi kèm schema.** Đây là ô duy nhất app phải gọi thêm một endpoint,
vì danh sách phụ thuộc **người đang đăng nhập** chứ không phụ thuộc biểu mẫu.

### Lấy danh sách chọn

```
GET /dms/routes/customers
```

Không nhận tham số nào. Server tự lấy **điểm bán thuộc mọi tuyến đang bật được giao cho chính người gọi**
(kể cả tuyến nằm ở tài khoản kiêm nhiệm khác của cùng người).

```json
{
  "success": true,
  "data": {
    "items": [
      { "id": 2036, "code": "08170152", "name": "Dịu Khoản", "address": "38/6 Phan Đình Phùng, Cam Ranh" },
      { "id": 5378, "code": "08120001", "name": "VLXD Hoàng Hương", "address": null }
    ],
    "truncated": false
  }
}
```

| Khoá | Ghi chú |
|---|---|
| `items[].id` | 🔴 **Đây là giá trị gửi lên khi nộp**, không phải `code` |
| `items[].code` | Mã điểm bán — hiện kèm tên để phân biệt hai điểm bán trùng tên (chuyện thường) |
| `items[].address` | Có thể `null` |
| `truncated` | `true` = danh sách chạm trần 2.000 dòng và **đã bị cắt** — hiện cảnh báo cho người dùng, đừng im lặng |

* Chưa được giao tuyến nào ⇒ `items` **rỗng kèm HTTP 200**. Đó là trạng thái hợp lệ (nhân viên mới), không
  phải lỗi — app hiện "bạn chưa được giao tuyến nào", đừng hiện màn lỗi.
* Danh sách đổi chậm (tuyến do quản trị giao) ⇒ **cache được**, làm mới khi mở app hoặc khi kéo-để-tải-lại.
  Đây cũng là dữ liệu app cần để chọn ô này khi **mất mạng**.
* Sắp sẵn theo tên; nên cho **gõ tìm** theo cả tên lẫn mã.

### Nộp giá trị

Trong `answers`, gửi **id dạng số**:

```json
"answers": { "diem_ban_khao_sat": 2036 }
```

🔴 **Server kiểm lại, không tin client:** id phải là điểm bán CÓ THẬT *và* **thuộc tuyến được giao cho
chính người nộp**. Sai một trong hai thì phiếu bị từ chối — xem bảng lỗi ở §2.

✅ **Hệ quả tiện cho app:** phiếu tự gắn điểm bán vừa chọn (`dms_form_submission.customer_id`), nên với
biểu mẫu `collect` app **không cần** gửi thêm `customer_id` ở thân request. Nếu có gửi (luồng check-in)
thì **giá trị ở thân request THẮNG** — đó là nơi nhân viên thật sự đang đứng.

---

## 2. Nộp phiếu

```
POST /dms/form-submissions
```

```json
{
  "config_id": 174,
  "visit_id": 41066,
  "customer_id": 8338,
  "answers": { "gia_ban": 185000, "vi_tri": "quay" },
  "submit_lat": 16.0678,
  "submit_lng": 108.2208,
  "submit_address": "12 Nguyễn Văn Linh, Đà Nẵng",
  "client_uuid": "0f1c…-uuid do app sinh",
  "client_time": "2026-09-23T16:04:11+07:00",
  "is_offline_sync": true
}
```

| Trường | Ghi chú |
|---|---|
| `config_id` | lấy từ §1. Cấu hình đã tắt/hết hạn ⇒ `404` |
| `visit_id` | **bắt buộc với `survey`**, và **không được gửi** với `collect` |
| `customer_id` | bắt buộc với `survey`; với `collect` thì tuỳ chọn |
| `answers` | khoá = `resolved.code`. Ô không điền thì **bỏ khoá**, đừng gửi `null` |
| `client_uuid` | UNIQUE — gửi lại cùng uuid khi mạng chập chờn sẽ **không** sinh phiếu đôi |
| `is_offline_sync` | đánh dấu phiếu đẩy lên sau khi mất mạng |

Server tự ghi: người nộp (`usr_user.id`), mã NV, **công ty/phòng ban tại thời điểm nộp**, giờ nhận, và
**ảnh chụp toàn bộ câu hỏi** — nên báo cáo kỳ cũ vẫn đọc đúng câu hỏi cũ sau khi admin sửa biểu mẫu.

### Trả về

```json
{ "success": true, "message": "Đã nộp 2 câu trả lời.", "data": { "id": 127 } }
```

### Lỗi thường gặp

| Tình huống | Phản hồi |
|---|---|
| Thiếu ô bắt buộc | `"Giá bán không được để trống."` — nêu đúng tên ô |
| Ô Khách hàng: điểm bán **ngoài tuyến của mình** | `"Điểm bán chọn ở ô “Điểm bán khảo sát” không thuộc tuyến nào được giao cho bạn."` |
| Ô Khách hàng: id không có thật / đã xoá | `"Điểm bán khảo sát có giá trị ngoài danh sách cho phép."` |
| Nộp lại cùng lượt viếng thăm | `"Lượt viếng thăm này đã nộp biểu mẫu khảo sát đó rồi."` |
| `collect` mà gửi `visit_id` | `"Biểu mẫu thu thập không gắn với lượt viếng thăm nào."` |
| `survey` mà thiếu `visit_id` | `"Biểu mẫu khảo sát thuộc về một lượt viếng thăm — nộp từ luồng check-in."` |

🔴 **Nộp xong là chốt** — không có endpoint sửa phiếu. Nhầm thì nộp phiếu mới.

---

## 3. Quyền

| Endpoint | Quyền | Vai đang giữ trên prod |
|---|---|---|
| `GET /dms/forms/available` | `/dms/form/available` | `crm_customer_self` (95 tài khoản) · `crm_customer_admin` |
| `POST /dms/form-submissions` | `/dms/form-submission/create` | như trên |
| `GET /dms/routes/customers` | `/dms/route/mine-customers` | như trên (áp prod 24/09/2026) |

Thiếu quyền ⇒ `403`; thiếu/hết hạn token ⇒ `401`.

---

## 4. Trạng thái 23/09/2026

Toàn bộ đã **chạy trên prod** và kiểm chứng bằng tài khoản thật trên `app_test`: đứng ở Nhà phân phối thấy
đúng biểu mẫu của NPP, đứng ở Đại lý C2 không thấy, menu chính không lẫn khảo sát, thiếu ô bắt buộc bị từ
chối, nộp trùng bị chặn.

Prod hiện **0 cấu hình** — chưa ai gán biểu mẫu nào, nên `data` sẽ là `[]` cho tới khi admin gán ở màn
*Khách hàng và Thị trường → Biểu mẫu thị trường*.

---

## 5. Cập nhật 24/09/2026 — việc app cần làm thêm

Đã lên prod: loại ô **`ref_customer`** (§1b) + endpoint `GET /dms/routes/customers` + quyền đi kèm.
Prod hiện có **1 cấu hình** biểu mẫu.

**App phải làm:**

1. Vẽ widget cho `input_type = "ref_customer"` — một ô chọn **có tìm kiếm**, nguồn từ `/dms/routes/customers`.
2. Cache danh sách điểm bán để dùng khi mất mạng; tôn trọng cờ `truncated`.
3. Gửi **`id` dạng số** trong `answers`; xử lý hai câu lỗi mới ở §2.

**Chưa làm kịp thì báo lại ngay** — người vận hành bỏ tick `ref_customer` ở `/system/settings/dms` là chặn
được, không cần sửa mã và không cần bản app mới. Để nguyên mà app chưa vẽ thì nhân viên thấy **ô trắng**.

# API Điểm bán (`/crm/customers*`) — hướng dẫn gọi

**Ngày:** 2026-09-15 · **Host:** `https://api-app.vthmgroup.vn` · **Trạng thái:** đã chạy · vai đã gán trên `app_test`, **prod chưa**

> Đặc tả máy đọc được nằm ở [`../openapi/one-api.json`](../openapi/one-api.json), **sinh tự động** từ mã
> nguồn (`php yii api-doc/generate`) — đó là nguồn chuẩn về đường dẫn, quyền, mã lỗi và hình dạng phản hồi.
> File này chỉ bổ sung thứ bộ sinh **không** đọc được: **tham số query**, ý nghĩa hai hàng rào quyền, và
> những bẫy khi gọi. Sửa hành vi API thì chạy lại bộ sinh, đừng sửa tay `one-api.json`.

---

## 1. Gọi được chưa — đo thật 15/09/2026

Gọi qua HTTP trên API test (`127.0.0.1:8899` → DB `app_test`), không phải suy từ mã:

| Lệnh | Kết quả |
|---|---|
| `GET /crm/customers?per-page=2` (super admin) | **200** · `total=8727` |
| `GET /crm/customers?assignee_code=VTG713` | **200** · `total=1383` |
| `GET /crm/customers/mine` (VTG713 · VTG784 · VTG920, vai `crm_customer_self`) | **200** · `total=1383` · `1523` · `1288` |
| `GET /crm/customers` (VTG713, **không** có quyền xem toàn bộ) | **403** |
| `GET /crm/customers/mine` (VTG713, **chưa** gán quyền) | **403** |
| `GET /crm/customers/meta` (nhân viên thị trường) | **200** · `dynamicColumns=5`, `stats=null` |
| `GET /crm/customers/meta` (quyền xem toàn bộ) | **200** · `stats={total:8727, active:8721, with_coords:7193}` |
| `GET /crm/customers?context=mobile` | **200** |
| `GET /crm/customers?context=moblie` | **400** · *"Bối cảnh hiển thị không hợp lệ. Giá trị cho phép: web, mobile."* |
| `GET /crm/customers?assignee_code=KHONG_TON_TAI` | **200** · `total=0` |

🔴 **Trên PROD hiện trả rỗng**: `crm_customer` có **0 dòng** (schema đã áp 13/09, dữ liệu 8.727 điểm bán
vẫn chỉ nằm ở `app_test`, chờ đợt di trú lên prod).

✅ **Trên `app_test` đã gán xong**: vai `crm_customer_self` cấp `/crm/customer/mine`, gán cho **95 tài khoản**
của khối thị trường (mọi mã trong `dms_sale_employee`). 🔴 **Trên PROD thì chưa** — xem mục 7.

---

## 2. Xác thực

Bearer token (JWT) như mọi endpoint khác của `api/`:

```http
GET /crm/customers/mine HTTP/1.1
Host: api-app.vthmgroup.vn
Authorization: Bearer <access_token>
```

Lấy token: `POST /auth/login`. Token server-to-server cho hệ ngoài: skill `/tao-token-api`.

⚠️ Phản hồi của `/auth/login` dùng khoá **`access_token`** (snake_case), không phải `accessToken`. Đọc
nhầm khoá thì biến token thành chuỗi rỗng và mọi lệnh sau nhận **401** — trông y hệt "token sai".

---

## 3. Sáu endpoint

| Method | Đường dẫn | Quyền | Dùng để |
|---|---|---|---|
| GET | `/crm/customers` | `/crm/customer/index` | Toàn bộ danh mục điểm bán |
| GET | `/crm/customers/mine` | `/crm/customer/mine` | Điểm bán **của** người gọi — phụ trách **hoặc** tự tạo |
| GET | `/crm/customers/{id}` | `/crm/customer/index` | Chi tiết một điểm bán |
| GET | `/crm/customers/meta` | `index` **hoặc** `mine` | Danh mục lọc + đặc tả cột động |
| **PATCH** | `/crm/customers/{id}` | `/crm/customer/update` | Sửa hồ sơ điểm bán |
| **DELETE** | `/crm/customers/{id}` | `/crm/customer/delete` | Xoá mềm (vào thùng rác) |

### 🔴 Hai cửa đọc theo người phụ trách — hai hàng rào, đừng gộp

```
GET /crm/customers/mine                 → sổ của CHÍNH người gọi, KHÔNG nhận tham số nhân viên
GET /crm/customers?assignee_code=VTG123 → tra sổ NGƯỜI KHÁC, đi kèm quyền xem trọn danh mục
```

`mine` lấy tập mã từ phiên đăng nhập nên **không có đường nào** để client đọc sổ của người khác. Quyền của
nó cấp rộng được cho nhân viên thị trường và cho app; quyền `index` thì không.

### "Của tôi" = phụ trách **HOẶC** tự tạo (chốt 15/09/2026)

```sql
EXISTS (SELECT 1 FROM crm_customer_assignment a
         WHERE a.customer_id = c.id AND a.deleted_at IS NULL
           AND a.employee_code IN (<tập mã>))
OR c.created_by_code IN (<tập mã>)
```

🔴 **Vì sao có vế thứ hai.** Ban đầu chỉ lọc theo phân công, và ca thật bày ra ngay ngày đầu: nhân viên mở
một điểm bán mới, nguồn để trống người phụ trách nên One không sinh dòng phân công — **người vừa tạo gọi
API và nhận danh sách rỗng**. Với luồng "NV mở điểm bán trên app" thì đó là mọi điểm bán vừa mở: tạo xong
là biến mất khỏi sổ của chính mình, không lỗi nào hiện.

Điểm bán **không rõ người tạo** (`created_by_code` NULL) không rơi vào sổ của ai — cột nullable đưa vào
`IN (...)` cho ra NULL chứ không TRUE, và đó là hành vi đúng.

Đo trên prod sau khi đổi: VTG713 **1.383 → 1.400** (+17 điểm bán tự mở mà không phụ trách) · VTG784
**1.523 → 1.561** (+38) · VTG926 **0 → 1**. Mỗi mức tăng khớp đúng số điểm bán người đó tạo mà không được
phân công — không nới thêm dòng nào.

⚠️ **Một người có NHIỀU mã nhân viên** (chuyển công ty trong tập đoàn = ERP cấp mã mới, dữ liệu cũ giữ mã
cũ). Cả hai cửa đều so bằng **tập mã**, không phải một mã — kể cả `?assignee_code=` cũng tự nở ra tập mã
của cùng người. Đừng tự ghép danh sách mã ở phía client.

---

## 4. Tham số query — phần bộ sinh OpenAPI không đọc được

Áp cho `index` và `mine` như nhau.

| Tham số | Kiểu | Ý nghĩa |
|---|---|---|
| `q` | string | Tìm **không dấu** trên mã · tên · người liên hệ · SĐT. Gõ `nguyen` ra `Nguyễn` |
| `customer_type_id` · `channel_id` · `region_id` | int | Lọc theo danh mục (lấy danh sách ở `/meta`) |
| `province_name` | string | Tỉnh/thành **mới** (35 giá trị) |
| `status` | `active` \| `inactive` | |
| `approval_status` | `draft` \| `pending` \| `approved` \| `rejected` | |
| `has_coords` | `1` \| `0` | `1` = chỉ điểm bán có toạ độ |
| `assignee_code` | string | **Chỉ `index`.** Mã NV phụ trách; tự nở ra tập mã của cùng người |
| `customer_type_code` · `channel_code` · `region_code` | string | Như ba dòng trên nhưng nhận **MÃ** thay vì id — dành cho client đến từ MobiWork (`loai_kh` · `kenh` · `khu_vuc`). Truyền cả hai thì **id thắng** |
| `unit_code` · `sale_group_code` | string | Điểm bán do người thuộc **đơn vị / nhóm bán hàng** đó phụ trách — vai trò của `phong_ban_nv` bên MobiWork |
| `created_from` · `created_to` | `YYYY-MM-DD` | Khoảng ngày TẠO, **bao gồm cả hai đầu** |
| `updated_from` · `updated_to` | `YYYY-MM-DD` | Khoảng ngày SỬA gần nhất, bao gồm cả hai đầu |
| `context` | `web` \| `mobile` | Bề mặt hiển thị — quyết định tập **ô động** trả về. Mặc định `web` |
| `page` · `per-page` | int | Phân trang; `per-page` tối đa **200**, mặc định 100 |
| `sort` | string | `code` · `name` · `status` · `created_at` · `updated_at`; `-` để giảm dần |

⚠️ **`region_id` ≠ `province_name`.** `region_id` là 63 khu vực **cũ** suy từ tiền tố mã khách hàng;
`province_name` là 35 tỉnh/thành **mới**. **37% số dòng hai thứ này khác nhau** — cấm dùng lẫn.

⚠️ Tham số lọc **sai kiểu** (ví dụ `customer_type_id=abc`, `updated_from=15/09/2026`) làm kết quả về
**rỗng**, không phải bỏ lọc. Mã danh mục không tồn tại cũng vậy — `?channel_code=KHONG_CO` ra 0 dòng.

### Đối chiếu với `GET /Customer` của MobiWork

| MobiWork | One |
|---|---|
| `nhan_vien` | `assignee_code` (hoặc dùng thẳng `/mine`) |
| `loai_kh` · `kenh` · `khu_vuc` | `customer_type_code` · `channel_code` · `region_code` |
| `phong_ban_nv` | `unit_code` · `sale_group_code` |
| `status` | `status` (giá trị `active`/`inactive`, không phải `Hoạt động`) |
| `tu_ngay` · `den_ngay` · `kieu_ngay` | `created_from/to` · `updated_from/to` |
| `page_size` · `page_number` | `per-page` · `page` |
| `nhom_kh` | — (nguồn `CustomerGroup` rỗng 0 dòng) |

🔴 **Cố ý KHÔNG bắt chước `kieu_ngay`.** Một tham số "kiểu ngày" quyết định cột nào bị lọc là thứ sai âm
thầm: gọi sai kiểu vẫn ra 200 kèm một tập dòng khác hẳn, và không có gì trong phản hồi nói nó vừa lọc theo
cột nào. Hai cặp ngày tường minh thì nhìn URL là biết.

---

## 5. Hình dạng phản hồi

```jsonc
{
  "success": true,
  "message": "Thành công",
  "data": [ /* … */ ],
  "meta": {
    "total": 1400, "currentPage": 1, "pageSize": 100, "pageCount": 14,

    // 🔴 ĐẶC TẢ Ô ĐỘNG ĐI KÈM CHÍNH TRANG DỮ LIỆU — client không phải gọi thêm /meta để biết nhãn.
    "dynamicColumns": [
      { "code": "mw_khach_hang_vthm", "label": "Khách hàng VTHM", "input_type": "text",
        "source": "mobiwork", "legacy_key": "khach_hang_vthm", "required": false, "read_only": true },
      { "code": "mw_nhan_1", "label": "Nhãn 1", "input_type": "text", "…": "…" }
    ]
  }
}
```

### Vì sao schema nằm ở `meta`, không nhúng vào từng dòng

Khoá `dynamic` của mỗi dòng chỉ là map `mã ⇒ giá trị` — **không có nhãn, không có kiểu ô**. Ba cách lấy
nhãn, và vì sao chọn cách này:

| Cách | Vấn đề |
|---|---|
| App gọi thêm `/crm/customers/meta` rồi tự ghép | Thêm một lượt gọi trên đường nóng, và có **cửa sổ lệch**: admin đổi cấu hình giữa hai lượt gọi thì app ghép nhãn cũ vào dữ liệu mới — màn hình sai mà không gì báo |
| Nhúng nhãn vào **từng dòng** | 5 ô × 8.730 dòng = lặp cùng một chuỗi hàng chục nghìn lần |
| ✅ **Schema ở `meta` của chính trang đó** | Một lượt gọi, không cửa sổ lệch, tốn **765 byte** trên trang 200 dòng (~225 KB) — **0,34%** |

`dynamicColumns` trong `meta` tôn trọng `?context=`: gọi `?context=mobile` thì nhận đúng tập ô admin đã
bật cho mobile, khớp một-một với khoá trong `dynamic` của mọi dòng cùng phản hồi.

🔴 **Bất biến app dựa vào:** tập mã trong `meta.dynamicColumns` **trùng khớp** tập khoá trong
`row.dynamic` — không thiếu, không thừa. Lệch một chiều là ô trắng không nhãn, lệch chiều kia là nhãn trỏ
vào giá trị không tồn tại; cả hai đều không ném lỗi. Có test khoá lại cho cả hai bề mặt.

Một dòng (mẫu thật, đã thay dữ liệu cá nhân):

```jsonc
{
  "id": 3472,
  "code": "08880149",
  "name": "<tên điểm bán>",
  "customer_type_id": 4,  "customer_type_name": "Nhà máy",
  "channel_id": 10,       "channel_name": "KA",
  "region_id": 62,        "region_name": "Tỉnh Vĩnh Phúc",
  "address": "<địa chỉ>",
  "province_name": "Tỉnh Phú Thọ",
  "ward_name": "Phường Vĩnh Phúc",
  "contact_name": "<người liên hệ>", "contact_title": null, "phone": "<sđt>",
  "lat": "21.3223441", "lng": "105.6237675",
  "status": "active", "approval_status": "approved",
  "created_by_name": "…", "updated_by_name": "…",
  "created_at": "2025-05-02 08:19:37+07", "updated_at": "2026-09-12 07:58:46+07",

  "dynamic":  { "mw_khach_hang_vthm": "1 - KH VTHM", "mw_nhan_1": null, "…": null },
  "assignees": [ { "employee_code": "VTG560", "is_primary": false }, "…" ]
}
```

### 5.0 Mức linh hoạt của phản hồi — ba tầng khác nhau

| Phần | Linh hoạt? |
|---|---|
| **23 khoá cứng** (`id`, `code`, `name`, `lat`, `status`…) | **Không.** Hardcode trong `Customer::fields()`; đổi phải sửa mã + migration |
| **`dynamic`** | **Có.** Tập khoá đi theo cấu hình admin ở `/crm/customer-fields`, và theo `?context=` |
| **`assignees`** | Không — luôn có mặt, luôn đủ danh sách |

🔴 **Client KHÔNG chọn được trường.** `?fields=` và `?expand=` **không có tác dụng** — đo 15/09: truyền
`?fields=id,code` vẫn nhận đủ 25 khoá, truyền `?expand=email` vẫn không có `email`. Nguyên nhân:
`paginated()` trả model **thô**, không qua REST Serializer của Yii. Muốn thêm trường phải mở ở **tầng
controller**, không phải từ client.

⚠️ **Cân nhắc trọng lượng cho app:** `assignees` luôn đi kèm và có thể tới **27 phần tử** cho một điểm bán
(đo thật trên prod). Một trang 100 dòng mang theo hàng nghìn object con. Nếu app không dùng tới danh sách
người phụ trách, nói để tôi tách nó thành `?expand`-style opt-in ở tầng controller.

### 5.1 `dynamic` — ô động, KHÔNG cố định

23 khoá đầu là **cột cứng**, hardcode trong mã. Khoá `dynamic` thì **đi theo cấu hình** admin đặt ở
`/crm/customer-fields`: nó là map `mã ô ⇒ giá trị`, tập khoá đổi khi admin bật/tắt ô.

🔴 **`dynamic` LUÔN là JSON object `{}`, không bao giờ là `[]`.** Đây là chỗ từng sai: `json_encode` của
PHP xuất mảng rỗng thành `[]` nhưng mảng có khoá thành `{}` — tức kiểu của trường đổi theo dữ liệu, và
client khai `Map<String, dynamic>` (Dart) sẽ nổ **đúng ở môi trường chưa cấu hình ô nào**, tức môi trường
mới dựng. Đã ép thành object ở `Customer::toArray()` và có test khoá lại; cứ khai kiểu map, không cần
nhánh phòng hờ.

**Nhãn và kiểu ô không nằm trong dòng dữ liệu** — lấy ở `/crm/customers/meta` → `dynamicColumns`
(mã · nhãn · `input_type` · `source` · `required` · `read_only`, **đúng thứ tự admin xếp**). Trang chi tiết
`/crm/customers/{id}` trả sẵn `dynamic_fields` gộp cả nhãn lẫn giá trị.

`source` của một ô cho biết giá trị đến từ đâu:

| `source` | Nghĩa |
|---|---|
| `own` | Ô admin tự thêm — sửa được (khi có luồng ghi) |
| `mobiwork` | Ô **nhận** từ dữ liệu gốc hệ cũ — **luôn `read_only`**, không bao giờ `required` |

### 5.1b `meta` trả gì tuỳ quyền

Hình dạng **không đổi** — luôn đủ 6 khoá `customerTypes`, `channels`, `regions`, `provinces`,
`dynamicColumns`, `stats`. Nhưng người chỉ có `/crm/customer/mine` nhận `stats = null` và `provinces[].cnt
= null`: đó là số đếm của **toàn bộ** 8.727 điểm bán, không phải phần họ được đọc. Client không phải rẽ
nhánh theo quyền, chỉ cần chịu được `null`.

### 5.2 `assignees` — người phụ trách

Trung bình **2,67 người/điểm bán**, cá biệt tới **23**. Đây là phần nặng nhất của payload; cân nhắc khi
đồng bộ về máy.

⚠️ `employee_code` **có thể không phải mã nhân viên**: khi di trú không dò ra mã từ email, nó lưu chính
email cắt còn 32 ký tự. Dữ liệu hiện tại chưa có dòng nào như vậy (65/65 mã đều dò ra), nhưng chỗ nào hiển
thị mã này cho người dùng thì phải chịu được giá trị đó.

---

## 6. Ví dụ

```bash
TOKEN=...   # từ POST /auth/login → data.access_token

# Sổ điểm bán của tôi, trang đầu
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers/mine?per-page=100'

# App thị trường — chỉ lấy ô admin đã bật cho mobile
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers/mine?context=mobile&per-page=200'

# Tìm không dấu trong sổ của mình
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers/mine?q=nguyen'

# Quản lý tra sổ của một nhân viên (cần quyền xem toàn bộ danh mục)
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers?assignee_code=VTG713'

# Đặc tả cột động cho app
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers/meta?context=mobile'
```

---

## 6b. Thử trên môi trường `app_test`

Chốt 15/09/2026: app thử trên **`app_test`** trước, không phải prod. Lý do: prod `crm_customer` **0 dòng**
nên gọi được cũng chỉ thấy danh sách rỗng, trong khi `app_test` có **8.727 điểm bán** và **95 tài khoản
khối thị trường đã gán vai**.

API test **dùng chung mã nguồn** với `api/`, chỉ đè component `db` sang `app_test` — nên nó luôn chạy đúng
bản mã mới nhất, không phải một bản sao phải đồng bộ.

### ① Địa chỉ và cách với tới

API test nghe **`127.0.0.1:8899`** và chỉ 127.0.0.1. Đó là hàng rào ở tầng **socket**, cố ý: `app_test` là
bản sao dữ liệu thật, gồm hồ sơ nhân sự kèm CCCD, và `YII_DEBUG` bật (stack trace lộ ra ngoài). Vhost ghi
rõ *"sai một dòng `Require` là mở ra Internet, còn bind vào 127.0.0.1 thì không"*.

Từ máy lập trình viên — mở tunnel, đừng đổi cách bind:

```bash
ssh -N -L 8899:127.0.0.1:8899 <user>@172.30.250.16
```

| Client chạy ở đâu | Base URL |
|---|---|
| Ngay trên máy đã tunnel (desktop / web / script) | `http://127.0.0.1:8899` |
| Máy ảo Android | `http://10.0.2.2:8899` |
| Máy ảo iOS | `http://127.0.0.1:8899` |
| Thiết bị thật nối USB | `adb reverse tcp:8899 tcp:8899` → `http://127.0.0.1:8899` |

⚠️ Đây là **HTTP thường**, không TLS. Client Android (API 28+) và một số HTTP stack chặn cleartext mặc
định — phải mở riêng cho bản debug, và đừng để cấu hình đó lọt sang bản phát hành.

Cần một địa chỉ LAN cố định thay vì tunnel thì phải chủ hệ thống quyết: nó gỡ đúng cái hàng rào socket ở
trên, nên không phải thứ tự đổi.

### ② Đăng nhập — dùng `VTG713`, KHÔNG dùng tài khoản super admin

| | VTG713 | VTG926 |
|---|---|---|
| Vai `crm_customer_self` | có | có |
| `is_super_admin` trên `app_test` | **không** | **CÓ** |
| Điểm bán được phân công | **1.383** | **0** |

🔴 Tài khoản super admin **bỏ qua toàn bộ phân quyền**: app sẽ "chạy đẹp" trong khi không hàng rào nào được
kiểm, và lỗi chỉ lộ ra khi phát hành cho người thật. Đo 15/09: VTG926 gọi `/crm/customers` lấy được **cả
8.727 dòng**, trong khi vai của tài khoản đó không cho phép.

Tài khoản có sổ khách để thử: **VTG713** (1.383) · **VTG784** (1.523) · **VTG920** (1.288).

Lấy token qua backdoor thử nghiệm — **khoá xin chủ hệ thống**, nằm ở `auth.testLoginKey` trong
`api/config/params-local.php`; đừng nhúng vào mã nguồn client:

```bash
curl -X POST http://127.0.0.1:8899/auth/test-login \
  -H 'Content-Type: application/json' \
  -d '{"key":"<khoá>","username":"VTG713"}'
```

⚠️ Khoá token trong phản hồi là **`data.access_token`** (snake_case), không phải `accessToken`.

---

## 6bis. Danh mục cho dropdown — `GET /crm/customers/meta`

Một lượt gọi cho **cả bộ** danh mục của form sửa. Quyền: `/crm/customer/index` **hoặc** `/crm/customer/mine`
— nhân viên thị trường cũng lấy được.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  'https://api-app.vthmgroup.vn/crm/customers/meta?context=mobile'
```

```jsonc
{
  "success": true,
  "data": {
    "customerTypes": [ {"id":1, "code":"Đại lý C2", "name":"Đại lý C2", "color":null}, … ],   // 10
    "channels":      [ {"id":1, "code":"MB1",       "name":"MB1",       "color":null}, … ],   // 15
    "regions":       [ {"id":1, "code":"0865", "name":"Thành phố Cần Thơ", "color":null}, … ],// 63
    "provinces":     [ {"province_name":"Thành phố Hà Nội", "cnt":494}, … ],                  // 35
    "dynamicColumns":[ … ],
    "stats":         {"total":8730, "active":8724, "with_coords":7196}
  }
}
```

### Ba danh mục dùng cho dropdown

| Khoá | Số dòng | Gửi lên khi PATCH | Ghi chú |
|---|---|---|---|
| `customerTypes` | 10 | `customer_type_id` | `code` chính là tên (`Đại lý C2`, `Nhà máy`…) |
| `channels` | 15 | `channel_id` | mã ngắn: `MB1` · `KA` · `MT1`… |
| `regions` | **63** | `region_id` | ⚠️ đọc cảnh báo dưới |

Mỗi phần tử: `id` (gửi lên) · `name` (hiện) · `code` (đối chiếu) · `color` (mã màu Bootstrap, có thể `null`).

🔴 **`regions` KHÔNG phải tỉnh/thành.** Đây là **63 khu vực CŨ** suy từ 4 số đầu mã khách hàng, tên nhìn
giống tỉnh (`Thành phố Cần Thơ`) nên rất dễ nhầm. Tỉnh/thành mới là `province_name` — **35 giá trị** và
**37% số dòng hai thứ này khác nhau**. Đừng đổ `regions` vào ô Tỉnh/Thành.

### Tỉnh/Thành và Xã/Phường: **chưa có danh mục**

`provinces` trong `meta` là `DISTINCT` trên chính `crm_customer` — nghĩa là chỉ những tỉnh **đang có khách
hàng**, và kèm cả giá trị rác (`"01"`, 9 dòng). `ward_name` thì không có danh mục nào.

Nên hai ô này trên form sửa vẫn là **ô gõ tay**, và hệ quả đã đo được: **1.596** điểm bán thiếu tỉnh,
**1.677** thiếu xã.

Dựng bảng danh mục hành chính 2025 (34 tỉnh + ~3.321 xã, dropdown xã lọc theo tỉnh) là việc đã thiết kế
xong nhưng **tạm gác** — chờ danh mục chính thức. Trong lúc đó dùng `regions`.

### Gợi ý cho client

- `meta` đổi rất ít — tải một lần khi mở form, cache lại; không gọi mỗi lần gõ phím.
- `?context=` chỉ ảnh hưởng `dynamicColumns`; ba danh mục trên không đổi theo bề mặt.
- `stats` là `null` với người chỉ có quyền `/crm/customer/mine` — xem §5.1b.

---

## 6c. Sửa điểm bán — `PATCH /crm/customers/{id}`

```bash
curl -X PATCH https://api-app.vthmgroup.vn/crm/customers/10031 \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"contact_title":"Chủ cửa hàng","phone":"0911111111"}'
```

```jsonc
{
  "success": true,
  "message": "Đã cập nhật 2 trường.",
  "data": {
    "id": 10031,
    "changed": ["contact_title", "phone"],
    "overwritten_on_next_sync": ["contact_title", "phone"]   // ⚠️ đọc mục dưới
  }
}
```

### 🔴 PATCH: ô KHÔNG gửi thì GIỮ NGUYÊN

Chỉ gửi đúng những ô muốn đổi. Gửi `null` là **xoá giá trị** — khác hẳn với không gửi.

```jsonc
{"phone": "0911111111"}   // đổi SĐT, mọi ô khác giữ nguyên
{"phone": null}           // XOÁ SĐT
{}                        // không đổi gì → 200 "Không có gì thay đổi."
```

### Ô sửa được — **mọi trường thông tin** (chốt 15/09/2026)

Nhóm nghiệp vụ: `code` · `name` · `customer_type_id` · `customer_group_id` · `channel_id` · `region_id` ·
`lat` · `lng` · `geofence_radius_m` · `address` · `delivery_address` · `province_name` · `ward_name` ·
`contact_name` · `contact_title` · `phone` · `email` · `birthday` · `photo_file_id` · `status` ·
`approval_status`

Nhóm nguồn gốc / đồng bộ: `mobiwork_id` · `created_by_code` · `client_uuid` · `legacy_source` ·
`legacy_key` · `is_offline_sync` · `created_by_name` · `updated_by_name`

Hai cột jsonb: `data` (ô động — **gộp**) · `custom_labels` (ảnh chụp hệ cũ — **thay thế trọn**)

**Bốn cột KHÔNG đi qua đây** — không phải vì nhạy cảm, mà vì có cửa khác:

| Cột | Đi đường nào |
|---|---|
| `id` | khoá chính — đổi là một bản ghi khác |
| `created_at` · `updated_at` | mốc do tầng nền ghi; sửa tay là hỏng mọi đối soát theo thời gian, gồm chính bộ lọc `updated_from` |
| `deleted_at` | `DELETE /crm/customers/{id}` + thùng rác |

Gửi một trong bốn cột đó, hoặc gõ sai tên khoá → **422 nêu đích danh**, không im lặng bỏ qua.

⚠️ **`code` sửa được, nhưng biết mình đang làm gì.** Mã đã phát ra ngoài: in trên chứng từ, và là khoá dò
của `dms_visit.legacy_customer_code` cho 1.505 lượt ghé của những điểm bán đã bị xoá bên nguồn. **Đổi mã
KHÔNG cập nhật các lượt ghé đó** — chúng vẫn trỏ mã cũ. Mã trùng thì nhận 422, không phải lỗi DB.

### 🔴 `overwritten_on_next_sync` — đọc kỹ khoá này

Chừng nào **còn đồng bộ từ MobiWork**, sửa ở One **không thắng**: lượt kéo dữ liệu kế tiếp ghi đè 31/37
cột. Khoá này liệt kê đúng những ô vừa sửa mà sẽ bị đè.

Đo thật 15/09/2026: sửa `contact_title` = "Chủ cửa hàng" → chạy `mobiwork-migrate/customers` →
giá trị về `NULL`.

Hai ô **không** bị đè (nguồn không có): `data` (ô động của One) và `geofence_radius_m`.

API này **làm chủ sau khi ngắt MobiWork**. Trước đó dùng để thử nghiệm và để sửa điểm bán không còn ở nguồn.

### Lỗi trả về

| Mã | Khi nào |
|---|---|
| `422` | Sai định dạng — email, toạ độ ngoài dải, geofence ngoài 10–5000, FK không tồn tại, **toạ độ lẻ một vế** |
| `400` | Ghi vào ô động không tồn tại, hoặc ô động `read_only` |
| `404` | Không có điểm bán với id đó |
| `403` | Thiếu quyền `/crm/customer/update` |

🔴 **Toạ độ phải đủ cặp.** Gửi mình `lat` mà thiếu `lng` → 422. Nửa cặp thì luật geofence **tắt im lặng** —
điểm bán trông như có vị trí mà mọi phép kiểm khoảng cách ra NULL.

### Ghi ô động

```jsonc
{"data": {"ma_o_cua_toi": "giá trị"}}
```

Gộp vào giá trị cũ, không thay thế — gửi một ô thì các ô khác giữ nguyên.

⚠️ Chỉ ghi được ô `source = "own"`. Ô `source = "mobiwork"` luôn `read_only` (không có đường ghi ngược về
hệ cũ) — gửi lên nhận **400** kèm tên ô. Đọc cờ `read_only` trong `dynamicColumns`, đừng đoán theo kiểu ô.

---

## 6d. Xoá điểm bán — `DELETE /crm/customers/{id}`

```bash
curl -X DELETE https://api-app.vthmgroup.vn/crm/customers/10031 \
  -H "Authorization: Bearer $TOKEN"
```

```jsonc
{ "success": true, "message": "Đã chuyển điểm bán vào thùng rác.",
  "data": { "id": 10031, "deleted": true } }
```

🔴 **Xoá MỀM, không mất dữ liệu.** `dms_visit.customer_id` là FK CASCADE — xoá cứng một điểm bán là **xoá
theo toàn bộ lịch sử viếng thăm** của nó. Nên bản ghi chỉ được đánh dấu: biến khỏi mọi danh sách, vào
**thùng rác** (`/trash/items?type=crm.customer`), khôi phục được, lượt ghé cũ còn nguyên.

⚠️ **Xoá SỐNG SÓT qua đồng bộ** — khác hẳn các ô sửa ở trên. Đo thật: xoá → chạy lại
`mobiwork-migrate/customers` → `deleted_at` vẫn còn nguyên. Migrator không ghi cột đó.

Xoá một bản ghi đã xoá → `200` kèm `"deleted": false`, **không** đè mốc xoá lần đầu.

---

## 6e. Tóm tắt cho app mobile — đọc mục này là đủ để viết client

### Vòng đời một màn hình điểm bán

```
① đăng nhập      POST /auth/login                    → data.access_token  (snake_case!)
② danh mục       GET  /crm/customers/meta?context=mobile      ← cache lại, cho dropdown
                 → customerTypes · channels · regions · dynamicColumns
③ kéo danh sách  GET  /crm/customers/mine?context=mobile&per-page=200
                 → data[]        : các dòng, mỗi dòng có `dynamic` (map mã ⇒ giá trị)
                 → meta.dynamicColumns : NHÃN + KIỂU của đúng những ô đó
④ sửa            PATCH /crm/customers/{id}   {"phone":"09…","channel_id":3}
⑤ xoá            DELETE /crm/customers/{id}
```

Không cần gọi `/meta` riêng: schema đã nằm trong `meta.dynamicColumns` của chính trang dữ liệu.

### Bảy điều client PHẢI làm đúng

| # | Điều | Vì sao |
|---|---|---|
| 1 | Dựng UI ô động từ `meta.dynamicColumns`, **không hardcode** | Admin bật/tắt/đổi nhãn/đổi thứ tự là phản hồi đổi ở lượt gọi kế tiếp |
| 2 | Lưu **cả schema** xuống SQLite, không chỉ dữ liệu | Không có schema thì mở offline không có nhãn để vẽ |
| 3 | Tôn trọng cờ `read_only` | Vẽ ô nhập cho ô chỉ đọc = người dùng gõ xong bấm lưu mà chẳng có gì được lưu |
| 4 | `dynamic` LUÔN là object `{}` | Khai `Map<String, dynamic>`, không cần nhánh phòng hờ |
| 5 | Chịu được `lat`/`lng` = `null` | 17,6% điểm bán chưa có toạ độ |
| 6 | PATCH chỉ gửi ô muốn đổi | Gửi cả object là ghi đè thứ người khác vừa sửa |
| 7 | Đọc `overwritten_on_next_sync` | Chừng nào còn đồng bộ MobiWork thì sửa ở One sẽ bị đè |

### Ánh xạ tham số từ `GET /Customer` của MobiWork

| MobiWork | One |
|---|---|
| `nhan_vien` | dùng thẳng `/crm/customers/mine` |
| `loai_kh` · `kenh` · `khu_vuc` | `customer_type_code` · `channel_code` · `region_code` |
| `phong_ban_nv` | `unit_code` · `sale_group_code` |
| `tu_ngay` · `den_ngay` | `updated_from` · `updated_to` (hoặc `created_from/to`) |
| `page_size` · `page_number` | `per-page` · `page` |

### Đồng bộ gia tăng

```
GET /crm/customers/mine?context=mobile&updated_from=<lần đồng bộ trước>&per-page=200
```

Lấy đúng phần đổi từ lần trước. Nhớ `updated_to` bao gồm cả ngày cuối.

⚠️ **Trọng lượng:** trang 200 dòng ≈ **225 KB**, phần lớn là `assignees` (một điểm bán có tới 27 người phụ
trách). Kéo trọn 1.400 dòng ≈ 1,5 MB mỗi lượt. Nếu app không dùng danh sách người phụ trách, báo để tách
thành opt-in — giảm khoảng 60%.

### Mã lỗi

| Mã | Nghĩa | App nên làm gì |
|---|---|---|
| `401` | Token sai/hết hạn | Đăng nhập lại |
| `403` | Thiếu quyền | Báo người dùng liên hệ quản trị — **đừng** thử lại |
| `404` | Không có điểm bán đó | Bỏ khỏi cache cục bộ |
| `422` | Sai định dạng | Hiện lỗi theo từng ô: `errors` là map `tên ô ⇒ [câu lỗi]` |
| `400` | Sai luật nghiệp vụ (ô động lạ/chỉ đọc, toạ độ lẻ vế, cột không sửa được) | Hiện `message` |

---

## 7. Phải biết trước khi dùng

1. 🔴 **PROD chưa gán vai.** `app_test` đã có vai `crm_customer_self` (95 tài khoản); trên prod quyền
   `/crm/customer/mine` vẫn **0 vai** ⇒ mọi người dùng thật nhận 403. Áp bằng:
   `bash scripts/migrate.sh --interactive=0 --migrationPath=@common/modules/crm/migrations/rbac`
   (thư mục `rbac/` **không** nằm trong `migrationPath` mặc định — cố ý, để một lượt `migrate.sh` của
   phiên khác không vô tình cấp quyền cho người dùng thật).
2. 🔴 **Prod chưa có dữ liệu** — `crm_customer` 0 dòng. API trả 200 kèm danh sách rỗng, không phải lỗi.
3. ⚠️ **`context` là TRÌNH BÀY, không phải phân quyền.** Client tự khai bề mặt, nên người chỉ có quyền
   `mine` gọi `?context=web` **vẫn nhận** những ô admin đã tắt cho mobile — trên chính điểm bán của họ.
   Muốn giấu thật một trường thì phải dùng **quyền** hoặc bỏ ô khỏi biểu mẫu, không phải công tắc hiển thị.
4. ⚠️ **Đợt này CHỈ ĐỌC** — chưa có thêm/sửa/xoá điểm bán. Luồng nhân viên mở điểm bán từ app nằm ở đợt sau.
5. ⚠️ **1.534/8.727 điểm bán chưa có toạ độ** (17,6%). Gần như toàn bộ là điểm bán chưa ai từng đến (chỉ
   7 cái từng có lượt viếng thăm, 0 cái trong 90 ngày), nhưng app phải chịu được `lat`/`lng` là `null`.

---

## 8. Liên quan

- [`../openapi/one-api.json`](../openapi/one-api.json) — đặc tả sinh tự động (789 path)
- [`../../specs/integrations/KE-HOACH-TRIEN-KHAI-DMS-2026-09-10.md`](../../specs/integrations/KE-HOACH-TRIEN-KHAI-DMS-2026-09-10.md) — kế hoạch triển khai, đợt B4a là API đồng bộ cho app
- [`../../specs/integrations/SPEC-CRM-CUSTOMER-TRUONG-DONG-2026-09-12.md`](../../specs/integrations/SPEC-CRM-CUSTOMER-TRUONG-DONG-2026-09-12.md) — thiết kế trường động

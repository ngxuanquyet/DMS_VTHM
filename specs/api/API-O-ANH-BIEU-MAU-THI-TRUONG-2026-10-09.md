# Ô ẢNH trong biểu mẫu thị trường — việc app di động phải làm

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <token>` (trừ §4.1) ·
viết 09/10/2026.

Loại ô **`image`** đã **bật trên prod ngày 08/10/2026**. Nhân viên chụp ảnh ngay trong biểu mẫu thị
trường (biển hiệu, kệ trưng bày, bảng giá) thay vì phải mở luồng khác.

**Ba việc mới cho app** — ngoài ra **không có gì đổi**: `GET /dms/forms/available` và
`POST /dms/form-submissions` giữ nguyên đường dẫn, nguyên hình dạng payload.

1. Vẽ widget máy ảnh cho ô có `input_type = "image"`.
2. Tải từng tấm lên `POST /dms/form-photos` **trước**, nhận `token`.
3. Nộp phiếu với **mảng token** trong `answers`.

Tài liệu nền, đọc trước nếu chưa làm biểu mẫu thị trường:
[`API-BIEU-MAU-THI-TRUONG-2026-09-23.md`](API-BIEU-MAU-THI-TRUONG-2026-09-23.md) ·
[`API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md`](API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md).
Ảnh của các luồng khác là **ống riêng, không dùng lẫn** — xem §7.

> Mọi phản hồi dưới đây **đo thật ngày 09/10/2026** trên `app_test` bằng tài khoản nhân viên thật
> (`TEST001`), biểu mẫu `zz_testcc_diemban` (config_id 435) có ô ảnh `dms_test_cc_anh_bien_hieu` —
> không phải ví dụ bịa.

---

## 1. Nhận ra ô ảnh trong schema

Ô ảnh về trong `schema.blocks[]` của `GET /dms/forms/available` như mọi ô khác:

```json
{
  "type": "field",
  "ref": "dms_test_cc_anh_bien_hieu",
  "required": false,
  "col_span": 12,
  "resolved": {
    "code": "dms_test_cc_anh_bien_hieu",
    "label": "Ảnh biển hiệu",
    "input_type": "image",
    "config": [],
    "description": null,
    "show_in_list": false
  }
}
```

| Khoá | Ý nghĩa |
|---|---|
| `resolved.input_type` | `"image"` — vẽ nút chụp ảnh |
| `resolved.config.max_files` | Số ảnh tối đa của ô. **Vắng mặt ⇒ 1** |
| `required` (cấp block) | Bắt buộc ⇒ chưa có ảnh nào thì không cho nộp |

🔴 **Bẫy parse JSON: `config` về dạng MẢNG RỖNG `[]` khi admin chưa khai gì** (PHP serialize mảng rỗng
thành `[]`, không phải `{}`). Dart/Kotlin ép thẳng sang `Map` tại đây là **nổ runtime**. Đọc kiểu:

```dart
final rawCfg = resolved['config'];
final cfg = rawCfg is Map ? Map<String, dynamic>.from(rawCfg) : <String, dynamic>{};
final maxFiles = (cfg['max_files'] as int?) ?? 1;
```

⚠️ **Tự kẹp `max_files` xuống 10.** Server kẹp lúc validate (`min(max_files, 10)`) nhưng schema trả
nguyên con số admin gõ. App vẽ 20 ô chụp rồi bị server từ chối ở tấm thứ 11 là lỗi người dùng không
hiểu được. `max_files <= 0` cũng hiểu là **1**, không phải "không giới hạn".

---

## 2. Tải ảnh lên — `POST /dms/form-photos`

**Tải lên TRƯỚC, nộp phiếu SAU.** Phiếu chưa tồn tại lúc nhân viên bấm chụp, nên ảnh phải có chỗ đứng
riêng. Cố ý **không** nhét ảnh vào chính lượt nộp phiếu: lượt nộp là JSON có `client_uuid` chống trùng
cho hàng đợi ngoại tuyến — đổi sang multipart thì mỗi lần gửi lại trên 3G là **tải lại toàn bộ ảnh**.

```bash
curl -X POST 'https://api-app.vthmgroup.vn/dms/form-photos' \
     -H 'Authorization: Bearer <token>' \
     -F 'file=@bien-hieu.png'
```

| | |
|---|---|
| Thân request | `multipart/form-data`, **đúng một tệp**, tên phần bắt buộc là **`file`** |
| Đuôi nhận | `jpg` `jpeg` `png` `gif` `webp` `bmp` — **chỉ ảnh** |
| Dung lượng | **tối đa 10 MB/tấm** (đo 09/10: 11 MB bị từ chối). Người vận hành đổi được ở `/system/settings` |
| Số lần gọi | Mỗi tấm **một lượt gọi**. Không có endpoint tải nhiều tấm một lần |

### Trả về — HTTP **201**

```json
{
  "success": true,
  "message": "Đã tải tệp lên.",
  "data": {
    "token": "b83a1130671e0b1f5b75592494186ea5",
    "name": "bien-hieu.png",
    "ext": "png",
    "size": 70,
    "mime": "image/png",
    "url": "/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5"
  }
}
```

* `token` — **32 ký tự hex**, là thứ duy nhất phải giữ để nộp phiếu.
* `url` — đường **tương đối**, ghép với host API để xem lại ngay bằng `<img src>` (§4.1). Dùng chuỗi
  server trả về, **đừng tự ghép** từ token: đổi đường phục vụ sau này sẽ không phải phát hành app mới.

### Lỗi (HTTP 422)

| Tình huống | `message` |
|---|---|
| Không gửi phần `file` | `Chưa chọn tệp nào để tải lên.` |
| Tệp không phải ảnh | `Tệp "x.txt" có định dạng không được phép — chỉ nhận ảnh.` |
| Quá dung lượng | `Tệp "big.png" (11264 KB) vượt mức tối đa 10240 KB.` |

⚠️ **Camera bắt buộc là việc của APP.** Server không phân biệt được ảnh chụp trực tiếp với ảnh chọn từ
thư viện — muốn ép chụp tại chỗ thì chặn ở app, đừng chờ server.

---

## 3. Nộp phiếu — giá trị ô ảnh là **MẢNG TOKEN**

```bash
curl -X POST 'https://api-app.vthmgroup.vn/dms/form-submissions' \
     -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' \
     -d '{
       "config_id": 435,
       "answers": {
         "dms_so_ke": 3,
         "dms_test_cc_anh_bien_hieu": ["b83a1130671e0b1f5b75592494186ea5"]
       },
       "client_uuid": "92cdec8b-36db-46c5-b48f-563a2c52e8ce"
     }'
```

```json
{ "success": true, "message": "Đã nộp 3 câu trả lời.", "data": { "id": 950, "duplicate": false } }
```

🔴 **LUÔN gửi mảng, kể cả khi ô chỉ cho một ảnh** — `["<token>"]`. Server có nhận chuỗi trần và tự bọc
thành mảng (đo 09/10: phiếu 951 lưu `["0f39…"]`), nhưng đừng dựa vào đó: dữ liệu trong DB luôn là mảng,
nên mọi chỗ đọc lại phải xử lý mảng; gửi lúc chuỗi lúc mảng là cách chắc chắn để một nhánh code quên.

* Ô ảnh **không điền** thì **bỏ hẳn khoá** khỏi `answers` — đừng gửi `null` hay `[]`.
* 🔴 **`client_uuid` phải là UUID đúng định dạng.** Chuỗi tự do (`"cc-anh-20261009-01"`) làm server trả
  lỗi SQL thô `invalid input syntax for type uuid`, không phải câu lỗi tử tế. Sinh bằng `Uuid.v4()`.
* Gửi lại **cùng `client_uuid`** ⇒ không sinh phiếu đôi: trả `success: true` kèm
  `"duplicate": true` và **đúng `id` cũ** (đo: `{"id": 952, "duplicate": true}` —
  *"Phiếu này đã được ghi nhận trước đó, không thêm gì thêm."*). App coi đây là **thành công**, xoá
  khỏi hàng đợi ngoại tuyến.

---

## 4. Xem lại ảnh — hai đường, cho hai việc khác nhau

Thư mục `uploads/` nằm ngoài webroot nên cả hai đường đều đi qua PHP.

### 4.1. Công khai — dán thẳng vào `<img src>`

```
GET /dms/form-photos/public/{token}      ← KHÔNG cần Bearer
```

Đo 09/10: `200 · image/png`. Đây chính là chuỗi ở khoá `url` của §2. Dùng cho khung xem trước ngay sau
khi chụp, và cho mọi chỗ không gắn được header.

Token 32-hex là **bí mật khó đoán**; đường này chỉ phục vụ ảnh thuộc ngữ cảnh biểu mẫu thị trường —
token ảnh của luồng khác nhận **404** (đo thật với một token ảnh điểm bán).

### 4.2. Có xác thực — cho HTTP client

```
GET /dms/form-photos/{token}             ← đòi Bearer, thiếu ⇒ 401
```

### 4.3. Ảnh của một phiếu đã nộp

`GET /dms/form-submissions/{id}` trả kèm khoá **`answer_photos`** — map `token → đường xem công khai`:

```json
"answers":       { "dms_test_cc_anh_bien_hieu": ["b83a1130671e0b1f5b75592494186ea5"] },
"answer_photos": { "b83a1130671e0b1f5b75592494186ea5": "/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5" }
```

🔴 **`answer_photos` CHỈ chứa token còn tệp thật.** Token có trong `answers` mà **vắng** trong
`answer_photos` nghĩa là tệp đã mất — hiện "ảnh không còn trên hệ thống", đừng vẽ một khung ảnh vỡ.

---

## 5. Hàng đợi ngoại tuyến — luật quan trọng nhất

🔴 **Ảnh đã tải lên mà chưa có phiếu nào nộp kèm là "tệp mồ côi", và có thể bị dọn rác sau 1 ngày.**
Phiếu nằm trong hàng đợi ngoại tuyến quá một ngày rồi mới gửi thì lượt nộp bị từ chối với câu *"không
tìm thấy ảnh vừa tải lên. Vui lòng tải lại."*

**App phải:** giữ **tệp ảnh gốc trên máy** cho tới khi phiếu nộp thành công, không chỉ giữ token. Gặp
đúng câu lỗi trên thì **tải lại ảnh để lấy token mới rồi nộp lại** — đừng báo cho nhân viên một lỗi họ
không sửa được.

> Trạng thái 09/10/2026: cron dọn rác `file-gc/run` đang **TẮT** trên prod (lần chạy cuối 05/07/2026),
> nên thực tế hiện chưa có ảnh nào bị xoá. Đừng thiết kế app dựa vào điều đó — cron bật lại là hành vi
> quay về như mô tả trên, không ai báo app trước.

Phần còn lại của hàng đợi ngoại tuyến không đổi: `client_uuid`, `client_time`, `is_offline_sync` giữ
nguyên ý nghĩa cũ.

---

## 6. Bảng lỗi khi nộp phiếu có ảnh (đo thật 09/10/2026)

| Tình huống | `message` | App làm gì |
|---|---|---|
| Gửi 2 token cho ô `max_files = 1` | `Ảnh biển hiệu chỉ cho phép tối đa 1 ảnh.` | Kẹp số ảnh ngay trên app theo §1 |
| Token của **luồng ảnh khác** (điểm bán, viếng thăm, chấm công) | `Ảnh biển hiệu: tệp này không được tải lên cho biểu mẫu này.` | Chỉ dùng token từ `POST /dms/form-photos` |
| Token không có thật / tệp đã bị dọn | `Ảnh biển hiệu: không tìm thấy ảnh vừa tải lên. Vui lòng tải lại.` | **Tải lại ảnh gốc** rồi nộp lại (§5) |
| Giá trị không phải chuỗi/số (object, boolean…) | `Ảnh biển hiệu có giá trị không hợp lệ.` | Sửa payload |
| Tệp không phải ảnh lọt vào ô | `Ảnh biển hiệu chỉ nhận tệp ảnh.` | — (đã chặn từ §2) |

Các lỗi chung của lượt nộp (thiếu ô bắt buộc, `visit_id` sai luồng, nộp trùng lượt viếng thăm) giữ
nguyên — xem §2 của `API-BIEU-MAU-THI-TRUONG-2026-09-23.md`.

---

## 7. Đừng nhầm với ba ống ảnh khác

Hệ thống có **bốn** ống ảnh tách biệt; mỗi ống chỉ phục vụ ảnh của chính nó, lấy token ống này gắn sang
ống kia luôn bị từ chối (đo ở §6).

| Việc | Endpoint tải lên | Tài liệu |
|---|---|---|
| **Ô ảnh trong biểu mẫu thị trường** | `POST /dms/form-photos` | tài liệu này |
| Ảnh hồ sơ điểm bán | `POST /crm/customer-photos` | `API-MOBILE-TAO-KHACH-HANG-NHIEU-ANH-2026-09-23.md` |
| Ảnh lượt viếng thăm | ống riêng của viếng thăm | `API-VIENG-THAM-MOBILE-2026-09-29.md` |
| Ảnh khai báo vị trí | ống riêng của khai báo vị trí | `API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md` |

---

## 8. Quyền

| Endpoint | Quyền | Ghi chú |
|---|---|---|
| `POST /dms/form-photos` | `/dms/form-submission/create` | **Không có quyền riêng cho ảnh** — ai nộp được phiếu thì chụp được ảnh |
| `GET /dms/form-photos/{token}` | `/dms/form-submission/index` **hoặc** `/dms/form-submission/create` | Người quản lý xem dữ liệu và nhân viên nộp phiếu đều qua được |
| `GET /dms/form-photos/public/{token}` | — | Không cần đăng nhập |

Ống ảnh này chỉ mở cho **nhân sự nội bộ**; tài khoản người ngoài (đối tác) không dùng được.
Thiếu quyền ⇒ `403`; thiếu/hết hạn token ⇒ `401`.

---

## 9. Việc app phải làm — danh sách kiểm

- [ ] Parse `config` **phòng thủ** (`[]` hay `{}`), lấy `max_files`, mặc định 1, kẹp trần 10.
- [ ] Widget chụp/chọn ảnh, hiện ảnh thu nhỏ bằng `data.url` trả về sau khi tải lên.
- [ ] Tải **từng tấm** lên `POST /dms/form-photos`, phần multipart tên `file`, nén xuống dưới 10 MB.
- [ ] Gửi **mảng token** trong `answers`; ô trống thì bỏ khoá.
- [ ] `client_uuid` là **UUID v4** thật.
- [ ] Giữ **tệp ảnh gốc** trong hàng đợi ngoại tuyến; gặp lỗi "không tìm thấy ảnh" thì tải lại rồi nộp lại.
- [ ] Hiểu `duplicate: true` là **thành công**.
- [ ] Màn xem lại phiếu: lấy đường ảnh từ `answer_photos`, token thiếu ⇒ báo "ảnh không còn trên hệ thống".

🔴 **Chưa làm kịp thì báo lại ngay.** Người vận hành bỏ tick `image` ở `/system/settings/dms` (khoá
`form_supported_input_types`) là chặn không cho gán ô ảnh vào biểu mẫu mới — không cần sửa mã, không
cần bản app mới. Để nguyên mà app chưa vẽ thì nhân viên đứng ngoài thị trường thấy một **ô trắng**
không điền được và **không có lỗi nào báo**.

⚠️ Bỏ tick **không** gỡ ô ảnh khỏi biểu mẫu đã gán trước đó (hàng rào chỉ chạy lúc gán) — phải sửa lại
từng cấu hình đang dùng.

---

## 10. Trạng thái prod 09/10/2026

| Hạng mục | Trạng thái |
|---|---|
| Backend (3 endpoint ảnh, validate, hàng rào ngữ cảnh) | ✅ chạy trên prod |
| `image` trong danh sách loại ô app vẽ được | ✅ bật (mặc định, chưa ai ghi đè ở `sys_setting`) |
| Màn soạn biểu mẫu trên web (chọn kiểu Ảnh + khai số ảnh) | ✅ có |
| **Ô ảnh thực tế trên prod** | **0** — chưa admin nào tạo ô ảnh nào (`fld_field` prod: 0 dòng `input_type='image'`) |
| Cron dọn tệp mồ côi `file-gc/run` | ⏸ đang TẮT (xem §5) |
| Xuất Excel dữ liệu biểu mẫu | in `"N ảnh"`, **chưa** in link — chờ chủ hệ thống quyết |

Nghĩa là app **làm trước được ngay**: tạo ô ảnh thử trên `app_test` rồi chạy đúng kịch bản §9, prod sẽ
có ô ảnh khi người vận hành cần.

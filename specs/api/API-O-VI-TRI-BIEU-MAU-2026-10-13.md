# Ô ĐỊA CHỈ + TOẠ ĐỘ GPS (`location`) trong biểu mẫu — việc app di động phải làm

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <token>` · viết 13/10/2026.

Loại ô mới **`input_type = "location"`** đã **bật trên prod ngày 13/10/2026** ở **hai** nơi:

| Nơi | Schema app đọc | App ghi giá trị qua |
|---|---|---|
| Biểu mẫu thị trường (DMS) | `GET /dms/forms/available` → `schema.blocks[]` | `POST /dms/form-submissions` → `answers` |
| Biểu mẫu điểm bán (CRM) | `GET /crm/customer-form/schema` → `fields[]` | `POST /crm/customers` · `PATCH /crm/customers/{id}` → `data` |

`POST /crm/customers` đi qua cùng bộ kiểm với `PATCH` (cùng `FormValidator`) nhưng lần đo này chỉ chạy `PATCH`.

🔴 **App phải vẽ được ô này TRƯỚC khi admin dùng nó.** Server đã cho admin thêm ô `location` vào biểu mẫu;
bản app chưa vẽ được thì nhân viên ngoài thị trường thấy **ô trắng không điền được** — và nếu ô đó bắt buộc
thì **không nộp được phiếu**. Làm xong thì báo lại để chủ hệ thống cho admin bắt đầu dùng.

**Việc cho app** — ngoài ra **không có gì đổi** (đường dẫn, payload, ô cũ giữ nguyên):

1. Vẽ widget vị trí cho ô có `input_type = "location"` (§2).
2. Gửi giá trị là **MỘT object** `{address, lat, lng, accuracy, mock}` (§3).
3. Hiện lại giá trị đã lưu ở màn xem (§5).
4. (Nhỏ) Mô tả "Dữ liệu gốc MobiWork…" của các ô điểm bán đã bị xoá — `description` nay là `null` (§7).

Tài liệu nền: [`API-BIEU-MAU-THI-TRUONG-2026-09-23.md`](API-BIEU-MAU-THI-TRUONG-2026-09-23.md) ·
[`API-BIEU-MAU-DIEM-BAN-2026-09-16.md`](API-BIEU-MAU-DIEM-BAN-2026-09-16.md) ·
[`API-SUA-DIEM-BAN-2026-09-16.md`](API-SUA-DIEM-BAN-2026-09-16.md) ·
[`API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md`](API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md).

> Mọi phản hồi dưới đây **đo thật ngày 13/10/2026** trên `app_test` bằng tài khoản `TEST001`: biểu mẫu
> thị trường `zz_testcc_diemban` (config_id 435) gắn tạm ô `dms_dms_test_cc_vi_tri` (bắt buộc), và điểm
> bán id 6 với ô động tạm `test_cc_vi_tri_2`. Ô tạm đã gỡ sau khi đo — không phải ví dụ bịa.

---

## 1. Nhận ra ô vị trí trong schema

**Biểu mẫu thị trường** — một block như mọi ô khác (`GET /dms/forms/available?kind=collect`):

```json
{
  "type": "field",
  "ref": "dms_dms_test_cc_vi_tri",
  "required": true,
  "col_span": 12,
  "resolved": {
    "code": "dms_dms_test_cc_vi_tri",
    "label": "[TEST-CC] Vị trí cửa hàng",
    "input_type": "location",
    "config": [],
    "description": null,
    "show_in_list": false
  }
}
```

**Biểu mẫu điểm bán** — một phần tử của `fields[]` (`GET /crm/customer-form/schema`):

```json
{
  "kind": "dynamic",
  "code": "test_cc_vi_tri_2",
  "label": "[TEST-CC] Vị trí kho",
  "input_type": "location",
  "description": null,
  "required": false,
  "read_only": false,
  "source": "own",
  "legacy_key": null,
  "catalog": null,
  "min_length": null,
  "max_length": null,
  "min": null,
  "max": null,
  "options": [],
  "max_files": null
}
```

* Khoá để ghi giá trị = `resolved.code` (DMS) / `code` (CRM) — **lấy đúng từ schema**, server có thể tự thêm
  tiền tố (`dms_…`) vào mã admin gõ.
* `required`, `read_only` (CRM), `show_if` (DMS, cấp block) áp như mọi ô khác.
* `max_length` (nếu admin khai) áp cho phần **địa chỉ**; không khai thì trần 500 ký tự.

---

## 2. Vẽ widget

Chủ hệ thống chốt 13/10/2026: **toạ độ lấy từ GPS của máy tại chỗ, không cho gõ tay**; địa chỉ gõ tay.

```
┌──────────────────────────────────────────────┐
│ Vị trí cửa hàng *                              │
│ ┌──────────────────────────────────────────┐ │
│ │ 12 Lý Thường Kiệt, Hoàn Kiếm             │ │  ← ô gõ địa chỉ (tuỳ chọn)
│ └──────────────────────────────────────────┘ │
│ [◎ Lấy vị trí]   📍 21.0285123, 105.8542 (±8 m) │  ← nút + toạ độ đã lấy
└──────────────────────────────────────────────┘
```

| Phần | Luật |
|---|---|
| Ô địa chỉ | Tuỳ chọn, ≤ 500 ký tự (hoặc `max_length`). Có thể gợi ý sẵn từ reverse-geocode nếu app đã có, người dùng sửa được. |
| Nút "Lấy vị trí" | Lấy vị trí **độ chính xác cao**, **mới** (không dùng vị trí cache cũ). Đã có toạ độ thì nút thành "Lấy lại vị trí". |
| Toạ độ | Chỉ hiển thị, không cho sửa tay. Hiện kèm `±accuracy m` để người điền biết GPS đang tốt hay kém. |
| Không có quyền vị trí / tắt GPS | Báo người dùng bật, **không** gửi toạ độ giả 0,0. |
| `read_only = true` (CRM) | Chỉ hiển thị (§5), ẩn nút và ô gõ. |

🔴 **`mock` phải là thật.** Gửi `true` khi hệ điều hành báo vị trí giả lập (Android `Location.isMock()` /
`isFromMockProvider()`; iOS 15+ `CLLocation.sourceInformation.isSimulatedBySoftware`). Server **không chặn**,
chỉ lưu làm cờ — báo cáo hiện chữ "GPS giả" cạnh toạ độ. Cùng tinh thần "GPS giả luôn gắn cờ" của check-in.

---

## 3. Giá trị gửi lên

MỘT object, khoá = mã ô:

```json
"dms_dms_test_cc_vi_tri": {
  "address": "12 Lý Thường Kiệt, Hoàn Kiếm",
  "lat": 21.028512345,
  "lng": 105.8542,
  "accuracy": 8.26,
  "mock": false
}
```

| Khoá | Bắt buộc | Kiểu · luật |
|---|---|---|
| `lat` | **có** khi ô có giá trị | số (chuỗi số cũng nhận), −90…90 |
| `lng` | **có** khi ô có giá trị | số, −180…180. `lat`/`lng` đi theo **cặp** |
| `address` | không | chuỗi, ≤ 500 ký tự (hoặc `max_length`) |
| `accuracy` | không | mét, ≥ 0 |
| `mock` | không | bool, mặc định `false` |

Server **chuẩn hoá** trước khi lưu: `lat`/`lng` làm tròn **7 số thập phân** (≈ 1 cm), `accuracy` 1 số,
`address` trim (rỗng ⇒ `null`), **bỏ mọi khoá khác** (độ cao, tốc độ, hướng… gửi lên cũng không lưu).

**Để trống ô:**

* Biểu mẫu thị trường: **bỏ khoá** khỏi `answers` (luật chung §2 tài liệu nền). `null` hoặc object rỗng
  `{address:"", lat:null, lng:null}` cũng được coi là trống.
* Điểm bán `PATCH`: gửi `"<mã ô>": null` là **xoá** giá trị; **không gửi khoá** là giữ nguyên (ngữ nghĩa PATCH).

**Ngoại tuyến:** không có bước tải lên riêng (khác ô ảnh) — lưu nguyên object vào hàng đợi, toạ độ là toạ độ
**lúc bấm nút**, không lấy lại lúc đồng bộ.

---

## 4. Lỗi (đo thật)

Mọi lỗi trả **HTTP 400**, `success: false`, câu lỗi ở `message` (nêu đúng nhãn ô):

| Gửi | `message` |
|---|---|
| Ô bắt buộc mà không gửi / `null` / object rỗng | `"<Nhãn> không được để trống."` |
| Chỉ có `address`, hoặc chỉ một nửa toạ độ | `"<Nhãn> cần có toạ độ GPS — bấm "Lấy vị trí"."` |
| Toạ độ ngoài miền (`lat: 121`) · chuỗi `"21.0285,105.8542"` thay vì object · `accuracy` âm | `"<Nhãn> có giá trị không hợp lệ."` |

Thành công:

```json
// POST /dms/form-submissions                       → 201
{ "success": true, "message": "Đã nộp 1 câu trả lời.", "data": { "id": 1475, "duplicate": false } }

// PATCH /crm/customers/6                            → 200
{ "success": true, "message": "Đã cập nhật 1 trường.",
  "data": { "id": 6, "changed": ["data"], "overwritten_on_next_sync": [] } }
```

---

## 5. Đọc lại giá trị đã lưu

Giá trị trả về đúng object đã chuẩn hoá (thứ tự khoá không cố định):

```json
// GET /dms/form-submissions/1475 → data.answers
{ "dms_dms_test_cc_vi_tri": { "lat": 21.0285123, "lng": 105.8542, "mock": true,
                               "address": "[TEST-CC] 12 Lý Thường Kiệt, Hoàn Kiếm", "accuracy": 8.3 } }
```

Điểm bán: `GET /crm/customers/{id}` → `data.dynamic_fields[]` phần tử có `input_type: "location"`, `value`
là object như trên (hoặc `null` khi trống).

Hiển thị gợi ý: `địa chỉ · vĩ, kinh (±m) · GPS giả`, bấm mở bản đồ
(`https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`) — đúng cách web đang hiện.

---

## 6. Đừng nhầm với các toạ độ khác

| Thứ | Là gì |
|---|---|
| Ô `location` (tài liệu này) | Câu trả lời do admin **thêm vào biểu mẫu** — vd "vị trí kho", "vị trí cửa hàng đối thủ" |
| `submit_lat` / `submit_lng` của phiếu DMS | Vị trí **máy lúc nộp phiếu** — app vẫn gửi như cũ, không đổi |
| Cột cứng `address` / `lat` / `lng` của điểm bán | Vị trí **chính thức** của điểm bán (geofence check-in) — không đổi |

---

## 7. Thay đổi nhỏ khác (13/10/2026)

**Mô tả "Dữ liệu gốc MobiWork, khoá …" đã bị xoá** khỏi các ô động của điểm bán nhận từ dữ liệu cũ (8 ô
trên prod: `mw_ma_erp`, `mw_khach_hang_vthm`, `mw_nhan_1`… ). Chủ hệ thống chốt: dữ liệu đã vào One thì One
quản lý, không gắn nhãn nguồn MobiWork. Trong `GET /crm/customer-form/schema` các ô đó nay có
`description: null`. App **không cần sửa gì** nếu đang hiện `description` khi có giá trị — chỉ đừng tự
dựng lại nhãn "MobiWork" từ `source: "mobiwork"` / `legacy_key` (hai trường này vẫn còn, dùng nội bộ).

---

## 8. Checklist nghiệm thu cho app

- [ ] Biểu mẫu thị trường có ô `location` bắt buộc: không lấy vị trí ⇒ app chặn trước khi nộp (hoặc hiện đúng câu lỗi 400).
- [ ] Bấm "Lấy vị trí" ⇒ hiện toạ độ + `±m`; nộp ⇒ 201, xem lại phiếu ra đúng object.
- [ ] Bật giả lập vị trí ⇒ gửi `mock: true`.
- [ ] Mất mạng: điền ô vị trí, nộp, có mạng lại ⇒ phiếu lên với toạ độ lúc bấm nút.
- [ ] Sửa điểm bán: điền ô vị trí ⇒ 200; xoá ô (gửi `null`) ⇒ `value: null` khi đọc lại.
- [ ] Ô `read_only` chỉ hiển thị; ô ẩn theo `show_if` không gửi giá trị.

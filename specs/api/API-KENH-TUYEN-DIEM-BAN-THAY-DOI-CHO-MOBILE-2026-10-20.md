# Thay đổi API ngày 20/10/2026 — Kênh/Tuyến điểm bán theo Bravo, bỏ "kênh" MobiWork cũ (`channel_id`)

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi** và app DMS cần làm gì. JSON dưới đây là phản hồi **thật**, gọi bằng `curl`
trên bản sao dữ liệu (`app_test`) ngày 20/10/2026 bằng tài khoản nhân viên thị trường thật (đã rút gọn khoá không liên
quan). Việc trong sổ: **#23682**.

> 🔴 **Hiệu lực trên prod:** khi bản API commit `420ca893` được deploy (chưa deploy lúc viết tài liệu này). Bản app cũ
> **vẫn chạy được** (không khoá nào bị xoá ở đợt này), nhưng điều kiện hiển thị dùng kênh mới sẽ **không trúng** trên
> app cũ — xem §2.

| # | Thay đổi | Loại | App phải làm |
|---|---|---|---|
| 1 | "Kênh" của điểm bán là **kênh Bravo** (KPP, KBL, KDA…) + **Tuyến** (MB1…OEM), lấy từ `erp_channels` / `territories`. Khoá cũ `channel_id` / `channel_name` (kênh MobiWork) **thôi dùng** | **ĐỔI NGHĨA** | Hiện Kênh/Tuyến từ khoá mới; ngừng đọc `channel_id`, `channel_name` (§1) |
| 2 | Biến điều kiện hiển thị `@customer.channel_id` **gỡ**, thay bằng **hai biến DANH SÁCH** `@customer.channel_ids`, `@customer.territory_codes` | **ĐỔI BIẾN** | Dựng hai biến mới khi đánh giá `show_if`; thôi dựng `channel_id` (§2) |
| 3 | Tạo/sửa điểm bán: server **bỏ qua** `channel_id` gửi lên (đã có từ 19/10) | **NGỪNG GHI** | Thôi gửi `channel_id` (§3) |
| 4 | `GET /dms/forms/available` lọc thêm theo cặp (Kênh, Tuyến) — server tự lọc | **ĐỔI HÀNH VI** | Không làm gì (§4) |

---

## 1. Kênh và Tuyến của điểm bán

### 1.1 Nghiệp vụ (chủ hệ thống chốt 19–20/10/2026)

* **Kênh** = kênh Bravo: `KPP` Kênh phân phối, `KBL` Kênh bán lẻ, `KDA` Kênh dự án, `KNB` Kênh nội bộ… **Tuyến** = tuyến
  kinh doanh Bravo: `MB1 MB2 MB3 MT1 MT2 MN1 MN2 KA OEM`.
* "Kênh" cũ trên app (`MB1`, `MN2, CN Cần Thơ`, `BHDA`…) thực chất là **tuyến/khu vực MobiWork** — đã chuyển sang Tuyến.
* Một điểm bán có thể thuộc **NHIỀU kênh** và **nhiều tuyến**:
  * Điểm bán **đã nối khách ERP**: kênh = kênh của các khách ERP đã nối; tuyến = tuyến Bravo của khách đó (thiếu thì
    tuyến tự khai của điểm bán).
  * Điểm bán **chưa nối** (tiềm năng): kênh tự khai (`own_channel_ids`, có thể nhiều) + tuyến tự khai (`territory_code`).

### 1.2 Khoá trong `GET /crm/customers/mine` và `GET /crm/customers/{id}`

| Khoá | Kiểu | Ý nghĩa |
|---|---|---|
| `erp_channels` | `[{id, code, name}]` | **Kênh hiện hành** — dùng để HIỂN THỊ và dựng `@customer.channel_ids` |
| `territories` | `string[]` | **Tuyến hiện hành** — dùng để HIỂN THỊ và dựng `@customer.territory_codes` |
| `erp_linked` | `bool` | Đã nối khách ERP chưa |
| `territory_code` | `string\|null` | Tuyến TỰ KHAI (ô sửa) — không phải tuyến hiện hành khi đã nối |
| `own_channel_ids` | `int[]` | Kênh TỰ KHAI (ô sửa) — bị bỏ qua khi đã nối |
| ~~`channel_id`~~, ~~`channel_name`~~ | | Kênh MobiWork cũ — **còn trả để app cũ không vỡ, sẽ XOÁ ở bước 2**. Đừng đọc |

Mẫu thật (rút gọn):

```json
GET /crm/customers/mine?per-page=200
{"success":true,"data":[
  {"id":3108,"code":"02950076","erp_linked":true,
   "erp_channels":[{"id":4,"code":"KBL","name":"Kênh bán lẻ"}],
   "territories":["MN2"],"territory_code":"MN2","own_channel_ids":[4]},

  {"id":1132,"code":"08660056","erp_linked":false,
   "erp_channels":[{"id":1,"code":"KPP","name":"Kênh phân phối"},{"id":4,"code":"KBL","name":"Kênh bán lẻ"}],
   "territories":["MN2"],"territory_code":"MN2","own_channel_ids":[1,4],
   "channel_id":8,"channel_name":"MN2, CN Cần Thơ"},

  {"id":1895,"code":"08880188","erp_linked":false,
   "erp_channels":[{"id":6,"code":"KNB","name":"Kênh nội bộ"}],
   "territories":[],"territory_code":null,"own_channel_ids":[6]}
]}
```

Điểm bán `1132` cho thấy vì sao phải đổi: khoá cũ nói một giá trị ghép `"MN2, CN Cần Thơ"`, khoá mới tách đúng nghĩa
**KPP + KBL, tuyến MN2**.

**Gợi ý hiển thị:** `KPP, KBL · MN2` (nối `erp_channels[].code` bằng `, `, rồi `·`, rồi nối `territories`). Mảng rỗng ⇒
không hiện phần đó (đừng hiện `null`/`[]`).

---

## 2. Điều kiện hiển thị biểu mẫu — biến ngữ cảnh mới

Hợp đồng đầy đủ: [`API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md`](API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md) §4
(đã cập nhật). Phần đổi:

| Biến | Giá trị | App dựng từ |
|---|---|---|
| `@customer.type_id` | số \| `null` | không đổi |
| `@customer.region_id` | số \| `null` | không đổi |
| `@customer.group_id` | số \| `null` | không đổi |
| ~~`@customer.channel_id`~~ | | **GỠ** — thôi dựng |
| `@customer.channel_ids` | **mảng số** | `erp_channels.map(c => c.id)` của điểm bán đang check-in |
| `@customer.territory_codes` | **mảng chuỗi** | `territories` của điểm bán đang check-in |

* Chưa có kênh/tuyến ⇒ mảng **rỗng `[]`**, không phải `null`.
* Phiếu `collect` mở từ menu chính (không có điểm bán) ⇒ không dựng biến nào — như cũ.
* Dựng ở **map ngữ cảnh riêng**, KHÔNG gửi trong `answers` (server tự dựng lại từ DB và ghi đè).

### 2.1 Toán tử với biến MẢNG

Trình soạn trên web chỉ cho chọn 5 toán tử với hai biến này. App phải đánh giá **đúng như server**
(`RuleEvaluator`) — lệch là app hiện ô mà server đòi/không đòi khác đi:

| `op` | `value` | Đúng khi |
|---|---|---|
| `in` | mảng | mảng thực tế và `value` có **ít nhất một** phần tử chung |
| `not_in` | mảng | **không có** phần tử chung |
| `contains` | một giá trị | mảng thực tế **chứa** giá trị đó |
| `is_empty` | — | mảng rỗng |
| `not_empty` | — | mảng có phần tử |

So sánh phần tử: số so theo giá trị số (`1` = `"1"`), chuỗi so nguyên văn (`"MB1"`). Ví dụ điều kiện thật:

```json
{"all":[
  {"field":"@customer.channel_ids","op":"in","value":[1,4]},
  {"field":"@customer.territory_codes","op":"contains","value":"MN2"}
]}
```

Điểm bán `1132` ở §1.2 (`channel_ids=[1,4]`, `territory_codes=["MN2"]`) ⇒ **hiện**; điểm bán `1895`
(`[6]`, `[]`) ⇒ **ẩn**.

Mã Dart gợi ý (bổ sung vào bộ đánh giá hiện có — nhánh `actual is List`):

```dart
bool inList(dynamic actual, List expected) {
  final items = actual is List ? actual : [actual];
  return items.any((a) => expected.any((e) => looseEquals(a, e)));
}
// 'in'       => value is List && inList(actual, value)
// 'not_in'   => value is List && !inList(actual, value)
// 'contains' => actual is List ? inList(actual, [value]) : /* chuỗi chứa chuỗi như cũ */
// 'is_empty' => actual == null || (actual is List && actual.isEmpty) || (actual is String && actual.trim().isEmpty)
```

### 2.2 App cũ (chưa cập nhật) sẽ ra sao

App cũ không dựng hai biến mới ⇒ coi là rỗng ⇒ điều kiện `in`/`contains` theo kênh/tuyến **luôn ẩn** mục đó trên app,
trong khi server có thể đòi điền (ô bắt buộc trong mục đang hiện theo server) ⇒ nộp phiếu nhận **422** "thiếu ô". Prod
20/10/2026 **chưa có biểu mẫu nào** dùng điều kiện kênh/tuyến, nên rủi ro chỉ xuất hiện khi quản trị bắt đầu dùng —
cần phát hành app mới trước khi quản trị khai điều kiện loại này.

---

## 3. Tạo / sửa điểm bán

`POST /crm/customers`, `PATCH /crm/customers/{id}`: khoá `channel_id` gửi lên **bị bỏ qua** (không lỗi, không ghi) — có
hiệu lực từ 19/10/2026. App bỏ ô chọn "Kênh" cũ (danh mục `crm_channel`) và thôi gửi `channel_id`. Kênh/tuyến của điểm
bán mới do server tự gán theo phòng của người tạo, người duyệt chỉnh lại trên web — app **không cần** gửi
`own_channel_ids` / `territory_code`.

---

## 4. `GET /dms/forms/available` — không đổi hình dạng

Quản trị nay giới hạn biểu mẫu khảo sát theo **Kênh** và **Tuyến** (thay cho "Kênh" cũ). Server khớp theo **CẶP**
(kênh, tuyến) của điểm bán: điểm bán thuộc KPP·MN2 và KBL·MB1 **không** nhận biểu mẫu khai "KPP + MB1". App vẫn gọi
`GET /dms/forms/available?kind=survey&customer_id=<id>` như cũ, **không tự lọc**.

---

## 5. Lịch gỡ hẳn (bước 2)

Sau khi app bản mới phát hành và không còn gửi/đọc kênh cũ, server sẽ **xoá** khoá `channel_id`, `channel_name` khỏi
phản hồi điểm bán và gỡ danh mục kênh cũ. Báo lại đội backend (sổ việc **#23682**) khi app bản mới đã lên store để
mở bước này.

## Checklist cho đội app

- [ ] Hiện Kênh/Tuyến điểm bán từ `erp_channels` + `territories` (§1.2); thôi đọc `channel_id`, `channel_name`
- [ ] Dựng `@customer.channel_ids` (mảng số) + `@customer.territory_codes` (mảng chuỗi); thôi dựng `@customer.channel_id`
- [ ] Bộ đánh giá `show_if` xử lý `in` / `not_in` / `contains` / `is_empty` / `not_empty` với giá trị MẢNG (§2.1)
- [ ] Bỏ ô "Kênh" cũ ở màn tạo/sửa điểm bán, thôi gửi `channel_id` (§3)
- [ ] Báo backend khi bản mới lên store (§5)

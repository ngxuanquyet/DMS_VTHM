# Điều kiện hiển thị `show_if` — việc app di động phải làm

**Viết 25/09/2026 · đã lên prod cùng ngày** (commit `6498ae79`).
Bổ sung cho [`API-BIEU-MAU-THI-TRUONG-2026-09-23.md`](API-BIEU-MAU-THI-TRUONG-2026-09-23.md) — đọc file đó
trước để biết hai endpoint `GET /dms/forms/available` và `POST /dms/form-submissions`.

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <token>`

---

## 0. Tóm tắt trong một trang

Admin nay khai được điều kiện hiển thị cho **một ô** hoặc cho **cả một MỤC**. Ví dụ có thật:

> Ô *"Lý do viếng thăm"* có A / B / C. Admin khai: **nếu lý do là B hoặc C thì hiện mục "Trưng bày"**
> (gồm 3 ô). Chọn A ⇒ cả mục ẩn, và nhân viên **không phải điền** kể cả ô đánh dấu bắt buộc trong đó.

| Việc | Ai làm |
|---|---|
| Tính "ô này thuộc mục nào" và AND điều kiện mục với điều kiện riêng | **Server** — app KHÔNG phải suy |
| Đánh giá cây điều kiện khi người dùng gõ | **App** |
| Ẩn/hiện ô **và** ô trình bày (`heading`/`divider`/`note`) theo kết quả | **App** |
| Không đòi "bắt buộc" với ô đang ẩn | **App** (server cũng đã miễn, xem §5) |
| Dựng biến ngữ cảnh `@customer.*` từ điểm bán đang check-in | **App** |

🔴 **App bỏ qua `show_if` thì nhân viên thấy TRỌN biểu mẫu**, kể cả mục lẽ ra phải ẩn — và **server vẫn
nhận phiếu**: ô ẩn chỉ được *miễn* bắt buộc, không bị *cấm* gửi giá trị. Không có lỗi nào báo, dữ liệu sai
lặng lẽ vào báo cáo.

---

## 1. `show_if` nằm ở đâu

Trong chính lượt `GET /dms/forms/available` đã dùng — không có endpoint mới, không có tham số mới:

```
data[].schema.blocks[].show_if
```

Vắng khoá `show_if` (hoặc `null`) = **luôn hiện**.

### Ví dụ thật (cắt từ một lượt gọi ngày 25/09/2026)

```json
{
  "schema": {
    "blocks": [
      {
        "type": "field", "ref": "dms_ly_do_vt", "required": false, "col_span": 12,
        "resolved": {
          "code": "dms_ly_do_vt", "label": "Lý do viếng thăm", "input_type": "select",
          "config": { "options": [
            { "label": "A", "value": "A" }, { "label": "B", "value": "B" }, { "label": "C", "value": "C" }
          ] }
        }
      },
      {
        "type": "field", "ref": "dms_muc_trung_bay", "required": false, "col_span": 12,
        "show_if": { "any": [ { "field": "dms_ly_do_vt", "op": "in", "value": ["B", "C"] } ] },
        "resolved": { "code": "dms_muc_trung_bay", "label": "Trưng bày", "input_type": "heading" }
      },
      {
        "type": "field", "ref": "dms_so_ke", "required": true, "col_span": 12,
        "show_if": { "any": [ { "field": "dms_ly_do_vt", "op": "in", "value": ["B", "C"] } ] },
        "resolved": { "code": "dms_so_ke", "label": "Số kệ", "input_type": "number" }
      },
      {
        "type": "field", "ref": "dms_ton_kho", "required": true, "col_span": 12,
        "show_if": { "all": [ { "field": "@customer.type_id", "op": "in", "value": [2] } ] },
        "resolved": { "code": "dms_ton_kho", "label": "Tồn kho", "input_type": "number" }
      }
    ]
  }
}
```

🔴 **Điều kiện của MỤC đã được server LAN sẵn xuống từng ô.** Ở ví dụ trên, ô `dms_so_ke` mang đúng điều
kiện của tiêu đề `dms_muc_trung_bay` mặc dù admin chỉ khai một lần ở dòng tiêu đề. **App đọc thẳng
`block.show_if`, đừng tự đi tìm tiêu đề mục phía trên.**

Nếu một ô vừa thuộc mục có điều kiện, vừa có điều kiện riêng, server gửi xuống dạng đã gộp:

```json
"show_if": { "all": [ { "any": [ … ] },        // điều kiện của MỤC
                      { "all": [ … ] } ] }     // điều kiện RIÊNG của ô
```

---

## 2. Ngữ nghĩa cây điều kiện

Ba hình dạng, lồng nhau tối đa **3 tầng**:

| Hình dạng | Nghĩa |
|---|---|
| `{ "all": [ … ] }` | **AND** — mọi nhánh con phải đúng |
| `{ "any": [ … ] }` | **OR** — chỉ cần một nhánh đúng |
| `{ "field": …, "op": …, "value": … }` | **lá** — một phép so sánh |
| `[ … ]` (mảng tuần tự, không có `all`/`any`) | **AND ngầm** — hiểu như `all` |

`null` / vắng mặt / `{}` ⇒ **true** (luôn hiện).

### Toán tử

| `op` | Nghĩa | `value` |
|---|---|---|
| `=` · `!=` | bằng / khác | vô hướng |
| `>` · `>=` · `<` · `<=` | so sánh thứ tự | số, hoặc chuỗi ngày ISO |
| `in` · `not_in` | thuộc / không thuộc danh sách | **mảng** |
| `contains` | chuỗi chứa, hoặc mảng có phần tử | vô hướng |
| `between` | trong khoảng **đóng** `[a, b]` | mảng đúng **2** phần tử |
| `is_empty` · `not_empty` | rỗng / khác rỗng | **không có** `value` |

### Bốn luật so sánh — sai một cái là app và server cho kết quả khác nhau

1. **`0`, `"0"`, `false` KHÔNG phải rỗng.** Chỉ `null`, chuỗi rỗng (sau khi trim) và mảng rỗng là rỗng.
   Số tiền 0 là giá trị thật.
2. **So bằng thì nới kiểu số ↔ chuỗi**: `"2"` và `2` là bằng nhau. So thứ tự: ưu tiên số; không phải số
   thì so chuỗi (ngày ISO `2026-09-25` so chuỗi vẫn đúng thứ tự).
3. **`op` lạ, lá thiếu `field`, hoặc object không có `all`/`any`/`field` ⇒ trả `false`, KHÔNG ném lỗi.**
   Cấu hình hỏng chỉ làm một nhánh không trúng; nó **không được** làm chết biểu mẫu của nhân viên đang
   đứng ngoài thị trường.
4. **Biến không tồn tại ⇒ RỖNG**, không phải lỗi.

---

## 3. 🔴 Ô ẩn được coi là RỖNG khi xét ô ĐỨNG SAU

Duyệt `blocks` **theo đúng thứ tự server trả về**, giữ một tập `hidden`. Khi đánh giá điều kiện, giá trị
của một ô đã nằm trong `hidden` phải đọc ra là `null` — **kể cả khi ô đó vẫn còn giá trị người dùng nhập
lúc trước**.

Ví dụ: A → B (`hiện khi A = "có"`) → C (`hiện khi B khác rỗng`). Người dùng nhập B rồi quay lại đổi A
thành "không": B ẩn ⇒ B coi như rỗng ⇒ **C cũng phải ẩn theo**.

⚠️ **Giá trị của ô ẩn KHÔNG bị xoá** — người dùng đổi ý một lần nữa thì nó còn nguyên. Chỉ *coi như rỗng
khi đánh giá điều kiện*, và không gửi lên khi nộp.

Server làm đúng như vậy (`FormValidator::hiddenCodes()`), nên app làm khác đi là hai bên bất đồng: app ẩn
ô mà server vẫn đòi, hoặc ngược lại.

---

## 4. Biến ngữ cảnh `@customer.*` — app phải tự dựng

Điều kiện được phép tham chiếu **thuộc tính của điểm bán đang viếng thăm**, không chỉ câu trả lời:

| Biến | Giá trị | Lấy từ đâu |
|---|---|---|
| `@customer.type_id` | id **Loại điểm bán** | `crm_customer.customer_type_id` của điểm bán đang check-in |
| `@customer.channel_id` | id **Kênh bán** | `crm_customer.channel_id` |
| `@customer.region_id` | id **Khu vực** | `crm_customer.region_id` |
| `@customer.group_id` | id **Nhóm khách hàng** | `crm_customer.customer_group_id` |

Giá trị luôn là **số** (hoặc `null` khi điểm bán chưa khai thuộc tính đó).

Khi đánh giá `{"field": "@customer.type_id"}`, app tra trong một map ngữ cảnh riêng, **không** tra trong
câu trả lời. Tiền tố `@` không bao giờ đụng mã ô — mã ô luôn khớp `/^[a-z][a-z0-9_]*$/`.

* **Phiếu `survey`** (mở trong luồng check-in): luôn có điểm bán ⇒ dựng đủ 4 biến.
* **Phiếu `collect`** (mở từ menu chính): thường **không** có điểm bán ⇒ cả 4 biến là `null` ⇒ điều kiện
  dựa vào chúng **không trúng** và mục đó ẩn. Đúng chủ ý: *không biết đang ở đâu thì không hiện*.

🔴 **KHÔNG gửi `@customer` trong `answers`.** Server dựng ngữ cảnh từ DB theo `customer_id` của phiếu và
**luôn ghi đè** thứ client gửi. Gửi lên chỉ tổ làm payload nặng thêm, không đổi được gì.

---

## 5. Nộp phiếu — server kiểm những gì

Không đổi endpoint, không đổi payload (`POST /dms/form-submissions`). Chỉ khác ở luật kiểm:

| Trường hợp | Kết quả |
|---|---|
| Ô bắt buộc đang **ẩn**, không gửi giá trị | ✅ **201** — được miễn |
| Ô bắt buộc đang **hiện**, không gửi giá trị | ❌ **400** · `"<nhãn ô> không được để trống."` |
| Gửi giá trị cho ô đang ẩn | ✅ nhận, giá trị được lưu (không khuyến khích — app nên bỏ hẳn) |
| Gửi kèm khoá `@customer` | bị bỏ qua, ngữ cảnh server thắng |

Server đánh giá `show_if` bằng **chính payload vừa gửi** cộng ngữ cảnh điểm bán, nên app và server phải
cùng kết quả. Nếu app ẩn một ô bắt buộc mà server lại thấy nó đang hiện, nhân viên nhận **400 trỏ vào một
ô không có trên màn hình** và không có cách nào tự gỡ — đó là lý do §2 và §3 phải làm đúng từng chi tiết.

---

## 6. Ô trình bày cũng nghe `show_if`

`heading` / `divider` / `note` không thu dữ liệu, nhưng **vẫn phải ẩn theo điều kiện**. Bỏ sót chỗ này thì
màn hình hiện một tiêu đề mục trơ không có ô nào bên dưới — và với điều kiện gán cho MỤC, đó là ca thường
gặp chứ không phải ngoại lệ. (Bản web đã vấp đúng lỗi này và đã vá.)

---

## 7. Mã tham chiếu

Bản web dùng đúng ngữ nghĩa này, đọc để đối chiếu khi nghi ngờ:

| Việc | File |
|---|---|
| Đánh giá cây rule (client) | `vn.vthmgroup.one/src/lib/dynamicRule.ts` |
| Ẩn/hiện theo tầng + tập `hidden` | `vn.vthmgroup.one/src/components/AppDynamicForm.tsx` → `visibilityMap()` |
| Đánh giá cây rule (server) | `common/modules/formfield/services/RuleEvaluator.php` |
| Miễn `required` cho ô ẩn | `common/modules/formfield/services/FormValidator.php` → `hiddenCodes()` |
| Lan điều kiện theo mục | `common/modules/formfield/services/FormService.php` → `spreadSectionRules()` |
| Dựng `@customer.*` | `common/modules/dms/services/FormSubmissionService.php` → `customerContext()` |

### Khung Dart gợi ý

```dart
/// Trả về map: mã ô → có hiện hay không. Duyệt theo ĐÚNG thứ tự blocks.
Map<String, bool> visibility(
  List<Block> blocks,
  Map<String, dynamic> answers,
  Map<String, dynamic> customerCtx,   // {'@customer': {'type_id': 2, ...}}
) {
  final out = <String, bool>{};
  final hidden = <String>{};

  dynamic read(String path) {
    if (path.startsWith('@')) return _readPath(customerCtx, path);   // tách theo dấu '.'
    return hidden.contains(path) ? null : answers[path];             // ô ẩn ⇒ RỖNG (§3)
  }

  for (final b in blocks) {
    final shown = evalRule(b.showIf, read);                          // null ⇒ true
    final code = b.resolved.code;
    out[code] = shown;
    if (!shown) hidden.add(code);                                    // kể cả ô trình bày (§6)
  }
  return out;
}
```

`evalRule` là bản dịch thẳng của `dynamicRule.ts` — giữ nguyên bốn luật so sánh ở §2.

---

## 8. Kiểm chứng đã làm ở phía server (25/09/2026)

Đo bằng HTTP thật trên `app_test`, biểu mẫu 10250, điểm bán 94 (Nhà phân phối) và 8338 (Đại lý C2):

| Phép đo | Kết quả |
|---|---|
| Schema trả về đã **lan** điều kiện của mục xuống từng ô | ✅ |
| Lý do = A (mục ẩn), bỏ trống ô bắt buộc trong mục | **201** |
| Lý do = B (mục hiện), vẫn bỏ trống | **400** · *"Số kệ không được để trống."* |
| Mục khai `@customer.type_id in [2]`, nộp tại điểm bán **loại 2** | **400** đòi điền |
| …cùng biểu mẫu đó, nộp tại điểm bán **loại 1** | **201** không đòi |

2090 test tự động xanh; PHPStan / PHPCS / cổng FE sạch.

---

## 9. Việc app cần làm — danh sách rút gọn

1. Dịch `dynamicRule.ts` sang Dart, giữ **bốn luật so sánh** ở §2.
2. Duyệt `blocks` theo thứ tự, giữ tập `hidden`, coi ô ẩn là **rỗng** khi xét ô sau (§3).
3. Dựng map `@customer.*` từ điểm bán đang check-in (§4); phiếu `collect` không có điểm bán thì để `null`.
4. Ẩn cả ô trình bày (§6).
5. Không đòi bắt buộc với ô đang ẩn; **không gửi** giá trị của ô ẩn khi nộp.
6. Cache `schema` kèm `show_if` để chạy offline — điều kiện đánh giá hoàn toàn cục bộ, không cần mạng.

**Chưa làm kịp?** Báo lại ngay. Cách chặn tạm duy nhất là người vận hành **gỡ điều kiện** ở màn soạn biểu
mẫu (`/crm/market-form-library`) — không có công tắc tắt tính năng, vì `show_if` là thuộc tính của từng
biểu mẫu chứ không phải một cờ hệ thống.

# Thay đổi API chấm công ngày 06/10/2026 — gửi đội mobile

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 06/10/2026** ở luồng **chấm công bằng app DMS**, và app
cần làm gì. Hợp đồng đầy đủ (toàn bộ endpoint, bảng mã lỗi, 19 phép thử curl) vẫn ở
[`API-CHAM-CONG-MOBILE-2026-10-05.md`](./API-CHAM-CONG-MOBILE-2026-10-05.md) — tài liệu đó **đã được cập
nhật kèm** các thay đổi dưới đây.

Mọi JSON ở đây là phản hồi thật đã gọi bằng `curl` trên bản sao dữ liệu (`app_test`) ngày 06/10/2026.

> 🟢 **KHÔNG có breaking change.** App đang chạy **không phải sửa gì để tiếp tục hoạt động**. Không trường
> nào app phải gửi thêm, không endpoint nào đổi đường dẫn hay phương thức. Mọi thay đổi đều là **khoá mới
> trong phản hồi cũ**, cộng một ca lỗi `500` nay thành `200`.
>
> 🔴 **Nhưng có 5 việc phải sửa để không vỡ về sau** — xem §5. Hai trong số đó (`null` ở toạ độ, `id` khi
> tải ảnh) nếu bỏ qua sẽ **làm hỏng app hoặc mất ảnh bằng chứng**, không phải chỉ xấu giao diện.

| # | Thay đổi | Loại | Endpoint |
|---|---|---|---|
| 1 | `direction` · `direction_label` — chiều Vào/Ra của từng lượt | **THÊM KHOÁ** | `POST punch` · `GET history` |
| 2 | Khối `today` — trạng thái chấm công hôm nay, nhãn nút tiếp theo | **THÊM KHOÁ** | `GET config` |
| 3 | `locations[].kind` — địa điểm kiểu **Mọi nơi** (không ràng buộc vị trí) | **THÊM KHOÁ** | `GET config` |
| 4 | Hai lượt cùng một giây: `500` → `200` kèm lượt đã có | **ĐỔI HÀNH VI** | `POST punch` |

---

## 1. THÊM KHOÁ — chiều Vào/Ra của từng lượt

### Luật

Trong một **ngày công**, server tự gắn nhãn chiều cho từng lượt (chủ hệ thống chốt 06/10/2026):

| Lượt | `direction` | `direction_label` |
|---|---|---|
| **sớm nhất** trong ngày | `"in"` | Vào |
| **muộn nhất** trong ngày | `"out"` | Ra |
| ở giữa | `"mid"` | Giữa ca |
| ngày chỉ có **một** lượt | `"in"` | Vào (đã vào, chưa ra) |
| không thuộc ngày công nào | `null` | `null` |

Hai khoá này có ở **cả** phản hồi `POST punch` lẫn từng phần tử của `GET history` — app dùng **một** kiểu
dữ liệu cho cả hai như trước.

### 🔴 App KHÔNG gửi chiều lên

Body của `POST punch` **không có** trường `direction` — đừng thêm. Chiều là nhãn server **suy ra từ dữ
liệu**, nên nó **thay đổi theo thời gian**: lượt đang là "Ra" sẽ **tụt xuống "Giữa ca"** ngay khi người đó
chấm thêm lần nữa.

> Đo thật 06/10 trên `app_test`: lượt `8729` mang nhãn "Ra"; sau khi lượt `8730` được ghi, `8729` thành
> "Giữa ca".

⇒ **Đừng nhớ đệm `direction_label` rồi hiển thị lại sau.** Đọc lại từ server mỗi lần mở màn lịch sử.

Lý do không cho người dùng tự chọn Vào/Ra bằng hai nút: bấm nhầm thì chiều **sai vĩnh viễn**, mà đợt này cố
ý **không có đường chấm bù**. Nhãn suy ra thì tự đúng lại ở lượt kế tiếp.

### Nhãn tính XUYÊN NGUỒN

Lượt nhập tay của nhân sự và lượt quẹt máy chấm công **cùng ngày** cũng tham gia xác định hai đầu mút.

> Đo thật 06/10: ngày 01/10 của `TEST001` có một lượt `manual` lúc 08:12 ⇒ lượt **app** lúc 17:30:38 nhận
> nhãn **"Giữa ca"**, không phải "Vào".

⇒ App **không tính lại chiều ở phía client được**, vì nó không nhìn thấy lượt từ nguồn khác.

### Khi nào `direction` là `null`

* lượt **đã huỷ**;
* lượt **chưa khớp mã nhân viên**;
* lượt nằm **ngoài cửa sổ ca** của một ngày **đã được tính công** (cửa sổ thật đang áp: **05:00–21:30**).

Ngày **không** được tính công (cuối tuần, ngày không xếp ca) thì cả ngày **vẫn có nhãn bình thường** —
người đi tuyến chấm ngày nghỉ không bị màn hình trắng.

⇒ Hiển thị gạch ngang. **`null` không phải lỗi.**

---

## 2. THÊM KHOÁ — `today`: trạng thái hôm nay để vẽ nút

```
GET /attendance/mobile/config
```

```json
"today": {
  "work_date":         "2026-10-06",
  "punch_count":       3,
  "first_in_at":       "2026-10-06 08:55:40+07",
  "last_out_at":       "2026-10-06 08:56:34+07",
  "next_action":       "out",
  "next_action_label": "Ra"
}
```

| Khoá | Ý nghĩa cho app |
|---|---|
| `next_action_label` | **Hiện thẳng lên nút** — "Vào" hoặc "Ra". Đừng tự dựng chữ |
| `next_action` | `"in"` khi `punch_count = 0`; từ lượt thứ nhất trở đi luôn `"out"` |
| `first_in_at` | Dựng câu "đã vào lúc …" |
| `last_out_at` | `null` khi mới có **một** lượt — lượt đó là giờ Vào, chưa có giờ Ra |
| `work_date` | Ngày công server đang tính, theo giờ Việt Nam |

### 🔴 Đọc trạng thái từ đây, đừng tự suy từ `history`

`history` **chỉ trả lượt nguồn `app`**. Lượt chấm có thể vào hệ thống bằng đường khác (nhân sự nhập tay,
máy chấm công) mà app không nhìn thấy. Tự đếm lượt trong `history` để đoán "vào hay ra" sẽ cho ra nút sai
đúng vào những ca rắc rối nhất.

---

## 3. THÊM KHOÁ — địa điểm kiểu "Mọi nơi"

Mỗi phần tử `locations[]` nay có `kind` và `kind_label`:

| `kind` | Nghĩa |
|---|---|
| `"radius"` | Vùng tròn quanh một toạ độ — như cũ |
| `"everywhere"` | **Chấm ở bất kỳ đâu**, không ràng buộc vị trí — dựng cho đội thị trường đi tuyến |

```json
{"id":16, "code":"MARKET-ANY", "name":"Thị trường – mọi nơi",
 "kind":"everywhere", "kind_label":"Mọi nơi",
 "lat":null, "lng":null, "radius_m":null, "distance_m":null}
```

### 🔴 Với `kind: "everywhere"` thì BỐN khoá đều `null`

`lat` · `lng` · `radius_m` · `distance_m`. Điểm đó **không có tâm** nên không có khoảng cách nào để đo.

* Ép kiểu số thẳng sẽ biến `null` thành `0` và **vẽ ra một địa điểm giữa Đại Tây Dương**;
* Hiện chữ "Mọi nơi" (dùng `kind_label`) thay cho số mét;
* 🔴 **Đừng làm mờ nút chấm** khi danh sách có một dòng `everywhere` — người này được chấm ở bất kỳ đâu.

### Nhóm luật nay chọn theo TỪNG NGƯỜI

Trước 06/10 mọi người chịu chung một nhóm. Nay nhân sự khai quy tắc theo **công ty / phòng ban / chức
danh** (cộng ngoại lệ đích danh) trên màn *Chấm công → Nhóm chấm công*; khớp nhiều nhóm thì nhóm có thứ tự
nhỏ hơn thắng; không khớp nhóm nào thì rơi về **nhóm mặc định**.

Với app **không có gì đổi** — vẫn đọc `group` và `locations` của `config`. Chỉ là **hai người khác nhau nay
có thể nhận hai bộ địa điểm khác nhau** ⇒ 🔴 **đừng nhớ đệm `config` qua nhiều tài khoản** trên cùng một máy.

---

## 4. ĐỔI HÀNH VI — hai lượt trong cùng một giây

`punch_at` ghi **giờ server cắt tới giây**, nên một đợt xả hàng đợi offline có thể gửi nhiều lượt rơi đúng
cùng một giây.

| | Trước 06/10/2026 | Từ 06/10/2026 |
|---|---|---|
| Phản hồi | `500` kèm nguyên văn câu SQL | **`200`** + lượt đang chiếm giây đó + `duplicate: true` |
| DB | không ghi được | không tạo dòng thứ hai |

Giống hệt ca gửi lại cùng `client_uuid` (§3.2 của hợp đồng đầy đủ).

### 🔴 Hệ quả: `id` trả về có thể KHÁC lượt vừa gửi

Và `client_uuid` trong phản hồi **có thể không phải cái app gửi lên** — lượt cũ có thể là lượt **nhân sự
nhập tay**, vốn không có `client_uuid`.

⇒ **Luôn dùng `id` trong phản hồi để tải ảnh lên.** Tự ghép theo `client_uuid` sẽ gửi ảnh vào một lượt
không tồn tại, và **mất ảnh bằng chứng của lượt chấm**.

> Đo thật 06/10: gửi 3 lượt liên tiếp, 2 dòng mới được tạo, lần thứ ba đụng giây ⇒ `200`,
> `duplicate: true`, trả `id: 8732`; DB **không** sinh dòng thứ ba.

---

## 5. Việc BẮT BUỘC phía app

| # | Việc | Bỏ qua thì sao |
|---|---|---|
| 1 | Chịu được `null` ở `lat` · `lng` · `radius_m` · `distance_m` | **App crash** hoặc vẽ địa điểm sai giữa đại dương |
| 2 | Tải ảnh theo `id` **trong phản hồi**, không ghép theo `client_uuid` | **Mất ảnh bằng chứng** của lượt chấm |
| 3 | Vẽ nút từ `today.next_action_label`, không tự đếm `history` | Nút ghi sai chiều ở đúng ca rắc rối |
| 4 | Không nhớ đệm `config` qua nhiều tài khoản trên cùng máy | Người sau nhận bộ địa điểm của người trước |
| 5 | Hiện `direction_label` nguyên văn, chịu được `null`, **không nhớ đệm** | Nhãn cũ hiển thị sai sau khi có lượt mới |

---

## 6. Tình trạng prod hôm nay (06/10/2026)

| Hạng mục | Trạng thái |
|---|---|
| Bốn thay đổi trên | ✅ đã lên prod, đã gọi thật bằng `curl` |
| Địa điểm đã khai | `VVP` và `VHM` — bán kính **200 m**, để trống chi nhánh nên **áp cho mọi đơn vị** |
| Nhóm luật đang bật | `MARKET` — **chặn cứng ngoài vùng**; **chưa có** địa điểm `everywhere` nào |
| Chấm bù / xin điều chỉnh | ❌ không có. Bị chặn là **mất lượt** |

⇒ App thử trên prod hôm nay **chấm được** khi đứng trong bán kính 200 m của `VVP` hoặc `VHM`, và nhận
`422` kèm câu nêu rõ **còn cách bao nhiêu mét** khi đứng ngoài. Đó **không phải lỗi app**.

⚠️ Bản tài liệu 05/10 ghi *"prod chưa khai địa điểm nào, mọi lượt đều 422"* — **câu đó nay đã cũ**, đã sửa
trong hợp đồng đầy đủ.

---

## 7. Hai câu lỗi còn tiếng Anh (nợ từ 05/10, chưa vá)

Ống tải ảnh còn hai câu chưa dịch — `BaseFileController` dịch theo category `attendance` mà
`common/messages/{vi,en}/attendance.php` chưa có hai khoá đó:

* quá 10 MB: `File "big.png" (11264 KB) exceeds maximum size limit 10240 KB.`
* sai đuôi tệp: `Invalid file extension "x.pdf".`

⇒ Hai câu này **hiện nguyên văn tiếng Anh** cho người dùng. App tự dịch sang tiếng Việt cũng được, nhưng
phải biết là chúng sẽ **đổi thành tiếng Việt** khi phía server vá — đừng so khớp chuỗi để bắt lỗi.

---

## 8. Tài liệu liên quan

* [`API-CHAM-CONG-MOBILE-2026-10-05.md`](./API-CHAM-CONG-MOBILE-2026-10-05.md) — **hợp đồng đầy đủ** của
  luồng chấm công bằng app (đã cập nhật kèm các thay đổi trên)
* [`API-VIENG-THAM-MOBILE-2026-09-29.md`](./API-VIENG-THAM-MOBILE-2026-09-29.md) — module viếng thăm, cùng
  khuôn GPS + ảnh + hàng đợi offline
* [`API-THAY-DOI-CHO-MOBILE-2026-10-01.md`](./API-THAY-DOI-CHO-MOBILE-2026-10-01.md) — đợt thay đổi trước
* [`../../specs/hr/SPEC-CHAM-CONG-APP-2026-10-01.md`](../../specs/hr/SPEC-CHAM-CONG-APP-2026-10-01.md) —
  thiết kế nghiệp vụ đầy đủ

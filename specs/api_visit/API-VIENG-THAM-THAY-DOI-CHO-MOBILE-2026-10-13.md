# Thay đổi API ngày 13/10/2026 — viếng thăm: đo vị trí lúc CHECK-OUT

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 13/10/2026**. Mọi JSON dưới đây là phản hồi **thật**,
gọi bằng `curl` trên bản sao dữ liệu (`app_test`) cùng ngày bằng tài khoản thật.

Hợp đồng đầy đủ của luồng viếng thăm vẫn là
[`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md) — file này chỉ là phần thêm.

> 🟢 **KHÔNG có breaking change. App đang chạy KHÔNG phải sửa gì.** Không endpoint nào đổi đường dẫn,
> không tham số nào thành bắt buộc, không mã lỗi mới, phản hồi check-out giữ nguyên các khoá cũ.
> Phần "app nên làm" ở §3 là **khuyến nghị trải nghiệm**, không phải điều kiện để API chạy.

| # | Thay đổi | Loại | Ảnh hưởng app |
|---|---|---|---|
| 1 | Server **đo khoảng cách lúc check-out** và gắn cờ `is_checkout_within_geofence` | **THÊM** | Không bắt buộc sửa |
| 2 | `GET /dms/visits/{id}` và `GET /dms/visits/mine` trả thêm 2 khoá | **THÊM KHOÁ** | Không bắt buộc đọc |

---

## 1. Chuyện gì đổi ở phía server

Trước 13/10/2026, toạ độ lúc check-out (`checkout_lat`/`checkout_lng`, có từ 29/09/2026) được **lưu nguyên
văn mà không đo gì**. Nay server tính luôn khoảng cách từ chỗ nhân viên đứng lúc bấm check-out tới toạ độ
điểm bán, rồi ghi hai cột mới:

| Khoá | Kiểu | Ý nghĩa |
|---|---|---|
| `checkout_distance_m` | `string\|null` | Khoảng cách (mét) lúc bấm check-out. `null` = chưa tính được |
| `is_checkout_within_geofence` | `bool\|null` | `true` còn trong bán kính · `false` đã ra ngoài · **`null` = CHƯA TÍNH ĐƯỢC** |

### 🔴 Hai điều phải nắm, nếu không app sẽ hiểu sai dữ liệu

**① Đứng ngoài bán kính KHÔNG bị chặn.** Khác hẳn check-in (luật ④ từ chối bằng 422). Ở chiều ra, lượt
vẫn đóng bình thường, server chỉ **gắn cờ** cho báo cáo nội bộ soi lại. Lý do: người bấm đang đứng ngoài
thị trường với một lượt **đã mở** — chặn họ lại là dựng một thế không có cách nào tự gỡ, còn ở chiều vào
thì họ luôn có thể đi gần lại rồi bấm lại.

Đừng viết trong app câu *"bạn ở quá xa, không check-out được"* — server không bao giờ trả lỗi đó.

**② `null` KHÔNG phải `false`.** `null` nghĩa là *chưa tính được*, và đây là ca **rất thường gặp**:
app không gửi toạ độ · người dùng từ chối quyền vị trí · máy mất GPS trong nhà · gói tin đến từ hàng đợi
ngoại tuyến · hoặc **chính điểm bán chưa có toạ độ** trong hồ sơ. App hiện cờ cảnh báo từ `!x` là dán nhãn
"ra ngoài vùng" lên hàng loạt lượt hoàn toàn hợp lệ. Luôn so `=== false` (Dart: `== false`, đừng `!flag`).

### Bán kính lấy ở đâu

**Dùng CHUNG đúng bán kính của check-in** — cố ý không đẻ tham số thứ hai:

1. `geofence_radius_m` riêng của điểm bán (có trong `GET /dms/routes/customers` từ 01/10/2026);
2. để trống thì rơi về `visit.default_radius_m` trong `GET /dms/mobile-rules`.

Nghĩa là app **tính trước được** kết quả mà không cần gọi thêm endpoint nào.

---

## 2. Bằng chứng gọi thật

Check-out ở cách điểm bán **1.223 m** (bán kính cho phép nhỏ hơn nhiều) — lượt **vẫn đóng, HTTP 200**:

```
POST /dms/visits/132325/checkout
{"visit_result":"visited","lat":"10.9628144","lng":"106.8112606","accuracy_m":"8.5"}
```

```json
{"success":true,"message":"Thành công","data":{
  "id":132325,
  "checkout_at":"2026-10-13 08:49:32.023047+07",
  "duration_seconds":2412,
  "visit_result":"visited",
  "checkout_lat":"10.9628144",
  "checkout_lng":"106.8112606"}}
```

⚠️ **Phản hồi check-out KHÔNG đổi** — vẫn đúng 6 khoá như hợp đồng 29/09. Cờ không nằm ở đây vì app không
cần nó để quyết định gì; nó là dữ liệu đối soát của báo cáo.

Đọc lại lượt đó bằng `GET /dms/visits/132325` thì thấy kết quả đo:

```json
{"id":132325,
 "distance_to_customer_m":"12.00",  "is_within_geofence":true,
 "checkout_distance_m":"1223.14",   "is_checkout_within_geofence":false,
 "checkout_lat":"10.9628144","checkout_lng":"106.8112606",
 "checkout_at":"2026-10-13 08:49:32.023047+07","duration_seconds":2412}
```

Đọc đúng lượt này: **vào đúng chỗ (12 m), ra cách 1,2 km** — tức là người đó đã rời khu vực rồi mới bấm
check-out, trong khi `duration_seconds` vẫn ghi 2.412 giây "ở điểm bán". Chính ca này là lý do phép đo ra đời.

`GET /dms/visits/mine` cũng trả hai khoá đó trong mỗi dòng:

```json
{"id":132325,"checkout_at":"2026-10-13 08:49:32.023047+07",
 "checkout_distance_m":"1223.14","is_checkout_within_geofence":false}
```

---

## 3. App nên làm gì (khuyến nghị, không bắt buộc)

**① Gửi `lat`/`lng` ở mọi lượt check-out.** Đã nằm trong hợp đồng từ 29/09 và vẫn **không bắt buộc** — nhưng
không gửi thì hai cột trên là `null` vĩnh viễn và lượt đó không đối soát được. Lấy được vị trí tới đâu thì
gửi tới đó; **đừng** chặn nút check-out để chờ GPS, và **đừng** gửi toạ độ cũ của lần check-in.

**② Cảnh báo MỀM trước khi bấm, nếu muốn.** App tự tính khoảng cách tới điểm bán (công thức haversine, cùng
phép đo server dùng) và so với bán kính ở §1. Vượt thì hiện một dòng nhắc kiểu *"Bạn đang cách điểm bán
~1,2 km — lượt này sẽ được đánh dấu để soi lại"* với nút **vẫn bấm tiếp được**. Đây là lựa chọn trải nghiệm;
bỏ qua cũng không sai.

**③ Nếu app có màn lịch sử lượt ghé của chính mình:** hiện `checkout_distance_m` cạnh `distance_to_customer_m`
cho người dùng tự thấy. Nhớ ba trạng thái: có số · ra ngoài vùng (tô đỏ) · `null` thì hiện `—`, **không** hiện 0.

---

## 4. Những gì KHÔNG đổi

* Ba cổng check-out (thời gian tối thiểu · biểu mẫu bắt buộc · số ảnh) — y nguyên, xem hợp đồng 29/09 §6.
* Năm luật check-in — y nguyên, kể cả luật ④ **vẫn CHẶN** khi check-in ngoài bán kính.
* `POST /dms/visits/{id}/checkout`: đường dẫn, tham số, mã lỗi, phản hồi — y nguyên.
* Trần ảnh một lượt (20 tấm) và dung lượng mỗi tấm — y nguyên.
* Không có quyền RBAC mới, không phải cấp lại vai cho ai.

---

## 5. Câu hỏi đội mobile hay hỏi

**Lượt cũ có được tính lại không?** Không. Cờ là **ảnh chụp lúc bấm check-out**, chỉ ghi một lần tại thời
điểm đó. 43.842 lượt có trước 13/10/2026 giữ `null` ở cả hai cột, và đó là trạng thái đúng của chúng.

**Điểm bán chưa có toạ độ thì sao?** Hai cột để `null` — không phải lỗi của nhân viên, và app đừng hiện gì.

**Lượt do cron tự đóng (quá hạn treo) thì sao?** Cũng `null`: không ai bấm nút nên không có toạ độ lúc ra.

**Sửa toạ độ điểm bán sau đó có làm cờ đổi không?** Không, cờ đã ghi thì giữ nguyên — giống hệt cách
`is_within_geofence` của chiều vào vẫn hoạt động.

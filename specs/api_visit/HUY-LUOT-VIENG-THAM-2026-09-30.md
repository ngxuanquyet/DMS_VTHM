# Huỷ lượt check-in — thay đổi ngày 30/09/2026

**Trạng thái:** ✅ đã thi công và đang chạy trên prod (phía server). Chờ app Flutter gọi cửa mới.
**Quyết định nghiệp vụ:** chủ hệ thống chốt 30/09/2026.
**Liên quan:** hợp đồng cho đội mobile ở `docs/reference/API-VIENG-THAM-MOBILE-2026-09-29.md` **§7.1**.

---

## 1. Vấn đề — vì sao phải làm

Trước đợt này **không có đường nào gỡ một lượt check-in đã mở**. Không endpoint, không nút trên One, kể cả
cho quản trị. Lối ra duy nhất là cron `dms-visit/close-stale` đóng hộ sau `visit_auto_close_after_hours`
giờ (mặc định **12**).

Điều làm nó nghiêm trọng hơn vẻ ngoài: luật `VisitService::assertNoOpenVisit()` chặn theo **NGƯỜI**, không
theo điểm bán.

```php
->andWhere(['v.user_id' => $userId, 'v.checkout_at' => null])
```

⇒ Nhân viên bấm check-in lúc 9h rồi bỏ dở — khách đóng cửa, gọi về gấp, máy hết pin — thì **mất phần còn
lại của ngày làm việc**: mọi lần check-in ở *mọi* điểm bán khác đều nhận

> *"Bạn còn một lượt viếng thăm chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới."*

cho tới khi cron gỡ, tức khoảng **21:15** với ca 9h sáng.

Và kể cả sau khi cron gỡ, điểm bán đó vẫn **cháy cả ngày**: dòng lượt còn nguyên với `visit_date` hôm nay,
nên quay lại làm cho đúng sẽ nhận *"Hôm nay bạn đã viếng thăm điểm bán này rồi."*

Ngoài ra lượt bị cron đóng **vẫn đếm là một lượt viếng thăm** trong báo cáo (chỉ khác là thời lượng trống)
— không có trạng thái nào phân biệt nó với lượt làm thật.

**Đo trên prod 30/09/2026:** 1 lượt đang treo, **0 lượt** từng bị cron tự đóng — tình huống này chưa xảy ra
trên dữ liệu thật vì app chưa phát hành. Nó sẽ xảy ra ngay tuần đầu khi có người dùng.

---

## 2. Bốn quyết định nghiệp vụ (chủ hệ thống chốt 30/09/2026)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Ai được huỷ | **Chính nhân viên**, trên lượt của mình |
| 2 | Cửa sổ thời gian | **Bất cứ lúc nào** khi lượt còn mở — không giới hạn |
| 3 | Lý do huỷ | **Không bắt nêu** |
| 4 | Hiện trên báo cáo | **Ẩn hẳn** |

**Hệ quả phải biết, đã nói với chủ hệ thống trước khi thi công:** ba lựa chọn 2+3+4 cộng lại nghĩa là **một
lượt đã đứng 3 tiếng vẫn huỷ được và biến mất khỏi mọi báo cáo, không kèm lý do**. Số lượt trên báo cáo vì
vậy có thể ít hơn số người thật sự đã bấm check-in.

Điều này **nhất quán** với hướng đã chốt cùng ngày cho đồng hồ đơn điệu: hàng rào chống gian lận của hệ này
là **geofence (phải đứng ở điểm bán) + ảnh (bằng chứng tại chỗ)**, không phải đồng hồ và cũng không phải
cửa huỷ. 🔴 **Đừng dựng thêm luật chặn trong `VisitService::cancel()` với kỳ vọng bịt lỗ đó** — docblock
của hàm đã ghi rõ.

**Một điều được quyết ở tầng kỹ thuật:** *"ẩn hẳn khỏi báo cáo" = báo cáo lọc ra, KHÔNG phải xoá khỏi CSDL.*
Dòng lượt ở lại cùng `cancelled_at`, và **ảnh đã tải lên được giữ nguyên**. Có tranh chấp về sau thì vẫn
còn thứ để đối chiếu; xoá thì không hoàn tác được.

---

## 3. Thiết kế

### 3.1 Cột mới — và vì sao KHÔNG dùng `deleted_at` có sẵn

`dms_visit.cancelled_at TIMESTAMPTZ NULL` (migration `m260930_000200_dms_visit_cancel`).

Bảng đã có `deleted_at` + `SoftDeleteScopeTrait` lọc ngầm ở `find()`. Dùng lại nó thì mọi báo cáo tự ẩn,
không phải sửa chỗ nào. **Vẫn cố ý không dùng**, hai lý do:

1. **Hai việc khác nghĩa.** `deleted_at` = "quản trị dọn một dòng rác"; `cancelled_at` = "người đi thị
   trường tự gỡ lượt của mình". Gộp một cột thì sau này không còn cách phân biệt, mà đó đúng là thứ cần
   biết khi hỏi *"có ai hay huỷ bất thường không"*.
2. **Cửa huỷ cần đọc được chính dòng đã huỷ.** `SoftDeleteScopeTrait` lọc ngầm ⇒ lần bấm huỷ thứ hai sẽ
   nhận 404 thay vì 200, phá tính idempotent mà hàng đợi ngoại tuyến cần.

Giá phải trả của lựa chọn này: **không có scope tự động, mọi nơi ĐỌC phải lọc tay** — xem §3.3.

### 3.2 Ràng buộc ở tầng DB

```sql
ALTER TABLE dms_visit ADD CONSTRAINT ck_dms_visit_cancel
  CHECK (cancelled_at IS NULL OR checkout_at IS NULL);
```

Lượt đã đóng thì ba cổng check-out đã phán quyết xong và đã vào báo cáo — huỷ sau đó là viết lại lịch sử.
Chặn ở DB chứ không chỉ ở service: cron, công cụ nhập liệu và mọi đường ghi tương lai đều đi qua ràng buộc
này, còn vế kiểm trong PHP thì chỉ đúng với đường đã nhớ sửa.

**Đã thử nghiệm ràng buộc có chặn thật** (không chỉ đọc mã): ghi `cancelled_at` vào một lượt đã check-out
trên `app_test` ⇒ `violates check constraint "ck_dms_visit_cancel"`.

### 3.3 🔴 Bảy đường đọc phải lọc tay — chỗ dễ hỏng nhất của đợt này

Sót một chỗ thì lượt đã huỷ **vẫn đếm vào thống kê** hoặc **vẫn chặn check-in**, im lặng, không mã lỗi nào.

| # | Nơi | Hỏng thế nào nếu quên |
|---|---|---|
| 1 | `VisitSearch::search()` | Lượt huỷ vẫn hiện ở lưới báo cáo, file Excel và `/dms/visits/mine` (ba cửa dùng chung một query) |
| 2 | `VisitController::actionTamperSummary()` — `Query` **thuần** | Bảng Nghi vấn GPS đếm nhiều hơn Báo cáo viếng thăm trên cùng khoảng lọc |
| 3 | `CustomerController` lịch sử ghé của một điểm bán — `Query` **thuần** | Màn chi tiết khách hàng vẫn liệt kê lượt đã huỷ |
| 4 | `VisitService::assertNoOpenVisit()` | **Huỷ xong vẫn kẹt y nguyên** — tính năng vô tác dụng |
| 5 | `VisitService::assertNotVisitedToday()` | **Không ghé lại được điểm bán vừa huỷ** — vô dụng đúng ở ca nó sinh ra để phục vụ |
| 6 | `VisitService::isFirstVisit()` | Lượt làm lại mất cờ "lần đầu ghé điểm bán này" |
| 7 | `VisitService::closeStaleVisits()` — `UPDATE` thô của cron | Cron đụng lượt đã huỷ ⇒ vi phạm `ck_dms_visit_cancel` ⇒ **cả lượt chạy cron đổ**, kéo theo lượt treo thật cũng không được dọn |

Cộng **hai cửa GHI** bị đóng lại: `checkOut()` và `assertCanAddPhoto()` từ chối lượt đã huỷ bằng câu tiếng
Việt rõ nghĩa, thay vì để ràng buộc DB nổ và app nhận *"Không lưu được lượt, thử lại"*.

### 3.4 Endpoint

```
POST /dms/visits/{id}/cancel       (không tham số, không body)
→ 200 {"id":128899,"cancelled_at":"2026-09-30 13:57:16+07"}
```

* Quyền `/dms/visit/cancel`, chỉ gán vai **`crm_customer_self`** (migration
  `rbac/m260930_000300_dms_visit_cancel_permission`). Không cấp cho vai quản trị: cửa này chỉ động tới lượt
  của chính người đăng nhập (`ownVisit()` → `findOwnedBy()`), nên cấp thêm cũng không làm được gì — chỉ
  khiến cây phân quyền gợi ý một khả năng không tồn tại.
* **IDEMPOTENT** — gửi lại lần hai vẫn 200 và `cancelled_at` **giữ mốc lần bấm đầu**. App ngoại tuyến gửi
  lại cả hàng đợi khi mạng chập; một cửa huỷ ném lỗi ở lần thứ hai sẽ kẹt retry vĩnh viễn (đúng vết xe của
  check-out, nơi tài liệu phải dặn app tự coi 422 là thành công).

---

## 4. Đã đo những gì

### 4.1 Curl đúng cửa app sẽ gọi (`app_test`, dữ liệu thử đã dọn)

| # | Kịch bản | Kết quả |
|---|---|---|
| 1 | Còn lượt treo → check-in điểm bán khác | bị chặn (hành vi cũ giữ nguyên) |
| 2 | Huỷ lượt | 200, trả `cancelled_at` |
| 3 | Huỷ lại lần hai | 200, **mốc không dời** |
| 4 | Ghé lại **chính điểm bán vừa huỷ**, cùng ngày | được |
| 5 | Lượt đã huỷ trong `GET /dms/visits/mine` | biến mất |
| 6 | Lưới `/dms/visits` + lịch sử ghé của điểm bán | biến mất |
| 7 | Check-out lượt đã huỷ | 422 *"…đã bị huỷ, không check-out được."* |
| 8 | Tải ảnh vào lượt đã huỷ | 422 *"…đã bị huỷ, không nhận thêm ảnh được."* |

### 4.2 Test

**418 test / 1.863 assertion xanh** (nhóm `dms` + `crm` + `platform`, 1'29"), không ca nào bị bỏ qua.
Trong đó **8 ca mới** cho tính năng huỷ, phủ đúng 7 đường đọc ở §3.3.

🔴 **Đã kiểm chứng test bắt được lỗi thật:** gỡ thử từng vế lọc vừa thêm ⇒ **đúng 4 ca đỏ** ứng với 4 vế bị
gỡ. Cổng xanh mà không bắt được gì thì vô nghĩa.

PHPStan sạch, PHPCS sạch.

### 4.3 Một lỗi có sẵn phát hiện nhân tiện

PHPStan lôi ra `Visit::$auto_closed_at` **chưa bao giờ được khai** trong docblock model (cột có từ
28/09/2026). Đã khai bổ sung trong cùng lần sửa.

---

## 5. Còn nợ

| # | Việc | Điều kiện đóng |
|---|---|---|
| 1 | 🔴 **App Flutter chưa gọi cửa này** | App ở **repo RIÊNG**. Nút huỷ phải nằm ngay trên màn hình lượt đang mở, đừng giấu trong menu phụ. Lượt **chưa kịp đồng bộ** thì app xoá thẳng bản ghi cục bộ, đừng gọi check-in rồi gọi huỷ |
| 2 | **Cổng test đầy đủ** (`composer test-gate`, 2.324 test) chưa chạy | Chạy lại trước khi coi là đóng — bản chạy hẹp không phủ phần còn lại của hệ thống |
| 3 | **Review chéo `agy-review`** (CLAUDE.md §9) chưa chạy | Việc này chạm migration + phân quyền + service dùng chung ⇒ bắt buộc. Lưu ý `agy-review` hết hạn tuần tới 02/10, phải mượn vai khác và khai rõ ở dòng đầu prompt |
| 4 | Không có **trạng thái "đã huỷ"** trên giao diện quản trị | Theo quyết định §2.4 là ẩn hẳn. Mở lại nếu chủ hệ thống muốn theo dõi ai hay huỷ — dữ liệu đã sẵn ở `cancelled_at`, chỉ cần một bộ lọc |

### Một việc nhỏ nên làm bất kể

Tham số `visit_auto_close_after_hours` đang là **12 giờ** (mặc định, chưa ai đổi — `sys_setting` chưa có
dòng nào cho khoá `visit%`). Nay đã có cửa huỷ nên nó bớt nguy hiểm, nhưng vẫn nên **hạ xuống 2–3 giờ** cho
ca người dùng quên hẳn không bấm gì: sửa ở `/system/settings/dms`, không cần đụng mã.

---

## 6. File đã đổi

**Migration (đã áp cả `app` lẫn `app_test`)**
* `common/modules/dms/migrations/m260930_000200_dms_visit_cancel.php`
* `common/modules/dms/migrations/rbac/m260930_000300_dms_visit_cancel_permission.php`

**Backend**
* `common/modules/dms/models/Visit.php` — `cancelled_at`, `isCancelled()`, khai bù `auto_closed_at`
* `common/modules/dms/services/VisitService.php` — `cancel()` + 6 đường đọc/ghi
* `common/modules/dms/models/VisitSearch.php` — lọc lượt đã huỷ khỏi báo cáo
* `api/modules/dms/controllers/VisitController.php` — `actionCancel()` + lọc bảng Nghi vấn GPS
* `api/modules/crm/controllers/CustomerController.php` — lọc lịch sử ghé của điểm bán
* `api/config/main.php` — URL rule
* `common/messages/{vi,en}/dms.php` — 4 khoá

**Test & tài liệu**
* `common/tests/Unit/DmsVisitRulesTest.php` — 8 ca mới
* `docs/reference/API-VIENG-THAM-MOBILE-2026-09-29.md` — §7.1 + nhật ký

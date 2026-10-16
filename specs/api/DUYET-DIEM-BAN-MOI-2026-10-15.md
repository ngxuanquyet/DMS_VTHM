# Duyệt điểm bán mới (kèm lượt viếng thăm) — DMS / CRM

**Trạng thái:** đã thi công 15/10/2026 (backend + SPA lên prod cùng ngày) — sổ việc **#23415** (con của quyết định **#23414**). Màn hàng chờ + hồ sơ tổng thể: 16/10/2026, **#23461** (§3b).

Logic DMS đổi 15/10/2026: nhân viên thị trường mở điểm bán mới trên app là **viếng thăm luôn**, và việc mở
mới + các lượt viếng thăm đó cần quản trị điểm bán duyệt.

## 1. Hiện trạng trước khi làm

* `crm_customer.approval_status` (`draft|pending|approved|rejected`) có từ đầu nhưng **không ai dùng**: bản MVP
  (chốt 18/09/2026) để `CustomerService::create()` luôn ghi `approved`.
* `PATCH /crm/customers/{id}` ghi được `approval_status` — kể cả nhân viên thị trường với điểm bán của chính
  mình (vai `crm_customer_self` có `/crm/customer/update`). Có luồng duyệt rồi mà còn đường này thì nhân viên
  tự duyệt hồ sơ của mình.
* `dms_visit` không có trạng thái duyệt; báo cáo viếng thăm (`VisitReportBuilder`) đếm mọi lượt đã check-out.

## 2. Quyết định của chủ hệ thống (15/10/2026, #23414)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Đơn vị duyệt | **Một hồ sơ chung**: duyệt/từ chối ĐIỂM BÁN; mọi lượt viếng thăm ở điểm bán đi theo trạng thái của nó |
| 2 | Ai duyệt | Quyền mới `/crm/customer/approve`, gán vai sẵn có `crm_customer_admin` |
| 3 | Đang chờ duyệt | Dùng **bình thường** (check-in, ảnh, biểu mẫu, ghé lại); ~~báo cáo không đếm~~ → **vẫn đếm**, gắn cờ (16/10, §3c) |
| 4 | Bị từ chối | Ghi `rejected` để **lưu vết** — không ẩn, không chặn; ~~báo cáo không đếm~~ → **vẫn đếm**, lượt gắn cờ kèm lý do (16/10, §3c); hàng tổng có nhãn số lượt bị từ chối |
| 5 | Điểm bán nào phải duyệt | Chỉ điểm bán do người **không** giữ `/crm/customer/index` (nhân viên thị trường) mở. Quản trị mở trên web, dữ liệu MobiWork và mọi điểm bán đã có trước giữ `approved` |
| 6 | Thông báo | Người duyệt khi có hồ sơ mới · người mở khi được duyệt · người mở khi bị từ chối (kèm lý do) |
| 7 | Đổi quyết định | **Được**, mỗi lần đổi lưu lịch sử (ai, lúc nào, từ → tới, lý do) |

## 3. Thiết kế

* **DB:** `crm_customer` thêm `approval_note`, `approval_by_user_id` (FK `usr_user`, SET NULL), `approval_at` —
  quyết định GẦN NHẤT để app/lưới đọc không cần join. Bảng `crm_customer_approval_log` giữ trọn lịch sử.
* **Ghi:** `CustomerApprovalService` là cửa DUY NHẤT đổi `approval_status` (`approve()` / `reject()` — từ chối bắt
  buộc lý do). `approval_status` bị **gỡ khỏi** `CustomerService::WRITABLE` + `CustomerUpdateForm` (PATCH gửi lên
  nhận 422) — thay bằng hai cửa có lịch sử và thông báo.
* **API:** `POST /crm/customers/{id}/approve`, `POST /crm/customers/{id}/reject` (body `note`),
  `GET /crm/customers/{id}/approval-log` — cả ba gác `/crm/customer/approve`.
* **Tạo mới:** `POST /crm/customers` của người không có `/crm/customer/index` ⇒ `pending` + báo những người giữ
  `/crm/customer/approve` (hỏi qua cây vai `getUserIdsWithItem(…, true)`). Lượt gửi lại cùng `client_uuid` không
  báo lần hai.
* **Thông báo:** tiền tố `crm.` — `crm.customer_pending`, `crm.customer_approved`, `crm.customer_rejected`, nhóm
  "Điểm bán" ở `NotificationModules`.
* **Báo cáo viếng thăm:** mỗi dòng mang `customer_approval_status`; hàng tổng kết ~~chỉ đếm lượt (và khách hàng) của
  điểm bán `approved`~~ đếm MỌI lượt, khách tách ba nhóm (16/10, §3c). Lưới hiện nhãn ở ô "N khách hàng"
  của hàng tổng + nhãn cạnh tên điểm bán; Excel ghi `[Chờ duyệt]`/`[Bị từ chối]` sau tên điểm bán và "Bị từ chối: N
  lượt" ở cột S hàng tổng. Tham số `approval_status` có ở API `GET /dms/visits` (+ export); lưới SPA CHƯA có ô lọc
  riêng cho nó. **Giờ làm, giờ viếng thăm, km KHÔNG đổi** — đó là công sức thật đã bỏ ra, không
  phụ thuộc hồ sơ điểm bán (giả định khi thi công, đổi được nếu chủ hệ thống muốn).
* **SPA:** màn Điểm bán thêm cột + bộ lọc "Trạng thái duyệt"; ngăn chi tiết có khối duyệt (`CustomerApprovalPanel`:
  trạng thái + lý do cho mọi người xem; nút Duyệt / Từ chối + lịch sử chỉ với người giữ quyền). Link thông báo
  `/crm/customers?open=<id>` mở thẳng ngăn chi tiết.
* **Nhóm thông báo** "Điểm bán" (`crm`) ở trang cài đặt thông báo — hai sự kiện tắt riêng được: hồ sơ chờ tôi duyệt ·
  kết quả duyệt điểm bán tôi mở.
* **App Flutter (repo riêng)** — hướng dẫn cho đội app: [`API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15.md`](../../reference/internal-api/API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15.md): `GET /crm/customers/mine` đã trả `approval_status`, nay thêm `approval_note` — app
  chỉ cần hiển thị nhãn + lý do, luồng tạo/check-in không đổi.

## 3b. Màn hàng chờ + hồ sơ duyệt tổng thể (chốt 16/10/2026, #23461)

Chủ hệ thống làm rõ: NV mở điểm bán là viếng thăm luôn, nên người duyệt phải **xem tổng thể điểm bán CÙNG lượt viếng
thăm** (biểu mẫu, ghi chú, ảnh) và quyết một lần cho cả hai.

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Xem và duyệt ở đâu | **Màn hàng chờ riêng** "Duyệt điểm bán mới" (`/crm/customer-approvals`, menu Khách hàng và Thị trường) |
| 2 | Hồ sơ gồm lượt nào | **Mọi lượt** từ lúc mở tới khi quyết; lượt sau khi duyệt tính bình thường |
| 3 | Lượt chưa check-out | **Chỉ quyết khi lượt ĐẦU đã check-out** |
| 4 | Từ chối | Giữ như §2.4 |

* **API:** `GET /crm/customers/approvals?tab=pending|decided&q=` (gác `/crm/customer/approve`, không bó phạm vi tổ chức — cùng
  lý do với `approve`). Tab "Đã xử lý" chỉ lấy điểm bán có dòng lịch sử mở mới (`from_status IS NULL`) — không lấy 8.700+
  điểm bán duyệt sẵn. Mỗi dòng có `visit_count` và `first_visit_open`.
* **Cổng check-out** ở `CustomerApprovalService::decide()` (console cũng chịu): rời `pending` khi lượt đầu (chưa xoá, chưa
  huỷ, `checkin_at` sớm nhất) còn `checkout_at IS NULL` ⇒ lỗi nghiệp vụ. Không có lượt nào ⇒ được. Đổi quyết định về sau
  không chặn.
* **Hồ sơ SPA** (`CustomerApprovalReviewDrawer`) KHÔNG có endpoint gộp — đọc các cửa chi tiết sẵn có: điểm bán
  (`/crm/customer/index`), lượt (`/crm/customers/{id}/visits` + `/dms/visits/{id}`, cần `/dms/visit/index`), phiếu
  (`/dms/form-submissions?customer_id=`, cần `/dms/form-submission/index`). Vai `crm_customer_admin` giữ đủ cả bốn. Dùng lại
  `VisitDetailBody` (tách từ `VisitDetailDrawer`) và `SubmissionAnswers` (tách từ màn Dữ liệu thu thập).
* Ngăn chi tiết ở màn Điểm bán giữ nguyên khối duyệt (đổi quyết định về sau).
* **Lượt đầu ở điểm bán NV mở trên app không chịu thời gian tối thiểu** (chốt 16/10/2026): `VisitCheckoutGuard` cổng ① trả
  0 khi `dms_visit.is_first_visit` và điểm bán có dòng lịch sử mở mới (`CustomerApprovalService::openedOnApp()`) — đọc
  theo lịch sử nên vẫn miễn dù quản trị duyệt trước khi NV check-out. Ảnh tối thiểu + biểu mẫu bắt buộc GIỮ. Điểm bán chờ
  duyệt vẫn ghé được nhiều lần (không có cổng nào chặn theo trạng thái duyệt).

## 3c. Lượt viếng thăm luôn được ghi nhận (chốt 16/10/2026 — thay §2.3, §2.4 về số đếm)

Chủ hệ thống đổi: **lượt viếng thăm luôn được ghi nhận**; điểm bán bị từ chối thì lượt chỉ bị **gắn cờ kèm lý do**.

* `VisitReportBuilder::summarizeEmployee()`: `visits` đếm MỌI lượt đã check-out, bất kể trạng thái duyệt. **Khách hàng
  tách ba nhóm** (điểm bán khác nhau, theo trạng thái duyệt hiện tại): `customers` = hợp lệ (đã duyệt) ·
  `pending_customers` = chờ duyệt · `rejected_customers` = không hợp lệ (bị từ chối). Ví dụ 3 lượt ở 3 điểm, một điểm
  bị từ chối ⇒ "3 lượt viếng thăm" · "2 khách hàng hợp lệ" · "Không hợp lệ: 1 khách". Thay `pending_visits` /
  `rejected_visits` (đã gỡ).
* Dòng lượt mang thêm `customer_approval_note` (`crm_customer.approval_note`). Lưới: nhãn "Bị từ chối" + lý do (chữ đỏ)
  dưới mã điểm bán. Excel cột K dòng lượt: `Tên [Bị từ chối: lý do]`; cột K hàng tổng: `N khách hàng hợp lệ · Chờ duyệt:
  P khách · Không hợp lệ: M khách`.
* Dòng ngày (giờ làm, giờ viếng thăm, km) tính mọi lượt — không đổi.
* Từ chối không huỷ, không xoá lượt (`dms_visit` không đổi) — như trước.

## 4. Ngoài phạm vi

* Báo cáo theo biểu mẫu thị trường (`MarketFormReportService`) — không lọc theo trạng thái duyệt.
* Gửi lại sau khi bị từ chối: không có bước riêng; quản trị đổi quyết định (§2.7).

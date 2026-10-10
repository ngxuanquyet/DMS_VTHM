# CẨM NANG HƯỚNG DẪN SỬ DỤNG ỨNG DỤNG DMS VTHM MOBILE
## Dành Cho Người Dùng Cuối (Nhân Viên Thị Trường, Nhân Viên Bán Hàng & Giám Sát)

---

> [!NOTE]
> **Hệ thống Quản lý Phân phối Thực địa (DMS VTHM Mobile)** được phát triển chuyên biệt cho đội ngũ kinh doanh và giám sát thị trường của **VTHM Group**. 
> Ứng dụng hoạt động theo kiến trúc **Offline-First**, cho phép người dùng tác nghiệp liên tục, mượt mà ngay cả khi mất sóng Internet hoặc làm việc tại các vùng hẻo lánh.

---

## MỤC LỤC CHI TIẾT

1. [Tổng Quan & Chuẩn Bị Ban Đầu](#1-tổng-quan--chuẩn-bị-ban-đầu)
   - 1.1. Mục đích và đối tượng sử dụng
   - 1.2. Cấp quyền ứng dụng trên thiết bị di động
   - 1.3. Quy định an toàn thiết bị & Chống gian lận
2. [Đăng Nhập & Thiết Lập Tài Khoản](#2-đăng-nhập--thiết-lập-tài-khoản)
   - 2.1. Đăng nhập hệ thống & Duy trì phiên (90 ngày)
   - 2.2. Khởi tạo & Tự động tải dữ liệu ban đầu
   - 2.3. Cài đặt cá nhân: Chế độ Tối (Dark Mode) & Ngôn ngữ
3. [Giao Diện Chính & Điều Hướng (Navigation)](#3-giao-diện-chính--điều-hướng-navigation)
   - 3.1. Thanh điều hướng dưới đáy (5 Tab chức năng)
   - 3.2. Thanh tiêu đề trên & Huy hiệu Đồng bộ (Top App Bar)
   - 3.3. Màn hình Trang chủ & 3 Thao tác nhanh (Quick Actions)
4. [Module 1: Chấm Công Thực Địa (Attendance)](#4-module-1-chấm-công-thực-địa-attendance)
   - 4.1. Khung giờ ca làm việc tiêu chuẩn
   - 4.2. Quy trình Chấm công Vào ca (Check-in) bằng 2 ảnh xác thực
   - 4.3. Quy trình Chấm công Ra ca (Check-out) cuối ngày
   - 4.4. Kiểm tra vùng chấm công (Geofence) & Xử lý ngoài vùng
   - 4.5. Xem Thống kê tháng & Lịch sử chấm công
5. [Module 2: Tuyến Bán Hàng & Lộ Trình (Route & MCP)](#5-module-2-tuyến-bán-hàng--lộ-trình-route--mcp)
   - 5.1. Xem danh sách điểm bán theo tuyến được giao
   - 5.2. Chế độ xem: Danh sách khoảng cách vs. Bản đồ Goong Map
   - 5.3. Nhận biết trạng thái viếng thăm các điểm bán
   - 5.4. Tìm kiếm & Sắp xếp điểm bán thông minh
6. [Module 3: Quy Trình Viếng Thăm Điểm Bán (Store Visit)](#6-module-3-quy-trình-viếng-thăm-điểm-bán-store-visit)
   - 6.1. Quy trình chuẩn 6 bước tại điểm bán
   - 6.2. Bước 1: Check-in điểm bán & Xác thực khoảng cách
   - 6.3. Bước 2: Chụp ảnh đóng dấu Watermark (Toạ độ & Giờ thực tế)
   - 6.4. Bước 3: Điền biểu mẫu khảo sát trong lượt
   - 6.5. Bước 4: Soi điều kiện hoàn thành (Check-out Requirements)
   - 6.6. Bước 5: Check-out đóng lượt (Mở cửa vs. Đóng cửa)
   - 6.7. Tính năng khẩn cấp: Huỷ lượt viếng thăm (Cancel Visit)
7. [Module 4: Quản Lý Khách Hàng / Điểm Bán (Customers)](#7-module-4-quản-lý-khách-hàng--điểm-bán-customers)
   - 7.1. Tra cứu & Xem chi tiết thông tin điểm bán
   - 7.2. Thêm mới điểm bán ngoại tuyến (Hỗ trợ chụp nhiều ảnh)
   - 7.3. Chỉnh sửa thông tin khách hàng
8. [Module 5: Biểu Mẫu Khảo Sát Thị Trường (Market Forms)](#8-module-5-biểu-mẫu-khảo-sát-thị-trường-market-forms)
   - 8.1. Phân biệt Biểu mẫu trong lượt (`survey`) vs. Biểu mẫu tự do (`collect`)
   - 8.2. Hướng dẫn thao tác các loại câu hỏi (Ảnh, Số, Chọn, Khách hàng...)
   - 8.3. Cơ chế logic ẩn/hiện câu hỏi có điều kiện
9. [Module 6: Khai Báo Vị Trí Thực Địa (Position Declaration)](#9-module-6-khai-báo-vị-trí-thực-địa-position-declaration)
   - 9.1. Khi nào cần Khai báo vị trí?
   - 9.2. Thao tác khai báo: Lý do, Chụp ảnh Watermark & Ghi chú
   - 9.3. Lịch sử khai báo vị trí của bản thân
10. [Module 7: Theo Dõi Quãng Đường Di Chuyển (My Travel)](#10-module-7-theo-dõi-quãng-đường-di-chuyển-my-travel)
    - 10.1. Nguyên lý tính quãng đường tự động qua các mốc thực tế
    - 10.2. Ba trạng thái con số km (Số đã chốt, 0 km cảnh báo, và Chưa tính)
    - 10.3. Tra cứu lịch sử chặng đường theo ngày công
11. [Module 8: Báo Cáo Hoạt Động Trong Ngày (Daily Report)](#11-module-8-báo-cáo-hoạt-động-trong-ngày-daily-report)
    - 11.1. Thống kê KPI hoạt động trong ngày
    - 11.2. Dòng thời gian Timeline & 5 Tab lọc hoạt động
    - 11.3. Xem chi tiết hoạt động thực địa
12. [Module 9: Trung Tâm Thông Báo & Nhắc Việc (Notifications)](#12-module-9-trung-tâm-thông-báo--nhắc-việc-notifications)
    - 12.1. Bảy loại thông báo nhắc nhở tự động
    - 12.2. Thao tác xem thông báo & Đánh dấu đã đọc
13. [Module 10: Cơ Chế Đồng Bộ Ngoại Tuyến (Offline-First Sync)](#13-module-10-cơ-chế-đồng-bộ-ngoại-tuyến-offline-first-sync)
    - 13.1. Nguyên lý hoạt động Offline-First: Ghi máy trước, Mạng sau
    - 13.2. Nhận biết các trạng thái của Huy hiệu đồng bộ (OfflineSyncBadge)
    - 13.3. Sử dụng Hộp thoại Chi tiết Hàng đợi (_OfflineSyncDetailSheet)
    - 13.4. Kích hoạt đồng bộ thủ công & Xử lý bản ghi lỗi (Dead Entries)
    - 13.5. Pipeline tải ảnh 2 bước & Kháng lỗi mạng tự động
14. [Xử Lý Sự Cố & Câu Hỏi Thường Gặp (FAQ)](#14-xử-lý-sự-cố--câu-hỏi-thường-gặp-faq)

---

## 1. TỔNG QUAN & CHUẨN BỊ BAN ĐẦU

### 1.1. Mục đích và đối tượng sử dụng
Ứng dụng **DMS VTHM Mobile** là công cụ làm việc bắt buộc dành cho:
- **Nhân viên kinh doanh / Nhân viên thị trường (Sales Rep / DSR)**: Thực hiện chấm công, di chuyển theo tuyến bán hàng, viếng thăm điểm bán, chụp ảnh trưng bày, khảo sát giá, phát triển điểm bán mới.
- **Giám sát bán hàng (Sales Supervisor - SS)**: Kiểm tra lộ trình, rà soát tiến độ viếng thăm, kiểm tra hình ảnh thực tế và theo dõi báo cáo hoạt động.

### 1.2. Cấp quyền ứng dụng trên thiết bị di động
Khi cài đặt và mở ứng dụng lần đầu, bạn **BẮT BUỘC** phải cấp đầy đủ các quyền sau:

| Quyền hạn | Mục đích sử dụng | Lưu ý quan trọng |
| :--- | :--- | :--- |
| 📍 **Vị trí (Location - GPS)** | Xác thực khoảng cách Geofence khi Check-in, chấm công và tính quãng đường di chuyển. | Chọn **"Trong khi dùng ứng dụng"** và bật tính năng **"Vị trí chính xác" (Precise Location)**. Không bật chế độ tiết kiệm pin làm giảm độ chính xác GPS. |
| 📷 **Máy ảnh (Camera)** | Chụp ảnh mặt tiền, quầy kệ trưng bày, ảnh selfie chấm công và ảnh khai báo vị trí. | Ứng dụng **cấm chọn ảnh từ thư viện** để đảm bảo 100% tính trung thực của bằng chứng thực địa. |
| 💾 **Bộ nhớ (Storage)** | Lưu trữ bộ nhớ đệm hình ảnh ngoại tuyến (`offline_customer_photos`) và cơ sở dữ liệu SQLite cục bộ. | Đảm bảo điện thoại còn trống ít nhất **500 MB** dung lượng khả dụng. |
| 🔔 **Thông báo (Notifications)** | Nhận thông báo nhắc chấm công vào/ra ca, tiến độ tuyến và gợi ý điểm bán lân cận. | Cho phép thông báo biểu ngữ và âm thanh để không bỏ lỡ ca làm việc. |

### 1.3. Quy định an toàn thiết bị & Chống gian lận
Hệ thống tích hợp công cụ kiểm soát tuân thủ [AntiFraudService](file:///c:/DMS_VTHM/dms-app/lib/core/services/anti_fraud_service.dart) kiểm tra tự động:
- 🚫 **Nghiêm cấm bật ứng dụng Giả lập vị trí (Fake GPS / Mock Location)**: Nếu thiết bị bật tính năng này, hệ thống sẽ phát hiện ngay lập tức và từ chối cho phép Check-in hoặc chấm công, đồng thời gắn cờ đỏ cảnh báo vi phạm gửi về máy chủ quản lý.
- ⏰ **Nghiêm cấm chỉnh sửa đồng hồ thiết bị (Clock Skew)**: Đồng hồ điện thoại phải luôn đặt ở chế độ *"Cập nhật ngày giờ tự động từ nhà mạng"*. Nếu đồng hồ bị chỉnh lùi hoặc chênh lệch quá ngưỡng cho phép (mặc định 15 phút), lượt ghi sẽ bị chặn hoặc gắn cờ kiểm toán rủi ro.

---

## 2. ĐĂNG NHẬP & THIẾT LẬP TÀI KHOẢN

### 2.1. Đăng nhập hệ thống & Duy trì phiên (90 ngày)
1. Mở ứng dụng DMS VTHM, tại màn hình Đăng nhập:
   - **Tên đăng nhập**: Nhập mã nhân viên hoặc tài khoản nội bộ do VTHM Group cấp (Ví dụ: `VTG920`, `TEST001`).
   - **Mật khẩu**: Nhập mật khẩu đã được cấp.
2. Nhấn nút **ĐĂNG NHẬP**.
3. **Cơ chế duy trì phiên thông minh**: Phiên đăng nhập chính (`access_token`) có hạn 1 giờ, nhưng hệ thống tích hợp `refresh_token` kéo dài **90 ngày (7.776.000 giây)**. Bạn **không cần đăng nhập lại mỗi ngày**, ứng dụng tự động gia hạn phiên ngầm khi có mạng.

> [!WARNING]
> Tài khoản bắt buộc phải được phòng Nhân sự cấp **Mã nhân viên** và gán vai trò **`crm_customer_self`** / **`employee`**. Nếu tài khoản mới chưa được gắn mã nhân viên, nút Chấm công sẽ bị vô hiệu hoá kèm thông báo nhắc liên hệ bộ phận nhân sự.

### 2.2. Khởi tạo & Tự động tải dữ liệu ban đầu
Ngay sau khi đăng nhập thành công vào màn hình [HomeScreen](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/screens/home_screen.dart), ứng dụng tự động kích hoạt gói đồng bộ nền:
- Tải quy tắc thị trường và ngưỡng định vị mới nhất (`/dms/mobile-rules`).
- Tải danh sách tuyến bán hàng được giao cho tài khoản.
- Tải toàn bộ danh sách điểm bán và lưu trữ vào cơ sở dữ liệu SQLite trên máy.
- Tải mẫu biểu mẫu khảo sát thị trường mới nhất.

### 2.3. Cài đặt cá nhân: Chế độ Tối (Dark Mode) & Ngôn ngữ
Truy cập tab **Cá nhân** (góc phải thanh điều hướng) để cấu hình:
- **Giao diện Tối (Dark Mode)**: Bật/Tắt công tắc để chuyển đổi giữa giao diện sáng thanh lịch và giao diện nền tối dịu mắt, tiết kiệm pin khi đi thị trường ngoài trời nắng.
- **Ngôn ngữ (Language)**: Chọn **Tiếng Việt** (mặc định) hoặc **English**.
- **Đăng xuất (Logout)**: Đăng xuất khỏi thiết bị khi bàn giao máy hoặc đổi tài khoản làm việc.

---

## 3. GIAO DIỆN CHÍNH & ĐIỀU HƯỚNG (NAVIGATION)

### 3.1. Thanh điều hướng dưới đáy (Bottom Navigation Bar)
Thanh điều hướng dưới chân màn hình gồm 5 nhánh chức năng cốt lõi:
1. 🏠 **Trang chủ (`/home`)**: Bảng điều khiển công việc trong ngày, thao tác nhanh và dòng thời gian thu nhỏ.
2. 👥 **Điểm bán (`/customers`)**: Sổ tay khách hàng, tra cứu thông tin và tạo điểm bán mới.
3. 🗺️ **Tuyến bán hàng (`/routes`)**: Lộ trình viếng thăm trong ngày theo tuyến (MCP) và bản đồ dẫn đường.
4. 📋 **Biểu mẫu (`/forms`)**: Danh sách các biểu mẫu khảo sát thị trường tự do.
5. 👤 **Cá nhân (`/profile`)**: Thông tin người dùng, quãng đường di chuyển và cài đặt hệ thống.

### 3.2. Thanh tiêu đề trên & Huy hiệu Đồng bộ (Top App Bar)
Trên thanh tiêu đề ở mọi màn hình chính:
- **Tiêu đề trang**: Cho biết màn hình bạn đang thao tác.
- **Biểu tượng Chuông thông báo**: Hiển thị chấm đỏ khi có thông báo nhắc việc mới chưa đọc.
- **Huy hiệu Đồng bộ Ngoại tuyến ([OfflineSyncBadge](file:///c:/DMS_VTHM/dms-app/lib/core/widgets/offline_sync_badge.dart))**:
  - Trạng thái trực quan giúp bạn luôn biết dữ liệu của mình đã được chuyển về máy chủ công ty an toàn hay chưa.
  - Bấm trực tiếp vào huy hiệu này để mở bảng kiểm tra chi tiết từng bản ghi đang chờ gửi.

### 3.3. Màn hình Trang chủ & 3 Thao tác nhanh (Quick Actions)
Tại [HomeScreen](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/screens/home_screen.dart), khu vực [HomeQuickActions](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/widgets/home_quick_actions.dart) cung cấp 3 hộp phím tắt nổi bật:
- 📷 **Box Chấm công (Màu Pastel Hổ phách `#FEF3C7`)**: Mở màn hình Chấm công vào/ra ca làm việc.
- 📍 **Box Khai báo vị trí (Màu Pastel Xanh ngọc `#CCFBF1`)**: Mở giao diện chụp ảnh khai báo địa điểm công tác ngoài tuyến.
- 📊 **Box Báo cáo (Màu Pastel Xanh lavender `#EEF2FF`)**: Mở menu lướt nhanh [ReportMenuBottomSheet](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/widgets/report_menu_bottom_sheet.dart) gồm:
  1. *Báo cáo viếng thăm & Hoạt động trong ngày*.
  2. *Lịch sử chấm công*.
  3. *Lịch sử khai báo vị trí*.
  4. *Nghi vấn rủi ro & Cảnh báo vị trí*.

---

## 4. MODULE 1: CHẤM CÔNG THỰC ĐỊA (ATTENDANCE)

Màn hình chi tiết: [AttendanceDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/screens/attendance_detail_screen.dart).

```
[Bắt đầu ca sáng 08:00] ──> Quét toạ độ GPS ──> Chụp ảnh Trước (Selfie) ──> Chụp ảnh Sau ──> [VÀO CA THÀNH CÔNG]
                                                                                                    │
                                                                                           Làm việc trong ngày
                                                                                                    │
[Kết thúc ca chiều 17:00] ──> Quét toạ độ GPS ──> Xác nhận Ra ca ──────────────────────────> [RA CA THÀNH CÔNG]
```

### 4.1. Khung giờ ca làm việc tiêu chuẩn
- **Giờ vào ca sáng**: **08:00 AM** (Hệ thống gửi thông báo nhắc từ 07:45 - 08:00; sau 08:05 sẽ cảnh báo vào ca muộn).
- **Giờ tan ca chiều**: **17:00 PM** (Hệ thống gửi thông báo nhắc từ 17:00; sau 17:15 sẽ cảnh báo chưa chốt công).

### 4.2. Quy trình Chấm công Vào ca (Check-in) bằng 2 ảnh xác thực
1. Tại Trang chủ, nhấn vào ô **Chấm công**.
2. Kiểm tra thông tin hiển thị trên màn hình:
   - Đồng hồ điện tử nhảy thời gian thực.
   - Thẻ vị trí GPS: Đảm bảo độ sai số GPS ở mức tốt (màu xanh lá, sai số < 20m).
   - Vùng làm việc được áp dụng (Văn phòng VVP, VHM hoặc Chế độ Mọi nơi `EVERYWHERE`).
3. Nhấn nút **CHẤM VÀO CA**:
   - Ứng dụng tự động kiểm tra GPS và chống gian lận.
   - Hộp thoại [AttendancePhotoCaptureDialog](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_photo_capture_dialog.dart) xuất hiện yêu cầu chụp **2 ảnh bắt buộc**:
     - **Tấm 1 (Camera trước)**: Ảnh chụp rõ mặt nhân viên tại địa điểm làm việc.
     - **Tấm 2 (Camera sau)**: Ảnh chụp quang cảnh/không gian làm việc xung quanh.
   - Ứng dụng tự động đóng dấu Watermark công ty lên cả 2 bức ảnh.
4. Bấm **Xác nhận gửi**: Hệ thống tải lượt chấm công và 2 ảnh lên máy chủ. Nút chấm công sẽ chuyển trạng thái ghi nhận giờ vào đầu tiên.

### 4.3. Quy trình Chấm công Ra ca (Check-out) cuối ngày
1. Khi hoàn thành ngày làm việc (sau 17:00), mở lại mục **Chấm công**.
2. Nút hành động chính sẽ tự động đổi sang nhãn **CHẤM RA CA** kèm biểu tượng đăng xuất.
3. Nhấn **CHẤM RA CA**:
   - Hệ thống quét toạ độ GPS hiện tại (toạ độ này được lưu lại để đối chiếu tính quãng đường di chuyển).
   - Ghi nhận giờ ra ca chính thức và tính toán tổng số giờ làm việc trong ngày (**Working Duration**).

### 4.4. Kiểm tra vùng chấm công (Geofence) & Xử lý ngoài vùng
- Nếu chính sách công ty quy định chấm công tại địa điểm cố định (Bán kính 200m) mà bạn đang đứng ngoài vùng:
  - Nút chấm công sẽ hiển thị cảnh báo ngoài vùng.
  - Hộp thoại [AttendanceOutOfRangeDialog](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_out_of_range_dialog.dart) sẽ thông báo rõ: *Bạn đang cách điểm làm việc [Tên địa điểm] X mét (Quy định: tối đa Y mét)*.
  - Bạn cần di chuyển lại gần khu vực văn phòng/chi nhánh để thực hiện chấm công.

### 4.5. Xem Thống kê tháng & Lịch sử chấm công
- **Thẻ Thống kê tháng ([MonthlyStatsCard](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/monthly_stats_card.dart))**: Xem tổng số ngày công đã đi làm trong tháng hiện tại và số ngày có cảnh báo trễ giờ.
- **Thẻ Lịch sử chấm công ([AttendanceHistoryCard](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_history_card.dart))**: Liệt kê chi tiết toàn bộ các lượt chấm công trong 7 ngày gần nhất kèm ảnh xem lại, thời gian và nhãn Vào/Ra rõ ràng.

---

## 5. MODULE 2: TUYẾN BÁN HÀNG & LỘ TRÌNH (ROUTE & MCP)

Màn hình chi tiết: [RouteScreen](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/screens/route_screen.dart).

```
   ┌─────────────────────────────────────────────────────────┐
   │             TUYẾN BÁN HÀNG (MCP) - HÔM NAY              │
   ├─────────────────────────────────────────────────────────┤
   │ [ Điểm bán 1 ] ──> Khoảng cách: 85m   ──> [ CHƯA GHÉ ]  │
   │ [ Điểm bán 2 ] ──> Khoảng cách: 320m  ──> [ CHƯA GHÉ ]  │
   │ [ Điểm bán 3 ] ──> Khoảng cách: 1.2km ──> [ ĐÃ GHÉ ✓ ]  │
   └─────────────────────────────────────────────────────────┘
```

### 5.1. Xem danh sách điểm bán theo tuyến được giao
- Tại thanh điều hướng, chọn tab **Tuyến bán hàng**.
- Bộ lọc phía trên cho phép bạn chọn:
  - Tuyến mặc định theo thứ trong tuần (Thứ Hai, Thứ Ba... Thứ Bảy).
  - Chọn một tuyến cụ thể trong danh sách các tuyến được phân công.
  - Chọn **Tất cả các tuyến** để xem toàn bộ danh sách điểm bán.
- Tuyến bán hàng được phân vùng bộ nhớ đệm an toàn theo từng tài khoản (`dms_user_routes_${accountKey}_v2`). Khi bạn không có mạng, danh sách tuyến vẫn hiển thị đầy đủ 100%.

### 5.2. Chế độ xem: Danh sách khoảng cách vs. Bản đồ Goong Map
Bạn có thể chuyển đổi linh hoạt giữa 2 chế độ hiển thị:
1. **Chế độ Danh sách (List View)**:
   - Sắp xếp thứ tự các điểm bán tự động theo **khoảng cách GPS thực tế từ gần đến xa** so với vị trí hiện tại của bạn.
   - Hiển thị khoảng cách chính xác (Ví dụ: `85m`, `350m`, `1.4 km`). Điểm nào gần bạn nhất sẽ được đưa lên đầu danh sách để tối ưu thời gian di chuyển.
2. **Chế độ Bản đồ (Map View - Goong Map)**:
   - Hiển thị trực quan toàn bộ các điểm bán dưới dạng các ghim (Marker) màu trên nền bản đồ số.
   - Vị trí hiện tại của bạn hiển thị bằng chấm xanh phát sóng.
   - Bấm vào một ghim điểm bán để xem tóm tắt thông tin và mở nút chỉ đường.

### 5.3. Nhận biết trạng thái viếng thăm các điểm bán
Mỗi thẻ điểm bán trên tuyến có màu sắc và huy hiệu trạng thái rõ ràng:
- ⚪ **Màu Xám / Trắng**: **Chưa ghé thăm** (Cần thực hiện trong ngày).
- 🟠 **Màu Cam nổi bật**: **Đang ghé thăm** (Bạn đã Check-in nhưng chưa bấm Check-out).
- 🟢 **Màu Xanh lá**: **Đã hoàn thành** (Đã Check-out thành công trong ngày hôm nay).

### 5.4. Tìm kiếm & Sắp xếp điểm bán thông minh
- Thanh tìm kiếm hỗ trợ gõ tìm kiếm không dấu (Ví dụ: gõ `nguyen` sẽ tìm ra `Nguyễn Văn A`, `Tạp hoá Nguyên`).
- Hỗ trợ tìm kiếm theo Mã điểm bán, Tên điểm bán hoặc Địa chỉ cụ thể.

---

## 6. MODULE 3: QUY TRÌNH VIẾNG THĂM ĐIỂM BÁN (STORE VISIT)

Màn hình chi tiết: [CheckInScreen](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/screens/check_in_screen.dart).

### 6.1. Quy trình chuẩn 6 bước tại điểm bán
Tại mỗi điểm bán trên tuyến, nhân viên thực hiện lần lượt theo quy trình chuẩn sau:

```
[1. BẤM CHECK-IN]
        │   Kiểm tra GPS Geofence (100m - 200m) & Cấm Fake GPS
        ▼
[2. CHỤP ẢNH TẠI ĐIỂM BÁN]
        │   Tự động đóng dấu Watermark toạ độ, địa chỉ & thời gian thực
        ▼
[3. ĐIỀN BIỂU MẪU KHẢO SÁT]
        │   Hoàn thành khảo sát giá, trưng bày, tồn kho bắt buộc
        ▼
[4. SOI ĐIỀU KIỆN CHECK-OUT]
        │   Kiểm tra 3 cổng: Đủ giờ ở lại? Đủ số ảnh? Đủ biểu mẫu?
        ▼
[5. BẤM CHECK-OUT ĐÓNG LƯỢT]
        │   Chọn "Mở cửa" hoặc "Đóng cửa" -> Chốt kết quả viếng thăm
        ▼
[HOÀN THÀNH VIẾNG THĂM]
```

---

### 6.2. Bước 1: Check-in điểm bán & Xác thực khoảng cách
1. Đến điểm bán, mở thẻ điểm bán trên danh sách tuyến, nhấn nút **Bắt đầu viếng thăm / Check-in**.
2. **Kiểm tra Năm luật Check-in từ hệ thống**:
   - **Luật ① (Tuyến được giao)**: Điểm bán phải thuộc tuyến quản lý của bạn.
   - **Luật ② (Mỗi ngày một lượt)**: Mỗi điểm bán chỉ được viếng thăm 1 lần trong ngày. Nếu đã hoàn thành, hệ thống sẽ từ chối check-in lần hai.
   - **Luật ③ (Không mở lượt chồng chéo)**: Bạn **không thể mở lượt mới nếu đang còn một lượt khác chưa check-out**. Hãy đóng hoặc huỷ lượt cũ trước.
   - **Luật ④ (Bán kính Geofence)**: Bạn phải đứng trong bán kính quy định của điểm bán (mặc định 100m - 200m). Nếu đứng cách xa (ví dụ 300m), hộp thoại [CheckinDistanceWarningDialog](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/widgets/checkin_distance_warning_dialog.dart) sẽ cảnh báo và yêu cầu lại gần quầy.
   - **Luật ⑤ (Chống Mock GPS)**: Cấm bật phần mềm giả lập toạ độ.
3. Khi điều kiện hợp lệ, phiên viếng thăm được mở, đồng hồ đếm thời gian bắt đầu chạy.

---

### 6.3. Bước 2: Chụp ảnh đóng dấu Watermark (Toạ độ & Giờ thực tế)
1. Tại khu vực hình ảnh của màn hình viếng thăm, nhấn **Chụp ảnh**.
2. Camera thiết bị mở lên để chụp trực tiếp:
   - Chụp ảnh mặt tiền biển hiệu điểm bán.
   - Chụp ảnh quầy kệ trưng bày sản phẩm VTHM.
   - Chụp vật phẩm quảng cáo (POSM) hoặc tài liệu liên quan.
3. **Cơ chế Watermark tự động bằng Canvas ([PhotoWatermarkHelper](file:///c:/DMS_VTHM/dms-app/lib/core/utils/photo_watermark_helper.dart))**:
   - Ngay khi chụp xong, ứng dụng tự động đóng dấu vĩnh viễn 4 dòng thông tin lên góc ảnh:
     - *Dòng 1*: Nhãn hiệu nhận diện `DMS VTHM`.
     - *Dòng 2*: Thời gian chụp chính xác đến từng giây (`DD/MM/YYYY HH:mm:ss`).
     - *Dòng 3*: Toạ độ GPS (`Lat: xx.xxxxxx, Lng: yy.yyyyyy`).
     - *Dòng 4*: Tên điểm bán và địa chỉ thực tế.
4. **Quy định về ảnh**:
   - Giới hạn tối đa **20 ảnh** cho một lượt viếng thăm.
   - Hệ thống tự động kiểm tra mã SHA-1 của tệp ảnh; nếu chụp trùng một tấm ảnh cũ, hệ thống sẽ cảnh báo không tải trùng.
   - Khi lượt viếng thăm chưa kết thúc, bạn có thể bấm icon thùng rác để xoá ảnh chụp bị mờ/lỗi. Sau khi đã Check-out, ảnh sẽ bị khoá hoàn toàn.

---

### 6.4. Bước 3: Điền biểu mẫu khảo sát trong lượt
1. Nhấn vào danh sách biểu mẫu khảo sát trong màn hình viếng thăm.
2. Xem các biểu mẫu được cấu hình cho điểm bán này (Ví dụ: *Khảo sát giá tháng*, *Khảo sát trưng bày*).
3. Biểu mẫu có nhãn màu đỏ **"Bắt buộc"** phải được điền và nộp trước khi ra về.
4. Nhập đầy đủ câu trả lời và nhấn **Nộp biểu mẫu**.

---

### 6.5. Bước 4: Soi điều kiện hoàn thành (Check-out Requirements)
Hệ thống cung cấp thẻ hiển thị điều kiện hoàn tất thời gian thực ([VisitRequirementsEntity](file:///c:/DMS_VTHM/dms-app/lib/features/visit/domain/entities/visit_requirements_entity.dart)):
- **Thời gian tối thiểu ở điểm bán**: Đếm ngược số phút/giây còn lại (Ví dụ: Bạn cần ở lại thêm 3 phút nữa mới được Check-out).
- **Số lượng ảnh còn thiếu**: Thông báo số lượng ảnh cần bổ sung (Ví dụ: Cần chụp thêm 1 ảnh trưng bày).
- **Biểu mẫu còn thiếu**: Danh sách các khảo sát bắt buộc chưa nộp.

> [!TIP]
> Nút **KẾT THÚC VIẾNG THĂM (CHECK-OUT)** chỉ sáng lên và cho phép bấm khi toàn bộ các điều kiện trên đã được thoả mãn (Không còn câu cảnh báo Blocker nào).

---

### 6.6. Bước 5: Check-out đóng lượt (Mở cửa vs. Đóng cửa)
Khi đã hoàn tất công việc tại điểm bán:
1. Nhấn nút **KẾT THÚC VIẾNG THĂM**.
2. Chọn kết quả viếng thăm:
   - **ĐIỂM BÁN MỞ CỬA (`visited`)**:
     - Áp dụng khi điểm bán hoạt động bình thường.
     - Bắt buộc qua đủ 3 cổng: Đủ thời gian tối thiểu, đủ số ảnh, nộp đủ biểu mẫu bắt buộc.
   - **ĐIỂM BÁN ĐÓNG CỬA (`closed`)**:
     - Áp dụng khi bạn đến nơi nhưng đại lý/cửa hàng đóng cửa, chủ đi vắng.
     - **Chính sách ưu đãi**: Được **MIỄN** thời gian tối thiểu và **MIỄN** biểu mẫu khảo sát (vì quầy đóng cửa không thể kiểm tra giá hay kiểm kê).
     - **Điều kiện bắt buộc**: Bắt buộc phải **chụp ít nhất 1 ảnh cửa hàng đóng cửa** làm bằng chứng thực địa và **nhập ghi chú lý do đóng cửa** (Ví dụ: *Cửa hàng sửa chữa, Chủ nhà nghỉ lễ*).
3. Ứng dụng ghi nhận toạ độ Check-out và hiển thị hộp thoại chúc mừng hoàn tất [CheckoutSuccessDialog](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/widgets/checkout_success_dialog.dart).

---

### 6.7. Tính năng khẩn cấp: Huỷ lượt viếng thăm (Cancel Visit)
- **Khi nào sử dụng?**: Khi bạn vừa bấm Check-in nhưng gặp sự cố đột xuất không thể tiếp tục lượt thăm (Khách hàng từ chối tiếp, có việc gia đình đột xuất, sự cố điện thoại hết pin...).
- **Cách thực hiện**:
  1. Tại màn hình viếng thăm đang mở, nhấn vào nút tuỳ chọn menu (3 chấm) ở góc trên bên phải.
  2. Chọn **Huỷ lượt viếng thăm này**.
  3. Xác nhận đồng ý huỷ.
- **Tác dụng**:
  - Phiên viếng thăm đang dở sẽ được huỷ ngay lập tức trên hệ thống.
  - Bạn được **giải phóng ngay lập tức**, không bị kẹt lỗi *"Còn lượt viếng thăm chưa đóng"* khi di chuyển sang điểm bán tiếp theo.
  - Điểm bán vừa huỷ không bị khoá — bạn hoàn toàn có thể quay lại viếng thăm điểm này vào buổi chiều cùng ngày.

---

## 7. MODULE 4: QUẢN LÝ KHÁCH HÀNG / ĐIỂM BÁN (CUSTOMERS)

Màn hình chi tiết: [CustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/customer_screen.dart).

```
   ┌─────────────────────────────────────────────────────────┐
   │               DANH SÁCH ĐIỂM BÁN (CUSTOMERS)            │
   ├─────────────────────────────────────────────────────────┤
   │ [🔍 Tìm tên, mã khách hàng, số điện thoại...]           │
   │                                                         │
   │ 🏪 CỬA HÀNG ĐẠI PHÁT              [Đại lý cấp 1]        │
   │ 📍 128 Nguyễn Trãi, P. Bến Thành, Q.1, TP.HCM           │
   │ 📞 0987.654.321 · Tuyến: Thứ 2 - Q1                     │
   │ [Xem chi tiết]                      [Chỉ đường Goong]   │
   └─────────────────────────────────────────────────────────┘
```

### 7.1. Tra cứu & Xem chi tiết thông tin điểm bán
- Nhấn tab **Điểm bán** trên thanh điều hướng dưới đáy.
- Danh sách hiển thị toàn bộ điểm bán bạn được phân quyền phụ trách.
- Bấm vào một điểm bán để mở [CustomerDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/customer_detail_screen.dart):
  - Thông tin chủ hộ kinh doanh, số điện thoại liên hệ (có nút bấm gọi điện trực tiếp).
  - Địa chỉ và vị trí ghim trên bản đồ.
  - Lịch sử các lần nhân viên công ty ghé thăm trong quá khứ.
  - Album ảnh thực địa đã chụp tại điểm bán.

---

### 7.2. Thêm mới điểm bán ngoại tuyến (Hỗ trợ chụp nhiều ảnh)
Màn hình: [AddCustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/add_customer_screen.dart).

> [!IMPORTANT]
> Bạn có thể tạo điểm bán mới ngay cả khi **HOÀN TOÀN KHÔNG CÓ MẠNG INTERNET**. Dữ liệu và hình ảnh được lưu an toàn trong máy và tự động tải lên khi có sóng.

1. Tại màn hình Điểm bán, nhấn nút dấu cộng tròn **(+) Thêm điểm bán** ở góc dưới.
2. Điền thông tin theo biểu mẫu:
   - **Tên điểm bán / Cửa hàng**: Tên bảng hiệu (Bắt buộc).
   - **Tuyến bán hàng**: Chọn tuyến phân công (được tự động lưu sẵn trong máy).
   - **Số điện thoại & Người liên hệ**: Nhập số điện thoại đại lý.
   - **Địa chỉ chi tiết**: Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành.
   - **Toạ độ GPS**: Bấm nút **"Lấy vị trí hiện tại"** để tự động điền toạ độ GPS chính xác nơi bạn đang đứng.
3. **Chụp ảnh điểm bán**:
   - Chụp ảnh mặt tiền biển hiệu và không gian cửa hàng.
   - Các ảnh chụp được lưu trữ vĩnh viễn vào thư mục an toàn của ứng dụng (`offline_customer_photos`).
4. Nhấn **LƯU ĐIỂM BÁN**:
   - Điểm bán mới xuất hiện **NGAY LẬP TỨC** trong danh sách khách hàng của bạn với huy hiệu *"Chờ đồng bộ"*.
   - Bạn có thể thực hiện Check-in viếng thăm điểm bán mới này ngay lập tức mà không cần đợi phản hồi từ máy chủ.

### 7.3. Chỉnh sửa thông tin khách hàng
Màn hình: [EditCustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/edit_customer_screen.dart).
- Dùng khi phát hiện đại lý thay đổi số điện thoại, đổi biển hiệu hoặc cập nhật lại toạ độ GPS chuẩn xác hơn.
- Sau khi chỉnh sửa, bấm **Lưu thay đổi** để cập nhật dữ liệu.

---

## 8. MODULE 5: BIỂU MẪU KHẢO SÁT THỊ TRƯỜNG (MARKET FORMS)

Màn hình chi tiết: [FormsScreen](file:///c:/DMS_VTHM/dms-app/lib/features/forms/presentation/screens/forms_screen.dart) & [MarketFormFillScreen](file:///c:/DMS_VTHM/dms-app/lib/features/forms/presentation/screens/market_form_fill_screen.dart).

### 8.1. Phân biệt 2 loại biểu mẫu
Hệ thống DMS VTHM hỗ trợ 2 nhóm biểu mẫu chuyên dụng:
1. **Biểu mẫu viếng thăm (`kind = survey`)**:
   - Gắn liền với một điểm bán cụ thể trong luồng Check-in.
   - Thường dùng cho: Khảo sát tồn kho đại lý, chụp ảnh trưng bày quầy kệ, kiểm tra giá bán lẻ của đối thủ cạnh tranh tại quầy.
2. **Biểu mẫu thu thập tự do (`kind = collect`)**:
   - Hiển thị trực tiếp tại tab **Biểu mẫu** trên thanh điều hướng.
   - Không bắt buộc gắn với lượt viếng thăm. Thường dùng cho: Khảo sát người tiêu dùng qua đường, thu thập thông tin đại lý mới tiềm năng, báo cáo chương trình khuyến mãi đột xuất của đối thủ.

---

### 8.2. Hướng dẫn thao tác các loại câu hỏi trong biểu mẫu
Hệ thống hỗ trợ công cụ vẽ biểu mẫu động linh hoạt:

| Loại câu hỏi | Giao diện trên app | Hướng dẫn thao tác |
| :--- | :--- | :--- |
| **Tiêu đề nhóm (`heading`)** | Khung màu phân cách lớn | Đọc hướng dẫn hoặc mục lục câu hỏi. |
| **Nhập văn bản (`text` / `textarea`)** | Ô nhập chữ | Nhập nội dung. Có hỗ trợ nút **Micro thu âm giọng nói** để chuyển giọng nói tiếng Việt thành văn bản tự động. |
| **Tiền tệ (`currency`)** | Ô nhập số tiền | Nhập số tiền (Ứng dụng tự động định dạng dấu phẩy hàng nghìn, ví dụ: `150,000 đ`). |
| **Lựa chọn một (`select` / `radio`)** | Nút bấm tròn hoặc menu xổ xuống | Chạm để chọn 1 đáp án duy nhất. |
| **Lựa chọn nhiều (`checkbox` / `multiselect`)** | Hộp kiểm vuông | Chạm để chọn một hoặc nhiều phương án phù hợp. |
| **Ngày giờ (`date` / `datetime`)** | Ô lịch chọn ngày | Nhấn để mở bộ chọn lịch ngày/tháng/năm. |
| **Chọn điểm bán (`customer`)** | Danh sách chọn đại lý | Tìm và chọn khách hàng liên quan trong tuyến. |
| **📷 Ô ẢNH THỊ TRƯỜNG (`image`)** | Nút máy ảnh chuyên dụng | **Chụp ảnh thực tế** (Biển hiệu, Bảng giá đối thủ, Kệ hàng trưng bày). Xem số lượng ảnh tối đa quy định bên cạnh. Mỗi ảnh chụp được nén chuẩn và đóng dấu token trước khi nộp. |

### 8.3. Cơ chế logic ẩn/hiện câu hỏi có điều kiện
Biểu mẫu tích hợp cơ chế logic thông minh: Một số câu hỏi phụ sẽ **tự động xuất hiện hoặc ẩn đi** dựa trên câu trả lời của bạn ở câu trước.
*(Ví dụ: Khi bạn chọn "Có bán hàng của đối thủ", hệ thống mới tự động làm xuất hiện thêm câu "Tên đối thủ" và "Giá bán của đối thủ")*.

---

## 9. MODULE 6: KHAI BÁO VỊ TRÍ THỰC ĐỊA (POSITION DECLARATION)

Màn hình chi tiết: [PositionDeclarationScreen](file:///c:/DMS_VTHM/dms-app/lib/features/position_declaration/presentation/screens/position_declaration_screen.dart).

```
   ┌─────────────────────────────────────────────────────────┐
   │                  KHAI BÁO VỊ TRÍ THỰC ĐỊA               │
   ├─────────────────────────────────────────────────────────┤
   │ 📌 LÝ DO KHAI BÁO: [ 001 - Công tác ngoại tỉnh      ▼ ] │
   │                                                         │
   │ 📷 ẢNH CHỨNG MINH THỰC ĐỊA:                             │
   │    [ Ảnh chụp có Watermark GPS & Giờ thực tế ]          │
   │                                                         │
   │ 📝 GHI CHÚ: "Đi phối hợp xử lý khiếu nại tại Long Xuyên"│
   │                                                         │
   │ [ GỬI KHAI BÁO VỊ TRÍ ]                                 │
   └─────────────────────────────────────────────────────────┘
```

### 9.1. Khi nào cần Khai báo vị trí?
Khai báo vị trí được sử dụng khi nhân viên **ở ngoài các điểm bán thuộc tuyến**, phục vụ các tình huống công việc thực tế:
- Đi công tác ngoại tỉnh, đi khảo sát vùng thị trường mới chưa có mã đại lý.
- Đi họp đột xuất tại chi nhánh, tham gia hội nghị khách hàng.
- Đi phối hợp giải quyết khiếu nại, sự cố đơn hàng hoặc thủ tục hành chính.

> [!NOTE]
> Khai báo vị trí là bản ghi **Một mốc duy nhất (Append-only)**: Không có Check-out, không tính thời lượng ở lại. Gửi thành công sẽ được ghi nhận vào lịch sử và **không thể sửa/xoá**.

### 9.2. Thao tác khai báo: Lý do, Chụp ảnh Watermark & Ghi chú
1. Tại Trang chủ, nhấn vào ô **Khai báo vị trí** (hoặc mở từ menu bên).
2. **Chọn Lý do**: Chọn lý do phù hợp trong danh mục chuẩn hoá (Ví dụ: `001 - Công tác ngoại tỉnh`, `002 - Phối hợp giải quyết công việc ngoài tuyến`). Danh mục này đã được lưu sẵn trong máy nên chọn được cả khi mất sóng.
3. **Chụp ảnh thực địa**: Nhấn nút chụp ảnh không gian bạn đang đứng. Ảnh tự động được đóng dấu Watermark toạ độ GPS, ngày giờ và địa chỉ.
4. **Nhập ghi chú**: Diễn giải ngắn gọn công việc đang xử lý.
5. Nhấn nút **GỬI KHAI BÁO**. Khi có mạng, bản ghi được gửi ngay. Khi mất mạng, bản ghi được cất an toàn vào hàng đợi ngoại tuyến.

### 9.3. Lịch sử khai báo vị trí của bản thân
- Truy cập [PositionDeclarationHistoryScreen](file:///c:/DMS_VTHM/dms-app/lib/features/position_declaration/presentation/screens/position_declaration_history_screen.dart) để xem lại danh sách các lượt khai báo vị trí đã thực hiện theo từng ngày.
- Bấm vào từng lượt để xem lại ảnh chụp thực tế và toạ độ đã ghi nhận.

---

## 10. MODULE 7: THEO DÕI QUÃNG ĐƯỜNG DI CHUYỂN (MY TRAVEL)

Màn hình chi tiết: [MyTravelScreen](file:///c:/DMS_VTHM/dms-app/lib/features/travel/presentation/screens/my_travel_screen.dart).

```
[Chấm công Vào ca] ──chặng 1──> [Điểm bán 1] ──chặng 2──> [Điểm bán 2] ──chặng 3──> [Điểm bán cuối]
     (08:00 AM)                   (09:15 AM)                  (10:30 AM)                  (16:45 PM)
```

### 10.1. Nguyên lý tính quãng đường tự động qua các mốc thực tế
- Nhân viên **KHÔNG PHẢI TỰ NHẬP TAY SỐ KM**.
- Hệ thống máy chủ tự động tính toán chính xác quãng đường di chuyển bằng xe máy theo **đường bộ thực tế (Goong Maps Routing API)** dựa vào các mốc:
  - **Chặng đầu (`start`)**: Nối từ toạ độ bạn **Chấm công Vào ca** buổi sáng đến toạ độ bạn **Check-in điểm bán đầu tiên**.
  - **Các chặng giữa (`between`)**: Nối từ toạ độ bạn **Check-out điểm bán trước** đến toạ độ bạn **Check-in điểm bán tiếp theo**.
  - **Điểm dừng cuối cùng**: Chuỗi tính toán dừng lại ở **Điểm bán cuối cùng trong ngày** (Đoạn đường từ điểm bán cuối về nhà không nằm trong chi phí công tác).

> [!IMPORTANT]
> **Hai hành động quyết định quãng đường của bạn có được ghi nhận đủ hay không:**
> 1. **Phải Chấm công Vào ca bằng app**: Nếu buổi sáng bạn quên chấm công trên app, mốc bắt đầu sẽ bị khuyết và chặng đầu tiên sẽ nhận **0 km**.
> 2. **Phải bấm Check-out khi rời quầy**: Toạ độ lúc Check-out là điểm xuất phát của chặng tiếp theo.

### 10.2. Ba trạng thái con số km (Cần phân biệt rõ)

| Trạng thái hiển thị | Ý nghĩa trên hệ thống | Nhân viên cần biết |
| :--- | :--- | :--- |
| **Con số cụ thể (VD: `18.5 km`)** | Quãng đường đã được máy chủ tính toán hoàn tất. | Con số đã chốt chính thức, làm căn cứ chi trả phụ cấp xăng xe/công tác phí. |
| **`0 km` (Kèm cảnh báo)** | **Thiếu mốc toạ độ**: Do quên chấm công vào ca hoặc không có toạ độ Check-in/out. | Không thể tính toán chặng này do thiếu dữ liệu xuất phát. |
| **Gạch ngang `—`** | **Chưa tính toán**: Tác vụ máy chủ tính quãng đường chạy tự động vào **01:30 sáng hôm sau**. | Trong ngày làm việc hiện tại, số km sẽ hiện `—` là hoàn toàn bình thường. Sáng hôm sau mở app sẽ thấy số km hoàn tất. |

### 10.3. Tra cứu lịch sử chặng đường theo ngày công
- Vào tab **Cá nhân** -> Chọn **Quãng đường của tôi**.
- Chọn ngày công để xem chi tiết từng chặng di chuyển (Ví dụ: *Chặng 1: Từ Văn phòng đến Tạp hoá An Bình - 4.2 km*, *Chặng 2: Từ Tạp hoá An Bình đến Đại lý Hưng Phát - 2.8 km*).

---

## 11. MODULE 8: BÁO CÁO HOẠT ĐỘNG TRONG NGÀY (DAILY REPORT)

Màn hình chi tiết: [DailyReportScreen](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/screens/daily_report_screen.dart).

```
   ┌─────────────────────────────────────────────────────────┐
   │               BÁO CÁO HOẠT ĐỘNG TRONG NGÀY              │
   ├─────────────────────────────────────────────────────────┤
   │ 🎯 TIẾN ĐỘ: 14 / 16 Điểm bán (88%)                      │
   │ 🟢 Đúng vị trí: 13      🟠 Chờ duyệt: 1     🔴 Rủi ro: 0│
   ├─────────────────────────────────────────────────────────┤
   │ [Tất cả]  [Viếng thăm]  [Chấm công]  [Khai báo]  [Rủi ro]│
   │                                                         │
   │ 08:02  [Chấm công]     Vào ca sáng (Đúng giờ)           │
   │ 08:45  [Viếng thăm]    Đại lý Minh Châu (Check-in)      │
   │ 09:10  [Viếng thăm]    Đại lý Minh Châu (Hoàn thành)    │
   │ 10:15  [Khai báo]      Họp tổ kinh doanh ngoài tuyến    │
   └─────────────────────────────────────────────────────────┘
```

### 11.1. Thống kê KPI hoạt động trong ngày
Đầu màn hình tổng hợp toàn bộ các chỉ số KPI thực địa trong ngày được chọn:
- **Tổng lượt ghé thăm**: Số điểm bán bạn đã thực hiện viếng thăm.
- **Tỷ lệ hoàn thành**: Tỷ lệ phần trăm số điểm bán đã đóng lượt thành công so với kế hoạch tuyến.
- **Đúng vị trí**: Số lượt ghé thăm có khoảng cách Geofence chuẩn xác (< 100m).
- **Cảnh báo rủi ro**: Số lượt ghé thăm có nghi vấn sai lệch toạ độ hoặc cảnh báo thiết bị.

### 11.2. Dòng thời gian Timeline & 5 Tab lọc hoạt động
Thẻ [DailyActivityTimelineCard](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/daily_activity_timeline_card.dart) sắp xếp toàn bộ hoạt động của bạn theo thứ tự thời gian giảm dần với 5 tab lọc:
1. **Tất cả**: Xem toàn cảnh diễn biến một ngày làm việc từ lúc vào ca đến lúc ra ca.
2. **Viếng thăm**: Lọc riêng các sự kiện Check-in, chụp ảnh và Check-out tại các cửa hàng.
3. **Chấm công**: Lọc các lượt Chấm công Vào ca và Ra ca.
4. **Khai báo**: Lọc các mốc Khai báo vị trí công tác ngoài tuyến.
5. **Gian lận / Cảnh báo**: Lọc các lượt bị ghi nhận sai lệch vị trí hoặc cảnh báo thiết bị để giải trình với quản lý nếu cần.

### 11.3. Xem chi tiết hoạt động thực địa
Nhấn vào bất kỳ mục nào trên dòng thời gian để mở bảng chi tiết [ActivityDetailSheet](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/activity_detail_sheet.dart):
- Xem ảnh chụp thực tế có đóng dấu Watermark rõ nét.
- Xem toạ độ GPS lúc thực hiện và khoảng cách sai lệch so với toạ độ đăng ký của cửa hàng.
- Thời gian chính xác đến từng phút giây.

---

## 12. MODULE 9: TRUNG TÂM THÔNG BÁO & NHẮC VIỆC (NOTIFICATIONS)

Màn hình chi tiết: [NotificationsScreen](file:///c:/DMS_VTHM/dms-app/lib/features/notifications/presentation/screens/notifications_screen.dart).

Dịch vụ thông báo nền thông minh [AppNotificationService](file:///c:/DMS_VTHM/dms-app/lib/core/services/app_notification_service.dart) liên tục hỗ trợ nhắc việc cho nhân viên:

### 12.1. Bảy loại thông báo nhắc nhở tự động

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🔔 1. NHẮC VÀO CA SÁNG (07:50 - 08:05)                                       │
│    "Sắp đến giờ vào ca (08:00). Đừng quên chấm công để ghi nhận công hôm nay!"│
├──────────────────────────────────────────────────────────────────────────────┤
│ 🗺️ 2. TÓM TẮT LỘ TRÌNH ĐẦU NGÀY (08:15)                                      │
│    "Hôm nay bạn có 16 điểm bán cần viếng thăm trên tuyến 'Thứ 2 - Q1'.      │
│     Chúc bạn một ngày làm việc hiệu quả!"                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ ⚡ 3. CẢNH BÁO TIẾN ĐỘ TUYẾN (11:30 & 15:30)                                 │
│    "Bạn đã hoàn thành 8/16 điểm bán (50%). Hãy tăng tốc để kịp tiến độ!"    │
├──────────────────────────────────────────────────────────────────────────────┤
│ ⚠️ 4. CẢNH BÁO QUÊN CHECK-OUT                                                │
│    "Bạn đang check-in tại 'Đại lý Minh Châu' hơn 45 phút. Đừng quên hoàn     │
│     thành biểu mẫu và bấm Kết thúc viếng thăm!"                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📍 5. GỢI Ý ĐIỂM BÁN LÂN CẬN THÔNG MINH                                      │
│    "Bạn đang ở gần 'Tạp hoá Hương Sen' (cách 85m) trên tuyến hôm nay.        │
│     Ghé thăm ngay để tối ưu lộ trình di chuyển!"                             │
├──────────────────────────────────────────────────────────────────────────────┤
│ 🏁 6. NHẮC RA CA CUỐI NGÀY (17:00 - 17:15)                                   │
│    "Đã đến giờ tan ca (17:00). Đừng quên bấm Ra ca để chốt công nhé!"        │
├──────────────────────────────────────────────────────────────────────────────┤
│ ☁️ 7. THÔNG BÁO ĐỒNG BỘ THÀNH CÔNG                                           │
│    "Đã đồng bộ thành công toàn bộ 5 bản ghi ngoại tuyến lên hệ thống!"       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 12.2. Thao tác xem thông báo & Đánh dấu đã đọc
- Chạm vào biểu tượng quả chuông ở thanh tiêu đề trên để mở màn hình Thông báo.
- Chạm vào một thông báo để **chuyển thẳng đến màn hình nghiệp vụ liên quan** (Ví dụ: chạm thông báo nhắc chấm công sẽ dẫn thẳng đến màn Chấm công).
- Bấm nút **"Đánh dấu đã đọc tất cả"** ở góc trên để xoá các chấm đỏ thông báo chưa đọc.

---

## 13. MODULE 10: CƠ CHẾ ĐỒNG BỘ NGOẠI TUYẾN (OFFLINE-FIRST SYNC)

Kiến trúc cốt lõi: [SyncService](file:///c:/DMS_VTHM/dms-app/lib/core/sync/sync_service.dart) & Cơ sở dữ liệu SQLite [AppDatabase](file:///c:/DMS_VTHM/dms-app/lib/core/database/app_database.dart).

```
   NGƯỜI DÙNG BẤM "LƯU" / "CHECK-IN" / "NỘP PHIẾU"
                    │
                    ▼
   [1. SINH MÃ DUY NHẤT client_uuid] (Ngay lập tức, 1 lần duy nhất)
                    │
                    ▼
   [2. LƯU AN TOÀN VÀO SQLITE TRÊN MÁY] (Hiển thị ngay trên UI)
                    │
                    ▼
   [3. XẾP VÀO HÀNG ĐỢI sync_queue (FIFO)]
                    │
                    ├──────────────────────────┐
                    ▼                          ▼
             [Có sóng Internet]          [Mất sóng Internet]
                    │                          │
                    ▼                          ▼
     Đẩy ngay lên máy chủ server        Giữ an toàn trong máy
                    │                          │
                    ▼                          │  (Chờ khi có mạng lại)
       Máy chủ xác nhận 200                    └──────────┐
                    │                                     ▼
                    ▼                          Tự động kích hoạt gửi bù
      Xoá khỏi hàng đợi thành công               (Theo thứ tự phát sinh)
```

### 13.1. Nguyên lý hoạt động Offline-First: Ghi máy trước, Mạng sau
- **Không bao giờ làm mất dữ liệu của bạn**: Khi bạn ở vùng không có sóng 3G/4G/Wifi (tầng hầm, nhà kho, vùng sâu vùng xa), mọi hành động:
  - Tạo khách hàng mới
  - Check-in điểm bán
  - Chụp ảnh thực địa
  - Điền biểu mẫu thị trường
  - Khai báo vị trí
  đều được lưu trữ **ngay lập tức vào bộ nhớ trong của điện thoại**. Bạn tiếp tục làm việc bình thường mà không bị màn hình chờ xoay vòng xoay tròn làm gián đoạn.
- **Bảo toàn thời gian thực qua Đồng hồ đơn điệu (`queued_seconds`)**: Dù bạn viếng thăm điểm bán lúc 09:00 sáng khi mất mạng và đến 12:00 trưa mới có mạng để đồng bộ, máy chủ vẫn ghi nhận chính xác bạn đã có mặt lúc 09:00 sáng.

---

### 13.2. Nhận biết các trạng thái của Huy hiệu đồng bộ (OfflineSyncBadge)
Huy hiệu nằm trên thanh tiêu đề trên đổi màu trực quan theo tình trạng kết nối:

| Màu sắc huy hiệu | Biểu tượng | Trạng thái hiển thị | Ý nghĩa |
| :---: | :---: | :--- | :--- |
| 🟢 **Xanh lá cây** | `Icons.cloud_done` | **Đã đồng bộ** | Thiết bị đang có mạng và toàn bộ dữ liệu trên máy đã được cập nhật thành công lên máy chủ công ty. |
| 🟡 **Màu Vàng hổ phách** | `Icons.cloud_off` | **Ngoại tuyến (X chờ)** | Điện thoại đang bị mất kết nối mạng. Có X bản ghi đang nằm an toàn trong hàng đợi của máy. |
| 🔵 **Màu Xanh dương** | `Icons.cloud_upload` | **X chờ gửi** | Đang có kết nối mạng và hệ thống đang tự động tải X bản ghi lên máy chủ. |
| 🔴 **Màu Đỏ hồng** | `Icons.error_outline` | **X lỗi** | Có bản ghi bị máy chủ từ chối do vi phạm quy tắc. Cần mở ra kiểm tra. |

---

### 13.3. Sử dụng Hộp thoại Chi tiết Hàng đợi (_OfflineSyncDetailSheet)
Khi nhấn vào Huy hiệu đồng bộ, hộp thoại chi tiết xuất hiện:
- **Tình trạng mạng**: Báo rõ điện thoại đang có Wifi/4G hay đang ngoại tuyến.
- **Hộp thống kê**: Thống kê số lượng bản ghi *Đang chờ gửi* và *Lỗi đồng bộ*.
- **Danh sách nhận diện chính xác từng loại dữ liệu**:
  - 👤 *Thêm khách hàng mới: [Tên khách hàng]* kèm địa chỉ và tuyến.
  - 📍 *Khai báo vị trí: [Lý do khai báo]* kèm địa chỉ.
  - 📋 *Biểu mẫu thị trường: [Mã phiếu]* kèm số lượng câu trả lời.
  - 🏪 *Lượt check-in: [Tên điểm bán]* kèm thời gian check-in.
  - 📷 *Ảnh thực địa* kèm dung lượng ảnh.

---

### 13.4. Kích hoạt đồng bộ thủ công & Xử lý bản ghi lỗi (Dead Entries)
- **Đồng bộ thủ công**: Khi vừa đi từ vùng mất sóng ra nơi có mạng 4G khoẻ, bạn có thể bấm vào Huy hiệu đồng bộ -> Nhấn nút **ĐỒNG BỘ NGAY BÂY GIỜ** để đẩy toàn bộ dữ liệu lên máy chủ ngay tức khắc mà không cần chờ chu kỳ tự động.
- **Xử lý bản ghi lỗi (Dead Queue Entries)**:
  - Nếu một bản ghi bị lỗi vĩnh viễn (Ví dụ: Điểm bán đã bị admin huỷ bỏ trên hệ thống), bản ghi đó sẽ chuyển sang danh sách lỗi màu đỏ.
  - Bạn có thể xem lý do lỗi từ máy chủ và bấm **"Xoá tất cả"** để dọn sạch hàng đợi lỗi, giúp huy hiệu trở lại màu xanh bình thường.

---

### 13.5. Pipeline tải ảnh 2 bước & Kháng lỗi mạng tự động
- **Bước 1**: Khi chụp ảnh tạo điểm bán ngoại tuyến, ảnh được lưu trữ an toàn trong thư mục vĩnh viễn của máy.
- **Bước 2**: Khi có mạng, dịch vụ đồng bộ tự động tải tệp ảnh lên máy chủ trước để nhận mã xác thực ảnh 32 ký tự hex (`photo_token`), sau đó mới gửi gói dữ liệu điểm bán kèm mã ảnh.
- **Cơ chế Kháng lỗi thông minh**: Nếu việc tải ảnh bị rớt mạng giữa chừng, hệ thống sẽ tự động hoãn lại và thử lại theo cơ chế Exponential Backoff, **tuyệt đối không gửi dữ liệu thiếu ảnh lên máy chủ** để tránh việc bị máy chủ từ chối lỗi dữ liệu.

---

## 14. XỬ LÝ SỰ CỐ & CÂU HỎI THƯỜNG GẶP (FAQ)

### ❓ Câu 1: Tại sao tôi bấm Chấm công nhưng nút bị mờ và báo "Chưa có mã nhân viên"?
> **Trả lời**: Tài khoản của bạn là tài khoản mới tạo và chưa được liên kết với hồ sơ nhân sự nội bộ. Hãy liên hệ với phòng Nhân sự hoặc Quản trị viên DMS của VTHM Group để được bổ sung Mã nhân viên vào hệ thống.

---

### ❓ Câu 2: Tôi đứng ngay trước cửa đại lý nhưng app báo "Bạn đang cách điểm bán 180m, hãy lại gần hơn"?
> **Trả lời**: 
> 1. Kiểm tra xem điện thoại của bạn đã bật chế độ **"Vị trí chính xác" (High Accuracy / Precise Location)** trong phần Cài đặt vị trí hay chưa.
> 2. Nếu đang đứng dưới mái tôn hoặc trong ngõ hẻm làm sóng GPS bị lệch, hãy bước ra ngoài trời thoáng khoảng 10 - 15 giây để điện thoại bắt lại toạ độ vệ tinh chính xác.
> 3. Nếu toạ độ gốc của đại lý đăng ký trên hệ thống bị sai lệch so với thực tế, hãy chụp ảnh mặt tiền, hoàn thành viếng thăm và dùng tính năng **Sửa điểm bán** để cập nhật lại toạ độ chuẩn cho lần ghé thăm sau.

---

### ❓ Câu 3: Tôi đang Check-in tại điểm bán thì khách hàng đóng cửa đi vắng, làm sao để tôi check-in điểm tiếp theo?
> **Trả lời**: Bạn có 2 cách xử lý:
> - **Cách 1 (Nếu đã ở đó và muốn ghi nhận công)**: Bấm Check-out -> Chọn kết quả **"Đóng cửa" (Closed)** -> Chụp 1 ảnh cửa hàng đóng cửa làm bằng chứng và ghi chú lý do. Bạn sẽ được miễn thời gian tối thiểu và miễn điền biểu mẫu.
> - **Cách 2 (Nếu muốn rời đi ngay và ghé lại sau)**: Bấm nút menu 3 chấm ở góc phải màn hình viếng thăm -> Chọn **"Huỷ lượt viếng thăm này"**. Phiên viếng thăm sẽ được huỷ ngay lập tức, bạn có thể đến điểm tiếp theo bình thường và có thể quay lại điểm này vào buổi chiều.

---

### ❓ Câu 4: Tôi bị mất mạng cả buổi sáng, dữ liệu có bị mất không?
> **Trả lời**: **Hoàn toàn không mất dữ liệu!** Ứng dụng DMS VTHM được thiết kế theo chuẩn Offline-First. Toàn bộ thông tin khách hàng mới, lượt viếng thăm, hình ảnh và câu trả lời khảo sát đều được lưu giữ an toàn tuyệt đối trong bộ nhớ điện thoại. Khi điện thoại kết nối lại Wifi hoặc 4G, dữ liệu sẽ tự động chuyển về máy chủ công ty.

---

### ❓ Câu 5: Tại sao trong mục "Quãng đường của tôi", số km của ngày hôm nay lại hiện dấu gạch ngang "—"?
> **Trả lời**: Đây là hoạt động hoàn toàn bình thường. Hệ thống máy chủ tự động quét và tính toán quãng đường di chuyển bằng thuật toán bản đồ xe máy vào lúc **01:30 sáng mỗi đêm**. Sáng ngày hôm sau bạn mở mục Quãng đường sẽ thấy hiển thị đầy đủ số km đã đi của ngày hôm trước.

---

### ❓ Câu 6: Tôi có được chỉnh lùi giờ trên điện thoại để chấm công đúng giờ không?
> **Trả lời**: **Tuyệt đối không!** Hệ thống tích hợp cơ chế chống gian lận thời gian qua đồng hồ đơn điệu và thời gian máy chủ. Nếu bạn chỉnh giờ điện thoại lệch quá ngưỡng cho phép, hệ thống sẽ phát hiện hành vi can thiệp đồng hồ (Clock Skew) và tự động khoá chức năng hoặc gắn cờ vi phạm gửi về cho Giám sát bán hàng.

---

## THÔNG TIN HỖ TRỢ KỸ THUẬT NỘI BỘ VTHM

Nếu gặp bất kỳ sự cố kỹ thuật nào trong quá trình sử dụng ứng dụng di động:
- **Bộ phận IT Support**: Hotline nội bộ hoặc liên hệ nhóm Zalo Hỗ trợ Kỹ thuật DMS VTHM.
- **Thời gian tiếp nhận**: Từ 07:30 đến 18:00 (Thứ Hai đến Thứ Bảy).
- **Khi báo lỗi**: Vui lòng chụp ảnh màn hình lỗi, ghi rõ Mã nhân viên và dòng điện thoại đang sử dụng để bộ phận kỹ thuật hỗ trợ nhanh nhất.

---
*Tài liệu được biên soạn và cập nhật theo phiên bản hoàn thiện của hệ thống DMS VTHM Mobile.*

# CẨM NANG HƯỚNG DẪN SỬ DỤNG TOÀN DIỆN ỨNG DỤNG DMS VTHM MOBILE
## Dành Cho Nhân Viên Kinh Doanh Thực Địa (Sales Rep / DSR) & Giám Sát Bán Hàng (SS)

---

> [!NOTE]
> **Hệ thống Quản lý Phân phối Thực địa (DMS VTHM Mobile)** là ứng dụng di động tác nghiệp chuyên dụng dành cho toàn bộ lực lượng bán hàng, nhân viên thị trường và giám sát của **VTHM Group**.
> Ứng dụng được xây dựng theo kiến trúc **Offline-First**, đảm bảo người dùng có thể tác nghiệp liên tục, ổn định và đầy đủ chức năng ngay cả khi làm việc tại các khu vực hoàn toàn mất kết nối mạng Internet hoặc điều kiện sóng yếu.

---

## MỤC LỤC CHI TIẾT

1. [Tổng Quan & Chuẩn Bị Ban Đầu](#1-tổng-quan--chuẩn-bị-ban-đầu)
   - 1.1. Giới thiệu hệ thống & Kiến trúc Offline-First
   - 1.2. Phân quyền và đối tượng người dùng
   - 1.3. Cấp quyền ứng dụng bắt buộc trên thiết bị di động
   - 1.4. Quy định an toàn thiết bị & Cơ chế chống gian lận (Anti-Fraud)
2. [Kịch Bản Thực Tế: Một Ngày Làm Việc Tiêu Chuẩn Của Nhân Viên Sale](#2-kịch-bản-thực-tế-một-ngày-làm-việc-tiêu-chuẩn-của-nhân-viên-sale)
   - 2.1. Sơ đồ dòng chảy hành trình 1 ngày làm việc
   - 2.2. Giai đoạn 1 (07:30 - 08:30): Đầu ngày – Nhắc ca, Chấm công Vào ca & Định hình lộ trình
   - 2.3. Giai đoạn 2 (08:30 - 11:30): Buổi sáng thực địa – Viếng thăm tuyến & Xử lý tình huống đóng cửa
   - 2.4. Giai đoạn 3 (11:30 - 13:00): Nghỉ trưa – Rà soát KPI nửa ngày & Tự động tiết kiệm pin
   - 2.5. Giai đoạn 4 (13:00 - 16:30): Buổi chiều thực địa – Tác nghiệp ngoại tuyến, Mở điểm bán mới & Khai báo ngoài tuyến
   - 2.6. Giai đoạn 5 (16:30 - 17:15): Cuối ngày – Rà soát Timeline, Kiểm tra km tích luỹ & Chấm công Ra ca
   - 2.7. Cơ chế tính quãng đường tức thì: Cập nhật thời gian thực ngay khi hoàn thành viếng thăm
3. [Đăng Nhập, Thiết Lập Phiên & Điều Hướng Chung](#3-đăng-nhập-thiết-lập-phiên--điều-hướng-chung)
   - 3.1. Đăng nhập hệ thống & Duy trì phiên an toàn 90 ngày (`refresh_token`)
   - 3.2. Cơ chế khôi phục màn hình đang làm dở (`RouteRestorationService`)
   - 3.3. Thanh tiêu đề trên (VthmTopAppBar): Logo, Avatar & Cụm 3 huy hiệu
   - 3.4. Bảng điều khiển Trang chủ (Dashboard) & 3 Thao tác nhanh (Quick Actions)
   - 3.5. Menu Báo cáo nhanh (ReportMenuBottomSheet)
   - 3.6. Thanh điều hướng dưới đáy (5 Tab chức năng chính)
4. [Module 1: Chấm Công Thực Địa (Attendance)](#4-module-1-chấm-công-thực-địa-attendance)
   - 4.1. Khung giờ ca làm việc tiêu chuẩn
   - 4.2. Quy trình Chấm công Vào ca (Check-in) bằng 2 ảnh xác thực (Chân dung & Quang cảnh)
   - 4.3. Quy trình Chấm công Ra ca (Check-out) cuối ngày & Tính thời lượng làm việc
   - 4.4. Kiểm tra bán kính Geofence & Xử lý cảnh báo ngoài vùng
   - 4.5. Thẻ Thống kê tháng & Lịch sử chấm công chi tiết
5. [Module 2: Định Vị Làm Việc & Minh Bạch Quyền Riêng Tư (Employee Tracking)](#5-module-2-định-vị-làm-việc--minh-bạch-quyền-riêng-tư-employee-tracking)
   - 5.1. Cơ chế chia sẻ vị trí làm việc an toàn (Foreground-only)
   - 5.2. Huy hiệu Định vị phát sóng (`LocationSharingBadge`) & Chu kỳ gửi ping
   - 5.3. Xử lý yêu cầu gửi toạ độ tức thời từ Giám sát (`Pending Location Request`)
   - 5.4. Màn hình "Nhật ký xem vị trí" (`/location-access-log`): Minh bạch quyền riêng tư
6. [Module 3: Tuyến Bán Hàng & Lộ Trình (Route & MCP)](#6-module-3-tuyến-bán-hàng--lộ-trình-route--mcp)
   - 6.1. Xem danh sách điểm bán theo tuyến được giao
   - 6.2. Bộ nhớ đệm phân vùng riêng biệt theo tài khoản (`dms_user_routes_v2`)
   - 6.3. Chế độ xem: Danh sách khoảng cách thực tế vs. Bản đồ Goong Map
   - 6.4. Nhận diện trạng thái viếng thăm các điểm bán
   - 6.5. Tìm kiếm không dấu & Sắp xếp điểm bán thông minh
7. [Module 4: Quy Trình Viếng Thăm Điểm Bán Chuẩn 6 Bước (Store Visit)](#7-module-4-quy-trình-viếng-thăm-điểm-bán-chuẩn-6-bước-store-visit)
   - 7.1. Sơ đồ quy trình chuẩn 6 bước tại điểm bán
   - 7.2. Bước 1: Check-in điểm bán & Năm luật kiểm tra nghiêm ngặt
   - 7.3. Bước 2: Chụp ảnh đóng dấu Watermark Canvas (4 dòng thông tin, tối đa 20 ảnh, chống trùng SHA-1)
   - 7.4. Bước 3: Điền biểu mẫu khảo sát trong lượt (`kind = survey`)
   - 7.5. Bước 4: Soi điều kiện hoàn thành (Check-out Requirements) đếm ngược
   - 7.6. Bước 5: Check-out đóng lượt: Điểm bán Mở cửa (`visited`) vs Điểm bán Đóng cửa (`closed`)
   - 7.7. Bước 6: Hoàn tất & Tính năng khẩn cấp: Huỷ lượt viếng thăm (Cancel Visit)
8. [Module 5: Quản Lý Khách Hàng / Điểm Bán (Customers)](#8-module-5-quản-lý-khách-hàng--điểm-bán-customers)
   - 8.1. Tra cứu & Xem chi tiết thông tin điểm bán, gọi điện thoại & chỉ đường
   - 8.2. Thêm mới điểm bán ngoại tuyến (Lấy toạ độ GPS, chụp nhiều ảnh lưu `offline_customer_photos`)
   - 8.3. Hiển thị tức thời khách hàng pending & Check-in ngay không cần mạng
   - 8.4. Chỉnh sửa và cập nhật thông tin khách hàng
9. [Module 6: Biểu Mẫu Khảo Sát Thị Trường (Market Forms)](#9-module-6-biểu-mẫu-khảo-sát-thị-trường-market-forms)
   - 9.1. Phân loại: Biểu mẫu trong lượt (`survey`) vs Biểu mẫu thu thập tự do (`collect`)
   - 9.2. Hướng dẫn chi tiết tất cả các loại câu hỏi nhập liệu
   - 9.3. Tiện ích Nhập liệu bằng giọng nói Tiếng Việt (Voice-to-Text / Micro thu âm)
   - 9.4. Cơ chế câu hỏi logic phân nhánh (Hiển thị có điều kiện)
   - 9.5. Lưu ngoại tuyến & Cơ chế nộp biểu mẫu an toàn
10. [Module 7: Khai Báo Vị Trí Thực Địa (Position Declaration)](#10-module-7-khai-báo-vị-trí-thực-địa-position-declaration)
    - 10.1. Mục đích và các trường hợp sử dụng nghiệp vụ ngoài tuyến
    - 10.2. Quy trình khai báo: Lý do chuẩn, Chụp ảnh Watermark Canvas & Ghi chú
    - 10.3. Nguyên lý bản ghi Append-only một mốc duy nhất
    - 10.4. Tra cứu lịch sử khai báo vị trí của bản thân
11. [Module 8: Theo Dõi Quãng Đường Di Chuyển (My Travel)](#11-module-8-theo-dõi-quãng-đường-di-chuyển-my-travel)
    - 11.1. Nguyên lý tính quãng đường tự động bằng Goong Maps Routing API theo đường bộ xe máy
    - 11.2. Mối liên hệ cốt lõi giữa Chấm công, Check-in/out và tính km
    - 11.3. Ba trạng thái con số km: Số km tức thì, Cảnh báo 0 km thiếu mốc & Đang xử lý
    - 11.4. Tra cứu chi tiết từng chặng di chuyển trong ngày (`/travel/legs`)
12. [Module 9: Báo Cáo Hoạt Động Trong Ngày (Daily Report)](#12-module-9-báo-cáo-hoạt-động-trong-ngày-daily-report)
    - 12.1. Thống kê bộ chỉ số KPI thực địa trong ngày
    - 12.2. Dòng thời gian Timeline hoạt động & 5 Tab lọc nghiệp vụ
    - 12.3. Bảng xem chi tiết từng hoạt động (Ảnh watermark, toạ độ, khoảng cách sai lệch, thời gian)
13. [Module 10: Trung Tâm Thông Báo & Nhắc Việc (Notifications)](#13-module-10-trung-tâm-thông-báo--nhắc-việc-notifications)
    - 13.1. Bảy kịch bản thông báo tự động hỗ trợ nhân viên
    - 13.2. Điều hướng thông minh & Đánh dấu đã đọc
    - 13.3. Công cụ kiểm thử thông báo hệ thống (Test khi tắt app 10s trong Profile)
14. [Module 11: Kiến Trúc Đồng Bộ Ngoại Tuyến (Offline-First Sync Engine)](#14-module-11-kiến-trúc-đồng-bộ-ngoại-tuyến-offline-first-sync-engine)
    - 14.1. Nguyên lý vận hành Offline-First: Ghi máy trước, Mạng sau
    - 14.2. Bảo toàn mốc thời gian bằng Đồng hồ đơn điệu (`queued_seconds`)
    - 14.3. Bốn trạng thái màu của Huy hiệu Đồng bộ (`OfflineSyncBadge`)
    - 14.4. Hộp thoại Chi tiết Hàng đợi (`_OfflineSyncDetailSheet`) & Nhận diện từng thực thể
    - 14.5. Cơ chế Đồng bộ thủ công & Dọn dẹp bản ghi lỗi vĩnh viễn (Dead Entries)
    - 14.6. Pipeline tải ảnh 2 bước (Photo Token) & Kháng lỗi mạng tự động
    - 14.7. Kiểm soát hiển thị Dialog mất mạng thông minh
15. [Module 12: Quản Lý Cá Nhân & Cài Đặt Hệ Thống (Profile & Settings)](#15-module-12-quản-lý-cá-nhân--cài-đặt-hệ-thống-profile--settings)
    - 15.1. Xem thông tin cá nhân, chức danh & phòng ban
    - 15.2. Chế độ Giao diện Tối (Dark Mode) & Chuyển đổi ngôn ngữ
    - 15.3. Quy trình Đăng xuất tài khoản an toàn
16. [Xử Lý Sự Cố Thường Gặp & Bộ Câu Hỏi FAQ Nghiệp Vụ](#16-xử-lý-sự-cố-thường-gặp--bộ-câu-hỏi-faq-nghiệp-vụ)

---

## 1. TỔNG QUAN & CHUẨN BỊ BAN ĐẦU

### 1.1. Giới thiệu hệ thống & Kiến trúc Offline-First
Ứng dụng **DMS VTHM Mobile** được thiết kế dựa trên tiêu chuẩn **Offline-First**. Điểm khác biệt cốt lõi so với các ứng dụng thông thường là:
- Mọi thao tác ghi nhận (Chấm công, Check-in, chụp ảnh, nộp biểu mẫu khảo sát, tạo khách hàng mới, khai báo vị trí) đều được **lưu trực tiếp và tức thì vào cơ sở dữ liệu SQLite cục bộ** trên thiết bị của nhân viên.
- Ứng dụng **không bao giờ bắt người dùng phải đợi mạng xoay vòng**. Sau khi bấm lưu, dữ liệu được xếp vào hàng đợi đồng bộ nền (`sync_queue`) và tự động chuyển về máy chủ công ty ngay khi có kết nối Internet trở lại.
- Tốc độ phản hồi của giao diện luôn đạt tức thì (< 50ms), loại bỏ hoàn toàn tình trạng đơ giật khi di chuyển giữa các vùng mạng chập chờn.

### 1.2. Phân quyền và đối tượng người dùng
- **Nhân viên bán hàng thực địa / Nhân viên kinh doanh (Sales Rep / DSR)**: Người dùng trực tiếp sử dụng ứng dụng để chấm công, đi theo lộ trình tuyến bán hàng, viếng thăm các đại lý/cửa hàng, chụp ảnh quầy kệ, kiểm kê hàng hóa, khảo sát giá đối thủ, mở điểm bán mới và chốt báo cáo ngày.
- **Giám sát bán hàng (Sales Supervisor - SS)**: Sử dụng ứng dụng để theo dõi tiến độ di chuyển của đội ngũ, kiểm tra tính xác thực của hình ảnh viếng thăm, kiểm tra cảnh báo sai lệch vị trí và nắm bắt số liệu thị trường tức thời.

### 1.3. Cấp quyền ứng dụng bắt buộc trên thiết bị di động
Khi cài đặt và mở ứng dụng lần đầu, bạn **BẮT BUỘC** phải cấp đầy đủ 4 quyền hệ thống sau:

| Quyền hạn | Mục đích sử dụng | Lưu ý quan trọng |
| :--- | :--- | :--- |
| 📍 **Vị trí (Location - GPS)** | Xác thực khoảng cách Geofence khi Check-in, chấm công và tính quãng đường di chuyển. | Bắt buộc chọn **"Trong khi dùng ứng dụng"** và bật tính năng **"Vị trí chính xác" (Precise Location)**. Tuyệt đối không bật chế độ tiết kiệm pin làm giảm độ chính xác của GPS. |
| 📷 **Máy ảnh (Camera)** | Chụp ảnh mặt tiền, quầy kệ trưng bày, ảnh selfie chấm công và ảnh khai báo vị trí. | Ứng dụng **chỉ cho phép chụp trực tiếp từ camera, không hỗ trợ chọn ảnh từ thư viện** nhằm đảm bảo 100% tính xác thực của bằng chứng thực địa. |
| 💾 **Bộ nhớ (Storage)** | Lưu trữ bộ nhớ đệm hình ảnh ngoại tuyến (`offline_customer_photos`) và cơ sở dữ liệu SQLite cục bộ. | Đảm bảo điện thoại còn trống ít nhất **500 MB** dung lượng khả dụng trước khi xuất phát đi thị trường. |
| 🔔 **Thông báo (Notifications)** | Nhận thông báo nhắc chấm công vào/ra ca, tiến độ tuyến và gợi ý điểm bán lân cận. | Cho phép thông báo biểu ngữ và âm thanh để không bỏ lỡ các mốc quan trọng trong ca làm việc. |

### 1.4. Quy định an toàn thiết bị & Cơ chế chống gian lận (Anti-Fraud)
Hệ thống tích hợp công cụ kiểm soát tuân thủ [AntiFraudService](file:///c:/DMS_VTHM/dms-app/lib/core/services/anti_fraud_service.dart) kiểm tra tự động:
- 🚫 **Nghiêm cấm ứng dụng Giả lập vị trí (Fake GPS / Mock Location)**: Nếu thiết bị kích hoạt tính năng vị trí giả lập trong Cài đặt nhà phát triển, ứng dụng sẽ phát hiện ngay lập tức và từ chối cho phép Check-in hoặc chấm công, đồng thời gắn cờ đỏ cảnh báo vi phạm gửi về máy chủ.
- ⏰ **Nghiêm cấm chỉnh sửa đồng hồ thiết bị (Clock Skew)**: Đồng hồ điện thoại phải luôn đặt ở chế độ *"Cập nhật ngày giờ tự động từ mạng"*. Nếu đồng hồ bị chỉnh lùi hoặc chênh lệch quá ngưỡng cho phép (mặc định 15 phút), lượt ghi nhận sẽ bị chặn hoặc gắn cờ kiểm toán rủi ro.
- 🎯 **Kiểm soát vùng địa lý (Geofence Distance)**: Mọi thao tác Check-in tại điểm bán và Chấm công tại văn phòng đều được đo khoảng cách Haversine so với toạ độ thực tế đã đăng ký.

---

## 2. KỊCH BẢN THỰC TẾ: MỘT NGÀY LÀM VIỆC TIÊU CHUẨN CỦA NHÂN VIÊN SALE

Để giúp nhân viên kinh doanh hình dung rõ ràng toàn bộ dòng chảy tác nghiệp trong thực tế, dưới đây là mô tả chi tiết một ngày làm việc chuẩn mực của một **Sales Rep (DSR) VTHM Group** từ sáng sớm đến khi kết thúc ngày làm việc.

### 2.1. Sơ đồ dòng chảy hành trình 1 ngày làm việc

```
07:45 ── Nhận thông báo nhắc Vào ca
  │
08:00 ── [BƯỚC 1: CHẤM CÔNG VÀO CA] (Selfie + Ảnh không gian có Watermark)
  │      └── Kích hoạt huy hiệu phát sóng định vị (Location Sharing Badge)
  │
08:15 ── [BƯỚC 2: ĐỊNH HÌNH TUYẾN MCP] (Xem danh sách cự ly gần->xa & Bản đồ Goong Map)
  │
08:30 ── [BƯỚC 3: DI CHUYỂN & VIẾNG THĂM ĐIỂM BÁN 1]
  │      ├── Check-in (Xác thực Geofence < 100m)
  │      ├── Chụp ảnh biển hiệu, quầy kệ (Watermark Canvas tự động)
  │      ├── Điền biểu mẫu khảo sát giá & tồn kho
  │      └── Check-out Mở cửa (Thoả mãn 3 điều kiện hoàn thành)
  │
09:30 ── [BƯỚC 4: XỬ LÝ ĐIỂM BÁN ĐÓNG CỬA (ĐIỂM BÁN 2)]
  │      ├── Check-in tại điểm bán
  │      └── Check-out Đóng cửa (Chụp 1 ảnh bằng chứng đóng cửa + Ghi chú lý do)
  │
10:15 ── [BƯỚC 5: NHẬN GỢI Ý THÔNG MINH ĐIỂM BÁN LÂN CẬN (85m)]
  │      └── Ghé thăm ngay điểm lân cận để tối ưu quãng đường
  │
11:30 ── [BƯỚC 6: NGHỈ TRƯA & RÀ SOÁT TIẾN ĐỘ]
  │      ├── Nhận thông báo tiến độ nửa ngày (VD: 6/14 điểm - 43%)
  │      └── Xem Timeline buổi sáng trên Daily Report; Ứng dụng ngủ đông tiết kiệm pin
  │
13:15 ── [BƯỚC 7: TÁC NGHIỆP NGOẠI TUYẾN 100% (KHU VỰC MẤT MẠNG)]
  │      ├── Viếng thăm điểm bán 4 & 5 hoàn toàn khi mất sóng 4G
  │      └── Huy hiệu báo màu Vàng: "Ngoại tuyến (2 chờ)", dữ liệu an toàn trong SQLite
  │
14:30 ── [BƯỚC 8: MỞ ĐIỂM BÁN MỚI NGOẠI TUYẾN]
  │      ├── Thêm mới khách hàng: Tự lấy GPS, chụp ảnh mặt tiền lưu offline
  │      └── Mở lượt Check-in thăm điểm mới ngay lập tức
  │
15:30 ── [BƯỚC 9: KHAI BÁO VỊ TRÍ SỰ CỐ / NGOÀI TUYẾN]
  │      └── Khai báo vị trí công tác ngoại tuyến có ảnh Watermark & Ghi chú
  │
16:00 ── [BƯỚC 10: CÓ MẠNG TRỞ LẠI - ĐỒNG BỘ NỀN TỰ ĐỘNG]
  │      └── Tải ảnh 2 bước (Photo Token) -> Huy hiệu chuyển màu Xanh lá
  │
16:45 ── [BƯỚC 11: HOÀN TẤT ĐIỂM BÁN CUỐI CÙNG & KIỂM TRA BÁO CÁO NGÀY]
  │      ├── Check-out điểm bán cuối
  │      └── Mở Báo cáo hoạt động (KPI: 14/14 điểm, 0 rủi ro)
  │
17:02 ── [BƯỚC 12: CHẤM CÔNG RA CA & CHỐT QUÃNG ĐƯỜNG TRONG NGÀY]
         ├── Nhấn Chấm Ra ca để chốt công và thời lượng làm việc
         ├── Quãng đường toàn bộ các chặng đã được tính tức thì sau mỗi lượt Check-out
         └── Tự động ngắt phát sóng định vị bảo vệ quyền riêng tư
```

---

### 2.2. Giai đoạn 1 (07:30 - 08:30): Đầu ngày – Nhắc ca, Chấm công Vào ca & Định hình lộ trình

#### 07:45 - Nhận thông báo nhắc ca làm việc
- Điện thoại của nhân viên nhận được thông báo cục bộ từ hệ thống:
  > *"Sắp đến giờ vào ca (08:00). Đừng quên chấm công để ghi nhận ngày công hôm nay!"*
- Nhân viên chạm vào thông báo, ứng dụng tự động mở thẳng màn hình [AttendanceDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/screens/attendance_detail_screen.dart).

#### 08:00 - Thao tác Chấm công Vào ca (Check-in)
1. Nhân viên có mặt tại địa điểm làm việc quy định (Văn phòng chi nhánh hoặc khu vực phụ trách).
2. Kiểm tra thẻ vị trí GPS trên màn hình:
   - Sai số GPS báo xanh lá (< 15m).
   - Tên địa điểm làm việc và khoảng cách hiển thị hợp lệ (trong bán kính 200m).
3. Nhấn nút lớn **CHẤM VÀO CA**:
   - Camera mở lên yêu cầu chụp **Tấm 1 (Camera trước)**: Nhân viên chụp ảnh chân dung rõ mặt.
   - Camera tự động chuyển sang **Tấm 2 (Camera sau)**: Nhân viên chụp ảnh không gian làm việc xung quanh.
   - Hệ thống tự động đóng dấu Watermark công ty lên cả 2 bức ảnh.
4. Nhấn **Xác nhận gửi**:
   - Màn hình thông báo: *"Đã ghi nhận Chấm công Vào ca lúc 08:02"*.
   - Mốc toạ độ này chính thức trở thành **Điểm xuất phát (Start Point)** cho thuật toán tính toán quãng đường công tác xe máy trong ngày.
   - Trên thanh tiêu đề, huy hiệu **LocationSharingBadge** bắt đầu phát sóng chấm xanh lá nhấp nháy, báo hiệu trạng thái định vị làm việc trong ca đã được kích hoạt.

#### 08:15 - Mở Tuyến bán hàng & Định hình lộ trình (MCP)
1. Tại thanh điều hướng dưới đáy, nhân viên chạm vào tab **Tuyến bán hàng** (`/routes`).
2. Tuyến bán hàng hôm nay (ví dụ: *Tuyến Thứ 2 - Quận 1*) tự động hiển thị với 14 điểm bán.
3. Nhân viên kiểm tra:
   - **Chế độ Danh sách (List View)**: Điểm bán nào ở gần vị trí hiện tại nhất (ví dụ: *Tạp hoá Minh Châu - cách 120m*) sẽ được đưa lên đầu tiên.
   - **Chế độ Bản đồ (Map View)**: Chuyển sang Goong Map để xem các ghim màu đỏ thể hiện các điểm chưa ghé, giúp hình dung một vòng cung di chuyển tối ưu, tránh đi lòng vòng quay đầu xe.

---

### 2.3. Giai đoạn 2 (08:30 - 11:30): Buổi sáng thực địa – Viếng thăm tuyến & Xử lý tình huống đóng cửa

#### 08:35 - Viếng thăm Điểm bán 1 (Quy trình chuẩn mở cửa)
1. Nhân viên dừng xe trước cửa hàng **Tạp hoá Minh Châu**, chọn điểm bán trên app và nhấn **Bắt đầu viếng thăm / Check-in**:
   - Hệ thống quét GPS: Khoảng cách thực tế 25m (nằm an toàn trong Geofence 100m).
   - Phiên viếng thăm mở thành công, đồng hồ đếm thời gian bắt đầu chạy.
2. **Chụp ảnh thực tế**:
   - Chụp 1 ảnh biển hiệu mặt tiền cửa hàng.
   - Chụp 1 ảnh quầy kệ trưng bày sản phẩm VTHM Group.
   - Ảnh chụp được Canvas đóng dấu tự động: Tên cửa hàng, địa chỉ, toạ độ toạ vị và thời gian thực.
3. **Thực hiện nghiệp vụ tại quầy**:
   - Trao đổi với chủ quán, kiểm tra tồn kho, tư vấn đơn hàng mới.
   - Mở mục biểu mẫu khảo sát trong lượt (`kind = survey`): Điền phiếu *Khảo sát giá & trưng bày*, nhấn nút **Nộp biểu mẫu**.
4. **Kiểm tra điều kiện Check-out**:
   - Thẻ điều kiện hoàn thành hiển thị:
     - Thời gian tối thiểu: Đã đủ (trên 10 phút) ✓
     - Số lượng ảnh: Đã chụp 2/1 ảnh yêu cầu ✓
     - Biểu mẫu bắt buộc: Đã nộp 1/1 biểu mẫu ✓
5. **Check-out**:
   - Nhân viên nhấn **KẾT THÚC VIẾNG THĂM** -> Chọn **Mở cửa (`visited`)**.
   - Hộp thoại chúc mừng hoàn tất xuất hiện. Thẻ điểm bán trên danh sách tuyến chuyển sang màu xanh lá cây hoàn thành.

#### 09:40 - Viếng thăm Điểm bán 2 (Tình huống đại lý đóng cửa)
1. Nhân viên đến điểm bán tiếp theo: **Đại lý Hưng Phát**. Cửa cuốn đóng kín, chủ nhà đi vắng.
2. Nhân viên mở thẻ điểm bán, nhấn **Bắt đầu viếng thăm / Check-in** (khoảng cách 15m hợp lệ).
3. Do cửa hàng đóng cửa, không thể vào kiểm tra tồn kho hay khảo sát giá.
4. Nhân viên nhấn ngay nút **KẾT THÚC VIẾNG THĂM**:
   - Chọn mục **ĐÓNG CỬA (`closed`)**.
   - Hệ thống áp dụng chính sách ưu đãi: **Miễn thời gian tối thiểu ở lại và miễn toàn bộ biểu mẫu khảo sát**.
   - Điều kiện duy nhất: Chụp **1 ảnh mặt tiền cửa cuốn đang đóng cửa** làm bằng chứng thực địa và nhập ghi chú lý do: *"Chủ nhà đi ăn cưới đóng cửa cả ngày"*.
5. Nhấn **Xác nhận kết thúc**: Lượt viếng thăm được chốt thành công với kết quả đóng cửa hợp lệ, không bị tính vi phạm.

#### 10:20 - Nhận gợi ý thông minh điểm bán lân cận
- Trong lúc đang di chuyển, hệ thống [AppNotificationService](file:///c:/DMS_VTHM/dms-app/lib/core/services/app_notification_service.dart) phát hiện nhân viên đang chạy ngang qua một điểm bán trên tuyến:
  > *"Bạn đang ở gần 'Tạp hoá Hương Sen' (cách 85m) trên tuyến hôm nay. Ghé thăm ngay để tối ưu lộ trình!"*
- Nhân viên lập tức rẽ vào viếng thăm điểm này trước, giúp tiết kiệm được 2 km phải quay lại sau đó.

---

### 2.4. Giai đoạn 3 (11:30 - 13:00): Nghỉ trưa – Rà soát KPI nửa ngày & Tự động tiết kiệm pin

#### 11:30 - Nhận thông báo tiến độ tuyến buổi sáng
- Hệ thống gửi thông báo tóm tắt:
  > *"Tiến độ tuyến 11:30: Bạn đã hoàn thành 6/14 điểm bán (43%). Hãy nghỉ trưa và tiếp tục tăng tốc vào buổi chiều!"*

#### 11:45 - Rà soát KPI và dòng thời gian
- Nhân viên mở [HomeScreen](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/screens/home_screen.dart) hoặc bấm vào box **Báo cáo** (màu tím pastel lavender) -> Chọn **Báo cáo viếng thăm & Hoạt động trong ngày**:
  - Xem số liệu KPI: Đã ghé 6, Đúng vị trí 6, Cảnh báo rủi ro 0.
  - Lướt xem Timeline: Các mốc từ 08:02 (Vào ca), 08:35 (Check-in Minh Châu), 09:40 (Check-in Hưng Phát)... được sắp xếp rõ ràng từng phút.

#### 12:00 - Cơ chế ngủ đông tiết kiệm pin thông minh
- Khi nhân viên thoát ứng dụng hoặc tắt màn hình điện thoại đi ăn trưa:
  - Dịch vụ theo dõi vị trí `EmployeeTrackingNotifier` tự động **dừng ngay lập tức bộ đếm gửi toạ độ định kỳ**, gửi đúng 1 điểm cuối mang cờ `source=app_exit`.
  - Ứng dụng **tuyệt đối không chạy ngầm GPS**, giúp bảo vệ pin tối đa cho điện thoại của nhân viên trong suốt 1 tiếng nghỉ ngơi.

---

### 2.5. Giai đoạn 4 (13:00 - 16:30): Buổi chiều thực địa – Tác nghiệp ngoại tuyến, Mở điểm bán mới & Khai báo ngoài tuyến

#### 13:15 - Tác nghiệp khi mất mạng hoàn toàn (Offline-First)
- Nhân viên đi vào khu chợ sâu hoặc tầng hầm một trung tâm thương mại, điện thoại **mất hoàn toàn sóng 4G/3G**:
  - Biểu tượng mạng hiển thị mất kết nối.
  - Nhân viên vẫn mở danh sách tuyến bình thường nhờ cache SQLite.
  - Bấm Check-in tại **Đại lý Vạn Thuận**: Hệ thống lưu ngay lượt Check-in vào SQLite trong 10ms.
  - Chụp 2 ảnh trưng bày, điền biểu mẫu khảo sát và bấm Check-out hoàn tất: Mọi dữ liệu đều được lưu mượt mà.
  - Trên thanh tiêu đề, huy hiệu **OfflineSyncBadge** đổi sang **Màu Vàng hổ phách**: *"Ngoại tuyến (2 chờ)"*.
  - Nhân viên an tâm tiếp tục di chuyển mà không bị bất kỳ thông báo lỗi gián đoạn nào.

#### 14:15 - Phát triển và thêm mới Điểm bán ngoại tuyến
- Nhân viên phát hiện một cửa hàng tạp hoá lớn mới mở chưa có trong danh sách phân phối: **Tạp hoá Anh Thư**.
- Tại tab **Điểm bán** (`/customers`), nhân viên nhấn nút tròn **(+) Thêm điểm bán**:
  1. Nhập tên cửa hàng: *Tạp hoá Anh Thư*.
  2. Tuyến bán hàng: Chọn tuyến *Thứ 2 - Quận 1* (danh mục tuyến đã được lưu sẵn trong máy).
  3. Nhập số điện thoại chủ quầy.
  4. Nhấn nút **"Lấy vị trí hiện tại"**: Toạ độ GPS nơi đang đứng được tự động điền chính xác.
  5. Bấm nút máy ảnh: Chụp 2 bức ảnh mặt tiền biển hiệu và gian hàng. Ảnh được lưu vĩnh viễn vào thư mục an toàn của app (`offline_customer_photos`).
  6. Nhấn **LƯU ĐIỂM BÁN**:
     - Điểm bán mới xuất hiện **NGAY TỨC THÌ** trên màn hình danh sách với nhãn *"Chờ đồng bộ"*.
     - Nhân viên bấm vào thẻ điểm bán mới này và thực hiện ngay quy trình Check-in viếng thăm đầu tiên mà không cần chờ mạng!

#### 15:20 - Khai báo vị trí thực địa công tác ngoài tuyến
- Giám sát bán hàng gọi điện yêu cầu nhân viên chạy sang kho trung chuyển cách đó 3 km để ký nhận gấp một biên bản giao nhận hàng hóa.
- Kho trung chuyển không phải là điểm bán đại lý thuộc tuyến, nhân viên thực hiện **Khai báo vị trí**:
  1. Mở Trang chủ, nhấn vào box **Khai báo vị trí** (màu xanh ngọc bích `#CCFBF1`).
  2. Chọn Lý do: `002 - Phối hợp giải quyết công việc ngoài tuyến`.
  3. Bấm chụp ảnh tại kho trung chuyển (Canvas tự động đóng dấu Watermark toạ độ kho).
  4. Nhập ghi chú: *"Có mặt ký biên bản bàn giao lô hàng súp theo yêu cầu SS"*.
  5. Nhấn **GỬI KHAI BÁO**: Mốc công tác được ghi nhận vào lịch sử, giúp bảo vệ quyền lợi tính quãng đường và giải trình công tác.

#### 16:00 - Có mạng trở lại & Hệ thống tự động đồng bộ nền
- Khi nhân viên di chuyển ra đường lớn có sóng 4G căng:
  - Dịch vụ [SyncService](file:///c:/DMS_VTHM/dms-app/lib/core/sync/sync_service.dart) tự động kích hoạt tiến trình gửi bù theo đúng thứ tự FIFO.
  - **Pipeline 2 bước**: Tải ảnh điểm bán mới lên lấy mã xác thực `photo_token`, sau đó gửi gói dữ liệu điểm bán, lượt check-in và biểu mẫu.
  - Huy hiệu đồng bộ tự động chuyển từ **Vàng** sang **Xanh lá cây**: *"Đã đồng bộ"*.
  - Thông báo xuất hiện: *"Đã đồng bộ thành công toàn bộ dữ liệu ngoại tuyến lên hệ thống!"*.

---

### 2.6. Giai đoạn 5 (16:30 - 17:15): Cuối ngày – Rà soát Timeline, Kiểm tra km & Chấm công Ra ca

#### 16:45 - Hoàn tất điểm bán cuối cùng & Kiểm tra báo cáo
- Nhân viên hoàn tất Check-out tại điểm bán số 14 trên tuyến.
- Mở màn hình [DailyReportScreen](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/screens/daily_report_screen.dart):
  - KPI tổng kết: **14 / 14 Điểm bán (100% kế hoạch)**.
  - Đúng vị trí: 14 / 14 lượt.
  - Cảnh báo rủi ro: 0 lượt.
  - Toàn bộ dòng thời gian trong ngày từ 08:02 đến 16:45 hiển thị đầy đủ, minh bạch.

#### 17:00 - Nhận thông báo tan ca & Chấm công Ra ca
- Hệ thống gửi thông báo nhắc việc:
  > *"Đã đến giờ tan ca (17:00). Đừng quên bấm Ra ca để chốt công và giờ làm việc nhé!"*
1. Nhân viên mở lại mục **Chấm công**.
2. Nút hành động chính tự động chuyển sang màu đỏ gạch với nhãn **CHẤM RA CA**.
3. Nhấn **CHẤM RA CA**:
   - Hệ thống quét toạ độ GPS lúc ra ca (mốc kết thúc ngày làm việc).
   - Màn hình thông báo chúc mừng: *"Ghi nhận Ra ca lúc 17:05. Tổng thời gian làm việc hôm nay: 9 giờ 03 phút"*.
4. **Tự động ngắt định vị**:
   - Ngay khi Chấm Ra ca thành công, huy hiệu `LocationSharingBadge` chuyển sang màu xám và tắt hoàn toàn.
   - Nhân viên hoàn toàn tự do thời gian cá nhân trên đường về nhà, hệ thống không theo dõi toạ độ ngoài giờ.

---

### 2.7. Cơ chế tính quãng đường tức thì: Cập nhật thời gian thực ngay khi hoàn thành viếng thăm
- **Không còn khái niệm chờ đồng bộ đêm hay đợi 01:30 sáng hôm sau**:
  - Hệ thống máy chủ và ứng dụng DMS VTHM áp dụng **cơ chế tính toán quãng đường thời gian thực (Real-time Routing Engine)**.
  - Ngay khi nhân viên bấm **KẾT THÚC VIẾNG THĂM (Check-out)** tại bất kỳ điểm bán nào:
    - Thuật toán Goong Maps Routing API theo đường bộ xe máy được kích hoạt **ngay lập tức** để tính chặng đường vừa đi (từ điểm trước đến điểm vừa hoàn thành).
    - Con số km hiển thị tức thời trên app và cộng dồn ngay vào tổng quãng đường ngày hôm nay.
- **Tiện ích thực tế cho nhân viên**:
  - Không cần phải đợi qua đêm hay sang ngày hôm sau mới biết mình đi được bao nhiêu km.
  - Vừa bước ra khỏi cửa hàng và check-out xong, mở mục **Quãng đường của tôi** (`/travel`) là nhân viên đã thấy ngay số km chặng vừa đi và tổng km tích luỹ trong ngày được cập nhật chính xác!
  - Con số được chốt ngay trong ngày làm căn cứ minh bạch để tính phụ cấp xăng xe công tác.

---

## 3. ĐĂNG NHẬP, THIẾT LẬP PHIÊN & ĐIỀU HƯỚNG CHUNG

### 3.1. Đăng nhập hệ thống & Duy trì phiên an toàn 90 ngày
- Mở ứng dụng DMS VTHM:
  - **Tên đăng nhập**: Nhập mã nhân viên hoặc tài khoản nội bộ (Ví dụ: `VTG920`, `TEST001`).
  - **Mật khẩu**: Nhập mật khẩu được cấp.
- Nhấn nút **ĐĂNG NHẬP**.
- **Cơ chế duy trì phiên thông minh**:
  - Hệ thống sử dụng cặp mã khoá `access_token` (hạn 1 giờ) và `refresh_token` (kéo dài **90 ngày / 7.776.000 giây**).
  - Nhân viên **chỉ cần đăng nhập 1 lần duy nhất**, ứng dụng sẽ tự động làm mới phiên ngầm khi có mạng. Sau mỗi đêm thức dậy mở app ra là vào làm việc được ngay.

> [!WARNING]
> Tài khoản bắt buộc phải được phòng Nhân sự cấp **Mã nhân viên** và gán vai trò nhân sự hợp lệ. Nếu tài khoản chưa có mã nhân viên, nút Chấm công sẽ bị mờ kèm thông báo nhắc liên hệ bộ phận nhân sự để liên kết hồ sơ.

### 3.2. Cơ chế khôi phục màn hình đang làm dở (`RouteRestorationService`)
Trong lúc đang đi thị trường, nếu bạn nhận cuộc gọi điện thoại, mở camera chụp ảnh ngoài hoặc điện thoại bị tắt ứng dụng do giải phóng RAM:
- Dịch vụ [RouteRestorationService](file:///c:/DMS_VTHM/dms-app/lib/core/services/route_restoration_service.dart) tự động ghi nhớ màn hình bạn đang thao tác.
- Khi chạm mở lại app, hệ thống **tự động đưa bạn quay trở lại đúng màn hình đang làm dở** (ví dụ: màn hình khảo sát biểu mẫu hoặc màn hình viếng thăm đang Check-in), giúp bạn không bị mất dấu công việc.

### 3.3. Thanh tiêu đề trên (VthmTopAppBar): Logo, Avatar & Cụm 3 huy hiệu
Thanh tiêu đề trên cùng xuất hiện đồng nhất tại các màn hình chính:
1. **Góc trái**: Ảnh đại diện Avatar (chạm vào để mở trang Cá nhân) & Logo VTHM Group.
2. **Ở giữa**: Tiêu đề trang màn hình hiện tại.
3. **Cụm 3 huy hiệu góc phải**:
   - 📡 **Huy hiệu Định vị làm việc ([LocationSharingBadge](file:///c:/DMS_VTHM/dms-app/lib/features/employee_tracking/presentation/widgets/location_sharing_badge.dart))**: Chấm tròn xanh phát sóng nhịp thở khi đang trong ca làm việc; xám khi đã ra ca.
   - ☁️ **Huy hiệu Đồng bộ Ngoại tuyến ([OfflineSyncBadge](file:///c:/DMS_VTHM/dms-app/lib/core/widgets/offline_sync_badge.dart))**: Đổi 4 màu trực quan (Xanh lá, Vàng, Xanh dương, Đỏ). Bấm vào để mở bảng quản lý hàng đợi.
   - 🔔 **Quả chuông Thông báo**: Hiển thị số lượng thông báo chưa đọc màu đỏ. Bấm vào mở màn hình Thông báo.

### 3.4. Bảng điều khiển Trang chủ (Dashboard) & 3 Thao tác nhanh
Tại [HomeScreen](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/screens/home_screen.dart):
- **Lời chào đầu ngày (GreetingHeader)**: Hiển thị tên nhân viên, ngày tháng và câu chào tràn đầy năng lượng.
- **Thẻ Tóm tắt Chấm công (AttendanceSummaryCard)**: Tóm tắt giờ vào ca hôm nay, trạng thái làm việc và thời lượng tích luỹ.
- **Khu vực Quick Actions (HomeQuickActions)** gồm 3 hộp màu pastel thanh lịch:
  - 📷 **Hộp Chấm công (Pastel Hổ phách `#FEF3C7`)**: Mở giao diện chấm công vào/ra ca.
  - 📍 **Hộp Khai báo vị trí (Pastel Ngọc bích `#CCFBF1`)**: Mở giao diện chụp ảnh khai báo công tác ngoài tuyến.
  - 📊 **Hộp Báo cáo (Pastel Lavender `#EEF2FF`)**: Mở menu lướt nhanh báo cáo tổng hợp.
- **Dòng thời gian thu nhỏ (Daily Activity Timeline)**: Xem ngay các sự kiện gần nhất trong ngày mà không cần chuyển màn.

### 3.5. Menu Báo cáo nhanh (ReportMenuBottomSheet)
Khi chạm vào hộp Báo cáo tại Trang chủ, bảng chọn trượt lên cung cấp 4 lối tắt tiện lợi:
1. *Báo cáo viếng thăm & Hoạt động trong ngày* -> Dẫn tới `/daily-report`.
2. *Lịch sử chấm công* -> Xem lại các lần vào/ra ca trong tuần.
3. *Lịch sử khai báo vị trí* -> Xem lại danh sách các điểm công tác đã khai báo.
4. *Nghi vấn rủi ro & Cảnh báo vị trí* -> Lọc nhanh các bản ghi bị lệch toạ độ để kịp thời giải trình.

### 3.6. Thanh điều hướng dưới đáy (5 Tab chức năng chính)
Thanh điều hướng cố định dưới chân màn hình giúp chuyển đổi nhanh chóng:
- 🏠 **Trang chủ (`/home`)**: Bảng điều khiển trung tâm và phím tắt thao tác.
- 👥 **Điểm bán (`/customers`)**: Sổ tay khách hàng, tra cứu thông tin và tạo điểm bán mới.
- 🗺️ **Tuyến bán hàng (`/routes`)**: Lộ trình viếng thăm trong ngày theo tuyến (MCP) và bản đồ dẫn đường.
- 📋 **Biểu mẫu (`/forms`)**: Danh sách các mẫu phiếu khảo sát thị trường tự do.
- 👤 **Cá nhân (`/profile`)**: Hồ sơ nhân viên, quãng đường di chuyển và cài đặt hệ thống.

---

## 4. MODULE 1: CHẤM CÔNG THỰC ĐỊA (ATTENDANCE)

Màn hình chi tiết: [AttendanceDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/screens/attendance_detail_screen.dart).

```
[Bắt đầu ca sáng 08:00] ──> Quét toạ độ GPS ──> Chụp ảnh Selfie ──> Chụp ảnh Quang cảnh ──> [VÀO CA THÀNH CÔNG]
                                                                                                    │
                                                                                           Làm việc trong ngày
                                                                                                    │
[Kết thúc ca chiều 17:00] ──> Quét toạ độ GPS ──> Xác nhận Ra ca ──────────────────────────> [RA CA THÀNH CÔNG]
```

### 4.1. Khung giờ ca làm việc tiêu chuẩn
- **Giờ vào ca sáng**: **08:00 AM** (Hệ thống nhắc nhở tự động từ 07:45 - 08:00; sau 08:05 cảnh báo trễ giờ).
- **Giờ tan ca chiều**: **17:00 PM** (Hệ thống nhắc nhở tự động từ 17:00; sau 17:15 cảnh báo chưa chốt công).

### 4.2. Quy trình Chấm công Vào ca (Check-in) bằng 2 ảnh xác thực
1. Mở màn hình Chấm công.
2. Kiểm tra thông tin:
   - Đồng hồ điện tử chạy thời gian thực.
   - Thẻ vị trí GPS: Sai số vệ tinh báo màu xanh lá (< 20m).
   - Tên địa điểm văn phòng/chi nhánh được áp dụng.
3. Bấm **CHẤM VÀO CA**:
   - Ứng dụng tự động kiểm tra chống Mock GPS.
   - Hộp thoại [AttendancePhotoCaptureDialog](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_photo_capture_dialog.dart) xuất hiện yêu cầu chụp **2 ảnh bắt buộc**:
     - **Tấm 1 (Camera trước)**: Ảnh chụp rõ mặt nhân viên tại nơi làm việc.
     - **Tấm 2 (Camera sau)**: Ảnh chụp quang cảnh/không gian xung quanh.
   - Cả 2 ảnh tự động được Canvas đóng dấu Watermark công ty.
4. Bấm **Xác nhận gửi**: Lượt chấm công được ghi nhận ngay lập tức, nút hành động chuyển sang trạng thái đã vào ca.

### 4.3. Quy trình Chấm công Ra ca (Check-out) cuối ngày & Tính thời lượng làm việc
1. Khi hoàn thành ngày làm việc (sau 17:00), mở lại mục Chấm công.
2. Nút hành động chính tự động đổi sang nhãn **CHẤM RA CA** kèm biểu tượng đăng xuất.
3. Bấm **CHẤM RA CA**:
   - Hệ thống quét toạ độ GPS hiện tại làm mốc kết thúc tính quãng đường xe máy.
   - Ghi nhận giờ ra ca chính thức và tính toán tổng số giờ làm việc trong ngày (**Working Duration**).

### 4.4. Kiểm tra bán kính Geofence & Xử lý cảnh báo ngoài vùng
- Nếu chính sách công ty quy định chấm công tại địa điểm cố định (Bán kính 200m) mà bạn đang đứng ngoài vùng:
  - Hộp thoại [AttendanceOutOfRangeDialog](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_out_of_range_dialog.dart) cảnh báo: *Bạn đang cách điểm làm việc [Tên địa điểm] X mét (Quy định: tối đa Y mét)*.
  - Bạn cần di chuyển lại gần khu vực làm việc để chấm công hợp lệ.

### 4.5. Thẻ Thống kê tháng & Lịch sử chấm công chi tiết
- **Thẻ Thống kê tháng ([MonthlyStatsCard](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/monthly_stats_card.dart))**: Xem tổng số ngày công đã hoàn thành trong tháng hiện tại và số ngày có cảnh báo trễ giờ.
- **Thẻ Lịch sử chấm công ([AttendanceHistoryCard](file:///c:/DMS_VTHM/dms-app/lib/features/attendance/presentation/widgets/attendance_history_card.dart))**: Liệt kê chi tiết toàn bộ các lượt chấm công trong 7 ngày gần nhất kèm ảnh chân dung, thời gian và nhãn Vào/Ra rõ ràng.

---

## 5. MODULE 2: ĐỊNH VỊ LÀM VIỆC & MINH BẠCH QUYỀN RIÊNG TƯ (EMPLOYEE TRACKING)

Dịch vụ quản trị: [EmployeeTrackingNotifier](file:///c:/DMS_VTHM/dms-app/lib/features/employee_tracking/presentation/services/employee_tracking_service.dart) & Huy hiệu [LocationSharingBadge](file:///c:/DMS_VTHM/dms-app/lib/features/employee_tracking/presentation/widgets/location_sharing_badge.dart).

### 5.1. Cơ chế chia sẻ vị trí làm việc an toàn (Foreground-only)
Hệ thống tuân thủ nghiêm ngặt chuẩn mực bảo vệ quyền riêng tư cá nhân của nhân viên:
- **Chỉ theo dõi trong giờ làm việc**: Dịch vụ định vị chỉ được kích hoạt sau khi nhân viên đã bấm Chấm công Vào ca và **tự động tắt hoàn toàn ngay khi bấm Chấm công Ra ca**.
- **Chỉ gửi khi ứng dụng đang mở (Foreground-only)**: Khi nhân viên tắt app hoặc chuyển ứng dụng xuống nền, bộ hẹn giờ sẽ dừng lại và gửi đúng 1 điểm cuối `source=app_exit`. Ứng dụng **không chạy ngầm định vị liên tục** làm hao tốn pin điện thoại.
- **Lưu trữ ngoại tuyến khi mất sóng**: Khi xe chạy vào vùng mất mạng, các điểm toạ độ phát sinh được lưu tạm vào hàng đợi SQLite trên máy và tự động đẩy bù khi có sóng.

### 5.2. Huy hiệu Định vị phát sóng (`LocationSharingBadge`) & Chu kỳ gửi ping
- Nằm trên thanh tiêu đề trên cùng (bên cạnh huy hiệu đồng bộ):
  - 🟢 **Xanh lá cây nhấp nháy**: Đang trong ca làm việc, đang phát sóng định vị theo chu kỳ quy định (mặc định 60s - 120s tuỳ server cấu hình).
  - ⚪ **Màu xám mờ**: Đang ngoài ca làm việc hoặc tính năng định vị đang tắt.
  - 🔄 **Vòng tròn xoay nhỏ**: Đang trong tích tắc gửi điểm ping toạ độ lên máy chủ.
- Chạm vào huy hiệu để mở bảng thông tin: Xem chu kỳ gửi hiện tại, thời điểm ping gần nhất và số điểm đang chờ gửi.

### 5.3. Xử lý yêu cầu gửi toạ độ tức thời từ Giám sát (`Pending Location Request`)
- Khi Giám sát bán hàng cần xác định vị trí tức thời của nhân viên trên bản đồ giám sát điều phối, hệ thống gửi lệnh `pending request` xuống thiết bị.
- Ngay khi ứng dụng mở ở foreground, dịch vụ sẽ tự động phản hồi toạ độ GPS chính xác kèm mã yêu cầu mà không làm gián đoạn màn hình làm việc của nhân viên.

### 5.4. Màn hình "Nhật ký xem vị trí" (`/location-access-log`): Minh bạch quyền riêng tư
Màn hình chi tiết: [LocationAccessLogScreen](file:///c:/DMS_VTHM/dms-app/lib/features/employee_tracking/presentation/screens/location_access_log_screen.dart).
- Để đảm bảo tính minh bạch 2 chiều tuyệt đối, nhân viên có quyền biết ai đang xem vị trí của mình:
  1. Vào tab **Cá nhân** (`/profile`) -> Chọn **"Ai đã xem vị trí của tôi"**.
  2. Màn hình liệt kê chi tiết:
     - Tên người quản lý / giám sát đã truy cập toạ độ của bạn.
     - Thời gian xem chính xác đến từng phút giây.
     - Lý do truy cập (Ví dụ: *Kiểm tra lộ trình tuyến, Hỗ trợ xử lý sự cố đơn hàng, Xác minh viếng thăm*).
     - Toạ độ GPS tại thời điểm được xem.

---

## 6. MODULE 3: TUYẾN BÁN HÀNG & LỘ TRÌNH (ROUTE & MCP)

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

### 6.1. Xem danh sách điểm bán theo tuyến được giao
- Tại thanh điều hướng, chọn tab **Tuyến bán hàng**.
- Bộ lọc phía trên cho phép bạn chọn:
  - Tuyến mặc định theo thứ trong tuần (Thứ Hai, Thứ Ba... Thứ Bảy).
  - Chọn một tuyến cụ thể trong danh sách các tuyến được phân công.
  - Chọn **Tất cả các tuyến** để xem toàn bộ danh sách điểm bán bạn phụ trách.

### 6.2. Bộ nhớ đệm phân vùng riêng biệt theo tài khoản (`dms_user_routes_v2`)
- Danh sách tuyến bán hàng được lưu trữ trong `SharedPreferences` và phân vùng cô lập theo khoá tài khoản đăng nhập (`dms_user_routes_${accountKey}_v2`).
- Dữ liệu giữa các nhân viên khác nhau không bao giờ bị trộn lẫn.
- Khi mất mạng, danh sách tuyến và toàn bộ khách hàng trên tuyến vẫn hiển thị đầy đủ 100%.

### 6.3. Chế độ xem: Danh sách khoảng cách thực tế vs. Bản đồ Goong Map
Bạn có thể chuyển đổi linh hoạt giữa 2 chế độ hiển thị:
1. **Chế độ Danh sách (List View)**:
   - Tự động sắp xếp thứ tự các điểm bán theo **khoảng cách GPS thực tế từ gần đến xa** so với vị trí hiện tại của bạn.
   - Điểm bán nào gần bạn nhất sẽ tự động nhảy lên đầu danh sách để tối ưu thời gian di chuyển.
2. **Chế độ Bản đồ (Map View - Goong Map)**:
   - Hiển thị trực quan toàn bộ các điểm bán dưới dạng ghim màu trên nền bản đồ số Goong Map.
   - Vị trí hiện tại của bạn hiển thị bằng chấm xanh phát sóng.
   - Chạm vào một ghim để xem tóm tắt thông tin và bấm nút mở chỉ đường.

### 6.4. Nhận diện trạng thái viếng thăm các điểm bán
Mỗi thẻ điểm bán trên tuyến có màu sắc và huy hiệu trạng thái rõ ràng:
- ⚪ **Màu Xám / Trắng**: **Chưa ghé thăm** (Cần thực hiện trong ngày).
- 🟠 **Màu Cam nổi bật**: **Đang ghé thăm** (Bạn đã Check-in nhưng chưa bấm Check-out).
- 🟢 **Màu Xanh lá**: **Đã hoàn thành** (Đã Check-out thành công trong ngày hôm nay).

### 6.5. Tìm kiếm không dấu & Sắp xếp điểm bán thông minh
- Thanh tìm kiếm hỗ trợ gõ tiếng Việt không dấu (Ví dụ: gõ `minh chau` sẽ tìm ra `Đại lý Minh Châu`).
- Hỗ trợ tìm kiếm theo Mã điểm bán, Tên điểm bán hoặc Địa chỉ cụ thể.

---

## 7. MODULE 4: QUY TRÌNH VIẾNG THĂM ĐIỂM BÁN CHUẨN 6 BƯỚC (STORE VISIT)

Màn hình chi tiết: [CheckInScreen](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/screens/check_in_screen.dart).

### 7.1. Sơ đồ quy trình chuẩn 6 bước tại điểm bán

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
[6. HOÀN TẤT VIẾNG THĂM]
```

---

### 7.2. Bước 1: Check-in điểm bán & Năm luật kiểm tra nghiêm ngặt
1. Đến điểm bán, mở thẻ điểm bán trên danh sách tuyến, nhấn nút **Bắt đầu viếng thăm / Check-in**.
2. **Kiểm tra Năm luật Check-in từ hệ thống**:
   - **Luật ① (Tuyến được giao)**: Điểm bán phải thuộc quyền quản lý của bạn.
   - **Luật ② (Mỗi ngày một lượt)**: Mỗi điểm bán chỉ được viếng thăm 1 lần trong ngày. Nếu đã hoàn thành, hệ thống sẽ từ chối check-in lần hai.
   - **Luật ③ (Không mở lượt chồng chéo)**: Bạn **không thể mở lượt mới nếu đang còn một lượt khác chưa check-out**. Hãy đóng hoặc huỷ lượt cũ trước.
   - **Luật ④ (Bán kính Geofence)**: Bạn phải đứng trong bán kính quy định của điểm bán (mặc định 100m - 200m). Nếu đứng cách xa, hộp thoại [CheckinDistanceWarningDialog](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/widgets/checkin_distance_warning_dialog.dart) sẽ cảnh báo và yêu cầu lại gần cửa hàng.
   - **Luật ⑤ (Chống Mock GPS)**: Cấm tuyệt đối phần mềm giả lập toạ độ.
3. Khi điều kiện hợp lệ, phiên viếng thăm được mở, đồng hồ đếm thời gian bắt đầu chạy.

---

### 7.3. Bước 2: Chụp ảnh đóng dấu Watermark Canvas (4 dòng thông tin, tối đa 20 ảnh, chống trùng SHA-1)
1. Tại khu vực hình ảnh của màn hình viếng thăm, nhấn **Chụp ảnh**.
2. Camera mở lên chụp trực tiếp:
   - Chụp ảnh mặt tiền biển hiệu cửa hàng.
   - Chụp ảnh quầy kệ trưng bày sản phẩm VTHM Group.
   - Chụp vật phẩm quảng cáo (POSM) hoặc tủ đông/tủ mát.
3. **Cơ chế Watermark tự động bằng Canvas ([PhotoWatermarkHelper](file:///c:/DMS_VTHM/dms-app/lib/core/utils/photo_watermark_helper.dart))**:
   - Ngay khi chụp xong, ứng dụng tự động đóng dấu vĩnh viễn 4 dòng thông tin lên góc dưới bức ảnh:
     - *Dòng 1*: Nhãn hiệu nhận diện `DMS VTHM`.
     - *Dòng 2*: Thời gian chụp chính xác đến từng giây (`DD/MM/YYYY HH:mm:ss`).
     - *Dòng 3*: Toạ độ GPS (`Lat: xx.xxxxxx, Lng: yy.yyyyyy`).
     - *Dòng 4*: Tên điểm bán và địa chỉ thực tế.
4. **Quy định về ảnh**:
   - Giới hạn tối đa **20 ảnh** cho một lượt viếng thăm.
   - Hệ thống tự động kiểm tra mã băm SHA-1 của tệp ảnh; nếu chụp trùng góc ảnh cũ, hệ thống sẽ cảnh báo không tải trùng.
   - Khi lượt viếng thăm chưa kết thúc, bạn có thể bấm icon thùng rác để xoá ảnh chụp bị mờ/lỗi. Sau khi đã Check-out, ảnh sẽ bị khoá hoàn toàn để đảm bảo tính pháp lý.

---

### 7.4. Bước 3: Điền biểu mẫu khảo sát trong lượt (`kind = survey`)
1. Nhấn vào danh sách biểu mẫu khảo sát trong màn hình viếng thăm.
2. Mở biểu mẫu được cấu hình cho điểm bán này (Ví dụ: *Khảo sát giá tháng*, *Khảo sát quầy kệ*).
3. Biểu mẫu có nhãn màu đỏ **"Bắt buộc"** phải được điền và nộp trước khi ra về.
4. Nhập đầy đủ câu trả lời và nhấn **Nộp biểu mẫu**.

---

### 7.5. Bước 4: Soi điều kiện hoàn thành (Check-out Requirements) đếm ngược
Hệ thống cung cấp thẻ hiển thị điều kiện hoàn tất thời gian thực ([VisitRequirementsEntity](file:///c:/DMS_VTHM/dms-app/lib/features/visit/domain/entities/visit_requirements_entity.dart)):
- **Thời gian tối thiểu ở điểm bán**: Đếm ngược số phút/giây còn lại (Ví dụ: Bạn cần ở lại thêm 3 phút nữa mới được Check-out).
- **Số lượng ảnh còn thiếu**: Thông báo số lượng ảnh cần bổ sung (Ví dụ: Cần chụp thêm ít nhất 1 ảnh).
- **Biểu mẫu còn thiếu**: Danh sách các khảo sát bắt buộc chưa nộp.

> [!TIP]
> Nút **KẾT THÚC VIẾNG THĂM (CHECK-OUT)** chỉ sáng lên và cho phép bấm khi toàn bộ các điều kiện trên đã được thoả mãn (Không còn câu cảnh báo Blocker nào).

---

### 7.6. Bước 5: Check-out đóng lượt: Điểm bán Mở cửa (`visited`) vs Điểm bán Đóng cửa (`closed`)
Khi đã hoàn tất công việc tại điểm bán:
1. Nhấn nút **KẾT THÚC VIẾNG THĂM**.
2. Chọn kết quả viếng thăm:
   - **ĐIỂM BÁN MỞ CỬA (`visited`)**:
     - Áp dụng khi điểm bán hoạt động bình thường.
     - Bắt buộc qua đủ 3 cổng: Đủ thời gian tối thiểu, đủ số ảnh, nộp đủ biểu mẫu bắt buộc.
   - **ĐIỂM BÁN ĐÓNG CỬA (`closed`)**:
     - Áp dụng khi bạn đến nơi nhưng đại lý/cửa hàng đóng cửa, chủ đi vắng.
     - **Chính sách ưu đãi**: Được **MIỄN** thời gian tối thiểu và **MIỄN** biểu mẫu khảo sát.
     - **Điều kiện bắt buộc**: Bắt buộc phải **chụp ít nhất 1 ảnh cửa hàng đóng cửa** làm bằng chứng thực địa và **nhập ghi chú lý do đóng cửa** (Ví dụ: *Cửa hàng sửa chữa, Chủ nhà nghỉ lễ*).
3. Ứng dụng ghi nhận toạ độ Check-out và hiển thị hộp thoại chúc mừng hoàn tất [CheckoutSuccessDialog](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/widgets/checkout_success_dialog.dart).

---

### 7.7. Bước 6: Hoàn tất & Tính năng khẩn cấp: Huỷ lượt viếng thăm (Cancel Visit)
- **Khi nào sử dụng?**: Khi bạn vừa bấm Check-in nhưng gặp sự cố đột xuất không thể tiếp tục lượt thăm (Khách hàng từ chối tiếp, sự cố cá nhân, điện thoại hết pin...).
- **Cách thực hiện**:
  1. Tại màn hình viếng thăm đang mở, nhấn vào nút menu (3 chấm) ở góc trên bên phải.
  2. Chọn **Huỷ lượt viếng thăm này**.
  3. Xác nhận đồng ý huỷ.
- **Tác dụng**:
  - Phiên viếng thăm đang dở sẽ được huỷ ngay lập tức trên hệ thống.
  - Bạn được **giải phóng ngay lập tức**, không bị kẹt lỗi *"Còn lượt viếng thăm chưa đóng"* khi di chuyển sang điểm bán tiếp theo.
  - Điểm bán vừa huỷ không bị khoá — bạn hoàn toàn có thể quay lại viếng thăm điểm này vào buổi chiều cùng ngày.

---

## 8. MODULE 5: QUẢN LÝ KHÁCH HÀNG / ĐIỂM BÁN (CUSTOMERS)

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

### 8.1. Tra cứu & Xem chi tiết thông tin điểm bán, gọi điện thoại & chỉ đường
- Nhấn tab **Điểm bán** trên thanh điều hướng.
- Danh sách hiển thị toàn bộ điểm bán bạn được phân quyền phụ trách.
- Bấm vào một điểm bán để mở [CustomerDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/customer_detail_screen.dart):
  - Thông tin chủ hộ kinh doanh, số điện thoại liên hệ (có nút bấm gọi điện thoại trực tiếp).
  - Địa chỉ và vị trí ghim trên bản đồ (có nút mở chỉ đường Google Maps / Goong Map).
  - Lịch sử các lần nhân viên công ty ghé thăm trong quá khứ.
  - Album ảnh thực địa đã chụp tại điểm bán.

---

### 8.2. Thêm mới điểm bán ngoại tuyến (Lấy toạ độ GPS, chụp nhiều ảnh lưu `offline_customer_photos`)
Màn hình: [AddCustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/add_customer_screen.dart).

> [!IMPORTANT]
> Bạn có thể tạo điểm bán mới ngay cả khi **HOÀN TOÀN KHÔNG CÓ MẠNG INTERNET**. Dữ liệu và hình ảnh được lưu an toàn trong máy và tự động tải lên khi có sóng.

1. Tại màn hình Điểm bán, nhấn nút tròn **(+) Thêm điểm bán** ở góc dưới.
2. Điền thông tin theo biểu mẫu:
   - **Tên điểm bán / Cửa hàng**: Tên bảng hiệu (Bắt buộc).
   - **Tuyến bán hàng**: Chọn tuyến phân công (được tự động lưu sẵn trong máy).
   - **Số điện thoại & Người liên hệ**: Nhập số điện thoại đại lý.
   - **Địa chỉ chi tiết**: Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành.
   - **Toạ độ GPS**: Bấm nút **"Lấy vị trí hiện tại"** để tự động điền toạ độ GPS chính xác nơi bạn đang đứng.
3. **Chụp ảnh điểm bán**:
   - Chụp ảnh mặt tiền biển hiệu và không gian cửa hàng.
   - Các ảnh chụp được lưu trữ vĩnh viễn vào thư mục an toàn của ứng dụng (`offline_customer_photos`).
4. Nhấn **LƯU ĐIỂM BÁN**.

### 8.3. Hiển thị tức thời khách hàng pending & Check-in ngay không cần mạng
- Điểm bán mới xuất hiện **NGAY LẬP TỨC** trong danh sách khách hàng của bạn với huy hiệu *"Chờ đồng bộ"*.
- Bạn có thể thực hiện Check-in viếng thăm điểm bán mới này ngay lập tức mà không cần đợi phản hồi từ máy chủ.

### 8.4. Chỉnh sửa và cập nhật thông tin khách hàng
Màn hình: [EditCustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/edit_customer_screen.dart).
- Dùng khi phát hiện đại lý thay đổi số điện thoại, đổi biển hiệu hoặc cập nhật lại toạ độ GPS chuẩn xác hơn.
- Sau khi chỉnh sửa, bấm **Lưu thay đổi** để cập nhật dữ liệu.

---

## 9. MODULE 6: BIỂU MẪU KHẢO SÁT THỊ TRƯỜNG (MARKET FORMS)

Màn hình chi tiết: [FormsScreen](file:///c:/DMS_VTHM/dms-app/lib/features/forms/presentation/screens/forms_screen.dart) & [MarketFormFillScreen](file:///c:/DMS_VTHM/dms-app/lib/features/forms/presentation/screens/market_form_fill_screen.dart).

### 9.1. Phân loại: Biểu mẫu trong lượt (`survey`) vs Biểu mẫu thu thập tự do (`collect`)
Hệ thống DMS VTHM hỗ trợ 2 nhóm biểu mẫu chuyên dụng:
1. **Biểu mẫu viếng thăm (`kind = survey`)**:
   - Gắn liền với một điểm bán cụ thể trong luồng Check-in.
   - Thường dùng cho: Khảo sát tồn kho đại lý, chụp ảnh trưng bày quầy kệ, kiểm tra giá bán lẻ của đối thủ tại quầy.
2. **Biểu mẫu thu thập tự do (`kind = collect`)**:
   - Hiển thị trực tiếp tại tab **Biểu mẫu** trên thanh điều hướng.
   - Không bắt buộc gắn với lượt viếng thăm. Thường dùng cho: Khảo sát người tiêu dùng qua đường, thu thập thông tin đại lý mới tiềm năng, báo cáo chương trình khuyến mãi đột xuất của đối thủ.

---

### 9.2. Hướng dẫn chi tiết tất cả các loại câu hỏi nhập liệu
Hệ thống hỗ trợ công cụ vẽ biểu mẫu động linh hoạt:

| Loại câu hỏi | Giao diện trên app | Hướng dẫn thao tác |
| :--- | :--- | :--- |
| **Tiêu đề nhóm (`heading`)** | Khung màu phân cách lớn | Đọc hướng dẫn hoặc mục lục câu hỏi. |
| **Nhập văn bản (`text` / `textarea`)** | Ô nhập chữ | Nhập nội dung. Hỗ trợ nút **Micro thu âm giọng nói** để chuyển giọng nói tiếng Việt thành văn bản tự động. |
| **Tiền tệ (`currency`)** | Ô nhập số tiền | Nhập số tiền (Ứng dụng tự động định dạng dấu phẩy hàng nghìn, ví dụ: `150,000 đ`). |
| **Lựa chọn một (`select` / `radio`)** | Nút bấm tròn hoặc menu xổ xuống | Chạm để chọn 1 đáp án duy nhất. |
| **Lựa chọn nhiều (`checkbox` / `multiselect`)** | Hộp kiểm vuông | Chạm để chọn một hoặc nhiều phương án phù hợp. |
| **Ngày giờ (`date` / `datetime`)** | Ô lịch chọn ngày | Nhấn để mở bộ chọn lịch ngày/tháng/năm. |
| **Chọn điểm bán (`customer`)** | Danh sách chọn đại lý | Tìm và chọn khách hàng liên quan trong tuyến. |
| **📷 Ô ẢNH THỊ TRƯỜNG (`image`)** | Nút máy ảnh chuyên dụng | **Chụp ảnh thực tế** (Biển hiệu, Bảng giá đối thủ, Kệ hàng trưng bày). Xem số lượng ảnh tối đa quy định bên cạnh. Mỗi ảnh chụp được nén chuẩn và đóng dấu token trước khi nộp. |

---

### 9.3. Tiện ích Nhập liệu bằng giọng nói Tiếng Việt (Voice-to-Text / Micro thu âm)
- Tại các trường nhập văn bản dài hoặc ghi chú khảo sát, bạn có thể bấm vào biểu tượng chiếc **Micro**:
  - Nói trực tiếp bằng tiếng Việt (Ví dụ: *"Đại lý đang tồn 5 thùng mì tôm và 2 két nước ngọt"*).
  - Hệ thống tự động nhận diện giọng nói và điền văn bản vào ô nhập liệu, giúp tiết kiệm thời gian gõ phím khi đang đứng ngoài quầy.

### 9.4. Cơ chế câu hỏi logic phân nhánh (Hiển thị có điều kiện)
Biểu mẫu tích hợp cơ chế logic thông minh: Một số câu hỏi phụ sẽ **tự động xuất hiện hoặc ẩn đi** dựa trên câu trả lời của bạn ở câu trước.
*(Ví dụ: Khi bạn chọn "Có bán hàng của đối thủ", hệ thống mới tự động làm xuất hiện thêm câu "Tên đối thủ" và "Giá bán của đối thủ")*.

### 9.5. Lưu ngoại tuyến & Cơ chế nộp biểu mẫu an toàn
- Khi điền xong biểu mẫu, bấm **Nộp biểu mẫu**.
- Nếu có mạng, biểu mẫu gửi về máy chủ ngay lập tức.
- Nếu mất mạng, câu trả lời được mã hoá lưu vào SQLite cục bộ và hàng đợi `sync_queue`. Khi có mạng trở lại, phiếu khảo sát sẽ tự động được gửi lên máy chủ mà không làm mất bất kỳ câu trả lời nào.

---

## 10. MODULE 7: KHAI BÁO VỊ TRÍ THỰC ĐỊA (POSITION DECLARATION)

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
   │    [ Xem lịch sử khai báo vị trí ]                      │
   └─────────────────────────────────────────────────────────┘
```

### 10.1. Mục đích và các trường hợp sử dụng nghiệp vụ ngoài tuyến
Khai báo vị trí được sử dụng khi nhân viên **ở ngoài các điểm bán thuộc tuyến**, phục vụ các tình huống công việc thực tế:
- Đi công tác ngoại tỉnh, đi khảo sát vùng thị trường mới chưa có mã đại lý.
- Đi họp đột xuất tại chi nhánh, tham gia hội nghị khách hàng.
- Đi phối hợp giải quyết khiếu nại, sự cố đơn hàng hoặc thủ tục hành chính.

### 10.2. Quy trình khai báo: Lý do chuẩn, Chụp ảnh Watermark Canvas & Ghi chú
1. Tại Trang chủ, nhấn vào ô **Khai báo vị trí** (hoặc mở từ menu bên).
2. **Chọn Lý do**: Chọn lý do phù hợp trong danh mục chuẩn hoá (Ví dụ: `001 - Công tác ngoại tỉnh`, `002 - Phối hợp giải quyết công việc ngoài tuyến`). Danh mục này đã được lưu sẵn trong máy nên chọn được cả khi mất sóng.
3. **Chụp ảnh thực địa**: Nhấn nút chụp ảnh không gian bạn đang đứng. Ảnh tự động được đóng dấu Watermark toạ độ GPS, ngày giờ và địa chỉ.
4. **Nhập ghi chú**: Diễn giải ngắn gọn công việc đang xử lý.
5. Nhấn nút **GỬI KHAI BÁO**. Khi có mạng, bản ghi được gửi ngay. Khi mất mạng, bản ghi được cất an toàn vào hàng đợi ngoại tuyến.

### 10.3. Nguyên lý bản ghi Append-only một mốc duy nhất
> [!NOTE]
> Khai báo vị trí là bản ghi **Một mốc duy nhất (Append-only)**: Không có Check-out, không tính thời lượng ở lại. Gửi thành công sẽ được ghi nhận vào lịch sử và **không thể sửa/xoá** nhằm đảm bảo tính toàn vẹn kiểm toán.

### 10.4. Tra cứu lịch sử khai báo vị trí của bản thân
- Truy cập [PositionDeclarationHistoryScreen](file:///c:/DMS_VTHM/dms-app/lib/features/position_declaration/presentation/screens/position_declaration_history_screen.dart) để xem lại danh sách các lượt khai báo vị trí đã thực hiện theo từng ngày.
- Bấm vào từng lượt để xem lại ảnh chụp thực tế và toạ độ đã ghi nhận.

---

## 11. MODULE 8: THEO DÕI QUÃNG ĐƯỜNG DI CHUYỂN (MY TRAVEL)

Màn hình chi tiết: [MyTravelScreen](file:///c:/DMS_VTHM/dms-app/lib/features/travel/presentation/screens/my_travel_screen.dart).

```
[Chấm công Vào ca] ──chặng 1──> [Điểm bán 1] ──chặng 2──> [Điểm bán 2] ──chặng 3──> [Điểm bán cuối]
     (08:00 AM)                   (09:15 AM)                  (10:30 AM)                  (16:45 PM)
```

### 11.1. Nguyên lý tính quãng đường tự động bằng Goong Maps Routing API theo đường bộ xe máy
- Nhân viên **KHÔNG PHẢI TỰ NHẬP TAY SỐ KM**.
- Hệ thống máy chủ tự động tính toán chính xác quãng đường di chuyển bằng xe máy theo **đường bộ thực tế (Goong Maps Routing API)** dựa vào các mốc:
  - **Chặng đầu (`start`)**: Nối từ toạ độ bạn **Chấm công Vào ca** buổi sáng đến toạ độ bạn **Check-in điểm bán đầu tiên**.
  - **Các chặng giữa (`between`)**: Nối từ toạ độ bạn **Check-out điểm bán trước** đến toạ độ bạn **Check-in điểm bán tiếp theo**.
  - **Điểm dừng cuối cùng**: Chuỗi tính toán dừng lại ở **Điểm bán cuối cùng trong ngày** (Đoạn đường từ điểm bán cuối về nhà không nằm trong chi phí công tác).

### 11.2. Mối liên hệ cốt lõi giữa Chấm công, Check-in/out và tính km
> [!IMPORTANT]
> **Hai hành động quyết định quãng đường của bạn có được ghi nhận đủ hay không:**
> 1. **Phải Chấm công Vào ca bằng app**: Nếu buổi sáng bạn quên chấm công trên app, mốc bắt đầu sẽ bị khuyết và chặng đầu tiên sẽ nhận **0 km**.
> 2. **Phải bấm Check-out khi rời quầy**: Toạ độ lúc Check-out là điểm xuất phát của chặng tiếp theo.

### 11.3. Ba trạng thái con số km: Số km tức thì, Cảnh báo 0 km thiếu mốc & Đang xử lý

| Trạng thái hiển thị | Ý nghĩa trên hệ thống | Nhân viên cần biết |
| :--- | :--- | :--- |
| **Con số cụ thể (VD: `28.6 km`)** | Quãng đường đã được máy chủ tính toán tức thì theo thời gian thực. | Con số cập nhật ngay sau mỗi lượt hoàn thành viếng thăm (Check-out), làm căn cứ chính thức tính phụ cấp xăng xe. |
| **`0 km` (Kèm cảnh báo)** | **Thiếu mốc toạ độ**: Do quên chấm công vào ca hoặc không có toạ độ Check-in/out. | Không thể tính toán chặng này do thiếu dữ liệu xuất phát. |
| **Gạch ngang `—` / Tạm tính** | **Đang xử lý / Đang trong phiên**: Lượt viếng thăm đang diễn ra hoặc đang trong tích tắc tính toán bản đồ. | Ngay khi bạn bấm Check-out đóng lượt viếng thăm, con số km của chặng vừa hoàn thành sẽ hiển thị đầy đủ ngay lập tức. |

### 11.4. Tra cứu chi tiết từng chặng di chuyển trong ngày (`/travel/legs`)
Màn hình chi tiết: [TravelLegDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/travel/presentation/screens/travel_leg_detail_screen.dart).
- Vào tab **Cá nhân** -> Chọn **Quãng đường của tôi** -> Chọn ngày công cụ thể:
  - Xem danh sách từng chặng (Ví dụ: *Chặng 1: Từ Văn phòng đến Tạp hoá An Bình - 4.2 km*, *Chặng 2: Từ Tạp hoá An Bình đến Đại lý Hưng Phát - 2.8 km*).
  - Xem toạ độ xuất phát, toạ độ đích đến và thời gian di chuyển của từng chặng.

---

## 12. MODULE 9: BÁO CÁO HOẠT ĐỘNG TRONG NGÀY (DAILY REPORT)

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

### 12.1. Thống kê bộ chỉ số KPI thực địa trong ngày
Đầu màn hình tổng hợp toàn bộ các chỉ số KPI thực địa trong ngày được chọn:
- **Tổng lượt ghé thăm**: Số điểm bán bạn đã thực hiện viếng thăm.
- **Tỷ lệ hoàn thành**: Tỷ lệ phần trăm số điểm bán đã đóng lượt thành công so với kế hoạch tuyến.
- **Đúng vị trí**: Số lượt ghé thăm có khoảng cách Geofence chuẩn xác (< 100m).
- **Cảnh báo rủi ro**: Số lượt ghé thăm có nghi vấn sai lệch toạ độ hoặc cảnh báo thiết bị.

### 12.2. Dòng thời gian Timeline hoạt động & 5 Tab lọc nghiệp vụ
Thẻ [DailyActivityTimelineCard](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/daily_activity_timeline_card.dart) sắp xếp toàn bộ hoạt động của bạn theo thứ tự thời gian giảm dần với 5 tab lọc:
1. **Tất cả**: Xem toàn cảnh diễn biến một ngày làm việc từ lúc vào ca đến lúc ra ca.
2. **Viếng thăm**: Lọc riêng các sự kiện Check-in, chụp ảnh và Check-out tại các cửa hàng.
3. **Chấm công**: Lọc các lượt Chấm công Vào ca và Ra ca.
4. **Khai báo**: Lọc các mốc Khai báo vị trí công tác ngoài tuyến.
5. **Gian lận / Cảnh báo**: Lọc các lượt bị ghi nhận sai lệch vị trí hoặc cảnh báo thiết bị để giải trình với quản lý nếu cần.

### 12.3. Bảng xem chi tiết từng hoạt động (Ảnh watermark, toạ độ, khoảng cách sai lệch, thời gian)
Nhấn vào bất kỳ mục nào trên dòng thời gian để mở bảng chi tiết [ActivityDetailSheet](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/activity_detail_sheet.dart):
- Xem ảnh chụp thực tế có đóng dấu Watermark rõ nét.
- Xem toạ độ GPS lúc thực hiện và khoảng cách sai lệch so với toạ độ đăng ký của cửa hàng.
- Thời gian chính xác đến từng phút giây.

---

## 13. MODULE 10: TRUNG TÂM THÔNG BÁO & NHẮC VIỆC (NOTIFICATIONS)

Màn hình chi tiết: [NotificationsScreen](file:///c:/DMS_VTHM/dms-app/lib/features/notifications/presentation/screens/notifications_screen.dart).

### 13.1. Bảy kịch bản thông báo tự động hỗ trợ nhân viên
Dịch vụ thông báo thông minh [AppNotificationService](file:///c:/DMS_VTHM/dms-app/lib/core/services/app_notification_service.dart) liên tục hỗ trợ nhắc việc cho nhân viên:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 🔔 1. NHẮC VÀO CA SÁNG (07:45 - 08:00)                                       │
│    "Sắp đến giờ vào ca (08:00). Đừng quên chấm công để ghi nhận công hôm nay!"│
├──────────────────────────────────────────────────────────────────────────────┤
│ 🗺️ 2. TÓM TẮT LỘ TRÌNH ĐẦU NGÀY (08:15)                                      │
│    "Hôm nay bạn có 14 điểm bán cần viếng thăm trên tuyến 'Thứ 2 - Q1'.       │
│     Chúc bạn một ngày làm việc hiệu quả!"                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ ⚡ 3. CẢNH BÁO TIẾN ĐỘ TUYẾN (11:30 & 15:30)                                 │
│    "Bạn đã hoàn thành 6/14 điểm bán (43%). Hãy tăng tốc để kịp tiến độ!"     │
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

### 13.2. Điều hướng thông minh & Đánh dấu đã đọc
- Chạm vào biểu tượng quả chuông ở thanh tiêu đề trên để mở màn hình Thông báo.
- Chạm vào một thông báo để **chuyển thẳng đến màn hình nghiệp vụ liên quan** (Ví dụ: chạm thông báo nhắc chấm công sẽ dẫn thẳng đến màn Chấm công).
- Bấm nút **"Đánh dấu đã đọc tất cả"** ở góc trên để xoá các chấm đỏ thông báo chưa đọc.

### 13.3. Công cụ kiểm thử thông báo hệ thống (Test khi tắt app 10s trong Profile)
- Trong tab **Cá nhân** -> Bấm vào mục **Thông báo hệ thống**:
  - Bấm nút **"Thử khi TẮT APP (10s)"**: Ứng dụng sẽ lên lịch một thông báo sau 10 giây. Bạn có thể thoát hẳn ứng dụng ra màn hình chính điện thoại để kiểm tra âm thanh chuông báo khi tắt app hoàn toàn.

---

## 14. MODULE 11: KIẾN TRÚC ĐỒNG BỘ NGOẠI TUYẾN (OFFLINE-FIRST SYNC ENGINE)

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

### 14.1. Nguyên lý vận hành Offline-First: Ghi máy trước, Mạng sau
- **Không bao giờ làm mất dữ liệu của bạn**: Khi bạn ở vùng không có sóng 3G/4G/Wifi (tầng hầm, nhà kho, vùng sâu vùng xa), mọi hành động:
  - Tạo khách hàng mới
  - Check-in điểm bán
  - Chụp ảnh thực địa
  - Điền biểu mẫu thị trường
  - Khai báo vị trí
  đều được lưu trữ **ngay lập tức vào bộ nhớ trong của điện thoại**. Bạn tiếp tục làm việc bình thường mà không bị màn hình chờ xoay vòng xoay tròn làm gián đoạn.

### 14.2. Bảo toàn mốc thời gian bằng Đồng hồ đơn điệu (`queued_seconds`)
- Dù bạn viếng thăm điểm bán lúc 09:00 sáng khi mất mạng và đến 12:00 trưa mới có mạng để đồng bộ, máy chủ vẫn ghi nhận chính xác bạn đã có mặt lúc 09:00 sáng nhờ trường dữ liệu chênh lệch đơn điệu `queued_seconds`.

### 14.3. Bốn trạng thái màu của Huy hiệu Đồng bộ (`OfflineSyncBadge`)
Huy hiệu nằm trên thanh tiêu đề trên đổi màu trực quan theo tình trạng kết nối:

| Màu sắc huy hiệu | Biểu tượng | Trạng thái hiển thị | Ý nghĩa |
| :---: | :---: | :--- | :--- |
| 🟢 **Xanh lá cây** | `Icons.cloud_done` | **Đã đồng bộ** | Thiết bị đang có mạng và toàn bộ dữ liệu trên máy đã được cập nhật thành công lên máy chủ công ty. |
| 🟡 **Màu Vàng hổ phách** | `Icons.cloud_off` | **Ngoại tuyến (X chờ)** | Điện thoại đang bị mất kết nối mạng. Có X bản ghi đang nằm an toàn trong hàng đợi của máy. |
| 🔵 **Màu Xanh dương** | `Icons.cloud_upload` | **X chờ gửi** | Đang có kết nối mạng và hệ thống đang tự động tải X bản ghi lên máy chủ. |
| 🔴 **Màu Đỏ hồng** | `Icons.error_outline` | **X lỗi** | Có bản ghi bị máy chủ từ chối do vi phạm quy tắc. Cần mở ra kiểm tra. |

### 14.4. Hộp thoại Chi tiết Hàng đợi (`_OfflineSyncDetailSheet`) & Nhận diện từng thực thể
Khi nhấn vào Huy hiệu đồng bộ, hộp thoại chi tiết xuất hiện:
- **Tình trạng mạng**: Báo rõ điện thoại đang có Wifi/4G hay đang ngoại tuyến.
- **Hộp thống kê**: Thống kê số lượng bản ghi *Đang chờ gửi* và *Lỗi đồng bộ*.
- **Danh sách nhận diện chính xác từng loại dữ liệu**:
  - 👤 *Thêm khách hàng mới: [Tên khách hàng]* kèm địa chỉ và tuyến.
  - 📍 *Khai báo vị trí: [Lý do khai báo]* kèm địa chỉ.
  - 📋 *Biểu mẫu thị trường: [Mã phiếu]* kèm số lượng câu trả lời.
  - 🏪 *Lượt check-in: [Tên điểm bán]* kèm thời gian check-in.
  - 📷 *Ảnh thực địa* kèm dung lượng ảnh.

### 14.5. Cơ chế Đồng bộ thủ công & Dọn dẹp bản ghi lỗi vĩnh viễn (Dead Entries)
- **Đồng bộ thủ công**: Khi vừa đi từ vùng mất sóng ra nơi có mạng 4G khoẻ, bạn có thể bấm vào Huy hiệu đồng bộ -> Nhấn nút **ĐỒNG BỘ NGAY BÂY GIỜ** để đẩy toàn bộ dữ liệu lên máy chủ ngay tức khắc mà không cần chờ chu kỳ tự động.
- **Xử lý bản ghi lỗi (Dead Queue Entries)**:
  - Nếu một bản ghi bị lỗi vĩnh viễn (Ví dụ: Điểm bán đã bị admin huỷ bỏ trên hệ thống), bản ghi đó sẽ chuyển sang danh sách lỗi màu đỏ.
  - Bạn có thể xem lý do lỗi từ máy chủ và bấm **"Xoá tất cả"** để dọn sạch hàng đợi lỗi, giúp huy hiệu trở lại màu xanh bình thường.

### 14.6. Pipeline tải ảnh 2 bước (Photo Token) & Kháng lỗi mạng tự động
- **Bước 1**: Khi chụp ảnh tạo điểm bán ngoại tuyến, ảnh được lưu trữ an toàn trong thư mục vĩnh viễn của máy (`offline_customer_photos`).
- **Bước 2**: Khi có mạng, dịch vụ đồng bộ tự động tải tệp ảnh lên máy chủ trước để nhận mã xác thực ảnh 32 ký tự hex (`photo_token`), sau đó mới gửi gói dữ liệu điểm bán kèm mã ảnh.
- **Cơ chế Kháng lỗi thông minh**: Nếu việc tải ảnh bị rớt mạng giữa chừng, hệ thống sẽ tự động hoãn lại và thử lại theo cơ chế Exponential Backoff, **tuyệt đối không gửi dữ liệu thiếu ảnh lên máy chủ** để tránh việc bị máy chủ từ chối lỗi dữ liệu.

### 14.7. Kiểm soát hiển thị Dialog mất mạng thông minh
- Không hiển thị chèn ngang khi đang khởi động Splash screen.
- Khi vào màn hình chính, chỉ hiển thị thông báo mất mạng đúng 1 lần duy nhất, **không spam lặp lại mỗi khi chuyển qua lại giữa các tab**.
- Khi có mạng trở lại, cờ thông báo tự động được đặt lại sẵn sàng cho lần mất mạng tiếp theo.

---

## 15. MODULE 12: QUẢN LÝ CÁ NHÂN & CÀI ĐẶT HỆ THỐNG (PROFILE & SETTINGS)

Màn hình chi tiết: [ProfileScreen](file:///c:/DMS_VTHM/dms-app/lib/features/profile/presentation/screens/profile_screen.dart).

### 15.1. Xem thông tin cá nhân, chức danh & phòng ban
- Vào tab **Cá nhân** trên thanh điều hướng:
  - Xem ảnh đại diện, họ tên, mã nhân viên, số điện thoại và email nội bộ.
  - Xem phòng ban (`department`) và chức danh đảm nhiệm.
  - Vào mục **Thông tin cá nhân** (`/profile/personal-info`) để kiểm tra hồ sơ chi tiết.

### 15.2. Chế độ Giao diện Tối (Dark Mode) & Chuyển đổi ngôn ngữ
- **Chế độ Tối (Dark Mode)**: Gạt công tắc Dark Mode để đổi sang tông nền tối. Giúp giảm độ chói khi sử dụng ngoài trời nắng gắt và tiết kiệm đáng kể dung lượng pin màn hình OLED/AMOLED.
- **Ngôn ngữ (Language)**: Hỗ trợ chuyển đổi nhanh chóng giữa **Tiếng Việt** (mặc định) và **English**.

### 15.3. Quy trình Đăng xuất tài khoản an toàn
- Khi cần bàn giao thiết bị hoặc đổi máy làm việc, kéo xuống cuối trang Cá nhân và bấm **ĐĂNG XUẤT**.
- Hệ thống sẽ xoá token xác thực trên thiết bị nhưng giữ an toàn cơ sở dữ liệu SQLite cục bộ.

---

## 16. XỬ LÝ SỰ CỐ THƯỜNG GẶP & BỘ CÂU HỎI FAQ NGHIỆP VỤ

### ❓ FAQ 1: Tại sao tôi bấm Chấm công nhưng nút bị mờ và báo "Chưa có mã nhân viên"?
> **Trả lời**: Tài khoản của bạn chưa được liên kết với mã hồ sơ nhân sự nội bộ. Hãy liên hệ ngay với phòng Nhân sự hoặc Quản trị viên DMS của VTHM Group để được bổ sung Mã nhân viên vào hệ thống.

---

### ❓ FAQ 2: Tôi đứng ngay trước cửa đại lý nhưng app báo "Bạn đang cách điểm bán 180m, hãy lại gần hơn"?
> **Trả lời**: 
> 1. Kiểm tra xem điện thoại của bạn đã bật chế độ **"Vị trí chính xác" (High Accuracy / Precise Location)** trong phần Cài đặt vị trí hay chưa.
> 2. Nếu đang đứng dưới mái tôn hoặc trong ngõ hẻm làm sóng GPS bị lệch, hãy bước ra ngoài trời thoáng khoảng 10 - 15 giây để điện thoại bắt lại toạ độ vệ tinh chính xác.
> 3. Nếu toạ độ gốc của đại lý đăng ký trên hệ thống bị sai lệch so với thực tế, hãy hoàn thành viếng thăm lần này và dùng tính năng **Sửa điểm bán** để cập nhật lại toạ độ chuẩn cho các lần ghé thăm sau.

---

### ❓ FAQ 3: Tôi đến nơi nhưng đại lý đóng cửa đi vắng, làm sao để hoàn thành lượt viếng thăm?
> **Trả lời**: Bạn có 2 cách xử lý:
> - **Cách 1 (Ghi nhận lượt viếng thăm đóng cửa)**: Bấm Check-out -> Chọn kết quả **"Đóng cửa" (Closed)** -> Chụp 1 ảnh cửa hàng đóng cửa làm bằng chứng và ghi chú lý do. Bạn sẽ được **miễn thời gian tối thiểu và miễn điền biểu mẫu**.
> - **Cách 2 (Huỷ lượt để ghé lại sau)**: Bấm nút menu 3 chấm ở góc phải màn hình viếng thăm -> Chọn **"Huỷ lượt viếng thăm này"**. Phiên viếng thăm sẽ được huỷ ngay lập tức, bạn có thể đến điểm tiếp theo bình thường và có thể quay lại điểm này vào buổi chiều.

---

### ❓ FAQ 4: Tôi bị mất mạng Internet cả buổi sáng, dữ liệu có bị mất không?
> **Trả lời**: **Hoàn toàn không mất dữ liệu!** Ứng dụng DMS VTHM được thiết kế theo chuẩn Offline-First. Toàn bộ thông tin khách hàng mới, lượt viếng thăm, hình ảnh và câu trả lời khảo sát đều được lưu giữ an toàn tuyệt đối trong bộ nhớ điện thoại. Khi điện thoại kết nối lại Wifi hoặc 4G, dữ liệu sẽ tự động chuyển về máy chủ công ty theo đúng thứ tự phát sinh.

---

### ❓ FAQ 5: Quãng đường di chuyển của tôi được tính vào lúc nào, có cần chờ qua đêm không?
> **Trả lời**: **HOÀN TOÀN KHÔNG CẦN CHỜ QUA ĐÊM!** Hệ thống DMS VTHM đã loại bỏ hoàn toàn cơ chế đồng bộ đêm. Quãng đường di chuyển được tính toán **tức thì theo thời gian thực ngay khi bạn bấm Kết thúc viếng thăm (Check-out)** tại mỗi điểm bán. Bạn có thể mở mục **Quãng đường của tôi** (`/travel`) bất kỳ lúc nào trong ngày để kiểm tra ngay số km các chặng đã đi và tổng quãng đường tích luỹ trong ngày.

---

### ❓ FAQ 6: Tôi có được chỉnh lùi giờ trên điện thoại để chấm công đúng giờ không?
> **Trả lời**: **Tuyệt đối không!** Hệ thống tích hợp cơ chế chống gian lận thời gian qua đồng hồ đơn điệu và thời gian máy chủ. Nếu bạn chỉnh giờ điện thoại lệch quá ngưỡng cho phép, hệ thống sẽ phát hiện hành vi can thiệp đồng hồ (Clock Skew) và tự động khoá chức năng hoặc gắn cờ vi phạm gửi về cho Giám sát bán hàng.

---

### ❓ FAQ 7: Làm sao để tôi biết ai đã xem vị trí của mình và có bị theo dõi ngoài giờ làm việc không?
> **Trả lời**: 
> 1. **Không theo dõi ngoài giờ**: Tính năng định vị làm việc chỉ phát sóng khi bạn đang trong ca làm việc (đã Chấm Vào ca) và tự động tắt hoàn toàn khi bạn Chấm Ra ca.
> 2. **Kiểm tra minh bạch**: Bạn vào tab **Cá nhân** -> Chọn **"Ai đã xem vị trí của tôi"** (`/location-access-log`). Màn hình sẽ hiển thị danh sách người quản lý nào đã xem vị trí của bạn, vào thời gian nào, toạ độ nào và lý do xem là gì.

---

### 16.8. Kênh tiếp nhận hỗ trợ kỹ thuật nội bộ VTHM Group
Nếu gặp bất kỳ sự cố kỹ thuật nào trong quá trình sử dụng ứng dụng di động:
- **Bộ phận IT Support**: Hotline nội bộ hoặc liên hệ nhóm Zalo Hỗ trợ Kỹ thuật DMS VTHM.
- **Thời gian tiếp nhận**: Từ 07:30 đến 18:00 (Thứ Hai đến Thứ Bảy).
- **Khi báo lỗi**: Vui lòng chụp ảnh màn hình lỗi, ghi rõ Mã nhân viên và dòng điện thoại đang sử dụng để bộ phận kỹ thuật hỗ trợ nhanh nhất.

---
*Cẩm nang Hướng Dẫn Sử Dụng được chuẩn hoá và ban hành đồng bộ theo phiên bản hoàn thiện của Hệ thống Phân phối Thực địa DMS VTHM Mobile.*

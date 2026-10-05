# TỔNG HỢP DANH SÁCH MÀN HÌNH & TÍNH NĂNG - GIAI ĐOẠN HOÀN THIỆN DMS VTHM

Tài liệu này tổng hợp toàn bộ danh sách các màn hình, widget chuyên dụng và các tính năng trọng tâm đã được triển khai, tối ưu và kiểm thử trong giai đoạn (phase) này của ứng dụng **DMS VTHM Mobile**.

---

## 1. DANH SÁCH CÁC MÀN HÌNH & MODAL (SCREENS & MODALS)

### 1.1. Màn hình Trang chủ ([HomeScreen](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/screens/home_screen.dart))
- **Vị trí:** `lib/features/home/presentation/screens/home_screen.dart`
- **Các thành phần chính:**
  - **VthmTopAppBar:** Tích hợp trực tiếp [OfflineSyncBadge](file:///c:/DMS_VTHM/dms-app/lib/core/widgets/offline_sync_badge.dart) theo dõi trạng thái mạng và số lượng bản ghi chờ gửi thời gian thực.
  - **Khu vực Quick Actions ([HomeQuickActions](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/widgets/home_quick_actions.dart)):**
    - **Box Chấm công:** Box màu pastel hổ phách nhạt (`#FEF3C7`), biểu tượng camera chấm công vào/ra ca làm việc.
    - **Box Khai báo vị trí:** Box màu pastel xanh ngọc ngọc bích nhạt (`#CCFBF1`), mở tính năng chụp ảnh và khai báo tọa độ thực địa.
    - **Box Báo cáo (Mới bổ sung):** Nằm ngay dưới box Chấm công với tông màu xanh lavender pastel dịu mắt (`#EEF2FF`), mở menu bottom sheet báo cáo tổng hợp.

### 1.2. Menu Báo cáo Nhanh ([ReportMenuBottomSheet](file:///c:/DMS_VTHM/dms-app/lib/features/home/presentation/widgets/report_menu_bottom_sheet.dart))
- **Vị trí:** `lib/features/home/presentation/widgets/report_menu_bottom_sheet.dart`
- **Chức năng:** Bottom sheet trượt lên khi nhấn vào box "Báo cáo" tại Trang chủ, cung cấp 4 lối tắt:
  1. **Báo cáo viếng thăm & Hoạt động trong ngày:** Dẫn tới màn hình Timeline tổng hợp (`/daily-report`).
  2. **Lịch sử chấm công:** Xem lại các lượt chấm công và thời gian vào ca.
  3. **Lịch sử khai báo vị trí:** Xem lại lịch sử các điểm bán/vị trí đã gửi hoặc lưu offline.
  4. **Nghi vấn gian lận & Rủi ro:** Lọc nhanh các bản ghi bị cảnh báo Mock GPS hoặc sai lệch Geofence.

### 1.3. Màn hình Báo cáo Hoạt động trong ngày ([DailyReportScreen](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/screens/daily_report_screen.dart))
- **Vị trí:** `lib/features/daily_report/presentation/screens/daily_report_screen.dart` (Route: `/daily-report`)
- **Chức năng:**
  - Tổng hợp số liệu KPI trong ngày (Tổng lượt ghé thăm, Đã hoàn thành, Đúng vị trí, Cảnh báo rủi ro).
  - Tích hợp [DailyActivityTimelineCard](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/daily_activity_timeline_card.dart) với 5 tab lọc động:
    - *Tất cả*
    - *Viếng thăm*
    - *Chấm công*
    - *Khai báo*
    - *Gian lận / Cảnh báo*
  - Bottom sheet chi tiết hoạt động ([ActivityDetailSheet](file:///c:/DMS_VTHM/dms-app/lib/features/daily_report/presentation/widgets/activity_detail_sheet.dart)) hiển thị ảnh thực địa, toạ độ, khoảng cách sai lệch và thời gian cụ thể.

### 1.4. Modal Chi tiết Hàng đợi Ngoại tuyến ([_OfflineSyncDetailSheet](file:///c:/DMS_VTHM/dms-app/lib/core/widgets/offline_sync_badge.dart#L114-L330))
- **Vị trí:** `lib/core/widgets/offline_sync_badge.dart`
- **Chức năng:**
  - Nhận diện chính xác 100% từng thực thể hàng đợi đang chờ gửi:
    - **Thêm khách hàng mới:** Hiển thị tên khách hàng đã nhập, tuyến bán hàng, địa chỉ, icon `Icons.person_add_alt_1_rounded` màu xanh lá lục bảo.
    - **Khai báo vị trí:** Hiển thị lý do khai báo, địa chỉ thực địa, icon `Icons.pin_drop_rounded`.
    - **Biểu mẫu thị trường:** Hiển thị tên/mã phiếu khảo sát, icon `Icons.assignment_turned_in_rounded`.
    - **Lượt check-in & viếng thăm:** Hiển thị tên điểm bán ghé thăm, icon `Icons.location_on_rounded`.
    - **Ảnh thực địa:** Icon `Icons.photo_camera_rounded`.
  - Hiển thị danh mục các bản ghi lỗi đồng bộ vĩnh viễn (nếu có lỗi 4xx) kèm nút "Xóa tất cả lỗi".
  - Nút bấm *"Đồng bộ ngay bây giờ"* để kích hoạt đẩy toàn bộ dữ liệu lên máy chủ ngay lập tức.

### 1.5. Màn hình Tuyến Bán hàng ([RouteScreen](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/screens/route_screen.dart))
- **Vị trí:** `lib/features/route/presentation/screens/route_screen.dart`
- **Chức năng:**
  - Hiển thị danh sách khách hàng theo từng tuyến hoặc tất cả các tuyến.
  - Hoạt động mượt mà cả khi ngoại tuyến nhờ cơ chế cache SQLite và tự động trích xuất danh sách tuyến.
  - Sắp xếp thứ tự ghé thăm theo khoảng cách GPS thực tế từ vị trí nhân viên.
  - Trực quan hóa tiến độ viếng thăm theo timeline và bản đồ Goong Map.

### 1.6. Màn hình Check-in Điểm bán ([CheckInScreen](file:///c:/DMS_VTHM/dms-app/lib/features/route/presentation/screens/check_in_screen.dart))
- **Vị trí:** `lib/features/route/presentation/screens/check_in_screen.dart`
- **Chức năng:**
  - Xác thực khoảng cách Geofence so với toạ độ điểm bán thực tế.
  - Tự động đóng dấu toạ độ GPS, thời gian thực và địa chỉ lên ảnh chụp tại điểm bán.
  - Kiểm tra các dấu hiệu gian lận (Mock Location, Clock Skew) trước khi cho phép mở lượt thăm.

### 1.7. Màn hình Khai báo Vị trí ([PositionDeclarationScreen](file:///c:/DMS_VTHM/dms-app/lib/features/position_declaration/presentation/screens/position_declaration_screen.dart))
- **Vị trí:** `lib/features/position_declaration/presentation/screens/position_declaration_screen.dart`
- **Chức năng:**
  - Chụp ảnh thực tế, tự động đóng dấu toạ độ và thời gian lên ảnh bằng Canvas.
  - Khai báo lý do di chuyển / dừng chân ngoài tuyến.
  - Lưu trữ ngoại tuyến an toàn vào SQLite và hàng đợi đồng bộ khi không có kết nối Internet.

### 1.8. Màn hình Khách hàng & Thêm mới ([CustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/customer_screen.dart) & [AddCustomerScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/add_customer_screen.dart))
- **Vị trí:**
  - Danh sách: `lib/features/customer/presentation/screens/customer_screen.dart`
  - Thêm mới: `lib/features/customer/presentation/screens/add_customer_screen.dart`
- **Chức năng:**
  - Tạo mới điểm bán ngoại tuyến, sinh `client_uuid` duy nhất, lưu SQLite tức thì.
  - Lựa chọn tuyến bán hàng bình thường ngay cả khi không có mạng nhờ cache tuyến `SharedPreferences`.
  - Hiển thị tức thì khách hàng mới tạo trong danh sách mà không cần đợi phản hồi từ máy chủ.

---

## 2. DANH SÁCH CÁC TÍNH NĂNG TRỌNG TÂM (CORE FEATURES)

### 2.1. Huy hiệu & Quản trị Hàng đợi Ngoại tuyến (Offline Sync Badge)
| Thành phần | Đặc điểm & Hành vi |
| :--- | :--- |
| **Trạng thái hiển thị** | Ẩn khi online và không có hàng đợi; hiển thị badge xanh lá khi đã đồng bộ; badge vàng khi ngoại tuyến; badge xanh dương khi có bản ghi chờ; badge đỏ khi có bản ghi lỗi. |
| **Nhận diện chính xác** | Đọc trực tiếp từ bảng `SyncQueueEntries` trong SQLite, phân tích payload JSON để hiển thị đúng: *"Thêm khách hàng mới: [Tên]"*, *"Khai báo vị trí: [Lý do]"*, *"Biểu mẫu thị trường"*, *"Lượt check-in: [Điểm bán]"*. |
| **Tương tác modal** | Nhấn vào badge mở bottom sheet chi tiết, xem thông tin từng bản ghi, thời gian tạo, và nhấn *"Đồng bộ ngay bây giờ"*. |

### 2.2. Timeline Hoạt động trong ngày (Daily Activity Timeline)
| Thành phần | Đặc điểm & Hành vi |
| :--- | :--- |
| **Dòng thời gian** | Sắp xếp toàn bộ hoạt động trong ngày theo thứ tự giảm dần thời gian (giờ:phút). |
| **Phân loại trực quan** | 4 màu sắc & biểu tượng đặc trưng: Xanh lá (Check-in), Cam (Chấm công), Xanh biển (Khai báo), Đỏ (Nghi vấn gian lận/sai toạ độ). |
| **Bộ lọc danh mục** | Lọc linh hoạt giữa 5 tab: Tất cả, Viếng thăm, Chấm công, Khai báo, Gian lận. |
| **Sheet chi tiết** | Xem ảnh chụp thực tế có đóng dấu watermark, khoảng cách GPS sai lệch so với mục tiêu và địa chỉ chi tiết. |

### 2.3. Chụp ảnh Đóng dấu Toạ độ & Thời gian (Photo Watermark Engine)
| Thành phần | Đặc điểm & Hành vi |
| :--- | :--- |
| **Bộ xử lý ảnh** | [PhotoWatermarkHelper](file:///c:/DMS_VTHM/dms-app/lib/core/utils/photo_watermark_helper.dart) sử dụng `dart:ui.Canvas` vẽ trực tiếp lên luồng bitmap ảnh, tối ưu bộ nhớ, không phụ thuộc thư viện native bên ngoài. |
| **Thông tin đóng dấu** | - Dòng 1: Logo & Nhãn hiệu nhận diện `DMS VTHM`<br>- Dòng 2: Thời gian chụp chính xác đến từng giây (`DD/MM/YYYY HH:mm:ss`)<br>- Dòng 3: Tọa độ GPS (`Lat: xx.xxxxxx, Lng: yy.yyyyyy`)<br>- Dòng 4: Tên điểm bán hoặc địa chỉ thực địa |
| **Áp dụng** | Tự động áp dụng cho ảnh chụp Check-in tại điểm bán và ảnh chụp Khai báo vị trí. |

### 2.4. Quản trị Rủi ro & Chống Gian lận (Anti-Fraud Engine)
| Thành phần | Đặc điểm & Hành vi |
| :--- | :--- |
| **Dịch vụ cốt lõi** | [AntiFraudService](file:///c:/DMS_VTHM/dms-app/lib/core/services/anti_fraud_service.dart) phân tích dữ liệu vị trí và thiết bị dựa trên bộ quy tắc doanh nghiệp `mobile-rules`. |
| **Phát hiện Mock GPS** | Kiểm tra cờ `isMockLocation` từ phần cứng Android/iOS, phát hiện ứng dụng tạo vị trí giả lập. |
| **Phát hiện Clock Skew** | Đối chiếu thời gian thiết bị với đồng hồ đơn điệu (monotonic clock) và server time để phát hiện hành vi chỉnh lùi giờ trên điện thoại. |
| **Kiểm tra Geofence** | Tính toán khoảng cách Haversine giữa vị trí nhân viên và tọa độ điểm bán đã đăng ký, cảnh báo nếu vượt quá bán kính cho phép (mặc định 100m - 200m). |
| **Mức độ rủi ro** | Chấm điểm rủi ro 3 cấp độ: `low` (An toàn), `medium` (Cần chú ý), `high` (Nghi vấn gian lận cao). |

### 2.5. Cơ chế Ngoại tuyến & Tự động Làm mới Bộ nhớ đệm (Offline-First & Auto-Refresh Cache)
| Thành phần | Đặc điểm & Hành vi |
| :--- | :--- |
| **Cache Khách hàng** | - Lưu trữ trong bảng `LocalCustomers` (SQLite).<br>- Đã gỡ bỏ hoàn toàn logic xóa cache cũ `hasStaleMockRoutes`.<br>- Khi offline: Trả về dữ liệu SQLite tức thì.<br>- Khi online: Gọi API server, tự động ghi đè và làm mới SQLite cache qua `cacheRemoteCustomers(reconcile: true)`, xóa khách hàng đã bị hủy trên server mà không ảnh hưởng bản ghi pending. |
| **Cache Tuyến bán hàng (Phân vùng theo tài khoản)** | - Lưu trữ danh sách tuyến trong `SharedPreferences` phân vùng riêng biệt theo ID người dùng đăng nhập (`dms_user_routes_${accountKey}_v2`).<br>- Cô lập 100% dữ liệu tuyến giữa các tài khoản khác nhau.<br>- Tự động phát hiện và dọn sạch các cache mock cũ (`Vũ Tùng Dương`) khi tài khoản thực đăng nhập.<br>- Gỡ bỏ triệt để mock interceptor đánh chặn lỗi `/dms/routes/mine` trên network layer.<br>- Khi offline: Đọc tuyến từ cache của chính tài khoản; nếu cache chưa có, tự động trích xuất các tuyến từ danh sách khách hàng trong SQLite (`LocalCustomers`) của tài khoản.<br>- Khi online: Gọi `/dms/routes/mine`, tự động cập nhật và ghi đè cache của tài khoản. |
| **Tạo Điểm bán & Đồng bộ Ảnh Ngoại tuyến** | - **Bảo toàn ảnh cục bộ**: Khi chụp ảnh tạo điểm bán lúc không có mạng, đường dẫn ảnh được sao chép vào bộ nhớ lưu trữ ứng dụng vĩnh viễn (`offline_customer_photos`), tránh bị hệ điều hành dọn dẹp cache.<br>- **Hiển thị tức thì**: Cập nhật ngay vào `LocalCustomers.dynamicFieldsJson` và `CustomerEntity`, cho phép thẻ khách hàng ([CustomerCard](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/widgets/customer_card.dart)) và màn chi tiết ([CustomerDetailScreen](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/customer_detail_screen.dart)) hiển thị ảnh chụp ngay khi đang offline.<br>- **Đóng gói hàng đợi chuẩn**: Lưu trữ cả đường dẫn ảnh cục bộ vào hàng đợi `sync_queue`.<br>- **Pipeline đồng bộ 2 bước khi có mạng**: [SyncService](file:///c:/DMS_VTHM/dms-app/lib/core/sync/sync_service.dart) tự động gửi các tệp ảnh lên endpoint `/crm/customer-photos` để lấy token 32-hex, gán vào payload `photo_tokens` gửi lên `/crm/customers`, sau đó cập nhật SQLite với token chính thức và tự động dọn dẹp tệp ảnh offline tạm.<br>- **Kháng lỗi mạng & Retry an toàn**: Nếu quá trình upload ảnh gặp sự cố mạng (500, timeout), tác vụ sẽ được giữ lại trong hàng đợi để thử lại theo Exponential Backoff, tuyệt đối không gửi payload thiếu ảnh lên server tránh bị lỗi 422. |
| **Dialog Thông báo Mất mạng** | - **Không chèn vào màn hình Splash**: Tự động hoãn hiển thị dialog mất mạng khi ứng dụng đang chạy Splash screen.<br>- **Chỉ hiện 1 lần duy nhất**: Sau khi chuyển vào màn chính (Login/Home), dialog hiển thị 1 lần sau 500ms.<br>- **Không lặp lại khi chuyển màn**: Khi người dùng đóng popup và di chuyển qua lại giữa các màn hình (Khách hàng, Tuyến bán hàng, Biểu mẫu...), các lỗi mạng do API gây ra sẽ không kích hoạt lại dialog.<br>- **Tự động đặt lại**: Khi có kết nối mạng trở lại, cờ được reset để sẵn sàng thông báo đúng 1 lần cho đợt mất mạng tiếp theo. |
| **Tự động đồng bộ** | - Khi thiết bị có mạng trở lại, [SyncService](file:///c:/DMS_VTHM/dms-app/lib/core/sync/sync_service.dart) tự động gửi các bản ghi trong hàng đợi theo thứ tự FIFO.<br>- Ngay khi gửi xong, tự động kích hoạt `loadCustomers(isRefresh: true)` và `getMyRoutes(forceRefresh: true)` để làm mới dữ liệu toàn diện. |

---

## 3. SƠ ĐỒ FILE SOURCE CODE TRIỂN KHAI

```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart          <- SQLite Table & Streams: watchAllPendingQueueEntries, watchDeadQueueEntries
│   │   └── database_provider.dart     <- Providers: allPendingQueueEntriesProvider, deadQueueEntriesProvider
│   ├── services/
│   │   └── anti_fraud_service.dart    <- Dịch vụ chống gian lận: Mock GPS, Clock Skew, Geofence
│   ├── sync/
│   │   └── sync_service.dart          <- Bộ điều khiển đồng bộ FIFO & tự động refresh cache khi online
│   ├── utils/
│   │   └── photo_watermark_helper.dart<- Vẽ watermark toạ độ & thời gian bằng Canvas lên ảnh
│   └── widgets/
│       ├── offline_sync_badge.dart    <- Huy hiệu ngoại tuyến & Modal nhận diện từng bản ghi
│       └── top_app_bar.dart           <- Gắn OfflineSyncBadge lên thanh tiêu đề chung
├── features/
│   ├── daily_report/                  <- Tính năng Báo cáo Hoạt động trong ngày
│   │   ├── domain/entities/           <- DailyActivityEntity, DailyReportSummary
│   │   └── presentation/
│   │       ├── screens/daily_report_screen.dart
│   │       └── widgets/
│   │           ├── daily_activity_timeline_card.dart
│   │           └── activity_detail_sheet.dart
│   ├── home/
│   │   └── presentation/widgets/
│   │       ├── home_quick_actions.dart          <- 3 Box pastel: Chấm công, Khai báo, Báo cáo
│   │       └── report_menu_bottom_sheet.dart    <- Menu 4 lựa chọn báo cáo nhanh
│   ├── customer/
│   │   └── data/repositories/
│   │       └── customer_repository_impl.dart    <- Cache SQLite khách hàng & loại bỏ xoá cache lỗi
│   └── route/
│       ├── data/services/
│       │   └── route_api_service.dart           <- Cache SharedPreferences cho tuyến bán hàng
│       └── presentation/screens/
│           └── check_in_screen.dart             <- Đóng dấu ảnh toạ độ khi check-in
```

---

## 4. KẾT QUẢ KIỂM THỬ (TEST SUITE VERIFICATION)

Các bài test tự động được viết mới và cập nhật đều đã vượt qua 100%:
1. `test/offline_sync_badge_test.dart`: Xác thực modal nhận diện chính xác thực thể khách hàng *"Thêm khách hàng mới: [Tên]"*, không bị gán nhầm thành check-in.
2. `test/customer_sync_online_offline_test.dart`: Xác thực lưu trữ ngoại tuyến khách hàng vào SQLite, đọc không lỗi khi offline, cache tuyến vào SharedPreferences và tự động ghi đè khi online.
3. `test/anti_fraud_test.dart`: Xác thực phát hiện vị trí giả lập Mock GPS, chênh lệch giờ và khoảng cách ngoài bán kính.
4. `test/daily_report/daily_report_test.dart`: Xác thực tính toán số liệu KPI và lọc hoạt động theo từng danh mục tab.
5. Toàn bộ 20 unit/widget tests trọng tâm đều hoàn thành xuất sắc (`All tests passed!`).

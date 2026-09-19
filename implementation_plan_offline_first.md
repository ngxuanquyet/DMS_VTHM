# Kế hoạch Triển khai Đồng bộ Offline-First (Drift SQLite) & Thêm mới Khách hàng Offline

Tài liệu thiết kế chi tiết triển khai cơ chế **Offline-First** cho tính năng thêm mới khách hàng (`crm_customer`) trên app DMS, tuân thủ nghiêm ngặt đặc tả tại [SPEC-DONG-BO-OFFLINE-2026-09-15.md](file:///c:/DMS_VTHM/dms-app/specs/sync_offline/SPEC-DONG-BO-OFFLINE-2026-09-15.md) và sử dụng thư viện **Drift** (SQLite).

---

## 1. Phân tích Hiện trạng & Các Bất biến Cốt lõi (Invariants)

Theo đặc tả tại [SPEC-DONG-BO-OFFLINE-2026-09-15.md](file:///c:/DMS_VTHM/dms-app/specs/sync_offline/SPEC-DONG-BO-OFFLINE-2026-09-15.md):

1. **BB-1: Ghi máy trước, mạng sau (Single Write Path)**:
   - Không chia 2 nhánh "online gửi thẳng / offline xếp hàng".
   - Mọi thao tác thêm khách hàng đều ghi vào SQLite cục bộ (Drift) trước $\rightarrow$ xếp hàng vào `sync_queue` $\rightarrow$ tiến trình nền (`SyncService`) đẩy lên server.
   - Sóng tốt thì hàng đợi đồng bộ sau < 1 giây; người dùng luôn thấy phản hồi mượt mà tức thì.
2. **BB-2: `client_uuid` sinh LÚC NHẬP, không phải lúc gửi**:
   - Khi người dùng bấm "Lưu", sinh ngay `client_uuid = const Uuid().v4()`.
   - `client_uuid` gắn chặt vào bản ghi khách hàng cục bộ và `sync_queue`. Khi mất mạng thử lại N lần, toàn bộ N lần đều dùng **CHUNG một UUID duy nhất** để server khử trùng tuyệt đối (Idempotency).
3. **BB-3: `client_uuid` $\neq$ `legacy_key`**:
   - Tách biệt hoàn toàn, không dùng lẫn.
4. **Hàng đợi `sync_queue` (§3.1)**:
   - Bảng SQLite lưu các cột: `id`, `entity` ('customer'), `op` ('create'), `client_uuid`, `parent_uuid`, `payload` (JSON đóng gói sẵn lúc nhập, không dựng lại lúc gửi), `state` ('pending' | 'sending' | 'done' | 'dead'), `attempts`, `next_attempt_at`, `last_error`, `created_at`, `created_elapsed` (đồng hồ đơn điệu monotonic), `boot_id`, `server_id`.
5. **Hồi phục tiến trình gửi mồ côi (§3.3 Luật 5)**:
   - Khi app khởi động, tự động chuyển toàn bộ mục `sending` về lại `pending`.
6. **Tìm kiếm offline không dấu (§7.4)**:
   - SQLite không có hàm `unaccent`, do đó lưu sẵn cột `name_unaccent` lúc nạp vào SQLite để khi gõ "nguyen" vẫn tìm ra "Nguyễn".
7. **Cache Schema Form Điểm bán**:
   - Schema form động (`/crm/customers/form-schema`) được cache sẵn cục bộ để khi không có mạng, người dùng vẫn mở được form thêm điểm bán với đầy đủ trường dữ liệu.

---

## 2. Các Thay đổi Đề xuất

### 2.1 Dependencies (`pubspec.yaml`)
Thêm các thư viện chính thức hỗ trợ SQLite & UUID:
- `drift: ^2.28.2`: Thư viện ORM/Database SQLite reactive typesafe cho Flutter.
- `sqlite3_flutter_libs: ^0.6.0+eol`: Thư viện binary sqlite3 native cho Android, iOS, Windows.
- `path_provider: ^2.1.6`: Lấy thư mục lưu trữ file database trên thiết bị.
- `path: ^1.9.1`: Xử lý đường dẫn file DB.
- `uuid: ^4.6.0`: Sinh UUID v4 chuẩn lúc nhập.
- `dev_dependencies`: `drift_dev: ^2.28.0` để sinh code bảng Drift (`build_runner`).

---

### 2.2 Core Database Layer (`lib/core/database/`)

#### [NEW] [app_database.dart](file:///c:/DMS_VTHM/dms-app/lib/core/database/app_database.dart)
Khởi tạo Drift Database với 2 bảng chính:
1. **`SyncQueueEntries`** (khớp chính xác bảng `sync_queue` tại §3.1):
   - `id`: Int, autoIncrement, primaryKey
   - `entity`: Text ('customer', 'visit', ...)
   - `op`: Text ('create', 'checkout', ...)
   - `clientUuid`: Text (unique)
   - `parentUuid`: Text (nullable)
   - `payload`: Text (JSON string)
   - `localPath`: Text (nullable, cho ảnh)
   - `state`: Text ('pending', 'sending', 'done', 'dead')
   - `attempts`: Int (default 0)
   - `nextAttemptAt`: Int (nullable, epoch ms)
   - `lastError`: Text (nullable)
   - `createdAt`: Int (epoch ms)
   - `createdElapsed`: Int (monotonic ms)
   - `bootId`: Text (định danh phiên khởi động)
   - `serverId`: Int (nullable)
2. **`LocalCustomers`**:
   - Lưu trữ danh sách khách hàng trên máy offline: `id` (server ID nếu có), `clientUuid`, `code`, `name`, `nameUnaccent` (tìm kiếm không dấu §7.4), `type`, `customerTypeId`, `channelName`, `channelId`, `regionId`, `route`, `address`, `provinceName`, `wardName`, `contactPerson`, `contactTitle`, `phone`, `email`, `lat`, `lng`, `geofenceRadiusM`, `status`, `approvalStatus` (mặc định 'pending' khi mở offline §5.4), `dynamicFieldsJson`, `syncStatus` ('synced', 'pending', 'error'), `createdAt`, `updatedAt`.
3. DAO và helper queries:
   - `getPendingQueueEntries()`
   - `recoverOrphanedSendingEntries()` (Luật 5)
   - `markEntrySending()`, `markEntryDone()`, `markEntryDead()`, `rescheduleEntry()`
   - `insertOrUpdateCustomer()`, `searchCustomers(query)` (sử dụng unaccent), `getCustomers()`.

#### [NEW] [database_provider.dart](file:///c:/DMS_VTHM/dms-app/lib/core/database/database_provider.dart)
Riverpod provider quản lý singleton instance của `AppDatabase`.

---

### 2.3 Tiện ích & Sync Layer (`lib/core/sync/` & `lib/core/utils/`)

#### [NEW] [string_utils.dart](file:///c:/DMS_VTHM/dms-app/lib/core/utils/string_utils.dart)
Hàm `removeDiacritics(String text)` chuyển đổi tiếng Việt có dấu sang không dấu (phục vụ cột `name_unaccent` §7.4).

#### [NEW] [sync_service.dart](file:///c:/DMS_VTHM/dms-app/lib/core/sync/sync_service.dart)
Bộ gửi hàng đợi chạy nền (Single Sender Process §3.3 Luật 4):
- Khởi động app: Gọi `recoverOrphanedSendingEntries()` (§3.3 Luật 5).
- Lắng nghe sự kiện mạng từ `connectivityProvider`: Khi có mạng $\rightarrow$ tự động kích hoạt `syncQueue()`.
- Xử lý hàng đợi FIFO:
  - Lấy các mục `state = 'pending'` và `next_attempt_at <= now`.
  - Giới hạn kích thước lô: tối đa 50 mục (§3.3 Luật 6).
  - Đối với từng mục `customer` + `op='create'`:
    - Chuyển `state = 'sending'`.
    - Gửi request lên server (gửi payload chứa `client_uuid`).
    - Nếu thành công (HTTP 200 / `CREATED` hoặc `ALREADY_EXISTS` §4.3): Đánh dấu `done`, cập nhật `server_id`, chuyển trạng thái khách hàng trong SQLite thành `syncStatus = 'synced'`.
    - Nếu lỗi 403 / 422 / INVALID: Đánh dấu `dead` (§3.2).
    - Nếu lỗi mạng / 5xx / timeout: Thử lại vô hạn với exponential backoff (`2s, 4s, 8s, 16s, max 5m`) kèm jitter $\pm 20\%$ (§8.2). `client_uuid` giữ nguyên tuyệt đối (§8.3).

---

### 2.4 Customer Feature Integration (`lib/features/customer/`)

#### [NEW] [customer_local_data_source.dart](file:///c:/DMS_VTHM/dms-app/lib/features/customer/data/datasources/customer_local_data_source.dart)
Nguồn dữ liệu cục bộ Drift:
- Ghi khách hàng mới vào SQLite kèm `client_uuid`.
- Đẩy vào bảng `sync_queue`.
- Đọc danh sách điểm bán offline kết hợp tìm kiếm không dấu (`name_unaccent`).
- Đồng bộ danh sách từ remote về SQLite cache.

#### [MODIFY] [customer_repository_impl.dart](file:///c:/DMS_VTHM/dms-app/lib/features/customer/data/repositories/customer_repository_impl.dart)
- Cập nhật `createCustomer(data)`:
  1. Sinh `clientUuid = const Uuid().v4()` ngay tại đây.
  2. Lưu vào Drift SQLite `LocalCustomers` (`syncStatus = 'pending'`, `approvalStatus = 'pending'`).
  3. Xếp hàng vào `SyncQueueEntries`.
  4. Trả về `CustomerEntity` ngay lập tức để UI cập nhật tức thì.
  5. Gọi ngầm `SyncService.syncQueue()` để gửi lên server nếu đang có mạng.
- Cập nhật `getCustomers()`:
  - Đọc từ Drift SQLite để offline vẫn hiển thị đầy đủ danh sách (kể cả các điểm bán vừa tạo offline với badge "Chờ đồng bộ").
  - Khi có mạng, nạp từ remote và cập nhật vào Drift SQLite.
- Cập nhật `getCustomerFormSchema()`:
  - Lưu schema vào SharedPreferences / Local cache để khi offline màn hình Thêm mới điểm bán vẫn mở được form đầy đủ.

#### [MODIFY] [customer_card.dart](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/widgets/customer_card.dart)
- Hiển thị badge trực quan "Chờ đồng bộ" (màu cam/vàng) nếu khách hàng có trạng thái `syncStatus == 'pending'`.

#### [MODIFY] [add_customer_screen.dart](file:///c:/DMS_VTHM/dms-app/lib/features/customer/presentation/screens/add_customer_screen.dart)
- Cải tiến thông báo khi thêm điểm bán thành công: Nếu đang offline, hiển thị snackbar "Đã lưu trên máy và xếp hàng chờ đồng bộ khi có mạng!".
- Màn hình tự động đóng và cập nhật danh sách ngay lập tức.

---

## 3. Kế hoạch Kiểm thử & Đối soát

### Automated Tests
1. **Unit Test Drift & Sync Queue**:
   - Kiểm tra ghi SQLite và đọc lại: `LocalCustomers` và `SyncQueueEntries`.
   - Kiểm tra `recoverOrphanedSendingEntries()`: Đảm bảo khi app mở lại, mục `sending` mồ côi chuyển về `pending`.
   - Kiểm tra `removeDiacritics`: "Nguyễn Văn Linh" $\rightarrow$ "nguyen van linh". Tìm kiếm "nguyen" ra đúng "Nguyễn".
2. **Unit Test Thêm mới Offline**:
   - Test `customerRepository.createCustomer()` khi ngắt mạng:
     - Tạo `client_uuid` v4 duy nhất.
     - Dữ liệu lưu vào SQLite cục bộ và hàng đợi sync.
     - `getCustomers()` trả về khách hàng mới ngay cả khi offline.
3. **Flutter Analyze**:
   - `flutter analyze` đạt 0 lỗi, 0 cảnh báo.

### Manual Verification
- Bật chế độ Máy bay (Airplane Mode) trên thiết bị / máy ảo.
- Vào màn hình "Khách hàng" $\rightarrow$ Click "Thêm điểm bán mới".
- Điền thông tin và bấm "Lưu":
  - Điểm bán được lưu ngay lập tức.
  - Danh sách hiển thị điểm bán mới với badge "Chờ đồng bộ".
  - Tắt chế độ Máy bay (bật lại mạng): `SyncService` tự động gửi dữ liệu lên server và đổi trạng thái sang "Đã đồng bộ".

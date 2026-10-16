# SỔ TAY TRA CỨU MÃ LỖI HỆ THỐNG DMS VTHM (MOBILE & BACKEND)

> **Cập nhật mới nhất:** 15/10/2026  
> **Áp dụng cho:** Ứng dụng Mobile Flutter (`dms-app`), Backend API (`api-app.vthmgroup.vn`), Đội phát triển, Kiểm thử (QA/QC) và Đội ngũ Vận hành thị trường.

---

## MỤC LỤC
1. [Quy ước cấu trúc phản hồi lỗi API (Error Envelope)](#1-quy-ước-cấu-trúc-phản-hồi-lỗi-api-error-envelope)
2. [Bảng tra cứu nhanh theo Mã trạng thái HTTP (HTTP Status Codes)](#2-bảng-tra-cứu-nhanh-theo-mã-trạng-thái-http-http-status-codes)
3. [Bảng tra cứu theo Mã định danh lỗi (`code` string)](#3-bảng-tra-cứu-theo-mã-định-danh-lỗi-code-string)
4. [Bảng tra cứu chi tiết theo Phân hệ nghiệp vụ](#4-bảng-tra-cứu-chi-tiết-theo-phân-hệ-nghiệp-vụ)
   - [4.1 Đăng nhập & Phân quyền ứng dụng (Auth & Permissions)](#41-đăng-nhập--phân-quyền-ứng-dụng-auth--permissions)
   - [4.2 Tuyến & Viếng thăm điểm bán (Visit & Route)](#42-tuyến--viếng-thăm-điểm-bán-visit--route)
   - [4.3 Khách hàng & Điểm bán (Customer & Dynamic Form)](#43-khách-hàng--điểm-bán-customer--dynamic-form)
   - [4.4 Chấm công di động (Attendance)](#44-chấm-công-di-động-attendance)
   - [4.5 Khai báo vị trí công tác (Position Declaration)](#45-khai-báo-vị-trí-công-tác-position-declaration)
   - [4.6 Theo dõi vị trí nhân viên & GPS (Employee Tracking)](#46-theo-dõi-vị-trí-nhân-viên--gps-employee-tracking)
   - [4.7 Đồng bộ ngoại tuyến & Kết nối mạng (Offline Sync & Network)](#47-đồng-bộ-ngoại-tuyến--kết-nối-mạng-offline-sync--network)
5. [Ánh xạ Exception trong mã nguồn Flutter (Dart Exceptions)](#5-ánh-xạ-exception-trong-mã-nguồn-flutter-dart-exceptions)
6. [Nguyên tắc vàng khi xử lý lỗi trên ứng dụng di động](#6-nguyên-tắc-vàng-khi-xử-lý-lỗi-trên-ứng-dụng-di-động)

---

## 1. Quy ước cấu trúc phản hồi lỗi API (Error Envelope)

Mọi API của hệ thống DMS VTHM đều trả về cấu trúc phong bì JSON thống nhất:

### Thành công:
```json
{
  "success": true,
  "message": "Thao tác thành công.",
  "data": { ... }
}
```

### Lỗi nghiệp vụ hoặc dữ liệu không hợp lệ:
```json
{
  "success": false,
  "message": "Câu thông báo lỗi bằng tiếng Việt chuẩn để hiển thị cho người dùng.",
  "errors": {
    "customer_id": ["Khách hàng không tồn tại."],
    "lat": ["Lat không được để trống."]
  },
  "data": null,
  "code": "MÃ_LỖI_CHUẨN"
}
```

### Ý nghĩa các trường:
* **`success`**: `false` khi có lỗi.
* **`message`**: Chuỗi tiếng Việt mô tả nguyên nhân lỗi rõ ràng. Ứng dụng di động ưu tiên hiển thị câu này trực tiếp lên UI (SnackBar/Dialog).
* **`errors`**: Object chứa chi tiết các trường bị lỗi dữ liệu (validation), dùng để highlight/tô đỏ từng ô nhập liệu.
* **`code`**: Chuỗi định danh lỗi lập trình (ví dụ: `DMS_APP_FORBIDDEN`, `VALIDATION_ERROR`, `NOT_FOUND`). Dùng để phân nhánh logic nghiệp vụ (không dựa hoàn toàn vào chuỗi `message`).

---

## 2. Bảng tra cứu nhanh theo Mã trạng thái HTTP (HTTP Status Codes)

| Mã HTTP | Tên chuẩn | Khi nào xuất hiện | Hành vi ứng dụng Mobile |
| :---: | :--- | :--- | :--- |
| **`200 / 201`** | OK / Created | Thao tác thành công. Có thể kèm `duplicate: true` nếu bản ghi đã tồn tại qua `client_uuid`. | Cập nhật giao diện, ghi nhận thành công, loại khỏi hàng đợi offline. |
| **`400`** | Bad Request | Cú pháp request sai, JSON hỏng hoặc tham số không đúng kiểu. | Báo lỗi lập trình, kiểm tra lại payload gửi lên. |
| **`401`** | Unauthorized | Token hết hạn (`REFRESH_INVALID`), thiếu Bearer Token hoặc sai mật khẩu đăng nhập. | Thử gọi `POST /auth/refresh`. Nếu thất bại, xóa token và điều hướng về màn hình đăng nhập. |
| **`403`** | Forbidden | Bị chặn quyền: chưa cấp quyền dùng app DMS (`DMS_APP_FORBIDDEN`), hoặc thiếu vai trò thực hiện chức năng. | **Không thử lại**. Hiển thị câu thông báo server trả về, xóa phiên nếu bị thu hồi quyền app. |
| **`404`** | Not Found | Bản ghi không tồn tại **hoặc bản ghi thuộc về nhân viên khác** (quy tắc bảo mật). | **Không thử lại**. Xóa khỏi danh sách/bộ nhớ tạm. |
| **`422`** | Unprocessable Entity | Dữ liệu sai định dạng (Validate) hoặc **vi phạm luật nghiệp vụ** (chưa đủ 3 cổng, ngoài bán kính, còn lượt treo...). | Hiển thị thông báo tiếng Việt từ `message` cho nhân viên sửa lỗi thao tác. |
| **`500 / 502 / 503`** | Server Error | Lỗi nội bộ máy chủ, mất kết nối cơ sở dữ liệu hoặc gateway timeout. | **Không xóa bản ghi**. Đưa vào hàng đợi ngoại tuyến (Offline Sync Queue) để tự động thử lại sau. |

---

## 3. Bảng tra cứu theo Mã định danh lỗi (`code` string)

| Mã lỗi (`code`) | HTTP | Ý nghĩa | Cách xử lý trên Mobile |
| :--- | :---: | :--- | :--- |
| **`DMS_APP_FORBIDDEN`** | `403` | Tài khoản chưa được cấp quyền sử dụng ứng dụng di động DMS (thiếu quyền `/dms/app-access/index`). | Hiển thị nguyên văn: *"Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý."*. Không báo "Sai mật khẩu". Xóa token lưu cục bộ. |
| **`REFRESH_INVALID`** | `401` | Refresh token không hợp lệ, đã hết hạn hoặc đã bị thu hồi. | Xóa toàn bộ token và phiên đăng nhập, đưa người dùng về màn hình Login. |
| **`VALIDATION_ERROR`** | `422` | Vi phạm ràng buộc dữ liệu đầu vào (thiếu tọa độ, thiếu client_uuid, sai kiểu...). | Parse object `errors`, tô đỏ trường tương ứng và hiển thị `message`. |
| **`NOT_FOUND`** | `404` | Không tìm thấy lượt viếng thăm, lượt chấm công, khách hàng hoặc ảnh tương ứng. | Thông báo dữ liệu không tồn tại hoặc đã bị gỡ bỏ, không retry tự động. |
| **`LOCATION_RULE`** | `422` | Quy tắc vị trí bị chặn (ngoài giờ theo dõi, tính năng vị trí bị tắt trên server). | Tạm dừng chu kỳ ping vị trí định kỳ, chờ cấu hình mới từ máy chủ. |
| **`LOCATION_PERMISSION_DENIED`** | `403` | Không có quyền gửi tọa độ nhân viên lên `/dms/location/ping`. | Dừng dịch vụ background tracking, ghi log cảnh báo. |

---

## 4. Bảng tra cứu chi tiết theo Phân hệ nghiệp vụ

### 4.1 Đăng nhập & Phân quyền ứng dụng (Auth & Permissions)
*Quy chuẩn từ ngày 15/10/2026: Mobile PHẢI luôn gửi header `X-Client: dms-app`.*

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Hành vi App |
| :--- | :---: | :--- | :--- |
| **Chưa cấp quyền App** | `403` | `Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.` | `code = DMS_APP_FORBIDDEN`. Mật khẩu đúng nhưng không cấp token. Ở lại màn đăng nhập, hiện thông báo server. |
| **Bị thu quyền khi đang dùng** | `403` | `Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.` | Xảy ra khi gọi `POST /auth/refresh`. Server đã hủy token. App xóa token, logout về màn đăng nhập. |
| **Hỏi quyền lúc mở app** | `403` | `Bạn không có quyền thực hiện thao tác này.` | Gọi `GET /dms/app-access`. Nếu nhận 403: logout và hiện câu thông báo yêu cầu liên hệ quản lý. Nếu mất mạng: giữ phiên làm việc offline. |
| **Sai mật khẩu / tài khoản** | `401` | `Tên đăng nhập hoặc mật khẩu không chính xác.` | Nhập sai credentials. Cho phép người dùng thử lại. |
| **Phiên hết hạn thông thường** | `401` | `Phiên làm việc hết hạn.` | Tự động dùng `refresh_token` để lấy cặp token mới. |

---

### 4.2 Tuyến & Viếng thăm điểm bán (Visit & Route)
*Cập nhật 15/10/2026: Đã bỏ luật "ghé 1 lần/ngày", bỏ cron đóng hộ 21h, bổ sung cờ "Ra khác ngày".*

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Giải pháp |
| :--- | :---: | :--- | :--- |
| **Còn lượt treo chưa đóng** | `422` | `Bạn còn một lượt viếng thăm chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới.` | Vi phạm Luật ③. Không còn cron tự đóng. App điều hướng thẳng tới lượt đang mở, cung cấp nút **Check-out** hoặc **Hủy lượt**. |
| **Đứng ngoài bán kính (Geofence)** | `422` | `Bạn đang đứng cách điểm bán 120m (vượt bán kính cho phép 50m).` | Nhân viên đứng xa điểm bán. Yêu cầu bật GPS độ chính xác cao, đến đúng điểm hoặc gửi yêu cầu cập nhật tọa độ. |
| **Chưa đủ thời gian tối thiểu** | `422` | `Bạn cần ở lại thêm 5 phút nữa mới check-out được.` | Cổng 1 check-out: Thời gian ở lại chưa đạt cấu hình (thường là 5–15 phút). App hiển thị đồng hồ đếm ngược. |
| **Chưa nộp phiếu khảo sát** | `422` | `Chưa nộp biểu mẫu khảo sát bắt buộc: [Tên biểu mẫu].` | Cổng 2 check-out: Chưa hoàn thành biểu mẫu thị trường được gắn kèm tuyến. Bấm vào để mở form khảo sát. |
| **Chưa đủ số ảnh check-out** | `422` | `Bạn cần chụp thêm 2 ảnh nữa.` | Cổng 3 check-out: Chưa chụp đủ số ảnh tối thiểu tại điểm bán. Mở camera chụp bổ sung. |
| **Check-out lượt đã đóng** | `422` | `Lượt viếng thăm này đã check-out rồi.` | Khi xả hàng đợi offline gửi lại lệnh check-out cũ. App coi đây là **Thành công** và hoàn tất đồng bộ. |
| **Thao tác trên lượt đã hủy** | `422` | `Lượt viếng thăm này đã bị huỷ, không check-out được.` / `...không nhận thêm ảnh được.` | Nhân viên đã bấm hủy lượt trước đó. Hủy các tác vụ ngầm liên quan đến lượt này. |
| **Giả lập tọa độ (Mock GPS)** | `422` | `Máy đang bật phần mềm giả lập vị trí. Vui lòng tắt để tiếp tục.` | Thiết bị bật Fake GPS. Chỉ chặn nếu admin cấu hình bật luật chặn giả lập. |

---

### 4.3 Khách hàng & Điểm bán (Customer & Dynamic Form)

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Giải pháp |
| :--- | :---: | :--- | :--- |
| **Thiếu tên điểm bán** | `422` | `Tên điểm bán là bắt buộc.` | Trường `name` bị để trống. |
| **Thiếu khu vực quản lý** | `422` | `Vui lòng chọn khu vực quản lý (Region).` | Trường `region_id` chưa được chọn. |
| **Thiếu tọa độ GPS** | `422` | `Toạ độ không được để trống.` | Chưa chọn vị trí trên bản đồ hoặc chưa lấy được GPS thiết bị. |
| **Ảnh vượt quá dung lượng** | `422` | `Tệp "x.jpg" (11265 KB) vượt mức tối đa 10240 KB.` | Ảnh chụp gốc quá lớn (> 10MB). App tự động nén ảnh JPEG chất lượng 80-85% trước khi upload. |
| **Sai định dạng tệp ảnh** | `422` | `Định dạng tệp không được hỗ trợ. Chỉ chấp nhận ảnh JPG, PNG, WEBP.` | Chọn nhầm tệp văn bản/PDF hoặc ảnh định dạng lạ. |
| **Điểm bán không tồn tại / Không thuộc quyền** | `404` | `Không tìm thấy điểm bán.` | Điểm bán đã bị xóa hoặc thuộc quyền quản lý của nhân viên khác. |

---

### 4.4 Chấm công di động (Attendance)

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Giải pháp |
| :--- | :---: | :--- | :--- |
| **Chưa khai báo địa điểm** | `422` | `Chưa khai địa điểm chấm công nào — liên hệ nhân sự trước khi chấm công bằng app.` | Tài khoản chưa được cấu hình văn phòng/điểm chấm công trên web One. |
| **Ngoài bán kính chấm công** | `422` | `Bạn đang đứng ngoài bán kính địa điểm chấm công cho phép.` | Nhân viên đứng xa văn phòng/kho hơn bán kính geofence quy định. |
| **Vượt trần số lượng ảnh** | `422` | `Lượt chấm này đã có tối đa 10 ảnh.` | Mỗi lượt chấm công chỉ được đính kèm tối đa 10 ảnh bằng chứng. |
| **Trùng giây quẹt thẻ** | `200` | *(Trả về bản ghi đang chiếm giây đó + `duplicate: true`)* | Không phải lỗi! Nhiều lượt gửi lên cùng 1 giây. App lấy `id` trả về để gán ảnh. |
| **Lượt chấm không tồn tại** | `404` | `Không tìm thấy lượt quẹt.` | `code = NOT_FOUND`. Tải ảnh vào một ID không có thực hoặc không thuộc về mình. |

---

### 4.5 Khai báo vị trí công tác (Position Declaration)

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Giải pháp |
| :--- | :---: | :--- | :--- |
| **Lý do công tác bị tắt** | `422` | `Lý do "X" đã ngừng sử dụng. Hãy chọn lý do khác.` | Quản trị viên vừa tắt lý do này trên danh mục One. App giữ lại tọa độ + ảnh, yêu cầu người dùng chọn lý do mới. |
| **Chưa đủ số ảnh tối thiểu** | `422` | `Bạn cần chụp thêm 1 ảnh trước khi gửi khai báo.` | Chưa đạt số ảnh tối thiểu theo cấu hình danh mục. |
| **Token ảnh không hợp lệ** | `422` | `Trường photo_tokens phải chứa mã tệp lấy từ cửa tải ảnh lên.` | Mã token ảnh tải lên bị sai lệch hoặc không phải chuỗi hex 32 ký tự. |
| **Token ảnh bị dọn rác** | `422` | *(Bị server bỏ qua im lặng và báo thiếu ảnh)* | Token ảnh tải lên quá lâu chưa nộp phiếu nên bị cron dọn dẹp. App yêu cầu chụp lại ảnh. |

---

### 4.6 Theo dõi vị trí nhân viên & GPS (Employee Tracking)

| Mã / Tình huống | HTTP | `message` thực tế | Nguyên nhân & Giải pháp |
| :--- | :---: | :--- | :--- |
| **Chưa bật tính năng vị trí** | `422` | `Tính năng giám sát vị trí chưa được kích hoạt.` | `code = LOCATION_RULE`. Server đang tắt công tắc `dms.location_enabled`. App ngừng gửi ping định kỳ. |
| **Thiếu quyền theo dõi** | `403` | `Tài khoản không có quyền theo dõi vị trí.` | `LocationPermissionDeniedException`. Tài khoản không được phân quyền giám sát. |
| **Lệnh yêu cầu hết hạn** | — | `status = expired` | Lệnh yêu cầu vị trí tức thời từ quản lý đã quá thời hạn phản hồi (TTL 10 phút). |

---

### 4.7 Đồng bộ ngoại tuyến & Kết nối mạng (Offline Sync & Network)

| Tình huống ngoại lệ | Mã lỗi Mobile | Bản chất kỹ thuật | Xử lý an toàn dữ liệu |
| :--- | :--- | :--- | :--- |
| **Mất kết nối Internet** | `NetworkException` | `SocketException`, `HttpException`, không có tín hiệu mạng di động / Wi-Fi. | Lưu bản ghi vào SQLite (`sync_queue`), kích hoạt lắng nghe mạng để gửi lại khi online. **Tuyệt đối không logout**. |
| **Hết thời gian chờ (Timeout)** | `NetworkException` | `connectTimeout` (15s) hoặc `receiveTimeout` (15s) bị vượt quá do mạng yếu. | Giữ nguyên dữ liệu trong hàng đợi, tự động thử lại ở chu kỳ đồng bộ tiếp theo. |
| **Lỗi bộ nhớ cục bộ** | `CacheException` | Lỗi đọc/ghi SharedPreferences hoặc cơ sở dữ liệu Drift SQLite. | Ghi log cục bộ, giải phóng vùng nhớ hoặc khởi tạo lại bảng dữ liệu an toàn. |

---

## 5. Ánh xạ Exception trong mã nguồn Flutter (Dart Exceptions)

Trong thư mục [`lib/core/errors/app_exceptions.dart`](file:///c:/DMS_VTHM/dms-app/lib/core/errors/app_exceptions.dart):

```dart
// 1. Ngoại lệ gốc của ứng dụng
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
}

// 2. Lỗi bị cấm truy cập ứng dụng DMS (HTTP 403 DMS_APP_FORBIDDEN)
class DmsAppForbiddenException extends AppException {
  const DmsAppForbiddenException([
    String message = 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
  ]) : super(message, 403, 'DMS_APP_FORBIDDEN');
}

// 3. Lỗi mạng / mất kết nối (Không bao giờ văng session)
class NetworkException extends AppException {
  const NetworkException([String message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.'])
      : super(message, null);
}

// 4. Lỗi máy chủ / lỗi nghiệp vụ từ backend
class ServerException extends AppException {
  const ServerException([
    super.message = 'Lỗi máy chủ. Vui lòng thử lại sau.',
    super.statusCode,
    super.code,
  ]);
}

// 5. Lỗi hết hạn phiên đăng nhập thông thường (HTTP 401)
class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Phiên đăng nhập đã hết hạn.'])
      : super(message, 401);
}

// 6. Lỗi truy xuất cache / offline database
class CacheException extends AppException {
  const CacheException([String message = 'Lỗi truy xuất bộ nhớ cục bộ.'])
      : super(message, null);
}
```

---

## 6. Nguyên tắc vàng khi xử lý lỗi trên ứng dụng di động

1. **Nguyên tắc "Offline-First" (Ngoại tuyến là trên hết):**
   * Lỗi mất mạng (`NetworkException`) hoặc lỗi kết nối máy chủ **KHÔNG ĐƯỢC PHÉP** làm người dùng bị văng khỏi app hoặc mất dữ liệu vừa nhập.
   * Dữ liệu chưa gửi được phải được lưu an toàn vào hàng đợi ngoại tuyến SQLite với `client_uuid`.

2. **Nguyên tắc Idempotent khi dọn hàng đợi:**
   * Mọi bản ghi tạo mới (check-in, chấm công, nộp biểu mẫu) phải gắn kèm `client_uuid` duy nhất (UUID v4).
   * Khi gửi lại bản ghi mà server trả về `duplicate: true`, `422 "đã check-out rồi"` hoặc `404 "đã xoá"` ➔ **Coi là THÀNH CÔNG** và dọn khỏi hàng đợi.

3. **Nguyên tắc bảo mật thông tin (Không suy diễn từ 404):**
   * Máy chủ cố ý trả `404 Not Found` cho cả trường hợp "bản ghi không tồn tại" và "bản ghi thuộc về người khác".
   * Ứng dụng không được hiển thị suy đoán như *"Bản ghi thuộc người khác"*, chỉ thông báo dữ liệu không tìm thấy.

4. **Hiển thị thông báo thân thiện (User-Friendly UI):**
   * Ưu tiên hiển thị thông điệp bằng tiếng Việt có sẵn từ trường `message` của server.
   * Khi gặp lỗi 403 `DMS_APP_FORBIDDEN`: Hiển thị rõ ràng là do **chưa được cấp quyền sử dụng app**, tuyệt đối không báo nhầm thành "Sai mật khẩu".

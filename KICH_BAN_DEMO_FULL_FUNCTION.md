# KỊCH BẢN HƯỚNG DẪN DEMO TOÀN DIỆN ỨNG DỤNG DMS VTHM MOBILE
## Kịch Bản Trình Diễn Full Chức Năng (End-to-End Live Demo Script)

---

> [!IMPORTANT]
> **Tài liệu này được thiết kế dành cho:**
> - Trưởng nhóm kỹ thuật, Solution Architect hoặc Product Owner khi trình diễn trực tiếp (Live Demo / Pitching) cho Ban Lãnh Đạo, Đối tác và Khách hàng.
> - Đội ngũ Đào tạo (Trainer / Giám sát bán hàng) hướng dẫn thực hành cho đội ngũ nhân viên kinh doanh thực địa (Sales Rep / DSR).
> - Đội ngũ QA / Tester thực hiện kiểm thử quy trình nghiệp vụ tổng thể (End-to-End Acceptance Testing).

---

## MỤC LỤC KỊCH BẢN DEMO

1. [Chuẩn Bị Môi Trường & Thiết Bị Trước Buổi Demo](#1-chuẩn-bị-môi-trường--thiết-bị-trước-buổi-demo)
2. [Lộ Trình Buổi Demo (Tổng Quan 45 Phút)](#2-lộ-trình-buổi-demo-tổng-quan-45-phút)
3. [Màn 1: Đăng Nhập, Tải Dữ Liệu & Giao Diện Tổng Quan (5 Phút)](#màn-1-đăng-nhập-tải-dữ-liệu--giao-diện-tổng-quan-5-phút)
4. [Màn 2: Chấm Công Vào Ca & Cơ Chế Chống Gian Lận (5 Phút)](#màn-2-chấm-công-vào-ca--cơ-chế-chống-gian-lận-5-phút)
5. [Màn 3: Tuyến Bán Hàng & Bản Đồ Thực Địa Goong Map (7 Phút)](#màn-3-tuyến-bán-hàng--bản-đồ-thực-địa-goong-map-7-phút)
6. [Màn 4: Quy Trình Viếng Thăm Điểm Bán Chuẩn 6 Bước (8 Phút)](#màn-4-quy-trình-viếng-thăm-điểm-bán-chuẩn-6-bước-8-phút)
7. [Màn 5: "Sát Thủ" Offline-First – Tác Nghiệp Khi Mất Mạng Hoàn Toàn (5 Phút)](#màn-5-sát-thủ-offline-first--tác-nghiệp-khi-mất-mạng-hoàn-toàn-5-phút)
8. [Màn 6: Biểu Mẫu Thị Trường & Chụp Ảnh Token Mới (4 Phút)](#màn-6-biểu-mẫu-thị-trường--chụp-ảnh-token-mới-4-phút)
9. [Màn 7: Thêm Mới Điểm Bán & Khai Báo Vị Trí Sự Cố (4 Phút)](#màn-7-thêm-mới-điểm-bán--khai-báo-vị-trí-sự-cố-4-phút)
10. [Màn 8: Báo Cáo Ngày, Quãng Đường & Chấm Công Ra Ca (5 Phút)](#màn-8-báo-cáo-ngày-quãng-đường--chấm-công-ra-ca-5-phút)
11. [Bảng Tổng Hợp Thông Số Kỹ Thuật Đáng Chú Ý](#11-bảng-tổng-hợp-thông-số-kỹ-thuật-đáng-chú-ý)
12. [Bộ Câu Hỏi & Trả Lời Khi Thuyết Trình (Demo Q&A)](#12-bộ-câu-hỏi--trả-lời-khi-thuyết-trình-demo-qa)

---

## 1. CHUẨN BỊ MÔI TRƯỜNG & THIẾT BỊ TRƯỚC BUỔI DEMO

### 1.1. Thiết bị & Công cụ trình chiếu
* **Điện thoại Demo:** 01 điện thoại Android (Android 10+) hoặc iPhone (iOS 15+) đã cài đặt bản build mới nhất của ứng dụng DMS VTHM.
* **Màn hình phản chiếu (Screen Mirroring):** Dùng phần mềm `scrcpy` (Android) hoặc `AirPlay / QuickTime Player` (iOS) để chiếu màn hình điện thoại lên máy chiếu / màn hình TV lớn.
* **Cấp quyền sẵn:** Mở app trước 1 lần để cấp quyền Vị trí (GPS chính xác), Máy ảnh (Camera), Thông báo (Notification).

### 1.2. Dữ liệu tài khoản Demo
* **Tài khoản nhân viên thị trường:** `TEST001` (hoặc tài khoản thật được cấp quyền trong phân hệ DMS).
* **Mật khẩu:** Theo tài khoản được cấp.
* **Môi trường API:** `https://api-app.vthmgroup.vn`

### 1.3. Chuẩn bị sẵn sàng các "Đạo cụ" kịch bản
1. **Một tấm bìa sản phẩm / quầy hàng mẫu** để hướng camera chụp ảnh quầy kệ thực tế.
2. **Kỹ thuật bật/tắt Chế độ Máy bay (Airplane Mode):** Rèn luyện thao tác vuốt Control Center nhanh để ngắt mạng tạo bất ngờ cho khán giả ở Màn 5.
3. **Ứng dụng Giả lập vị trí (Fake GPS / Mock Location)** cài sẵn trên máy phụ (nếu muốn biểu diễn cơ chế chặn gian lận tự động của app).

---

## 2. LỘ TRÌNH BUỔI DEMO (TỔNG QUAN 45 PHÚT)

```mermaid
journey
    title HÀNH TRÌNH 1 NGÀY LÀM VIỆC CỦA NHÂN VIÊN THỊ TRƯỜNG VTHM
    section Đầu ngày (08:00)
      Đăng nhập & Đồng bộ dữ liệu: 5: Người thuyết trình
      Chấm công Vào ca + 2 ảnh Watermark: 5: Người thuyết trình
      Xem Tuyến & Bản đồ Goong Map: 5: Người thuyết trình
    section Giữa ngày (Thực địa)
      Ghé thăm điểm bán 1 (Check-in, Khảo sát, Check-out): 8: Người thuyết trình
      Bật Airplane Mode (Tác nghiệp Offline 100%): 5: Người thuyết trình
      Điền biểu mẫu thị trường (Chụp ảnh token mới): 4: Người thuyết trình
      Khai báo vị trí & Thêm điểm bán mới: 4: Người thuyết trình
    section Cuối ngày (17:00)
      Xem Báo cáo hoạt động & Quãng đường di chuyển: 4: Người thuyết trình
      Chấm công Ra ca & Kết thúc ngày làm việc: 3: Người thuyết trình
      Hỏi đáp (Q&A): 5: Khán giả
```

---

## MÀN 1: ĐĂNG NHẬP, TẢI DỮ LIỆU & GIAO DIỆN TỔNG QUAN (5 Phút)

### Mục tiêu màn 1
> Chứng minh tốc độ khởi động, khả năng duy trì phiên bảo mật lâu dài (90 ngày) và sự chuyên nghiệp, trực quan của giao diện người dùng theo chuẩn Material Design 3.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Mở ứng dụng DMS VTHM từ màn hình chính.     "Kính thưa quý vị, xin chào mừng đến với buổi
                                              trình diễn thực tế ứng dụng DMS VTHM Mobile.
                                              Ứng dụng được xây dựng trên nền tảng Flutter
                                              hiện đại, tối ưu hoá cho cả Android và iOS."

2. Hiển thị màn hình Splash và chuyển         "Ngay khi mở ứng dụng, phiên làm việc được bảo vệ
   ngay vào màn hình chính (nếu đã lưu        bằng Access Token an toàn, có khả năng duy trì
   phiên) hoặc màn hình Đăng nhập.             phiên đăng nhập lên tới 90 ngày. Nhân viên không
                                              cần phải đăng nhập lại mỗi buổi sáng."

3. Tại màn hình Đăng nhập:                   "Chúng ta sẽ đăng nhập với tài khoản nhân viên
   - Nhập Mã NV: TEST001                      thị trường TEST001. Hệ thống lập tức tải dữ liệu
   - Nhập Mật khẩu                            cấu hình, phân quyền, danh mục tuyến bán hàng
   - Bấm [ĐĂNG NHẬP]                          và các quy tắc vận hành cục bộ."

4. Dừng tại Màn hình Trang chủ:               "Giao diện Trang chủ được thiết kế tập trung vào
   - Chỉ vào Top Bar (Huy hiệu đồng bộ)       hiệu suất công việc với 3 khu vực chính:
   - Chỉ vào 3 Thao tác nhanh (Quick Actions)  1. Thanh tiêu đề trên cùng: hiển thị Trạng thái
   - Chỉ vào Thẻ tóm tắt Chấm công            kết nối mạng và Huy hiệu đồng bộ dữ liệu.
   - Chỉ vào Bottom Bar (5 Tab)                2. Thẻ Chấm công & Lộ trình trọng tâm trong ngày.
                                              3. Thanh điều hướng 5 tab: Trang chủ, Tuyến hàng,
                                              Khách hàng, Báo cáo và Cá nhân."

5. Chạm vào biểu tượng Avatar góc phải:        "Ứng dụng hỗ trợ đầy đủ Chế độ Tối (Dark Mode)
   - Bật chuyển Dark Mode                     giúp nhân viên đỡ mỏi mắt khi di chuyển ngoài
   - Chuyển lại Light Mode                    nắng gắt và tiết kiệm pin tối đa cho thiết bị."
```

---

## MÀN 2: CHẤM CÔNG VÀO CA & CƠ CHẾ CHỐNG GIAN LẬN (5 Phút)

### Mục tiêu màn 2
> Biểu diễn quy trình chấm công GPS nghiêm ngặt: Kiểm tra vùng địa lý (Geofence), chặn ứng dụng Fake GPS, bắt buộc chụp 2 ảnh bằng camera thực tế có Watermark bản quyền.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Từ Trang chủ, chạm vào nút [CHẤM CÔNG]      "Bước đầu tiên mỗi sáng của một nhân viên thị
   trên Quick Actions hoặc thẻ Chấm công.      trường là Chấm công Vào ca. Khung giờ chuẩn của
                                              chúng ta là từ 08:00 sáng đến 17:00 chiều."

2. Màn hình Chấm công xuất hiện:              "Ứng dụng tự động kích hoạt GPS độ chính xác cao.
   - GPS định vị và tính khoảng cách           Quý vị có thể thấy trên màn hình:
   - Hiển thị tên địa điểm chấm công           - Hệ thống tự động so khớp tọa độ của tôi với địa
   - Bán kính Geofence (ví dụ: cách 25m)      điểm văn phòng / chi nhánh gần nhất.
   - Trạng thái: Hợp lệ (Xanh lá)             - Nút Chấm công hiển thị trạng thái 'VÀO CA'."

3. Tình huống chống gian lận (Nhấn mạnh):     "Đặc biệt, phân hệ AntiFraudService của chúng tôi
   - Giải thích tính năng chặn Mock GPS        được tích hợp ở mức nhân hệ thống:
   - Giải thích tính năng khoá chỉnh đồng hồ   - Nếu nhân viên bật ứng dụng Giả lập vị trí
                                              (Fake GPS), hệ thống sẽ lập tức chặn đứng thao tác.
                                              - Nếu nhân viên chỉnh lùi đồng hồ điện thoại để
                                              tránh bị tính đi muộn, server sẽ từ chối ghi nhận."

4. Bấm nút [CHẤM CÔNG VÀO CA]:                 "Khi bấm chấm công, quy trình xác thực hình ảnh
   - Dialog yêu cầu ảnh xuất hiện              kép bắt buộc được kích hoạt. Nhân viên KHÔNG THỂ
   - Bước 1: Mở camera chụp ảnh Chân dung     chọn ảnh từ album điện thoại, mà bắt buộc chụp trực
   - Bấm [CHỤP ẢNH CHÂN DUNG]                  tiếp tại hiện trường:
   - Hướng camera chụp selfie                  - Tấm thứ nhất: Ảnh chân dung selfie của nhân viên."

5. Chuyển sang Bước 2:                         "- Tấm thứ hai: Ảnh khung cảnh văn phòng / môi trường
   - Bấm [CHỤP ẢNH KHUNG CẢNH]                 làm việc xung quanh."
   - Hướng camera chụp khung cảnh xung quanh

6. Màn hình xử lý và hoàn tất:                 "Ngay khi chụp xong, hệ thống tự động:
   - Tiến trình 3 bước đẩy dữ liệu             1. Đóng dấu Watermark không thể tẩy xoá: Toạ độ GPS,
   - Thông báo: 'Đã ghi nhận chấm công          Thời gian thực tế, Tên địa điểm và Logo công ty.
     lúc 08:02'                                2. Đẩy lượt chấm và tải ảnh lên máy chủ.
                                               3. Cập nhật ngay dòng trạng thái 'Đang trong ca làm việc'."
```

---

## MÀN 3: TUYẾN BÁN HÀNG & BẢN ĐỒ THỰC ĐỊA GOONG MAP (7 Phút)

### Mục tiêu màn 3
> Giới thiệu tuyến bán hàng (MCP - Master Coverage Plan), trực quan hoá danh sách điểm bán trên bản đồ Goong Map với tính toán khoảng cách thời gian thực.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Chạm vào Tab 2 [TUYẾN BÁN HÀNG] trên        "Sau khi vào ca, nhân viên chuyển sang Tab Tuyến
   thanh điều hướng dưới đáy.                  để bắt đầu hành trình di chuyển trong ngày.
                                              Đây là toàn bộ danh sách điểm bán (Master Coverage
                                              Plan - MCP) được quản lý phân công hôm nay."

2. Thao tác trên Chế độ Danh sách:             "Danh sách được thiết kế cực kỳ thông minh:
   - Vuốt xem các thẻ điểm bán                 - Mỗi thẻ thể hiện: Tên cửa hàng, Mã khách hàng,
   - Chỉ vào khoảng cách: 'Cách 120m'          Địa chỉ chi tiết, Tên chủ tiệm và Số điện thoại.
   - Thử thanh tìm kiếm: gõ 'tạp hoá'         - Khoảng cách từ vị trí nhân viên tới từng cửa
   - Thử bộ lọc trạng thái: 'Chưa ghé',        hàng được tính toán trực tiếp theo thời gian thực.
     'Đã hoàn thành'                           - Tính năng tìm kiếm không dấu hỗ trợ cả Unicode tổ hợp,
                                              giúp tìm đại lý cực nhanh chỉ trong vài mili-giây."

3. Bấm nút chuyển sang [BẢN ĐỒ] (Góc trên):    "Bên cạnh danh sách, nhân viên có thể chuyển sang
   - Bản đồ Goong Map tải lên                  Chế độ Bản đồ số Goong Map chuyên nghiệp.
   - Các ghim (Marker) hiển thị trực quan      Goong Map sử dụng dữ liệu bản đồ chi tiết của
   - Vị trí hiện tại của nhân viên (chấm xanh)  Việt Nam, hiển thị rõ ràng từng số nhà, ngõ ngách."

4. Phân tích màu sắc các Marker trên bản đồ:   "Hệ thống trực quan hoá trạng thái bằng màu sắc:
   - Marker Xám: Điểm bán chưa ghé             - Màu xám: Điểm bán chưa viếng thăm.
   - Marker Xanh lá: Điểm bán đã hoàn thành    - Màu xanh lá: Điểm bán đã viếng thăm thành công.
   - Marker Cam/Đỏ: Điểm bán đóng cửa          - Màu cam: Điểm bán đóng cửa hoặc có sự cố.
                                               Nhân viên dễ dàng hình dung lộ trình đi theo đường
                                               ngắn nhất, không bị đi vòng lãng phí xăng xe."

5. Chạm vào 1 Marker trên bản đồ:              "Khi chạm vào bất kỳ ghim nào, thẻ thông tin thu nhỏ
   - Xuất hiện Bottom Sheet xem nhanh          lập tức mở ra với đầy đủ thông tin tóm tắt và
   - Bấm nút [CHỈ ĐƯỜNG]                       nút bấm mở Google Maps / Apple Maps để điều hướng
                                               bằng giọng nói nếu nhân viên đi đường chưa quen."
```

---

## MÀN 4: QUY TRÌNH VIẾNG THĂM ĐIỂM BÁN CHUẨN 6 BƯỚC (8 Phút)

### Mục tiêu màn 4
> Trình diễn "trái tim" của ứng dụng: Quy trình 6 bước tại cửa hàng (Check-in GPS -> Chụp ảnh trưng bày -> Khảo sát biểu mẫu -> Kiểm tra điều kiện -> Check-out đóng lượt).

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Từ danh sách, chọn điểm bán đầu tiên        "Bây giờ chúng ta cùng theo chân nhân viên bước
   (ví dụ: 'Đại lý Bánh Kẹo Hùng Mai')         vào cửa hàng đầu tiên: 'Đại lý Hùng Mai'.
   Bấm nút [BẮT ĐẦU VIẾNG THĂM].               Tôi bấm Bắt đầu viếng thăm."

2. BƯỚC 1: XÁC THỰC CHECK-IN GPS               "Hệ thống kiểm tra hàng rào địa lý Geofence:
   - Ứng dụng đo khoảng cách                   - Nếu nhân viên đứng cách cửa hàng dưới bán kính
   - Nếu ở gần: Vào thẳng màn Check-in         cho phép (ví dụ 100m), app cho phép Check-in ngay.
   - (Mẹo: Nếu demo trong phòng họp,            - Nếu nhân viên đứng quá xa, app hiển thị cảnh báo
     chọn điểm bán có toạ độ gần đó hoặc       và yêu cầu giải trình lý do viếng thăm ngoài vùng."
     hệ thống tự tính khoảng cách).

3. Màn hình Chi tiết phiên viếng thăm mở ra:   "Ngay khi Check-in thành công:
   - Đồng hồ bấm giờ thời gian thực chạy       - Đồng hồ thời gian bắt đầu tính từng giây, đảm
   - Hiển thị 4 nhiệm vụ cần hoàn thành       bảo nhân viên ở lại điểm bán đủ thời gian quy định
                                               (ví dụ: tối thiểu 10 phút/cửa hàng).
                                               - Màn hình hiển thị rõ ràng danh sách việc cần làm."

4. BƯỚC 2: CHỤP ẢNH MẶT TIỀN / QUẦY KỆ         "Việc đầu tiên: Chụp ảnh chứng minh hiện diện.
   - Bấm vào mục [Chụp ảnh viếng thăm]         Tôi bấm chụp ảnh biển hiệu cửa hàng.
   - Camera kích hoạt                          Camera bật lên, tôi chụp tấm biển hiệu."
   - Chụp một vật phẩm làm mẫu
   - Màn hình xem lại ảnh hiện ra:             "Quý vị hãy quan sát góc dưới ảnh:
     * Góc dưới có chữ đóng dấu toạ độ         Hệ thống tự động in chìm toạ độ GPS, ngày giờ chụp,
     * Địa chỉ cửa hàng & Logo VTHM             tên điểm bán và logo thương hiệu VTHM.
     * Bấm [LƯU ẢNH]                           Bức ảnh này là bằng chứng không thể chối cãi, bảo vệ
                                               sự minh bạch của nhân viên với giám sát."

5. BƯỚC 3: ĐIỀN BIỂU MẪU KHẢO SÁT              "Việc thứ hai: Thực hiện khảo sát quầy kệ và tồn kho.
   - Chạm vào [Khảo sát trưng bày & Tồn kho]   Mẫu khảo sát động mở ra với các trường thông tin:
   - Nhập số lượng mặt hàng tồn kho            - Số lượng khay kệ trưng bày: tôi nhập '3'.
   - Chọn đánh giá đối thủ cạnh tranh         - Có sản phẩm đối thủ không: chọn 'Có'.
   - Bấm [LƯU KẾT QUẢ KHẢO SÁT]                Dữ liệu được lưu ngay vào bộ nhớ máy."

6. BƯỚC 4 & 5: CHECK-OUT ĐÓNG LƯỢT VIẾNG THĂM   "Sau khi trao đổi với chủ tiệm xong, nhân viên bấm
   - Bấm nút [KẾT THÚC VIẾNG THĂM]             [KẾT THÚC VIẾNG THĂM].
   - Dialog chọn: 'Cửa hàng Mở cửa'            Hệ thống hỏi trạng thái: 'Cửa hàng mở cửa' hay 'Đóng cửa'.
   - Xác nhận hoàn tất                         Tôi chọn 'Mở cửa bình thường'.
                                               Một bản ghi Check-out được đóng gói kèm thời lượng viếng
                                               thăm chính xác đến từng giây (ví dụ: 12 phút 45 giây)."

7. Quay lại danh sách Tuyến:                   "Quay lại màn hình Tuyến, quý vị thấy ngay:
   - Thẻ điểm bán chuyển sang icon Xanh lá     Điểm bán 'Đại lý Hùng Mai' đã chuyển sang trạng thái
   - Trạng thái: 'Đã hoàn thành'               'Đã hoàn thành' với dấu tích xanh đầy thỏa mãn!"
```

---

## MÀN 5: "SÁT THỦ" OFFLINE-FIRST – TÁC NGHIỆP KHI MẤT MẠNG HOÀN TOÀN (5 Phút)

### Mục tiêu màn 5 (ĐIỂM NHẤN WOW NHẤT BUỔI DEMO)
> Chứng minh kiến trúc Offline-First tuyệt đối: Cắt hoàn toàn mạng Internet (Wifi + 4G), app vẫn chạy mượt mà, lưu vào SQLite cục bộ và tự động đồng bộ bù ngay khi có sóng trở lại.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. VUỐT XUỐNG BẬT CHẾ ĐỘ MÁY BAY:              "Thưa quý vị, nhân viên thị trường thường xuyên
   - Tắt hoàn toàn Wifi & Dữ liệu di động      phải vào các ngõ sâu, tầng hầm siêu thị, hoặc đi
   - Biểu tượng Máy bay ✈️ hiện trên máy       các vùng huyện hẻo lánh không hề có sóng 3G/4G.
                                               Tôi sẽ bật Chế độ Máy bay – ngắt hoàn toàn Internet!"

2. Chỉ vào màn hình ứng dụng:                  "Quý vị chú ý:
   - Banner cảnh báo ngoại tuyến hiện nhẹ      - Thanh tiêu đề lập tức báo trạng thái 'Ngoại tuyến'.
   - App hoàn toàn KHÔNG bị đơ, không văng     - Nhưng toàn bộ dữ liệu, danh sách tuyến, lịch sử
   - Không xuất hiện vòng quay tải vô tận      đều đang nằm sẵn trong bộ nhớ đệm SQLite trên máy."

3. Thực hiện viếng thăm điểm bán thứ 2         "Bây giờ trong tình trạng KHÔNG CÓ MẠNG, tôi vẫn:
   trong trạng thái Offline:                   1. Bấm mở điểm bán thứ hai.
   - Bấm Check-in điểm bán                     2. Bấm Check-in GPS (GPS vệ tinh hoạt động độc lập không cần 4G).
   - Chụp 1 tấm ảnh mặt tiền                   3. Chụp ảnh quầy kệ thực địa.
   - Điền câu trả lời khảo sát                 4. Bấm Kết thúc viếng thăm thành công!"
   - Bấm [KẾT THÚC VIẾNG THĂM]

4. Chạm vào Huy hiệu Đồng bộ góc trên:         "Làm sao dữ liệu được bảo toàn?
   - Mở Bottom Sheet [Chi tiết hàng đợi]       Hãy chạm vào Huy hiệu Đồng bộ ở góc trên màn hình:
   - Danh sách bản ghi 'Đang chờ gửi':         - Một bảng điều khiển hàng đợi OfflineSync hiện ra.
     * 1 lượt check-in                         - Bản ghi check-in, ảnh chụp và câu trả lời khảo sát
     * 1 tệp ảnh                               đang được lưu trữ an toàn trong cơ sở dữ liệu SQLite cục bộ,
     * 1 lượt check-out                        sẵn sàng chờ mạng trở lại."

5. TẮT CHẾ ĐỘ MÁY BAY (BẬT LẠI MẠNG):          "Và bây giờ, nhân viên rời khỏi tầng hầm, điện thoại
   - Tắt chế độ máy bay, có lại 4G/Wifi        bắt lại được sóng 4G:
   - Theo dõi màn hình ứng dụng                Hệ thống tự động kích hoạt tiến trình đồng bộ nền:
   - Huy hiệu đổi icon: Đang đồng bộ...        - Tự động đẩy lượt Check-in lên server.
   - Vài giây sau: Đổi tick Xanh [Đã đồng bộ]  - Nén và tải ảnh lên server.
   - Thông báo đẩy: 'Đồng bộ 3 tác vụ          - Và thông báo đẩy reo lên: 'Đồng bộ ngoại tuyến thành công!'
     lên máy chủ thành công'                   Không mất một byte dữ liệu nào của doanh nghiệp!"
```

---

## MÀN 6: BIỂU MẪU THỊ TRƯỜNG & CHỤP ẢNH TOKEN MỚI (4 Phút)

### Mục tiêu màn 6
> Trình diễn phân hệ Biểu mẫu động (Dynamic Market Forms) linh hoạt và tính năng chụp ảnh biểu mẫu độc lập nhận token 32-hex theo chuẩn kỹ thuật mới nhất.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Mở Menu tiện ích nhanh hoặc vào mục         "Ngoài các khảo sát trong lượt viếng thăm, công ty
   [BIỂU MẪU THỊ TRƯỜNG]:                      thường có các chiến dịch khảo sát chuyên sâu: Khảo
   - Chọn biểu mẫu khảo sát thị trường         sát đối thủ, Báo giá thị trường, Đăng ký biển hiệu.
   - Chọn biểu mẫu mẫu: 'zz_testcc_diemban'    Tất cả các biểu mẫu này được tạo động hoàn toàn từ
                                               trang quản trị web mà không cần cập nhật lại app."

2. Khám phá các loại câu hỏi đa dạng:          "Form hỗ trợ đầy đủ các loại câu hỏi nghiệp vụ:
   - Ô nhập số lượng (có phím tăng giảm)       - Nhập số lượng, số kệ.
   - Ô tiền tệ (tự format: 150.000 đ)          - Nhập giá tiền có định dạng dấu phẩy tự động.
   - Ô chọn một / chọn nhiều (Dropdown/Radio)   - Chọn khách hàng theo tuyến bán hàng."
   - Ô tham chiếu khách hàng

3. ĐIỂM NHẤN: Ô ẢNH MỚI (§2 & §3 SPEC MỚI)     "Đặc biệt, đây là tính năng ô ảnh vừa được nâng cấp:
   - Cuộn đến ô: 'Ảnh biển hiệu / trưng bày'   - Giao diện hiển thị rõ badge giới hạn, cho phép
   - Badge hiển thị: '0/10 ảnh'                chụp tối đa lên đến 10 ảnh theo cấu hình hệ thống.
   - Bấm nút [Chụp ảnh mới]                    - Khi nhân viên bấm chụp ảnh: bức ảnh được tải ngay
   - Chụp 1 tấm ảnh mẫu                        lên endpoint riêng để sinh mã Token bảo mật 32 ký tự.
   - Ảnh hiển thị xem trước sắc nét            - Nhân viên có thể chụp thêm ảnh thứ 2, thứ 3..."
   - Badge cập nhật: '1/10 ảnh'

4. Bấm [NỘP BIỂU MẪU]:                         "Khi bấm Nộp biểu mẫu, phiếu được đóng gói với mảng
   - Màn hình nộp thành công                   Token và mã UUID v4 chống trùng lặp.
   - Mở màn hình Chi tiết biểu mẫu đã nộp:     Hệ thống phản hồi tức thì và hiển thị đầy đủ hình ảnh
   - Hình ảnh hiển thị xem lại sắc nét         đã chụp trong phiếu lưu trữ."
```

---

## MÀN 7: THÊM MỚI ĐIỂM BÁN & KHAI BÁO VỊ TRÍ SỰ CỐ (4 Phút)

### Mục tiêu màn 7
> Giới thiệu 2 nghiệp vụ quan trọng ngoài thị trường: Phát triển điểm bán mới ngay tại thực địa và Khai báo vị trí minh bạch khi có sự cố phát sinh.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Chuyển sang Tab 3 [KHÁCH HÀNG]:             "Tại Tab Khách hàng, nhân viên có thể quản lý danh
   - Bấm nút dấu cộng [+] (Góc dưới phải)      sách khách hàng toàn diện.
   - Mở màn hình [THÊM MỚI ĐIỂM BÁN]           Khi phát hiện một cửa hàng tạp hóa tiềm năng trên
                                               đường, nhân viên bấm dấu [+] để phát triển mới."

2. Thao tác thêm mới khách hàng:               "Màn hình thêm mới điểm bán tích hợp thông minh:
   - Nhập Tên cửa hàng: 'Tạp Hoá Minh Châu'     - Tự động lấy toạ độ GPS vị trí đang đứng làm toạ độ
   - Tự động điền toạ độ GPS hiện tại          cửa hàng (không cần nhập tay kinh độ, vĩ độ).
   - Chọn Tuyến bán hàng                       - Cho phép chụp nhiều ảnh hồ sơ: mặt tiền, hợp đồng.
   - Chụp 1 ảnh mặt tiền cửa hàng              - Và quan trọng nhất: việc thêm mới này cũng hoạt
   - Bấm [LƯU ĐIỂM BÁN]                        động 100% OFFLINE, tự động đồng bộ khi có mạng!"

3. NGHIỆP VỤ KHAI BÁO VỊ TRÍ SỰ CỐ:            "Một tình huống thực tế khác: Nhân viên đang đi đường
   - Vào mục [KHAI BÁO VỊ TRÍ]                 thì bị hỏng xe, hoặc đi gặp khách hàng lớn đột xuất
   - Chọn Lý do: 'Hỏng xe / Sự cố kỹ thuật'    ngoài tuyến đã lên lịch.
   - Nhập Ghi chú: 'Thủng lốp xe tại ngã tư'   Nhân viên mở tính năng [Khai báo vị trí]:
   - Chụp ảnh chiếc xe hoặc hiện trường        - Chọn lý do chuẩn hoá.
   - Bấm [GỬI KHAI BÁO]                        - Chụp ảnh hiện trường có đóng dấu GPS Watermark.
                                               Cấp quản lý trên văn phòng sẽ thấy ngay thông báo và
                                               không đánh giá nhân viên rời bỏ vị trí làm việc."
```

---

## MÀN 8: BÁO CÁO NGÀY, QUÃNG ĐƯỜNG & CHẤM CÔNG RA CA (5 Phút)

### Mục tiêu màn 8
> Khép lại một ngày làm việc trọn vẹn: Xem báo cáo tiến độ KPI thời gian thực, minh bạch số km di chuyển thực tế, và Chấm công Ra ca kết thúc ngày.

```
[Thao tác người demo]                        [Nội dung thuyết minh (Script)]
-----------------------------------------------------------------------------------------
1. Chạm vào Tab 4 [BÁO CÁO HOÀN THÀNH]:        "Đến cuối ngày làm việc, nhân viên mở Tab Báo cáo
   - Xem khối KPI đầu trang:                   để tự đánh giá kết quả làm việc của mình:
     * Tổng số điểm bán đã ghé: 2/12           - Các chỉ số KPI hiển thị trực quan: Tỷ lệ hoàn thành
     * Tỷ lệ hoàn thành: 17%                   tuyến, thời lượng làm việc trung bình tại mỗi điểm.
     * Biểu mẫu đã gửi: 2                      - Dòng thời gian Timeline liệt kê toàn bộ sự kiện từ
   - Cuộn xem Dòng thời gian Timeline          lúc vào ca 08:02, điểm ghé 1, điểm ghé 2 kèm ảnh."

2. Mở tính năng [QUÃNG ĐƯỜNG CỦA TÔI]:         "Một tính năng cực kỳ được nhân viên yêu thích:
   - Thẻ thống kê Gradient hiện đại            [Quãng đường của tôi - My Travel].
   - Hiển thị: 'Hôm nay: 8.4 km'                Dựa vào toạ độ GPS thực tế của các mốc chấm công và
   - Liệt kê các chặng di chuyển (Legs)        check-in điểm bán, hệ thống tự động tính quãng đường
                                               di chuyển hợp lệ để thanh toán phụ cấp xăng xe.
                                               Hoàn toàn minh bạch, không thể gian lận số km!"

3. BƯỚC CUỐI CÙNG: CHẤM CÔNG RA CA (17:00)     "Đã hết giờ làm việc, nhân viên quay lại màn Chấm công
   - Bấm nút [CHẤM CÔNG RA CA]                 để chốt ngày.
   - Nút hiển thị màu cam: 'RA CA'             Nút chuyển sang trạng thái 'RA CA'.
   - Chụp 2 ảnh xác thực (Chân dung + Cảnh)    Nhân viên thực hiện chụp 2 ảnh xác thực cuối ngày.
   - Bấm xác nhận hoàn tất

4. Màn hình hoàn thành:                        "Hệ thống thông báo: 'Đã hoàn tất ngày làm việc!'.
   - Tổng thời gian làm việc được chốt         - Tổng thời gian làm việc được ghi nhận chính xác.
   - Lịch báo thức nhắc việc tự động hủy       - Lịch hẹn nhắc nhở của hệ điều hành tự động huỷ vì
   - Dòng trạng thái: 'Đã hoàn thành công'     nhân viên đã ra ca đúng quy định.
                                               Hành trình một ngày của nhân viên kinh doanh thực địa
                                               khép lại với 100% dữ liệu được số hoá hoàn hảo!"
```

---

## 11. BẢNG TỔNG HỢP THÔNG SỐ KỸ THUẬT ĐÁNG CHÚ Ý

Khi demo cho đối tác kỹ thuật hoặc hội đồng thẩm định, hãy tự tin trích dẫn các thông số sau:

| Tiêu chí | Thông số kỹ thuật của DMS VTHM Mobile |
| :--- | :--- |
| **Framework & Ngôn ngữ** | Flutter 3.x / Dart 3.x (Hỗ trợ iOS & Android từ một mã nguồn duy nhất). |
| **Kiến trúc ứng dụng** | **Clean Architecture** kết hợp State Management bằng **Riverpod 2.6+**. |
| **Cơ sở dữ liệu cục bộ** | **Drift (SQLite)** mã nguồn mở, hỗ trợ Reactive Stream và Migration an toàn. |
| **Bản đồ số** | **Goong Map / MapLibre GL v8**, dữ liệu giao thông Việt Nam cập nhật liên tục. |
| **Duy trì phiên đăng nhập** | Token-based Authentication, tự động lưu đệm duy trì phiên **90 ngày**. |
| **Chống gian lận vị trí** | Tích hợp kiểm tra cờ `isMocked` của phần cứng GPS và kiểm soát độ lệch đồng hồ (`SystemClock`). |
| **Đóng dấu ảnh bản quyền** | Bộ sinh Canvas tự động in chìm toạ độ, thời gian, tên điểm bán, logo độ phân giải cao. |
| **Chiến lược đồng bộ** | **Offline-First**, cơ chế tự phục hồi bản ghi mồ côi (`recoverOrphanedSendingEntries`), cơ chế phân loại lỗi 4xx (Dead) vs 5xx (Retry). |

---

## 12. BỘ CÂU HỎI & TRẢ LỜI KHI THUYẾT TRÌNH (DEMO Q&A)

### Câu 1: Nếu nhân viên chụp ảnh xong mà tắt ứng dụng ngay thì ảnh có bị mất không?
> **Trả lời:** *Dạ hoàn toàn không mất. Tệp ảnh gốc được lưu ngay vào bộ nhớ trong của thiết bị (`app_flutter/offline_customer_photos/`) và ghi vào hàng đợi SQLite trước khi gửi đi. Khi mở lại app hoặc khi có mạng, dịch vụ đồng bộ nền (`SyncService`) sẽ tự động quét và tải ảnh lên server.*

### Câu 2: App liên tục lấy toạ độ GPS như vậy có gây nóng máy và nhanh hết pin không?
> **Trả lời:** *Không ạ. Ứng dụng áp dụng cơ chế **GPS theo yêu cầu (On-Demand Geolocation)**: Chỉ bật GPS mức chính xác cao nhất (High Accuracy) trong vài giây khi nhân viên thực hiện thao tác Check-in hoặc Chấm công. Khi di chuyển bình thường, GPS chỉ ghi nhận mức thụ động (Passive) hoặc dừng hoàn toàn để tiết kiệm tối đa pin cho thiết bị.*

### Câu 3: Làm thế nào để biết nhân viên không chụp ảnh một bức ảnh có sẵn trên màn hình máy tính khác?
> **Trả lời:** *Hệ thống áp dụng 3 lớp bảo vệ: (1) Khóa hoàn toàn chức năng chọn ảnh từ thư viện, chỉ mở camera thực tế; (2) Chụp ảnh góc rộng kép cả chân dung và khung cảnh xung quanh; (3) Tự động đóng dấu Watermark toạ độ thực tế và thời gian thực ngay lúc bấm máy.*

### Câu 4: Nếu quản trị viên trên Web sửa biểu mẫu hoặc gán thêm điểm bán thì nhân viên trên app khi nào nhận được?
> **Trả lời:** *Nhân viên nhận được ngay khi mở app hoặc vuốt nhẹ để làm mới (Pull-to-refresh). Ngoài ra, trên Trang chủ có nút **Đồng bộ tất cả** (`_handleSyncAll`), chỉ mất 1-2 giây để tải toàn bộ danh mục mới nhất từ server về máy.*

---

*Tài liệu được biên soạn và chuẩn hoá theo bộ mã nguồn thực tế của dự án `DMS VTHM Mobile`.*  
*Chúc bạn có một buổi thuyết trình và trình diễn ứng dụng thành công rực rỡ!*

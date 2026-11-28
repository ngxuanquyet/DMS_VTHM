# Luật app DMS (`dms-app/`, Flutter — repo RIÊNG)

Luật chung của hệ thống ở `CLAUDE.md` gốc của checkout `appnew`. File này chỉ ghi luật RIÊNG của app DMS.

## 1. Cập nhật app: vá Shorebird hay phát hành bản mới

App dùng **Shorebird code push**: sửa code Dart ⇒ đẩy bản vá, app tự tải và chạy code mới ở **lần mở THỨ HAI**
(lần đầu tải nền), nhân viên không cài lại. Cấu hình: `shorebird.yaml` (app_id); CLI `/opt/shorebird/bin/shorebird`;
token `secrets/shorebird.env` của checkout `appnew` (`set -a; . ../secrets/shorebird.env; set +a` — KHÔNG in ra);
cần `ANDROID_HOME=/opt/android-sdk`.

### 1a. Chọn đường nào

| Thay đổi | Đường |
|---|---|
| Sửa lỗi gấp (crash, nút không bấm được, tính sai, hiện sai) · text · giao diện nhỏ (bố cục, màu, thứ tự trường, ẩn/hiện) · kiểm tra đầu vào · điều kiện · luồng thao tác ở màn thường · thích ứng API đổi (máy chủ vẫn nhận kiểu cũ) | **Bản vá** Shorebird |
| Thêm/nâng plugin native · quyền hệ điều hành · `AndroidManifest`/`Info.plist` · icon app, splash gốc, tên app · đổi phiên bản Flutter | **Release mới** (không vá được) |
| Migration/schema `drift` | **Release mới** — migration chạy trên máy nhân viên, rút bản vá về thì code cũ gặp DB đã đổi |
| Sửa lớn đồng bộ offline (`sync_service`, hàng đợi gửi) | **Release mới** — rủi ro mất/gửi trùng dữ liệu chưa gửi trên máy |
| Xử lý ảnh/watermark, tính toán nặng | **Release mới** — trên iOS hàm bị vá chạy bằng trình thông dịch, chậm hơn |
| Tính năng lớn nhiều màn | **Release mới** (cần kiểm thử đủ + mốc phiên bản rõ) |
| Ảnh/font/Lottie mới trong `assets/` · tác vụ nền (định vị nền, push khi app tắt) | Chưa xác nhận vá được ⇒ coi như **release mới** cho tới khi thử thật |
| Ngưỡng, công tắc, bán kính, số ảnh tối thiểu | **Máy chủ** — `GET /dms/mobile-rules`, đổi trên One áp đồng loạt ngay; KHÔNG viết cứng rồi vá |
| Nội dung biểu mẫu khảo sát | **Máy chủ** — biểu mẫu động |

### 1b. Quy trình vá

1. Sửa code → **commit vào `dms-app` TRƯỚC khi vá** (bản vá phải khớp một commit).
2. `shorebird patch android|ios --release-version=<bản đang phát hành> --track=staging` → thử trên vài máy thật
   (cả Android lẫn iPhone). App mặc định chỉ hỏi kênh `stable` ⇒ máy thử cài bản kênh staging bằng
   `shorebird preview --release-version=<…> --track=staging`.
3. Ổn ⇒ `shorebird patches promote` sang `stable` (có thể `--rollout=<%>` rồi nâng dần). Hỏng ⇒ `shorebird patches
   rollback` (máy quay về bản trước).
4. Gom thay đổi lớn cho release định kỳ; mỗi release mới làm sạch chuỗi bản vá.

### 1c. Bẫy đã vấp

- 🔴 **Chỉ APK/IPA do `shorebird release` sinh mới nhận bản vá.** `flutter build`/`flutter run` — kể cả cùng commit —
  dùng engine gốc (không có updater) và ra code biên dịch khác ⇒ không bao giờ nhận bản vá. Bản phát hành cho
  nhân viên (`scripts/publish_apk.sh dms`, Codemagic iOS) PHẢI là bản `shorebird release`. Bản debug không áp bản vá.
- **Trong một thời gian có cả máy chạy logic cũ lẫn mới** (nhân viên vài ngày mới mở app) ⇒ đổi dữ liệu gửi lên API
  thì máy chủ phải nhận được CẢ HAI kiểu trong thời gian chuyển tiếp.
- Kiểm phía máy chủ không cần thiết bị: `POST https://api.shorebird.dev/api/v1/patches/check` với
  `{app_id, channel:"stable", release_version, patch_number:null, platform:"android", arch:"x86_64"|"aarch64"}`.
- Gói miễn phí tính theo **lượt cài bản vá trên mỗi máy** (5.000/tháng), không theo số bản vá.

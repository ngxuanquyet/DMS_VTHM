# Thay đổi API ngày 15/10/2026 — quyền "được dùng app DMS"

**Host:** `https://api-app.vthmgroup.vn` · **Xác thực:** `Authorization: Bearer <access_token>`

Tài liệu này liệt kê **đúng những gì đổi trong ngày 15/10/2026** ở luồng đăng nhập của app DMS. Mọi JSON dưới
đây là phản hồi **thật**, gọi bằng `curl` trên bản sao dữ liệu (`app_test`) cùng ngày (đã cắt gọn token).

Hợp đồng đầy đủ của luồng viếng thăm vẫn là
[`API-VIENG-THAM-MOBILE-2026-09-29.md`](API-VIENG-THAM-MOBILE-2026-09-29.md) — file này chỉ là phần thêm.

> 🟡 **App PHẢI sửa thì rào mới có tác dụng.** Server đã sẵn sàng từ 15/10/2026, nhưng chỉ chặn khi app tự
> khai mình là app DMS bằng header `X-Client: dms-app`. Bản app chưa gửi header vẫn chạy y như cũ — không vỡ
> gì, nhưng cũng chưa chặn ai.

| # | Thay đổi | Loại | Ảnh hưởng app |
|---|---|---|---|
| 1 | Gửi header `X-Client: dms-app` ở `POST /auth/login`, `POST /auth/refresh` | **APP PHẢI THÊM** | Bắt buộc |
| 2 | Hai cửa trên trả **403 `DMS_APP_FORBIDDEN`** khi tài khoản chưa được cấp quyền | **MÃ LỖI MỚI** | Bắt buộc xử lý |
| 3 | Endpoint mới `GET /dms/app-access` — hỏi "tôi còn được dùng app không" | **THÊM** | Nên gọi lúc mở app |

---

## 1. Chuyện gì đổi ở phía server

Trước 15/10/2026, app DMS đăng nhập qua đúng cửa của web One nên **mọi tài khoản One** đều vào được app;
người không đi thị trường chỉ bị 403 lẻ tẻ khi bấm vào từng chức năng.

Nay có quyền riêng **`/dms/app-access/index`** — "Được đăng nhập app DMS (thị trường) trên điện thoại". Quyền
nằm sẵn trong vai `crm_customer_self` (nhân viên thị trường) và `crm_customer_admin`, nên **mọi người đang dùng
app hôm nay vẫn vào được**. Quản trị cấp/thu quyền trên web One (Tài khoản → Phân quyền, hoặc Vai trò).

Super admin luôn qua.

---

## 2. App phải làm gì

### 2.1 Gửi header ở hai cửa đăng nhập

```
POST /auth/login
X-Client: dms-app
Content-Type: application/json

{"username":"VTG920","password":"…"}
```

```
POST /auth/refresh
X-Client: dms-app
Content-Type: application/json

{"refresh_token":"…"}
```

Giá trị phải đúng `dms-app` (không phân biệt hoa thường). Gắn header vào **mọi request** qua interceptor của
Dio/HttpClient cũng được — các endpoint khác bỏ qua nó. Server đã cho phép header này ở CORS (preflight trả
`Access-Control-Allow-Headers: content-type, x-client`), nên chạy app bằng Flutter Web cũng không bị chặn.

### 2.2 Xử lý 403 `DMS_APP_FORBIDDEN`

**Đăng nhập khi chưa được cấp quyền** — mật khẩu đúng nhưng không có token nào được phát:

```json
HTTP 403
{"success":false,"message":"Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.","errors":null,"data":null,"code":"DMS_APP_FORBIDDEN"}
```

→ Ở lại màn đăng nhập, **hiện nguyên câu `message`**. Đừng hiện "Sai mật khẩu" — mật khẩu đúng.

**Làm mới phiên khi đã bị thu quyền** (người đang dùng app thì quản lý gỡ quyền):

```json
HTTP 403
{"success":false,"message":"Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.","errors":null,"data":null,"code":"DMS_APP_FORBIDDEN"}
```

→ Server **đã thu hồi** refresh token đó (gửi lại sẽ nhận `401 REFRESH_INVALID`). App xoá access + refresh token
trong máy, về màn đăng nhập, hiện câu `message`.

🔴 **Phân biệt bằng khoá `code`, không phải bằng mã HTTP.** 401 ở `/auth/refresh` vẫn là "phiên hết hạn,
đăng nhập lại"; chỉ `code = "DMS_APP_FORBIDDEN"` mới là "không có quyền dùng app" — đăng nhập lại cũng vô ích.

### 2.3 Hỏi lại quyền lúc mở app (khuyến nghị)

Người mở app khi còn giữ phiên cũ thì chưa đi qua `/auth/login`. Gọi một lần lúc khởi động (hoặc lúc app quay
lại foreground):

```
GET /dms/app-access
Authorization: Bearer <access_token>
```

Còn quyền:

```json
HTTP 200
{"success":true,"message":"Tài khoản được dùng app DMS.","data":{"allowed":true}}
```

Đã bị thu quyền:

```json
HTTP 403
{"success":false,"message":"Bạn không có quyền thực hiện thao tác này.","errors":null,"data":null}
```

→ 403 ở đây: xử lý như §2.2 (xoá token, về màn đăng nhập), nhưng hiện câu của app *"Tài khoản chưa được cấp
quyền dùng app DMS. Vui lòng liên hệ quản lý."* — câu `message` của endpoint này là câu 403 chung.
→ 401: access token hết hạn — gọi `/auth/refresh` như thường, rồi hỏi lại.
→ Mất mạng: **đừng** đẩy người dùng ra; giữ phiên và hỏi lại lần sau (app phải chạy được ngoại tuyến).

### 2.4 Danh sách quyền trong phản hồi đăng nhập

`POST /auth/login` và `/auth/refresh` vẫn trả mảng `permissions` như trước; người có quyền thì mảng có chuỗi
`"/dms/app-access/index"` (super admin nhận `["*"]`). Dùng nó để vẽ giao diện thì được, nhưng **server mới là
hàng rào** — đừng thay §2.2 bằng việc tự soi mảng này.

---

## 3. Những gì KHÔNG đổi

- Không endpoint nào đổi đường dẫn; hình dạng phản hồi đăng nhập thành công giữ nguyên.
- Các API nghiệp vụ (`/dms/visits`, `/dms/routes/...`, `/crm/customers/mine`…) vẫn gác bằng quyền riêng của chúng
  như §1 của tài liệu viếng thăm — quyền app chỉ chặn ở **cửa vào**.
- Thu quyền KHÔNG cắt ngay access token đang cầm (sống tới hết `expires_in`, hiện 3600 giây); người đó bị đẩy ra
  ở lần `/auth/refresh` kế tiếp, hoặc sớm hơn nếu app gọi `GET /dms/app-access` theo §2.3.

## 4. Kiểm thử nhanh trên app

| Ca | Kỳ vọng |
|---|---|
| Tài khoản có vai `crm_customer_self`, đăng nhập | 200, vào app |
| Tài khoản thường (chỉ vai `employee`), đăng nhập | 403 `DMS_APP_FORBIDDEN`, ở lại màn đăng nhập với câu báo |
| Đang dùng app → quản trị gỡ vai → chờ ≤5 phút (cache quyền) → mở lại app | `GET /dms/app-access` 403 → về màn đăng nhập |
| Như trên nhưng app không gọi `/dms/app-access` | bị đẩy ra ở lần làm mới phiên kế tiếp (≤1 giờ) |

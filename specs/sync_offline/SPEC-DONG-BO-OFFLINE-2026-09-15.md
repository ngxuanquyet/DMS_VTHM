# SPEC — Đồng bộ OFFLINE-FIRST cho app DMS

**Ngày:** 2026-09-15 · **Trạng thái:** 🟡 THIẾT KẾ — chưa thi công
**Phạm vi:** app thị trường (Flutter) ↔ `api-app.vthmgroup.vn`, cho `crm_customer` · `dms_visit` ·
`dms_position_declaration` · `dms_form_submission` · `dms_visit_photo`.

> Đi kèm: [SPEC-CRM-DMS-2026-09-07](./SPEC-CRM-DMS-2026-09-07.md) §8 (bản nguyên tắc — tài liệu này là bản
> thi công của nó) · [KE-HOACH-TRIEN-KHAI-DMS](./KE-HOACH-TRIEN-KHAI-DMS-2026-09-10.md) (đợt B4a/B4b) ·
> [SPEC-DI-TRU-MOBIWORK](./SPEC-DI-TRU-MOBIWORK-2026-09-11.md) (ba bẫy ngày giờ đã trả giá).

Mọi con số trong tài liệu **đo trực tiếp ngày 15/09/2026** trên DB `app_test` (18 migration `crm_`/`dms_`/`att_`;
prod đã áp đủ từ 13/09) và trên mã nguồn hiện tại. Chỗ nào là ước lượng đều nói rõ là ước.

---

## 0. Một câu tóm tắt

Nhân viên thị trường mất sóng là **chuyện thường**, không phải ngoại lệ. Vì vậy app **luôn ghi vào máy
trước**, coi mạng là thứ có thể không bao giờ đến; và mọi cơ chế dưới đây tồn tại để trả lời đúng một câu:
**làm sao biết chắc một lần bấm của người dùng vào hệ đúng MỘT lần — không mất, không nhân đôi.**

---

## 1. Ba bất biến, đọc kỹ trước khi thiết kế gì thêm

### BB-1 · Ghi máy trước, mạng sau — không có nhánh "đang có mạng thì gửi thẳng"

Một app có hai đường ghi (online gửi thẳng / offline xếp hàng) là hai đường code, hai tập lỗi, và đường
online **không bao giờ được kiểm** ở nơi sóng tốt. Chỉ MỘT đường: ghi SQLite → xếp hàng → bộ gửi chạy nền.
Sóng tốt thì hàng đợi rỗng sau 1 giây; người dùng không phân biệt được.

### BB-2 · `client_uuid` sinh LÚC NHẬP, không phải lúc gửi

🔴 **Đây là bất biến quan trọng nhất của cả tài liệu.** Sinh lúc gửi thì mỗi lần thử lại là một UUID mới,
và một lần bấm của người dùng thành N bản ghi trên server — đúng khi mạng chập chờn, tức đúng lúc hay
xảy ra nhất.

```
người dùng bấm "Lưu"
   ├─ sinh uuid_v4()          ← TẠI ĐÂY, một lần duy nhất
   ├─ ghi SQLite kèm uuid
   └─ đẩy vào hàng đợi
          └─ gửi lần 1 (mất sóng) → gửi lần 2 → lần 3 … CÙNG một uuid
```

UUID đi cùng bản ghi suốt đời nó, kể cả sau khi cài lại app (nếu DB còn) và sau khi server đã nhận.

### BB-3 · `client_uuid` ≠ `legacy_key`

Hai cột khác nhau, hai mục đích, **cấm dùng lẫn**:

| Cột | Ai sinh | Nghĩa |
|---|---|---|
| `client_uuid` | **app** | "một lần bấm của người dùng" |
| `legacy_key` | **bộ di trú** | "một bản ghi bên MobiWork" |

Trộn hai thứ là mất dòng im lặng: 28–33% lượt viếng thăm cũ không có mã khách hàng, và khoá di trú của
chúng có hình dạng khác hẳn UUID.

---

## 2. Hiện trạng đo được 15/09/2026 — đây là điểm xuất phát thật

| Đo gì | Số | Ý nghĩa cho thiết kế |
|---|---|---|
| `pubspec.yaml` của `dms-app/` | **không** có `drift`/`sqflite`/`hive`/`isar`, **không** có `uuid` | Offline chưa bắt đầu; BB-2 chưa có gói để thực hiện |
| `api/modules/dms/` | **chưa tồn tại** (module `dms` mới có 12 migration + 3 service di trú) | `/dms/sync/*` sẽ là controller đầu tiên của module |
| `common/modules/dms/settings/` | **chưa tồn tại** | Chưa có `DmsSettingProvider`; mọi ngưỡng dưới đây chưa có chỗ nằm |
| Điểm bán `crm_customer` | **8.730** | Cấm tải toàn bộ mỗi lần mở app |
| Phân công `crm_customer_assignment` (còn sống) | **23.372** dòng / **66** mã NV | TB **354** điểm/người · **p90 991** · **max 1.523** |
| Lượt ghé `dms_visit` | 42.501 (di trú) | T08/2026: **2.064** lượt + **1.004** khai báo vị trí, **41** NV |
| Nhịp thật một người | **≈2,9** bản ghi/người/ngày làm việc · ngày cao nhất đo được **27** | Hàng đợi thường rất ngắn, nhưng phải chịu được ngày 27 mục |
| Ảnh mỗi lượt (đo từ `legacy_raw->>'hinh_anh'`) | TB **2,18** · **max 32** | ⚠️ Con số "0–8 ảnh" của bản nháp trước là SAI |
| Ảnh sau nén | ~77 KB (chuẩn đo từ MobiWork) | 1 ngày offline ≈ **0,5 MB** hàng đợi · 1 tuần ≈ **3,4 MB** (ước) |

🔴 **Ba thứ trong DB khác với `SPEC-CRM-DMS-2026-09-07` §6.2 — bám BẢNG THẬT, không bám spec:**

1. `dms_visit` **không có cột `reason_id`** (spec ghi NOT NULL). Lý do chỉ thuộc khai báo vị trí.
2. `dms_visit.customer_id` **nullable**, nhưng CHECK `ck_dms_visit_customer` buộc
   `customer_id IS NOT NULL OR (legacy_source IS NOT NULL AND legacy_customer_code IS NOT NULL)` ⇒ bản ghi
   **từ app bắt buộc có `customer_id` thật**. Hệ quả nặng ở §5.3.
3. `dms_visit` **không có `updated_at`** — đúng với bản chất append-only, và là lý do §8.1 không áp
   Last-Write-Wins cho lượt ghé.

---

## 3. Hàng đợi ngoại tuyến

### 3.1 Bảng hàng đợi trên máy (SQLite qua `drift`)

```
sync_queue
  id              INTEGER PK AUTOINCREMENT   -- thứ tự FIFO
  entity          TEXT      -- 'customer' | 'visit' | 'declaration' | 'form_submission' | 'photo'
  op              TEXT      -- 'create' | 'checkout' | 'attach_photo'   (§5.5 — KHÔNG chỉ có create)
  client_uuid     TEXT      -- khoá chống trùng của CHÍNH mục này
  parent_uuid     TEXT      -- uuid của bản ghi phải vào server TRƯỚC (§5.3); NULL nếu độc lập
  payload         TEXT      -- JSON đóng gói SẴN lúc nhập, KHÔNG dựng lại lúc gửi
  local_path      TEXT      -- chỉ với 'photo': đường dẫn tệp trên máy
  state           TEXT      -- 'pending' | 'sending' | 'done' | 'dead'
  attempts        INTEGER   DEFAULT 0
  next_attempt_at INTEGER   -- epoch ms; bộ gửi bỏ qua mục chưa tới hạn
  last_error      TEXT
  created_at      INTEGER   -- epoch ms theo ĐỒNG HỒ MÁY lúc nhập
  created_elapsed INTEGER   -- ĐỒNG HỒ ĐƠN ĐIỆU (monotonic) lúc nhập — §6.3, KHÔNG bỏ cột này
  boot_id         TEXT      -- định danh lần khởi động máy; khác lần khởi động ⇒ elapsed vô nghĩa
  server_id       INTEGER   -- id server trả về khi thành công
```

⚠️ **`payload` đóng gói SẴN lúc nhập, không dựng lại lúc gửi.** Dựng lại lúc gửi nghĩa là đọc lại điểm bán
và danh mục ở trạng thái **hiện tại của máy**, mà giữa lúc nhập và lúc gửi có thể đã có một lượt pull đổi
dữ liệu. Bản ghi gửi đi khi đó không còn là thứ người dùng đã nhìn thấy và xác nhận.

### 3.2 Máy trạng thái

```
        nhập                gửi              2xx
 (—) ─────────► pending ─────────► sending ────────► done ──(sau N ngày)──► xoá
                   ▲                  │
        lùi lịch   │                  │ lỗi tạm / mạng / cha chưa vào (§8.2)
                   └──────────────────┤
                                      │ lỗi vĩnh viễn (403 / 422 / INVALID)
                                      └────────► dead ──► hiện trên màn "Đồng bộ"
```

### 3.3 Bảy luật của hàng đợi

1. **FIFO theo `id`**, nhưng **không được tắc đầu hàng**. Một mục lỗi vĩnh viễn phải chuyển `dead` và
   **đi tiếp**, không chặn 200 mục sau nó. Mục `dead` hiện trên màn "Đồng bộ" để người dùng thấy và báo lại.
2. **Mục có `parent_uuid` chỉ rời `pending` khi cha đã `done`** (§5.3). Ảnh là ca thường gặp nhất nhưng
   không phải ca duy nhất.
3. **Không xoá mục `done` ngay.** Giữ theo `dms.sync.queueKeepDoneDays` (đề xuất **7**) để màn "Đồng bộ"
   trả lời được "hôm qua tôi gửi những gì" khi có tranh cãi số liệu. Sau đó dọn.
4. **Một tiến trình gửi duy nhất.** Hai luồng cùng đọc hàng đợi sẽ gửi trùng — server chặn được (§4),
   nhưng ảnh thì tốn băng thông thật của người dùng.
5. 🔴 **Mở app là phải hồi phục mục `sending` mồ côi về `pending`.** HĐH giết tiến trình nền giữa lúc gửi
   là chuyện bình thường trên Android; mục kẹt ở `sending` sẽ **nằm lại vĩnh viễn** vì không vòng lặp nào
   nhận nó. Bộ gửi khởi động: `UPDATE sync_queue SET state='pending' WHERE state='sending'`. An toàn, vì
   `client_uuid` đã chống trùng ở server.
6. **Trần kích thước lô**: `dms.sync.pushBatchSize` (đề xuất **50** mục/request). Ngày cao nhất đo được là
   27 mục/người nên 50 đủ cho một ngày, và vẫn nhỏ để gửi lại rẻ khi lô hỏng.
7. **Ảnh gửi từng tấm, không gộp lô.** Một request một tấm: mất sóng giữa chừng chỉ mất tấm đó.

---

## 4. Chống trùng phía server

### 4.1 Ràng buộc đã có sẵn trong DB

Bốn partial unique index **đã tồn tại** (đo trên `app_test` 15/09), không phải việc phải làm:

```sql
uq_crm_customer_uuid  ON crm_customer             (client_uuid) WHERE client_uuid IS NOT NULL
uq_dms_visit_uuid     ON dms_visit                (client_uuid) WHERE client_uuid IS NOT NULL
uq_dms_decl_uuid      ON dms_position_declaration (client_uuid) WHERE client_uuid IS NOT NULL
uq_dms_sub_uuid       ON dms_form_submission      (client_uuid) WHERE client_uuid IS NOT NULL
```

🔴 **Vế `WHERE … IS NOT NULL` là bắt buộc, không phải trang trí.** UNIQUE thường trên cột nullable **không
chặn gì**: PostgreSQL coi mỗi `NULL` là một giá trị khác nhau — nhưng chiều ngược lại mới là chỗ chết ở đây:
thiếu vế `WHERE`, **8.730 dòng di trú** (đều `client_uuid` NULL) sẽ không cùng tồn tại được. Bẫy UNIQUE trên
cột nullable đã cắn 3 lần trong module `attendance`; phép thử bắt buộc là **ghi 2 dòng NULL** (phải vào) và
**2 dòng trùng giá trị** (phải bị chặn).

### 4.2 🔴 `dms_visit_photo` KHÔNG có `client_uuid` — lỗ phải vá trước khi viết pha 2

Đo 15/09: `dms_visit_photo` có `id · visit_id · declaration_id · file_id · photo_type · taken_at · lat ·
lng · sort_order · legacy_url · created_at` — **không có `client_uuid`, không có cột hash**. Nghĩa là hôm
nay **không có gì chặn một tấm ảnh vào hai lần**: mất sóng sau khi server đã lưu ảnh → app gửi lại → 2 dòng
ảnh giống hệt trong cùng lượt ghé, và báo cáo "số ảnh chụp" đếm sai.

Khử trùng bằng `sha1(file)` qua `sys_file.hash` **không thay thế được**: hai lần chụp khác nhau của cùng một
kệ hàng cho hai hash khác nhau (đúng — là hai ảnh thật), còn hai lần **gửi cùng một tệp** mới là thứ cần
khử — mà đó chính là điều `client_uuid` nói chắc chắn còn hash chỉ đoán.

⇒ **Việc phải làm (§10 mục 1):** migration thêm `client_uuid uuid` vào `dms_visit_photo` +
`uq_dms_photo_uuid … WHERE client_uuid IS NOT NULL`. UUID của ảnh sinh **lúc bấm chụp**, cùng luật BB-2.

### 4.3 Hợp đồng của `POST /dms/sync/push`

Nhận một **lô trộn loại**, trả kết quả **từng bản ghi** — không phải một mã thoát cho cả lô:

```jsonc
// gửi
{ "items": [
    {"entity":"customer", "op":"create", "client_uuid":"a42b…", "data":{…}},
    {"entity":"visit",    "op":"create", "client_uuid":"6f1c…", "parent_uuid":"a42b…", "data":{…}}
]}

// nhận — 200, KỂ CẢ khi có mục trùng
{ "results": [
    {"client_uuid":"a42b…", "status":"CREATED", "id":9981},
    {"client_uuid":"6f1c…", "status":"CREATED", "id":10234}
]}
```

| `status` | Nghĩa | App làm gì |
|---|---|---|
| `CREATED` | Đã tạo mới | `done`, lưu `server_id` |
| `ALREADY_EXISTS` | Lô trước đã vào rồi | **cũng `done`** — đây là thành công, không phải lỗi. Trả kèm `id` của dòng đã có |
| `PENDING_PARENT` | Bản ghi cha chưa có trên server (§5.3) | giữ `pending`, **không** tăng `attempts`, đẩy xuống cuối hàng |
| `INVALID` | Payload sai luật nghiệp vụ | `dead` + hiện lỗi từng trường cho người dùng |
| `RETRY` | Lỗi tạm (khoá, quá tải) | giữ `pending`, lùi lịch theo §8.2 |

🔴 **`ALREADY_EXISTS` trả HTTP 200, không phải 409.** Client gặp 4xx thường được lập trình là "bỏ vào
dead" — mà đây là ca **bình thường nhất** của mọi hệ offline: gửi thành công rồi mất sóng trước khi nhận
được phản hồi. Trả 409 là biến ca bình thường thành ca lỗi.

**Phép kiểm chấp nhận:** gửi cùng một `client_uuid` **10 lần** → DB có **1 dòng**, 9 lần sau trả
`ALREADY_EXISTS` kèm **cùng một `id`**.

### 4.4 Vì sao không dùng `ON CONFLICT DO NOTHING` rồi thôi

Vì app cần **`id` của dòng đã có** để gắn ảnh và để hiện "đã đồng bộ" đúng bản ghi. `DO NOTHING` trả về 0
dòng, không nói id là gì:

```sql
INSERT INTO dms_visit (…) VALUES (…)
ON CONFLICT (client_uuid) WHERE client_uuid IS NOT NULL
DO UPDATE SET client_uuid = EXCLUDED.client_uuid   -- no-op, chỉ để có RETURNING
RETURNING id, (xmax = 0) AS was_inserted;
```

`xmax = 0` phân biệt `CREATED` với `ALREADY_EXISTS` trong **một** câu lệnh, thay vì SELECT trước rồi INSERT
sau (hai câu = có khe chạy đua giữa hai request của cùng một máy khi mạng chập chờn).

⚠️ **Mỗi mục trong lô là MỘT transaction riêng** (hoặc một SAVEPOINT). Lý do đã đo được ở module khác: bắt
lỗi DB trong transaction PostgreSQL rồi ghi tiếp là `25P02` — cả transaction đã ABORT, nên một mục `INVALID`
sẽ kéo **mọi mục sau nó trong cùng lô** chết theo, và thông báo lỗi không chỉ ra nguyên nhân thật. Sau khi
rollback tới SAVEPOINT thì **ĐỌC LẠI** để biết mình vướng ràng buộc nào, đừng đoán theo tên constraint.

---

## 5. Thứ tự gửi: bản ghi trước, ảnh sau — và cha trước, con sau

### 5.1 Vì sao hai pha

Một lượt viếng thăm có trung bình **2,18** ảnh (tối đa đo được **32**), mỗi ảnh ~77 KB sau nén. Gửi kèm
trong một request thì:
- mất sóng giữa chừng là **mất cả bản ghi** dù nó chỉ nặng ~2 KB;
- không gửi lại được riêng tấm ảnh hỏng;
- thời gian chờ dài, người dùng tưởng app treo.

Tách hai pha: **bản ghi (nhỏ, quan trọng) đi trước và độc lập**; ảnh là phần bổ sung, hỏng thì lượt viếng
thăm vẫn còn.

### 5.2 Ảnh tham chiếu bằng `client_uuid`, KHÔNG bằng id server

```
PATCH /dms/visits/by-uuid/{client_uuid}/photos
  multipart: file, client_uuid (của ẢNH), photo_type, taken_at, lat, lng, sort_order
```

🔴 App **có thể chưa biết id server** — chính là ca mất sóng sau khi gửi bản ghi. Bắt app chờ id mới gửi
được ảnh là dựng lại đúng vấn đề vừa tách ra.

| Ca | Server trả |
|---|---|
| uuid cha có thật, ảnh mới | `200` + `photo_id` |
| uuid cha **chưa** có | `404` — **và KHÔNG tạo bản ghi cha**; app giữ `pending` |
| cùng ảnh (cùng `client_uuid` của ảnh) gửi 2 lần | `200` + **cùng** `photo_id` — cần cột ở §4.2 |

**Không tạo bản ghi cha khi nhận ảnh** là có chủ ý: tạo ngầm sẽ sinh ra một lượt viếng thăm rỗng không có
giờ check-in, không có toạ độ — và nó sẽ nằm trong báo cáo.

⚠️ **Ảnh đi qua kho `sys_file` hiện có**, không dựng kho riêng: `dms_visit_photo.file_id` trỏ `sys_file.id`.
`uploads/` nằm ngoài webroot, chỉ stream qua PHP kèm Bearer.

### 5.3 Ba pha, không phải hai — khi lượt ghé xảy ra ở điểm bán mở mới

Đây là phần bản nháp trước thiếu hẳn, và nó là **ca phổ biến**: nhân viên đến một quán chưa có trong hệ, mở
điểm bán mới **ngay tại chỗ khi đang mất sóng**, rồi check-in luôn vào chính điểm bán đó.

```
pha 0: điểm bán mới  (client_uuid = A)  ──┐
pha 1: lượt ghé      (parent_uuid = A)  ──┤ cha phải vào TRƯỚC
pha 2: ảnh           (parent_uuid = uuid lượt ghé)
```

🔴 **Vì sao không bỏ qua được:** `ck_dms_visit_customer` buộc bản ghi từ app phải có `customer_id` thật, mà
id đó **chỉ server biết** — mã điểm bán sinh theo khu vực, có `pg_advisory_xact_lock` chống hai người tạo
cùng lúc, nên app **không được** tự sinh mã. App chỉ có `client_uuid` của điểm bán.

⇒ **Payload lượt ghé mang `customer_client_uuid`** khi chưa biết `customer_id`. Server giải theo thứ tự:
`customer_id` (nếu app biết) → tra `crm_customer` theo `client_uuid` → chưa có thì trả `PENDING_PARENT`.

⇒ **Trong cùng một lô, server xử lý theo đúng thứ tự mảng `items`**, mục sau thấy được mục trước; app xếp
cha trước con khi đóng gói. Nhưng **không được dựa vào đó để bỏ `PENDING_PARENT`**: lô có thể bị cắt ở giữa.

### 5.4 Điểm bán mới còn phải QUA DUYỆT — hệ quả cho lượt ghé

`crm_customer.approval_status` có 4 giá trị (`draft`/`pending`/`approved`/`rejected`); điểm bán do nhân viên
mở nhận `pending`. Lượt ghé trỏ vào điểm bán `pending` có hợp lệ không, và nếu điểm bán bị `rejected` thì
lượt ghé đã ghi xử lý ra sao — **chưa chốt**, xem §12 Q1/Q2. Đề xuất: ghi nhận bình thường (nhân viên đã
thực sự đến nơi), báo cáo lọc riêng nhóm này.

### 5.5 Check-out KHÔNG phải bản ghi mới — nó là CẬP NHẬT

Bản nháp trước viết "đợt 1 app chỉ TẠO". Điều đó **không đúng với chính nghiệp vụ viếng thăm**:
`dms_visit.checkout_at` / `duration_seconds` được điền **sau** check-in, cách nhau có khi 40 phút, và giữa
hai lần đó máy có thể mất sóng.

```
PATCH /dms/visits/by-uuid/{client_uuid}/checkout
  { "checkout_at": "2026-09-15T10:42:00+07:00", "client_time": "…", "queued_seconds": 0 }
```

| Ca | Server làm |
|---|---|
| `checkout_at` đang NULL | ghi, tính `duration_seconds`, trả `UPDATED` |
| `checkout_at` đã có, **bằng** giá trị gửi lên | trả `ALREADY_EXISTS` — app `done` (ca gửi lại) |
| `checkout_at` đã có, **khác** giá trị gửi lên | trả `INVALID` kèm giá trị hiện có; **không đè** |
| uuid chưa tồn tại | `404`; app giữ `pending` (check-in chưa lên) |

⚠️ CHECK `ck_dms_visit_checkout` (`checkout_at >= checkin_at`) là hàng rào cuối: check-out mang giờ máy bị
chỉnh lùi sẽ **vi phạm CHECK và làm cả request 500** nếu server không kiểm trước. Server phải trả `INVALID`
tử tế, không để DB ném ra ngoài.

---

## 6. Thời gian: lưu CẢ HAI, quyết định bằng CÁI THỨ BA

### 6.1 Bốn cột đã có trên `dms_visit`, `dms_position_declaration`, `dms_form_submission`

| Cột | Nguồn | Dùng để |
|---|---|---|
| `client_time` | **đồng hồ máy** lúc người dùng bấm | thứ người dùng tin là đúng |
| `server_received_at` | `NOW()` của DB lúc nhận | mốc không ai sửa được |
| `time_diff_seconds` | `server_received_at − client_time` | đo lệch |
| `is_time_tampered` | theo §6.3 | cờ để soi, **không** để chặn |

CHECK `ck_dms_*_tamper` (`NOT is_time_tampered OR time_diff_seconds IS NOT NULL`) đã có trên cả ba bảng:
cờ nghi vấn **phải kèm số đo**, không để cờ trơ.

Báo cáo dùng `client_time` (đúng nghĩa nghiệp vụ), đối soát dùng `server_received_at`. Chỉ tin máy thì đổi
giờ là khai khống được; chỉ tin server thì lượt gửi sau 3 ngày mất sóng mang giờ ngày gửi — sai ngày làm
việc và hỏng báo cáo tần suất ghé thăm.

### 6.2 `visit_date` suy từ `client_time`, không từ giờ server

Ngày làm việc là **ngày theo giờ VN của `client_time`**. Server **không** tự suy `visit_date` từ
`server_received_at` — làm thế thì 50 lượt ghé của 3 ngày mất sóng dồn hết vào ngày gửi.

### 6.3 🔴 `time_diff_seconds` MỘT MÌNH không phân biệt được gian lận với hàng đợi

Đây là lỗi thiết kế nặng nhất của bản nháp trước, và cũng là chỗ `SPEC-CRM-DMS` §6.7 còn hở. Hai ca có
**cùng một dấu hiệu** nhưng ý nghĩa ngược nhau:

| Ca | `client_time` | `server_received_at` | `time_diff` | Thực chất |
|---|---|---|---|---|
| Mất sóng 3 ngày, đồng hồ đúng | 12/09 09:00 | 15/09 09:00 | **+259.200** | **HỢP LỆ** |
| Chỉnh lùi đồng hồ 50 phút rồi check-in, gửi ngay | 08:00 | 08:50 | **+3.000** | **GIAN LẬN** |

Luật `|time_diff| > ngưỡng ⇒ tampered` gắn cờ **cả 50 lượt hợp lệ** của ca TC-OFF-05. Luật ngược lại của
§6.7 (*"bản ghi offline chỉ gắn cờ khi lệch ÂM"*) thì bỏ lọt hoàn toàn người chỉnh lùi giờ rồi để hàng đợi
gửi sau vài giờ — lệch của họ cũng là dương.

⇒ **Phải có mốc thứ ba mà người dùng không sửa được: đồng hồ đơn điệu (monotonic) của máy.** Nó đếm từ lúc
khởi động, **không đổi khi chỉnh giờ**, không đổi khi đổi múi giờ.

```
app gửi kèm mỗi bản ghi:
  client_time     — giờ máy LÚC NHẬP
  queued_seconds  — (monotonic lúc gửi − monotonic lúc nhập): bản ghi đã NẰM CHỜ bao lâu

server tính:
  time_diff_seconds = server_received_at − client_time          (giữ nguyên, để soi)
  clock_skew        = time_diff_seconds − queued_seconds        ← THỨ QUYẾT ĐỊNH
  is_time_tampered  = |clock_skew| > dms.sync.timeSkewToleranceSeconds
```

Đọc lại hai ca trên: mất sóng 3 ngày có `queued_seconds ≈ 259.200` ⇒ `clock_skew ≈ 0` ⇒ **không gắn cờ**.
Chỉnh lùi giờ có `queued_seconds ≈ 0` ⇒ `clock_skew ≈ +3.000` ⇒ **gắn cờ**. Và quan trọng: chỉnh lùi giờ
**rồi chờ 6 giờ mới gửi** vẫn ra `clock_skew ≈ +3.000` ⇒ vẫn gắn cờ.

⚠️ **`queued_seconds` do app gửi, nên về lý thuyết can thiệp được** (root máy, sửa APK). Chấp nhận: cờ này
là **công cụ soi**, không phải chứng cứ. Hàng rào thật nằm ở thứ đo tại hiện trường — `is_mock_location`,
`distance_to_customer_m`, `is_within_geofence`. Ghi rõ điều này để đừng ai dựng quy trình kỷ luật chỉ dựa
trên `is_time_tampered`.

⚠️ **Khởi động lại máy làm monotonic về 0.** Vì vậy hàng đợi lưu `boot_id`; khác lần khởi động thì
`queued_seconds` **không tính được** ⇒ app gửi `null`, server **bỏ qua** phép kiểm skew cho bản ghi đó
(`is_time_tampered = false`), không đoán bừa. Đây là ca thật: máy hết pin giữa chuyến đi.

### 6.4 Ngưỡng là THAM SỐ, không hardcode

Khai ở `SettingProvider` của module `dms` (`common/modules/dms/settings/` — **chưa tồn tại**, việc §10):

| Khoá | Mặc định đề xuất | Nghĩa |
|---|---|---|
| `dms.sync.timeSkewToleranceSeconds` | **300** | Quá ngưỡng ⇒ `is_time_tampered` |
| `dms.sync.pushBatchSize` | **50** | Trần số mục một request |
| `dms.sync.queueKeepDoneDays` | **7** | Giữ mục đã gửi để tra cứu |
| `dms.sync.pullPageSize` | **500** | Trần số bản ghi một trang pull |
| `dms.sync.tombstoneRetentionDays` | **90** | Quá hạn ⇒ buộc tải lại từ đầu (§7.2) |
| `dms.sync.staleQueueAlertHours` | **24** | Hàng đợi tồn đọng quá lâu thì app cảnh báo đỏ |

Người vận hành chỉnh ở `/system/settings/dms` — trang tự hiện, **cấm dựng màn cấu hình riêng cho cùng khoá**.

### 6.5 🔴 Ba bẫy múi giờ đã trả giá thật trong đợt di trú

Ghi lại vì app sẽ gặp lại y hệt:

1. **Chuỗi có hậu tố `Z` mà KHÔNG phải UTC.** Nguồn cũ trả `...T17:00:00.000Z` cho một **ngày thuần giờ
   VN**. Đổi múi giờ đẩy sang ngày hôm sau. Đối chiếu 429 lượt: cắt 10 ký tự khớp **429/429**, đổi TZ khớp
   **0/429**.
2. **Giá trị chỉ có GIỜ** (`"09:56"`) truyền thẳng vào hàm ngày giờ ra **hôm nay** — làm **cả 49.137 lượt
   dồn vào tháng hiện tại**, không exception nào.
3. **Tổng số dòng khớp KHÔNG chứng minh ngày đúng.** Lỗi ② cho tổng khớp tuyệt đối 49.137/49.137 trong khi
   mọi ngày đều sai. Thứ bắt được nó là **đối soát PHÂN BỐ THEO THÁNG**.

⇒ **Luật cho app:** mọi mốc gửi lên dùng **ISO-8601 có offset tường minh** (`2026-09-15T14:32:10+07:00`).
Cấm gửi chuỗi trần, cấm gửi epoch không nói đơn vị.

---

## 7. Kéo dữ liệu về máy (pull)

Phần này quyết định app có dùng được ngoài vùng phủ sóng hay không, và nó có một cái bẫy đã đo được.

### 7.1 Kéo cái gì, ai được kéo cái gì

| Loại | Nguồn | Phạm vi |
|---|---|---|
| Điểm bán | `crm_customer` | **Chỉ điểm bán được phân công cho tập mã NV của người đăng nhập** (`crm_customer_assignment`) + OrgScope. TB 354/người, p90 991 |
| Phân công | `crm_customer_assignment` | Của chính mình |
| Danh mục | `crm_customer_type` · `crm_channel` · `crm_region` · `dms_position_reason` | Toàn bộ (nhỏ) |
| Biểu mẫu | `fld_form` + schema | Còn hiệu lực với mình |
| Ô động điểm bán | `fld_field` của form `crm_customer` | Toàn bộ |

🔴 **Đọc "của tôi" phải dùng TẬP MÃ (`codes()`), không phải một mã.** Một người có nhiều mã NV; so mã đơn
làm người vừa đổi công ty mất sạch điểm bán của chính mình.

🔴 **Mọi action `/dms/sync/*` phải có `requirePermission()` ở dòng đầu** và áp OrgScope **giống hệt** các
action anh em cùng controller. Endpoint sync không gác quyền không phải "tiện cho app" — nó mở toàn bộ
8.730 điểm bán cho mọi tài khoản đã đăng nhập. Thêm action xong phải `rbac/scan` + gán vai + điền
`description` tiếng Việt, nếu không deny-by-default trả 403 cho đúng người cần dùng.

### 7.2 Delta theo `updated_at` — và cái bẫy đã đo

```
GET /dms/sync/pull?entity=customer&since=2026-09-15T08:00:00+07:00&limit=500
→ { "items":[…], "next_since":"…", "has_more":true, "server_time":"…" }
```

🔴 **Đo trực tiếp 15/09/2026 trên `app_test`: xoá mềm KHÔNG cập nhật `updated_at`.**

Cách đo: tạo một `crm_customer` thử, chờ 2 giây, gọi `softDelete()`, đọc lại hai cột — `updated_at`
**15:43:04**, `deleted_at` **15:43:06** (bản ghi thử đã xoá cứng sau khi đo). Nguyên nhân nằm ngay trong
`SoftDeleteTrait::softDelete()`: `save(false, ['deleted_at'])` giới hạn danh sách thuộc tính được ghi, nên
giá trị `updated_at` mà `TimestampBehavior` vừa đặt trong `beforeSave` **bị lọc ra trước khi vào câu UPDATE**.

**Hệ quả nếu cứ dùng `since=updated_at`:** điểm bán bị xoá **không bao giờ xuất hiện trong delta** ⇒ nó
sống vĩnh viễn trên máy nhân viên, vẫn hiện trong ô tìm kiếm, vẫn check-in vào được, và lượt ghé đó trỏ tới
một điểm bán mà web đã coi là không còn. Không có lỗi nào báo, ở cả hai đầu.

**Ba cách vá, chọn cách 2:**

| Cách | Làm gì | Vì sao chọn / không |
|---|---|---|
| 1 | Sửa `SoftDeleteTrait` để chạm `updated_at` | Chạm hạ tầng dùng chung của **mọi** module xoá mềm — rủi ro lan rộng vì một nhu cầu của DMS |
| **2** | **Mốc delta = `GREATEST(c.updated_at, c.deleted_at, a.updated_at, a.deleted_at)`**, và trả bản đã xoá dưới dạng **tombstone** `{"id":…, "deleted":true}` | Cục bộ trong endpoint sync, không đụng ai; app xoá bản ghi khỏi SQLite khi gặp tombstone |
| 3 | App tải lại toàn bộ định kỳ | 8.730 dòng mỗi lần — đúng thứ delta sinh ra để tránh |

⚠️ **Tombstone phải có hạn.** App lâu không mở (nghỉ 2 tháng) rồi pull một lần: nếu server chỉ giữ tombstone
30 ngày mà máy lệch 60 ngày thì bản ghi đã xoá bị bỏ sót. Luật: `since` cũ hơn
`dms.sync.tombstoneRetentionDays` ⇒ server trả `full_resync_required: true`, app xoá kho cục bộ và tải lại.
🔴 **Hàng đợi GỬI không bị xoá trong ca này** — nó là dữ liệu chưa ai có; xoá là mất trắng việc của nhân viên.

### 7.3 Đổi phân công cũng phải đẩy được tombstone

Ca thật: điểm bán không đổi gì, nhưng **phân công bị gỡ** khỏi nhân viên A. `crm_customer.updated_at` không
đổi (không ai sửa điểm bán) ⇒ delta theo mình cột đó **không bao giờ** báo cho máy của A. A vẫn thấy, vẫn
check-in vào điểm bán không còn thuộc mình.

⇒ Mốc delta của `entity=customer` phải tính cả `crm_customer_assignment` của chính người đó, và **gỡ phân
công sinh tombstone** y như xoá điểm bán. Bảng phân công dùng chung base AR nên dính **đúng cái bẫy
`updated_at` ở §7.2** — đó là lý do công thức `GREATEST` ở trên có cả `a.deleted_at`.

### 7.4 Tải lần đầu

p90 là **991** điểm bán/người, max **1.523**. Với ~1,5 KB JSON mỗi điểm bán (ước, gồm ô động) thì lần đầu
tải ~1,5 MB — chấp nhận được **nếu có phân trang** (`pullPageSize` 500) và **nếu làm khi còn WiFi**. App
phải: hiện tiến độ, cho ngắt giữa chừng, và **ghi mốc `next_since` sau MỖI trang** — mất sóng ở trang 2/3
mà mốc chưa ghi thì lần sau tải lại từ đầu.

⚠️ **Tìm điểm bán offline phải lưu sẵn cột không dấu.** SQLite không có `unaccent`; bỏ dấu lúc truy vấn thì
không dùng được index và gõ "nguyen" sẽ không ra "Nguyễn". Ghi `name_unaccent` lúc nạp vào SQLite.

---

## 8. Xung đột và thử lại

### 8.1 Xung đột — ai thắng, theo từng loại

| Dữ liệu | Ai thắng | Vì sao |
|---|---|---|
| **Bản ghi MỚI từ app** (lượt ghé, khai báo vị trí, điểm bán mới, phiếu biểu mẫu) | **app** | Server không có gì để tranh; chỉ cần chống trùng |
| **Lượt ghé / khai báo vị trí đã ghi** | **không ai** — append-only | Bảng không có `updated_at`; sửa phải qua luồng có log, không qua sync |
| **Check-out** | **lần ghi đầu tiên** | §5.5 — giá trị khác thì `INVALID`, không đè |
| **Danh mục** (loại, kênh, khu vực, lý do, ô động) | **server** | Nguồn sự thật; app chỉ đọc |
| **Sửa điểm bán ĐÃ CÓ** | ⚠️ xem dưới | |

🔴 **Sửa điểm bán đã có là ca khó, và giai đoạn này CHƯA mở cho app.** Chừng nào còn đồng bộ từ MobiWork thì
**MobiWork thắng** — đã đo: sửa `contact_title` rồi chạy lại di trú, giá trị về `NULL`. Cho app sửa offline
trong giai đoạn này là hứa với nhân viên một thứ hệ thống sẽ xoá.

Sau cutover, khi One làm chủ, dùng **so sánh theo TRƯỜNG** (không phải theo bản ghi):
- app gửi kèm `base_updated_at` — mốc của bản ghi lúc app tải về;
- server đối chiếu: trường nào **server đã đổi sau mốc đó** thì từ chối riêng trường ấy, trả
  `CONFLICT_FIELDS: ["phone"]`, các trường còn lại vẫn ghi;
- app hiện cho người dùng đúng những trường bị từ chối, kèm giá trị hai bên.

Khoá cả bản ghi vì một trường lệch là bắt người dùng nhập lại cả form — họ sẽ ghi đè bừa cho xong.

⚠️ Riêng `custom_labels` (jsonb) hợp nhất theo **từng khoá** (`custom_labels || new`), không thay cả cột:
hai người sửa hai ô khác nhau thì không ai mất việc của ai.

### 8.2 Thử lại

```
lần 1: ngay
lần 2: +2s      lần 3: +4s      lần 4: +8s      lần 5: +16s
lần 6+: +5 phút (trần), mãi mãi — KHÔNG có "số lần tối đa" cho lỗi mạng
```

| Loại lỗi | Ví dụ | Xử lý |
|---|---|---|
| **Mạng / 5xx / timeout** | mất sóng, server lỗi | thử lại **vô hạn** theo backoff — dữ liệu người dùng không được bỏ vì server hôm đó hỏng |
| **401** | token hết hạn | làm mới token rồi thử lại **ngay**, không tính là một lần thất bại |
| **403** | thiếu quyền | `dead` + hiện thông báo — thử lại vô ích |
| **422 / `INVALID`** | payload sai luật | `dead` + hiện lỗi từng trường |
| **404 khi gửi ảnh / check-out** | bản ghi cha chưa vào | **giữ `pending`**, đẩy xuống cuối hàng, **không** tăng `attempts` |
| **`PENDING_PARENT`** | cha cùng lô chưa vào | như trên |

⚠️ **Thêm nhiễu ngẫu nhiên (jitter) ±20% vào mỗi mốc backoff.** Không có nó thì 66 máy mất sóng cùng lúc vì
sập một trạm sẽ gửi lại **đồng loạt cùng giây** khi sóng về.

⚠️ **`404`/`PENDING_PARENT` không được tăng `attempts`** — nếu tăng, một lượt ghé chờ điểm bán cha sẽ leo
lên mốc backoff 5 phút rồi nằm đó, dù cha đã vào từ lâu.

### 8.3 Không bao giờ sinh lại `client_uuid` khi thử lại

Nhắc lại vì đây là chỗ dễ sai nhất khi refactor: thử lại là gửi **cùng một payload**, gồm cùng `client_uuid`.
Mã nào sinh UUID nằm trong hàm gửi là **sai thiết kế**, kể cả khi test đang xanh. Một phép kiểm tĩnh rẻ:
`grep -rn "Uuid()" lib/core/network/` phải **không** ra kết quả nào.

---

## 9. Kịch bản kiểm thử

Chạy trên **máy thật ở chế độ máy bay**, không phải giả lập — giả lập không tái hiện được chuyển mạng
4G↔WiFi và việc HĐH giết tiến trình nền.

### 9.1 Mất mạng

| Mã | Kịch bản | Kết quả phải đạt |
|---|---|---|
| **TC-OFF-01** | Bật máy bay → tạo 1 lượt ghé + 3 ảnh → tắt máy bay | 1 dòng `dms_visit`, 3 dòng `dms_visit_photo`, không trùng, `is_offline_sync = true` |
| **TC-OFF-02** | Mất sóng **giữa lúc gửi** (server đã nhận, app chưa nhận phản hồi) | Lần sau trả `ALREADY_EXISTS`, DB vẫn **1 dòng** |
| **TC-OFF-03** | Gửi cùng `client_uuid` **10 lần** liên tiếp | **1 dòng**, 9 lần sau `ALREADY_EXISTS` cùng `id` |
| **TC-OFF-04** | Gửi ảnh trước khi bản ghi cha vào | `404`, **không** tạo bản ghi cha; ảnh giữ `pending`, `attempts` **không tăng**; vào được ở lượt sau |
| **TC-OFF-05** | Tạo 50 lượt ghé offline rải 3 ngày → mở mạng | Đủ 50 dòng, `client_time`/`visit_date` giữ đúng ngày tạo, `server_received_at` là ngày gửi, **`is_time_tampered = false` cả 50** |
| **TC-OFF-06** | Giết app giữa lúc hàng đợi đang chạy → mở lại | Hàng đợi tiếp tục, không mất mục, không gửi trùng; mục `sending` mồ côi về `pending` (§3.3 luật 5) |
| **TC-OFF-07** | Mở điểm bán mới **offline** rồi check-in ngay vào nó | Cả hai vào server, `dms_visit.customer_id` trỏ đúng điểm bán vừa tạo; **không** có lượt ghé mồ côi |
| **TC-OFF-08** | Như trên nhưng lô bị cắt: chỉ điểm bán vào được | Lượt ghé nhận `PENDING_PARENT`, giữ `pending`, vào ở lô sau |
| **TC-OFF-09** | Check-in offline, check-out offline 40 phút sau, gửi cả hai | 1 dòng, `checkout_at` đúng, `duration_seconds ≈ 2400` |
| **TC-OFF-10** | Gửi lại đúng lệnh check-out lần hai | `ALREADY_EXISTS`, `checkout_at` **không đổi** |
| **TC-QUEUE-01** | Một mục `INVALID` nằm giữa 200 mục hợp lệ (kiểm cả ca cùng một lô 50 mục) | Mục đó `dead`, **199 mục kia vẫn đi** — bắt được lỗi `25P02` nếu thiếu SAVEPOINT (§4.4) |
| **TC-QUEUE-02** | 4G ↔ WiFi đổi qua lại khi đang gửi | Không mục nào mất, không mục nào gửi hai lần |
| **TC-QUEUE-03** | Hàng đợi tồn 30 giờ | App hiện cảnh báo đỏ theo `staleQueueAlertHours` |

### 9.2 Đổi giờ máy

| Mã | Kịch bản | Kết quả phải đạt |
|---|---|---|
| **TC-TIME-01** | Chỉnh đồng hồ **lùi 50 phút** → check-in → gửi ngay | `time_diff ≈ +3.000`, `queued ≈ 0`, `clock_skew ≈ +3.000` ⇒ **`is_time_tampered = true`**, lượt ghé **vẫn được ghi** |
| **TC-TIME-02** | Chỉnh **lùi 50 phút** → check-in → **để hàng đợi 6 giờ** rồi gửi | `time_diff ≈ +24.600`, `queued ≈ 21.600`, `clock_skew ≈ +3.000` ⇒ **vẫn `true`** — ca mà luật "chỉ gắn cờ khi lệch âm" bỏ lọt |
| **TC-TIME-03** | Chỉnh **tiến 2 ngày** → check-in → trả giờ về → gửi | `client_time` là giờ đã chỉnh, `server_received_at` giờ thật, `clock_skew` **âm** lớn ⇒ cờ bật |
| **TC-TIME-04** | Đổi múi giờ máy (VN → Bangkok) khi còn mục chờ | Mốc gửi lên vẫn có offset đúng; **giờ tuyệt đối không đổi**; cờ **không** bật |
| **TC-TIME-05** | Tạo lúc 23:58, gửi lúc 00:05 hôm sau | `visit_date` = **ngày tạo**, không phải ngày gửi |
| **TC-TIME-06** | Đồng hồ lệch **trong ngưỡng** (< 5 phút) | `is_time_tampered = false` — không báo động giả |
| **TC-TIME-07** | Khởi động lại máy khi còn mục trong hàng đợi, rồi gửi | `queued_seconds` gửi **`null`**, server **không** gắn cờ, bản ghi vào bình thường (§6.3) |

🔴 **TC-TIME-01 phải GHI ĐƯỢC.** Cờ `is_time_tampered` để người quản lý soi, **không phải để chặn**: chặn
thì một máy sai giờ làm nhân viên không ghi được cả ngày, và họ sẽ bỏ dùng app.

### 9.3 Pull

| Mã | Kịch bản | Kết quả phải đạt |
|---|---|---|
| **TC-PULL-01** | Web xoá mềm một điểm bán → app pull | Điểm bán **biến mất** khỏi SQLite (tombstone, §7.2) |
| **TC-PULL-02** | Gỡ phân công một điểm bán khỏi NV → app của NV đó pull | Điểm bán biến mất; app của NV khác **không** đổi |
| **TC-PULL-03** | `since` cũ hơn hạn tombstone | `full_resync_required: true`; app tải lại, **hàng đợi gửi còn nguyên** |
| **TC-PULL-04** | Mất sóng ở trang 2/3 của lần tải đầu | Lần sau tiếp từ trang 2, không tải lại từ đầu |
| **TC-PULL-05** | Tài khoản NV A pull | Chỉ ra điểm bán của A (TB 354, p90 991), **không** ra 8.730 |
| **TC-PULL-06** | Gõ "nguyen" trong ô tìm điểm bán khi **offline** | Ra "Nguyễn…" (cột `name_unaccent`, §7.4) |

### 9.4 Đối soát sau mỗi đợt kiểm thử

Không nghiệm thu bằng "app chạy đẹp". Đếm trên DB:

```sql
-- không trùng
SELECT client_uuid, count(*) FROM dms_visit
 WHERE client_uuid IS NOT NULL GROUP BY 1 HAVING count(*) > 1;   -- phải RỖNG

-- phân bố theo NGÀY, không phải tổng số dòng (bài học di trú: tổng khớp mà mọi ngày đều sai)
SELECT visit_date, count(*) FROM dms_visit
 WHERE is_offline_sync GROUP BY 1 ORDER BY 1;

-- ảnh mồ côi (CHECK ck_dms_photo_owner đã chặn; câu này bắt ca lách qua SQL tay)
SELECT count(*) FROM dms_visit_photo WHERE visit_id IS NULL AND declaration_id IS NULL;  -- phải 0

-- ảnh gửi trùng (sau khi có cột ở §4.2)
SELECT client_uuid, count(*) FROM dms_visit_photo
 WHERE client_uuid IS NOT NULL GROUP BY 1 HAVING count(*) > 1;   -- phải RỖNG

-- cờ đổi giờ phải HIẾM. Trên 5% thì công thức §6.3 sai, không phải nhân viên gian
SELECT round(count(*) FILTER (WHERE is_time_tampered) * 100.0 / nullif(count(*),0), 2)
  FROM dms_visit WHERE is_offline_sync;
```

---

## 10. Việc phải làm, theo thứ tự phụ thuộc

| # | Việc | Ở đâu | Chặn bởi |
|---|---|---|---|
| 1 | Migration thêm `client_uuid` + partial unique cho **`dms_visit_photo`** (§4.2) | `common/modules/dms/migrations/` | — |
| 2 | `DmsSettingProvider` + 6 khoá ở §6.4 | `common/modules/dms/settings/` | — |
| 3 | `POST /dms/sync/push` (lô trộn loại, kết quả từng bản ghi, SAVEPOINT từng mục) | `api/modules/dms/` | 2 |
| 4 | `PATCH /dms/visits/by-uuid/{uuid}/photos` · `…/checkout` | `api/modules/dms/` | 1, 3 |
| 5 | `GET /dms/sync/pull` + tombstone + phạm vi theo phân công (§7) | `api/modules/dms/` | 2 |
| 6 | `rbac/scan` + gán vai + **mô tả tiếng Việt** cho mọi action mới | — | 3, 4, 5 |
| 7 | Ca `TC-OFF-*` / `TC-QUEUE-*` / `TC-PULL-*` chạy bằng **script curl**, trước khi app có | `common/tests/` | 3, 4, 5 |
| 8 | `drift` + `uuid` vào `pubspec.yaml`, dựng schema SQLite (§3.1) | repo app | — |
| 9 | Hàng đợi + bộ gửi + backoff + hồi phục `sending` | repo app | 8 |
| 10 | Màn "Đồng bộ" (mục chờ, mục `dead`, nút gửi lại, cảnh báo tồn đọng) | repo app | 9 |
| 11 | Ca `TC-TIME-*` trên **máy thật** | — | 9 |

⚠️ **Việc 7 làm được ngay, không chờ app.** Hợp đồng server kiểm được bằng curl; để tới lúc có app mới phát
hiện `ALREADY_EXISTS` trả sai mã HTTP là muộn hai tuần.

⚠️ **`api/modules/dms/` chưa tồn tại** — module `dms` mới có migration và service di trú. Việc 3 là endpoint
đầu tiên, nên nó cũng là nơi lần đầu phải khai URL rule **đúng verb** (`POST`/`PATCH`/`GET`) ở
`api/config/main.php`: thiếu rule cho đúng verb thì action ghi trả 404/405 im lặng.

⚠️ **Việc 1 là migration THÊM cột** — `api/` chạy thẳng từ repo, nên phải áp **ngay trong cùng lần sửa** với
code đọc cột đó. Chạy bằng `bash scripts/migrate.sh`, đọc danh sách migration sẽ áp **trước khi** Enter:
lệnh này áp mọi migration chưa áp của **mọi phiên**, không riêng của mình.

---

## 11. Những gì tài liệu này CỐ Ý không giải quyết

- **Sửa/xoá bản ghi nghiệp vụ từ app khi offline.** Đợt 1 app chỉ TẠO, cộng check-out (cập nhật **một lần,
  một trường**, §5.5). Sửa tự do khi offline cần vector version hoặc CRDT — chi phí không tương xứng.
- **Đồng bộ hai chiều cho điểm bán.** Chừng nào còn MobiWork thì nó thắng; sau cutover mới bàn (§8.1).
- **Tuyến (`dms_route*`) và biểu mẫu (`dms_form_config`).** Hai nhánh đang rỗng có chủ ý (Q7/Q8 của spec di
  trú). Khi mở, chúng chỉ thêm loại vào `entity` của hàng đợi, không đổi cơ chế.
- **GPS nền.** Đã gỡ khỏi phạm vi 09/09 (`SPEC-CRM-DMS` §6.6) — không có hàng đợi riêng cho nó.
- **Nén/giảm chất lượng ảnh.** Thuộc app, không thuộc hợp đồng đồng bộ. Chỉ chốt một con số: ~77 KB/ảnh sau
  nén, dùng để ước băng thông.
- **Mã hoá kho SQLite trên máy.** Máy mất thì dữ liệu điểm bán (tên, điện thoại, toạ độ) đọc được. Nếu cần,
  đó là quyết định về thiết bị, không phải về đồng bộ.

---

## 12. Câu chờ chủ hệ thống chốt

| # | Câu hỏi | Đề xuất của tài liệu |
|---|---|---|
| **Q1** | Lượt ghé vào điểm bán **mở mới chưa được duyệt** (`approval_status='pending'`) có hợp lệ không? | **Có** — nhân viên đã thực sự đến nơi; báo cáo lọc riêng nhóm này |
| **Q2** | Điểm bán bị **`rejected`** thì các lượt ghé đã trỏ vào nó xử lý ra sao? | Giữ lượt ghé, đánh dấu để người quản lý xử lý tay; **không** xoá dữ liệu nhân viên đã ghi |
| **Q3** | `is_time_tampered` dùng vào việc gì trong quản trị? | **Chỉ để soi**, không chặn, không tự động kỷ luật (§6.3) |
| **Q4** | Giữ mục hàng đợi đã gửi bao lâu trên máy? | **7 ngày** (`queueKeepDoneDays`) |
| **Q5** | Hạn tombstone phía server? | **90 ngày**; quá hạn thì app tải lại từ đầu (§7.2) |
| **Q6** | Nhân viên xem lại lượt ghé cũ của chính mình khi offline được bao xa? | Cần chốt — nó quyết định lượng dữ liệu pull về máy; đề xuất **90 ngày gần nhất** |

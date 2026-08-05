# Hướng dẫn kiểm thử thủ công — Data Freshness

Tài liệu này dùng cho tester trên **local hoặc staging**, không dùng trực tiếp
trên production. Mục tiêu là xác nhận dữ liệu cào được kiểm tra lại, thay đổi
rủi ro đi qua hàng chờ quản trị, và người dùng có thể báo thông tin sai.

## 1. Chuẩn bị

### Tài khoản và môi trường

- Một tài khoản user thường đã đăng nhập được vào ứng dụng.
- Một tài khoản admin có `user_account.role = 'admin'`.
- Supabase local/staging đã chạy migration
  `20260803000100_data_freshness.sql`.
- Đã deploy `data-freshness-check` và `data-freshness`.
- Trên staging, `DATA_FRESHNESS_CHECK_SECRET` của Edge Function phải trùng
  Vault secret `data_freshness_check_secret`.

Không chụp secret, access token, email thật hoặc dữ liệu cá nhân vào bằng
chứng kiểm thử.

### Chạy ứng dụng

User app:

```powershell
cd D:\Work\hello-vietnam\frontend
flutter run -d chrome --web-port=3000
```

Admin app:

```powershell
cd D:\Work\hello-vietnam\frontend
flutter run -d chrome --target=lib/main_admin.dart --web-port=3001
```

Các URL chính:

- User: `http://localhost:3000`
- Admin Data Freshness: `http://localhost:3001/admin/data-freshness`

## 2. Chuẩn bị dữ liệu test

Chạy SQL trên **local/staging**. Trước tiên lấy ít nhất bốn địa điểm đang
hoạt động:

```sql
select id_place, name
from public.place
where coalesce(status, 'active') = 'active'
order by created_at nulls last
limit 4;
```

Gán UUID vào các biến:

| Biến | Dùng cho |
|---|---|
| `<PLACE_STALE>` | Cảnh báo stale và tab stale |
| `<PLACE_REVIEW>` | Proposal cần duyệt |
| `<PLACE_EVENT>` | Sự kiện đã hết hạn |
| `<PLACE_MISSING>` | Nguồn trả về 404 hai lần |

### 2.1. Tạo trạng thái stale

```sql
insert into public.content_freshness (
  content_type, content_id, source_type, source_url, source_external_id,
  availability_type, freshness_status, next_check_at
)
values (
  'place', '<PLACE_STALE>', 'wikipedia',
  'https://en.wikipedia.org/wiki/Hoi_An',
  'wikipedia:https://en.wikipedia.org/wiki/Hoi_An',
  'business', 'stale', now() - interval '1 minute'
)
on conflict (content_type, content_id) do update set
  source_type = excluded.source_type,
  source_url = excluded.source_url,
  source_external_id = excluded.source_external_id,
  availability_type = excluded.availability_type,
  freshness_status = excluded.freshness_status,
  consecutive_missing_count = 1,
  next_check_at = excluded.next_check_at,
  last_error = null;
```

### 2.2. Tạo proposal cần duyệt

```sql
with freshness as (
  select id
  from public.content_freshness
  where content_type = 'place' and content_id = '<PLACE_REVIEW>'
), cleanup as (
  delete from public.content_change_proposal
  where freshness_id = (select id from freshness) and decision = 'pending'
)
insert into public.content_change_proposal (
  freshness_id, change_type, before_data, proposed_data,
  changed_fields, reason, confidence, decision
)
select
  f.id,
  'possibly_closed',
  jsonb_build_object('name', p.name, 'status', coalesce(p.status, 'active')),
  '{"status":"archived"}'::jsonb,
  '["status"]'::jsonb,
  'possibly_closed', 0.95, 'pending'
from freshness f
join public.place p on p.id_place = '<PLACE_REVIEW>';

update public.content_freshness
set freshness_status = 'needs_review',
    consecutive_missing_count = 2,
    next_check_at = now()
where content_type = 'place' and content_id = '<PLACE_REVIEW>';
```

### 2.3. Tạo scheduled event đã hết hạn

```sql
update public.content_freshness
set source_type = 'wikipedia',
    source_url = 'https://en.wikipedia.org/wiki/Water_puppetry',
    source_external_id = 'wikipedia:https://en.wikipedia.org/wiki/Water_puppetry',
    availability_type = 'scheduled_event',
    valid_until = now() - interval '1 hour',
    freshness_status = 'due',
    next_check_at = now(),
    last_error = null
where content_type = 'place' and content_id = '<PLACE_EVENT>';
```

### 2.4. Tạo nguồn OSM chắc chắn không tồn tại

Node ID dưới đây chỉ dùng cho staging/local để adapter nhận HTTP 404 hợp lệ:

```sql
update public.content_freshness
set source_type = 'osm',
    source_url = 'https://www.openstreetmap.org/node/999999999999999',
    source_external_id = 'osm:node:999999999999999',
    availability_type = 'business',
    freshness_status = 'due',
    consecutive_missing_count = 0,
    source_hash = null,
    next_check_at = now(),
    last_error = null
where content_type = 'place' and content_id = '<PLACE_MISSING>';
```

## 3. Gọi checker thủ công

Chỉ thực hiện trên local/staging. Không ghi secret vào shell history hoặc ảnh
chụp màn hình.

```powershell
$headers = @{
  "Content-Type" = "application/json"
  "x-data-freshness-secret" = $env:DATA_FRESHNESS_CHECK_SECRET
}

Invoke-RestMethod `
  -Uri "https://<PROJECT_REF>.supabase.co/functions/v1/data-freshness-check" `
  -Method Post `
  -Headers $headers `
  -Body '{"triggerType":"admin"}'
```

Kết quả phải có `runId`, `selectedCount`, `checkedCount`, `failedCount` và
`status`. Truy vấn trạng thái:

```sql
select id, trigger_type, status, selected_count, checked_count,
       unchanged_count, proposal_count, auto_applied_count,
       failed_count, started_at, finished_at, error_summary
from public.content_update_run
order by started_at desc
limit 5;

select content_type, content_id, freshness_status,
       consecutive_missing_count, source_hash, last_error,
       last_checked_at, last_verified_at, next_check_at
from public.content_freshness
where content_id in (
  '<PLACE_STALE>', '<PLACE_REVIEW>', '<PLACE_EVENT>', '<PLACE_MISSING>'
)
order by content_id;
```

## 4. Checklist kiểm thử thủ công

Tester đánh dấu `Pass`, `Fail` hoặc `Blocked`, ghi bước tái hiện nếu Fail và
chụp ảnh chỉ phần giao diện cần thiết.

### DF-01 — Hiển thị cảnh báo stale

- **Dữ liệu:** Mục 2.1.
- **Thao tác:** Mở Explore, tìm `<PLACE_STALE>`, mở chi tiết.
- **Mong đợi:** Địa điểm vẫn xuất hiện, có banner “Thông tin chưa được xác
  minh gần đây”, và có nút báo thông tin sai.

### DF-02 — User gửi báo cáo sai

- **Tài khoản:** User thường.
- **Thao tác:** Nhấn biểu tượng báo cáo; chọn “Sai giờ mở cửa”; nhập ghi chú;
  nhấn Submit.
- **Mong đợi:** Hiển thị gửi thành công và có bản ghi `open`:

  ```sql
  select content_type, content_id, reason, status, note
  from public.content_report
  where content_id = '<PLACE_STALE>'
  order by created_at desc;
  ```

- Gửi lại cùng lý do phải báo trùng và không tạo thêm report `open`.

### DF-03 — Admin xem báo cáo

- **Tài khoản:** Admin.
- **Thao tác:** Mở `/admin/data-freshness`, chọn `Báo sai`.
- **Mong đợi:** Report DF-02 hiện đúng loại nội dung, lý do, ghi chú và thời
  gian.

### DF-04 — Admin xem stale và yêu cầu kiểm tra lại

- **Dữ liệu:** Mục 2.1.
- **Thao tác:** Chọn `Dữ liệu stale`, nhấn `Kiểm tra lại` trên `<PLACE_STALE>`.
- **Mong đợi:** Không lỗi quyền; `next_check_at` được đặt về hiện tại và
  `freshness_status = 'due'`.

### DF-05 — Admin duyệt proposal và archive

- **Dữ liệu:** Mục 2.2.
- **Thao tác:** Chọn `Chờ duyệt`, tìm `<PLACE_REVIEW>`, nhấn Approve.
- **Mong đợi:** Proposal thành `approved`, `place.status` thành `archived`,
  địa điểm biến mất khỏi Explore và Trip Planner.

  ```sql
  select id_place, name, status
  from public.place
  where id_place = '<PLACE_REVIEW>';
  ```

### DF-06 — Scheduled event tự hết hạn

- **Dữ liệu:** Mục 2.3.
- **Thao tác:** Gọi checker ở mục 3.
- **Mong đợi:** Freshness thành `expired`, canonical row thành `expired`, có
  proposal `auto_applied`/`auto_expired`, và nội dung bị ẩn khỏi Explore.

### DF-07 — Missing lần thứ nhất chỉ stale

- **Dữ liệu:** Mục 2.4; gọi checker một lần.
- **Mong đợi:** Counter bằng `1`, freshness `stale`, canonical row vẫn
  `active`, chưa có proposal pending mới.

### DF-08 — Missing lần thứ hai tạo proposal

- **Thao tác:** Gọi checker lần thứ hai sau DF-07.
- **Mong đợi:** Counter bằng `2`, freshness `needs_review`, có một proposal
  `possibly_closed`, canonical row chưa tự archive và bị loại khỏi Explore/
  Trip Planner.

### DF-09 — Lỗi adapter không tăng missing counter

Chuẩn bị một dòng test riêng rồi gọi checker:

```sql
update public.content_freshness
set source_type = 'manual_test_provider', source_url = null,
    freshness_status = 'due', consecutive_missing_count = 0,
    source_hash = 'keep-this-hash', next_check_at = now(), last_error = null
where content_type = 'place' and content_id = '<PLACE_STALE>';
```

- **Mong đợi:** Counter vẫn `0`, hash vẫn `keep-this-hash`, freshness không bị
  chuyển do missing, và `last_error` có nội dung lỗi.
- Sau test, chạy lại mục 2.1 để khôi phục `<PLACE_STALE>`.

### DF-10 — Archive từ admin content/food

- Mở `Activity`, `Culture`, `Local Product` hoặc `Food` trong admin.
- Chọn một bản ghi test, nhấn biểu tượng archive và xác nhận.
- **Mong đợi:** Hộp thoại nói bản ghi được giữ lại cho lịch sử; tải lại danh
  sách thì status của bản ghi là `archived`. Với Food, bản ghi archived không
  còn trong danh sách Food đang hoạt động; với Activity/Culture/Local Product,
  bản ghi có thể vẫn hiện trong admin để phục vụ audit và khôi phục thủ công.
  Ở phía user, bản ghi archived phải biến mất khỏi Explore.
- Không dùng Province cho case này vì Province là dữ liệu cấu trúc và vẫn có
  thao tác delete cũ.

### DF-11 — Crawler idempotency (tuỳ chọn)

Chỉ chạy khi có credential staging và được phép gọi nguồn ngoài:

```powershell
cd D:\Work\hello-vietnam\backend\crawldata
python crawl_seed_data_fixed_v3.py --mode activity --limit 5 --upsert
python crawl_seed_data_fixed_v3.py --mode activity --limit 5 --upsert
```

Lần thứ hai không tạo activity mới cho cùng Wikipedia URL; mô tả, gallery,
tag và rating biên tập không bị crawler ghi đè. Với OSM, cùng
`osm:node:<id>` phải giữ nguyên `id_place`.

## 5. Bằng chứng cần gửi lại

Gửi một thư mục hoặc file zip gồm:

1. Bảng kết quả DF-01 đến DF-11 (`Pass`/`Fail`/`Blocked`).
2. Ảnh cho DF-01, DF-02, DF-03, DF-04, DF-05 và DF-10.
3. JSON response của checker ở DF-06 đến DF-09.
4. Kết quả các truy vấn SQL tương ứng, che UUID/email nếu cần.
5. Nếu Fail: thời gian, tài khoản/role, UUID test, bước tái hiện và lỗi đầy đủ.

Mẫu ghi kết quả:

| Test | Kết quả | Bằng chứng | Ghi chú |
|---|---|---|---|
| DF-01 |  |  |  |
| DF-02 |  |  |  |
| DF-03 |  |  |  |
| DF-04 |  |  |  |
| DF-05 |  |  |  |
| DF-06 |  |  |  |
| DF-07 |  |  |  |
| DF-08 |  |  |  |
| DF-09 |  |  |  |
| DF-10 |  |  |  |
| DF-11 |  |  |  |

## 6. Dọn dữ liệu test

Chỉ chạy trên local/staging. Không xoá canonical content thật trên
production. Khôi phục các dòng đã archive/expired nếu muốn giữ dữ liệu demo:

```sql
update public.place
set status = 'active'
where id_place in (
  '<PLACE_STALE>', '<PLACE_REVIEW>', '<PLACE_EVENT>', '<PLACE_MISSING>'
);

update public.content_freshness
set freshness_status = 'fresh',
    availability_type = 'business',
    valid_until = null,
    consecutive_missing_count = 0,
    source_hash = null,
    last_error = null,
    next_check_at = now() + interval '30 days'
where content_type = 'place'
  and content_id in (
    '<PLACE_STALE>', '<PLACE_REVIEW>', '<PLACE_EVENT>', '<PLACE_MISSING>'
  );
```

Nên giữ lại `content_change_proposal`, `content_report` và
`content_update_run` để làm audit trail. Nếu staging cần làm sạch hoàn toàn,
xoá riêng các UUID test sau khi đã xuất bằng chứng.

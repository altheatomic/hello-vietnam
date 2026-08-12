# Runbook demo Data Crawler và Data Freshness

Tài liệu này dành cho buổi demo trên **local hoặc staging**. Không chạy fixture,
`--upsert` hoặc SQL thay đổi dữ liệu trên production.

## 1. Mục tiêu demo

Demo gồm ba phần độc lập:

1. **Manual crawler:** crawler lấy dữ liệu từ nguồn, xuất JSON/CSV và có thể upsert
   vào Supabase.
2. **Freshness checker:** checker rà các bản ghi đến hạn, kiểm tra OSM/Wikipedia,
   ghi run history và tạo proposal khi phát hiện thay đổi rủi ro.
3. **Admin review:** admin xem stale/proposal/run history và duyệt hoặc từ chối
   thay đổi.

Thông điệp cần nói rõ: freshness checker không tự chạy lại toàn bộ Python crawler;
nó là lớp kiểm tra nguồn và kiểm soát thay đổi sau khi dữ liệu đã được nhập.

## 2. Chuẩn bị một lần

### 2.1. Python crawler

Tạo môi trường riêng trong `backend/crawldata`:

```powershell
cd backend\crawldata
py -3.11 -m venv .demo-venv
.\.demo-venv\Scripts\python.exe -m pip install --upgrade pip
.\.demo-venv\Scripts\python.exe -m pip install -r requirements-demo.txt
.\.demo-venv\Scripts\python.exe -c "import requests, bs4, lxml, dotenv, supabase; print('crawler dependencies: ok')"
.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py --help
```

Nếu máy chỉ có Python 3.14, dùng `py -3.14` thay cho `py -3.11`.

### 2.2. Helper chạy nhanh

Từ thư mục gốc repo, có thể chạy preflight và crawler mà không ghi đè output
đang tracked. Crawler helper ghi file vào thư mục tạm của Windows:

```powershell
cd .
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\data-freshness-demo.ps1 -Mode preflight -SupabaseUrl $env:SUPABASE_URL
.\scripts\data-freshness-demo.ps1 -Mode crawler -Limit 5
```

Sau khi đã set secret trong terminal hiện tại, trigger checker bằng:

```powershell
.\scripts\data-freshness-demo.ps1 -Mode checker -CheckerBatchSize 5 -SupabaseUrl $env:SUPABASE_URL
```

Nếu secret chưa có, helper dừng với mã `2` và không in giá trị secret. Không lưu
secret vào file `.ps1`, `.env` tracked hoặc ảnh chụp màn hình.

### 2.3. Supabase owner-only setup

Các bước này cần người có quyền Supabase và không đưa secret vào source code:

- Migration `backend/supabase/migrations/20260803000100_data_freshness.sql` đã
  được apply ở local/staging.
- Edge Function `data-freshness-check` đã deploy với **JWT verification tắt**;
  function tự xác thực bằng `x-data-freshness-secret` vì cron không gửi JWT.
- Edge Function `data-freshness` đã deploy.
- `DATA_FRESHNESS_CHECK_SECRET` đã set cho Edge Function.
- Vault secret `data_freshness_check_secret` đã set và có cùng giá trị.
- Có user đăng nhập với `user_account.role = 'admin'`.

Nếu cần deploy lại bằng CLI (sau khi đã `npx --yes supabase login`), chạy từ
repo root với project ref đích:

```powershell
npx --yes supabase functions deploy data-freshness-check `
  --project-ref <PROJECT_REF> --no-verify-jwt --workdir backend
npx --yes supabase functions deploy data-freshness `
  --project-ref <PROJECT_REF> --workdir backend
```

Không dùng `--no-verify-jwt` cho `data-freshness`; endpoint đó vẫn yêu cầu
Authorization của tài khoản admin.

Kiểm tra cron trên **local/staging**:

```sql
select jobname, schedule, active
from cron.job
where jobname = 'data-freshness-daily';
```

Cron đúng phải có schedule `15 2 * * *` (02:15 UTC). Nếu Vault secret thiếu,
cron sẽ bỏ qua request một cách an toàn.

> **Quan trọng khi dùng project khác:** migration hiện tại tạo cron với URL
> `https://ziouozppetvvdrzgojcx.supabase.co/functions/v1/data-freshness-check`.
> Nếu staging/local không phải project này, không dùng cron đó nguyên trạng; hãy
> deploy Edge Function/configure cron với URL của project đích rồi kiểm tra lại
> `cron.job` và một lần trigger thủ công.

### 2.4. Trạng thái remote đã xác minh

Với project `ziouozppetvvdrzgojcx` đã liên kết trong workspace, kiểm tra ngày
2026-08-07 cho thấy migration `20260803000100`, `20260806100000` và
`20260807000100` đã áp dụng; cron `data-freshness-daily` đang active với lịch
`15 2 * * *`; Vault và Edge Function secret có cùng digest; checker đang
`ACTIVE`, `verify_jwt = false`, còn admin API `verify_jwt = true`; database có
1 tài khoản admin.

Lượt demo nhỏ gần nhất dùng `batchSize = 5` đã `completed`, kiểm tra 5 dòng,
0 lỗi, tạo 3 proposal và 1 unchanged. Các lượt batch 50 trước đó có partial
failure do OSM rate-limit/timeout; vì vậy dùng batch 5 trong buổi demo và giữ
output run này làm bằng chứng dự phòng.

## 3. Chạy manual crawler

### 3.1. Dry run trước

Chạy không có `--upsert` để kiểm tra nguồn và tạo output cục bộ:

```powershell
cd backend\crawldata
.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py `
  --mode local_products `
  --limit 5
```

Mong đợi: terminal báo số rows và các file được tạo trong `output/`.

### 3.2. Upsert trên staging

Chỉ chạy sau khi đã export biến môi trường staging có chủ đích:

```powershell
$env:SUPABASE_URL = 'https://<staging-project-ref>.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = '<staging-service-role-key>'

.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py `
  --mode local_products `
  --limit 5 `
  --upsert
```

Sau đó kiểm tra số lượng bản ghi trong Supabase và giữ lại terminal output làm
phương án dự phòng nếu website nguồn chậm trong lúc trình bày.

Các mode khác:

```powershell
.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py --mode activity --limit 5
.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py --mode culture --limit 5
.\.demo-venv\Scripts\python.exe crawl_seed_data_fixed_v3.py --mode all --limit 5
```

### 3.3. Tình trạng nguồn đã kiểm tra

Trong lần kiểm tra chuẩn bị ngày 2026-08-07, parser chạy được sau khi cài
`lxml`. Một lần dry run trả về 0 rows, còn helper chạy lại sau đó lấy được 2
rows; nhiều URL fallback của Wikipedia vẫn trả HTTP 429. Vì vậy không coi exit
code 0 hoặc một lần crawl đơn lẻ là bằng chứng nguồn luôn ổn định. Nếu nguồn
tiếp tục rate-limit vào lúc demo, dùng output `activity.json` hoặc `culture.json`
đã chuẩn bị từ trước để minh họa payload và nói rõ đó là fallback đã cache; không
chạy lại job live nhiều lần để tránh bị rate-limit nặng hơn.

Tại thời điểm chuẩn bị, các output tracked còn có sẵn: `activity.json` (15 rows),
`culture.json` (9 rows) và `local_products.json` (9 rows). Hãy kiểm tra lại số
rows trước khi trình bày vì dữ liệu có thể được thay đổi bởi một lần crawl khác.

## 4. Chạy freshness checker trong demo

Đây là cách chạy ngay, không phải chờ cron. Secret chỉ nằm trong biến môi trường
của terminal và không chụp vào screenshot:

```powershell
$headers = @{
  'Content-Type' = 'application/json'
  'x-data-freshness-secret' = $env:DATA_FRESHNESS_CHECK_SECRET
}

Invoke-RestMethod `
  -Uri 'https://<project-ref>.supabase.co/functions/v1/data-freshness-check' `
  -Method Post `
  -Headers $headers `
  -Body '{"triggerType":"admin","batchSize":5}'
```

Response cần có:

- `runId`
- `selectedCount`
- `checkedCount`
- `failedCount`
- `status` (`completed`, `partial_failure` hoặc `failed`)

`batchSize` là tùy chọn, tối đa 50. Dùng `5` trong demo để tránh nguồn OSM
rate-limit; cron hằng ngày không truyền trường này và dùng batch mặc định 50.

Kiểm tra run mới nhất:

```sql
select id, trigger_type, status, selected_count, checked_count,
       unchanged_count, proposal_count, auto_applied_count, failed_count,
       started_at, finished_at, error_summary
from public.content_update_run
order by started_at desc
limit 5;
```

## 5. Fixture staging cho màn hình admin

Nếu không muốn phụ thuộc vào nội dung nguồn trong lúc demo, lấy hai UUID của các
place đang active:

```sql
select id_place, name
from public.place
where coalesce(status, 'active') = 'active'
order by created_at nulls last
limit 2;
```

Gán hai UUID theo thứ tự:

| UUID | Vai trò demo |
|---|---|
| thứ nhất | stale row |
| thứ hai | proposal chờ duyệt |

### 5.1. Fixture stale

```sql
insert into public.content_freshness (
  content_type, content_id, source_type, source_url, source_external_id,
  availability_type, freshness_status, consecutive_missing_count, next_check_at
)
values (
  'place', '<UUID_1>', 'wikipedia',
  'https://en.wikipedia.org/wiki/Hoi_An',
  'demo:wikipedia:stale:<UUID_1>',
  'business', 'stale', 1, now() - interval '1 minute'
)
on conflict (content_type, content_id) do update set
  source_type = excluded.source_type,
  source_url = excluded.source_url,
  source_external_id = excluded.source_external_id,
  availability_type = excluded.availability_type,
  freshness_status = excluded.freshness_status,
  consecutive_missing_count = excluded.consecutive_missing_count,
  next_check_at = excluded.next_check_at,
  last_error = null;
```

### 5.2. Fixture proposal

```sql
insert into public.content_freshness (
  content_type, content_id, source_type, source_url, source_external_id,
  availability_type, freshness_status, consecutive_missing_count, next_check_at
)
values (
  'place', '<UUID_2>', 'wikipedia',
  'https://en.wikipedia.org/wiki/Hanoi',
  'demo:wikipedia:review:<UUID_2>',
  'business', 'needs_review', 2, now()
)
on conflict (content_type, content_id) do update set
  source_type = excluded.source_type,
  source_url = excluded.source_url,
  source_external_id = excluded.source_external_id,
  availability_type = excluded.availability_type,
  freshness_status = excluded.freshness_status,
  consecutive_missing_count = excluded.consecutive_missing_count,
  next_check_at = excluded.next_check_at,
  last_error = null;

delete from public.content_change_proposal
where freshness_id = (
  select id from public.content_freshness
  where content_type = 'place' and content_id = '<UUID_2>'
) and decision = 'pending';

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
from public.content_freshness f
join public.place p on p.id_place = '<UUID_2>'
where f.content_type = 'place' and f.content_id = '<UUID_2>';

update public.content_freshness
set freshness_status = 'needs_review',
    consecutive_missing_count = 2,
    next_check_at = now()
where content_type = 'place' and content_id = '<UUID_2>';
```

## 6. Mở admin web

```powershell
cd frontend
flutter run -d chrome --target=lib/main_admin.dart --web-port=3001
```

Mở `http://localhost:3001/admin/data-freshness` bằng tài khoản admin.

Trình tự trình bày nên là:

1. Overview cards.
2. `Dữ liệu stale`: mở row stale và bấm `Kiểm tra lại`.
3. `Lịch sử chạy`: cho thấy `runId`/status của checker.
4. `Chờ duyệt`: mở proposal và bấm Approve.
5. Refresh/reopen Explore để cho thấy content đã archive hoặc được xử lý theo
   quyết định admin.

Lưu ý để nói đúng trong demo:

- Nút lớn `Tải lại dữ liệu` chỉ reload dữ liệu trang; nó không trigger checker.
- Nút `Kiểm tra lại` chỉ đặt row về `due`; checker sẽ xử lý ở lượt chạy tiếp theo.
- Admin page đang quản lý freshness/proposal/report/run history, chưa phải giao
  diện điều khiển Python crawler.

## 7. Fallback khi mạng hoặc nguồn crawl chậm

Chuẩn bị trước:

- Terminal output của một lần dry run thành công.
- Một screenshot run history có `completed` hoặc `partial_failure` hợp lệ.
- Một screenshot proposal trước khi approve.
- Các UUID fixture và SQL đã copy sẵn nhưng không chứa secret.

Khi trình bày, có thể nói checker đã được gọi thủ công để không chờ cron; cron
production dùng cùng Edge Function nhưng chạy theo lịch.

## 8. Checklist khi người dùng quay lại

- [ ] Cài `.demo-venv` và chạy `--help` thành công.
- [ ] Chạy dry run crawler, xác nhận output JSON/CSV.
- [ ] Set secret staging trong terminal, không ghi vào file tracked.
- [ ] Apply fixture SQL trên local/staging.
- [ ] Gọi checker thủ công và lưu `runId`.
- [ ] Mở admin bằng tài khoản role `admin`.
- [ ] Kiểm tra `cron.job` và secret parity nếu cần tuyên bố cron đang hoạt động.
- [ ] Không chạy `--upsert` hoặc fixture trên production.

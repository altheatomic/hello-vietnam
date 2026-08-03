# Thiết kế cơ chế cập nhật độ mới dữ liệu

**Ngày:** 2026-08-03

**Trạng thái:** Đã được duyệt

**Phạm vi:** Bản chạy được để trình diễn đồ án

## 1. Bối cảnh

HelloVietnam đang sử dụng dữ liệu tổng hợp từ các nguồn công khai cho các
bảng `place`, `activity`, `culture`, `food` và `local_products`. Giá trị của
những dữ liệu này giảm theo thời gian: nhà hàng hoặc cửa hàng có thể đóng cửa,
giờ hoạt động và địa chỉ có thể thay đổi, còn hoạt động hoặc sự kiện có thể kết
thúc.

Dự án hiện đã có CRUD quản trị và một số trường như `status`, `updated_at`,
`source`, `source_place_id`, nhưng chưa có pipeline kiểm tra độ mới. Hàm Explore
chỉ quyết định khả năng hiển thị dựa trên trạng thái nội dung và chưa xét hạn sử
dụng hoặc lần xác minh gần nhất.

Script OSM cho `place` đã dùng định danh nguồn ổn định và `upsert`. Ngược lại,
crawler `activity`, `culture` và `local_products` đang tạo UUID ngẫu nhiên nên
chạy lại có thể tạo bản ghi trùng thay vì cập nhật bản ghi cũ.

## 2. Mục tiêu

- Có bằng chứng rằng dữ liệu dự án được cập nhật tự động và thủ công.
- Tự động xử lý những thay đổi có quy tắc chắc chắn, đặc biệt là sự kiện hết
  hạn.
- Không tự kết luận quán hoặc shop đã đóng cửa chỉ từ một lần kiểm tra thất bại.
- Cho admin xem dữ liệu cũ, dữ liệu đề xuất và lý do trước khi duyệt thay đổi có
  rủi ro.
- Cho người dùng báo thông tin không chính xác từ màn hình chi tiết.
- Giữ lịch sử đủ để giải thích, kiểm thử và trình diễn khi bảo vệ đồ án.
- Chạy lại checker hoặc crawler an toàn, không tạo bản ghi hay đề xuất trùng.

## 3. Ngoài phạm vi

- Dùng AI để tự xác minh một cơ sở đã đóng cửa.
- Đối chiếu đồng thời nhiều nhà cung cấp dữ liệu trả phí.
- Cho người dùng tải ảnh bằng chứng.
- Gửi thông báo kết quả xử lý cho người đã báo cáo.
- Giao diện khôi phục riêng từng trường từ lịch sử phiên bản.
- Xây dựng hệ thống đồng thuận nhiều nguồn. Mỗi nội dung chỉ có một nguồn kiểm
  tra chính trong bản demo.

## 4. Kiến trúc tổng thể

Hệ thống dùng một pipeline kết hợp:

1. Nguồn công khai, báo sai của người dùng hoặc thao tác admin tạo nhu cầu kiểm
   tra.
2. Edge Function `data-freshness-check` lấy lại dữ liệu nguồn, chuẩn hóa và so
   sánh với nội dung hiện tại.
3. Bộ quy tắc freshness phân loại kết quả thành thay đổi an toàn hoặc thay đổi
   có rủi ro.
4. Thay đổi an toàn được tự động áp dụng và ghi lịch sử.
5. Thay đổi có rủi ro trở thành đề xuất trong hàng chờ admin.
6. Ứng dụng chỉ dùng nội dung đáp ứng chính sách hiển thị và lập lịch trình.

Các thành phần có ranh giới độc lập:

- **Source adapter:** tải và chuẩn hóa một loại nguồn như OSM hoặc Wikipedia.
- **Freshness checker:** điều phối batch, retry và lịch kiểm tra.
- **Diff engine:** tạo hash, xác định trường thay đổi và tôn trọng quyền sở hữu
  trường.
- **Rule engine:** quyết định tự áp dụng hay chờ admin.
- **Admin review:** duyệt, từ chối, sửa hoặc yêu cầu kiểm tra lại.
- **User report:** nhận tín hiệu sai thông tin có xác thực và giới hạn tần suất.
- **Public eligibility:** lọc nội dung cho Explore, đề xuất và Trip Planner.

## 5. Định danh nguồn và chống dữ liệu trùng

Mỗi bản ghi do crawler quản lý phải có:

- `source_type`, ví dụ `osm` hoặc `wikipedia`;
- `source_url` khi nguồn có URL ổn định;
- `source_external_id`, ví dụ ID node/way/relation của OSM hoặc URL chuẩn hóa
  của trang Wikipedia.

Cặp `source_type + source_external_id` là duy nhất trong một loại nội dung.
Crawler tạo UUID xác định từ cặp này hoặc dùng khóa duy nhất khi `upsert`. Chạy
lại cùng một nguồn phải cập nhật đúng bản ghi cũ.

Cơ sở dữ liệu áp dụng unique index có điều kiện trên
`(content_type, source_type, source_external_id)` khi `source_external_id` khác
null. Index này là lớp bảo vệ cuối cùng nếu crawler xử lý lại cùng một nguồn.

Nội dung admin tạo có `source_type = manual`; checker không tự tải nguồn cho
nội dung này. Bản ghi nhập cũ không thể khôi phục URL được gắn
`source_type = legacy_import` và đưa vào danh sách cần xác minh thủ công, nhưng
không bị ẩn ngay.

## 6. Mô hình dữ liệu

### 6.1 `content_freshness`

Một bản ghi freshness cho một nội dung:

- `id` UUID, khóa chính;
- `content_type`: `place`, `activity`, `culture`, `food`, `local_product`;
- `content_id` UUID;
- `source_type`, `source_url`, `source_external_id`;
- `availability_type`: `business`, `scheduled_event`, `evergreen`, `seasonal`;
- `valid_from`, `valid_until`;
- `freshness_status`: `fresh`, `due`, `stale`, `needs_review`, `expired`;
- `last_checked_at`, `last_verified_at`, `next_check_at`;
- `source_hash`;
- `consecutive_missing_count`, mặc định 0;
- `last_error`;
- `created_at`, `updated_at`.

Có ràng buộc duy nhất trên `(content_type, content_id)`. Quan hệ đa hình tới các
bảng nội dung không thể biểu diễn bằng một khóa ngoại PostgreSQL duy nhất, vì
vậy Edge Function phải kiểm tra bản ghi đích tồn tại trước khi tạo freshness.

### 6.2 `content_change_proposal`

Lưu đề xuất và đồng thời làm audit log:

- `id`, `freshness_id`;
- `change_type`, ví dụ `field_change`, `possibly_closed`, `source_recovered`,
  `auto_expired`;
- `before_data`, `proposed_data`, `changed_fields` dạng `jsonb`;
- `reason`, `confidence`;
- `decision`: `pending`, `auto_applied`, `approved`, `rejected`;
- `detected_at`, `reviewed_at`, `reviewed_by`;
- `applied_data` để ghi chính xác giá trị cuối cùng sau khi admin có chỉnh sửa.

Một partial unique index chỉ cho phép một đề xuất `pending` trên mỗi
`freshness_id`. Một lần chạy lại sẽ cập nhật đề xuất đang mở thay vì tạo thêm.

### 6.3 `content_report`

Lưu báo sai từ người dùng:

- `id`, `reporter_user_id`, `content_type`, `content_id`;
- `reason`: `closed`, `wrong_hours`, `wrong_location`, `event_ended`, `other`;
- `note` dạng text, không có tệp đính kèm trong bản demo;
- `status`: `open`, `resolved`, `dismissed`;
- `created_at`, `resolved_at`, `resolved_by`.

Một người không được có hai báo cáo `open` cùng `content_type`, `content_id` và
`reason`.

### 6.4 `content_update_run`

Lưu khả năng quan sát của từng lượt chạy:

- `id`, `trigger_type`: `cron`, `admin`, `retry`;
- `started_at`, `finished_at`, `status`;
- `selected_count`, `checked_count`, `unchanged_count`;
- `proposal_count`, `auto_applied_count`, `failed_count`;
- `error_summary`.

### 6.5 Chuẩn hóa bảng nội dung

Các bảng động dùng chung tập trạng thái:

- `active`: được công khai;
- `draft`: chưa công khai;
- `hidden`: tạm ẩn;
- `expired`: sự kiện đã kết thúc;
- `archived`: ngừng sử dụng nhưng vẫn giữ dữ liệu.

Các bảng chưa có `status` hoặc `updated_at` phải được bổ sung. Trigger cập nhật
`updated_at` chỉ chạy khi nội dung thật sự thay đổi. `last_checked_at` thuộc bảng
freshness và không làm thay đổi `updated_at`.

Thao tác xóa trên trang quản trị đối với nội dung động được đổi thành archive.
Xóa cứng không nằm trong luồng vận hành thông thường.

## 7. Quyền sở hữu trường

Checker được phép đề xuất thay đổi:

- tên;
- địa chỉ và tọa độ;
- giờ hoạt động;
- điện thoại;
- website;
- trạng thái vận hành từ nguồn.

Checker không tự ghi đè:

- mô tả do admin biên tập;
- ảnh được admin chọn;
- tag và phân loại biên tập;
- rating và review nội bộ;
- dữ liệu người dùng tạo.

Nhờ vậy việc chạy lại crawler không xóa các cải thiện nội dung do admin thực
hiện.

## 8. Lịch kiểm tra

Cron gọi `data-freshness-check` hằng ngày. Mỗi lần lấy tối đa 50 bản ghi có
`next_check_at <= now()` và khóa các bản ghi đã chọn để các worker không xử lý
trùng.

Khi claim một bản ghi đã đến hạn, checker chuyển freshness từ `fresh` sang
`due`. Trạng thái này vẫn cho phép hiển thị nội dung và chỉ có nghĩa là lượt xác
minh tiếp theo đang chờ hoặc đang được xử lý.

| Loại dữ liệu | Chu kỳ |
|---|---:|
| Sự kiện có `valid_until` | kiểm tra hạn hằng ngày |
| Nhà hàng, quán cà phê, shop | 7 ngày |
| Điểm tham quan, hoạt động | 14 ngày |
| Văn hóa, món ăn, sản phẩm địa phương | 30 ngày |
| Admin yêu cầu kiểm tra ngay | ưu tiên lượt kế tiếp |

`next_check_at` được phân tán theo thời gian để tránh toàn bộ dữ liệu đến hạn
cùng lúc. Nút **Kiểm tra ngay** gọi cùng pipeline, không tạo một cách xử lý thứ
hai.

## 9. Quy tắc trạng thái

### 9.1 Nguồn không đổi

- Cập nhật `last_checked_at` và `last_verified_at`.
- Đặt `freshness_status = fresh`.
- Đặt `consecutive_missing_count = 0` và tính `next_check_at`.
- Không sửa `updated_at` của nội dung.

### 9.2 Sự kiện hết hạn

Khi `valid_until < now()`:

- tự động đặt trạng thái nội dung và freshness thành `expired`;
- tạo proposal có `decision = auto_applied` để lưu lịch sử;
- loại nội dung khỏi danh sách công khai và Trip Planner.

### 9.3 Nguồn thay đổi trường dữ liệu

- Tạo hoặc cập nhật proposal `pending`.
- Lưu dữ liệu cũ, dữ liệu đề xuất và danh sách trường khác biệt.
- Đặt `freshness_status = needs_review` nếu thay đổi ảnh hưởng khả năng vận
  hành, địa chỉ hoặc tọa độ.
- Không ghi đè dữ liệu công khai trước khi admin duyệt.

### 9.4 Không tìm thấy nguồn

- Lần đầu: tăng `consecutive_missing_count` lên 1, đặt freshness thành `stale`,
  giữ nội dung `active` và tạo cảnh báo mức thấp.
- Lần kiểm tra theo lịch thành công thứ hai vẫn không tìm thấy: đặt
  `needs_review`, tạo proposal `possibly_closed` ưu tiên cao và loại nội dung
  khỏi gợi ý/lập lịch trình.
- Nếu nguồn xuất hiện lại: đưa bộ đếm về 0, đặt `fresh` và đóng cảnh báo đang mở
  bằng một bản ghi lịch sử `source_recovered`.
- Không lần nào tự chuyển quán/shop sang `archived`.

Hai lần không tìm thấy phải là hai lượt kiểm tra đã nhận phản hồi hợp lệ từ
nguồn; timeout hoặc lỗi parser không được tính.

### 9.5 Lỗi kỹ thuật

- Ghi `last_error` và tăng `failed_count` của lượt chạy.
- Giữ nguyên nội dung, `source_hash` và bộ đếm missing.
- Retry tối đa hai lần sau lần gọi đầu, dùng backoff ngắn.
- Nếu vẫn lỗi, đặt lịch retry nhưng không xem là bằng chứng dữ liệu không tồn
  tại.

## 10. Luồng admin

Trang **Data Freshness** có bốn nhóm:

- Chờ duyệt;
- Báo sai;
- Dữ liệu stale;
- Lịch sử chạy.

Dashboard hiển thị số bản ghi đến hạn, chờ duyệt, tự hết hạn và lượt chạy có
lỗi. Chi tiết proposal hiển thị nguồn, thời điểm kiểm tra, dữ liệu cũ, dữ liệu
mới, lý do và mức tin cậy.

Admin có thể:

- duyệt toàn bộ hoặc chọn các trường được áp dụng;
- từ chối và giữ dữ liệu hiện tại;
- chỉnh sửa giá trị trước khi duyệt;
- yêu cầu kiểm tra lại;
- xác nhận đã đóng để archive.

Khi duyệt, backend khóa proposal, kiểm tra nội dung chưa thay đổi kể từ
`before_data`, áp dụng thay đổi trong transaction rồi cập nhật freshness và
audit log. Nếu nội dung đã được người khác sửa, backend không áp dụng proposal
cũ và yêu cầu admin tải lại.

Khi admin từ chối một cảnh báo đóng cửa, proposal chuyển `rejected`, bộ đếm
missing về 0, nội dung được xác minh là `fresh` và được lên lịch kiểm tra lại
sớm hơn chu kỳ bình thường.

## 11. Luồng báo sai của người dùng

Trang chi tiết có nút **Báo thông tin không chính xác**. Người dùng chọn lý do,
nhập ghi chú tùy chọn và gửi.

- Yêu cầu đăng nhập.
- Giới hạn ba báo cáo mỗi tài khoản trong một ngày UTC.
- Chặn báo cáo `open` trùng nội dung và lý do.
- Một báo cáo không sửa trạng thái nội dung hoặc freshness.
- Nhiều tài khoản báo cùng vấn đề làm tăng thứ tự ưu tiên trong admin, nhưng
  không tự động ẩn nội dung.
- Admin có thể kiểm tra nguồn, sửa nội dung rồi đánh dấu báo cáo `resolved`, hoặc
  `dismissed` nếu không chính xác.

## 12. Chính sách hiển thị và lập lịch trình

- Nội dung `active` với freshness `fresh` hoặc `due`: dùng bình thường.
- Nội dung `active` với freshness `stale`: vẫn xuất hiện trong Explore kèm nhãn
  **Thông tin chưa được xác minh gần đây**.
- Freshness `needs_review`: không được đưa vào đề xuất và Trip Planner. Nội dung
  đã lưu trước đó có thể mở bằng liên kết trực tiếp nhưng phải có cảnh báo.
- Nội dung `expired`, `hidden` hoặc `archived`: không xuất hiện trong danh sách
  công khai, đề xuất hoặc Trip Planner.

Hàm lọc Explore hiện tại phải nhận biết thêm `expired` và trạng thái freshness.
Các truy vấn ứng viên của service đề xuất/lập lịch trình phải áp dụng cùng chính
sách để tránh hai màn hình cho kết quả mâu thuẫn.

## 13. Bảo mật

- Người dùng chỉ được tạo và xem báo cáo của chính mình qua RLS.
- Client không được insert hoặc update proposal, freshness hay update run.
- Admin action phải xác thực JWT và kiểm tra role hiện tại ở backend.
- Checker dùng service role ở Edge Function; khóa không xuất hiện trong Flutter.
- Source adapter chỉ gọi hostname nằm trong allowlist cấu hình, bao gồm các
  endpoint OSM/Wikimedia/Wikipedia được dự án sử dụng. Không gọi URL tùy ý lấy
  trực tiếp từ request người dùng.
- Input báo cáo được giới hạn độ dài và lưu dưới dạng text, không render HTML.
- Mọi mutation admin quan trọng đều lưu `reviewed_by` và thời gian.

## 14. Khả năng chịu lỗi và idempotency

- Một bản ghi lỗi không làm dừng cả batch.
- Mỗi batch luôn kết thúc bằng trạng thái và thống kê rõ ràng.
- Partial unique index ngăn proposal pending trùng.
- Định danh nguồn ổn định ngăn nội dung trùng khi crawler chạy lại.
- Transaction ngăn trạng thái nội dung, freshness và audit log lệch nhau.
- Optimistic freshness check ngăn admin áp dụng đề xuất được tạo từ phiên bản
  dữ liệu đã cũ.
- Mọi thao tác archive đều có thể phục hồi bằng admin edit; không xóa cứng.

## 15. Thứ tự triển khai

1. Tạo migration cho bốn bảng, RLS, index, trạng thái và timestamp trigger.
2. Backfill freshness cho nội dung hiện có.
3. Sửa crawler dùng định danh nguồn ổn định và giữ trường do admin sở hữu.
4. Xây source adapter, diff/rule engine và Edge Function checker.
5. Cấu hình cron và lịch batch.
6. Xây trang quản trị Data Freshness.
7. Thêm form báo sai và cảnh báo stale trong Flutter.
8. Áp dụng eligibility policy cho Explore, Recommend và Trip Planner.

Trong backfill:

- `place` có metadata OSM giữ nguồn hiện tại;
- bản ghi có URL nguồn xác định được nhận source tương ứng;
- bản ghi không có nguồn được gắn `legacy_import`, freshness `stale`, vẫn hiển
  thị và chờ admin bổ sung nguồn hoặc xác minh;
- không đặt hàng loạt dữ liệu cũ thành `needs_review`, vì thao tác đó sẽ làm mất
  toàn bộ ứng viên đề xuất ngay sau migration.

## 16. Kiểm thử

### SQL và RLS

- Các check constraint và unique index hoạt động.
- Người dùng không đọc/sửa dữ liệu nội bộ của freshness hoặc proposal.
- Người dùng chỉ tạo/xem báo cáo của mình.
- Admin và service role thực hiện đúng thao tác được phép.
- `updated_at` chỉ đổi khi nội dung đổi.

### Unit test

- Chuẩn hóa nguồn và tạo hash ổn định.
- Phân biệt trường do nguồn và admin sở hữu.
- Nguồn không đổi, thay đổi trường, hết hạn, missing và recovery.
- Timeout/parser error không tăng missing count.
- Tính `next_check_at` đúng theo `availability_type`.

### Edge Function integration test

- Batch tối đa 50 và tiếp tục khi một item lỗi.
- Cùng một kết quả chạy lại không tạo proposal trùng.
- Hai phản hồi missing hợp lệ tạo đúng một proposal.
- Duyệt proposal cập nhật nội dung, freshness và audit trong cùng transaction.
- Proposal cũ không ghi đè nội dung vừa được admin sửa.
- Rate limit báo cáo hoạt động.

### Flutter test

- Admin xem được thống kê, filter, diff và action state.
- Người dùng gửi báo cáo hợp lệ và thấy lỗi trùng/rate limit rõ ràng.
- Nhãn stale hiển thị đúng.
- Nội dung không đủ điều kiện không xuất hiện trong danh sách và planner.

## 17. Kịch bản nghiệm thu

1. Tạo sự kiện có `valid_until` trong quá khứ, chạy checker và xác nhận hệ thống
   tự chuyển `expired` với audit log `auto_applied`.
2. Giả lập quán không còn trong hai phản hồi nguồn hợp lệ, xác nhận có đúng một
   proposal `possibly_closed`.
3. Admin xem diff và xác nhận đã đóng, quán chuyển `archived` và biến mất khỏi
   Explore/Trip Planner.
4. Người dùng báo sai giờ mở cửa, xác nhận báo cáo xuất hiện trong hàng chờ
   admin nhưng dữ liệu công khai chưa bị sửa.
5. Giả lập timeout nguồn, xác nhận job ghi lỗi nhưng dữ liệu, source hash và
   missing count không đổi.
6. Chạy lại crawler trên cùng tập nguồn, xác nhận số bản ghi không tăng.

## 18. Chỉ số trình diễn

Trang quản trị hiển thị cho lượt chạy gần nhất:

- số bản ghi được chọn và kiểm tra;
- số nguồn không đổi;
- số đề xuất mới;
- số thay đổi tự áp dụng;
- số lỗi;
- thời gian bắt đầu và kết thúc.

Các chỉ số này đủ chứng minh dữ liệu có quy trình cập nhật, đồng thời giúp phát
hiện checker bị lỗi mà không cần xây hệ thống quan sát production phức tạp.

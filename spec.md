## spec.md

## Requirements

**Mục tiêu sản phẩm**

- App du lịch “Hello Vietnam”.
- Các module “ngoài navbar” đều có thể truy cập từ **Home** (và sau này có thể từ Search/Explore/Drawer).

## Phạm vi màn hình

- **Bottom navbar (4 tab):**
  - Home
  - Trip Planner
  - Messages
  - Profile

- **Trang/module ngoài navbar (đi từ Home hoặc mở theo push flow):**
  - Forum
  - Popular Phrases
  - Send Feedback
  - Recommend
  - Explore
  - Popular Apps
  - AI Search
  - Trip Planner

## Yêu cầu chức năng (Functional)

- **Điều hướng**
  - 4 tab chính luôn hiển thị bottom navbar.
  - Trang ngoài navbar mở dạng **push** lên trên, không làm mất trạng thái tab hiện tại.
  - Mỗi tab có stack điều hướng riêng cho các màn hình con như detail / create / edit / search / filter.
  - Nút back quay lại đúng màn hình trước đó trong cùng flow.
  - Các icon heart/favorite dùng để thêm hoặc bỏ địa điểm khỏi Wish List.

- **Home**
  - Hiển thị các entry point để đi tới các module ngoài navbar như Explore, Recommend, AI Search, Popular Apps, Forum, Popular Phrases, Send Feedback.
  - Điều hướng vào module theo kiểu push.
  - Giữ nguyên trạng thái tab Home khi người dùng quay lại.

- **Trip Planner**

- **Profile**

- **Explore**

- **Forum**

- **Popular Phrases**

- **Wish List**

- **AI Search**

- **Popular Apps**
  - Hiển thị danh sách ứng dụng đề xuất cho du lịch.
  - Có thể mở link ngoài hoặc xem mô tả ngắn.

- **Recommend**
  - Màn hình gốc **Recommendation** có 2 lựa chọn chính:
    - **Where**
    - **When**

### Luồng Recommend - Where

- **Recommendation**
  - Người dùng nhấn tab / card **Where** để bắt đầu flow chọn nơi muốn đi.

- **Recommendation 1.1**
  - Màn hình nhập hoặc tìm kiếm điểm đến.
  - Hiển thị search bar.
  - Có thể hiển thị danh sách địa điểm nổi bật / gợi ý ban đầu.

- **Recommendation 1.2**
  - Khi người dùng focus vào search bar, hiển thị trạng thái nhập liệu.
  - Có keyboard và nội dung đang nhập.

- **Recommendation 1.3**
  - Hiển thị danh sách kết quả gợi ý theo từ khóa tìm kiếm.
  - Ví dụ: Hà Nội, Hà Giang, Hải Phòng, Hà Tĩnh...
  - Nhấn vào một kết quả sẽ mở chi tiết địa điểm.

- **Recommendation 1.4**
  - Màn hình chi tiết điểm đến theo flow **Where**.
  - Có thể gồm:
    - ảnh nổi bật
    - tên địa điểm
    - rating
    - mô tả ngắn
    - các tab nội dung: `All`, `Best Time`, `Activities`, `Food`, `Tips`
  - Có thể favorite địa điểm.
  - Có thể quay lại danh sách kết quả hoặc màn hình search trước đó.
  - Quy tắc hiển thị theo tab:
    - **All**: hiển thị toàn bộ nội dung chi tiết của địa điểm theo đúng layout đầy đủ như Figma.
    - **Best Time**: chỉ hiển thị section **Best month to visit** / **Best time to visit** của trang `All` nếu địa điểm có dữ liệu.
    - **Activities**: chỉ hiển thị section hoạt động / trải nghiệm nổi bật của trang `All` nếu địa điểm có dữ liệu.
    - **Food**: chỉ hiển thị section **Must-try Cuisine** của trang `All` nếu địa điểm có dữ liệu.
    - **Tips**: chỉ hiển thị section **Tips** của trang `All` nếu địa điểm có dữ liệu.
  - Các tab không phải dữ liệu độc lập; chúng là các view lọc từ nội dung của tab `All`.
  - Nếu section tương ứng không có dữ liệu:
    - không hiển thị section rỗng;
    - có thể hiển thị trạng thái trống ngắn gọn, ví dụ: `No information available`.

### Luồng Recommend - When

- **Recommendation**
  - Người dùng nhấn tab / card **When** để bắt đầu flow chọn theo thời gian.

- **Recommendation 2.1**
  - Màn hình chọn năm / tháng / lịch du lịch.
  - Người dùng xem được calendar theo từng tháng.

- **Recommendation 2.2**
  - Người dùng chọn ngày hoặc khoảng ngày rảnh để đi du lịch.
  - Khi dữ liệu hợp lệ thì nút **Next** được bật.
  - Nhấn **Next** để sang danh sách địa điểm phù hợp theo thời gian đã chọn.

- **Recommendation 2.3**
  - Hiển thị **list địa điểm** được recommend dựa trên thời gian đã chọn.
  - Có thể có sort.
  - Mỗi item hiển thị:
    - ảnh
    - tên địa điểm
    - mô tả ngắn
    - rating hoặc tag ngắn
  - Nhấn vào một địa điểm sẽ đi tới **Recommendation 2.4**.

- **Recommendation 2.4**
  - Màn hình chi tiết địa điểm theo flow **When**.
  - Có thể gồm:
    - ảnh banner
    - tên địa điểm
    - rating
    - mô tả
    - gallery ảnh
    - highlights
    - bản đồ
  - Có thể favorite địa điểm.
  - Có thể quay lại danh sách ở **Recommendation 2.3**.

## Ghi chú luồng Recommend

- Flow **Where** và **When** là 2 nhánh độc lập, cùng bắt đầu từ màn hình **Recommendation**.
- Flow **Where** thiên về việc người dùng biết hoặc gần biết nơi mình muốn đi.
- Flow **When** thiên về việc người dùng biết thời gian rảnh trước, sau đó hệ thống mới gợi ý nơi phù hợp.
- ## Ở cả 2 flow, màn hình chi tiết địa điểm là điểm cuối của luồng xem recommend và có thể là nơi dẫn tiếp sang Trip Planner hoặc Wish List ở các phase sau.
- Send Feedback:

**Yêu cầu phi chức năng (Non-functional)**

- Hiệu năng: list scroll mượt (>= 55–60fps mục tiêu), tránh rebuild thừa.
- Tính ổn định: app không crash khi network fail; hiển thị empty/error states.
- Khả năng mở rộng: feature-first, route rõ ràng, dễ thêm màn hình con.
- Logging: log mức dev (debug) + tắt/giảm ở release.
- i18n (chuẩn bị): cấu trúc text tránh hardcode quá sớm (giai đoạn sau bật).
- Bảo mật: không commit secrets; cấu hình env tách riêng.

**Ràng buộc**

- Android-first (test trên Pixel), nhưng kiến trúc giữ cross-platform.
- Build pipeline Android phải reproducible (commit Gradle wrapper; không commit local.properties).

## Quyết định kiến trúc

**UI framework**

- Flutter + Material 3.

**Routing**

- `go_router` với `StatefulShellRoute.indexedStack` cho 4 tab (mỗi tab 1 navigation stack).
- “Trang ngoài navbar” đặt ở root routes (push overlay) để giữ trạng thái tab.

**Tổ chức code**

- Feature-first:
  - `lib/features/<feature>/presentation/...`
  - `lib/core/...` cho hạ tầng dùng chung
  - `lib/app/...` cho App shell (router/theme)
- “Clean-lite”:
  - `presentation/` + service nhẹ.
  - `data/` (repositories/datasources) + `domain/` (entities/usecases) theo nhu cầu.

**State management (đề xuất)**

- MVP nhanh: `flutter_hooks` hoặc `setState` + service.
- Scale ổn: Riverpod (khuyến nghị) để tách UI/state, dễ test.
- Quy ước: state theo feature; tránh “global singleton” không kiểm soát.

**Data layer (định hướng)**

- Giai đoạn v0.x: mock + local JSON/fixtures để đóng UI nhanh.
- Giai đoạn v1: kết nối backend (ví dụ Supabase/Postgres hoặc API riêng) + cache local.

**Thiết kế component**

- Widgets dùng chung đặt ở `core/widgets`.
- Screen là `*_page.dart`; widget con đặt trong `widgets/` cùng feature.
- Error/Empty/Loading: component chuẩn hoá (không copy-paste).

**Build & config**

- Secrets/config: `lib/core/config/env.dart` đọc từ `--dart-define` (không hardcode).
- Android specifics chỉ chỉnh khi cần (permissions, signing, deeplink).

## Data model

**Nguyên tắc chung**

- Chuẩn hoá type cho UI:
  - Không lẫn logic vào model UI.

**Entities**

**UserAccount**

- `id_user`, `full_name`, `username`, `password`, `role`, `created_at`

**UserContact**

- `id_user`, `phone_number`, `email`

**UserAccessibility**

- `id_user`, `not_enabled`, `email_enabled`, `location_enabled`, `mic_enabled`, `quiet_start`, `quiet_end`, `push_token`

**UserSetting**

- `id_user`, `language`, `theme`, `currency`

**CityProvince**

- `id_city`, `name`, `area`, `description`

**PlaceSubcategory**

- `id_place_subcategory`, `name`, `place_category`, `update_by`, `update_at`

**Place**

- `id_place`, `id_place_subcategory`, `name`, `description`, `timespan`, `timeclose`, `status`, `images_path`, `created_at`

**PlaceAddress**

- `id_address`, `id_place`, `address`, `id_city`

**PlaceRating**

- `id_place`, `rating_avg`, `rating_count`, `updated_at`

**Food**

- `id_food`, `name`, `type`, `id_city`, `image_path`, `description`

**Hobby**

- `id_user`, `id_subcategory`

**Plan**

- `id_plan`, `id_user`, `duration`, `start_at`, `end_at`, `city_province`, `created_at`

**PlanComponent**

- `id_component`, `id_plan`, `day`, `time_part`

**ForumTopic**

- `id_topic`, `created_by`, `title`, `description`, `created_at`, `updated_at`, `status`, `last_post_at`

**ForumPost**

- `id_post`, `id_topic`, `id_author_user`, `title`, `content`, `created_at`, `updated_at`, `status`

**ForumComment**

- `id_comment`, `id_post`, `id_author_user`, `content`, `created_at`, `updated_at`, `status`

**Notification**

- `id_notification`, `id_user`, `id_voucher`, `id_comment`, `title`, `body`, `deeplink`, `payload_jsonb`, `is_in_app`, `is_push`, `sent_at`, `read_at`, `status`, `created_at`

**Feedback**

- `id_feedback`, `id_user`, `id_item`, `type`, `report_content`, `create_at`, `status`

**Favorite**

- `id_user`, `id_item`, `type`

**RateItem**

- `id_rate`, `id_user`, `id_item`, `review`, `rating`, `create_at`, `update_at`, `report_status`

**Report**

- `id_report`, `id_user`, `id_content`, `content_type`, `report`

**Phrase**

- `id_phrase`, `content`, `sound_north`, `sound_south`, `phrase_category`, `example`

**PopularApp**

- `id_app`, `name`, `type`, `guide`, `url_image`, `url_video`, `description`, `update_at`

**MediaAsset**

- `id_media`, `owner_user_id`, `url`, `mime_type`, `sha256_hash`, `width`, `height`, `ext_json`, `created_at`

**AIIdentification**

- `id_ai_ident`, `id_user`, `id_input_media`, `input_media_type`, `model`, `status`, `confidence`, `alt_candidates`, `created_at`, `processed_at`

**SubscriptionPlan**

- `id_subscription_plan`, `code`, `name`, `duration_days`, `price_minor`, `status`

**FeatureEntitlement**

- `id_entitlement`, `id_subscription_plan`, `feature_code`, `limit_value`, `notes`, `statuses`

**Voucher**

- `id_voucher`, `id_applicable_plan`, `code`, `type`, `value`, `max_discount_value`, `start_at`, `end_at`, `status`, `usage_limit_total`, `usage_limit_per_user`, `min_order_amount_min`, `created_at`

**VoucherGrant**

- `id_grant`, `id_voucher`, `id_user`, `source_type`, `granted_at`, `expires_at`, `status`

**VoucherRedemption**

- `id_redemption`, `id_voucher`, `id_user`, `id_payment`, `discount_minor`, `redeemed_at`

**PremiumSubscription**

- `id_prs`, `id_user`, `id_plan`, `start_date`, `end_date`, `currency`, `status`

**Payment**

- `id_payment`, `id_user`, `id_subscription_plan`, `provider`, `method`, `amount_minor`, `currency`, `status`, `external_ref`, `created_at`, `confirmed_at`, `failure_reason`

**CannedReply**

- `id_canned_reply`, `content`, `updated_at`

**Storage strategy**

- Source of truth: PostgreSQL database schema from `db.sql`
- UUID generated at DB level
- Frontend MVP may still use mock data, but data models must match DB entities
- Optional local cache/offline layer can be added later using SQLite/Isar/Hive

## Chiến lược test

**Test pyramid**

- Unit tests (nhiều nhất): parsing model, services, validators, pure functions.
- Widget tests: UI state cơ bản, navigation, empty/error states.
- Integration/E2E: flow chính (open app → nav tab → mở module → back).

**Công cụ**

- `flutter_test` cho unit/widget.
- `integration_test` cho E2E trên Android device/emulator.
- Mock network: `http_mock_adapter` (nếu dùng Dio) hoặc fake repository layer.

**Phạm vi test theo module**

- Router:
  - Bảo đảm 4 tab render, chuyển tab không crash, push route ngoài navbar hoạt động.
- Home:
- Trip Planner:
- Profile:
- Recommend:

**CI (định hướng)**

- `flutter analyze`
- `flutter test`
- `flutter test integration_test` (tuỳ pipeline/thiết bị)
- Lint rules: bật dần theo milestone.

**Chất lượng**

- Mục tiêu coverage MVP: 30–40% (tập trung services/router), tăng dần >60% khi vào data/backend.

**Assumptions**

- Backend có thể đến sau; giai đoạn đầu ưu tiên hoàn thiện UI + navigation + data mock.
- i18n/offline/push notification nằm ngoài MVP trừ khi cần sớm.

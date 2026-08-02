# Stripe Sandbox Hardening Design

## Mục tiêu

Giữ Stripe Checkout ở chế độ test để phục vụ demo trước phản biện, nhưng loại bỏ
các đường cấp Premium không qua xác minh Stripe, bảo đảm callback/webhook chạy
lặp lại không tạo dữ liệu trùng, và mô tả đúng đây là gói Premium trả trước không
tự gia hạn.

Thiết kế này không đưa Stripe vào bản Android phát hành chính thức trên Google
Play. Sau phản biện, bản Google Play sẽ chuyển sang Google Play Billing; Stripe
chỉ còn dành cho Flutter Web hoặc bản phân phối ngoài Play.

## Quyết định sản phẩm

- Stripe tiếp tục dùng test key và Checkout Sandbox.
- Các gói `1m`, `6m`, `12m` là quyền truy cập trả trước trong 30, 180, 365 ngày.
- Checkout tiếp tục dùng `mode=payment`; không quảng cáo tự động gia hạn.
- Màn thanh toán phải hiện rõ `TEST MODE · No real charge`.
- Không triển khai recurring subscription, Google Play Billing, hoàn tiền thật
  hoặc Stripe production trong phạm vi trước phản biện.

## Kiến trúc đích

```text
Flutter
  │ JWT
  ▼
subscription-payment Edge Function
  ├─ tạo payment_attempt ở trạng thái pending
  ├─ tạo Stripe Checkout Session bằng giá snapshot phía server
  └─ trả checkout URL
          │
          ▼
     Stripe Sandbox
       ├─ success deep link ──► Flutter ──► confirm_checkout
       └─ signed webhook ─────► stripe-webhook Edge Function
                                      │
                                      ▼
                           finalize_verified_payment RPC
                                      │
                                      ▼
                  payment + premium_subscription + voucher
```

Deep link giúp người dùng thấy kết quả ngay. Webhook là đường xác nhận độc lập
để vẫn cấp Premium khi người dùng đã trả tiền nhưng không quay lại app. Hai
đường cùng gọi một transaction idempotent.

## Ranh giới tin cậy

### Flutter

Flutter chỉ được:

- Gửi `plan_code`, voucher và nền tảng callback.
- Mở Checkout URL do server trả về.
- Gửi `session_id` quay lại Edge Function để yêu cầu đồng bộ trạng thái.
- Đọc payment và Premium của chính người dùng qua RLS.

Flutter không được:

- Truyền giá, tiền tệ, provider hoặc trạng thái thanh toán đáng tin cậy.
- Gọi RPC tạo payment/Premium.
- Có Stripe secret hoặc Supabase service-role key.

### Edge Functions

`subscription-payment` bắt buộc xác minh user JWT. Function này:

- Đọc plan/voucher và tính giá phía server.
- Tạo `payment_attempt`.
- Tự xây dựng callback URL từ allowlist cấu hình server.
- Tạo và đọc Checkout Session bằng Stripe secret.
- So khớp session với attempt trước khi finalize.

`stripe-webhook` không dùng user JWT vì Stripe là caller. Function này:

- Đọc raw request body.
- Xác minh `Stripe-Signature` bằng webhook secret.
- Chỉ xử lý event được allowlist.
- Tìm `payment_attempt` theo `metadata.attempt_id`, rồi đối chiếu Stripe
  Session ID với attempt.
- Gọi cùng transaction finalize như callback.

### PostgreSQL

PostgreSQL là nguồn sự thật của entitlement. Chỉ service role được gọi
`finalize_verified_payment`. RPC nhận `attempt_id`, không nhận user, plan, giá,
provider hoặc external reference tùy ý từ client.

## Thay đổi dữ liệu

### Bảng `payment_attempt`

Bảng mới lưu snapshot tại thời điểm bắt đầu Checkout:

- `id_attempt uuid primary key`
- `id_user uuid not null`
- `id_subscription_plan uuid not null`
- `id_voucher uuid null`
- `id_voucher_wallet uuid null`
- `plan_code text not null`
- `plan_name text not null`
- `duration_days integer not null check (duration_days > 0)`
- `original_amount_minor bigint not null check (original_amount_minor >= 0)`
- `discount_minor bigint not null check (discount_minor >= 0)`
- `amount_minor bigint not null check (amount_minor >= 0)`
- `voucher_code text null`
- `currency text not null check (currency = 'USD')`
- `stripe_session_id text unique`
- `status text not null` với các giá trị `pending`, `paid`, `finalized`,
  `expired`, `failed`
- `failure_reason text null`
- `created_at`, `updated_at`, `finalized_at`

RLS được bật. Client không có policy ghi hoặc đọc trực tiếp; mọi thao tác đi qua
Edge Function/service role.

### Bảng `payment`

- Thêm unique constraint `(provider, external_ref)`.
- Duy trì RLS chỉ cho user đọc payment của chính mình.
- Không có policy insert/update/delete cho client.

### Bảng `premium_subscription`

- Thêm `id_payment uuid` để truy vết entitlement về đúng giao dịch.
- Duy trì RLS chỉ cho user đọc subscription của chính mình.
- Không có policy insert/update/delete cho client.

Mọi RLS/policy đang tồn tại trên database phải được đưa vào migration để repo và
production không tiếp tục lệch schema.

## Xóa đường cấp Premium không an toàn

Hai RPC sau không còn được public/anon/authenticated gọi:

- `confirm_paid_subscription_with_voucher`
- `purchase_subscription_with_voucher`

Nếu không còn dependency, drop cả hai. Nếu cần giữ tạm để migration dữ liệu,
revoke toàn bộ rồi chỉ grant cho `service_role`.

Flutter xóa repository method `purchase()` gọi trực tiếp
`purchase_subscription_with_voucher`.

## Tạo Checkout

1. Xác minh JWT bằng Supabase Auth.
2. Validate `plan_code` và voucher.
3. Tính giá hoàn toàn phía server.
4. Tạo `payment_attempt` pending với giá snapshot.
5. Tạo Stripe Session:
   - `mode=payment`
   - `client_reference_id=user_id`
   - metadata chỉ chứa `attempt_id`
   - amount/currency lấy từ attempt
   - success/cancel URL do server tạo từ platform enum và allowlist
6. Gửi Stripe idempotency key bằng `attempt_id`.
7. Cập nhật `stripe_session_id` vào attempt.
8. Trả Checkout URL cho Flutter.

Runtime không được seed hoặc upsert plan/voucher mặc định. Catalog phải được
quản lý bằng migration hoặc trang admin, tránh mỗi request thanh toán ghi đè giá
đang vận hành.

## Xác nhận Checkout

Callback và webhook đều phải kiểm tra:

- Attempt tồn tại và chưa bị failed/expired.
- Stripe Session ID khớp attempt.
- `client_reference_id` khớp `attempt.id_user`.
- `metadata.attempt_id` khớp.
- `status=complete`.
- `payment_status=paid`.
- `amount_total` khớp `attempt.amount_minor`.
- `currency` khớp `attempt.currency`.

Không tính lại giá/voucher ở thời điểm finalize. Giá snapshot trong attempt là
giá đã được Stripe thu.

## Transaction finalize

`finalize_verified_payment(attempt_id uuid, stripe_session_id text,
amount_total bigint, currency text)` thực hiện trong một transaction:

1. Khóa attempt bằng `FOR UPDATE`.
2. Nếu đã finalized, trả lại payment/subscription hiện có.
3. Insert payment bằng `(provider='stripe', external_ref=stripe_session_id)`.
4. Ghi voucher redemption nếu attempt có voucher.
5. Tạo Premium với ngày hết hạn dựa trên `duration_days` snapshot.
6. Liên kết Premium với payment.
7. Đánh dấu voucher wallet đã dùng nếu có.
8. Đánh dấu attempt finalized.
9. Trả payment ID, Premium ID, số tiền và ngày hết hạn.

Unique constraint và row lock bảo đảm callback/webhook chạy đồng thời vẫn chỉ
tạo một kết quả.

Việc cộng loyalty point phải idempotent theo payment ID. Nếu loyalty tạm thời
lỗi, entitlement đã trả tiền không bị rollback; lỗi được log để retry riêng.

## Event webhook

Trước phản biện chỉ cần hỗ trợ:

- `checkout.session.completed`: xác minh và finalize.
- `checkout.session.expired`: đánh dấu attempt expired.

Các event khác được trả `200 ignored` sau khi chữ ký hợp lệ. Refund/chargeback là
ngoài phạm vi Sandbox demo và sẽ được thiết kế cùng payment provider production.

## UI và thông báo lỗi

- Badge cố định: `TEST MODE · No real charge`.
- Bỏ nội dung tự động gia hạn/hủy subscription.
- Nội dung thay thế: `This is a one-time sandbox payment. Premium access does
  not renew automatically.`
- Khi callback lỗi mạng, hiển thị trạng thái đang đồng bộ và nút Retry; không
  tuyên bố thanh toán thất bại nếu Stripe đã paid.
- App refresh entitlement sau callback, khi resume và khi mở trang Premium.

## Quan sát và đối soát

Log phải có các khóa không nhạy cảm:

- `attempt_id`
- `stripe_session_id`
- event type
- trạng thái trước/sau
- mã lỗi chuẩn hóa

Không log Stripe secret, webhook secret, JWT, card data hoặc toàn bộ webhook
payload.

Trang admin/payment history đọc trạng thái từ `payment` và có thể đối chiếu
`payment_attempt`; không trực tiếp sửa entitlement.

## Kiểm thử chấp nhận

- User chưa đăng nhập không tạo/confirm checkout.
- Session của user A không thể được confirm bởi user B.
- Session unpaid, expired, sai amount hoặc sai currency không cấp Premium.
- Callback gọi hai lần chỉ tạo một payment/Premium.
- Callback và webhook đồng thời chỉ tạo một payment/Premium.
- Thanh toán xong nhưng không quay lại app vẫn được webhook cấp Premium.
- Deep link thành công refresh entitlement và mở màn success.
- Voucher hết hạn/đã dùng bị từ chối trước khi tạo Checkout.
- RPC cũ không callable bởi anon/authenticated.
- Client chỉ đọc được payment/Premium của chính mình.
- Giao diện không còn nội dung auto-renew và luôn hiện Sandbox test mode.

## Triển khai và rollback

1. Deploy migration khóa RPC/RLS trước.
2. Deploy transaction và bảng attempt.
3. Deploy `subscription-payment` mới.
4. Deploy/configure `stripe-webhook` Sandbox.
5. Cập nhật Flutter.
6. Chạy smoke test với Stripe test cards.

Nếu webhook gặp sự cố, callback vẫn có thể finalize. Nếu Flutter mới gặp lỗi,
server vẫn giữ attempt và webhook tiếp tục đồng bộ entitlement. Rollback không
được mở lại RPC public cũ.

## Ngoài phạm vi

- Google Play Billing.
- Stripe live mode.
- Recurring Stripe Subscription.
- Customer Portal và tự động gia hạn.
- Xử lý refund/chargeback production.
- iOS.

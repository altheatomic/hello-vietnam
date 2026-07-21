# Android Push Notification Design

## Muc tieu

Bo sung thong bao Android that cho ung dung bang Firebase Cloud Messaging
(FCM), dong thoi thay the notification mock bang du lieu Supabase. He thong ho
tro nam nhom thong bao:

- `loyalty`: cong diem, doi thuong va thay doi hang.
- `forum`: binh luan, tra loi va tuong tac bai viet.
- `voucher`: nhan voucher, voucher sap het han va trang thai su dung.
- `trip`: tao lich trinh, nhac lich va cap nhat chuyen di.
- `account`: thanh toan, subscription, bao mat va thay doi tai khoan.

Nguoi dung co the tat toan bo push notification hoac tat rieng tung nhom. Tat
push khong xoa lich su thong bao trong ung dung.

## Hien trang

- Flutter chua co `firebase_core`, `firebase_messaging` va
  `flutter_local_notifications`.
- Android chua co Google Services plugin, `google-services.json` va quyen
  `POST_NOTIFICATIONS`.
- Man hinh Notification dang dung `MockNotificationRepository`.
- Badge tai Home doc so luong chua doc tu mock repository.
- Loyalty luu tuy chon notification trong SharedPreferences va tao thong bao
  mock.
- Profile co switch Notification chi thay doi state tren UI.
- Database da co bang `notification`, nhung chua co bang device token,
  preference theo loai va RLS day du.
- `NotificationTarget` va `NotificationActionHandler` da co san, co the tai su
  dung de dieu huong khi bam push notification.

## Kien truc lua chon

Su dung Supabase lam nguon du lieu va backend nghiep vu duy nhat. Firebase chi
dam nhiem kenh van chuyen push notification.

```text
Domain event
    -> Supabase notification record
    -> notification-dispatch Edge Function
    -> FCM HTTP v1
    -> Android device
    -> firebase_messaging
    -> flutter_local_notifications (foreground)
    -> NotificationTarget router
```

Khong goi FCM truc tiep tu Flutter va khong dua Firebase service account vao
ung dung. Edge Function su dung service account qua Supabase Secrets.

## Mo hinh du lieu

### `notification`

Tai su dung bang hien co va bo sung cac cot can thiet:

- `notification_type`: mot trong nam nhom thong bao.
- `payload_jsonb`: du lieu phuc vu UI va dieu huong, bao gom
  `NotificationTarget`.
- `is_in_app`, `is_push`: kenh gui duoc yeu cau.
- `status`: `queued`, `processing`, `sent`, `partial`, `failed` hoac
  `in_app_only`.
- `sent_at`, `read_at`, `push_error`: trang thai phat va doc.

Moi notification chi thuoc mot `id_user`. Client chi doc va cap nhat thong bao
cua chinh minh qua RLS.

### `user_push_device`

Luu tung installation cua nguoi dung:

- `id_device` UUID.
- `id_user` tham chieu `user_account`.
- `fcm_token` unique.
- `platform` (`android`, `ios`, `web`).
- `installation_id` de phan biet cac ban cai.
- `is_active`, `last_seen_at`, `created_at`, `updated_at`.

Token refresh duoc upsert. Khi dang xuat, token cua installation hien tai duoc
vo hieu hoa truoc khi session bi xoa. Mot user co the co nhieu thiet bi.

### `user_notification_preference`

Moi user co mot dong cho moi `notification_type`:

- `id_user`.
- `notification_type`.
- `push_enabled`.
- `in_app_enabled`.
- `created_at`, `updated_at`.

Mot preference tong the `all` duoc luu rieng trong cung bang hoac trong bang
setting cua user. Khi push, he thong yeu cau ca preference tong the va
preference cua nhom deu bat. Mac dinh ca hai kenh deu bat neu chua co dong
preference.

## Edge Functions

### `notifications`

API da muc dich cho client da xac thuc:

- `register-device`: upsert token cho user dang dang nhap.
- `unregister-device`: vo hieu hoa token hien tai.
- `list`: phan trang notification moi nhat.
- `unread-count`: lay badge count.
- `mark-read`: danh dau mot notification da doc.
- `mark-all-read`: danh dau tat ca da doc.
- `get-preferences`: doc cac tuy chon.
- `update-preference`: cap nhat mot nhom hoac master switch.

### `notification-dispatch`

Function noi bo dung service role:

1. Nhan `id_notification` hoac payload tao notification.
2. Khoa/claim notification dang `queued` de tranh gui lap.
3. Doc preference cua user.
4. Neu push bi tat, giu notification trong app va dat `in_app_only`.
5. Doc cac device token dang active.
6. Tao OAuth access token tu Firebase service account.
7. Gui FCM HTTP v1 den tung thiet bi.
8. Vo hieu hoa token ma FCM bao khong con hop le.
9. Cap nhat `sent`, `partial` hoac `failed` cung loi rut gon.

Viec tao notification phai duoc goi tu server-side domain flow hoac database
trigger, khong cho client tu tao notification cho user khac.

## Flutter

### Khoi tao

- Chi khoi tao Firebase Messaging tren Android trong phase bootstrap phu hop.
- Tao Android notification channel mot lan.
- Yeu cau quyen Android 13+ khi user bat Notification hoac sau dang nhap, co
  giai thich ngan truoc khi hien system prompt.
- Sau khi co session, lay FCM token va dang ky voi Supabase.
- Lang nghe `onTokenRefresh` va auth state de dong bo token.

Flutter Web khong khoi tao push Android, do do khong yeu cau Firebase Web config
va khong lam hong admin/web build.

### Nhan thong bao

- Foreground: `FirebaseMessaging.onMessage` hien native notification bang
  `flutter_local_notifications` va refresh inbox/badge.
- Background: Android hien notification tu FCM notification payload.
- App opened from background: `onMessageOpenedApp` xu ly payload.
- Cold start: `getInitialMessage` xu ly sau khi router va auth da san sang.
- Notification duoc tao foreground: callback cua
  `flutter_local_notifications` dung cung bo xu ly payload.

Tap event duoc queue neu router chua san sang. Sau bootstrap, payload duoc chuyen
thanh `NotificationTarget` va tai su dung `NotificationActionHandler`.

### Repository va UI

- Tao `SupabaseNotificationRepository`, thay default mock repository.
- Notification page load theo trang, co refresh, unread count va mark read.
- Home bell badge dung cung controller/repository, khong doc mock singleton.
- Profile Notification mo trang settings thay vi switch UI-only.
- Settings co master switch va nam switch nhom.
- Loyalty page doc/cap nhat preference `loyalty` qua cung repository, bo key
  SharedPreferences cu sau khi migrate.

## Nguon phat su kien

Dot dau noi cac flow that dang co:

- Loyalty award approved, voucher redeemed/granted va rank changed.
- Forum comment/reply va cac tuong tac co nguoi nhan xac dinh.
- Trip generated/saved/reminder.
- Payment/subscription success va account/security events.

Moi noi goi mot helper server-side chung de tao notification theo cung schema.
Khong nhan ban logic goi FCM trong tung feature.

## Bao mat

- Firebase service account chi ton tai trong Supabase Secrets.
- Client chi gui token cua chinh session hien tai.
- RLS gioi han notification, token va preference theo `auth.uid()`.
- Service-role dispatch endpoint khong chap nhan request cong khai khong co
  internal secret hoac service authorization.
- Log khong ghi FCM token day du, private key hay payload nhay cam.
- Payload chi chua ID/deeplink can thiet; man hinh dich doc du lieu moi tu DB.

## Cau hinh bat buoc ngoai repository

Nguoi quan tri Firebase can:

1. Tao Firebase project va Android app dung package hien tai
   `com.example.hellovietnam` (hoac doi package truoc khi tao neu sap publish).
2. Dat `google-services.json` tai `frontend/android/app/`; file nay khong commit.
3. Tao Firebase service account dung de gui FCM HTTP v1.
4. Dat `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL` va
   `FIREBASE_PRIVATE_KEY` trong Supabase Secrets.
5. Deploy migration va hai Edge Functions.

## Kiem thu

- Unit test payload parsing, preference merge, token upsert va pending tap.
- Repository test pagination, unread count va mark read.
- Widget test notification settings va notification inbox.
- Deno test auth, preference filtering, invalid-token cleanup va idempotent
  dispatch.
- Android manual test: foreground, background, killed app, logout/login user
  khac, token refresh, tat master va tat tung nhom.
- Chay `flutter analyze`, Flutter tests va Deno tests truoc khi hoan tat.

## Pham vi khong lam trong dot nay

- iOS push notification.
- Firebase Web Push cho Flutter Web.
- Rich media notification va notification action buttons.
- Gui hang loat theo segment/marketing campaign.


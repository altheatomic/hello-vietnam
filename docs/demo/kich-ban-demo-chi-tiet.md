# Kịch bản demo và kiểm thử theo chức năng - Hello Vietnam

Ngày soạn: 2026-07-13
Branch tham chiếu: `feature/be-review`
Tài liệu yêu cầu: `docs/README_demo_testing.md`

Tài liệu này được tổ chức theo nhóm chức năng. Mỗi phần bên dưới là một nhóm chức năng; mỗi dòng là một case cần demo/kiểm thử, gồm bước thao tác và kết quả cần có. Các mục trong README nhưng chưa thấy đủ route, màn hình, API hoặc dữ liệu mock trong code hiện tại đã được loại khỏi danh sách case chính.

## 1. Phạm vi có thể demo theo code

| Nhóm | Route/màn hình | Source chính | Trạng thái |
|---|---|---|---|
| Auth | `/login`, `/register`, `/forgot-password` | `frontend/lib/features/auth/presentation` | Có source |
| Onboarding sở thích | `/onboarding/travel-preferences` | `features/personalization` | Có source + repository |
| Home | `/home` | `features/home` | Có source |
| Explore | `/explore`, `/explore-search`, `/explore-search-result`, `/explore-category` | `features/explore` | Có source + API/mock fallback |
| Detail | `/details/activities`, `/details/culture`, `/details/food`, `/details/local-products` | `features/item_detail` | Có source |
| Wishlist | `/wishlist`, nút favorite trong card/detail | `features/profile/data/wishlist_repository.dart` | Có source + API |
| Review | Section trong detail | `features/reviews` | Có source + API |
| Report | Popup report detail, forum report | `features/report`, `features/forum` | Có source |
| Recommend | `/recommend`, `/recommend/where-search`, `/recommend/when-calendar`, `/recommend/when-results` | `features/recommend` | Có source, mock data |
| Trip Planner | `/trip-planner/*` | `features/planner` | Có source, mock/partial |
| Translate/TTS | `/translate` | `features/translate` | Có source, phụ thuộc env/API |
| AI Search | `/ai-search` | `features/ai_search` | Có source, phụ thuộc env/API |
| Popular Apps | `/popular-apps` | `features/popular_apps` | Có source, mock data |
| Forum | `/forum/*` | `features/forum` | Có source |
| Profile/Settings | `/profile`, `/edit-profile`, `/change-password`, `/language`, `/currency`, `/profile/delete-user-data` | `features/profile` | Có source |
| Loyalty/Voucher/Premium | `/loyalty`, `/voucher`, `/voucher-detail`, `/rank-benefits`, `/upgrade-account`, `/upgrade-payment` | `features/loyalty`, `features/profile` | Có source, một phần phụ thuộc env |
| Notification/Feedback | `/notification`, `/send-feedback` | `features/notification`, `features/feedback` | Có source |
| Admin | `/admin/*` | `features/admin` | Có source |

## 2. Dữ liệu chuẩn bị

| Loại dữ liệu | Cần chuẩn bị | Mục đích |
|---|---|---|
| User mới | Email/password chưa có preferences hoặc đã reset preferences | Kiểm tra đăng ký, onboarding, cold start |
| User có hành vi | Email/password có sẵn preferences và vài event Explore | Kiểm tra personalization |
| Admin | Tài khoản có quyền vào admin route | Kiểm tra quản trị |
| Nội dung Explore | Có ít nhất 1 item mỗi nhóm Activity, Culture, Food, Local Products | Kiểm tra Explore/detail/wishlist/review/report |
| Dữ liệu trip | Dùng mock planner hiện có | Kiểm tra flow planner, result, day detail, map |
| Env ngoài | Supabase, DeepSeek, Stripe nếu demo translate/AI/payment | Tránh lỗi do thiếu secret |

## 3. Auth và phiên đăng nhập

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| AUTH-01 | Mở app khi chưa đăng nhập | Get Started/Login | Mở app từ trạng thái chưa có session | Không có | Router giữ user ở Get Started hoặc Login | Không vào Home/Profile riêng tư khi chưa đăng nhập | Có |
| AUTH-02 | Đăng nhập thành công | `/login` | Nhập email/password đúng, bấm Sign in | User demo hợp lệ | `AuthRepository.signIn` tạo session | Điều hướng đến Home hoặc Onboarding nếu thiếu preferences | Có |
| AUTH-03 | Bỏ trống email | `/login` | Để trống email, nhập password, bấm Sign in | Email rỗng | UI validate field trước khi gọi API | Hiển thị lỗi `Please enter your email` | Có |
| AUTH-04 | Bỏ trống password | `/login` | Nhập email, để trống password, bấm Sign in | Password rỗng | UI validate field trước khi gọi API | Hiển thị lỗi `Please enter your password` | Có |
| AUTH-05 | Sai mật khẩu | `/login` | Nhập email đúng, password sai, bấm Sign in | Password sai | Supabase auth trả lỗi | Snackbar `Failed to sign in: ...`; user vẫn ở Login | Có |
| AUTH-06 | Email chưa tồn tại | `/login` | Nhập email không có trong hệ thống | Email lạ | Supabase auth trả lỗi | Hiển thị lỗi đăng nhập, không tạo session | Có |
| AUTH-07 | Google sign in thành công | `/login` | Bấm Google sign in | Tài khoản Google hợp lệ | `signInWithGoogle` chạy OAuth | Điều hướng theo auth state | Có, phụ thuộc cấu hình OAuth |
| AUTH-08 | Google sign in lỗi | `/login` | Bấm Google sign in khi OAuth/env lỗi | Không áp dụng | Catch exception | Snackbar `Google sign in failed: ...` | Có, phụ thuộc env |
| AUTH-09 | Chuyển sang đăng ký | `/login` -> `/register` | Bấm link Sign up/Register | Không có | Router chuyển route | Màn hình Register mở đúng | Có |
| AUTH-10 | Đăng xuất | `/profile` | Bấm Logout | User đang đăng nhập | `AuthRepository.signOut` xóa session | Điều hướng về Login; route riêng tư cần login lại | Có |

## 4. Đăng ký tài khoản

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| REG-01 | Đăng ký thành công | `/register` | Nhập username/email/password/confirm, bấm Register | Email mới, password hợp lệ | `AuthRepository.signUp` gọi Supabase | Snackbar yêu cầu kiểm tra email xác nhận; điều hướng Login | Có |
| REG-02 | Bỏ trống trường | `/register` | Để trống một trong các field, bấm Register | Thiếu username/email/password/confirm | UI validate trước API | Snackbar `Please fill in all fields` | Có |
| REG-03 | Password confirm không khớp | `/register` | Nhập password và confirm khác nhau | Password A, confirm B | UI so sánh password | Snackbar `Passwords do not match`; không gọi đăng ký thành công | Có |
| REG-04 | Email đã tồn tại hoặc Supabase từ chối | `/register` | Nhập email đã dùng, bấm Register | Email đã có | Supabase trả lỗi | Snackbar hiển thị lỗi từ exception; vẫn ở Register | Có |
| REG-05 | Chuyển về Login | `/register` | Bấm link Login | Không có | Router chuyển route | Màn hình Login mở đúng | Có |

## 5. Quên mật khẩu và đổi mật khẩu qua email

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| FP-01 | Mở quên mật khẩu từ Login | `/login` -> `/forgot-password` | Bấm `Forgot password?` | Không có | Router push forgot password | Màn hình nhập email reset mở đúng | Có |
| FP-02 | Gửi reset email thành công | `/forgot-password` | Nhập email hợp lệ, bấm Confirm email | Email user demo | `resetPassword(email)` chạy | Snackbar `Password reset email sent`; chuyển bước Check email | Có, phụ thuộc email config |
| FP-03 | Email rỗng | `/forgot-password` | Bấm Confirm email khi chưa nhập | Rỗng | UI validate | Snackbar `Please enter your email` | Có |
| FP-04 | Email sai format | `/forgot-password` | Nhập chuỗi không phải email | `abc` | UI regex validate | Snackbar `Please enter a valid email address` | Có |
| FP-05 | Gửi lại email | `/forgot-password` | Ở bước Check email, bấm resend | Email đã nhập | `resetPassword(email)` chạy lại | Snackbar `Password reset email resent` hoặc lỗi rate limit | Có |
| FP-06 | Rate limit reset email | `/forgot-password` | Gửi reset nhiều lần liên tục | Email hợp lệ | Supabase/backend trả rate limit | Snackbar báo chờ trước khi thử lại | Có, phụ thuộc Supabase |
| FP-07 | Bấm xác minh khi chưa có session reset | `/forgot-password` | Ở bước Check email, bấm verify/đã click link nhưng chưa có session | Không có session | Kiểm tra `currentSession` | Snackbar yêu cầu click reset link trong email | Có |
| FP-08 | Tạo password mới thành công | `/forgot-password` | Mở bằng reset link hợp lệ, nhập password mới, confirm, submit | Password >= 6 và khớp | `updatePassword` chạy | Snackbar thành công, chuyển bước success | Có, phụ thuộc reset link |
| FP-09 | Password mới rỗng | `/forgot-password` | Ở bước new password, bỏ trống field | Rỗng | UI validate | Snackbar `Please fill in all fields` | Có |
| FP-10 | Password mới quá ngắn | `/forgot-password` | Nhập password < 6 ký tự | `123` | UI validate length | Snackbar `Password must be at least 6 characters long` | Có |
| FP-11 | Confirm password không khớp | `/forgot-password` | Nhập password và confirm khác nhau | Password A/B | UI so sánh | Snackbar `Passwords do not match` | Có |

## 6. Onboarding và sở thích du lịch

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| ONB-01 | User mới bị chuyển vào onboarding | Sau Login/Register | Đăng nhập user chưa hoàn tất preferences | User chưa có preferences | Router kiểm tra `TravelPreferencesRepository` | Điều hướng `/onboarding/travel-preferences` | Có |
| ONB-02 | Chọn sở thích thành công | `/onboarding/travel-preferences` | Chọn các option sở thích, bấm hoàn tất | Ví dụ Food, Culture, Nature | Repository lưu preferences | Chuyển về Home hoặc return route | Có |
| ONB-03 | Reload sau onboarding | Home -> reload app | Reload hoặc mở lại app | User đã có preferences | Repository load trạng thái completed | Không bị đưa lại onboarding | Có |
| ONB-04 | User đã defer/hoàn tất onboarding vào Login | `/login` | Đăng nhập user đã có preferences | User cũ | Router kiểm tra preferences | Chuyển Home, không hiện onboarding | Có |
| ONB-05 | API/preferences lỗi | Onboarding | Submit khi API lỗi/mất mạng | Sở thích đã chọn | Repository trả lỗi | UI không mất lựa chọn hoặc hiển thị lỗi hợp lệ | Có, cần kiểm thử thực tế |

## 7. Home

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| HOME-01 | Mở Home sau đăng nhập | `/home` | Login thành công và vào Home | Không có | Load home data | Home render không crash | Có |
| HOME-02 | Shortcut Explore | `/home` | Bấm shortcut/feature Explore | Không có | Router chuyển Explore | Mở `/explore` | Có |
| HOME-03 | Shortcut Trip Planner | `/home` | Bấm Trip Planner | Không có | Router chuyển planner | Mở `/trip-planner` hoặc bước đầu của planner | Có |
| HOME-04 | Shortcut Recommend/Popular Apps nếu có | `/home` | Bấm các feature card tương ứng | Không có | Router chuyển đúng route | Màn hình đích mở đúng | Có |
| HOME-05 | Active trip hiển thị trên Home | `/home` | Start trip ở planner rồi quay lại Home | Trip đã start | `TripStore` đọc active trip local | Home hiển thị trạng thái trip hoặc card liên quan | Partial |
| HOME-06 | Home khi dữ liệu lỗi/rỗng | `/home` | Mở Home khi repository không có data | Không có | UI xử lý empty/loading | Không crash, có empty/loading state hợp lệ | Có, cần kiểm thử thực tế |

## 8. Explore tổng quan và tìm tỉnh/thành

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| EXP-01 | Mở Explore tổng quan | `/explore` | Bấm Explore từ Home/nav | Không có | `getExploreSections` hoặc cache load | Có các section Activity, Culture, Food, Local Products | Có |
| EXP-02 | Explore có dữ liệu fallback/cache | `/explore` | Mở lại Explore sau lần đầu | Không có | Repository đọc cache local nếu có | Render nhanh, không mất toàn bộ dữ liệu khi reload | Có |
| EXP-03 | Tìm tỉnh/thành hợp lệ | `/explore-search` | Nhập từ khóa thành phố | `Ha Noi` | Gọi `searchExploreProvinces` | Hiển thị danh sách tỉnh/thành phù hợp | Có |
| EXP-04 | Từ khóa rỗng | `/explore-search` | Để rỗng ô search | Rỗng | Không gọi API vô ích hoặc trả empty | Không crash, có state gợi ý/empty hợp lệ | Có |
| EXP-05 | Không tìm thấy tỉnh/thành | `/explore-search` | Nhập chuỗi không khớp | `zzzz` | API trả empty | Hiển thị empty state dễ hiểu | Có |
| EXP-06 | Chọn tỉnh/thành từ search | `/explore-search-result` | Bấm một tỉnh/thành trong list | Province object | Router truyền extra và load result | Màn hình result hiển thị đúng tên tỉnh/thành | Có |
| EXP-07 | Filter category trong result | `/explore-search-result` | Chọn Activity/Culture/Food/Local Products | Tab category | Load items theo category | Chỉ hiển thị item đúng nhóm đang chọn | Có |
| EXP-08 | Lỗi API Explore | `/explore` hoặc result | Tắt network/API fail | Không có | Catch error, dùng cache/empty/error state | Không crash; có retry hoặc thông báo hợp lệ | Có, cần kiểm thử thực tế |

## 9. Explore category và card item

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| CAT-01 | Mở category Activity | `/explore-category` | Chọn tab Activity | Activity | Gọi `getExploreCategoryItems` | List Activity không lẫn Food/Culture | Có |
| CAT-02 | Mở category Culture | `/explore-category` | Chọn tab Culture | Culture | Gọi API theo category | List Culture đúng nhóm | Có |
| CAT-03 | Mở category Food | `/explore-category` | Chọn tab Food | Food | Gọi API theo category | List Food đúng nhóm | Có |
| CAT-04 | Mở category Local Products | `/explore-category` | Chọn tab Local Products | Local Products | Gọi API theo category | List sản phẩm địa phương đúng nhóm | Có |
| CAT-05 | Category rỗng | `/explore-category` | Chọn category không có item trong data | Category bất kỳ | API trả empty | Empty state `No ... found` hoặc tương đương | Có |
| CAT-06 | Favorite từ card | Category/result card | Bấm icon heart trên item | User đã login | Wishlist API toggle + tracking favorite/unfavorite | Icon đổi trạng thái; snackbar lỗi nếu chưa login/API lỗi | Có |
| CAT-07 | Favorite khi chưa login | Category/result card | Bấm heart khi không có session | Chưa login | UI kiểm tra session | Snackbar `Please sign in to update wishlist.` | Có |
| CAT-08 | Mở detail từ card | Category/result card | Bấm item/card | Item bất kỳ | Router sang detail route theo category | Detail đúng item/category mở ra | Có |

## 10. Cá nhân hóa Explore và tracking hành vi

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| PER-01 | User chưa có hành vi | Explore | Đăng nhập user mới, mở Explore | User mới | Dựa vào onboarding/default ranking | List không trống; không yêu cầu khác biệt mạnh | Có |
| PER-02 | User có preferences | Explore | Đăng nhập user đã chọn sở thích, mở Explore | User có preferences | Backend dùng `user_interest_tag` nếu đủ tag | Item phù hợp sở thích có ưu tiên hơn default | Có, phụ thuộc data |
| PER-03 | Track xem detail | Detail | Mở một item | Item có id/category | Gửi `recordExploreEvent` type `view_detail` | Không chặn UI nếu tracking fail; event được gửi nếu có token | Có |
| PER-04 | Track favorite | Detail/category card | Favorite item | User login | Gửi event `favorite` | Wishlist đổi trạng thái; tracking không làm crash UI | Có |
| PER-05 | Track unfavorite | Detail/category card | Bấm bỏ favorite | User login | Gửi event `unfavorite` | Item rời wishlist; tracking không làm crash UI | Có |
| PER-06 | Track share | Detail | Bấm share nếu UI hiện | Item detail | Gửi event `share` | Share sheet/flow mở hoặc event được gửi; lỗi không crash | Có |
| PER-07 | Reload sau hành vi | Explore | Favorite/view vài item rồi reopen Explore | User login | Backend có thể sort lại theo final weight | Kết quả có thể đổi nhẹ; không mất diversity | Có, phụ thuộc seed/API |
| PER-08 | Không có token | Detail/category card | Thao tác khi session hết hạn | Token null | Tracking service bỏ qua event | UI chính vẫn hoạt động; không crash | Có |

## 11. Detail item

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| DET-01 | Activity detail | `/details/activities` | Mở Activity item | Activity item | Load shared/detail data | Có ảnh, tên, mô tả, thông tin phụ | Có |
| DET-02 | Culture detail | `/details/culture` | Mở Culture item | Culture item | Load shared/detail data | Có ảnh, tên, mô tả, thông tin phụ | Có |
| DET-03 | Food detail | `/details/food` | Mở Food item | Food item | Load shared/detail data | Có ảnh, tên, mô tả, thông tin phụ | Có |
| DET-04 | Local Product detail | `/details/local-products` | Mở Local Product item | Local Product item | Load shared/detail data | Có ảnh, tên, mô tả, thông tin phụ | Có |
| DET-05 | Back navigation | Detail | Bấm back | Không có | Navigator quay lại list trước đó | Về đúng Explore/category/result, không mất route | Có |
| DET-06 | Favorite trong detail | Detail | Bấm heart | User login | Toggle wishlist | Icon đổi; item vào/rời Wishlist | Có |
| DET-07 | Share trong detail | Detail | Bấm share | Item detail | Tạo shared item/post request nếu source hỗ trợ | Không crash; mở flow chia sẻ hoặc forum create nếu có | Có/partial |
| DET-08 | Report trong detail | Detail | Bấm report/bug icon | Chọn issue | Mở report popup | Popup hiển thị các loại vấn đề | Có |
| DET-09 | Detail thiếu data | Detail | Mở item thiếu ảnh/mô tả | Item incomplete | Fallback image/text | Không crash; UI vẫn đọc được | Có, cần data lỗi |

## 12. Wishlist

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| WISH-01 | Mở Wishlist khi đã login | `/wishlist` | Vào Profile/Wishlist hoặc route | User login | Gọi `listWishlist` | Hiển thị item đã lưu hoặc empty state | Có |
| WISH-02 | Mở Wishlist khi chưa login | `/wishlist` | Mở wishlist không có session | Chưa login | UI kiểm tra auth | Hiển thị yêu cầu sign in | Có |
| WISH-03 | Thêm Food vào Wishlist | Detail/category | Favorite Food item | Food item | `toggleFavoriteByRawId` hoặc `setFavorite` | Food xuất hiện trong Wishlist | Có |
| WISH-04 | Thêm Place/City vào Wishlist | Detail/city | Favorite place/city | Place/city item | Lưu vào bảng tương ứng | Item xuất hiện đúng nhóm nếu UI phân nhóm | Có |
| WISH-05 | Xóa item khỏi Wishlist | `/wishlist` | Bấm remove/unfavorite | Item đang lưu | API remove favorite | Item biến khỏi list, không còn trạng thái favorite | Có |
| WISH-06 | API Wishlist lỗi | `/wishlist` hoặc detail | Tắt API hoặc token lỗi | User login | Catch error | Snackbar `Update wishlist failed: ...` hoặc load error hợp lệ | Có |

## 13. Review

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| REV-01 | Load summary review | Detail | Mở detail item | Item có content type/id | Gọi `getReviewSummary` | Hiển thị average rating và review count hoặc 0 review | Có |
| REV-02 | Load danh sách review | Detail | Cuộn tới Review section | Item có reviews | Gọi `getReviews` | List review hiển thị; nếu rỗng có empty state | Có |
| REV-03 | Lỗi load review | Detail | API reviews lỗi | Không có | Catch error | Hiển thị `Could not load reviews right now` và nút Retry | Có |
| REV-04 | Viết review mới | Detail | Bấm Write a review, chọn sao, nhập comment, publish | Rating 1-5, comment hợp lệ | Gọi `upsertReview` | Review xuất hiện đầu list; summary cập nhật | Có |
| REV-05 | Sửa review đã có | Detail | Bấm Edit your review, đổi rating/comment | Review của user | Gọi `upsertReview` | Review được cập nhật, không tạo duplicate | Có |
| REV-06 | Comment bị moderation chặn | Detail | Submit comment chứa keyword cấm nếu có seed rule | Comment không hợp lệ | Backend moderation reject | UI báo lỗi publish/review, không lưu review | Có, phụ thuộc data |
| REV-07 | Lọc review theo sao | Detail | Bấm filter sao | Star filter | Gọi/hiển thị list theo filter | Chỉ review đúng filter hoặc empty state | Có |
| REV-08 | Chưa login viết review | Detail | Bấm Write review khi chưa login | Chưa login | API/auth từ chối hoặc UI yêu cầu login | Không lưu review; có lỗi dễ hiểu | Có, cần kiểm thử |

## 14. Report nội dung

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| REP-01 | Mở popup report | Detail | Bấm icon report/bug | Item detail | Mở `ReportIssuePopup` | Popup hiện các loại vấn đề | Có |
| REP-02 | Submit report thành công | Popup report | Chọn issue, nhập mô tả nếu có, submit | Issue type + note | Insert vào bảng `report` qua repository | Hiển thị success/thank you; popup đóng hoặc chuyển success | Có |
| REP-03 | Chưa chọn issue | Popup report | Bấm submit khi chưa chọn issue | Không có | UI không cho submit hoặc validate | Không gửi report rỗng | Có |
| REP-04 | API report lỗi | Popup report | Submit khi API lỗi | Issue hợp lệ | Catch exception | Snackbar lỗi, không crash | Có |
| REP-05 | Forum post report | `/forum/report/:postId` | Mở report từ bài forum | Post id | Tạo report cho forum post | Report lưu hoặc báo lỗi hợp lệ | Có |

## 15. Recommend đi đâu/khi nào

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| REC-01 | Mở Recommend | `/recommend` | Bấm feature Recommend | Không có | Load Recommend page | Có lựa chọn gợi ý Where/When | Có |
| REC-02 | Search destination | `/recommend/where-search` | Nhập từ khóa | `Ha Noi`, `Da Lat` | Lọc `recommend_mock_data` | Hiển thị destination phù hợp | Mock |
| REC-03 | Search không có kết quả | `/recommend/where-search` | Nhập chuỗi lạ | `zzzz` | Lọc mock data | Empty state hợp lệ | Mock |
| REC-04 | Xem detail destination | Where result | Bấm một destination | Destination id | Mở thông tin destination | Có ảnh, rating, tags, best time, activities, cuisine/tips nếu data có | Mock |
| REC-05 | Chọn khoảng ngày | `/recommend/when-calendar` | Chọn date range | Date range hợp lệ | Chuyển `/recommend/when-results` | Result hiển thị destination phù hợp tháng/mùa theo mock data | Mock |
| REC-06 | Chưa chọn ngày | `/recommend/when-calendar` | Không chọn range | Không có | Nút tiếp tục disabled | Không chuyển trang khi thiếu date range | Có |
| REC-07 | Favorite từ recommend result | Recommend result | Bấm heart nếu UI có | User login | Wishlist update | Item được lưu hoặc snackbar yêu cầu sign in | Có/partial |

## 16. Trip Planner

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| PLAN-01 | Mở Trip Planner | `/trip-planner` | Bấm Trip Planner từ Home/nav | Không có | Load planner landing/page | Màn hình planner render không crash | Có |
| PLAN-02 | Chọn destination | `/trip-planner/location` | Search/chọn điểm đến | `Ha Noi` hoặc city có trong UI | Lưu lựa chọn trong flow | Có thể đi bước tiếp theo | Có |
| PLAN-03 | Search destination rỗng | Location | Để trống search | Rỗng | UI giữ state | Không crash; không chọn destination sai | Có |
| PLAN-04 | Nhập nơi lưu trú/xuất phát | `/trip-planner/business-location` | Nhập địa chỉ | `Old Quarter, Ha Noi` | Lưu input | Có thể đi bước tiếp theo | Có |
| PLAN-05 | Chọn duration | `/trip-planner/duration` | Chọn số ngày | 3 ngày | Lưu duration | Có thể đi interest/budget | Có |
| PLAN-06 | Chọn interest | `/trip-planner/interest` | Chọn Culture/Food/Nature | Interest list | Lưu interest | Có thể đi budget | Có |
| PLAN-07 | Chọn budget | `/trip-planner/budget` | Chọn budget hoặc nhập custom | Medium hoặc số tiền | Lưu budget | Có thể tạo result | Có |
| PLAN-08 | Thiếu dữ liệu trong flow | Planner steps | Thử đi tiếp khi chưa chọn field bắt buộc | Không đủ input | Step scaffold/UI chặn hoặc vẫn fallback hợp lệ | Không crash, không tạo state lỗi khó hiểu | Có, cần kiểm thử |
| PLAN-09 | Tạo result | `/trip-planner/result` | Hoàn tất flow | Input hợp lệ | Load `TripPlannerMockData.tripDays` | Có danh sách ngày, mỗi ngày có activity/time/description/tips | Mock/partial |
| PLAN-10 | Xem chi tiết ngày | `/trip-planner/result/day/:dayIndex` | Bấm một ngày | Day index | Load activity của ngày | Danh sách activity đúng ngày, có time slot | Mock/partial |
| PLAN-11 | Xem map activity | `/trip-planner/result/day/:dayIndex/map/:activityIndex` | Bấm map/direction trên activity | Day + activity index | Load activity + nearby places | Có info activity, nearby place, distance/ETA nếu data có | Mock/partial |
| PLAN-12 | Activity index sai | Trip map route | Truy cập route với index ngoài range | Index sai | Fallback/guard route | Không crash; quay lại hoặc hiển thị dữ liệu mặc định hợp lệ | Cần kiểm thử |
| PLAN-13 | Start trip | Result | Bấm Start Trip nếu UI có | Trip result | `TripStore.startTrip` lưu SharedPreferences | Home/Saved Trips có active trip | Partial |
| PLAN-14 | Saved Trips | `/trip-planner/saved` | Mở Saved Trips | Có/không active trip | Load local trip state | Có list/card hoặc empty state | Partial |
| PLAN-15 | End/dismiss active trip | Saved/Home | Bấm End/Dismiss nếu UI có | Active trip | `TripStore.endTrip` xóa local state | Active trip biến khỏi Home/Saved | Partial |

## 17. Translate/TTS

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| TR-01 | Mở Translate | `/translate` | Bấm Translate route | Không có | Load page | Có input text, chọn ngôn ngữ, mode Offline/AI nếu UI có | Có |
| TR-02 | Dịch offline | `/translate` | Chọn Offline, nhập câu phổ biến | `Hello` hoặc phrase có trong offline data | Offline service xử lý | Có bản dịch hoặc fallback message | Có |
| TR-03 | Dịch AI thành công | `/translate` | Chọn AI/Premium, nhập câu | `How much is this?` | Gọi API `translate` | Trả bản dịch, không mất input | Có, phụ thuộc env |
| TR-04 | Text rỗng | `/translate` | Bấm Translate khi chưa nhập | Rỗng | UI disabled hoặc validate | Không gọi API; không crash | Có |
| TR-05 | Chọn ngôn ngữ nguồn/đích | `/translate` | Mở language selector, search/chọn language | `Vietnamese`, `English` | Update selected language | Label ngôn ngữ đổi đúng | Có |
| TR-06 | API translate lỗi | `/translate` | Tắt network/secret thiếu | Text hợp lệ | Catch error | Snackbar/thông báo lỗi dễ hiểu | Có |
| TR-07 | TTS thành công | `/translate` | Có bản dịch, bấm nghe | Text dịch | Gọi TTS service/API | Phát âm thanh hoặc trạng thái đang phát | Có, phụ thuộc env/device |
| TR-08 | TTS lỗi | `/translate` | Bấm nghe khi API/audio lỗi | Text dịch | Catch error | Không crash; báo lỗi hợp lệ | Có |

## 18. AI Search

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| AI-01 | Mở AI Search | `/ai-search` | Mở route AI Search | Không có | Load page | UI search/chat render không crash | Có |
| AI-02 | Query hợp lệ | `/ai-search` | Nhập câu hỏi du lịch | `What should I eat in Ha Noi?` | Gọi AI/search service | Có kết quả hoặc câu trả lời | Có, phụ thuộc env/API |
| AI-03 | Query rỗng | `/ai-search` | Submit khi input rỗng | Rỗng | UI validate | Không gọi API; không crash | Có |
| AI-04 | API AI lỗi | `/ai-search` | Tắt API/thiếu secret | Query hợp lệ | Catch error | Hiển thị lỗi dễ hiểu, không mất toàn bộ UI | Có |
| AI-05 | Favorite kết quả AI nếu UI có | `/ai-search` | Bấm favorite trong result | Result item | Wishlist update | Icon đổi hoặc snackbar yêu cầu sign in | Có/partial |

## 19. Popular Apps

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| APP-01 | Mở Popular Apps | `/popular-apps` | Bấm feature Popular Apps | Không có | Load mock data | Danh sách app/guide hiển thị | Mock/có source |
| APP-02 | Xem chi tiết app | `/popular-apps/:id` | Bấm một app | App id | Router mở detail | Detail có nội dung hướng dẫn | Mock/có source |
| APP-03 | App id không hợp lệ | `/popular-apps/:id` | Truy cập id lạ | Id không tồn tại | Detail xử lý missing data | Không crash; có fallback/empty hợp lệ | Cần kiểm thử |

## 20. Forum/community

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| FOR-01 | Mở Forum | `/forum` | Bấm Forum route | Không có | Load forum store/repository | Danh sách post hoặc empty state | Có |
| FOR-02 | Xem thread | `/forum/post/:postId` | Bấm một post | Post id | Load thread | Chi tiết post/comment hiển thị | Có |
| FOR-03 | Tạo post | `/forum/create` | Bấm create, nhập nội dung, submit | Title/content nếu UI yêu cầu | Repository tạo post | Post mới xuất hiện hoặc success state | Có/partial |
| FOR-04 | Tạo post thiếu nội dung | Create post | Submit rỗng | Rỗng | UI validate | Không tạo post rỗng | Có/partial |
| FOR-05 | Saved posts | `/forum/saved` | Mở saved posts | User login | Load saved list | Có list hoặc empty state | Có |
| FOR-06 | Forum notifications | `/forum/notifications` | Mở notifications | User login | Load notification list | Có list hoặc empty state | Có |
| FOR-07 | Forum profile | `/forum/me`, `/forum/profile/:authorId` | Mở profile | Author id | Load user/forum profile | Profile render đúng | Có |
| FOR-08 | Report forum post | `/forum/report/:postId` | Report một post | Post id + reason | Insert report | Success/error state hợp lệ | Có |

## 21. Profile và settings

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| PROF-01 | Mở Profile | `/profile` | Bấm tab/profile | User login | Load auth profile | Hiển thị email/avatar/setting items | Có |
| PROF-02 | Edit profile | `/edit-profile` | Bấm edit, đổi username/email/avatar preset, save | Thông tin mới | Navigator trả result cho Profile | Profile cập nhật hiển thị local | Có |
| PROF-03 | Upload avatar | `/edit-profile` | Chọn/tải avatar nếu UI hỗ trợ | File ảnh | Upload qua storage nếu cấu hình | Snackbar thành công hoặc lỗi hợp lệ | Có/partial |
| PROF-04 | Remove avatar | `/edit-profile` | Bấm remove avatar nếu có | Avatar đã upload | Xóa avatar | Snackbar thành công hoặc lỗi hợp lệ | Có/partial |
| PROF-05 | Change password thành công | `/change-password` | Nhập current/new/confirm, submit | Password hợp lệ | Update password | Success screen, điều hướng Login nếu UI yêu cầu | Có |
| PROF-06 | New password và confirm không khớp | `/change-password` | Nhập new/confirm khác nhau | Password A/B | UI validate | Snackbar `New password and confirm password do not match` | Có |
| PROF-07 | New password giống current | `/change-password` | Nhập current và new giống nhau | Same password | UI validate | Snackbar `New password must be different from current password` | Có |
| PROF-08 | Language | `/language` | Mở Language, chọn ngôn ngữ | Language option | Cập nhật app language/local state | UI đổi label theo ngôn ngữ hoặc lưu lựa chọn | Có |
| PROF-09 | Currency | `/currency` | Mở Currency, chọn tiền tệ | Currency option | Currency service/repository xử lý | Lưu currency, hiển thị currency mới hoặc lỗi hợp lệ | Có |
| PROF-10 | Delete user data | `/profile/delete-user-data` | Mở trang delete data, xác nhận nếu có | User login | Gọi flow xóa dữ liệu nếu có | Success/error rõ ràng, không xóa nhầm nếu chưa confirm | Có |
| PROF-11 | Logout | `/profile` | Bấm Logout | User login | Sign out | Về Login | Có |

## 22. Loyalty, voucher và premium

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| LOY-01 | Mở Loyalty | `/loyalty` | Bấm Loyalty | User login | Load loyalty repository/mock | Hiển thị điểm/rank/benefits nếu data có | Có/partial |
| LOY-02 | Rank benefits | `/rank-benefits` | Mở rank benefits | Không có | Load page | Danh sách quyền lợi hiển thị | Có |
| VOU-01 | Mở Voucher | `/voucher` | Bấm Voucher | User login | Load voucher page | Có list voucher hoặc empty state | Có |
| VOU-02 | Xem voucher detail | `/voucher-detail` | Bấm voucher | Payload voucher | Load detail | Hiển thị code, expiry, điểm, điều kiện | Có |
| SUB-01 | Mở Upgrade Account | `/upgrade-account` | Bấm Upgrade | User login | Load subscription plans | Hiển thị plan, giá, quyền lợi | Có |
| SUB-02 | Chọn plan | `/upgrade-account` | Chọn plan và tiếp tục | Plan id | Router sang payment | Mở `/upgrade-payment` đúng plan | Có |
| SUB-03 | Thanh toán thiếu đăng nhập/env | `/upgrade-payment` | Bấm checkout khi chưa login/thiếu env | Plan id | Repository trả lỗi | Snackbar/error text dễ hiểu | Có/partial |
| SUB-04 | Deep link payment result | `/upgrade-payment?stripe_session_id=...` | Mở link trả về | Session id | Page xử lý query | Hiển thị trạng thái thành công/lỗi theo session | Có, phụ thuộc Stripe |

## 23. Notification và feedback

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| NOTI-01 | Mở Notification | `/notification` | Bấm notification icon/route | User login | Load notification repository | Có list hoặc empty state | Có |
| NOTI-02 | Tap notification action | `/notification` | Bấm một notification có action | Notification item | `notification_action_handler` điều hướng | Đi đúng màn hình đích hoặc bỏ qua an toàn | Có |
| FB-01 | Mở Feedback | `/send-feedback` | Bấm Send Feedback | Không có | Load feedback page | Form feedback hiển thị | Có |
| FB-02 | Submit feedback hợp lệ | `/send-feedback` | Nhập nội dung, submit | Feedback text | Gửi/lưu feedback theo source hiện có | Success hoặc snackbar hợp lệ | Có/partial |
| FB-03 | Submit feedback rỗng | `/send-feedback` | Submit khi rỗng | Rỗng | UI validate | Không gửi feedback rỗng | Có/partial |

## 24. Admin

| Mã | Chức năng/case | Màn hình | Bước thao tác | Dữ liệu nhập | Xử lý mong đợi | Kết quả cần có | Trạng thái source |
|---|---|---|---|---|---|---|---|
| ADM-01 | Mở dashboard | `/admin/dashboard` | Login admin, mở dashboard | Admin user | Load admin dashboard repository/mock | Dashboard không crash, có cards/stats hoặc empty state | Có |
| ADM-02 | Quản lý users | `/admin/users` | Mở Users | Admin user | Load user list | List/search/filter/sort render | Có |
| ADM-03 | Tạo/sửa user nếu UI có | `/admin/users` | Mở form, nhập thông tin, save | User fields | Repository xử lý | Row mới/cập nhật hoặc lỗi hợp lệ | Có/partial |
| ADM-04 | Canned replies | `/admin/canned-replies` | Mở canned replies | Admin user | Load page | List/form hiển thị | Có |
| ADM-05 | Reports | `/admin/reports` | Mở Reports | Có report demo | Load `admin_report_list`/repository | Report list hiển thị; filter/status hoạt động nếu UI có | Có |
| ADM-06 | Feedback | `/admin/feedback` | Mở Feedback | Có feedback demo | Load page | Feedback list hoặc empty state | Có |
| ADM-07 | Food management | `/admin/food` | Mở Food | Food data | Load food repository/mock | List food, search/filter/form hiển thị | Có |
| ADM-08 | Province management | `/admin/provinces` | Mở Provinces | Province data | Load admin content config | List/table/form hiển thị | Có |
| ADM-09 | Place management | `/admin/places` | Mở Places | Place data | Load admin content config | List/table/form hiển thị | Có |
| ADM-10 | Activity management | `/admin/activities` | Mở Activities | Activity data | Load admin content config | List/table/form hiển thị | Có |
| ADM-11 | Culture management | `/admin/cultures` | Mở Cultures | Culture data | Load admin content config | List/table/form hiển thị | Có |
| ADM-12 | Local products management | `/admin/local-products` | Mở Local Products | Local product data | Load admin content config | List/table/form hiển thị | Có |
| ADM-13 | Popular apps management | `/admin/popular-apps` | Mở Popular Apps | App guide data | Load admin popular app page | List/form hiển thị | Có |
| ADM-14 | Admin API lỗi | Bất kỳ admin page | Tắt API/thiếu quyền | Admin route | Repository trả lỗi | Page có error/empty state, không crash | Có, cần kiểm thử |

## 25. Bảng ghi nhận kết quả thực tế

| Mã case | Chức năng | Kết quả cần có | Kết quả thực tế | Đạt/Không đạt | Ghi chú lỗi |
|---|---|---|---|---|---|
| AUTH-02 | Đăng nhập thành công | Có session, điều hướng đúng |  |  |  |
| AUTH-05 | Sai mật khẩu | Báo lỗi, vẫn ở Login |  |  |  |
| FP-02 | Gửi reset email | Báo đã gửi email hoặc lỗi env rõ ràng |  |  |  |
| ONB-02 | Lưu onboarding | Vào Home, không hỏi lại |  |  |  |
| EXP-01 | Explore tổng quan | 4 nhóm nội dung không trống |  |  |  |
| EXP-03 | Search tỉnh/thành | Có kết quả phù hợp |  |  |  |
| CAT-06 | Favorite từ card | Icon đổi, wishlist cập nhật |  |  |  |
| DET-01 | Detail Activity | Detail hiển thị đủ |  |  |  |
| REV-04 | Viết review | Review xuất hiện hoặc lỗi hợp lệ |  |  |  |
| REP-02 | Submit report | Success hoặc lỗi hợp lệ |  |  |  |
| REC-02 | Recommend search | Có destination mock phù hợp |  |  |  |
| PLAN-09 | Trip result | Có ngày/activity/time/tips |  |  |  |
| PLAN-11 | Trip map | Có nearby/distance/tips |  |  |  |
| TR-03 | AI translate | Có bản dịch hoặc lỗi env rõ ràng |  |  |  |
| FOR-03 | Tạo forum post | Post mới hoặc lỗi hợp lệ |  |  |  |
| PROF-05 | Change password | Success hoặc lỗi auth rõ ràng |  |  |  |
| SUB-02 | Chọn premium plan | Sang payment đúng plan |  |  |  |
| ADM-05 | Admin reports | List report hoặc empty state |  |  |  |

## 26. Checklist trước khi chạy demo/kiểm thử

- [ ] App chạy được trên target demo.
- [ ] Có ít nhất một user mới/chưa onboarding.
- [ ] Có ít nhất một user đã có preferences và behavior Explore.
- [ ] Có admin user nếu demo admin.
- [ ] Explore có dữ liệu cho 4 nhóm hoặc có mock fallback.
- [ ] Ít nhất một Food/Culture item mở được detail.
- [ ] Supabase Auth hoạt động.
- [ ] Wishlist API hoạt động hoặc đã chuẩn bị ghi nhận lỗi.
- [ ] Reviews API hoạt động hoặc đã chuẩn bị ghi nhận lỗi.
- [ ] Translate/AI/Stripe chỉ demo nếu env sẵn sàng.
- [ ] Có screenshot/video fallback cho Explore và Trip Planner nếu mạng/API lỗi.

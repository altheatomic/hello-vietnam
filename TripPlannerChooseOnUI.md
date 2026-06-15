# Chức năng chọn sở thích trong Trip Planner

## 1. Mục đích của chức năng

Phần **“What is your interest?”** cho phép người dùng xác định loại trải nghiệm mà họ muốn ưu tiên trong **chuyến đi đang tạo**.

Lựa chọn này khác với sở thích được thu thập trong onboarding:

```text
Sở thích onboarding:
Phản ánh sở thích tương đối lâu dài của người dùng.

Sở thích Trip Planner:
Phản ánh mục tiêu và mong muốn riêng của chuyến đi hiện tại.
```

Ví dụ, hồ sơ dài hạn của người dùng có thể thiên về:

```text
Culture
Coffee
Local Life
```

Nhưng trong chuyến đi hiện tại, người dùng có thể muốn tập trung vào:

```text
Nature & Outdoor
Adventure
```

Vì vậy, lựa chọn tại Trip Planner chỉ được sử dụng để cá nhân hóa chuyến đi hiện tại. Nó không trực tiếp thay đổi `user_interest_tag`.

---

## 2. Vị trí trong flow tạo chuyến đi

Phần chọn sở thích được đặt sau khi hệ thống đã có các thông tin cơ bản như:

```text
điểm đến
ngày bắt đầu
ngày kết thúc
số ngày đi
```

Flow có thể được tổ chức như sau:

```text
Bước 1: Chọn loại Trip Planner hoặc bắt đầu tạo lịch
Bước 2: Chọn điểm đến
Bước 3: Chọn ngày đi
Bước 4: Chọn sở thích cho chuyến đi
Bước 5: Xác nhận và tạo lịch trình
```

Khi đến bước 4, hệ thống đã có một bản ghi `trip_plan` ở trạng thái:

```text
draft
```

Các lựa chọn của người dùng tại bước này sẽ được lưu theo `id_trip_plan`.

---

## 3. Các lựa chọn hiện tại

Màn hình hiện tại có bốn lựa chọn:

| Tên hiển thị      | `option_code`     | Ý nghĩa                                                  |
| ----------------- | ----------------- | -------------------------------------------------------- |
| Culture & History | `culture_history` | Ưu tiên văn hóa, lịch sử, di sản, bảo tàng               |
| Nature & Outdoor  | `nature_outdoor`  | Ưu tiên thiên nhiên, cảnh quan và hoạt động ngoài trời   |
| Adventure         | `adventure`       | Ưu tiên khám phá, vận động và trải nghiệm mạnh           |
| Entertainment     | `entertainment`   | Ưu tiên vui chơi, sự kiện, mua sắm và hoạt động giải trí |

Danh mục này được lấy từ bảng:

```text
trip_interest_option
```

Chỉ các option có:

```text
is_active = true
```

mới được hiển thị.

Thứ tự hiển thị dựa trên:

```text
display_order
```

Do đó, giao diện không cần hard-code cố định bốn option. Backend có thể đọc trực tiếp từ database.

---

## 4. Quy tắc chọn trên giao diện

Đây là màn hình cho phép chọn nhiều lựa chọn.

Quy tắc đề xuất:

```text
Tối thiểu: 1 lựa chọn
Tối đa: 3 lựa chọn
```

### Vì sao cần ít nhất một lựa chọn?

Nếu người dùng không chọn gì, chức năng này không bổ sung được ngữ cảnh cho chuyến đi.

Tuy nhiên, hệ thống vẫn có thể hỗ trợ trường hợp bỏ qua bằng cách sử dụng sở thích dài hạn từ `user_interest_tag`.

Có thể triển khai theo một trong hai cách:

```text
Cách 1:
Bắt buộc chọn tối thiểu một option.

Cách 2:
Cho phép bỏ qua và sử dụng sở thích mặc định của user.
```

Với giao diện hiện tại, nếu nút `Next` chỉ được bật khi đã chọn ít nhất một option thì nên áp dụng cách 1.

### Vì sao nên giới hạn tối đa ba lựa chọn?

Nếu người dùng chọn cả bốn option, sở thích chuyến đi trở nên quá rộng. Khi đó:

```text
trọng số tag bị phân tán
mức ưu tiên subcategory gần như dàn đều
khả năng cá nhân hóa chuyến đi giảm
```

Giới hạn ba option buộc người dùng thể hiện ưu tiên rõ hơn.

---

## 5. Trạng thái lựa chọn trên giao diện

Mỗi option có hai trạng thái:

### Chưa chọn

```text
viền mặc định
không có biểu tượng check
không nằm trong danh sách selected options
```

### Đã chọn

```text
viền nổi bật
tên option đổi màu
hiển thị biểu tượng check
được thêm vào danh sách selected options
```

Khi người dùng nhấn lại vào option đã chọn:

```text
option được bỏ chọn
dòng tương ứng sẽ không được lưu hoặc sẽ bị xóa
```

Nếu người dùng đã chọn đủ số lượng tối đa, hệ thống không nên tự bỏ option cũ. Nên hiển thị thông báo ngắn:

```text
You can select up to 3 interests.
```

---

## 6. Nguồn dữ liệu hiển thị

Frontend lấy danh sách option từ:

```text
trip_interest_option
```

Dữ liệu tối thiểu cần trả về:

```text
id_trip_interest_option
option_code
display_name
description
display_order
is_active
```

Ví dụ response:

```json
[
  {
    "id_trip_interest_option": "uuid-1",
    "option_code": "culture_history",
    "display_name": "Culture & History",
    "description": "Museums, temples, heritage",
    "display_order": 1
  },
  {
    "id_trip_interest_option": "uuid-2",
    "option_code": "nature_outdoor",
    "display_name": "Nature & Outdoor",
    "description": "Hiking, beaches, parks",
    "display_order": 2
  }
]
```

Icon có thể được lưu trong code frontend hoặc bổ sung một cột như:

```text
icon_key
```

vào `trip_interest_option`.

Nếu icon thay đổi theo thiết kế giao diện và không ảnh hưởng thuật toán, giữ icon trong frontend là đủ.

---

## 7. Dữ liệu được giữ tạm trong giao diện

Trong lúc người dùng đang ở màn hình, frontend giữ một danh sách:

```text
selectedInterestOptionIds
```

Ví dụ:

```text
Nature & Outdoor
Adventure
```

sẽ được giữ dưới dạng:

```json
[
  "id-option-nature-outdoor",
  "id-option-adventure"
]
```

Nên sử dụng UUID của option thay vì tên hiển thị vì:

```text
display_name có thể thay đổi
option_code có thể được dùng cho logic
UUID bảo đảm liên kết foreign key chính xác
```

---

## 8. Lưu lựa chọn vào database

Khi người dùng nhấn `Next`, hệ thống lưu lựa chọn vào:

```text
trip_interest_choice
```

Ví dụ người dùng chọn:

```text
Nature & Outdoor
Adventure
```

Database có hai dòng:

| id_trip_plan | id_trip_interest_option | selection_order | source          |
| ------------ | ----------------------- | --------------: | --------------- |
| Trip A       | Nature & Outdoor ID     |               1 | `user_selected` |
| Trip A       | Adventure ID            |               2 | `user_selected` |

Trong đó:

```text
id_trip_plan
```

xác định chuyến đi đang được tạo.

```text
id_trip_interest_option
```

xác định option được chọn.

```text
selection_order
```

lưu thứ tự lựa chọn nếu cần phục vụ giao diện hoặc phân tích.

```text
source
```

cho biết lựa chọn đến từ đâu.

Các giá trị hiện tại:

```text
user_selected
profile_default
system_suggested
```

---

## 9. Ý nghĩa của trường `source`

### `user_selected`

Người dùng trực tiếp chọn option trên màn hình.

Đây là nguồn có độ tin cậy cao nhất đối với chuyến đi hiện tại.

### `profile_default`

Option được hệ thống chọn sẵn dựa trên sở thích dài hạn của người dùng.

Ví dụ user thường thích Nature, màn hình có thể tick sẵn:

```text
Nature & Outdoor
```

Nếu người dùng giữ nguyên và nhấn Next, lựa chọn vẫn có thể được lưu với nguồn:

```text
profile_default
```

### `system_suggested`

Option được hệ thống đề xuất dựa trên địa điểm, mùa, số ngày hoặc dữ liệu khác.

Ví dụ user chọn một tỉnh nổi bật với du lịch biển, hệ thống có thể đề xuất:

```text
Nature & Outdoor
```

Tuy nhiên, chỉ nên lưu `system_suggested` nếu hệ thống thực sự thêm option vào trip. Nếu chỉ hiển thị gợi ý mà người dùng chưa chọn, không nên lưu vào `trip_interest_choice`.

---

## 10. Cách xử lý khi người dùng quay lại sửa

Nếu người dùng quay lại bước chọn sở thích, frontend cần tải các lựa chọn đã lưu:

```text
trip_interest_choice
join trip_interest_option
```

Các option đã có trong `trip_interest_choice` được hiển thị ở trạng thái selected.

Khi người dùng thay đổi và nhấn `Next`, có thể xử lý theo hai cách.

### Cách đơn giản

Xóa toàn bộ lựa chọn cũ của trip:

```sql
delete from public.trip_interest_choice
where id_trip_plan = :id_trip_plan;
```

Sau đó insert lại danh sách mới.

Cách này phù hợp vì mỗi trip chỉ có một số lượng lựa chọn rất nhỏ.

### Cách upsert và xóa phần thừa

```text
Upsert các option đang được chọn.
Xóa các option không còn trong danh sách mới.
```

Cách này phức tạp hơn nhưng giữ được `created_at` của các dòng không thay đổi.

Với hệ thống hiện tại, cách xóa rồi insert lại là đủ đơn giản và an toàn nếu chạy trong transaction.

---

## 11. Transaction khi lưu

Việc cập nhật lựa chọn nên được thực hiện trong một transaction:

```text
Bắt đầu transaction
→ xóa lựa chọn cũ
→ insert lựa chọn mới
→ cập nhật updated_at của trip_plan
→ commit
```

Nếu insert bị lỗi:

```text
rollback
```

Như vậy tránh trường hợp trip bị mất toàn bộ lựa chọn do quá trình lưu chỉ hoàn thành một phần.

---

## 12. Kiểm tra dữ liệu phía backend

Frontend có thể giới hạn số lựa chọn, nhưng backend vẫn phải kiểm tra lại.

Các validation cần có:

```text
id_trip_plan tồn tại
trip thuộc đúng user đang đăng nhập
trip chưa bị cancelled
tất cả option đều tồn tại
tất cả option đều is_active = true
không có option trùng
số lựa chọn nằm trong giới hạn cho phép
```

Ví dụ:

```text
1 ≤ số option ≤ 3
```

Không nên chỉ dựa vào giao diện vì request có thể bị sửa trực tiếp.

---

## 13. Không cập nhật `user_interest_tag`

Lựa chọn ở màn hình này không được ghi trực tiếp vào:

```text
user_interest_tag
```

Lý do là `user_interest_tag` phản ánh hồ sơ sở thích dài hạn, trong khi lựa chọn Trip Planner chỉ có hiệu lực với một chuyến đi.

Ví dụ:

```text
User chọn Adventure cho chuyến đi với bạn bè
```

không đủ để kết luận rằng user có sở thích Adventure lâu dài.

Dữ liệu chỉ nên được dùng khi tính chuyến đi có `id_trip_plan` tương ứng.

---

## 14. Chuyển lựa chọn thành tag của chuyến đi

Sau khi lưu `trip_interest_choice`, thuật toán join qua:

```text
trip_interest_option_tag
```

để lấy các tag tương ứng.

Ví dụ:

```text
Nature & Outdoor
→ nature: 1.0
→ outdoor: 1.0
→ scenic_view: 0.6
→ park: 0.6
→ beach: 0.6
→ lake_river: 0.6
```

Nếu người dùng chọn nhiều option và một tag xuất hiện nhiều lần, raw weight được cộng dồn.

Ví dụ:

```text
Nature & Outdoor → outdoor = 1.0
Adventure → outdoor = 0.6

Tổng outdoor = 1.6
```

Sau đó chuẩn hóa toàn bộ tag để tạo:

```text
trip_weight
```

---

## 15. Chuyển lựa chọn thành ưu tiên subcategory

Thuật toán đồng thời join qua:

```text
trip_interest_option_subcategory
```

để xác định các subcategory cần được ưu tiên trong Diversity.

Ví dụ:

```text
Nature & Outdoor
→ Thiên nhiên & Cảnh quan
→ Công viên & Vườn
→ Biển & Đảo
→ Hồ & Sông
→ Núi rừng & Trekking
```

Điểm ưu tiên của các subcategory được cộng dồn nếu chúng xuất hiện ở nhiều option.

Kết quả này được sử dụng để:

```text
tính số slot cho mỗi subcategory
```

Nó không được dùng trực tiếp làm TagMatch.

---

## 16. Ảnh hưởng đến kết quả gợi ý

Lựa chọn tại màn Trip Planner tác động đến thuật toán ở hai vị trí.

### Tác động đến TagMatch

Các tag được sinh từ option làm tăng trọng số hiệu lực của những tag phù hợp với mục tiêu chuyến đi.

Kết quả:

```text
Place có tag phù hợp với lựa chọn hiện tại sẽ có TagMatch cao hơn.
```

### Tác động đến Diversity

Các subcategory được map từ option sẽ có priority cao hơn khi phân bổ slot.

Kết quả:

```text
Các nhóm địa điểm phù hợp với mục tiêu chuyến đi nhận nhiều candidate slot hơn.
```

Do đó, chức năng không chỉ làm thay đổi thứ tự place trong từng nhóm mà còn thay đổi phân bố nhóm địa điểm trong Top K.

---

## 17. Trường hợp không có lựa chọn

Nếu hệ thống bắt buộc chọn ít nhất một option, trường hợp này không xảy ra.

Nếu cho phép bỏ qua:

```text
trip_interest_choice không có dòng nào cho trip
```

Khi đó:

```text
Không sinh trip_weight.
Không sinh trip_subcategory_priority.
Module 1 dùng user_interest_tag làm đầu vào.
Diversity dùng priority từ hồ sơ dài hạn.
```

Pipeline vẫn tiếp tục hoạt động bình thường.

---

## 18. Trường hợp option bị vô hiệu hóa

Một option có thể được đặt:

```text
is_active = false
```

Khi đó:

```text
không hiển thị cho trip mới
không được thêm mới vào trip_interest_choice
```

Đối với trip cũ đã từng chọn option này, có hai cách:

```text
Giữ dữ liệu lịch sử nhưng không dùng khi regenerate.
Hoặc vẫn dùng mapping cũ để tái tạo kết quả lịch sử.
```

Với hệ thống hiện tại, nên giữ dữ liệu nhưng khi tạo lại lịch, chỉ dùng option đang active. Nếu cần tái hiện chính xác lịch cũ, sau này nên bổ sung version cho mapping.

---

## 19. Log cần lưu hoặc xuất khi chạy

Để kiểm tra chức năng, log nên có:

```text
id_trip_plan
selected_option_codes
choice_sources
mapped_trip_tags
raw_trip_tag_weights
normalized_trip_tag_weights
mapped_subcategories
subcategory_priority_weights
```

Ví dụ:

```text
selected_option_codes:
- nature_outdoor
- adventure
```

```text
mapped_trip_tags:
- nature: 1.0
- outdoor: 1.6
- adventure: 1.0
- activity: 1.0
```

```text
mapped_subcategories:
- Thiên nhiên & Cảnh quan: 1.6
- Núi rừng & Trekking: 1.6
- Biển & Đảo: 0.6
```

Log giúp xác định lỗi nằm ở:

```text
lựa chọn của user
mapping option
cộng raw weight
chuẩn hóa
hay phân bổ slot
```

---

## 20. Kết quả đầu ra của chức năng

Sau khi xử lý xong bước chọn sở thích, phần này cung cấp cho Module 1 hai đầu ra:

```text
trip_normalized_tag_weights
```

Dùng để kết hợp với `user_interest_tag` và tính TagMatch.

```text
trip_subcategory_priorities
```

Dùng để phân bổ slot trong Diversity.

Có thể biểu diễn:

```json
{
  "trip_normalized_tag_weights": {
    "nature": 0.1266,
    "outdoor": 0.2025,
    "adventure": 0.1266
  },
  "trip_subcategory_priorities": {
    "Thiên nhiên & Cảnh quan": 1.6,
    "Núi rừng & Trekking": 1.6,
    "Biển & Đảo": 0.6
  }
}
```

---

## 21. Tóm tắt hoạt động

Luồng của chức năng chọn sở thích trong Trip Planner:

```text
Hiển thị option từ trip_interest_option
        ↓
User chọn từ 1 đến 3 option
        ↓
Lưu vào trip_interest_choice
        ↓
Map option sang tag bằng trip_interest_option_tag
        ↓
Cộng và chuẩn hóa trip tag weight
        ↓
Map option sang subcategory bằng trip_interest_option_subcategory
        ↓
Cộng priority của subcategory
        ↓
Truyền hai kết quả sang Module 1
```

Vai trò chính của chức năng:

```text
1. Ghi nhận ý định riêng của chuyến đi.
2. Điều chỉnh TagMatch theo mục tiêu hiện tại.
3. Điều chỉnh số slot Diversity theo nhóm địa điểm mong muốn.
4. Không làm thay đổi hồ sơ sở thích dài hạn của người dùng.
```

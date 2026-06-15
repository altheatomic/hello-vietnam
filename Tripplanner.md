# Thay đổi của thuật toán sau khi bổ sung sở thích riêng cho Trip Planner

## 1. Bổ sung một nguồn sở thích mới theo từng chuyến đi

Trước đây, Module 1 chỉ sử dụng sở thích dài hạn của người dùng được lưu trong bảng:

```text
user_interest_tag
```

Các trọng số trong bảng này được hình thành từ:

```text
lựa chọn onboarding
+
hành vi sử dụng ứng dụng
```

Sau khi bổ sung màn hình **“What is your interest?”** trong Trip Planner, thuật toán có thêm một nguồn dữ liệu mới là **sở thích riêng của chuyến đi hiện tại**.

Ví dụ, người dùng thường thích văn hóa và cà phê, nhưng trong chuyến đi hiện tại lại chọn:

```text
Nature & Outdoor
Adventure
```

Thuật toán phải ưu tiên ý định của chuyến đi hiện tại hơn sở thích dài hạn, nhưng không được ghi đè hoặc làm thay đổi trực tiếp hồ sơ sở thích lâu dài của người dùng.

Luồng mới:

```text
Sở thích dài hạn của user
+
Sở thích của chuyến đi hiện tại
→ tạo trọng số sở thích hiệu lực
→ tính TagMatch
```

---

## 2. Lưu một bản ghi `trip_plan` trước khi chạy thuật toán

Trước khi người dùng chọn sở thích chuyến đi, hệ thống cần tạo hoặc cập nhật một bản ghi trong bảng:

```text
trip_plan
```

Bản ghi này lưu các thông tin chính của yêu cầu lập lịch:

```text
id_user
id_province
start_date
end_date
total_days
status
```

Khi người dùng chưa hoàn tất toàn bộ flow, trạng thái có thể là:

```text
draft
```

Khi bắt đầu chạy thuật toán:

```text
generating
```

Khi tạo lịch thành công:

```text
generated
```

Nếu thuật toán lỗi:

```text
failed
```

Việc tạo `trip_plan` trước giúp toàn bộ dữ liệu lựa chọn của người dùng được gắn với đúng một chuyến đi cụ thể.

---

## 3. Lưu lựa chọn của người dùng vào `trip_interest_choice`

Khi người dùng chọn một hoặc nhiều option tại màn Trip Planner, hệ thống lưu các lựa chọn vào:

```text
trip_interest_choice
```

Ví dụ người dùng chọn:

```text
Nature & Outdoor
Adventure
```

Bảng sẽ có hai dòng cùng `id_trip_plan`, mỗi dòng tham chiếu đến một option trong bảng `trip_interest_option`.

Dữ liệu này chỉ áp dụng cho chuyến đi hiện tại. Nó không được ghi vào `user_onboarding_choice` và không cập nhật trực tiếp `user_interest_tag`.

Vai trò mới của bước này là:

```text
Lưu lại chính xác người dùng muốn ưu tiên loại trải nghiệm nào trong chuyến đi hiện tại.
```

---

## 4. Đọc cấu hình lựa chọn từ `trip_interest_option`

Sau khi lấy các dòng trong `trip_interest_choice`, hệ thống join với:

```text
trip_interest_option
```

để xác định:

```text
option_code
display_name
is_active
display_order
```

Chỉ các option có:

```text
is_active = true
```

mới được sử dụng để tính toán.

Ví dụ:

```text
nature_outdoor
adventure
```

được xác nhận là hai option hợp lệ trước khi thuật toán tiếp tục đọc mapping tag và mapping subcategory.

---

## 5. Sinh trọng số tag riêng cho chuyến đi

Thuật toán đọc bảng:

```text
trip_interest_option_tag
```

để map mỗi lựa chọn sang các tag tương ứng.

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

```text
Adventure
→ adventure: 1.0
→ activity: 1.0
→ mountain: 0.6
→ outdoor: 0.6
→ amusement: 0.3
```

Các mức trọng số được hiểu như sau:

```text
1.0 = tag chính
0.6 = tag phụ liên quan trực tiếp
0.3 = tag phụ ngữ cảnh
```

Nếu một tag xuất hiện từ nhiều lựa chọn, trọng số của tag đó được cộng dồn.

Ví dụ `outdoor` xuất hiện trong cả hai option:

```text
Nature & Outdoor → outdoor = 1.0
Adventure → outdoor = 0.6
```

Kết quả:

```text
raw_trip_weight(outdoor) = 1.6
```

---

## 6. Chuẩn hóa trọng số tag của chuyến đi

Sau khi cộng dồn toàn bộ tag, hệ thống chuẩn hóa trọng số:

```text
trip_weight(tag)
=
raw_trip_weight(tag)
/
tổng raw_trip_weight của tất cả tag
```

Mục đích là đưa tổng trọng số tag của chuyến đi về:

```text
1
```

Ví dụ:

```text
outdoor raw weight = 1.6
tổng raw weight = 7.9

trip_weight(outdoor)
= 1.6 / 7.9
≈ 0.203
```

Trọng số này chỉ tồn tại trong phạm vi chuyến đi hiện tại.

Có thể tính trực tiếp trong bộ nhớ khi chạy thuật toán. Không bắt buộc lưu thành một bảng riêng nếu hệ thống chưa cần audit chi tiết.

---

## 7. Kết hợp sở thích dài hạn và sở thích chuyến đi

Trước đây, Module 1 sử dụng trực tiếp:

```text
user_interest_tag.final_weight
```

Sau thay đổi, thuật toán tạo:

```text
effective_interest_weight
```

cho từng tag.

Công thức đề xuất:

```text
effective_weight(tag)
=
α × user_final_weight(tag)
+
β × trip_weight(tag)
```

Trong đó:

```text
α = 0.4
β = 0.6
```

Ý nghĩa:

```text
40% dựa trên sở thích dài hạn
60% dựa trên ý định của chuyến đi hiện tại
```

Sở thích chuyến đi được ưu tiên cao hơn vì đây là lựa chọn trực tiếp của người dùng ngay tại thời điểm tạo lịch.

Nếu một tag không tồn tại trong hồ sơ dài hạn:

```text
user_final_weight = 0
```

Nếu một tag không được sinh từ lựa chọn chuyến đi:

```text
trip_weight = 0
```

Sau khi kết hợp, hệ thống chuẩn hóa lại toàn bộ `effective_weight` để tổng bằng 1.

---

## 8. Trường hợp người dùng không chọn sở thích riêng

Màn Trip Planner có thể cho phép người dùng giữ lựa chọn mặc định hoặc bỏ qua.

Nếu không có dòng nào trong `trip_interest_choice`, thuật toán không cần tạo `trip_weight`.

Khi đó:

```text
effective_weight(tag)
=
user_interest_tag.final_weight
```

Module 1 tiếp tục hoạt động như trước đây.

Như vậy, bước chọn sở thích chuyến đi là một lớp điều chỉnh thêm, không làm hệ thống phụ thuộc bắt buộc vào dữ liệu mới.

---

## 9. Thay đổi cách tính TagMatch

Trước đây:

```text
TagMatch
=
so khớp place_tag với user_interest_tag.final_weight
```

Sau thay đổi:

```text
TagMatch
=
so khớp place_tag với effective_interest_weight
```

Các bước tính còn lại không thay đổi:

```text
1. Lấy danh sách tag của place.
2. Join với effective_interest_weight theo id_tag hoặc tag_code.
3. Nhân trọng số user/trip với confidence_score của place_tag.
4. Cộng điểm các tag trùng.
5. Chuẩn hóa theo công thức TagMatch hiện tại.
```

Điểm khác biệt duy nhất là đầu vào không còn chỉ là trọng số dài hạn của người dùng.

---

## 10. Bổ sung mức ưu tiên subcategory theo chuyến đi

Ngoài mapping tag, mỗi option còn được map sang các subcategory thông qua bảng:

```text
trip_interest_option_subcategory
```

Ví dụ:

```text
Nature & Outdoor
→ Thiên nhiên & Cảnh quan: 1.0
→ Công viên & Vườn: 0.6
→ Biển & Đảo: 0.6
→ Hồ & Sông: 0.6
→ Núi rừng & Trekking: 0.6
```

```text
Adventure
→ Núi rừng & Trekking: 1.0
→ Vui chơi giải trí: 0.6
→ Thiên nhiên & Cảnh quan: 0.6
```

Nếu cùng một subcategory xuất hiện ở nhiều option, điểm ưu tiên được cộng dồn.

Ví dụ:

```text
Thiên nhiên & Cảnh quan
= 1.0 từ Nature & Outdoor
+ 0.6 từ Adventure
= 1.6
```

```text
Núi rừng & Trekking
= 0.6 từ Nature & Outdoor
+ 1.0 từ Adventure
= 1.6
```

Điểm này không dùng để tính TagMatch. Nó chỉ dùng để phân bổ slot trong bước Diversity.

---

## 11. Thay đổi cách xác định priority cho Diversity

Trước đây, Diversity chủ yếu dựa trên sở thích onboarding và hồ sơ dài hạn để xác định subcategory liên quan.

Sau thay đổi, mức ưu tiên subcategory được tính từ hai nguồn:

```text
priority dài hạn từ user profile
+
priority trực tiếp từ trip interest
```

Nên ưu tiên trip interest cao hơn.

Công thức có thể áp dụng:

```text
effective_subcategory_priority
=
0.4 × profile_subcategory_priority
+
0.6 × trip_subcategory_priority
```

Hoặc ở phiên bản đơn giản hơn:

```text
Nếu trip có lựa chọn riêng:
    dùng trip_subcategory_priority làm nguồn chính

Nếu trip không có lựa chọn riêng:
    dùng profile_subcategory_priority
```

Phương án đầu tiên mềm hơn vì vẫn giữ được ảnh hưởng từ hồ sơ dài hạn.

---

## 12. Thay đổi bước phân bổ slot theo subcategory

Diversity vẫn hoạt động theo mô hình slot-based:

```text
1. Gom place theo subcategory.
2. Xếp hạng place trong từng subcategory theo TagMatch.
3. Cấp số slot cho từng subcategory.
4. Lấy Top N place trong mỗi subcategory.
5. Gộp thành diversified_top_k.
```

Điểm thay đổi nằm ở bước cấp slot.

Trước đây, slot được cấp chủ yếu dựa trên profile chung của người dùng.

Sau thay đổi:

```text
Subcategory được map trực tiếp từ lựa chọn Trip Planner
→ được tăng priority
→ được nhận nhiều slot hơn
```

Ví dụ user chọn:

```text
Nature & Outdoor
Adventure
```

thì các nhóm sau được ưu tiên:

```text
Thiên nhiên & Cảnh quan
Núi rừng & Trekking
Biển & Đảo
Công viên & Vườn
Hồ & Sông
Vui chơi giải trí
```

Các subcategory không liên quan vẫn có thể nhận một số slot bổ sung nếu cần đủ Top K, nhưng không được ưu tiên cao hơn nhóm người dùng vừa chọn.

---

## 13. Xếp hạng place riêng trong từng subcategory

Sau khi có `effective_interest_weight`, TagMatch của place đã phản ánh cả:

```text
sở thích dài hạn
+
ý định chuyến đi
```

Trong mỗi subcategory, hệ thống sắp xếp:

```text
module1_score giảm dần
```

Nếu `module1_score` hiện tại bằng TagMatch:

```text
module1_score = TagMatch
```

Nếu bằng điểm tổng hợp:

```text
module1_score
=
w1 × TagMatch
+
w2 × rating_score
+
w3 × popularity_score
```

thì vẫn sử dụng công thức đã có.

Ví dụ subcategory `Biển & Đảo` được cấp 4 slot:

```text
Sort toàn bộ place Biển & Đảo theo module1_score
→ lấy Top 4
```

Nhờ đó, lựa chọn chuyến đi chỉ quyết định mức ưu tiên nhóm và trọng số tag. Nó không khiến hệ thống chọn place ngẫu nhiên.

---

## 14. Xử lý trường hợp subcategory được cấp slot nhưng thiếu place

Một subcategory có thể được cấp 4 slot nhưng chỉ có 2 candidate hợp lệ.

Khi đó:

```text
1. Chọn 2 place hiện có.
2. Hai slot còn thừa được thu hồi.
3. Phân phối lại cho các subcategory còn candidate chưa được chọn.
4. Ưu tiên subcategory có effective priority cao hơn.
```

Việc phân phối lại phải tiếp tục dựa trên:

```text
subcategory priority
số candidate còn lại
module1_score của các candidate
```

Không fill global một cách không kiểm soát như cách diversity cũ.

---

## 15. Bổ sung dữ liệu log cho Module 1

Sau thay đổi, log của Module 1 nên bổ sung:

```text
selected_trip_interest_options
trip_raw_tag_weights
trip_normalized_tag_weights
effective_interest_weights
trip_subcategory_priorities
effective_subcategory_priorities
allocated_slots_by_subcategory
selected_places_by_subcategory
```

Ví dụ:

```text
selected_trip_interest_options:
- nature_outdoor
- adventure
```

```text
effective_subcategory_priorities:
- Thiên nhiên & Cảnh quan: 1.6
- Núi rừng & Trekking: 1.6
- Biển & Đảo: 0.6
- Công viên & Vườn: 0.6
```

Các log này giúp kiểm tra vì sao một subcategory được nhiều slot và vì sao một place được chọn.

---

## 16. Không cập nhật ngược vào hồ sơ dài hạn

Lựa chọn trong Trip Planner không được cập nhật trực tiếp vào:

```text
user_interest_tag.initial_weight
user_interest_tag.final_weight
```

Lý do:

```text
Lựa chọn này chỉ thể hiện ý định của một chuyến đi, không chắc là sở thích lâu dài.
```

Ví dụ user chọn Adventure trong một chuyến đi với bạn bè không có nghĩa user luôn thích Adventure.

Chỉ các hành vi thực tế sau đó, như:

```text
favorite
add_to_trip
check_in
high_rating
```

mới được dùng để cập nhật `behavior_score` và `final_weight` dài hạn.

---

## 17. Thay đổi tổng thể của pipeline

Pipeline trước đây:

```text
user_interest_tag
→ tính TagMatch
→ xếp hạng
→ Diversity
→ Top K
→ Module 2
```

Pipeline sau thay đổi:

```text
user_interest_tag
        +
trip_interest_choice
        ↓
trip_interest_option_tag
        ↓
trip_weight
        ↓
effective_interest_weight
        ↓
tính TagMatch
        ↓
xếp hạng place trong từng subcategory
```

Song song:

```text
trip_interest_choice
        ↓
trip_interest_option_subcategory
        ↓
trip_subcategory_priority
        ↓
effective_subcategory_priority
        ↓
phân bổ slot Diversity
```

Sau đó:

```text
Lấy Top N place trong từng subcategory
→ diversified_top_k
→ Module 2
```

---

## 18. Kết quả của thay đổi

Sau khi bổ sung lựa chọn sở thích trong Trip Planner, thuật toán đạt được ba thay đổi chính:

### Cá nhân hóa theo từng chuyến đi

Một người dùng có thể tạo các chuyến đi với mục tiêu khác nhau mà không làm thay đổi hồ sơ dài hạn.

### TagMatch phản ánh đúng ý định hiện tại hơn

Place có tag liên quan trực tiếp đến option vừa chọn sẽ được tăng điểm thông qua `effective_interest_weight`.

### Diversity cấp slot đúng ngữ cảnh chuyến đi

Các subcategory liên quan trực tiếp đến lựa chọn Trip Planner được ưu tiên slot, nhưng trong từng nhóm vẫn chọn place theo TagMatch.

Phần mới không thay thế thuật toán cũ. Nó thêm một lớp điều chỉnh theo chuyến đi vào hai vị trí:

```text
1. Điều chỉnh trọng số tag trước khi tính TagMatch.
2. Điều chỉnh priority subcategory trước khi phân bổ slot Diversity.
```

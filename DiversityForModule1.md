# Mô tả chi tiết Diversity Selection dạng Slot-Based theo Subcategory

## 1. Mục tiêu của bước Diversity

Sau khi Module 1 tính xong `TagMatch` hoặc `module1_score` cho toàn bộ địa điểm, nếu chỉ sắp xếp toàn bộ place theo điểm giảm dần rồi lấy Top K, kết quả rất dễ bị lệch về một nhóm có tag khớp mạnh nhất.

Ví dụ user chọn `Coffee`, `Food`, `Relaxation`, `Indoor`, thì các địa điểm thuộc `Cà phê & Trà` sẽ có điểm TagMatch rất cao vì chúng thường có nhiều tag trùng như:

```text
coffee
food
relaxation
indoor
```

Khi đó Top K có thể bị `Cà phê & Trà` chiếm quá nhiều, làm Module 2 không có đủ nguyên liệu để tạo lịch trình đa dạng.

Vì vậy, Diversity slot-based được thêm vào để:

```text
1. Vẫn giữ TagMatch là điểm xếp hạng chính.
2. Không lấy Top K bằng cách sort global đơn thuần.
3. Chia số lượng slot cho từng subcategory.
4. Trong mỗi subcategory, chỉ lấy các place có điểm TagMatch cao nhất.
5. Gộp các place đã chọn từ nhiều subcategory thành danh sách cuối cùng.
```

Nói ngắn gọn:

```text
TagMatch quyết định place nào tốt trong từng subcategory.
Diversity quyết định mỗi subcategory được lấy bao nhiêu place.
```

---

## 2. Khác biệt so với cách diversity cũ

### Cách cũ

Cách cũ hoạt động theo hướng:

```text
1. Sort toàn bộ place theo TagMatch giảm dần.
2. Duyệt từ trên xuống.
3. Chặn bằng quota.
4. Nếu thiếu Top K thì fill từ overflow.
```

Vấn đề là khi fill, hệ thống có thể lấy lại các place điểm cao từ cùng một subcategory, làm quota bị phá. Vì vậy, dù có diversity, kết quả vẫn có thể bị lệch, ví dụ `Cà phê & Trà` chiếm 21/24 place.

---

### Cách mới: Slot-based theo subcategory

Cách mới không lấy Top K trực tiếp từ ranking global. Thay vào đó:

```text
1. Tính TagMatch cho toàn bộ place.
2. Gom place theo từng subcategory.
3. Sort place bên trong từng subcategory theo TagMatch giảm dần.
4. Tính số slot mỗi subcategory được nhận.
5. Với mỗi subcategory, lấy Top N place theo số slot đã cấp.
6. Gộp lại thành diversified_top_k.
```

Cách này tránh được lỗi một subcategory chiếm quá nhiều vì mỗi subcategory đã có số slot riêng.

---

## 3. Vị trí của Diversity trong pipeline

Diversity slot-based nằm ở cuối Module 1, trước khi chuyển dữ liệu sang Module 2.

Pipeline đầy đủ:

```text
Bước 1: Lọc candidate places
Bước 2: Build user interest profile
Bước 3: Tính TagMatch/module1_score cho từng place
Bước 4: Gom place theo subcategory
Bước 5: Tính slot cho từng subcategory
Bước 6: Lấy Top place trong từng subcategory
Bước 7: Gộp thành diversified_top_k
Bước 8: Đưa diversified_top_k sang Module 2
```

Module 2 sẽ dùng `diversified_top_k` để chia cụm theo vị trí, cân bằng số lượng địa điểm/ngày và xử lý duration.

---

## 4. Input của Diversity

Diversity nhận vào danh sách `ranked_places` sau khi đã tính `module1_score`.

Mỗi place nên có các trường:

```text
id_place
name
module1_score
tag_match
subcategory_name
place_category
average_rating
review_count
estimated_duration_minutes
latitude
longitude
```

Trong đó:

```text
module1_score
```

là điểm dùng để xếp hạng place. Hiện tại có thể bằng:

```text
module1_score = tag_match
```

Sau này có thể mở rộng thành:

```text
module1_score =
w1 × tag_match
+ w2 × rating_score
+ w3 × popularity_score
+ w4 × budget_score
```

---

## 5. Công thức Top K

`top_k` là số lượng candidate mà Module 1 trả sang Module 2.

Công thức:

```text
top_k = min(total_days × candidate_per_day, max_top_k)
```

Trong đó:

```text
total_days: số ngày đi của user
candidate_per_day: số candidate lấy dư mỗi ngày, ví dụ 8
max_top_k: giới hạn kỹ thuật, ví dụ 120
```

Ví dụ user đi 3 ngày:

```text
top_k = min(3 × 8, 120)
top_k = 24
```

Nghĩa là Module 1 trả 24 địa điểm tốt nhất đã được diversity cho Module 2.

Nếu user đi 20 ngày:

```text
top_k = min(20 × 8, 120)
top_k = 120
```

Giới hạn `120` giúp pipeline không bị quá nặng khi user đi rất nhiều ngày.

---

## 6. Phân loại profile sở thích của user

Trước khi chia slot, hệ thống cần xác định user có sở thích hẹp, trung bình hay rộng.

Dựa trên các lựa chọn onboarding của user, hệ thống map ra các `place_category` liên quan.

### Narrow profile

User được xem là `narrow` nếu sở thích chỉ tập trung vào 1 đến 2 nhóm lớn.

Ví dụ:

```text
Coffee
Food
Street Food
```

Các lựa chọn này chủ yếu thuộc nhóm:

```text
Ẩm thực
```

Với user narrow, diversity không nên ép quá nhiều nhóm khác vào. Nhóm user thích chính đáng được nhiều slot hơn.

---

### Medium profile

User được xem là `medium` nếu sở thích map ra khoảng 3 nhóm lớn.

Ví dụ:

```text
Food
Coffee
Culture
Temples
```

Có thể map ra:

```text
Ẩm thực
Tham quan
Tâm linh / Văn hóa
```

Với user medium, slot nên cân bằng vừa phải.

---

### Broad profile

User được xem là `broad` nếu sở thích map ra từ 4 nhóm lớn trở lên.

Ví dụ:

```text
Culture
Food
Local Life
Temples
Coffee
Beaches
Scenic Spots
```

Các lựa chọn này map ra nhiều nhóm:

```text
Ẩm thực
Tham quan
Mua sắm
Local life
Biển & Đảo
Tâm linh
Văn hóa
```

Với user broad, diversity cần siết hơn để không một nhóm nào chiếm quá nhiều.

---

## 7. Cấp slot cho subcategory

Ý tưởng chính của slot-based diversity là:

```text
Mỗi subcategory được cấp một số slot.
Sau đó lấy Top N place tốt nhất trong subcategory đó.
```

Ví dụ `top_k = 24`, hệ thống có thể cấp slot như sau:

```text
Biển & Đảo: 3 slot
Cà phê & Trà: 5 slot
Tâm linh & Tôn giáo: 4 slot
Di tích & Lịch sử: 4 slot
Bảo tàng & Nghệ thuật: 2 slot
Quán ăn địa phương: 3 slot
Chợ truyền thống: 2 slot
Làng nghề & Trải nghiệm địa phương: 1 slot
```

Sau đó:

```text
Biển & Đảo lấy Top 3 place trong nhóm Biển & Đảo.
Cà phê & Trà lấy Top 5 place trong nhóm Cà phê & Trà.
Tâm linh & Tôn giáo lấy Top 4 place trong nhóm Tâm linh & Tôn giáo.
...
```

Cuối cùng gộp lại thành danh sách 24 place.

---

## 8. Cách xác định subcategory liên quan đến sở thích user

Hệ thống cần map onboarding option sang nhóm subcategory liên quan.

Ví dụ:

```text
Coffee
→ Cà phê & Trà

Food
→ Quán ăn địa phương
→ Ẩm thực đường phố
→ Nhà hàng / Fine Dining

Temples
→ Tâm linh & Tôn giáo

Culture
→ Di tích & Lịch sử
→ Bảo tàng & Nghệ thuật
→ Tâm linh & Tôn giáo

Local Life
→ Chợ truyền thống
→ Làng nghề & Trải nghiệm địa phương

Beaches
→ Biển & Đảo

Scenic Spots
→ Biển & Đảo
→ Thiên nhiên & Cảnh quan
→ Hồ & Sông
→ Công viên & Vườn
→ Di tích & Lịch sử
```

Các subcategory xuất hiện từ sở thích user sẽ được xem là **related subcategories**.

Related subcategory sẽ được ưu tiên cấp slot trước.

---

## 9. Tính điểm ưu tiên cho từng subcategory

Mỗi subcategory cần có một `subcategory_priority_score`.

Điểm này dùng để biết subcategory nào nên được nhiều slot hơn.

Cách tính đơn giản:

```text
subcategory_priority_score =
tổng weight của các interest map tới subcategory đó
```

Ví dụ user chọn:

```text
Coffee
Temples
Beaches
Scenic Spots
```

Mapping:

```text
Coffee → Cà phê & Trà
Temples → Tâm linh & Tôn giáo
Beaches → Biển & Đảo
Scenic Spots → Biển & Đảo, Thiên nhiên & Cảnh quan, Công viên & Vườn
```

Khi đó:

```text
Cà phê & Trà có priority từ Coffee
Tâm linh & Tôn giáo có priority từ Temples
Biển & Đảo có priority từ Beaches + Scenic Spots
Thiên nhiên & Cảnh quan có priority từ Scenic Spots
Công viên & Vườn có priority từ Scenic Spots
```

Nếu một subcategory được nhiều option cùng map tới, nó sẽ có điểm ưu tiên cao hơn.

---

## 10. Slot tối thiểu và slot tối đa

Để slot không bị quá lệch, mỗi subcategory nên có giới hạn.

### Slot tối thiểu

Nếu subcategory liên quan trực tiếp đến sở thích user và có place trong candidate pool, nó nên có ít nhất:

```text
min_slot_per_related_subcategory = 1
```

Nghĩa là nếu user chọn `Temples` và candidate có `Tâm linh & Tôn giáo`, thì nên cấp ít nhất 1 slot cho nhóm này.

Tuy nhiên, không ép nếu subcategory không có place.

---

### Slot tối đa

Mỗi subcategory không nên chiếm quá nhiều Top K.

Công thức adaptive:

```text
max_slot_per_subcategory =
max(
  3,
  min(
    ceil(top_k × subcategory_ratio),
    day_based_cap
  )
)
```

Trong đó:

```text
top_k: số place cần lấy
subcategory_ratio: tỷ lệ slot tối đa theo profile
day_based_cap: trần theo số ngày
```

Bộ hệ số đề xuất:

```text
Narrow:
subcategory_ratio = 0.28
day_based_cap = total_days + 4

Medium:
subcategory_ratio = 0.22
day_based_cap = total_days + 3

Broad:
subcategory_ratio = 0.18
day_based_cap = total_days + 2
```

Ví dụ user broad đi 3 ngày:

```text
top_k = 24
subcategory_ratio = 0.18
day_based_cap = 3 + 2 = 5
```

Tính:

```text
ceil(24 × 0.18) = ceil(4.32) = 5
max_slot_per_subcategory = max(3, min(5, 5)) = 5
```

Vậy mỗi subcategory tối đa 5 slot.

---

## 11. Slot theo place_category

Ngoài subcategory, cần kiểm soát cả `place_category`.

Lý do: một `place_category` lớn có thể gồm nhiều subcategory.

Ví dụ nhóm `Ẩm thực` gồm:

```text
Cà phê & Trà
Quán ăn địa phương
Ẩm thực đường phố
Nhà hàng / Fine Dining
```

Nếu mỗi subcategory được nhiều slot, tổng nhóm `Ẩm thực` vẫn có thể chiếm gần hết Top K.

Vì vậy cần có:

```text
max_slot_per_place_category = ceil(top_k × category_ratio)
```

Bộ hệ số đề xuất:

```text
Narrow:
category_ratio = 0.70

Medium:
category_ratio = 0.55

Broad:
category_ratio = 0.45
```

Ví dụ user broad, `top_k = 24`:

```text
max_slot_per_place_category = ceil(24 × 0.45)
max_slot_per_place_category = 11
```

Nghĩa là một nhóm lớn như `Ẩm thực` hoặc `Tham quan` không nên vượt quá 11 slot.

---

## 12. Quy trình cấp slot tổng quát

### Bước 1: Gom place theo subcategory

Sau khi có `ranked_places`, hệ thống tạo cấu trúc:

```text
places_by_subcategory = {
  "Cà phê & Trà": [...],
  "Biển & Đảo": [...],
  "Tâm linh & Tôn giáo": [...],
  "Di tích & Lịch sử": [...],
  ...
}
```

Trong mỗi subcategory, sort place theo:

```text
module1_score desc
average_rating desc
review_count desc
```

---

### Bước 2: Xác định related subcategories

Từ onboarding option, map ra các subcategory liên quan.

Ví dụ user chọn:

```text
Culture
Food
Local Life
Temples
Coffee
Beaches
Scenic Spots
```

Related subcategories có thể gồm:

```text
Di tích & Lịch sử
Bảo tàng & Nghệ thuật
Tâm linh & Tôn giáo
Quán ăn địa phương
Ẩm thực đường phố
Nhà hàng / Fine Dining
Cà phê & Trà
Biển & Đảo
Chợ truyền thống
Làng nghề & Trải nghiệm địa phương
Thiên nhiên & Cảnh quan
Công viên & Vườn
```

---

### Bước 3: Cấp slot tối thiểu cho subcategory liên quan

Với mỗi related subcategory có place trong candidate pool:

```text
slot[subcategory] = 1
```

Mục tiêu là đảm bảo các nhóm sở thích chính có đại diện.

Ví dụ:

```text
Cà phê & Trà = 1
Biển & Đảo = 1
Tâm linh & Tôn giáo = 1
Di tích & Lịch sử = 1
Quán ăn địa phương = 1
Chợ truyền thống = 1
...
```

Nếu tổng slot tối thiểu đã vượt `top_k`, thì chỉ giữ các subcategory có priority cao nhất.

---

### Bước 4: Phân bổ slot còn lại theo priority

Sau khi cấp slot tối thiểu, nếu vẫn còn slot:

```text
remaining_slots = top_k - tổng slot đã cấp
```

Hệ thống phân bổ slot còn lại theo `subcategory_priority_score`.

Công thức:

```text
extra_slot[subcategory] =
round(
  remaining_slots
  × subcategory_priority_score
  / tổng priority_score của tất cả subcategory liên quan
)
```

Sau đó đảm bảo:

```text
slot[subcategory] <= max_slot_per_subcategory
```

và:

```text
slot theo place_category không vượt max_slot_per_place_category
```

---

### Bước 5: Cấp slot cho các subcategory có điểm cao nhưng không nằm trong onboarding

Sau khi phân bổ cho related subcategories, nếu vẫn chưa đủ `top_k`, hệ thống có thể lấy thêm từ các subcategory khác.

Điều kiện:

```text
1. Subcategory đó có place trong candidate pool.
2. Place đứng đầu subcategory có module1_score đủ cao so với các nhóm khác.
3. Subcategory đó chưa vượt max_slot_per_subcategory.
4. Place_category của nó chưa vượt max_slot_per_place_category.
```

Điều này giúp hệ thống không bỏ lỡ những địa điểm rất tốt, dù user không chọn trực tiếp subcategory đó.

Ví dụ user không chọn `Bảo tàng`, nhưng nếu `Bảo tàng & Nghệ thuật` có place điểm cao và user chọn `Culture`, thì vẫn có thể lấy.

---

### Bước 6: Lấy Top N place trong từng subcategory

Sau khi đã có slot:

```text
slot["Cà phê & Trà"] = 5
slot["Biển & Đảo"] = 3
slot["Tâm linh & Tôn giáo"] = 4
```

Hệ thống lấy:

```text
Top 5 place trong Cà phê & Trà
Top 3 place trong Biển & Đảo
Top 4 place trong Tâm linh & Tôn giáo
```

Trong từng subcategory, place vẫn được sort theo:

```text
module1_score desc
average_rating desc
review_count desc
```

Vì vậy, dù không dùng score floor, hệ thống vẫn lấy các place tốt nhất trong từng nhóm.

---

### Bước 7: Gộp danh sách cuối cùng

Sau khi lấy place từ từng subcategory, hệ thống gộp lại thành:

```text
diversified_top_k
```

Danh sách cuối có thể được sort lại theo:

```text
module1_score desc
```

hoặc giữ thứ tự theo nhóm.

Đề xuất:

```text
Sort lại theo module1_score desc trước khi đưa sang Module 2
```

Vì Module 2 vẫn nên biết place nào ưu tiên cao hơn.

Tuy nhiên, cần giữ thêm metadata:

```text
allocated_slot
subcategory_slot_rank
diversity_reason
```

để debug.

---

## 13. Ví dụ với user hiện tại

Input:

```text
total_days = 3
top_k = 24

Screen 1:
Culture
Food
Local Life

Screen 2:
Couple

Screen 3:
Balanced

Screen 4:
Temples
Coffee
Beaches
Scenic Spots
```

User này là `broad profile` vì sở thích map ra nhiều nhóm.

Cấu hình:

```text
top_k = 24
max_slot_per_subcategory = 5
max_slot_per_place_category = 11
```

Slot kỳ vọng có thể là:

```text
Biển & Đảo: 3
Cà phê & Trà: 4 hoặc 5
Tâm linh & Tôn giáo: 3
Di tích & Lịch sử: 3
Bảo tàng & Nghệ thuật: 2
Quán ăn địa phương: 3
Ẩm thực đường phố: 2
Chợ truyền thống: 2
Làng nghề & Trải nghiệm địa phương: 1
Thiên nhiên & Cảnh quan / Công viên & Vườn: 1 hoặc 2
```

Tổng khoảng 24 slot.

Khi lấy place:

```text
Biển & Đảo lấy top place như Bãi Trước, Bãi Tắm Thủy Tiên, Bãi Ông Đụng.

Cà phê & Trà lấy top 4 hoặc 5 quán cà phê có TagMatch cao nhất.

Tâm linh & Tôn giáo lấy top các chùa, nhà thờ, đền có TagMatch cao nhất.

Di tích & Lịch sử lấy top các di tích có TagMatch cao nhất.

Food group lấy top quán ăn, street food, nhà hàng có TagMatch cao nhất.
```

Kết quả cuối không còn tình trạng `Cà phê & Trà` chiếm 21/24.

---

## 14. Ưu điểm của cách slot-based

### 14.1. Không bị phá quota bởi fallback

Vì slot đã cấp trước cho từng subcategory, hệ thống không cần fallback kiểu lấy global score rồi phá quota.

---

### 14.2. Dễ kiểm soát

Có thể nhìn vào bảng slot là biết vì sao Top K có số lượng như vậy.

Ví dụ:

```text
Cà phê & Trà: 5 slot
Biển & Đảo: 3 slot
Tâm linh & Tôn giáo: 4 slot
```

Nếu kết quả lệch, chỉ cần kiểm tra bảng slot.

---

### 14.3. Vẫn giữ TagMatch

Trong mỗi subcategory, place vẫn được xếp theo TagMatch. Vì vậy diversity không chọn ngẫu nhiên.

---

### 14.4. Phù hợp với Module 2

Module 2 cần candidate pool đủ đa dạng để chia ngày. Slot-based giúp Module 2 có nhiều loại place hơn:

```text
ăn uống
cà phê
biển
di tích
tâm linh
local life
công viên
bảo tàng
```

---

## 15. Nhược điểm và cách xử lý

### Nhược điểm 1: Có thể lấy place điểm thấp trong subcategory yếu

Vì không dùng score floor, một subcategory được cấp slot có thể lấy place điểm thấp nếu nhóm đó ít match.

Cách xử lý:

```text
Không cấp slot cho subcategory không liên quan đến sở thích user, trừ khi place đứng đầu nhóm có điểm đủ tốt.
```

Có thể dùng điều kiện nhẹ:

```text
top_score_of_subcategory > 0
```

hoặc:

```text
top_score_of_subcategory >= một ngưỡng rất thấp như 0.05
```

Không nên dùng score floor cứng như trước, nhưng vẫn nên tránh subcategory có toàn điểm 0.

---

### Nhược điểm 2: Nếu user sở thích rất hẹp, diversity có thể quá rộng

Ví dụ user chỉ chọn `Coffee`, hệ thống không nên cấp nhiều slot cho di tích, bảo tàng, biển.

Cách xử lý:

```text
Dựa vào profile narrow/medium/broad.
Narrow thì category_ratio cao hơn.
Broad thì category_ratio thấp hơn.
```

Với narrow profile:

```text
category_ratio = 0.70
subcategory_ratio = 0.28
```

Nghĩa là nhóm chính vẫn có thể chiếm nhiều slot.

---

### Nhược điểm 3: Slot có thể không đủ top_k nếu một số subcategory thiếu place

Nếu subcategory được cấp 3 slot nhưng chỉ có 1 place, hệ thống chỉ lấy được 1.

Cách xử lý:

```text
Slot còn dư sẽ được trả lại vào remaining_slots.
Sau đó phân bổ lại cho các subcategory còn place.
```

---

## 16. Log cần có để kiểm tra

Khi chạy diversity slot-based, nên log:

```text
top_k
profile
related_subcategories
slot_by_subcategory
slot_by_place_category
selected_count_by_subcategory
selected_count_by_place_category
unused_slots
refilled_slots
final_selected_count
```

Mỗi place nên có:

```text
diversity_reason
subcategory_slot_rank
allocated_subcategory_slot
```

Ví dụ:

```text
Bãi Trước
subcategory = Biển & Đảo
subcategory_slot_rank = 1
allocated_subcategory_slot = 3
diversity_reason = selected_by_subcategory_slot
```

---

## 17. Quality check sau khi chạy

Sau diversity, cần kiểm tra:

### 17.1. Kiểm tra số lượng

```text
len(diversified_top_k) == top_k
```

Nếu nhỏ hơn, cần xem:

```text
Có thiếu candidate không?
Có subcategory nào được cấp slot nhưng không đủ place không?
Có cần refill không?
```

---

### 17.2. Kiểm tra subcategory không vượt slot

```text
selected_count_by_subcategory[subcategory] <= slot_by_subcategory[subcategory]
```

Nếu vượt, nghĩa là bug ở bước select.

---

### 17.3. Kiểm tra place_category không vượt quota

```text
selected_count_by_place_category[category] <= max_slot_per_place_category
```

Nếu vượt nhẹ do refill thì phải log rõ.

---

### 17.4. Kiểm tra coverage

Với mỗi interest user chọn, nếu có subcategory liên quan và có place, nên có ít nhất một đại diện trong `diversified_top_k`.

Ví dụ:

```text
Temples → có Tâm linh & Tôn giáo
Coffee → có Cà phê & Trà
Beaches → có Biển & Đảo
Food → có Quán ăn địa phương / Ẩm thực đường phố / Nhà hàng
Local Life → có Chợ truyền thống / Làng nghề
Culture → có Di tích / Bảo tàng / Tâm linh
```

---

## 18. Kết luận

Diversity slot-based là cách phù hợp hơn cho bài toán hiện tại vì nó không cố repair Top K sau khi đã bị lệch, mà chủ động chia slot trước cho từng subcategory.

Thiết kế mới:

```text
1. Tính TagMatch cho tất cả place.
2. Gom place theo subcategory.
3. Sort place trong từng subcategory theo TagMatch.
4. Tính slot cho từng subcategory.
5. Lấy Top N trong từng subcategory.
6. Gộp thành diversified_top_k.
```

Cách này đảm bảo:

```text
Cà phê & Trà không thể chiếm quá nhiều.
Các nhóm sở thích chính có đại diện.
Trong mỗi nhóm vẫn lấy place có TagMatch cao nhất.
Module 2 nhận candidate pool đa dạng hơn.
```

Nói ngắn gọn:

```text
Cách cũ: chọn theo global ranking rồi sửa lệch.
Cách mới: chia slot trước rồi chọn top trong từng nhóm.
```

Cách mới dễ kiểm soát, dễ debug và phù hợp hơn với hệ thống trip planner có nhiều loại địa điểm.

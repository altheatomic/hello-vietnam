## Thuật toán xây dựng hồ sơ sở thích người dùng và tính TagMatch

### 1. Mục tiêu

Thuật toán này dùng để xây dựng hồ sơ sở thích của người dùng từ quá trình onboarding và hành vi sử dụng app, sau đó so khớp hồ sơ đó với tập tag của từng địa điểm để tính điểm `TagMatch`.

Trong hệ thống Hello Vietnam, mỗi địa điểm đã được gắn nhiều tag trong bảng `place_tag`. Mỗi user cũng được biểu diễn bằng nhiều tag sở thích trong bảng `user_interest_tag`. Vì vậy, bài toán tính độ phù hợp giữa user và place được chuyển thành bài toán so khớp giữa:

```text
user_interest_tag
và
place_tag
```

Kết quả cuối cùng của bước này là điểm:

```text
TagMatch(u, p)
```

Trong đó:

```text
u: user
p: place
```

`TagMatch` càng cao thì địa điểm càng phù hợp với sở thích của user.

---

### 2. Các bảng dữ liệu liên quan

#### 2.1. Bảng `tag`

Bảng này lưu bộ tag chuẩn của hệ thống.

Các nhóm tag chính gồm:

```text
main
experience
environment
attribute
service
```

Trong đó:

```text
main: sở thích lớn như food, culture, nature, shopping
experience: trải nghiệm cụ thể như coffee, beach, museum, religious_site
environment: bối cảnh như quiet, crowded, local_experience
attribute: thuộc tính như quick_visit, long_visit, indoor, outdoor
service: nhóm tiện ích, không dùng cho itinerary
```

#### 2.2. Bảng `place_tag`

Bảng này lưu các tag đã được gắn cho từng địa điểm.

Mỗi dòng gồm:

```text
id_place
id_tag
confidence_score
source
```

Trong đó:

```text
confidence_score: độ chắc chắn rằng place có tag đó
source: nguồn sinh tag, ví dụ subcategory_rule, attribute_rule, auto_embedding
```

Ví dụ:

```text
Place: Chợ Bến Thành

local_market       confidence = 1.0
shopping           confidence = 1.0
culture            confidence = 1.0
street_food        confidence = 0.75
souvenir           confidence = 0.68
```

#### 2.3. Bảng `user_travel_profile`

Bảng này lưu các lựa chọn không trực tiếp dùng để tính TagMatch, nhưng dùng cho lọc và tạo lịch trình.

Các cột chính:

```text
id_user
companion_style
budget_level
pace_level
```

Ví dụ:

```text
companion_style = couple
budget_level = mid_range
pace_level = balanced
```

#### 2.4. Bảng `user_interest_tag`

Bảng này là bảng chính để tính `TagMatch`.

Các cột chính:

```text
id_user
id_tag
initial_weight
behavior_score
behavior_weight
final_weight
source
```

Ý nghĩa:

```text
initial_weight: trọng số ban đầu từ onboarding
behavior_score: điểm hành vi thô tích lũy
behavior_weight: trọng số hành vi sau khi chuẩn hóa
final_weight: trọng số cuối cùng dùng để tính TagMatch
source: nguồn tạo sở thích, ví dụ onboarding, system, behavior, manual
```

---

### 3. Sinh tag sở thích từ onboarding

Khi user đăng nhập lần đầu, app có 4 màn hình onboarding:

```text
Screen 1: What kind of trips feel most like you?
Screen 2: Who do you usually travel with?
Screen 3: How packed do you want your days to be?
Screen 4: Pick the things you want to see more often
```

Mục tiêu là chuyển các lựa chọn trên UI thành tập tag sở thích của user.

---

## 4. Screen 1: Travel Style

Screen 1 là màn chọn gu du lịch tổng quát. Vì đây là sở thích lớn, hệ thống dùng quy tắc đơn giản:

```text
tag chính = 1.0
tag phụ = 0.5
```

Mapping đề xuất:

| Lựa chọn UI | Tag chính        | Raw weight | Tag phụ           | Raw weight |
| ----------- | ---------------- | ---------: | ----------------- | ---------: |
| Food        | food             |        1.0 | local_cuisine     |        0.5 |
| Culture     | culture          |        1.0 | history, heritage |        0.5 |
| Nature      | nature           |        1.0 | outdoor           |        0.5 |
| Relaxation  | relaxation       |        1.0 | quiet             |        0.5 |
| Adventure   | adventure        |        1.0 | activity          |        0.5 |
| Shopping    | shopping         |        1.0 | local_market      |        0.5 |
| Photography | photography      |        1.0 | scenic_view       |        0.5 |
| Local Life  | local_experience |        1.0 | traditional_craft |        0.5 |

Lý do tag chính cao hơn tag phụ là vì tag chính là điều user chọn trực tiếp, còn tag phụ chỉ là hệ thống suy ra. Ví dụ user chọn `Culture` thì chắc chắn user có quan tâm đến văn hóa, nhưng chưa chắc user đặc biệt thích `history` hoặc `heritage`, nên các tag này chỉ nhận trọng số phụ.

---

## 5. Screen 2: Companion Style

Screen 2 hỏi user thường đi với ai. Thông tin này được lưu chính vào:

```text
user_travel_profile.companion_style
```

Ví dụ:

```text
solo
couple
friends
family
seniors
business
```

Ngoài ra, hệ thống có thể sinh thêm một số tag ngầm với raw weight thấp, vì đây chỉ là ngữ cảnh chuyến đi, không phải sở thích trực tiếp.

Mapping đề xuất:

| Lựa chọn UI | companion_style | Tag ngầm         | Raw weight |
| ----------- | --------------- | ---------------- | ---------: |
| Solo        | solo            | local_experience |        0.4 |
| Solo        | solo            | walking          |        0.4 |
| Couple      | couple          | scenic_view      |        0.5 |
| Couple      | couple          | relaxation       |        0.4 |
| Couple      | couple          | photography      |        0.4 |
| Friends     | friends         | activity         |        0.5 |
| Friends     | friends         | amusement        |        0.4 |
| Friends     | friends         | nightlife        |        0.3 |
| Family      | family          | family_friendly  |        0.6 |
| Family      | family          | park             |        0.4 |
| Family      | family          | amusement        |        0.4 |
| Seniors     | seniors         | relaxation       |        0.5 |
| Seniors     | seniors         | quiet            |        0.4 |
| Seniors     | seniors         | indoor           |        0.3 |
| Business    | business        | quick_visit      |        0.4 |
| Business    | business        | indoor           |        0.3 |

Các tag này nên có trọng số thấp hơn Screen 1 và Screen 4 vì chúng không phản ánh trực tiếp sở thích, mà chỉ giúp hệ thống điều chỉnh gợi ý phù hợp với kiểu chuyến đi.

---

## 6. Screen 3: Pace Level

Screen 3 hỏi user muốn lịch trình dày hay nhẹ. Màn này không dùng để sinh tag chính cho TagMatch.

Dữ liệu được lưu vào:

```text
user_travel_profile.pace_level
```

Mapping đề xuất:

| Lựa chọn UI | pace_level | Số địa điểm/ngày đề xuất |
| ----------- | ---------- | -----------------------: |
| Easy        | easy       |                        3 |
| Balanced    | balanced   |                        4 |
| Active      | active     |                        5 |
| Packed      | packed     |                        5 |

Màn này dùng cho Module 2 và Module 3 để quyết định số địa điểm/ngày, không nên ảnh hưởng mạnh đến TagMatch. Ví dụ user chọn `Easy` nghĩa là user muốn lịch trình nhẹ hơn, không có nghĩa là user chắc chắn thích `long_visit`.

---

## 7. Screen 4: Topic cụ thể

Screen 4 là màn user chọn các trải nghiệm muốn thấy nhiều hơn. Đây là tín hiệu cụ thể nhất trong onboarding, nên tag chính có trọng số cao hơn Screen 1.

Quy tắc:

```text
tag chính = 1.2
tag phụ rất gần = 0.8
tag phụ liên quan vừa = 0.6 hoặc 0.7
tag phụ bối cảnh = 0.4 hoặc 0.5
```

Lý do chọn `1.2` cho tag chính là vì Screen 4 thể hiện ý định rõ hơn Screen 1. Ví dụ user chọn `Culture` ở Screen 1 chỉ cho biết user thích văn hóa nói chung, nhưng user chọn `Temples` ở Screen 4 thì hệ thống biết rõ user thích `religious_site`. Vì vậy tag chính từ Screen 4 nên mạnh hơn một chút.

Mapping đề xuất:

| Lựa chọn UI    | Tag               | Raw weight |
| -------------- | ----------------- | ---------: |
| Street Food    | street_food       |        1.2 |
| Street Food    | local_cuisine     |        0.8 |
| Street Food    | food              |        0.7 |
| Coffee         | coffee            |        1.2 |
| Coffee         | relaxation        |        0.6 |
| Coffee         | indoor            |        0.4 |
| Museums        | museum            |        1.2 |
| Museums        | culture           |        0.7 |
| Museums        | indoor            |        0.4 |
| Temples        | religious_site    |        1.2 |
| Temples        | culture           |        0.7 |
| Temples        | heritage          |        0.5 |
| Festivals      | festival          |        1.2 |
| Festivals      | culture           |        0.7 |
| Festivals      | local_experience  |        0.6 |
| Beaches        | beach             |        1.2 |
| Beaches        | nature            |        0.7 |
| Beaches        | relaxation        |        0.6 |
| Beaches        | photography       |        0.5 |
| Mountains      | mountain          |        1.2 |
| Mountains      | nature            |        0.7 |
| Mountains      | adventure         |        0.7 |
| Mountains      | photography       |        0.5 |
| Night Markets  | local_market      |        1.2 |
| Night Markets  | street_food       |        0.8 |
| Night Markets  | shopping          |        0.7 |
| Night Markets  | nightlife         |        0.5 |
| Workshops      | traditional_craft |        1.2 |
| Workshops      | local_experience  |        0.8 |
| Workshops      | culture           |        0.6 |
| Handmade Goods | souvenir          |        1.2 |
| Handmade Goods | local_product     |        0.8 |
| Handmade Goods | traditional_craft |        0.7 |
| Handmade Goods | shopping          |        0.6 |
| Scenic Spots   | scenic_view       |        1.2 |
| Scenic Spots   | photography       |        0.8 |
| Scenic Spots   | nature            |        0.6 |
| Wellness       | relaxation        |        1.2 |
| Wellness       | quiet             |        0.6 |

---

## 8. Gom tag và cộng raw weight

Sau khi user chọn xong 4 màn hình, hệ thống gom toàn bộ tag được sinh ra.

Nếu một tag xuất hiện nhiều lần, hệ thống cộng raw weight.

Ví dụ user chọn:

```text
Screen 1: Culture
Screen 2: Couple
Screen 3: Balanced
Screen 4: Temples, Beaches
```

Các tag sinh ra:

```text
Culture:
culture = 1.0
history = 0.5
heritage = 0.5

Couple:
scenic_view = 0.5
relaxation = 0.4
photography = 0.4

Balanced:
không sinh tag

Temples:
religious_site = 1.2
culture = 0.7
heritage = 0.5

Beaches:
beach = 1.2
nature = 0.7
relaxation = 0.6
photography = 0.5
```

Sau khi cộng tag trùng:

| Tag            | Raw weight |
| -------------- | ---------: |
| culture        |        1.7 |
| heritage       |        1.0 |
| history        |        0.5 |
| scenic_view    |        0.5 |
| relaxation     |        1.0 |
| photography    |        0.9 |
| religious_site |        1.2 |
| beach          |        1.2 |
| nature         |        0.7 |

---

## 9. Giới hạn raw weight

Vì một tag có thể được củng cố từ nhiều lựa chọn, hệ thống cần giới hạn raw weight tối đa để tránh tag quá rộng áp đảo hồ sơ user.

Quy tắc:

```text
raw_weight_i = min(raw_weight_i, 2.5)
```

Lý do chọn `2.5`:

```text
- Nếu cap = 1.0, hệ thống mất khả năng nhận biết tag nào được củng cố nhiều lần.
- Nếu cap quá cao như 3.0 hoặc 4.0, các tag rộng như culture, food, nature có thể áp đảo tag cụ thể.
- Cap = 2.5 cho phép tag được củng cố nhiều lần mạnh hơn tag chỉ xuất hiện một lần, nhưng vẫn không áp đảo toàn bộ hồ sơ user.
```

---

## 10. Chuẩn hóa thành initial_weight

Sau khi có raw weight cuối cùng, hệ thống chuẩn hóa:

```text
initial_weight_i = raw_weight_i / sum(raw_weight_all)
```

Mục tiêu:

```text
sum(initial_weight) = 1
```

Ví dụ tổng raw weight là:

```text
8.7
```

Kết quả:

| Tag            | Raw weight | Initial weight |
| -------------- | ---------: | -------------: |
| culture        |        1.7 |          0.195 |
| heritage       |        1.0 |          0.115 |
| history        |        0.5 |          0.057 |
| scenic_view    |        0.5 |          0.057 |
| relaxation     |        1.0 |          0.115 |
| photography    |        0.9 |          0.103 |
| religious_site |        1.2 |          0.138 |
| beach          |        1.2 |          0.138 |
| nature         |        0.7 |          0.080 |

Với user mới chưa có hành vi:

```text
behavior_score = 0
behavior_weight = 0
final_weight = initial_weight
```

---

## 11. Cập nhật điểm hành vi

Sau khi user sử dụng app, hệ thống học thêm từ hành vi.

Mỗi hành vi có điểm thưởng hoặc phạt `r`.

Bảng điểm đề xuất:

| Hành vi         |    r |
| --------------- | ---: |
| view_detail     |   +1 |
| long_view       | +1.5 |
| favorite        |   +3 |
| share           |   +3 |
| add_to_trip     |   +5 |
| check_in        |   +5 |
| high_rating     |   +5 |
| skip_repeated   |   -1 |
| remove_favorite |   -3 |
| low_rating      |   -4 |

Khi user thực hiện hành vi với một place, hệ thống lấy các tag của place đó trong `place_tag`, sau đó cập nhật `behavior_score`.

Công thức:

```text
behavior_score_new =
behavior_score_old + η × r × place_tag.confidence_score
```

Trong đó:

```text
η: hệ số học, đề xuất η = 0.5
r: điểm hành vi
place_tag.confidence_score: độ chắc chắn place có tag đó
```

Ví dụ user lưu yêu thích một địa điểm có tag:

| Place tag  | Confidence |
| ---------- | ---------: |
| coffee     |        1.0 |
| relaxation |        1.0 |
| food       |        0.8 |

Với:

```text
favorite: r = +3
η = 0.5
```

Cập nhật:

```text
coffee += 0.5 × 3 × 1.0 = 1.5
relaxation += 0.5 × 3 × 1.0 = 1.5
food += 0.5 × 3 × 0.8 = 1.2
```

---

## 12. High rating và low rating

Nếu app dùng thang điểm 1 đến 5 sao, có thể quy đổi như sau:

| Rating | Behavior        |  r |
| -----: | --------------- | -: |
|  5 sao | high_rating     | +5 |
|  4 sao | positive_rating | +3 |
|  3 sao | neutral         |  0 |
|  2 sao | negative_rating | -3 |
|  1 sao | low_rating      | -4 |

Nếu muốn đơn giản hơn:

```text
rating >= 4 → high_rating
rating = 3 → không cập nhật
rating <= 2 → low_rating
```

---

## 13. Chuẩn hóa behavior_weight

Sau khi có `behavior_score`, hệ thống chuẩn hóa thành `behavior_weight`.

Vì behavior_score có thể âm, hệ thống chỉ lấy phần dương để chuẩn hóa:

```text
positive_score_i = max(behavior_score_i, 0)
```

Sau đó:

```text
behavior_weight_i =
positive_score_i / sum(positive_score_all)
```

Nếu:

```text
sum(positive_score_all) = 0
```

thì:

```text
behavior_weight_i = 0
```

Ví dụ:

| Tag        | behavior_score | positive_score |
| ---------- | -------------: | -------------: |
| coffee     |              6 |              6 |
| relaxation |              3 |              3 |
| food       |              1 |              1 |
| culture    |             -2 |              0 |

Tổng positive score:

```text
6 + 3 + 1 = 10
```

Behavior weight:

| Tag        | behavior_weight |
| ---------- | --------------: |
| coffee     |             0.6 |
| relaxation |             0.3 |
| food       |             0.1 |
| culture    |               0 |

---

## 14. Giới hạn behavior_score

Để tránh một tag tăng quá mạnh và thống trị toàn bộ recommendation, hệ thống nên giới hạn `behavior_score`.

Đề xuất:

```text
behavior_score_min = -10
behavior_score_max = 20
```

Sau mỗi lần cập nhật:

```text
behavior_score_i = min(20, max(-10, behavior_score_i))
```

---

## 15. Kết hợp onboarding và behavior

Sau khi có:

```text
initial_weight
behavior_weight
```

hệ thống tính:

```text
final_weight_i =
λ × initial_weight_i + (1 - λ) × behavior_weight_i
```

Trong đó:

```text
λ: mức độ tin vào onboarding
1 - λ: mức độ tin vào hành vi
```

Đề xuất dùng λ động:

```text
λ = max(0.4, 0.8 - 0.02 × behavior_count)
```

Ý nghĩa:

| behavior_count |   λ | Tỷ lệ onboarding / behavior |
| -------------: | --: | --------------------------- |
|              0 | 0.8 | 80% / 20%                   |
|              5 | 0.7 | 70% / 30%                   |
|             10 | 0.6 | 60% / 40%                   |
|             15 | 0.5 | 50% / 50%                   |
|            20+ | 0.4 | 40% / 60%                   |

Nếu user chưa có hành vi:

```text
final_weight = initial_weight
```

Nếu user có hành vi:

```text
final_weight_i =
λ × initial_weight_i + (1 - λ) × behavior_weight_i
```

Sau đó nên chuẩn hóa lại:

```text
final_weight_i =
final_weight_i / sum(final_weight_all)
```

Mục tiêu:

```text
sum(final_weight) = 1
```

---

## 16. Tính TagMatch

Sau khi user có `final_weight`, hệ thống tính TagMatch giữa user và từng place.

Ký hiệu:

```text
Iu: tập tag sở thích của user
Tp: tập tag của place
wi: final_weight của tag i
cp,i: confidence_score của tag i trên place p
```

Công thức:

```text
TagMatch(u, p) =
sum(wi × cp,i for i in Iu ∩ Tp)
/
sum(wi for i in Iu)
```

Vì hệ thống đã chuẩn hóa:

```text
sum(wi) = 1
```

nên công thức có thể hiểu đơn giản là:

```text
TagMatch = tổng trọng số các sở thích user mà place đáp ứng được,
có nhân với độ chắc chắn của tag trên place.
```

---

## 17. Ví dụ tính TagMatch

User có final_weight:

| User tag   | final_weight |
| ---------- | -----------: |
| coffee     |         0.35 |
| relaxation |         0.25 |
| culture    |         0.20 |
| beach      |         0.20 |

Place A có tag:

| Place tag  | confidence_score |
| ---------- | ---------------: |
| coffee     |              1.0 |
| relaxation |              0.8 |
| indoor     |              1.0 |
| food       |              0.9 |

Tập tag giao nhau:

```text
coffee
relaxation
```

Tính:

```text
TagMatch =
coffee_weight × coffee_confidence
+ relaxation_weight × relaxation_confidence
```

Thay số:

```text
TagMatch =
0.35 × 1.0
+ 0.25 × 0.8
= 0.35 + 0.20
= 0.55
```

Kết luận:

```text
Place A đáp ứng khoảng 55% hồ sơ sở thích có trọng số của user.
```

---

## 18. Quy trình thuật toán hoàn chỉnh

Toàn bộ quy trình gồm các bước sau:

```text
Bước 1: User hoàn thành onboarding.

Bước 2: Lưu companion_style, budget_level, pace_level vào user_travel_profile.

Bước 3: Map lựa chọn ở Screen 1, Screen 2 và Screen 4 thành các tag sở thích.

Bước 4: Gán raw_weight cho từng tag:
- Screen 1 tag chính = 1.0
- Screen 1 tag phụ = 0.5
- Screen 2 tag ngầm = 0.3 đến 0.6
- Screen 4 tag chính = 1.2
- Screen 4 tag phụ = 0.4 đến 0.8

Bước 5: Cộng raw_weight nếu tag xuất hiện nhiều lần.

Bước 6: Giới hạn raw_weight:
raw_weight_i = min(raw_weight_i, 2.5)

Bước 7: Chuẩn hóa:
initial_weight_i = raw_weight_i / sum(raw_weight_all)

Bước 8: Lưu vào user_interest_tag:
initial_weight = giá trị đã chuẩn hóa
behavior_score = 0
behavior_weight = 0
final_weight = initial_weight

Bước 9: Khi user có hành vi với một place, lấy các tag của place từ place_tag.

Bước 10: Cập nhật behavior_score:
behavior_score += η × r × place_tag.confidence_score

Bước 11: Giới hạn behavior_score trong [-10, 20].

Bước 12: Chuẩn hóa behavior_score dương thành behavior_weight.

Bước 13: Tính λ theo behavior_count:
λ = max(0.4, 0.8 - 0.02 × behavior_count)

Bước 14: Tính final_weight:
final_weight = λ × initial_weight + (1 - λ) × behavior_weight

Bước 15: Chuẩn hóa lại final_weight để tổng bằng 1.

Bước 16: Với từng place ứng viên, lấy place_tag.

Bước 17: Tính TagMatch:
TagMatch(u, p) =
sum(user.final_weight × place_tag.confidence_score)
/
sum(user.final_weight)

Bước 18: Dùng TagMatch làm một thành phần trong content-based recommendation để tính điểm xếp hạng địa điểm.
```

---

## 19. Kết luận

Thuật toán này giúp hệ thống biểu diễn cả user và place bằng cùng một không gian tag. User được biểu diễn bằng tập tag sở thích có trọng số, còn place được biểu diễn bằng tập tag có confidence score. Khi user mới sử dụng app, hệ thống dựa chủ yếu vào onboarding. Sau khi user có hành vi thực tế, hệ thống cập nhật behavior_score, chuẩn hóa thành behavior_weight và kết hợp lại với initial_weight để tạo final_weight. Cuối cùng, TagMatch được tính bằng mức độ giao nhau giữa tag user và tag place, có xét cả trọng số sở thích và độ chắc chắn của tag trên địa điểm.

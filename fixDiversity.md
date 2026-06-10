# Mô tả phần cần sửa trong Diversity Selection

## 1. Vấn đề hiện tại

Hiện tại thuật toán Diversity Selection đã được thêm vào sau bước tính `TagMatch/module1_score`, nhưng kết quả thực tế cho thấy diversity chưa hoạt động đúng mục tiêu.

Theo thiết kế, sau khi tính `TagMatch`, hệ thống không nên lấy thẳng Top K theo điểm giảm dần, vì có thể xảy ra tình trạng một subcategory chiếm quá nhiều slot. Diversity được dùng để giới hạn việc lặp lại quá nhiều một nhóm địa điểm, đồng thời vẫn giữ các place có điểm phù hợp cao.

Tuy nhiên, trong kết quả chạy hiện tại, trước diversity và sau diversity gần như không thay đổi. Top K sau diversity vẫn bị `Cà phê & Trà` chiếm phần lớn danh sách. Điều này cho thấy bước diversity hiện tại chưa kiểm soát được quota, chưa đảm bảo coverage theo sở thích user và chưa tạo được candidate pool đa dạng cho Module 2.

Vấn đề không nằm ở `TagMatch`. Công thức `TagMatch` đang chạy đúng theo tag của user và tag của place. Vấn đề nằm ở bước chọn lại Top K sau khi đã có điểm `module1_score`.

---

## 2. Hiện tại đang sai ở đâu?

### 2.1. Diversity config đúng nhưng không được áp dụng đúng

Hệ thống đã xác định đúng user thuộc nhóm `broad profile`, vì user chọn nhiều nhóm sở thích khác nhau như:

```text
Culture
Food
Local Life
Temples
Coffee
Beaches
Scenic Spots
```

Với profile này, hệ thống đặt các tham số diversity như sau:

```text
top_k = 24
max_per_subcategory = 5
max_per_place_category = 11
score_floor ≈ 0.215896
```

Ý nghĩa của các tham số này là:

```text
Top K cần lấy 24 địa điểm.
Mỗi subcategory không nên vượt quá 5 địa điểm.
Mỗi place_category lớn không nên vượt quá 11 địa điểm.
Place được chọn phải có module1_score >= score_floor.
```

Nhưng kết quả sau diversity vẫn có:

```text
Biển & Đảo: 3
Cà phê & Trà: 21
```

Điều này sai vì `Cà phê & Trà` đã vượt rất xa quota `max_per_subcategory = 5`.

Nếu diversity chạy đúng, `Cà phê & Trà` chỉ nên có tối đa khoảng 5 địa điểm trong Top 24, hoặc chỉ được vượt nhẹ trong trường hợp fallback có kiểm soát. Không thể để `Cà phê & Trà` chiếm 21/24 slot.

---

### 2.2. Bước fill đang phá quota

Lỗi lớn nhất nằm ở bước fill.

Theo kết quả hiện tại, sau khi chọn lượt đầu, hệ thống chưa đủ Top K nên chạy bước fill. Tuy nhiên, bước fill lại lấy thêm nhiều place từ `overflow_pool` theo điểm cao nhất mà không kiểm tra lại quota.

Vì các quán cà phê có `module1_score` rất cao và rất gần nhau, nên khi fill theo score thuần, thuật toán lại lấy tiếp hàng loạt quán cà phê.

Cách hoạt động hiện tại có thể đang giống như sau:

```text
1. Chọn một số place theo quota.
2. Chưa đủ Top K.
3. Lấy thêm từ overflow_pool theo module1_score giảm dần.
4. Không kiểm tra subcategory_count và place_category_count.
5. Kết quả là Cà phê & Trà quay lại chiếm phần lớn Top K.
```

Đây là nguyên nhân làm diversity mất tác dụng. Quota chỉ có ý nghĩa ở lượt chọn đầu, nhưng bị phá ở bước fill.

---

### 2.3. Coverage theo sở thích user đang tính sai

Hiện tại hệ thống báo các sở thích như `Culture`, `Food`, `Local Life`, `Temples`, `Coffee`, `Beaches`, `Scenic Spots` đều đã được cover.

Nhưng Top K sau diversity thực tế chỉ có:

```text
Biển & Đảo
Cà phê & Trà
```

Như vậy không thể xem là đã cover đúng các nhóm như:

```text
Culture
Food
Local Life
Temples
```

Lỗi có thể do hệ thống đang check coverage bằng tag quá rộng, thay vì check bằng subcategory đại diện.

Ví dụ, nếu một place có tag `culture` hoặc tag liên quan nhẹ, hệ thống có thể xem là đã cover `Culture`. Nhưng về mặt trải nghiệm lịch trình, user chọn `Culture` thì Top K nên có ít nhất một số địa điểm thuộc:

```text
Di tích & Lịch sử
Bảo tàng & Nghệ thuật
Tâm linh & Tôn giáo
```

Tương tự, user chọn `Temples` thì Top K nên có đại diện từ:

```text
Tâm linh & Tôn giáo
```

User chọn `Local Life` thì Top K nên có đại diện từ:

```text
Chợ truyền thống
Làng nghề & Trải nghiệm địa phương
```

Nếu Top K chỉ có `Cà phê & Trà` và `Biển & Đảo`, thì coverage không thể xem là đạt.

---

### 2.4. Score quality đang đánh giá chưa đủ

Hiện tại hệ thống có thể báo:

```text
avg_score_before = avg_score_after
score_quality_ok = true
```

Điều này đúng về mặt điểm trung bình, nhưng không đủ để kết luận diversity hoạt động tốt.

Lý do là sau diversity danh sách gần như không đổi, nên điểm trung bình không giảm. Nhưng mục tiêu của diversity không chỉ là giữ điểm trung bình, mà còn phải kiểm soát phân bố category.

Vì vậy, ngoài `score_quality_ok`, cần có thêm:

```text
quota_quality_ok
coverage_quality_ok
```

Trong kết quả hiện tại:

```text
score_quality_ok = true
quota_quality_ok = false
coverage_quality_ok = false
```

Nghĩa là điểm số không giảm, nhưng diversity chưa đạt mục tiêu cân bằng.

---

## 3. Vì sao lỗi này xảy ra?

### 3.1. Do Cà phê & Trà có nhiều tag trùng với user

User có các tag sở thích như:

```text
coffee
food
relaxation
indoor
```

Trong khi subcategory `Cà phê & Trà` thường có default tag:

```text
coffee
food
relaxation
indoor
```

Do đó rất nhiều quán cà phê có `TagMatch` cao và gần như bằng nhau. Đây là điều bình thường, không phải lỗi của TagMatch.

Nếu chỉ sort theo `module1_score`, quán cà phê sẽ xuất hiện liên tục ở Top đầu.

---

### 3.2. Do fill đang ưu tiên score tuyệt đối

Sau khi áp quota, nếu selected chưa đủ 24 địa điểm, hệ thống cần fill thêm. Nhưng fill hiện tại đang ưu tiên score tuyệt đối, nên các quán cà phê trong overflow lại được lấy vào.

Điều này làm thuật toán quay về gần giống cách lấy Top K cũ, tức là sort theo score thuần.

---

### 3.3. Do coverage không ép đại diện theo subcategory

Hệ thống chưa bắt buộc mỗi sở thích quan trọng phải có đại diện theo subcategory phù hợp.

Ví dụ:

```text
Temples phải có Tâm linh & Tôn giáo.
Food phải có Quán ăn địa phương, Ẩm thực đường phố hoặc Nhà hàng.
Culture phải có Di tích, Bảo tàng hoặc Tâm linh.
Local Life phải có Chợ truyền thống hoặc Làng nghề.
```

Vì chưa kiểm tra kiểu này, hệ thống tưởng rằng coverage đã đủ, trong khi Top K thực tế vẫn lệch.

---

## 4. Cần sửa gì?

## 4.1. Sửa logic fill để không phá quota

Bước fill cần chia thành nhiều vòng, không được lấy overflow theo score thuần ngay từ đầu.

### Fill vòng 1: Fill nghiêm ngặt theo quota

Chỉ chọn place nếu thỏa:

```text
module1_score >= score_floor
subcategory_count[subcategory] < max_per_subcategory
place_category_count[place_category] < max_per_place_category
```

Nếu không thỏa, chưa được chọn.

Mục tiêu của vòng này là cố gắng lấp đủ Top K nhưng vẫn giữ quota.

---

### Fill vòng 2: Nới quota nhẹ nếu chưa đủ Top K

Nếu sau vòng 1 chưa đủ `top_k`, hệ thống được phép nới quota nhẹ:

```text
relaxed_max_per_subcategory = max_per_subcategory + 1
relaxed_max_per_place_category = max_per_place_category + 2
```

Sau đó duyệt lại overflow để lấy thêm place.

Điều kiện:

```text
module1_score >= score_floor
subcategory_count[subcategory] < relaxed_max_per_subcategory
place_category_count[place_category] < relaxed_max_per_place_category
```

Các place được chọn ở vòng này nên log:

```text
diversity_reason = selected_by_quota_relaxation
```

---

### Fill vòng 3: Fallback theo score nếu vẫn thiếu nghiêm trọng

Chỉ dùng vòng này nếu candidate thật sự không đủ để tạo Top K.

Khi đó mới lấy overflow theo score cao nhất, nhưng phải log rõ:

```text
diversity_reason = selected_by_fallback_score
```

Vòng này không nên chạy trong trường hợp dữ liệu đủ nhiều như hiện tại. Vì hiện tại có nhiều place từ `Tâm linh & Tôn giáo`, `Di tích & Lịch sử`, `Làng nghề`, `Quán ăn địa phương` có điểm trên `score_floor`, nên không có lý do để fallback về toàn quán cà phê.

---

## 4.2. Sửa coverage theo subcategory đại diện

Coverage không nên chỉ check bằng tag. Cần tạo mapping từ onboarding option sang subcategory đại diện.

Ví dụ:

```text
Coffee
→ Cà phê & Trà

Beaches
→ Biển & Đảo

Temples
→ Tâm linh & Tôn giáo

Culture
→ Di tích & Lịch sử
→ Bảo tàng & Nghệ thuật
→ Tâm linh & Tôn giáo

Food
→ Quán ăn địa phương
→ Ẩm thực đường phố
→ Nhà hàng / Fine Dining

Local Life
→ Chợ truyền thống
→ Làng nghề & Trải nghiệm địa phương

Scenic Spots
→ Biển & Đảo
→ Thiên nhiên & Cảnh quan
→ Công viên & Vườn
```

Sau khi có selected list, hệ thống kiểm tra từng sở thích user:

```text
Nếu user chọn Temples mà selected chưa có Tâm linh & Tôn giáo:
    tìm place Tâm linh & Tôn giáo có module1_score cao nhất

Nếu user chọn Food mà selected chưa có nhóm food:
    tìm place food có module1_score cao nhất

Nếu user chọn Local Life mà selected chưa có Chợ hoặc Làng nghề:
    tìm place local life có module1_score cao nhất
```

Điều kiện bắt buộc:

```text
new_place.module1_score >= score_floor
```

Nếu không có place đạt ngưỡng, bỏ qua. Không ép place yếu vào.

---

## 4.3. Sửa logic thay thế khi selected đã đầy

Nếu selected đã đủ Top K nhưng thiếu coverage, hệ thống cần thay thế một place đang dư.

Cách chọn place mới:

```text
new_place = place có module1_score cao nhất
thuộc nhóm subcategory đang thiếu
và module1_score >= score_floor
```

Cách chọn place bị loại:

```text
remove_place = place trong selected
thuộc subcategory đang vượt quota nhiều nhất
và có module1_score thấp nhất
```

Không được loại place nếu:

```text
1. Place đó là đại diện duy nhất của một sở thích khác.
2. Place đó nằm trong nhóm điểm rất cao.
3. Place mới thấp hơn place bị loại quá nhiều.
```

Dùng điều kiện bảo vệ:

```text
new_place.module1_score >= remove_place.module1_score × 0.85
```

Ví dụ:

```text
remove_place.module1_score = 0.260
new_place phải có điểm ít nhất:
0.260 × 0.85 = 0.221
```

Nếu new place thấp hơn 0.221 thì không thay.

---

## 4.4. Thêm kiểm tra quota violation

Sau khi chạy diversity, hệ thống cần kiểm tra lại phân bố.

Ví dụ:

```text
for each subcategory in selected:
    if count > max_per_subcategory:
        add quota violation
```

Log nên có dạng:

```text
quota_violations:
  Cà phê & Trà:
    count = 21
    max_allowed = 5
    violation = 16
```

Nếu có violation lớn, không được xem diversity là pass.

Tương tự với place_category:

```text
place_category_violations:
  Ẩm thực:
    count = 21
    max_allowed = 11
    violation = 10
```

---

## 4.5. Thêm quality flags

Sau diversity, cần đánh giá bằng 3 nhóm chỉ số:

### Score quality

```text
avg_score_after >= avg_score_before × 0.90
```

Nếu đúng:

```text
score_quality_ok = true
```

### Quota quality

```text
Không có subcategory hoặc place_category vượt quota nghiêm trọng.
```

Nếu đúng:

```text
quota_quality_ok = true
```

### Coverage quality

```text
Các sở thích chính của user có đại diện nếu có candidate đạt score_floor.
```

Nếu đúng:

```text
coverage_quality_ok = true
```

Kết quả diversity chỉ nên xem là ổn khi:

```text
score_quality_ok = true
quota_quality_ok = true
coverage_quality_ok = true
```

---

## 5. Quy trình diversity sau khi sửa

Quy trình đúng nên là:

```text
Bước 1:
Nhận ranked_places đã sort theo module1_score giảm dần.

Bước 2:
Tính top_k, score_floor, max_per_subcategory, max_per_place_category.

Bước 3:
Chọn lượt đầu:
- Duyệt ranked_places theo score.
- Chỉ chọn nếu đạt score_floor và chưa vượt quota.

Bước 4:
Kiểm tra coverage theo onboarding interests:
- Nếu thiếu nhóm quan trọng, tìm place tốt nhất thuộc nhóm đó.
- Chỉ thêm nếu đạt score_floor.
- Nếu selected đã đầy, thay thế place thuộc nhóm đang dư.

Bước 5:
Fill nếu chưa đủ Top K:
- Fill vòng 1 theo quota gốc.
- Fill vòng 2 với quota nới nhẹ.
- Fill vòng 3 fallback theo score chỉ khi thật sự thiếu dữ liệu.

Bước 6:
Tính lại count_by_subcategory và count_by_place_category.

Bước 7:
Kiểm tra:
- score_quality_ok
- quota_quality_ok
- coverage_quality_ok

Bước 8:
Trả diversified_top_k.
```

---

## 6. Kết quả kỳ vọng sau khi sửa

Với user đi 3 ngày:

```text
top_k = 24
max_per_subcategory = 5
max_per_place_category = 11
```

Top K sau diversity không nên còn dạng:

```text
Biển & Đảo: 3
Cà phê & Trà: 21
```

Kết quả hợp lý hơn có thể là:

```text
Biển & Đảo: 3
Cà phê & Trà: 5
Tâm linh & Tôn giáo: 3 đến 5
Di tích & Lịch sử: 2 đến 4
Bảo tàng & Nghệ thuật: 1 đến 2
Quán ăn địa phương / Ẩm thực đường phố / Nhà hàng: 3 đến 5
Chợ truyền thống / Làng nghề: 1 đến 3
Công viên / Cảnh quan: 1 đến 2
```

Không cần đúng tuyệt đối các số trên. Điều quan trọng là:

```text
Không một subcategory nào chiếm quá nhiều.
Các sở thích chính có đại diện.
Các place được chọn vẫn có module1_score >= score_floor.
```

---

## 7. Kết luận

Hiện tại diversity sai không phải vì công thức quota sai, mà vì logic áp dụng quota chưa đúng.

Các lỗi chính là:

```text
1. Fill đang lấy overflow theo score và phá quota.
2. Coverage đang check chưa đúng theo subcategory đại diện.
3. Không có quota_quality_ok để phát hiện Cà phê & Trà vượt quota.
4. Score quality đang pass nhưng không phản ánh sự mất cân bằng.
```

Cần sửa theo hướng:

```text
1. Fill nhiều vòng, không phá quota ngay từ đầu.
2. Coverage theo onboarding-to-subcategory mapping.
3. Replacement có kiểm soát bằng replacement_ratio.
4. Thêm quota violation log.
5. Chỉ xem diversity pass khi score, quota và coverage đều đạt.
```

Sau khi sửa, Diversity Selection mới thực sự tạo ra `diversified_top_k` đúng nghĩa: vừa phù hợp với user, vừa đủ đa dạng để Module 2 chia lịch trình tốt hơn.

# Module 2: Phân chia địa điểm vào các ngày trong lịch trình

## 1. Mục tiêu của Module 2

Sau khi Module 1 đã lọc và xếp hạng các địa điểm phù hợp với sở thích người dùng, Module 2 có nhiệm vụ chia các địa điểm đó vào từng ngày trong chuyến đi.

Module 1 trả về danh sách Top K địa điểm theo `TagMatch` hoặc `module1_score`. Các địa điểm này là những nơi phù hợp nhất với hồ sơ sở thích của người dùng. Tuy nhiên, Module 2 không sử dụng toàn bộ Top K làm lịch trình cuối cùng. Thay vào đó, Top K được xem là tập ứng viên tốt nhất để Module 2 lựa chọn và phân bổ.

Mục tiêu chính của Module 2 là:

```text
1. Gom các địa điểm gần nhau về mặt địa lý vào cùng một ngày.
2. Đảm bảo số lượng địa điểm mỗi ngày không quá ít hoặc quá nhiều.
3. Kiểm soát tổng thời gian tham quan trong mỗi ngày.
4. Ưu tiên giữ lại các địa điểm có điểm phù hợp cao với người dùng.
5. Tạo đầu vào hợp lý cho Module 3, nơi tối ưu thứ tự tham quan trong từng ngày.
```

Module 2 chưa sắp xếp thứ tự đi trong ngày. Module này chỉ trả lời câu hỏi:

```text
Những địa điểm nào nên được xếp chung vào cùng một ngày?
```

Việc sắp xếp thứ tự đi trước, đi sau trong từng ngày sẽ được xử lý ở Module 3.

---

## 2. Lý do chọn K-means + Greedy Repair

Trong bài toán chia địa điểm vào các ngày, có nhiều phương án có thể dùng như K-means, Greedy assignment, Constrained clustering, DBSCAN hoặc K-means kết hợp Greedy Repair.

Hệ thống chọn K-means + Greedy Repair vì phương án này cân bằng được nhiều yêu cầu:

```text
1. K-means gom các địa điểm gần nhau theo tọa độ.
2. Có thể kiểm soát số cụm bằng số ngày du lịch.
3. Greedy Repair giúp sửa các cụm bị quá nhiều, quá ít hoặc quá tải thời gian.
4. Dễ triển khai bằng thư viện có sẵn.
5. Phù hợp với dữ liệu hiện tại của hệ thống.
```

K-means phù hợp vì lịch trình du lịch phụ thuộc nhiều vào vị trí địa lý. Những địa điểm gần nhau nên được xếp chung vào một ngày để giảm thời gian di chuyển. Tuy nhiên, K-means chỉ gom điểm theo vị trí, không đảm bảo mỗi cụm có số lượng địa điểm hợp lý. Vì vậy cần thêm bước Greedy Repair để cân bằng lại cụm.

---

## 3. Các thư viện sử dụng

Module 2 có thể triển khai bằng Python với các thư viện sau.

### 3.1. `scikit-learn`

Dùng để chạy thuật toán K-means.

```python
from sklearn.cluster import KMeans
```

Vai trò:

```text
1. Nhận input là tọa độ latitude, longitude của các địa điểm.
2. Phân cụm các địa điểm thành k cụm.
3. Mỗi cụm tương ứng với một ngày trong lịch trình.
```

Cài đặt:

```bash
pip install scikit-learn
```

---

### 3.2. `numpy`

Dùng để xử lý mảng số, tọa độ và tính toán khoảng cách.

```python
import numpy as np
```

Vai trò:

```text
1. Chuyển danh sách tọa độ thành ma trận.
2. Tính toán vector tọa độ.
3. Hỗ trợ tính trung bình cụm, khoảng cách và các phép toán số học.
```

Cài đặt:

```bash
pip install numpy
```

---

### 3.3. `pandas`

Dùng để xử lý dữ liệu dạng bảng trong quá trình test hoặc debug.

```python
import pandas as pd
```

Vai trò:

```text
1. Chuyển dữ liệu địa điểm thành DataFrame.
2. Dễ kiểm tra danh sách place, cluster, score, duration.
3. Xuất log kiểm tra kết quả.
```

Cài đặt:

```bash
pip install pandas
```

Trong production, có thể không bắt buộc dùng pandas nếu backend xử lý bằng list/dict.

---

### 3.4. `math`

Dùng để tính khoảng cách Haversine nếu không muốn cài thêm thư viện ngoài.

```python
import math
```

Vai trò:

```text
1. Tính khoảng cách giữa hai tọa độ theo km.
2. Dùng trong Greedy Repair để kiểm tra điểm có quá xa cụm nhận hay không.
```

Hệ thống nên dùng Haversine thay vì khoảng cách Euclidean thô khi cần tính khoảng cách thực tế theo km.

---

### 3.5. `geopy` hoặc `haversine`

Có thể dùng nếu muốn tính khoảng cách địa lý tiện hơn.

```bash
pip install geopy
```

hoặc:

```bash
pip install haversine
```

Ví dụ dùng `geopy`:

```python
from geopy.distance import geodesic
```

Tuy nhiên, để giảm phụ thuộc thư viện, hệ thống có thể tự viết hàm Haversine bằng `math`.

---

### 3.6. `supabase-py`

Nếu backend Python cần lấy dữ liệu trực tiếp từ Supabase.

```python
from supabase import create_client
```

Vai trò:

```text
1. Lấy Top K địa điểm từ kết quả Module 1.
2. Lấy thông tin place, latitude, longitude, estimated_duration_minutes.
3. Lưu kết quả phân ngày nếu cần.
```

Cài đặt:

```bash
pip install supabase
```

Nếu Module 2 nhận dữ liệu trực tiếp từ backend Node.js hoặc API nội bộ thì không bắt buộc dùng `supabase-py`.

---

## 4. Đầu vào của Module 2

Module 2 nhận đầu vào từ Module 1.

Module 1 đã thực hiện:

```text
1. Lọc địa điểm theo điều kiện bắt buộc.
2. Tính TagMatch giữa user và place.
3. Sắp xếp địa điểm theo TagMatch hoặc module1_score.
4. Lấy Top K địa điểm phù hợp nhất.
```

Đầu vào của Module 2 là:

```text
top_places = danh sách Top K địa điểm từ Module 1
```

Mỗi địa điểm nên có các trường:

```text
id_place
name
latitude
longitude
tag_match
module1_score
estimated_duration_minutes
id_place_subcategory
subcategory_name
is_itinerary_eligible
```

Trong phiên bản hiện tại, nếu chưa có `FinalRank`, có thể dùng:

```text
module1_score = tag_match
```

Sau này nếu Module 1 kết hợp thêm rating, popularity, budget, opening hours thì có thể dùng:

```text
module1_score = FinalRank
```

Trong đó:

```text
FinalRank = w1 × TagMatch + w2 × RatingScore + w3 × PopularityScore + ...
```

---

## 5. Đầu ra của Module 2

Đầu ra của Module 2 là danh sách các cụm địa điểm theo ngày.

Ví dụ:

```json
{
  "day_clusters": [
    {
      "day": 1,
      "date": "2026-06-22",
      "places": [p1, p4, p7, p9]
    },
    {
      "day": 2,
      "date": "2026-06-23",
      "places": [p2, p3, p5, p8]
    }
  ],
  "backup_places": [...],
  "optional_places": [...]
}
```

Trong đó:

```text
day_clusters: danh sách địa điểm chính được xếp vào từng ngày
backup_places: địa điểm dự phòng, có thể dùng nếu người dùng thay đổi lịch
optional_places: địa điểm điểm cao nhưng chưa xếp được vào lịch chính
```

Module 2 chưa quyết định thứ tự đi trong ngày. Ví dụ ngày 1 có 4 địa điểm, nhưng đi địa điểm nào trước sẽ do Module 3 xử lý.

---

## 6. Các tham số chính

### 6.1. `total_days`

Số ngày đi của user:

```text
total_days = (end_date - start_date) + 1
```

Ví dụ:

```text
start_date = 2026-06-22
end_date = 2026-06-23
total_days = 2
```

---

### 6.2. `CandidatePerDay`

Số địa điểm ứng viên lấy dư cho mỗi ngày.

```text
CandidatePerDay = 8
```

Số lượng địa điểm đưa vào Module 2:

```text
CandidateLimit = total_days × CandidatePerDay
```

Ví dụ user đi 2 ngày:

```text
CandidateLimit = 2 × 8 = 16
```

Điểm quan trọng:

```text
CandidateLimit không phải số địa điểm cuối cùng trong lịch trình.
CandidateLimit chỉ là số lượng ứng viên tốt nhất để Module 2 lựa chọn.
```

---

### 6.3. `target_per_day`, `min_per_day`, `max_per_day`

Số địa điểm mỗi ngày nên phụ thuộc vào `pace_level` mà user chọn ở onboarding.

Bảng đề xuất:

| pace_level | Ý nghĩa         | target_per_day | min_per_day | max_per_day |
| ---------- | --------------- | -------------: | ----------: | ----------: |
| easy       | Đi nhẹ, ít điểm |              3 |           2 |           4 |
| balanced   | Cân bằng        |              4 |           3 |           5 |
| active     | Đi nhiều hơn    |              5 |           4 |           6 |
| packed     | Lịch dày        |              5 |           4 |           6 |

Với user chọn `balanced`:

```text
target_per_day = 4
min_per_day = 3
max_per_day = 5
```

Nếu user đi 2 ngày:

```text
target_total_places = 2 × 4 = 8
min_total_places = 2 × 3 = 6
max_total_places = 2 × 5 = 10
```

Nghĩa là từ Top 16 ứng viên, Module 2 sẽ chọn khoảng 8 địa điểm chính, không dùng hết 16 địa điểm.

---

### 6.4. `MaxVisitDuration`

Tổng thời gian tham quan tối đa trong một ngày.

Đề xuất:

```text
MaxVisitDuration = 420 phút
```

Tức là mỗi ngày không nên vượt quá khoảng 7 giờ tham quan.

Tuy nhiên, nếu sau này hệ thống tính được thời gian di chuyển, nên tách thành:

```text
MaxVisitDuration = 300 đến 360 phút
MaxDayLoad = 420 phút
```

Trong đó:

```text
MaxVisitDuration: chỉ tính thời gian tham quan
MaxDayLoad: tính thời gian tham quan + thời gian di chuyển ước tính
```

Ở phiên bản hiện tại, nếu chưa có travel time thì có thể tạm dùng:

```text
VisitDuration(day) ≤ 420 phút
```

---

### 6.5. `HighRankThreshold`

Ngưỡng bảo vệ địa điểm có điểm cao.

```text
HighRankThreshold = 0.8
```

Nếu:

```text
module1_score >= 0.8
```

thì địa điểm được xem là rất phù hợp với user. Các địa điểm này nên hạn chế bị loại khỏi lịch chính. Nếu không xếp được vào ngày chính, nên đưa vào `optional_places` thay vì xóa hẳn.

Trong trường hợp hiện tại nếu `TagMatch` thường nhỏ hơn 0.8, có thể chỉnh ngưỡng này linh hoạt hơn:

```text
HighRankThreshold = top 20% module1_score cao nhất
```

Cách này hợp lý hơn khi điểm TagMatch thực tế không đạt tới 0.8.

---

## 7. Quy trình thực hiện Module 2

## Bước 1: Nhận Top K địa điểm từ Module 1

Module 1 trả về danh sách địa điểm đã được sắp xếp theo `TagMatch` hoặc `module1_score` giảm dần.

Ví dụ user đi 2 ngày:

```text
total_days = 2
CandidatePerDay = 8
CandidateLimit = 16
```

Module 1 trả về:

```text
top_places = Top 16 địa điểm theo TagMatch
```

Nếu Module 1 trả về nhiều hơn 16 địa điểm, Module 2 chỉ lấy Top 16.

Nếu Module 1 trả về ít hơn 16 địa điểm, Module 2 dùng toàn bộ địa điểm có sẵn.

---

## Bước 2: Kiểm tra dữ liệu đầu vào

Trước khi chạy K-means, cần kiểm tra các điều kiện:

```text
1. Place phải có latitude và longitude.
2. Place phải có is_itinerary_eligible = true.
3. Place phải có module1_score hoặc tag_match.
4. Place nên có estimated_duration_minutes.
```

Nếu thiếu `estimated_duration_minutes`, dùng fallback theo subcategory.

Ví dụ fallback duration:

| Subcategory              | Duration mặc định |
| ------------------------ | ----------------: |
| Cà phê & Trà             |           60 phút |
| Quán ăn địa phương       |           60 phút |
| Nhà hàng / Fine Dining   |           90 phút |
| Chợ truyền thống         |           60 phút |
| Di tích & Lịch sử        |           90 phút |
| Bảo tàng & Nghệ thuật    |          120 phút |
| Tâm linh & Tôn giáo      |           60 phút |
| Công viên & Vườn         |           90 phút |
| Biển & Đảo               |          150 phút |
| Vui chơi giải trí        |          180 phút |
| Núi rừng / Vườn quốc gia |          240 phút |

Nếu địa điểm không có tọa độ, không nên đưa vào K-means. Có thể đưa vào `backup_places` hoặc loại khỏi Module 2.

---

## Bước 3: Xác định số địa điểm cuối cùng cần chọn

Dựa vào `pace_level`, xác định:

```text
target_per_day
min_per_day
max_per_day
```

Sau đó tính:

```text
target_total_places = total_days × target_per_day
min_total_places = total_days × min_per_day
max_total_places = total_days × max_per_day
```

Ví dụ user đi 2 ngày và chọn `balanced`:

```text
target_per_day = 4
min_per_day = 3
max_per_day = 5

target_total_places = 2 × 4 = 8
min_total_places = 2 × 3 = 6
max_total_places = 2 × 5 = 10
```

Module 2 sẽ cố gắng tạo lịch chính khoảng 8 địa điểm, miễn là dữ liệu đủ.

---

## Bước 4: Chuẩn bị dữ liệu tọa độ cho K-means

Mỗi địa điểm được biểu diễn bằng vector:

```text
Xi = (latitude_i, longitude_i)
```

Tập dữ liệu đưa vào K-means:

```text
X = [
  [lat1, lon1],
  [lat2, lon2],
  ...
]
```

Nếu dùng K-means trực tiếp trên latitude và longitude, trong phạm vi một tỉnh hoặc một thành phố thì có thể chấp nhận được. Nếu dữ liệu trải rộng nhiều tỉnh hoặc khoảng cách lớn, nên chuyển tọa độ sang dạng khoảng cách km hoặc dùng Haversine để kiểm tra ở bước repair.

---

## Bước 5: Chạy K-means

Số cụm:

```text
k = total_days
```

Ví dụ user đi 2 ngày:

```text
k = 2
```

Chạy K-means:

```python
kmeans = KMeans(
    n_clusters=total_days,
    random_state=42,
    n_init=10
)
labels = kmeans.fit_predict(coordinates)
```

Kết quả:

```text
Mỗi place được gán một cluster label.
Mỗi cluster label tương ứng với một ngày.
```

Ví dụ:

```text
cluster 0 → ngày 1
cluster 1 → ngày 2
```

Lưu ý: K-means không biết ngày nào là ngày 1, ngày nào là ngày 2 theo tuyến đường. Nó chỉ tạo cụm địa lý. Việc sắp xếp ngày theo tuyến có thể xử lý sau bằng cách sort cụm theo vị trí hoặc để Module 3 xử lý.

---

## Bước 6: Tạo cụm ban đầu

Sau khi có label từ K-means, hệ thống gom địa điểm theo cụm:

```text
C = {C1, C2, ..., CD}
```

Trong đó:

```text
Cd là danh sách địa điểm thuộc ngày d.
```

Ví dụ:

```text
C1 = {p1, p4, p7, p10, p12}
C2 = {p2, p3, p5, p6, p8, p9}
```

Ở bước này, cụm có thể chưa hợp lệ. Một cụm có thể có quá nhiều địa điểm, cụm khác có quá ít địa điểm hoặc tổng thời gian tham quan quá dài.

---

## Bước 7: Trong mỗi cụm, chọn địa điểm chính

Vì Top K chỉ là candidate pool, Module 2 không dùng hết tất cả địa điểm trong cụm.

Với mỗi cụm ngày:

```text
1. Sắp xếp địa điểm trong cụm theo module1_score giảm dần.
2. Chọn tối đa target_per_day địa điểm tốt nhất trước.
3. Nếu cụm vẫn còn chỗ và ngày chưa đạt min_per_day, có thể lấy thêm đến max_per_day.
4. Các địa điểm còn lại đưa vào backup_places.
```

Ví dụ:

```text
User đi 2 ngày
Top K = 16
target_per_day = 4
```

Sau K-means:

```text
Cụm 1 có 9 địa điểm
Cụm 2 có 7 địa điểm
```

Chọn lịch chính:

```text
Ngày 1: lấy 4 địa điểm có module1_score cao nhất trong cụm 1
Ngày 2: lấy 4 địa điểm có module1_score cao nhất trong cụm 2
Backup: 8 địa điểm còn lại
```

---

## Bước 8: Tính tải thời gian của từng ngày

Với mỗi ngày, tính tổng thời gian tham quan:

```text
VisitDuration(Cd) = sum(duration_i for pi in Cd)
```

Trong đó:

```text
Cd: cụm địa điểm của ngày d
duration_i: thời gian tham quan ước tính của địa điểm i
```

Ví dụ:

```text
Ngày 1 có 4 địa điểm:
A = 90 phút
B = 60 phút
C = 120 phút
D = 90 phút

VisitDuration = 90 + 60 + 120 + 90 = 360 phút
```

Điều kiện hợp lệ:

```text
VisitDuration(Cd) ≤ MaxVisitDuration
```

Ví dụ:

```text
MaxVisitDuration = 420 phút
```

thì ngày trên hợp lệ vì:

```text
360 ≤ 420
```

---

## Bước 9: Kiểm tra tính hợp lệ của từng ngày

Một cụm ngày hợp lệ nếu thỏa:

```text
min_per_day ≤ số địa điểm trong ngày ≤ max_per_day
VisitDuration(day) ≤ MaxVisitDuration
```

Ví dụ với `balanced`:

```text
3 ≤ số địa điểm trong ngày ≤ 5
VisitDuration(day) ≤ 420 phút
```

Nếu tất cả ngày đều hợp lệ, Module 2 có thể trả kết quả.

Nếu có ngày không hợp lệ, chuyển sang Greedy Repair.

---

## Bước 10: Greedy Repair khi ngày có quá ít địa điểm

Trường hợp:

```text
Ngày d có số địa điểm < min_per_day
```

Ví dụ:

```text
Ngày 1 có 2 địa điểm
min_per_day = 3
```

Cách xử lý:

```text
1. Tìm địa điểm trong backup_places hoặc cụm khác.
2. Ưu tiên địa điểm gần tâm cụm ngày đang thiếu.
3. Ưu tiên địa điểm có module1_score cao.
4. Chỉ thêm nếu tổng duration không vượt MaxVisitDuration.
5. Chỉ thêm nếu khoảng cách đến cụm nhận không quá xa.
```

Công thức chọn điểm bổ sung có thể là:

```text
AddScore(pi, Cd)
=
α × module1_score_i
- β × distance(pi, centroid_d)
- γ × duration_penalty_i
```

Trong đó:

```text
module1_score_i: điểm phù hợp của địa điểm
distance(pi, centroid_d): khoảng cách từ địa điểm đến tâm cụm ngày d
duration_penalty_i: mức phạt nếu địa điểm làm ngày quá tải
```

Chọn địa điểm có `AddScore` cao nhất để thêm vào ngày thiếu.

---

## Bước 11: Greedy Repair khi ngày có quá nhiều địa điểm

Trường hợp:

```text
Ngày d có số địa điểm > max_per_day
```

Ví dụ:

```text
Ngày 1 có 6 địa điểm
max_per_day = 5
```

Cần chọn địa điểm để chuyển ra khỏi ngày đó.

Không nên chọn ngẫu nhiên. Nên ưu tiên đưa ra địa điểm:

```text
1. Xa tâm cụm hiện tại.
2. Có duration dài.
3. Có module1_score thấp.
```

Công thức:

```text
MoveScore(pi)
=
λ1 × distance(pi, centroid_current)
+ λ2 × duration_i
- λ3 × module1_score_i
```

Ý nghĩa:

```text
Địa điểm càng xa tâm cụm thì càng dễ bị chuyển.
Địa điểm có thời gian tham quan càng dài thì càng dễ bị chuyển.
Địa điểm có điểm phù hợp càng cao thì càng được giữ lại.
```

Địa điểm có `MoveScore` cao nhất sẽ được chuyển ra khỏi ngày hiện tại.

Sau khi chọn điểm cần chuyển, hệ thống thử:

```text
1. Chuyển sang ngày khác nếu ngày đó còn chỗ và đủ gần.
2. Nếu không chuyển được, đưa vào backup_places.
3. Nếu điểm có module1_score rất cao, đưa vào optional_places thay vì loại bỏ.
```

---

## Bước 12: Greedy Repair khi ngày quá tải thời gian

Trường hợp:

```text
VisitDuration(day) > MaxVisitDuration
```

Ví dụ:

```text
Ngày 1 có 4 địa điểm nhưng tổng duration = 520 phút
MaxVisitDuration = 420 phút
```

Ngày này bị quá tải dù số lượng địa điểm vẫn hợp lệ.

Cách xử lý:

```text
1. Tính MoveScore cho từng địa điểm trong ngày.
2. Ưu tiên chuyển địa điểm có duration dài, xa tâm cụm và score thấp.
3. Sau mỗi lần chuyển, tính lại VisitDuration.
4. Lặp đến khi VisitDuration ≤ MaxVisitDuration.
```

Nếu địa điểm bị chuyển có `module1_score` cao, không nên xóa hẳn. Nên đưa vào `optional_places`.

---

## Bước 13: Điều kiện chấp nhận chuyển địa điểm sang ngày khác

Khi chuyển một địa điểm từ ngày A sang ngày B, cần kiểm tra:

```text
1. Ngày B chưa vượt max_per_day.
2. VisitDuration(B) + duration_i ≤ MaxVisitDuration.
3. Địa điểm không quá xa tâm cụm ngày B.
```

Điều kiện khoảng cách:

```text
distance(pi, centroid_B) ≤ delta
```

Trong đó:

```text
delta: ngưỡng khoảng cách tối đa cho phép
```

Có thể chọn `delta` theo khoảng cách trung bình của cụm nhận:

```text
delta = rho × AvgDist_B
```

Với:

```text
rho = 2
```

Ví dụ:

```text
AvgDist_B = 2 km
delta = 2 × 2 = 4 km
```

Nghĩa là địa điểm mới chỉ được chuyển vào ngày B nếu cách tâm cụm ngày B không quá 4 km.

Nếu cụm nhận còn quá ít điểm, có thể nới `rho` lên 2.5 hoặc 3 để dễ repair hơn.

---

## Bước 14: Bảo vệ địa điểm có điểm cao

Một địa điểm có `module1_score` cao nghĩa là rất phù hợp với sở thích người dùng. Vì vậy hệ thống không nên dễ dàng loại địa điểm này.

Cách xử lý:

```text
1. Nếu địa điểm có điểm rất cao, hạn chế chuyển ra khỏi lịch chính.
2. Nếu bắt buộc phải chuyển, ưu tiên chuyển sang ngày khác thay vì đưa vào backup.
3. Nếu không thể xếp được vì quá xa hoặc quá tải thời gian, đưa vào optional_places.
```

Có thể xác định địa điểm điểm cao bằng một trong hai cách:

```text
Cách 1: module1_score >= HighRankThreshold
Cách 2: nằm trong top 20% địa điểm có module1_score cao nhất
```

Với data hiện tại, nên dùng cách 2 vì điểm TagMatch thực tế có thể không đạt đến 0.8.

---

## Bước 15: Xử lý trường hợp không thể repair

Trong một số trường hợp, hệ thống không thể tạo lịch thỏa tất cả điều kiện.

Ví dụ:

```text
1. Số địa điểm ứng viên quá ít.
2. Các địa điểm quá xa nhau.
3. Tất cả điểm trong một cụm đều có duration quá dài.
4. Cụm thiếu điểm nhưng backup_places cũng quá xa.
5. Nếu thêm điểm thì vượt MaxVisitDuration.
```

Thứ tự xử lý fallback:

```text
1. Nới min_per_day, ví dụ từ 3 xuống 2.
2. Giữ ngày thiếu điểm nhưng đánh dấu warning.
3. Chuyển địa điểm score thấp sang backup_places.
4. Đưa địa điểm score cao nhưng khó xếp vào optional_places.
5. Trả kết quả tốt nhất có thể thay vì fail toàn bộ.
```

Không nên ép lịch trình đạt đủ số lượng nếu điều đó làm ngày đi quá xa hoặc quá tải.

---

## 8. Pseudocode tổng quát

```text
Input:
  top_places từ Module 1
  start_date
  end_date
  pace_level

Output:
  day_clusters
  backup_places
  optional_places

Bước 1:
  total_days = (end_date - start_date) + 1

Bước 2:
  candidate_limit = total_days × 8
  candidate_places = top_places[:candidate_limit]

Bước 3:
  xác định target_per_day, min_per_day, max_per_day theo pace_level

Bước 4:
  loại place thiếu latitude/longitude
  bổ sung estimated_duration_minutes nếu thiếu

Bước 5:
  chạy K-means với k = total_days trên tọa độ candidate_places

Bước 6:
  gom place theo cluster

Bước 7:
  trong mỗi cluster:
    sort place theo module1_score giảm dần
    chọn target_per_day place làm lịch chính
    phần còn lại đưa vào backup_places

Bước 8:
  kiểm tra từng ngày:
    số lượng place
    tổng duration

Bước 9:
  nếu ngày thiếu place:
    lấy thêm từ backup_places hoặc cụm khác bằng AddScore

Bước 10:
  nếu ngày quá nhiều place:
    chuyển bớt place có MoveScore cao nhất

Bước 11:
  nếu ngày quá tải duration:
    chuyển bớt place có MoveScore cao nhất

Bước 12:
  nếu không thể repair:
    nới min_per_day hoặc đưa place vào optional_places

Bước 13:
  trả về day_clusters, backup_places, optional_places
```

---

## 9. Ví dụ với user đi 2 ngày

Input từ Module 1:

```text
total_days = 2
Top K = 16 địa điểm theo TagMatch
pace_level = balanced
```

Thiết lập:

```text
target_per_day = 4
min_per_day = 3
max_per_day = 5
MaxVisitDuration = 420 phút
```

Quy trình:

```text
Bước 1: Lấy Top 16 địa điểm từ Module 1.
Bước 2: Chạy K-means với k = 2.
Bước 3: K-means chia 16 địa điểm thành 2 cụm địa lý.
Bước 4: Trong mỗi cụm, chọn 4 địa điểm có module1_score cao nhất.
Bước 5: Kiểm tra mỗi ngày có từ 3 đến 5 địa điểm.
Bước 6: Kiểm tra tổng duration mỗi ngày không vượt 420 phút.
Bước 7: Nếu ngày nào thiếu hoặc quá tải, dùng Greedy Repair.
```

Kết quả kỳ vọng:

```text
Ngày 1: 3 đến 5 địa điểm
Ngày 2: 3 đến 5 địa điểm
Tổng địa điểm chính: khoảng 8 địa điểm
Backup places: các địa điểm còn lại trong Top 16
Optional places: địa điểm điểm cao nhưng chưa xếp được
```

---

## 10. Những điểm cần lưu ý với dữ liệu hiện tại

### 10.1. Top K không phải final itinerary

Với user đi 2 ngày:

```text
Top K = 16
```

Nhưng lịch cuối không nên có 16 địa điểm vì:

```text
max_per_day = 5
2 ngày × 5 = 10 địa điểm tối đa
```

Vì vậy Top K chỉ là candidate pool.

---

### 10.2. Cần có `estimated_duration_minutes`

Module 2 dùng duration để kiểm soát lịch trình. Nếu cột này chưa đầy đủ, cần fallback theo subcategory.

Không nên để duration bị null, vì khi đó hệ thống không biết ngày đó có quá tải hay không.

---

### 10.3. Cần dữ liệu tọa độ sạch

K-means phụ thuộc vào latitude và longitude. Các place thiếu tọa độ hoặc tọa độ sai sẽ làm cụm sai.

Cần loại bỏ trước các place:

```text
latitude is null
longitude is null
latitude ngoài [-90, 90]
longitude ngoài [-180, 180]
```

---

### 10.4. Không nên để service place vào Module 2

Các địa điểm như bệnh viện, nhà thuốc, trạm xăng, lãnh sự quán, cơ quan hành chính không nên vào Module 2.

Điều kiện trước khi chạy Module 2:

```text
is_itinerary_eligible = true
```

---

### 10.5. Nếu `TagMatch` đang là điểm duy nhất, dùng `module1_score = tag_match`

Trong phiên bản hiện tại:

```text
module1_score = tag_match
```

Sau này có thể mở rộng:

```text
module1_score = FinalRank
```

Trong đó FinalRank kết hợp nhiều yếu tố hơn.

---

## 11. Kết luận

Module 2 sử dụng phương pháp K-means + Greedy Repair để chia các địa điểm từ Module 1 vào từng ngày trong lịch trình.

Quy trình chính là:

```text
1. Nhận Top K địa điểm từ Module 1.
2. Xác định số ngày và pace_level.
3. Chạy K-means để gom địa điểm gần nhau.
4. Chọn địa điểm chính trong mỗi cụm theo module1_score.
5. Kiểm tra số lượng địa điểm và tổng duration mỗi ngày.
6. Dùng Greedy Repair để sửa ngày quá ít, quá nhiều hoặc quá tải.
7. Trả về day_clusters, backup_places và optional_places.
```

Điểm quan trọng nhất là:

```text
Top K sau Module 1 chỉ là candidate pool.
Module 2 không bắt buộc dùng hết Top K.
Module 2 chỉ chọn số địa điểm phù hợp với số ngày và pace_level của user.
```

Với user đi 2 ngày, nếu Module 1 trả Top 16 địa điểm, Module 2 nên chọn khoảng 8 địa điểm chính và chia thành 2 ngày, mỗi ngày khoảng 4 địa điểm nếu pace_level là balanced.

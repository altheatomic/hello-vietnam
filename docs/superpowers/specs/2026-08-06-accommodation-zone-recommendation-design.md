# Đề xuất khu vực lưu trú theo lịch trình

## Trạng thái

Hướng thiết kế đã được người dùng chốt. Tài liệu này là đặc tả trước triển khai; chưa thay đổi code.

## Mục tiêu

Sau khi Module 2 hoàn tất việc chia địa điểm vào từng ngày, hệ thống tính một hoặc nhiều khu vực lưu trú phù hợp cho toàn bộ lịch trình. Kết quả được trả về cùng kết quả tạo lịch trình để giao diện hiển thị ngay cho người dùng.

Module 3 tiếp tục dùng cách xác định điểm bắt đầu và cách tối ưu tuyến hiện tại. Tính năng này không được phép thay đổi `start_point`, thứ tự chạy Module 3 hoặc dữ liệu địa điểm đã chọn.

## Cơ sở chọn ngưỡng ban đầu

Không có một tiêu chuẩn nghiên cứu phổ quát quy định chính xác khoảng cách giữa hai khu vực lưu trú. Các nghiên cứu cho thấy vị trí khách sạn ảnh hưởng đáng kể đến chuyển động của khách du lịch, nên việc tối ưu theo các cụm ngày là có cơ sở: [Hotel location and tourist activity in cities](https://www.sciencedirect.com/science/article/pii/S0160738311000326).

Một nghiên cứu thực nghiệm năm 2026 về tần suất đổi khách sạn báo cáo phương án đổi khách sạn nhiều hơn giảm 47 km tổng quãng đường, giảm chi phí vận chuyển trung bình và tăng thời gian nghỉ trong một ca nghiên cứu tại Trùng Khánh: [Influence of hotel change frequency on the satisfaction of urban multiday personalized tourism itinerary](https://www.accscience.com/journal/IJOCTA/articles/online_first/8121). Con số 47 km là tổng mức tiết kiệm của lịch trình, không được diễn giải thành chuẩn bắt buộc về khoảng cách giữa hai khu vực.

Nghiên cứu về travel-time budget cũng cho thấy mức chấp nhận thời gian và chi phí di chuyển thay đổi theo người dùng, loại hoạt động và bối cảnh: [TTB or not TTB](https://www.sciencedirect.com/science/article/pii/S0965856404000680). Vì vậy, các giá trị dưới đây là tham số kỹ thuật khởi điểm để kiểm thử, không phải kết luận phổ quát.

## Tham số khởi điểm

```text
LONG_TRIP_MIN_DAYS = 5
MIN_ZONE_SEPARATION_KM = 50.0
MIN_TRAVEL_COST_REDUCTION_RATIO = 0.35
MIN_DAYS_PER_ZONE = 2
```

Ý nghĩa:

- Chuyến đi từ 1 đến 4 ngày: chỉ đề xuất một khu vực lưu trú.
- Từ 5 ngày trở lên: thử cả phương án một khu vực và các phương án nhiều khu vực.
- Hai khu vực liền kề phải cách nhau ít nhất 50 km theo Haversine.
- Phương án nhiều khu vực chỉ được chọn nếu chi phí di chuyển ước tính giảm ít nhất 35% so với phương án một khu vực.
- Mỗi khu vực phải bao phủ ít nhất 2 ngày liên tiếp để tránh đổi chỗ ở quá thường xuyên.

Ngưỡng 50 km được chọn vì 15 km vẫn có thể chỉ là hai phần của cùng một đô thị và chưa đủ biện minh cho việc chuyển hành lý, nhận phòng và đổi khách sạn. 50 km là ngưỡng bảo thủ để chỉ tách khi các nhóm ngày thực sự khác biệt về địa lý. Giá trị này sẽ được kiểm tra lại bằng dữ liệu lịch trình thực tế.

## Phạm vi và cách phân chia ngày

Các ngày phải được chia thành các đoạn liên tiếp theo thời gian. Không dùng K-Means trực tiếp cho khu vực lưu trú vì K-Means có thể gom các ngày không liền nhau vào cùng một nhóm, dẫn đến lịch trình phải quay lại hoặc đổi chỗ ở không hợp lý.

Giới hạn số khu vực:

- 1–4 ngày: tối đa 1 khu vực.
- 5–8 ngày: tối đa 2 khu vực.
- 9–14 ngày: tối đa 3 khu vực.
- Từ 15 ngày: tối đa 4 khu vực.

Với mỗi cách chia hợp lệ, hệ thống chọn tâm khu vực là một day-centroid đại diện (medoid) trong đoạn đó. Chọn medoid thay vì trung bình tọa độ thuần túy giúp tránh đề xuất một điểm ở giữa khu vực không có địa điểm thực tế.

## Hàm chi phí

Module 2 hiện chưa có dữ liệu đường đi thực tế hoặc giá tiền theo phương tiện. Vì vậy, phiên bản đầu dùng chi phí di chuyển ước tính theo km đường chim bay; đây là proxy để so sánh các phương án, không phải giá tiền VND.

Với mỗi ngày, tính khoảng cách từ tâm lưu trú của phương án đến day-centroid của ngày đó. Gọi các khoảng cách này là `d_1 ... d_n`:

```text
mean_distance = mean(d_1 ... d_n)
worst_day_distance = max(d_1 ... d_n)
cost = 0.6 * mean_distance + 0.4 * worst_day_distance
```

Mức cải thiện của phương án nhiều khu vực:

```text
reduction_ratio =
    (single_zone_cost - selected_multi_zone_cost)
    / single_zone_cost
```

Phương án nhiều khu vực chỉ hợp lệ khi đồng thời thỏa mãn:

```text
adjacent_zone_separation >= 50 km
reduction_ratio >= 0.35
```

Nếu không có phương án nào đạt cả hai điều kiện, giữ một khu vực lưu trú. Không gọi Goong, Google Routes hoặc dịch vụ tính đường trong bước này; điều đó giữ cho Module 2 nhanh và không phụ thuộc API bên ngoài.

## Ví dụ nghiệp vụ

Với chuyến 7 ngày, nếu ngày 1–3 tạo thành cụm A, ngày 4–7 tạo thành cụm B, tâm A và B cách nhau 68 km và phương án hai khu vực giảm chi phí 41%, kết quả là:

```text
Khu vực 1: ngày 1–3
Khu vực 2: ngày 4–7
```

Nếu hai tâm chỉ cách nhau 25 km hoặc mức giảm chỉ 28%, hệ thống giữ một khu vực cho cả 7 ngày.

## Hợp đồng dữ liệu backend

Bổ sung một trường cấp gốc trong response tạo lịch trình:

```json
{
  "accommodation_recommendation": {
    "version": 1,
    "strategy": "single_zone",
    "zones": [
      {
        "zone_index": 1,
        "day_from": 1,
        "day_to": 7,
        "latitude": 21.0285,
        "longitude": 105.8542,
        "google_maps_query": "hotels near 21.0285,105.8542"
      }
    ],
    "evaluation": {
      "single_zone_cost_km": 18.4,
      "selected_cost_km": 18.4,
      "reduction_ratio": 0.0,
      "objective_weights": {
        "mean_distance": 0.6,
        "worst_day_distance": 0.4
      },
      "min_zone_separation_km": 50.0,
      "min_cost_reduction_ratio": 0.35
    }
  }
}
```

`strategy` có hai giá trị: `single_zone` và `multi_zone`. Mỗi zone có khoảng ngày, tọa độ trung tâm và query tọa độ để frontend tạo link Google Maps tìm khách sạn. Backend không trả danh sách khách sạn, giá hoặc tình trạng phòng.

Nếu không có tọa độ hợp lệ ở một hoặc nhiều ngày, không suy đoán vị trí từ tên địa điểm. Khi đó trả `accommodation_recommendation: null` kèm lý do debug nội bộ; phần tạo lịch trình chính vẫn hoạt động như trước.

## Tích hợp code dự kiến

Backend:

- Tạo helper thuần, ví dụ `cf_service/services/accommodation_recommendation.py`.
- Gọi helper trong `build_module2_result()` sau khi Greedy Repair và `recompute_day_centroid` hoàn tất.
- Thêm kết quả vào object Module 2 và truyền lên response của `TripPlannerService`.
- Không sửa đoạn Module 3 bắt đầu từ `_derive_start_point(top_places)` và không sửa vòng lặp cập nhật `start_point`.

Frontend:

- Thêm model optional cho `accommodation_recommendation` vào `TripPlanResponse`.
- Hiển thị card “Khu vực lưu trú đề xuất” trên trang kết quả ngay sau phần tổng quan, trước danh sách ngày.
- Với `single_zone`, hiển thị một khu vực và một nút “Tìm khách sạn trên Google Maps”.
- Với `multi_zone`, hiển thị từng zone cùng khoảng ngày, tọa độ và một nút Google Maps tương ứng.
- Link được tạo bằng tọa độ, không dùng riêng tên tỉnh hoặc tên địa điểm để tránh tìm nhầm sang tỉnh khác.
- Nếu recommendation không có, không hiển thị card; không chặn việc xem lịch trình.

## Kiểm thử

Backend unit tests dùng dữ liệu tọa độ tổng hợp:

- 3 ngày: luôn trả một zone.
- 7 ngày, hai cụm cách nhau trên 50 km và giảm trên 35%: trả hai zone liên tiếp.
- Hai cụm cách dưới 50 km: giữ một zone.
- Mức giảm dưới 35%: giữ một zone.
- Một zone có dưới 2 ngày: loại phương án đó.
- Không có tọa độ hợp lệ: trả recommendation null, không làm hỏng Module 2.
- Regression test xác nhận Module 3 vẫn nhận và cập nhật `start_point` như cũ.

Frontend tests:

- Parse được response không có trường recommendation để tương thích response cũ.
- Hiển thị đúng một hoặc nhiều zone.
- Link Google Maps chứa đúng tọa độ zone.
- Không hiển thị card khi recommendation null.

Sau khi triển khai, chạy ma trận hiệu chỉnh:

```text
distance threshold: 40 / 50 / 60 km
cost reduction:     25 / 35 / 45 %
```

Theo dõi số lần đổi khu vực, số ngày mỗi zone, chi phí ước tính trung bình, khoảng cách ngày xa nhất và các trường hợp người dùng phải di chuyển qua lại. Bộ `50 km + 35%` là baseline để so sánh.

## Ngoài phạm vi

- Không thay đổi cách lấy điểm bắt đầu của Module 3.
- Không thay đổi thuật toán Module 3 hoặc thứ tự các địa điểm trong ngày.
- Không truy vấn Google Maps/Goong để tính route trong backend.
- Không lưu hotel selection, giá phòng, tồn phòng hoặc booking.
- Không thay đổi schema Supabase trong phiên bản đầu.

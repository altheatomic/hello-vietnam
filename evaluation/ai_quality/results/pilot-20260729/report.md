# Đánh giá chất lượng các tính năng AI

Thời điểm tổng hợp: 2026-07-28T23:37:43.846943+00:00

Điểm tự động bên dưới được tính từ bộ dữ liệu khóa. Các tiêu chí factuality, relevance, fluency và độ tự nhiên của giọng nói vẫn được đánh dấu **Chờ chấm thủ công**.

| Tính năng | Số mẫu | Thành công | P50 | P95 | Chờ chấm thủ công |
|---|---:|---:|---:|---:|---:|
| AI Search (Gemini) | 20 | 95.0% | 8273 ms | 14775 ms | 19 |
| AI Chat (DeepSeek) | 14 | 92.9% | 2405 ms | 8248 ms | 13 |
| Translation (DeepSeek) | 14 | 100.0% | 1153 ms | 1366 ms | 14 |
| TTS (VBee) | 6 | 100.0% | 2971 ms | 3306 ms | 6 |

## AI Search (Gemini)

- Đúng loại ảnh: 95.0%
- Đúng tên: 20.0%
- Ghép đúng dữ liệu món ăn: 60.0%
- Đúng đầu-cuối: 20.0%
- ECE của confidence: 0.745

## AI Chat (DeepSeek)

- Đúng hành động điều hướng: 100.0%
- Bao phủ dữ kiện bắt buộc: 92.9%
- Tỷ lệ đạt tự động: 92.9%

## Translation (DeepSeek)

- Token F1 trung bình: 0.926
- chrF trung bình: 0.912
- Bảo toàn số: 85.7%
- Tỷ lệ đạt tự động: 85.7%

## TTS (VBee)

- Có audio URL: 100.0%
- Audio truy cập được: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## Cách hoàn tất đánh giá con người

Mở `human_ratings.csv`, cho ít nhất 3 người chấm độc lập theo thang 1–5. Báo cáo trung bình, độ lệch chuẩn và mức đồng thuận; không gộp ô trống vào điểm trung bình.

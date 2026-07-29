# Đánh giá chất lượng các tính năng AI

Thời điểm tổng hợp: 2026-07-28T23:31:35.852472+00:00

Điểm tự động bên dưới được tính từ bộ dữ liệu khóa. Các tiêu chí factuality, relevance, fluency và độ tự nhiên của giọng nói vẫn được đánh dấu **Chờ chấm thủ công**.

| Tính năng | Số mẫu | Thành công | P50 | P95 | Chờ chấm thủ công |
|---|---:|---:|---:|---:|---:|
| AI Search (Gemini) | 2 | 0.0% | N/A | N/A | 0 |
| AI Chat (DeepSeek) | 2 | 100.0% | 4220 ms | 4625 ms | 2 |
| Translation (DeepSeek) | 2 | 100.0% | 3616 ms | 3705 ms | 2 |
| TTS (VBee) | 2 | 100.0% | 3275 ms | 3367 ms | 2 |

## AI Search (Gemini)

- Đúng loại ảnh: 0.0%
- Đúng tên: 0.0%
- Ghép đúng dữ liệu món ăn: 0.0%
- Đúng đầu-cuối: 0.0%
- ECE của confidence: N/A

## AI Chat (DeepSeek)

- Đúng hành động điều hướng: 100.0%
- Bao phủ dữ kiện bắt buộc: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## Translation (DeepSeek)

- Token F1 trung bình: 0.962
- chrF trung bình: 0.887
- Bảo toàn số: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## TTS (VBee)

- Có audio URL: 100.0%
- Audio truy cập được: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## Cách hoàn tất đánh giá con người

Mở `human_ratings.csv`, cho ít nhất 3 người chấm độc lập theo thang 1–5. Báo cáo trung bình, độ lệch chuẩn và mức đồng thuận; không gộp ô trống vào điểm trung bình.

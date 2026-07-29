# Đánh giá chất lượng các tính năng AI

Thời điểm tổng hợp: 2026-07-28T23:47:17.614962+00:00

Điểm tự động bên dưới được tính từ bộ dữ liệu khóa. Các tiêu chí factuality, relevance, fluency và độ tự nhiên của giọng nói vẫn được đánh dấu **Chờ chấm thủ công**.

| Tính năng | Số mẫu | Thành công | P50 | P95 | Chờ chấm thủ công |
|---|---:|---:|---:|---:|---:|
| AI Search (Gemini) | 20 | 0.0% | 502 ms | 668 ms | 0 |
| AI Chat (DeepSeek) | 14 | 100.0% | 2221 ms | 3093 ms | 14 |
| Translation (DeepSeek) | 14 | 100.0% | 1178 ms | 1457 ms | 14 |
| TTS (VBee) | 6 | 100.0% | 2972 ms | 4069 ms | 6 |

## AI Search (Gemini)

- Đúng loại ảnh: 0.0%
- Đúng tên: 100.0%
- Ghép đúng dữ liệu món ăn (12 mẫu): 0.0%
- Đúng đầu-cuối: 0.0%
- ECE của confidence: N/A

## AI Chat (DeepSeek)

- Đúng hành động điều hướng: 100.0%
- Bao phủ dữ kiện bắt buộc: 97.6%
- Tỷ lệ đạt tự động: 92.9%

## Translation (DeepSeek)

- Token F1 trung bình: 0.938
- chrF trung bình: 0.935
- Bảo toàn số: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## TTS (VBee)

- Có audio URL: 100.0%
- Audio truy cập được: 100.0%
- Tỷ lệ đạt tự động: 100.0%

## Cách hoàn tất đánh giá con người

Mở `human_ratings.csv`, cho ít nhất 3 người chấm độc lập theo thang 1–5. Báo cáo trung bình, độ lệch chuẩn và mức đồng thuận; không gộp ô trống vào điểm trung bình.

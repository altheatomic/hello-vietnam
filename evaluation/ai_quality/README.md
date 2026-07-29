# HelloVietnam AI quality evaluation

Bộ đánh giá này gọi đúng các Supabase Edge Function mà ứng dụng Flutter đang
dùng:

- `ai-search`: Gemini nhận diện ảnh và liên kết món ăn với database.
- `ai-chat`: DeepSeek trả lời du lịch và đề xuất hành động trong app.
- `translate`: DeepSeek dịch văn bản.
- `translate` với action `tts`: VBee tạo giọng đọc.

## Chạy

Kiểm tra bộ dữ liệu khóa:

```powershell
python -m evaluation.ai_quality.run_evaluation validate
```

Smoke test hai mẫu cho mỗi tính năng bằng tài khoản Premium tạm thời:

```powershell
python -m evaluation.ai_quality.run_evaluation run --provision-user --limit 2
```

Chạy toàn bộ:

```powershell
python -m evaluation.ai_quality.run_evaluation run --provision-user
```

Với provider có quota thấp, giãn nhịp giữa các mẫu:

```powershell
python -m evaluation.ai_quality.run_evaluation run `
  --provision-user `
  --features ai_search `
  --delay-seconds 3.5
```

Có thể chỉ định tính năng:

```powershell
python -m evaluation.ai_quality.run_evaluation run `
  --provision-user `
  --features ai_search,translation
```

Runner đọc `SUPABASE_URL` và `SUPABASE_SERVICE_ROLE_KEY` từ
`cf_service/.env`; anon key được ưu tiên đọc từ biến môi trường
`SUPABASE_ANON_KEY`, sau đó mới đọc cấu hình Flutter. Khóa bí mật, JWT và mật
khẩu tạm không được ghi vào artifacts. Tài khoản tạm cùng dữ liệu phát sinh
được xóa trong `finally`, kể cả khi nhà cung cấp AI lỗi.

## Kết quả

Mỗi lần chạy tạo:

- `raw.jsonl`: phản hồi gốc và latency của từng mẫu.
- `scores.csv`: điểm tự động theo từng mẫu.
- `summary.json`: số liệu tổng hợp để vẽ bảng/biểu đồ.
- `report.md`: báo cáo tiếng Việt.
- `human_ratings.csv`: phiếu chấm tay, để trống thay vì bịa điểm.

## Cách đọc chỉ số

- AI Search: accuracy phân loại, độ đúng tên, ghép database, accuracy đầu-cuối
  và ECE của confidence.
- AI Chat: độ đúng action, độ bao phủ dữ kiện bắt buộc và tỷ lệ đạt tự động.
- Translation: token F1, chrF, bảo toàn số và tỷ lệ đạt tự động.
- TTS: tỷ lệ có/truy cập được audio URL. MOS và intelligibility phải được
  người thật chấm.
- Tất cả tính năng: success/error rate và latency mean, P50, P95, P99.

Các chỉ số tự động không thay thế đánh giá người dùng. Nên có ít nhất 3 người
chấm độc lập theo thang 1–5 cho factuality, relevance, fluency, adequacy,
naturalness và intelligibility.

## Chạy test

```powershell
python -m unittest discover -s evaluation/ai_quality/tests -v
```

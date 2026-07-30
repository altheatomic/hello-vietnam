# Đánh giá chất lượng các tính năng AI của HelloVietnam

Ngày đánh giá: 29/07/2026

## Kết luận ngắn

- **AI Chat:** đạt tốt trong pilot tự động; 14/14 yêu cầu trả về thành công,
  chọn đúng action và bao phủ đủ ý bắt buộc. Vẫn cần người thật chấm tính đúng
  sự thật và mức hữu ích.
- **Dịch thuật:** đạt tốt; 14/14 câu đạt tiêu chí tự động, chrF trung bình
  0,935, token F1 trung bình 0,938 và bảo toàn số 100%.
- **TTS:** hoạt động ổn định ở mức kỹ thuật; 6/6 mẫu tạo được audio URL và tải
  được audio. Chưa thể kết luận giọng tự nhiên vì MOS phải do người nghe chấm.
- **AI Search:** chưa đạt nếu mục tiêu là nhận diện đúng món và mở đúng dữ liệu
  trong app. Gemini phân loại 12/12 ảnh là `food`, nhưng chỉ đúng tên và ghép
  đúng database 4/12 (33,3%). Confidence vẫn rất cao ở cả ca sai.
- **Rủi ro vận hành:** sau lượt pilot, 20/20 request kiểm tra tiếp theo bị
  Gemini trả HTTP 429 do quota free-tier. Nhóm 8 ảnh object mới vì vậy chưa có
  số liệu hợp lệ và không bị tính thành 0 điểm.

## Phạm vi và phương pháp

Bộ đánh giá gọi đúng các Edge Function production mà Flutter đang sử dụng:
`ai-search`, `ai-chat` và `translate`. Một tài khoản Premium tạm được tạo cho
mỗi lượt, sau đó dữ liệu test và tài khoản được xóa.

Các chỉ số được chọn theo loại bài toán:

- Nhận diện: accuracy đầu-cuối, đúng loại, đúng tên, đúng `db_match`,
  confidence và Expected Calibration Error (ECE). ECE dùng để kiểm tra
  confidence có phản ánh xác suất đúng hay không, theo hướng đánh giá calibration
  của [Guo và cộng sự, ICML 2017](https://proceedings.mlr.press/v70/guo17a.html).
- Dịch thuật: token F1, bảo toàn số và chrF. chrF là F-score trên character
  n-gram theo [Popović, WMT 2015](https://aclanthology.org/W15-3049/).
- TTS: khả năng tạo và truy cập audio được đo tự động; độ tự nhiên cần chấm MOS
  theo nhóm khuyến nghị [ITU-T P.800](https://www.itu.int/itu-t/recommendations/rec.aspx?lang=en&rec=12972).
- Độ trễ: mean, P50, P95 và P99 của thời gian gọi Edge Function.

## Kết quả tự động

| Tính năng | Mẫu hợp lệ | Thành công API | Chỉ số nhiệm vụ chính | P50 | P95 |
|---|---:|---:|---|---:|---:|
| AI Search – món ăn | 12 | 100% | End-to-end 33,3% | 7,63 s | 14,21 s |
| AI Chat | 14 | 100% | Action + rubric pass 100% | 2,22 s | 3,09 s |
| Dịch thuật | 14 | 100% | chrF 0,935; bảo toàn số 100% | 1,18 s | 1,46 s |
| TTS | 6 | 100% | Audio tạo và truy cập được 100% | 2,97 s | 4,07 s |

### 1. AI Search – Gemini

Kết quả trên 12 ảnh món ăn lấy từ dữ liệu thật:

- Schema JSON hợp lệ: 12/12.
- Phân loại đúng `food`: 12/12.
- Nhận đúng tên: 4/12.
- Ghép đúng ID món trong database: 4/12.
- Đúng toàn bộ pipeline: 4/12.
- ECE: 0,623 – rất cao, cho thấy confidence chưa được calibration.
- Confidence trung bình của 4 ca đúng: 0,980.
- Confidence trung bình của 8 ca sai: 0,945.

Điểm đáng lo nhất không phải là model “không biết”, mà là model **sai với độ tự
tin rất cao**. Ví dụ các ảnh bị nhầm giữa bánh bò/bánh da lợn, bánh căn/bánh
bèo, bánh cống/bánh khọt; matcher sau đó mở đúng bản ghi của tên sai, làm lỗi
lan truyền sang màn chi tiết.

Độ trễ P95 14,21 giây cũng dài đối với thao tác tương tác trực tiếp. Không nên
dùng confidence hiện tại làm điều kiện duy nhất để tự động mở món.

### 2. AI Chat – DeepSeek

- 14/14 request thành công.
- 13 action điều hướng đều đúng; câu chỉ hỏi thông tin trả `action = null`
  đúng yêu cầu.
- Bao phủ dữ kiện bắt buộc: 100%.
- Không xuất route/URL ngoài allowlist trong bộ mẫu.
- P95: 3,09 giây.

Kết quả này chứng minh contract và điều hướng hoạt động tốt trên bộ intent hiện
tại. Nó **chưa chứng minh** mọi nội dung tư vấn đều đúng sự thật; cần người chấm
factuality, relevance và safety trên tập câu hỏi mở lớn hơn.

### 3. Dịch thuật – DeepSeek

- 14/14 request thành công và đạt ngưỡng tự động.
- Token F1 trung bình: 0,938.
- chrF trung bình: 0,935.
- Bảo toàn thời gian, giá tiền, số hiệu chuyến bay và địa chỉ: 100%.
- P95: 1,46 giây.

Các câu gồm dị ứng, hỏi đường, giá tiền, chuyến bay, hộ chiếu và tình huống khẩn
cấp. Số liệu tốt ở mức pilot, nhưng cần người song ngữ chấm adequacy/fluency vì
điểm so với reference không phát hiện hết câu dịch trôi chảy nhưng sai nghĩa.

### 4. TTS – VBee

- 6/6 request thành công.
- 6/6 có audio URL và URL tải được.
- P95: 4,07 giây.

Đây chỉ là kiểm tra kỹ thuật. Chưa có MOS, độ dễ hiểu tên riêng, giờ, số tiền và
ngữ điệu; vì vậy chưa được tuyên bố “giọng đọc chất lượng cao”.

## Ảnh hưởng dây chuyền khi một thành phần sai

| Thành phần sai | Thành phần sau bị ảnh hưởng | Mức ảnh hưởng |
|---|---|---|
| Gemini nhận sai tên món | `db_match` chọn sai món, UI mở sai chi tiết | Cao |
| Gemini confidence quá cao | App khó biết lúc nào cần hỏi lại người dùng | Cao |
| AI Chat chọn sai action | Điều hướng sai màn hình | Cao, nhưng pilot chưa gặp |
| AI Chat sai nội dung | Người dùng nhận tư vấn du lịch sai | Cao; cần human review |
| Dịch sai nghĩa | TTS đọc chính câu sai | Cao nếu người dùng bấm phát âm |
| TTS phát âm kém | Không làm hỏng dữ liệu, chỉ giảm khả năng giao tiếp | Trung bình |

## Sự cố quota và khả năng chịu tải

Lượt đánh giá sạch đầu tiên hoàn thành 20 Gemini request. Sau đó, hai lượt kiểm
tra tiếp theo nhận HTTP 429; lượt xác nhận cuối có 20/20 request bị 429. Google
quy định quota theo project và có thể giới hạn theo RPM, TPM hoặc RPD; vượt một
trong các giới hạn sẽ trả lỗi rate-limit
([Gemini API rate limits](https://ai.google.dev/gemini-api/docs/rate-limits)).

Do đó:

- Không dùng 20 lỗi 429 để tính accuracy AI Search.
- Vẫn phải báo đây là lỗi availability thực tế.
- Chưa thể kết luận “10 người dùng đồng thời chạy được” từ pilot tuần tự này.
  Cần một bài load test riêng ở mức 1, 5 và 10 virtual users sau khi nâng quota
  hoặc bật billing.

## Phần còn phải chấm bằng người thật

Sử dụng `human_ratings.csv`, tối thiểu 3 người chấm độc lập theo thang 1–5:

- AI Search: tên đúng, mô tả hữu ích, văn hóa đúng.
- AI Chat: factuality, relevance, groundedness, safety.
- Dịch: adequacy và fluency; ưu tiên người biết cả hai ngôn ngữ.
- TTS: MOS và intelligibility, đặc biệt với tên Việt Nam, giờ và số tiền.

Báo cáo trung bình, độ lệch chuẩn và mức đồng thuận; không thay ô trống bằng
điểm mặc định.

## Khuyến nghị sửa theo ưu tiên

1. **P0 – AI Search:** không tự động mở bản ghi chỉ dựa trên confidence hiện
   tại. Trả top-3 ứng viên và yêu cầu người dùng xác nhận khi matcher không đạt
   ngưỡng đã calibration.
2. **P0 – quota:** nâng tier/billing hoặc đổi model phù hợp, thêm retry có
   backoff, thông báo “đã hết lượt tạm thời” và telemetry riêng cho HTTP 429.
3. **P1 – AI Search:** tăng ảnh test lên tối thiểu 100 ảnh, cân bằng food/object,
   có ảnh khó, ánh sáng yếu và góc chụp thực tế; calibration lại ngưỡng trên tập
   validation tách biệt.
4. **P1 – human evaluation:** hoàn thành phiếu chấm 3 người trước khi đưa các
   điểm “độ chính xác AI” và “độ tự nhiên TTS” vào luận văn/poster.
5. **P1 – load test:** chạy 1/5/10 người dùng đồng thời, báo throughput, P95,
   error rate và quota exhaustion; không trộn bài test tải với bài test accuracy.
6. **P2 – giám sát lỗi dây chuyền:** log riêng `detected_name`, top candidate,
   score matcher, action AI Chat và feedback người dùng để biết thành phần nào
   gây sai.

## Dữ liệu kiểm chứng

- AI Search lượt sạch: `../pilot-20260729/raw.jsonl` (báo cáo này chỉ dùng 12
  case `search-food-*`).
- Chat/Dịch/TTS lượt cuối: `../final-20260729/raw.jsonl`.
- Bằng chứng quota 429: `../ai-search-final-20260729/raw.jsonl`.
- Tóm tắt máy đọc: `summary.json`.

Đánh giá này là **pilot tự động**, chưa phải kết luận cuối cùng của khảo sát
người dùng.

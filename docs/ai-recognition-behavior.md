# AI Recognition: phạm vi phân loại và hành vi hiện tại

> Cập nhật theo mã nguồn ngày 2026-08-07. Tài liệu này mô tả hành vi đang được triển khai, không phải danh sách tính năng dự kiến.

## 1. Tóm tắt

AI Recognition hiện có **6 nhánh kết quả cấp cao** (`result_kind`):

1. `food`
2. `landmark`
3. `cultural_object`
4. `sign_text`
5. `unclear`
6. `unsupported`

Trong đó:

- **4 nhánh đầu** là loại nội dung mà AI có thể nhận diện và trả về thông tin.
- **2 nhánh cuối** là trạng thái an toàn/dự phòng, dùng khi ảnh không đủ rõ hoặc nằm ngoài phạm vi hỗ trợ.
- `sign_text` có thêm 5 loại con: `street`, `business`, `traffic`, `informational` và `other`.

AI Recognition được thiết kế cho ngữ cảnh **du lịch Việt Nam**, không phải bộ phân loại mọi vật thể có thể xuất hiện trong ảnh. Phạm vi chính là món ăn, địa danh, đồ vật văn hóa và biển có chữ đọc được.

## 2. Luồng xử lý tổng quát

Luồng nhận diện hiện tại diễn ra như sau:

1. Người dùng chụp ảnh hoặc chọn ảnh từ thư viện.
2. Ứng dụng gửi ảnh, MIME type và ngôn ngữ đang chọn tới Supabase Edge Function `ai-search`.
3. Backend yêu cầu Gemini chọn đúng một `result_kind` và trả về JSON theo schema cố định.
4. Kết quả thô được chuẩn hóa để loại bỏ các suy đoán không đủ tin cậy, dữ liệu không hợp lệ hoặc quyền mở bản đồ không phù hợp.
5. Nếu kết quả là `food`, backend thử đối chiếu món ăn với food catalog của ứng dụng.
6. Flutter parse kết quả và chọn UI tương ứng với từng `result_kind`.
7. Kết quả hợp lệ được lưu vào lịch sử cục bộ cùng thumbnail của ảnh.

Tóm tắt luồng dữ liệu:

```text
Camera/Gallery
    -> Flutter AI Search service
    -> Supabase Edge Function ai-search
    -> Gemini structured JSON
    -> Recognition normalization
    -> Food database matching (chỉ food)
    -> Flutter result UI
    -> Local recognition history (nếu đủ điều kiện)
```

## 3. Ma trận hành vi nhanh

| Kết quả | Có thông tin nhận diện | Lưu lịch sử | Nút yêu thích | Mở Maps | Đối chiếu database |
|---|---:|---:|---:|---:|---:|
| `food` | Có | Có, nếu có tên | Có | Không | Có |
| `landmark` | Có | Có, nếu có tên | Có | Có điều kiện | Không |
| `cultural_object` | Có | Có, nếu có tên | Có | Có điều kiện | Không |
| `sign_text` | Có | Có, nếu OCR có chữ | Không | Có điều kiện | Không |
| `unclear` | Không | Không | Không | Không | Không |
| `unsupported` | Không | Không | Không | Không | Không |

“Có điều kiện” nghĩa là backend phải cho phép mở bản đồ và phải cung cấp `map_query` không rỗng. Ứng dụng không tự bịa địa điểm từ vị trí hiện tại của người dùng.

## 4. Chi tiết từng loại kết quả

### 4.1. `food` — món ăn

#### Khi nào được phân loại

Ảnh được chọn là `food` khi chủ thể chính là món ăn Việt Nam hoặc món ăn có liên quan rõ ràng đến trải nghiệm du lịch. Kết quả hợp lệ phải có `detected_name` và confidence tối thiểu `0.55`.

#### Dữ liệu có thể được trả về

- Tên món ăn và mô tả ngắn.
- Nguyên liệu chính (`primary_tags`).
- Đặc điểm hương vị (`secondary_tags`).
- Thời điểm phù hợp để thưởng thức.
- Ghi chú về món ăn.
- Ý nghĩa văn hóa.
- Khoảng giá tham khảo.
- Cách chế biến.
- Các địa điểm gợi ý để thử món.
- Tên gọi khác, dùng thêm cho quá trình đối chiếu database.

#### Hành vi UI

- Hiển thị thẻ kết quả tổng quát gồm mức độ khớp và phần mô tả.
- Chỉ hiển thị các thẻ chi tiết có dữ liệu; trường rỗng sẽ bị ẩn.
- Nếu backend tìm thấy món tương ứng trong food catalog, ứng dụng hiển thị thẻ “Travel database match”.
- Người dùng có thể mở trang chi tiết món ăn từ database match.
- Có nút yêu thích trên màn hình kết quả.
- Không có nút “Find on Map”, kể cả khi AI trả về nơi nên thử món. `suggested_places` hiện chỉ được hiển thị dưới dạng văn bản.

#### Hành vi backend đặc biệt

`food` là loại duy nhất được đưa qua `resolveFoodDatabaseMatch()`. Backend sử dụng tên nhận diện, tên gọi khác và confidence để tìm bản ghi phù hợp. Các loại kết quả khác luôn nhận `db_match: null`.

### 4.2. `landmark` — địa danh/điểm tham quan

#### Khi nào được phân loại

Ảnh có chủ thể là địa danh, công trình hoặc điểm tham quan liên quan đến hành trình du lịch. Kết quả hợp lệ phải có tên nhận diện và confidence tối thiểu `0.55`.

#### Dữ liệu có thể được trả về

- Tên địa danh.
- Mô tả/ngữ cảnh dành cho khách tham quan.
- Gợi ý khu vực hoặc thành phố.
- Thời điểm phù hợp để ghé thăm.
- Câu truy vấn bản đồ và quyền mở bản đồ.

#### Hành vi UI

- Hiển thị thẻ kết quả tổng quát và mô tả nhận diện.
- Hiển thị các thẻ “Visitor context”, “Area” và “A good time to visit” nếu có dữ liệu.
- Hiển thị nút “Find on Map” khi `can_open_map == true` và `map_query` không rỗng.
- Có nút yêu thích.
- Được lưu vào lịch sử nếu có `detected_name`.

Khi mở Maps, ứng dụng có thể sử dụng vị trí hiện tại làm điểm xuất phát nếu quyền vị trí sẵn sàng. Nếu chưa có quyền, người dùng có thể mở cài đặt hoặc tiếp tục tìm kiếm mà không dùng vị trí hiện tại.

### 4.3. `cultural_object` — đồ vật văn hóa

#### Khi nào được phân loại

Ảnh có chủ thể là đồ thủ công, vật dụng truyền thống, tác phẩm hoặc vật thể mang ý nghĩa văn hóa. Kết quả hợp lệ phải có tên nhận diện và confidence tối thiểu `0.55`.

#### Dữ liệu có thể được trả về

- Tên vật thể.
- Vật liệu.
- Các cách sử dụng truyền thống.
- Cách chế tác/sản xuất.
- Ý nghĩa văn hóa.
- Tên gọi khác.
- Thông tin tìm kiếm trên bản đồ nếu vật thể gắn với một địa điểm có thể tìm được.

#### Hành vi UI

- Hiển thị thẻ kết quả tổng quát và mô tả nhận diện.
- Hiển thị vật liệu, cách sử dụng, cách chế tác và ý nghĩa văn hóa nếu có.
- Có nút “Find on Map” khi kết quả chứa truy vấn hợp lệ.
- Có nút yêu thích.
- Được lưu vào lịch sử nếu có `detected_name`.

Hiện tại trường `alternative_names` được parse và lưu trong model nhưng chưa có thẻ UI riêng để hiển thị cho `cultural_object`.

### 4.4. `sign_text` — biển có chữ

#### Khi nào được phân loại

Ảnh chứa chữ có thể đọc được trên biển đường, biển cửa hàng, biển giao thông hoặc biển thông tin. Với tên đường, đường phố, đại lộ hoặc giao lộ đọc đủ rõ, prompt yêu cầu ưu tiên `sign_text` thay vì `cultural_object`.

Kết quả `sign_text` bắt buộc phải có `text_analysis` và `original_text`. Nếu thiếu dữ liệu OCR này, backend chuyển kết quả thành `unclear`.

#### Năm loại biển con

| `sign_type` | Ý nghĩa | Hành vi đáng chú ý |
|---|---|---|
| `street` | Biển tên đường, đại lộ, giao lộ | Có thể mở Maps khi tên đủ rõ và có `map_query` |
| `business` | Biển tên cửa hàng/doanh nghiệp | Hiển thị OCR và bản dịch; Maps chỉ hiện khi backend cho phép |
| `traffic` | Biển giao thông | Hiển thị thêm ghi chú an toàn |
| `informational` | Biển hướng dẫn/thông tin | Hiển thị OCR và bản dịch |
| `other` | Biển có chữ không thuộc các nhóm trên | Hành vi OCR cơ bản |

#### Dữ liệu có thể được trả về

- Nội dung chữ gốc.
- Mã và tên ngôn ngữ được phát hiện.
- Nội dung dịch sang ngôn ngữ hiện đang chọn trong ứng dụng.
- Loại biển.
- Ngữ cảnh du lịch (`travel_context`).
- Truy vấn bản đồ và quyền mở bản đồ.

#### Hành vi UI

- Không hiển thị thẻ kết quả tổng quát giống `food`, `landmark` và `cultural_object`.
- Hiển thị nội dung gốc và nút sao chép.
- Nếu có bản dịch, hiển thị bản dịch, nút sao chép và nút “Listen”.
- Nút “Listen” hiện đang phát âm **nội dung gốc**, sử dụng ngôn ngữ được AI phát hiện; nó không đọc bản dịch dù nằm trong thẻ Translation.
- Nếu `sign_type == traffic`, hiển thị ghi chú yêu cầu tuân theo biển báo và hướng dẫn tại địa phương.
- Nếu có `map_query` hợp lệ, hiển thị nút mở Google Maps.
- Được lưu lịch sử nếu `original_text` không rỗng.
- Không có nút yêu thích.

#### Quy tắc sửa phân loại nhầm

Nếu Gemini trả `landmark` hoặc `cultural_object` nhưng đồng thời cung cấp:

- `text_analysis.original_text` không rỗng,
- `sign_type == street`,
- `can_open_map == true`, và
- `map_query` không rỗng,

backend tự động chuyển kết quả thành `sign_text`. Quy tắc này giúp biển tên đường không bị hiển thị như một địa danh hoặc đồ vật văn hóa.

### 4.5. `unclear` — không nhận diện đủ rõ

#### Khi nào được sử dụng

- Ảnh mờ hoặc chất lượng thấp.
- Không có chủ thể rõ ràng.
- Chữ trong ảnh không đọc được.
- Không đủ bằng chứng để đưa ra kết luận.
- AI chọn một loại được hỗ trợ nhưng confidence thấp hơn `0.55`.
- `sign_text` không có OCR hợp lệ.
- `food`, `landmark` hoặc `cultural_object` không có tên nhận diện.

#### Hành vi dữ liệu và UI

Backend trả một kết quả rỗng có `confidence_band: low`, đồng thời xóa tên, mô tả, tag, giá, bản đồ và text analysis. Cách xử lý này ngăn UI hiển thị dữ kiện mà AI không đủ chắc chắn.

Ứng dụng hiển thị hướng dẫn chụp ảnh sáng hơn, gần hơn và chỉ giữ một chủ thể rõ ràng trong khung hình. Người dùng có hai lựa chọn:

- Chụp lại ảnh.
- Chọn ảnh khác từ thư viện.

Kết quả không được lưu lịch sử, không có nút yêu thích và không thể mở Maps.

### 4.6. `unsupported` — loại ảnh không được hỗ trợ

#### Khi nào được sử dụng

- Vật thể thông thường không liên quan đến phạm vi du lịch.
- Ảnh người hoặc selfie.
- Giấy tờ tùy thân.
- Thẻ thanh toán.
- Nội dung không an toàn.
- Gemini trả về một `result_kind` không tồn tại.
- Response của model không tuân thủ contract ở một số trường hợp có thể chuẩn hóa.

Backend có các reason code liên quan:

- `out_of_scope`
- `person_or_selfie`
- `sensitive_document`
- `unsafe_content`
- `invalid_result_kind`
- `invalid_model_response`

AI được yêu cầu không nhận diện danh tính người và không chép lại nội dung giấy tờ nhạy cảm. Khi Gemini chặn ảnh vì safety, Edge Function vẫn trả HTTP 200 với kết quả `unsupported`, thay vì biến nó thành lỗi kỹ thuật trên UI.

#### Hành vi dữ liệu và UI

Tương tự `unclear`, backend xóa toàn bộ claim, tag, truy vấn bản đồ và text analysis. UI giải thích rằng tính năng chỉ tập trung vào món ăn Việt Nam, địa danh, đồ vật văn hóa và biển có chữ; sau đó cho phép chụp hoặc chọn ảnh khác.

Kết quả không được lưu lịch sử, không có nút yêu thích và không thể mở Maps.

## 5. Confidence và quá trình chuẩn hóa

### 5.1. Ngưỡng confidence

| Confidence | Kết quả chuẩn hóa |
|---:|---|
| `>= 0.80` | Kết quả được hỗ trợ, `confidence_band = confident` |
| `>= 0.55` và `< 0.80` | Kết quả được hỗ trợ, `confidence_band = tentative` |
| `< 0.55` | Nếu AI chọn một trong 4 loại nội dung, backend đổi thành `unclear` |

Confidence được ép vào khoảng từ `0` đến `1`. Nếu giá trị không thể chuyển thành số hữu hạn, backend dùng giá trị `0.5`; với loại nội dung được hỗ trợ, giá trị này sau đó dẫn đến `unclear`.

### 5.2. Các guardrail quan trọng

- `result_kind` không nằm trong danh sách 6 giá trị hợp lệ sẽ thành `unsupported/invalid_result_kind`.
- `unsupported` không có reason hợp lệ sẽ mặc định thành `out_of_scope`.
- `unclear` không có reason hợp lệ sẽ mặc định thành `insufficient_evidence`.
- Loại nội dung không phải biển bắt buộc có `detected_name`.
- `sign_text` bắt buộc có `text_analysis.original_text`.
- Chỉ `landmark`, `cultural_object` và `sign_text` có quyền dùng Maps.
- Chỉ bật Maps khi có cả cờ cho phép và câu truy vấn không rỗng.
- Kết quả `unclear` và `unsupported` luôn bị làm rỗng các trường mô tả để tránh rò rỉ claim không đáng tin.

## 6. Lịch sử nhận diện

### Điều kiện lưu

- `food`, `landmark`, `cultural_object`: lưu khi `detected_name` không rỗng.
- `sign_text`: lưu khi `text_analysis.original_text` không rỗng.
- `unclear`, `unsupported`: không lưu.

Lịch sử hiện được lưu cục bộ bằng `SharedPreferences`, tách key theo user Supabase hoặc `anonymous`. Mỗi entry chứa:

- ID.
- Thời điểm tạo theo UTC.
- Thumbnail PNG rộng tối đa 240 px.
- Toàn bộ recognition result đã parse.

Repository giữ tối đa 30 entry và giới hạn chuỗi JSON khoảng 4 MiB. Nếu dữ liệu vượt giới hạn, các entry cũ nhất sẽ được loại dần trước khi ghi.

## 7. Bản đồ

Ba loại có thể mở Maps là:

- `landmark`
- `cultural_object`
- `sign_text`

Điều kiện bắt buộc:

```text
can_open_map == true AND map_query.trim().isNotEmpty
```

Với biển có chữ, quyền Maps được lấy từ `text_analysis`. Với địa danh và đồ vật văn hóa, quyền này lấy từ các field cấp cao của recognition result.

Nếu mở Google Maps thất bại, UI hiển thị thông báo và cho phép sao chép câu truy vấn. Prompt cũng quy định `map_query` chỉ là câu tìm kiếm địa điểm/tên trên biển; AI không được suy luận hoặc khẳng định vị trí hiện tại của người dùng.

## 8. Database matching

Database matching hiện chỉ hỗ trợ `food`:

1. Backend nhận tên món ăn và tên gọi khác từ Gemini.
2. Food matcher tìm bản ghi phù hợp trong catalog.
3. Nếu có kết quả, response chứa `db_match` gồm category, ID, tên và match score.
4. Flutter hiển thị thẻ database match và cho phép mở trang chi tiết món ăn.

`landmark`, `cultural_object` và `sign_text` chưa có cơ chế liên kết tới bản ghi nội bộ tương ứng.

## 9. Phân biệt lỗi nghiệp vụ và lỗi kỹ thuật

`unclear` và `unsupported` là kết quả nghiệp vụ hợp lệ, không phải lỗi request. Chúng được hiển thị thành UI riêng và thường trả HTTP 200.

Các tình huống sau là lỗi kỹ thuật và được hiển thị bằng snackbar/error message:

- Thiếu `GEMINI_API_KEY` trên server.
- Request không có ảnh hoặc body JSON không hợp lệ.
- Gemini API trả lỗi HTTP.
- Gemini không trả analysis text.
- Gemini trả chuỗi không parse được thành JSON.
- Flutter không thể chọn/đọc ảnh.
- Không thể mở Maps, sao chép hoặc phát audio.
- Nhận diện thành công nhưng không thể lưu lịch sử.

## 10. Các điểm chưa nhất quán hoặc còn thiếu trong UI

Đây là các hành vi tồn tại trong code hiện tại, không phải lỗi đã được sửa:

1. **Tên hiển thị của `sign_text` quá hẹp:** UI gọi mọi kết quả `sign_text` là “Street Sign”, dù contract hỗ trợ cả business, traffic, informational và other.
2. **Nút Listen gây hiểu nhầm:** nút nằm trong thẻ Translation nhưng phát âm `original_text`, không phát âm `translated_text`.
3. **`travel_context` chưa được hiển thị:** backend/schema có trả ngữ cảnh du lịch cho biển báo, nhưng widget kết quả hiện không render trường này.
4. **`alternative_names` của cultural object chưa được hiển thị:** dữ liệu được parse nhưng không có section tương ứng.
5. **Favorite không hỗ trợ biển báo:** `sign_text` được lưu lịch sử nhưng không có nút yêu thích.
6. **Favorite trên màn hình kết quả chỉ là state của page:** thao tác toggle hiện không đi qua repository lưu trữ riêng trong `AiSearchPage`.
7. **Gợi ý nơi ăn không mở Maps:** `food.suggested_places` chỉ là text, do contract chủ động không cho `food` sử dụng map action.
8. **Một số chuỗi UI còn hard-code tiếng Anh:** nhiều tiêu đề section và thông báo trong AI Recognition chưa đi qua localization đầy đủ.

## 11. Nguồn mã liên quan

- Contract, loại kết quả, reason code và normalization: [`backend/supabase/functions/ai-search/recognition_contract.ts`](../backend/supabase/functions/ai-search/recognition_contract.ts)
- Prompt và JSON response schema gửi Gemini: [`backend/supabase/functions/ai-search/recognition_prompt.ts`](../backend/supabase/functions/ai-search/recognition_prompt.ts)
- Edge Function và food database matching: [`backend/supabase/functions/ai-search/index.ts`](../backend/supabase/functions/ai-search/index.ts)
- Domain model, parse result, lịch sử và quyền Maps: [`frontend/lib/features/ai_search/domain/ai_recognition_result.dart`](../frontend/lib/features/ai_search/domain/ai_recognition_result.dart)
- UI riêng cho từng loại kết quả: [`frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart`](../frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart)
- Luồng chọn ảnh, gọi AI, copy, TTS, Maps, favorite và render kết quả: [`frontend/lib/features/ai_search/presentation/ai_search_page.dart`](../frontend/lib/features/ai_search/presentation/ai_search_page.dart)
- Lưu lịch sử nhận diện cục bộ: [`frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart`](../frontend/lib/features/ai_search/data/ai_recognition_history_repository.dart)

## 12. Kết luận

Nếu tính theo contract, AI Recognition có **6 nhánh kết quả**. Nếu chỉ tính các loại nội dung mà AI thực sự nhận diện và mô tả, hệ thống hiện hỗ trợ **4 loại cấp cao**: món ăn, địa danh, đồ vật văn hóa và biển có chữ. Hai nhánh `unclear` và `unsupported` đóng vai trò bảo vệ chất lượng và an toàn, giúp ứng dụng không hiển thị suy đoán khi bằng chứng không đủ hoặc ảnh nằm ngoài phạm vi hỗ trợ.

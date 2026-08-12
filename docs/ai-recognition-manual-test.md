# Hướng dẫn kiểm thử thủ công — AI Recognition

Tài liệu này dành cho bản AI Recognition vừa điều chỉnh: phân loại biển hiệu/tên
đường, mở bản đồ theo yêu cầu, xử lý ảnh không rõ/không hỗ trợ và chống tràn
nhãn khu vực trên màn hình hẹp. Không cần kiểm thử các bảng dữ liệu hay crawler.

## 1. Chuẩn bị

- Dùng local hoặc staging, không dùng ảnh riêng tư trên production.
- Có một tài khoản user đã đăng nhập.
- Edge Function `ai-search` đã deploy và có `GEMINI_API_KEY`.
- Có mạng Internet; chuẩn bị Google Maps nếu muốn kiểm tra nút bản đồ.
- Chạy app:

  ```powershell
  cd frontend
  flutter run -d chrome --web-port=3000
  ```

- Mở `http://localhost:3000/ai-search` (đăng nhập lại nếu app chuyển về màn
  hình đăng nhập).

Không tải lên căn cước, hộ chiếu, thẻ thanh toán, ảnh khuôn mặt của người khác
hoặc nội dung nhạy cảm. Các ảnh mẫu nên gồm:

| Mã ảnh | Nội dung gợi ý |
|---|---|
| A | Món Việt rõ nét, ví dụ bún bò Huế hoặc bún chả |
| B | Địa danh/landmark, ví dụ Đại Nội Huế |
| C | Đồ vật văn hoá, ví dụ nón lá |
| D | Biển tên đường rõ chữ, ví dụ `ĐƯỜNG NGUYỄN HUỆ` |
| E | Ảnh mờ, thiếu sáng hoặc chữ không đọc được |
| F | Vật dụng đời thường không liên quan du lịch, ví dụ điện thoại hoặc ghế |

## 2. Checklist kiểm thử

Đánh dấu `Pass`, `Fail` hoặc `Blocked`; ghi tên ảnh, ngôn ngữ app và trình
duyệt khi có lỗi.

### AR-01 — Mở luồng nhận diện

- Từ AI Recognition chọn `Choose from Library` và chọn ảnh A.
- Trong lúc xử lý phải thấy trạng thái `Analyzing image...`; sau đó chuyển sang
  màn hình kết quả, không crash.
- Nếu trình duyệt không cho camera, dùng thư viện ảnh thay thế.

### AR-02 — Kết quả món ăn

- Dùng ảnh A.
- Mong đợi nhãn `Food`, tên món và thẻ thông tin món ăn (nguyên liệu, vị,
  thời điểm, ghi chú nếu AI trả về).
- Nếu hệ thống tìm thấy món trong database, xuất hiện `Travel database match`
  và nút mở chi tiết; nếu không tìm thấy thì kết quả AI vẫn được hiển thị bình
  thường.
- Không mong đợi nút bản đồ cho kết quả Food.

### AR-03 — Landmark và đồ vật văn hoá

- Lần lượt dùng ảnh B và C.
- Mong đợi nhãn tương ứng `Landmark` hoặc `Cultural Object`, không bị ép thành
  `Food`.
- Landmark có thể có `Visitor context`, khu vực, thời điểm tham quan và nút
  `Find on Map` khi có truy vấn bản đồ hợp lệ.
- Cultural Object có thể có vật liệu, cách sử dụng, cách làm và ý nghĩa văn
  hoá. Không hiển thị các trường không có dữ liệu chỉ để lấp chỗ trống.

### AR-04 — Biển hiệu/tên đường (case chính)

- Dùng ảnh D, bảo đảm chữ `ĐƯỜNG ...` nhìn rõ.
- Mong đợi kết quả cuối có nhãn `Street Sign` (không phải `Cultural Object`),
  hiển thị các vùng:
  - `Original Text`: chữ đọc được trên ảnh;
  - `Translation`: bản dịch theo ngôn ngữ đang chọn;
  - `Find on Map` nếu tên đường đủ rõ;
  - `Copy` cho bản gốc và bản dịch, `Listen` cho chữ gốc.
- Không xuất hiện thẻ nguyên liệu, giá, cách chế biến hoặc thông tin văn hoá
  không liên quan.
- Nếu có thể xem JSON/log của Edge Function, xác nhận:

  ```text
  result_kind = sign_text
  text_analysis.sign_type = street
  text_analysis.original_text không rỗng
  can_open_map = true chỉ khi map_query không rỗng
  location_hint là tên thành phố/khu vực ngắn, không phải đoạn mô tả dài
  ```

Ngay cả khi Gemini ban đầu trả `cultural_object`, kết quả cuối vẫn phải đi vào
luồng `Street Sign` khi có đủ bằng chứng chữ đường phố.

### AR-05 — Mở bản đồ và quyền vị trí

- Khi đang phân tích ảnh, không được tự hỏi quyền vị trí.
- Sau AR-04, nhấn `Find on Map`:
  - Nếu cho phép vị trí, Google Maps mở tìm đường/tìm kiếm tới tên đường.
  - Nếu từ chối vị trí hoặc tắt Location Services, chọn `Continue Without Location`;
    Google Maps vẫn mở tìm kiếm bằng tên đường.
  - `Open Settings` phải mở đúng phần cài đặt khi được chọn.
- Nếu trình duyệt chặn mở tab mới, cho phép popup. Nếu vẫn không mở được, app
  phải hiện thông báo lỗi và tùy chọn copy truy vấn bản đồ.

### AR-06 — Ảnh không đủ rõ

- Dùng ảnh E.
- Mong đợi nhãn `Unclear` hoặc thông báo `Could not recognize clearly`.
- Không có nút bản đồ, giá, vật liệu, database match hay thông tin chi tiết bịa
  ra.
- Có hai nút `Take Another Photo` và `Choose Another Image` để thử lại.

### AR-07 — Ảnh ngoài phạm vi hỗ trợ

- Dùng ảnh F.
- Mong đợi `Not Supported` / `Image Type Not Supported` và giải thích ngắn rằng
  tính năng tập trung vào món Việt, địa danh, đồ vật văn hoá và biển hiệu đọc
  được.
- Không có map, food detail, database match hoặc OCR không liên quan.
- Kết quả này không được tự lưu vào lịch sử; có nút chụp/chọn ảnh khác.

### AR-08 — Màn hình hẹp không tràn layout

- Mở Chrome DevTools, chọn thiết bị tuỳ chỉnh khoảng `400 x 642`.
- Mở lại một kết quả có phần khu vực/location ở đầu ảnh, ưu tiên ảnh D.
- Dòng location chỉ nằm trên một dòng và được cắt bằng dấu `…` nếu dài; không
  xuất hiện `RenderFlex overflow`, thanh cuộn ngang hoặc chữ đè lên nút.
- Các thẻ kết quả bên dưới vẫn cuộn dọc bình thường.

### AR-09 — Ngôn ngữ, copy và nghe phát âm

- Chạy AR-04 khi app ở English, sau đó đổi sang Vietnamese và nhận diện lại ảnh
  D.
- Bản gốc phải giữ nguyên; bản dịch phải đổi theo ngôn ngữ đích được chọn.
- Nhấn `Copy` ở cả hai vùng và dán thử vào ô văn bản khác.
- Nhấn `Listen`; nếu trình duyệt không phát âm được, app phải báo lỗi rõ ràng,
  không bị treo.

### AR-10 — Lịch sử nhận diện

- Sau khi nhận diện thành công ảnh A hoặc D, mở `Recognition history`.
- Kết quả thành công xuất hiện và mở lại được màn hình kết quả.
- Kết quả `Unclear`/`Not Supported` không tạo mục lịch sử mới.
- Khi mở lại mục biển hiệu từ lịch sử, app không hỏi quyền vị trí ngay; chỉ xử
  lý quyền khi nhấn `Find on Map`.

## 3. Bằng chứng cần gửi lại

| Case | Kết quả | Bằng chứng | Ghi chú |
|---|---|---|---|
| AR-01 |  | Ảnh trạng thái analyzing/kết quả |  |
| AR-02 |  | Màn hình Food |  |
| AR-03 |  | Landmark/Cultural Object |  |
| AR-04 |  | Street Sign, OCR và bản dịch |  |
| AR-05 |  | Google Maps hoặc dialog quyền vị trí |  |
| AR-06 |  | Màn hình Unclear |  |
| AR-07 |  | Màn hình Not Supported |  |
| AR-08 |  | Ảnh viewport hẹp |  |
| AR-09 |  | Bản dịch/copy/listen |  |
| AR-10 |  | Lịch sử và màn hình khôi phục |  |

Khi báo `Fail`, ghi thêm: thiết bị/trình duyệt, ngôn ngữ app, tên ảnh, bước tái
hiện, thông báo lỗi nguyên văn và ảnh chụp màn hình. Không gửi access token,
API key hoặc ảnh nhạy cảm.

## 4. Nếu không thể test end-to-end

Đánh dấu `Blocked` nếu `ai-search` thiếu `GEMINI_API_KEY`, tài khoản chưa đăng
nhập, hết quota Gemini hoặc không có mạng. Không tự sửa JSON/log để biến thành
`Pass`; gửi lại lỗi cấu hình để kiểm tra riêng.

Sau khi test xong, có thể xoá ảnh khỏi máy test và xoá các mục lịch sử thử
nghiệm nếu staging dùng chung. Không cần chạy SQL cleanup cho tính năng này.

# Thiết kế script tạo Google Form khảo sát HelloVietnam

## Mục tiêu

Tạo một file Google Apps Script độc lập giúp người dùng tự động tạo bản khảo sát
đánh giá HelloVietnam rút gọn. Biểu mẫu dành cho người đã trải nghiệm ứng dụng,
có thời gian trả lời dự kiến từ 5 đến 7 phút và phù hợp để thu thập dữ liệu cho
đồ án tốt nghiệp.

## Sản phẩm đầu ra

File triển khai dự kiến:

`tao_google_form_khao_sat_hellovietnam.gs`

File phải chứa:

- hướng dẫn dán và chạy script trong Google Apps Script;
- hàm chính `createHelloVietnamSurvey()`;
- toàn bộ nội dung câu hỏi bằng tiếng Việt;
- các hàm hỗ trợ nhỏ để tạo câu hỏi và nhóm Likert;
- thông báo kết quả gồm liên kết chỉnh sửa Form, liên kết trả lời Form và liên
  kết Google Sheets.

Mỗi lần chạy hàm chính sẽ tạo một Google Form và một Google Sheets mới. Script
không sửa hoặc ghi đè biểu mẫu đã tạo trước đó.

## Cấu trúc biểu mẫu

### Phần 1 — Giới thiệu và xác nhận trải nghiệm

- Trình bày mục đích nghiên cứu, thời gian trả lời và nguyên tắc không xác định
  danh tính người tham gia.
- Hỏi mức độ đã trải nghiệm HelloVietnam.
- Ba lựa chọn đã trải nghiệm tiếp tục sang phần thông tin người tham gia.
- Lựa chọn “Chưa trải nghiệm” chuyển đến phần kết thúc dành cho người không đủ
  điều kiện khảo sát.

### Phần 2 — Thông tin người tham gia

Gồm năm câu:

1. Độ tuổi.
2. Tần suất đi du lịch tự túc.
3. Cách thường dùng để lập kế hoạch chuyến đi.
4. Kinh nghiệm sử dụng ứng dụng lập lịch trình.
5. Các chức năng HelloVietnam đã trải nghiệm.

Không thu thập họ tên, số điện thoại hoặc email.

### Phần 3 — Đánh giá ứng dụng

Sử dụng 22 nhận định Likert với năm cột:

1. Hoàn toàn không đồng ý.
2. Không đồng ý.
3. Trung lập.
4. Đồng ý.
5. Hoàn toàn đồng ý.

Các nhận định được chia thành bảy lưới ngắn:

- mức độ hữu ích: 4 nhận định;
- chất lượng gợi ý: 3 nhận định;
- chất lượng lịch trình: 5 nhận định;
- khả năng sử dụng: 4 nhận định;
- giao diện: 2 nhận định;
- hiệu năng cảm nhận: 2 nhận định;
- ý định sử dụng: 2 nhận định.

Mỗi lưới là bắt buộc. Không bật giới hạn một câu trả lời cho mỗi cột vì nhiều
nhận định có thể nhận cùng một mức điểm.

### Phần 4 — Đánh giá tổng thể

Gồm:

- thang điểm 1–5 về mức độ hợp lý tổng thể của lịch trình;
- khả năng dùng lịch trình cho chuyến đi thật;
- chức năng có thời gian chờ lâu nhất;
- tần suất gặp khó khăn khi thao tác;
- mô tả bước gây khó khăn, không bắt buộc.

### Phần 5 — Ý kiến mở

Gồm:

- điểm hữu ích nhất;
- điểm chưa hài lòng hoặc gây khó khăn;
- nội dung lịch trình cần cải thiện;
- thông tin địa điểm sai hoặc thiếu;
- chức năng mong muốn bổ sung;
- ý kiến khác.

Hai câu đầu là bắt buộc. Các câu còn lại không bắt buộc.

### Phần kết thúc dành cho người chưa trải nghiệm

Hiển thị thông báo rằng khảo sát chỉ dành cho người đã trải nghiệm hoặc xem bản
trình diễn. Sau phần này, biểu mẫu được gửi ngay và không đi qua các phần đánh
giá.

## Cài đặt Google Form

Script thiết lập:

- biểu mẫu không phải bài kiểm tra;
- không tự động thu thập email;
- không giới hạn một phản hồi cho mỗi tài khoản;
- bật thanh tiến trình;
- không trộn thứ tự câu hỏi;
- không hiển thị liên kết gửi thêm phản hồi;
- không công khai bản tổng hợp câu trả lời;
- thông báo cảm ơn sau khi gửi;
- liên kết Google Sheets làm nơi lưu phản hồi.

## Xử lý lỗi và khả năng chạy lại

- Hàm chính dùng khối `try/catch` để ghi lỗi rõ ràng vào nhật ký.
- Form và Sheet được tạo mới ở đầu mỗi lần chạy.
- Nếu lỗi xảy ra sau khi một tài nguyên đã được tạo, script ghi lại liên kết
  tài nguyên đó để người dùng có thể kiểm tra hoặc xóa thủ công.
- Không lưu ID cố định và không yêu cầu người dùng sửa mã trước khi chạy.

## Tiêu chí hoàn thành

- Script không chứa chỗ trống cần người dùng điền trước khi chạy.
- Chạy hàm chính tạo được Form và Sheet mới.
- Form có đúng cấu trúc phần, câu hỏi, lựa chọn và trạng thái bắt buộc.
- Phân nhánh “Chưa trải nghiệm” kết thúc khảo sát đúng cách.
- Các lưới Likert có đủ 22 nhận định và năm mức đánh giá.
- Nhật ký hiển thị đủ ba liên kết: chỉnh sửa, trả lời và bảng phản hồi.
- Phần chú thích đầu file hướng dẫn được một người chưa dùng Apps Script làm
  theo.

## Phạm vi không thực hiện

- Không tự động phát Form cho người tham gia.
- Không tự động phân tích kết quả hoặc tạo biểu đồ.
- Không cài trigger thu thập phản hồi.
- Không yêu cầu quyền truy cập dữ liệu của ứng dụng HelloVietnam.

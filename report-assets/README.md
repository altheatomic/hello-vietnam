# Report assets

Các hình trong thư mục này được tạo từ kiến trúc và migration hiện có của dự án:

- `system-architecture.png`: Hình 3.1.1, kiến trúc tổng thể.
- `system-architecture-v2.png`: Hình 3.1.1 cập nhật, bổ sung luồng Edge Function proxy sang FastAPI Trip & Recommend Service, hai đường truy cập PostgreSQL và FCM dự kiến tích hợp.
- `database-core-erd.png`: Hình 3.3.3.1, ERD cốt lõi dễ đọc trên trang A4.
- `database-erd.png`: ERD tổng quát nhiều nhóm nghiệp vụ, phù hợp đặt ở phụ lục hoặc trang ngang.
- `installation-flow.png`: Hình 4.1.1, quy trình cài đặt và triển khai.
- Các tệp `.svg` phù hợp khi cần phóng lớn không vỡ hình.
- Các tệp `.mmd` là mã nguồn Mermaid để chỉnh sửa và dựng lại hình.

## Dựng lại hình

Từ thư mục gốc của dự án, chạy:

```powershell
npx -y @mermaid-js/mermaid-cli -i report-assets/system-architecture.mmd -o report-assets/system-architecture.png -b white -w 2200
npx -y @mermaid-js/mermaid-cli -i report-assets/database-core-erd.mmd -o report-assets/database-core-erd.png -b white -w 2200
npx -y @mermaid-js/mermaid-cli -i report-assets/database-erd.mmd -o report-assets/database-erd.png -b white -w 2600
npx -y @mermaid-js/mermaid-cli -i report-assets/installation-flow.mmd -o report-assets/installation-flow.png -b white -w 2200
```

## Chụp lược đồ trực tiếp từ Supabase

1. Mở Supabase Dashboard của dự án.
2. Chọn `Database` rồi chọn `Schema Visualizer`.
3. Chọn schema `public`; ẩn các schema hệ thống như `auth`, `storage` nếu hình quá dày.
4. Chọn các bảng cần minh họa hoặc sắp xếp bảng theo sáu nhóm trong phần 3.3.3.
5. Thu nhỏ trình duyệt vừa đủ để thấy tên bảng và đường quan hệ, sau đó chụp màn hình ở độ phân giải cao.
6. Không đưa API key, secret, chuỗi kết nối hoặc dữ liệu cá nhân vào ảnh báo cáo.

Ảnh từ Supabase nên dùng làm hình đối chứng hoặc đưa vào phụ lục. Hình ERD rút gọn nên đặt trong phần chính vì dễ đọc hơn.

## Chụp giao diện ứng dụng

- Chạy cấu hình `User` trên cổng 3000 để chụp giao diện người dùng.
- Chạy cấu hình `Admin` trên cổng 3001 để chụp trang quản trị.
- Với giao diện di động, dùng kích thước khoảng `400 x 800`; với Admin dùng ít nhất `1440 x 900`.
- Ẩn DevTools, thanh debug, thông báo lỗi và dữ liệu cá nhân trước khi chụp.
- Giữ cùng một tỷ lệ, theme và ngôn ngữ cho các hình trong cùng một luồng chức năng.

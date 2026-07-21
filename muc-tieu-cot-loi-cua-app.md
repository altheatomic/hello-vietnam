# Ba mục tiêu cốt lõi của ứng dụng Hello Vietnam

Các mục tiêu dưới đây được tổng hợp từ những luồng chức năng và module đang có trong mã nguồn ứng dụng.

## Hướng tiếp cận chính

Để hiện thực hóa ba mục tiêu trên, hệ thống được tổ chức thành ba module thuật toán liên kết với nhau:

1. **Module 1 – CB + CF (Content-Based và Collaborative Filtering):** hồ sơ sở thích, thẻ địa điểm và hành vi người dùng được dùng để tính điểm phù hợp theo nội dung (CB). Điểm này được kết hợp với điểm cộng tác (CF) lấy từ lịch sử tương tác/rating của người dùng để xếp hạng địa điểm hoặc tỉnh thành. Phần triển khai chính nằm ở `cf_service/services/module1_algorithm.py`, `cf_service/services/module1_repository.py` và `cf_service/services/recommend_service.py`.
2. **Module 2 – K-Means + Greedy Repair:** các địa điểm được gom cụm theo tọa độ bằng K-Means với số cụm tương ứng số ngày, sau đó Greedy Repair điều chỉnh các cụm theo giới hạn số điểm mỗi ngày, nhịp độ chuyến đi và khoảng cách. Thuật toán được triển khai trong `cf_service/services/module2_algorithm.py`.
3. **Module 3 – SA-TSPTW:** mỗi ngày bắt đầu từ một tuyến Greedy nearest-neighbour, sau đó Simulated Annealing thử các phép đổi chỗ, đảo đoạn và chèn điểm để giảm chi phí tuyến. Hàm tính chi phí có xét thời gian di chuyển, thời gian chờ, giờ mở cửa, thời lượng tham quan, giờ nghỉ trưa và giới hạn cuối ngày. Phần triển khai nằm ở `cf_service/services/module3_optimizer.py` và `cf_service/services/schedule_builder.py`.

Về stack kỹ thuật, **Flutter/Dart** đảm nhiệm ứng dụng mobile và giao diện; **FastAPI/Python** cung cấp service cho gợi ý, lập kế hoạch và tối ưu tuyến; **Supabase** lưu trữ dữ liệu, xác thực người dùng và cung cấp các Edge Function/API hỗ trợ. Phạm vi dữ liệu tập trung vào các tỉnh, thành phố và địa điểm du lịch tại Việt Nam, với nguồn tỉnh thành chính được truy vấn từ bảng `old_province` và các địa điểm đủ điều kiện tham quan trong cơ sở dữ liệu Supabase.

### Công nghệ triển khai được thể hiện trong code

- **Mobile/UI:** Flutter và Dart; điều hướng bằng `go_router`; quản lý trạng thái cục bộ bằng StatefulWidget/Controller; lưu tùy chọn cục bộ bằng `shared_preferences`; hỗ trợ theme sáng/tối, Google Fonts, SVG và các asset hình ảnh.
- **Dữ liệu và API:** `supabase_flutter` ở Flutter; Supabase Database/Auth/Edge Functions; các client HTTP và Supabase Function Client để gọi API có xác thực. Backend Edge Functions viết bằng TypeScript chạy trên Deno.
- **Service thuật toán:** FastAPI/Uvicorn trên Python; `pydantic` cho dữ liệu request/response; `supabase-py` và `asyncpg` cho truy cập Supabase/PostgreSQL; NumPy và SciPy cho xử lý số liệu.
- **Bản đồ và vị trí:** `flutter_map` + `latlong2`, dữ liệu nền OpenStreetMap, `geolocator` để lấy vị trí thiết bị, `geocoding` để chuyển đổi tọa độ/địa chỉ và `url_launcher` để mở ứng dụng bản đồ.
- **Ngôn ngữ và AI:** Google ML Kit Translation chạy phía mobile; DeepSeek phục vụ dịch qua Edge Function; Gemini phục vụ AI Search; Vbee cung cấp chuyển văn bản thành giọng nói; `flutter_tts`/`audioplayers` phát nội dung âm thanh. Các API key được đọc từ Supabase Secrets ở phía server.
- **Media:** Cloudflare R2 được dùng qua Edge Function `media-upload` cho lưu trữ media, trong khi metadata và URL được lưu trong Supabase.

### Các thuật toán và kỹ thuật xử lý dữ liệu

- **Xếp hạng cá nhân hóa:** Content-Based Filtering dựa trên tag match và trọng số sở thích; Collaborative Filtering từ tương tác ngầm/tường minh. Backend có mô hình implicit ALS (`cf_service/ml/wals_model.py`), ma trận điểm kết hợp explicit/implicit (`matrix_a.py`) và cơ chế giảm trọng số onboarding khi có thêm hành vi.
- **Sinh và đối sánh tag:** cosine similarity được dùng trong `scripts/generate_place_tags.py` để gán tag cho địa điểm từ embedding; các hàm chuẩn hóa, tính tag match và chọn top-k nằm trong `module1_algorithm.py`.
- **Lọc ứng viên:** lọc trạng thái hoạt động, rating/review tối thiểu, ngân sách, số lượng điểm mỗi ngày và điều kiện có tọa độ; khi thiếu dữ liệu, pipeline có các mức fallback để vẫn tạo được kế hoạch.
- **Phân cụm và cân bằng lịch:** K-Means theo tọa độ, sau đó tính khoảng cách Haversine đến tâm cụm và Greedy Repair để di chuyển các điểm giữa ngày, bảo đảm giới hạn min/target/max theo pace.
- **Tối ưu tuyến có ràng buộc thời gian:** Greedy nearest-neighbour tạo nghiệm ban đầu; Simulated Annealing cải thiện tuyến bằng swap/reverse/insert. `schedule_builder.py` tính cost theo travel time, wait time, giờ mở cửa, thời lượng tham quan, lunch break, day-end cutoff và penalty vi phạm.
- **Tính khoảng cách:** công thức Haversine được dùng ở truy vấn địa điểm lân cận, phân cụm và tối ưu tuyến; bounding-box được dùng trước ở tầng database để giảm số ứng viên cần tính chính xác.
- **AI Search và dịch:** Edge Functions gọi Gemini/DeepSeek qua REST, yêu cầu kết quả JSON, kiểm tra lỗi/giới hạn sử dụng và chuẩn hóa dữ liệu trước khi trả về Flutter.

## 1. Xây dựng hệ thống gợi ý địa điểm cá nhân hóa

Hello Vietnam hướng đến việc đề xuất các điểm đến phù hợp với sở thích và hoàn cảnh của từng người dùng, thay vì chỉ hiển thị một danh sách địa điểm cố định.

Trong `frontend/lib/features/personalization/data/travel_recommendation_service.dart`, ứng dụng tiếp nhận `UserTravelPreferences` và tạo trọng số từ nhiều nhóm thông tin:

- phong cách du lịch, chẳng hạn ẩm thực, văn hóa, thiên nhiên, nghỉ dưỡng, phiêu lưu hoặc mua sắm;
- chủ đề quan tâm như món ăn đường phố, cà phê, bảo tàng, bãi biển, chợ đêm và địa điểm chụp ảnh;
- mức ngân sách và nhóm người đồng hành.

Các trọng số này được so khớp với tên, mô tả, thẻ, hoạt động và ẩm thực của địa điểm. Sau đó, `recommendedDestinations()` và `recommendedExploreItems()` tính điểm phù hợp, sắp xếp kết quả theo mức độ tương thích và dùng điểm đánh giá làm tiêu chí phụ. Nhờ đó, trang Home, Explore và Recommend có thể cung cấp nội dung gần với nhu cầu thực tế của từng người dùng.

## 2. Tự động phân bổ địa điểm theo ngày và tối ưu lộ trình

Ứng dụng cung cấp chức năng lập kế hoạch chuyến đi nhiều ngày, trong đó các địa điểm được tự động phân bổ vào từng ngày và sắp xếp theo trình tự tham quan.

Luồng lập kế hoạch được triển khai qua các màn hình wizard trong `frontend/lib/features/planner/presentation/`, gồm chọn địa điểm/tỉnh, thời lượng chuyến đi, sở thích và ngân sách. Dữ liệu được gửi từ `TripRepository.planTrip()` (`frontend/lib/features/planner/data/trip_repository.dart`) đến dịch vụ lập kế hoạch với các tham số như số ngày, ngày bắt đầu, tọa độ, lựa chọn sở thích và số lần chạy thuật toán.

Kết quả được ánh xạ bởi `TripPlanResponse` (`frontend/lib/features/planner/data/models/trip_plan_response.dart`) thành danh sách ngày và các điểm dừng. Mỗi điểm dừng có thể chứa thứ tự, khung giờ, thời lượng dự kiến, thời gian di chuyển, tọa độ và các điểm số `tag_match`, `cf_score`, `final_score`. Cấu trúc này cho phép hệ thống cân bằng mức độ phù hợp của địa điểm với tính liên tục của hành trình, đồng thời hỗ trợ lưu, nhân bản và chia sẻ kế hoạch.

Ngoài danh sách lịch trình, `TripMapPage` hiển thị các điểm trên bản đồ OpenStreetMap và gọi `getNearbyPlaces()` để tìm địa điểm lân cận. Người dùng vì vậy có thể xem trực quan tuyến đi và tiếp tục điều chỉnh lựa chọn trong quá trình di chuyển.

## 3. Thiết kế giao diện thân thiện, dễ dùng khi di chuyển

Mục tiêu thứ ba là giảm thao tác và giúp người dùng nhanh chóng tìm, chọn và sử dụng thông tin du lịch trên thiết bị di động.

`HomePage` tổ chức các chức năng chính bằng banner, thanh tìm kiếm, thẻ đề xuất, lưới tính năng và thẻ chuyến đi đang hoạt động. `RecommendPage` dùng hai lựa chọn trực quan “Where do you want to go?” và “When are you free to travel?”, dẫn người dùng qua các bước tìm kiếm địa điểm hoặc chọn lịch rảnh. Các màn hình lập kế hoạch tiếp tục chia nhỏ quy trình thành từng bước độc lập, giúp người dùng không phải nhập quá nhiều thông tin trên một màn hình.

Nhiều màn hình sử dụng `MediaQuery`, `SafeArea`, bố cục cuộn và các thành phần có kích thước linh hoạt để thích ứng với màn hình điện thoại. Ứng dụng cũng có theme sáng/tối, hệ thống bản địa hóa qua `context.l10n`, nút thao tác nhanh, trạng thái loading/thông báo lỗi và thao tác lưu/chia sẻ. Ở bước tham quan, bản đồ và các địa điểm lân cận được đưa trực tiếp vào luồng sử dụng, giúp giao diện hỗ trợ người dùng từ lúc khám phá đến khi đang ở trên đường.

## Tóm tắt

Ba mục tiêu trên tạo thành một chuỗi trải nghiệm thống nhất: hệ thống hiểu sở thích để gợi ý đúng địa điểm, tự động biến các lựa chọn thành lịch trình nhiều ngày có thứ tự và thông tin di chuyển, rồi trình bày toàn bộ quá trình bằng giao diện trực quan, dễ thao tác trên mobile.

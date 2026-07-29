

TRƯỜNG ĐẠI HỌC KHOA HỌC TỰ NHIÊN

**KHOA CÔNG NGHỆ THÔNG TIN**

**Phan Lê Đức Anh \- Lê Trần Kim Oanh**

**Nguyễn Gia Phúc \- Cao Phạm Hoàng Thái** 

**ỨNG DỤNG GỢI Ý LỊCH TRÌNH**

**CHO NGƯỜI DU LỊCH TỰ TÚC**

THỰC TẬP DỰ ÁN TỐT NGHIỆP CỬ NHÂN CNTT

CHƯƠNG TRÌNH CHẤT LƯỢNG CAO

Thành phố Hồ Chí Minh, 2026

**TRƯỜNG ĐẠI HỌC KHOA HỌC TỰ NHIÊN**

**KHOA CÔNG NGHỆ THÔNG TIN**

Phan Lê Đức Anh (22127020)

Lê Trần Kim Oanh (22127319) 

Nguyễn Gia Phúc (22127331)

Cao Phạm Hoàng Thái (22127382)

**XÂY DỰNG ỨNG DỤNG HỖ TRỢ NGƯỜI NƯỚC NGOÀI DU LỊCH TẠI VIETNAM**

**THỰC TẬP DỰ ÁN TỐT NGHIỆP CỬ NHÂN CNTT**

**CHƯƠNG TRÌNH CHẤT LƯỢNG CAO**

**GIẢNG VIÊN HƯỚNG DẪN**

ThS. Tiết Gia Hồng (Khoa Công nghệ Thông tin) 

Thành phố Hồ Chí Minh, 2026

**Lời cảm ơn**

Đồ án tốt nghiệp chuyên ngành Hệ thống thông tin với đề tài **“Xây dựng ứng dụng hỗ trợ người nước ngoài du lịch tại Việt Nam”** là kết quả của quá trình học tập, nghiên cứu và thực hiện nghiêm túc của nhóm, cùng với sự hỗ trợ quý báu từ Thầy, Cô, gia đình và bạn bè.

Trước hết, chúng em xin bày tỏ lòng biết ơn sâu sắc đến **Thạc sĩ Tiết Gia Hồng**, người đã tận tình hướng dẫn, định hướng và đóng góp nhiều ý kiến thiết thực trong suốt quá trình thực hiện đề tài. Sự hỗ trợ và những nhận xét chuyên môn của Cô là nền tảng quan trọng giúp nhóm từng bước hoàn thiện sản phẩm và báo cáo.

Chúng em cũng xin chân thành cảm ơn Ban Giám hiệu Trường Đại học Khoa học Tự nhiên, Đại học Quốc gia Thành phố Hồ Chí Minh, Khoa Công nghệ Thông tin cùng quý Thầy, Cô trong bộ môn đã tạo điều kiện thuận lợi, truyền đạt kiến thức và hỗ trợ nhóm trong quá trình học tập và thực hiện đồ án.

Bên cạnh đó, chúng em xin gửi lời cảm ơn đến gia đình, bạn bè và người thân đã luôn động viên, chia sẻ và đóng góp những góc nhìn đa chiều, giúp chúng em có thêm động lực để hoàn thành đề tài một cách tốt nhất.

Mặc dù đã dành nhiều thời gian và nỗ lực trong quá trình thực hiện, do giới hạn về thời gian, kinh nghiệm và nguồn lực, đồ án khó tránh khỏi những thiếu sót. Chúng em rất mong nhận được những ý kiến nhận xét và góp ý từ quý Thầy, Cô và bạn đọc để đề tài có thể được tiếp tục hoàn thiện trong tương lai.

TP. Hồ Chí Minh, ngày 20 tháng 07 năm 2026

**Nhóm tác giả**

**Danh sách bảng**

**Danh sách hình**

**Danh sách từ viết tắt và thuật ngữ**

| STT | Viết tắt | Viết đầy đủ |
| ----- | ----- | ----- |
| 1 |  |  |
| 2 |  |  |
| 3 |  |  |
| 4 |  |  |
| 5 |  |  |
| 6 |  |  |
| 7 |  |  |
| 8 |  |  |
| 9 |  |  |
| 10 |  |  |
| 11 |  |  |
| 12 |  |  |
| 13 |  |  |
| 14 |  |  |

**TÓM TẮT**

*\[Trình bày ngắn gọn bối cảnh và vấn đề: du lịch tự túc phát triển mạnh nhưng việc lên kế hoạch cá nhân hóa còn tốn nhiều công sức. HelloVietnam ra đời nhằm giải quyết bài toán này.\]*

*\[Mô tả ngắn phương pháp: hệ thống sử dụng ba module – gợi ý địa điểm (CB \+ CF/WALS), phân cụm theo ngày (K-Means \+ Greedy Repair), và tối ưu lộ trình (SA với TSPTW) – tích hợp qua API FastAPI với hai frontend Flutter.\]*

*\[Nêu kết quả chính: sản phẩm đầu ra, kết quả đánh giá thuật toán (Precision@K, F1-score), thời gian phản hồi, và phản hồi từ khảo sát người dùng.\]*

[**Chương 1: GIỚI THIỆU	11**](#heading=)

[**1.1.Đặt vấn đề	11**](#heading=)

[**1.2.Mục tiêu và hướng tiếp cận	11**](#heading=)

[**Chương 2: CÁC HỆ THỐNG VÀ CÔNG NGHỆ LIÊN QUAN	12**](#heading=)

[**2.1.Các hệ thống hỗ trợ du lịch hiện có	12**](#heading=)

[**2.2.Các công nghệ và thuật toán được áp dụng	12**](#heading=)

[**2.2.1.Hệ thống gợi ý (Recommendation Systems)	12**](#heading=)

[**2.2.3.Tối ưu lộ trình – TSP với ràng buộc thời gian (TSPTW)	13**](#heading=)

[**2.2.4.Công nghệ phát triển hệ thống	13**](#heading=)

[**Chương 3: ỨNG DỤNG HELLOVIETNAM	15**](#heading=)

[3.1. Kiến trúc hệ thống	15](#3.1.kiến-trúc-hệ-thống)

[**3.2. Thuật toán gợi ý và tối ưu lịch trình	15**](#heading=)

[**3.2.1. Module 1 – Gợi ý và chọn địa điểm	15**](#heading=)

[**3.2.2. Module 2 – Phân cụm địa điểm theo ngày	17**](#heading=)

[**3.2.3. Module 3 – Tối ưu lộ trình trong ngày (SA-TSPTW)	20**](#heading=)

[**3.3.Thiết kế các thành phần	20**](#heading=)

[**3.3.1.Dữ liệu	20**](#heading=)

[**3.3.2.Sơ đồ use-case	21**](#heading=)

[**3.3.3.Lược đồ cơ sở dữ liệu	21**](#heading=)

[Chương 4: CÀI ĐẶT VÀ ĐÁNH GIÁ	21](#chương-4:-cài-đặt-và-đánh-giá)

[**4.1.Hướng dẫn cài đặt	21**](#heading=)

[**4.2.Cài đặt các màn hình	22**](#heading=)

[**4.3.Đánh giá hiệu năng	22**](#heading=)

[**4.4.Đánh giá thuật toán	22**](#heading=)

[**4.5.Đánh giá độ hữu ích	23**](#heading=)

[**Chương 5: KẾT LUẬN	24**](#heading=)

[**5.1.Kiến thức	24**](#heading=)

[**5.2.Khó khăn trong quá trình thực hiện	24**](#heading=)

[**5.3.Sản phẩm đạt được	24**](#heading=)

[5.4. Hướng phát triển	24](#5.4.-hướng-phát-triển)

# **Chương 1: GIỚI THIỆU**

## **1.1.Đặt vấn đề**

*\[Phân tích bối cảnh: xu hướng du lịch tự túc (FIT) tại Việt Nam, số liệu UNWTO, Booking.com hoặc các nguồn khác về mức độ phổ biến. Chỉ ra những khó khăn cụ thể người dùng gặp phải khi tự lên kế hoạch: quá nhiều nguồn thông tin, khó cá nhân hóa, khó tối ưu lộ trình di chuyển giữa các địa điểm.\]*

*\[Từ đó đặt vấn đề cho đồ án: cần một công cụ có thể đồng thời gợi ý địa điểm phù hợp sở thích và tối ưu lịch trình theo ràng buộc thực tế (giờ mở cửa, khoảng cách, số ngày).\]*

Trong bối cảnh du lịch Việt Nam phục hồi mạnh mẽ sau đại dịch, ngành du lịch tiếp tục giữ vai trò quan trọng trong phát triển kinh tế, xã hội. Theo Cục Du lịch Quốc gia Việt Nam, năm 2024, Việt Nam đón khoảng 17,6 triệu lượt khách quốc tế, phục vụ 110 triệu lượt khách nội địa và đạt tổng thu từ khách du lịch khoảng 840 nghìn tỷ đồng \[1\]. Những kết quả này cho thấy thị trường du lịch Việt Nam có quy mô lớn và còn nhiều tiềm năng tăng trưởng. Việc mở rộng chính sách thị thực, cải thiện hạ tầng và đẩy mạnh quảng bá điểm đến cũng góp phần nâng cao sức hấp dẫn của Việt Nam đối với du khách quốc tế.

Cùng với sự phục hồi của thị trường, du lịch tự túc, thường được gọi là FIT (Free Independent Traveller), ngày càng trở nên phổ biến. Khác với hình thức tham gia tour trọn gói, khách du lịch tự túc chủ động lựa chọn điểm đến, thời gian, phương tiện, nơi lưu trú và các hoạt động trong chuyến đi. Theo Decision Lab, 57% người tham gia khảo sát tại Việt Nam ưu tiên tự lập kế hoạch và đặt các dịch vụ cần thiết, trong khi 27% lựa chọn tour trọn gói và 16% kết hợp cả hai hình thức \[5\]. Điều này cho thấy du khách ngày càng đề cao tính linh hoạt, khả năng kiểm soát hành trình và mức độ phù hợp với nhu cầu cá nhân.

Bên cạnh đó, chuyển đổi số đang trở thành một định hướng quan trọng của ngành du lịch Việt Nam. Theo Cổng Thông tin điện tử Chính phủ, Đề án ứng dụng công nghệ của công nghiệp 4.0 trong phát triển du lịch đặt mục tiêu xây dựng hệ sinh thái du lịch thông minh, phát triển các nền tảng và ứng dụng phục vụ khách du lịch, thúc đẩy hoạt động kinh doanh trực tuyến và nâng cao trải nghiệm người dùng \[2\]. Vì vậy, việc ứng dụng công nghệ vào hoạt động du lịch không còn chỉ mang tính hỗ trợ mà đang trở thành yêu cầu cần thiết để nâng cao chất lượng dịch vụ và năng lực cạnh tranh.

Tuy mang lại sự chủ động, du lịch tự túc cũng đặt ra nhiều khó khăn trong quá trình chuẩn bị. Thông tin về địa điểm, văn hóa, ẩm thực, giờ hoạt động, mức giá và phương thức di chuyển thường phân tán trên nhiều website, mạng xã hội, blog và ứng dụng bản đồ. Người dùng phải dành nhiều thời gian để tìm kiếm, tổng hợp và đánh giá độ tin cậy của thông tin. Khi số lượng nguồn và lựa chọn tăng lên, người dùng dễ gặp tình trạng quá tải thông tin và khó xác định những địa điểm thực sự phù hợp.

Việc lựa chọn và xây dựng lịch trình cũng không đơn giản vì mỗi người có sở thích, ngân sách, thời gian và mục đích du lịch khác nhau. Các danh sách địa điểm phổ biến thường được xây dựng theo xu hướng chung, chưa phản ánh đầy đủ nhu cầu cá nhân. Sau khi chọn được địa điểm, người dùng còn phải phân bổ chúng vào từng ngày và sắp xếp thứ tự tham quan sao cho phù hợp với khoảng cách, thời gian di chuyển, thời lượng tham quan, giờ mở cửa và số ngày của chuyến đi. Nếu sắp xếp không hợp lý, lịch trình có thể làm tăng quãng đường di chuyển, phát sinh thời gian chờ hoặc không thể hoàn thành trong thực tế.

Những khó khăn này càng rõ rệt đối với khách nước ngoài khi đến Việt Nam. Ngoài việc tìm kiếm và kiểm chứng thông tin, họ còn có thể gặp trở ngại về ngôn ngữ, giao tiếp, chỉ dẫn và sử dụng dịch vụ tại điểm đến. Theo nghiên cứu của Booking.com, 44% du khách cho biết rào cản ngôn ngữ có thể khiến họ chần chừ khi lên kế hoạch cho chuyến đi, trong khi 18% lo ngại bị lạc khi không thể sử dụng ngôn ngữ địa phương \[3\]. Khách quốc tế cũng có thể gặp khó khăn khi tìm hiểu phong tục, văn hóa, ẩm thực và phương thức di chuyển tại Việt Nam.

Trong khi đó, nhu cầu sử dụng các công cụ thông minh để hỗ trợ lập kế hoạch du lịch ngày càng gia tăng. Theo khảo sát toàn cầu của Booking.com, 41% người tham gia quan tâm đến việc sử dụng lịch trình được cá nhân hóa bằng trí tuệ nhân tạo trong quá trình lên kế hoạch \[4\]. Điều này cho thấy nhu cầu của người dùng đã chuyển từ tra cứu thông tin đơn thuần sang mong muốn được hỗ trợ chọn lọc địa điểm, cá nhân hóa gợi ý và xây dựng hành trình phù hợp với điều kiện thực tế.

Từ những vấn đề trên, cần xây dựng một công cụ có khả năng đồng thời lựa chọn và xếp hạng các địa điểm phù hợp với sở thích của người dùng, đồng thời phân bổ và sắp xếp các địa điểm theo số ngày, vị trí địa lý, khoảng cách di chuyển và giờ hoạt động. Việc kết hợp giữa gợi ý cá nhân hóa và tối ưu lịch trình có thể giúp giảm thời gian chuẩn bị, hạn chế các chặng di chuyển không cần thiết và nâng cao tính khả thi của chuyến đi.

Xuất phát từ cơ sở đó, đề tài “Xây dựng ứng dụng hỗ trợ người nước ngoài du lịch tại Việt Nam” được đề xuất nhằm phát triển ứng dụng HelloVietnam theo hướng thông minh và cá nhân hóa. Ứng dụng hướng đến khách du lịch tự túc tại Việt Nam, đặc biệt là khách nước ngoài, với các chức năng như tìm kiếm và khám phá địa điểm, gợi ý nội dung phù hợp với sở thích, tự động xây dựng lịch trình, hỗ trợ ngôn ngữ, cung cấp thông tin văn hóa và ẩm thực, nhận diện món ăn hoặc đồ vật bằng hình ảnh và kết nối du khách với người dân bản địa.

Thông qua đó, HelloVietnam góp phần giảm thời gian và công sức khi lập kế hoạch, nâng cao trải nghiệm của khách quốc tế, hỗ trợ quảng bá các giá trị văn hóa và du lịch địa phương, đồng thời phù hợp với định hướng chuyển đổi số và phát triển hệ sinh thái du lịch thông minh tại Việt Nam.

## **1.2.Mục tiêu và hướng tiếp cận**

*\[Nêu ba mục tiêu cốt lõi: (1) xây dựng hệ thống gợi ý địa điểm cá nhân hóa; (2) tự động phân bổ địa điểm vào các ngày và tối ưu lộ trình; (3) thiết kế giao diện thân thiện, dễ dùng trong quá trình di chuyển.\]*

*\[Trình bày hướng tiếp cận chính: ba module thuật toán (CB+CF, K-Means+Greedy, SA-TSPTW), stack kỹ thuật (Supabase, FastAPI, Flutter), và phạm vi dữ liệu (các tỉnh thành Việt Nam).\]*

Như đã trình bày ở phần 1.1, khách du lịch tự túc, đặc biệt là khách nước ngoài khi đến Việt Nam, thường gặp khó khăn trong việc tìm kiếm thông tin, lựa chọn địa điểm phù hợp và xây dựng lịch trình có tính khả thi. Xuất phát từ những vấn đề đó, ứng dụng HelloVietnam được xây dựng nhằm hỗ trợ người dùng trong quá trình khám phá địa điểm, lập kế hoạch và trải nghiệm du lịch tại Việt Nam.

Đề tài tập trung vào ba mục tiêu cốt lõi. **Thứ nhất,** xây dựng hệ thống gợi ý địa điểm cá nhân hóa dựa trên sở thích, ngân sách và hành vi tương tác của người dùng. **Thứ hai**, tự động phân bổ các địa điểm vào từng ngày và tối ưu thứ tự tham quan dựa trên vị trí địa lý, khoảng cách, thời gian di chuyển, giờ hoạt động và thời lượng tham quan. **Thứ ba,** thiết kế ứng dụng di động có giao diện trực quan, dễ thao tác và phù hợp với nhu cầu sử dụng trong quá trình di chuyển.

Để thực hiện các mục tiêu trên, hệ thống gợi ý lịch trình được tổ chức thành **ba module thuật toán liên kết với nhau.** Module đầu tiên kết hợp Content-Based Filtering và Collaborative Filtering để lựa chọn, tính điểm và xếp hạng các địa điểm phù hợp với từng người dùng. Module thứ hai sử dụng K-Means để phân cụm địa điểm theo số ngày du lịch, sau đó áp dụng Greedy Repair nhằm điều chỉnh số lượng địa điểm giữa các ngày. Module cuối cùng tiếp cận bài toán TSPTW và sử dụng Simulated Annealing để tối ưu thứ tự tham quan, có xét đến thời gian di chuyển, giờ mở cửa, thời gian chờ, thời lượng tham quan, thời gian nghỉ trưa và giới hạn kết thúc trong ngày.

**Về công nghệ triển khai,** ứng dụng sử dụng Flutter và Dart để xây dựng giao diện trên thiết bị di động; FastAPI và Python để phát triển các dịch vụ gợi ý, lập kế hoạch và tối ưu lịch trình; Supabase để quản lý cơ sở dữ liệu PostgreSQL, xác thực người dùng và cung cấp các API hoặc Edge Function hỗ trợ. Hệ thống cũng tích hợp OpenStreetMap và các dịch vụ định vị để hiển thị bản đồ, tìm kiếm địa điểm lân cận và hỗ trợ di chuyển.

Ngoài ra, HelloVietnam sử dụng Google ML Kit và DeepSeek để hỗ trợ dịch thuật, Gemini cho chức năng tìm kiếm bằng trí tuệ nhân tạo, Vbee cho chuyển văn bản thành giọng nói và Cloudflare R2 để lưu trữ hình ảnh, tệp đa phương tiện. Các dịch vụ bên ngoài được gọi thông qua backend hoặc Edge Function nhằm bảo vệ thông tin xác thực và chuẩn hóa dữ liệu trước khi trả về ứng dụng.

Phạm vi dữ liệu của đề tài tập trung vào các tỉnh, thành phố và địa điểm du lịch tại Việt Nam. Dữ liệu địa điểm bao gồm các thông tin cơ bản như tên, mô tả, danh mục, thẻ nội dung, tọa độ địa lý, mức giá, điểm đánh giá, giờ hoạt động và thời lượng tham quan dự kiến. Trước khi được sử dụng để gợi ý và lập lịch trình, dữ liệu được kiểm tra và lọc theo trạng thái hoạt động, mức ngân sách, chất lượng đánh giá và tính đầy đủ của thông tin vị trí.

# **Chương 2: CÁC HỆ THỐNG VÀ CÔNG NGHỆ LIÊN QUAN**

## **2.1.Các hệ thống hỗ trợ du lịch hiện có**

*\[Khảo sát và so sánh các ứng dụng lên lịch trình tự động hiện có (ví dụ: Google Travel, TripIt, Inspirock, TripHobo, các ứng dụng Việt Nam nếu có). Phân tích điểm mạnh và hạn chế của từng giải pháp theo các tiêu chí: gợi ý cá nhân hóa, tối ưu lộ trình, hỗ trợ offline, dữ liệu địa điểm Việt Nam. Từ đó chỉ ra khoảng trống mà HelloVietnam hướng đến.\]*

*Bảng 2.1.1: So sánh các ứng dụng hỗ trợ du lịch hiện có*

*\[\[Chèn bảng so sánh tại đây\]\]*

## **2.2.Các công nghệ và thuật toán được áp dụng**

*\[Tổng quan lý thuyết về các kỹ thuật nền tảng. Mỗi mục gồm: giới thiệu lý thuyết, công thức toán học cốt lõi (nếu có), ưu nhược điểm, và lý do liên quan đến bài toán này.\]*

### **2.2.1.Hệ thống gợi ý (Recommendation Systems)**

*\[Trình bày Content-Based Filtering: vector hóa thuộc tính địa điểm (tag, category), độ tương đồng cosine. So sánh với Collaborative Filtering (matrix factorization, WALS, implicit feedback). Giải thích công thức kết hợp explicit/implicit signals và cơ sở lý thuyết của trọng số w\_e, w\_i. Nêu bài toán cold start và cách tiếp cận trong HelloVietnam.\]*

Content-Based Filtering là một phương pháp gợi ý dựa trên đặc trưng của đối tượng và hồ sơ sở thích của người dùng. Ý tưởng chính của phương pháp này là hệ thống sẽ phân tích những đặc điểm mà người dùng quan tâm, sau đó tìm và đề xuất các đối tượng có đặc trưng tương tự.

Trong bài toán du lịch, đối tượng cần gợi ý có thể là địa điểm tham quan, nhà hàng, quán cà phê, hoạt động trải nghiệm hoặc sản phẩm địa phương. Mỗi đối tượng có thể được mô tả thông qua các đặc trưng như danh mục, tag, mô tả, mức giá, khu vực, thời lượng tham quan hoặc loại trải nghiệm. Trong khi đó, hồ sơ người dùng có thể được xây dựng từ sở thích ban đầu, lựa chọn trong chuyến đi hoặc hành vi tương tác của người dùng trong quá trình sử dụng hệ thống.

Quy trình chung của Content-Based Filtering gồm ba bước chính. Đầu tiên, hệ thống xây dựng hồ sơ sở thích của người dùng. Tiếp theo, hệ thống biểu diễn các đối tượng cần gợi ý bằng các đặc trưng nội dung. Cuối cùng, hệ thống so khớp hồ sơ người dùng với đặc trưng của từng đối tượng để xác định mức độ phù hợp và tạo ra danh sách gợi ý.

Phương pháp này phù hợp với các hệ thống gợi ý địa điểm du lịch vì không phụ thuộc quá nhiều vào dữ liệu hành vi của cộng đồng. Ngay cả khi người dùng mới chưa có nhiều lịch sử tương tác, hệ thống vẫn có thể đưa ra gợi ý dựa trên thông tin sở thích ban đầu và dữ liệu mô tả địa điểm. Ngoài ra, kết quả gợi ý cũng dễ giải thích hơn, vì hệ thống có thể cho biết một địa điểm được đề xuất do có các đặc trưng phù hợp với sở thích của người dùng.

Tuy nhiên, Content-Based Filtering cũng có một số hạn chế. Chất lượng gợi ý phụ thuộc nhiều vào chất lượng dữ liệu mô tả đối tượng. Nếu địa điểm bị thiếu tag, phân loại chưa chính xác hoặc mô tả chưa đầy đủ, kết quả gợi ý có thể bị ảnh hưởng. Bên cạnh đó, phương pháp này có thể có xu hướng đề xuất các đối tượng quá giống với sở thích đã biết của người dùng, làm giảm độ đa dạng trong danh sách gợi ý.

### **2.2.2.Tối ưu lộ trình – TSP với ràng buộc thời gian (TSPTW)**

*\[Định nghĩa bài toán TSPTW: tối thiểu tổng thời gian di chuyển với ràng buộc time window \[open\_i, close\_i\] cho mỗi địa điểm. Phân tích độ phức tạp NP-hard. Trình bày Simulated Annealing: cơ chế acceptance probability, lịch trình giảm nhiệt, neighborhood operator (2-opt swap). So sánh với Brute Force (optimal nhưng O(n\!)) và Genetic Algorithm.\]*

### **2.2.3.Công nghệ phát triển hệ thống**

*\[Giới thiệu ngắn gọn: Supabase (PostgreSQL \+ PostgREST \+ Auth), FastAPI (async Python microservice), Flutter (cross-platform mobile \+ web), OpenStreetMap/flutter\_map. Nêu lý do lựa chọn từng công nghệ.\]*

# **Chương 3: ỨNG DỤNG HELLOVIETNAM**

## **3.1. Kiến trúc hệ thống** {#3.1.kiến-trúc-hệ-thống}

HelloVietnam được xây dựng theo kiến trúc phân lớp nhằm tách giao diện, xử lý nghiệp vụ, thuật toán và dữ liệu. Mỗi lớp đảm nhận một nhóm trách nhiệm rõ ràng và chỉ trao đổi với lớp khác thông qua giao diện đã xác định. Cách tổ chức này giúp giảm phụ thuộc giữa các thành phần, thuận tiện khi kiểm thử và cho phép nâng cấp dịch vụ thuật toán hoặc dịch vụ bên ngoài mà không phải thay đổi toàn bộ ứng dụng.

*Hình 3.1.1: Sơ đồ kiến trúc hệ thống HelloVietnam*

![Sơ đồ kiến trúc hệ thống HelloVietnam](report-assets/system-architecture-final.png)

Các khối trong Hình 3.1.1 và mục đích của chúng được tóm tắt như sau:

| Lớp/khối | Công nghệ chính | Mục đích |
|---|---|---|
| Lớp giao diện | Flutter, Dart, GoRouter | Hiển thị giao diện Android/Web, tiếp nhận thao tác và điều hướng giữa các màn hình |
| Xác thực và backend | Supabase Auth, Edge Functions, PostgREST, RPC | Xác thực người dùng, kiểm tra quyền, xử lý nghiệp vụ và cung cấp giao diện truy cập dữ liệu |
| Dịch vụ thuật toán | FastAPI, Python, scikit-learn | Cá nhân hóa gợi ý, phân cụm địa điểm và tối ưu lịch trình |
| Lớp dữ liệu | PostgreSQL, RLS | Lưu trữ dữ liệu quan hệ và giới hạn quyền truy cập theo người dùng |
| Lưu trữ và dịch vụ ngoài | Cloudflare R2, Firebase FCM, DeepSeek/Gemini, Vbee, OpenStreetMap, Stripe, API tỷ giá | Lưu media, gửi thông báo, cung cấp AI, giọng nói, bản đồ, thanh toán và tỷ giá |

**Lớp giao diện.** Frontend được phát triển bằng Flutter và Dart. Mã nguồn có hai điểm khởi chạy: ứng dụng người dùng trên Android/Flutter Web và trang quản trị trên Flutter Web. Ứng dụng người dùng cung cấp các chức năng xác thực, khám phá nội dung du lịch, wishlist, diễn đàn, dịch thuật, nhận dạng bằng AI, loyalty, thanh toán gói Premium và lập lịch trình. Trang quản trị phục vụ quản lý người dùng, báo cáo và dữ liệu du lịch. GoRouter ánh xạ URL hoặc đường dẫn sâu đến màn hình tương ứng; nhờ đó ứng dụng có thể xử lý điều hướng nội bộ và mở đúng màn hình khi người dùng nhấn vào liên kết hoặc thông báo. Mã nguồn được tổ chức theo từng feature; lớp repository thực hiện truy cập dữ liệu, store quản lý trạng thái và lớp giao diện chịu trách nhiệm hiển thị, tiếp nhận thao tác từ người dùng.

**Lớp xác thực và backend.** Supabase Auth thực hiện đăng ký, đăng nhập bằng email hoặc Google OAuth và cấp JSON Web Token (JWT) cho phiên người dùng. JWT là token có chữ ký số để backend kiểm tra danh tính và tính toàn vẹn; token không được xem là dữ liệu đã mã hóa. Trong quá trình truyền, HTTPS/TLS bảo vệ token và nội dung yêu cầu khỏi bị đọc hoặc sửa đổi trên đường truyền. Với các thao tác dữ liệu đơn giản thuộc phạm vi người dùng, Flutter có thể gọi PostgREST hoặc RPC của Supabase bằng khóa công khai và JWT. Row Level Security (RLS) tại PostgreSQL kiểm tra định danh trong JWT để chỉ cho phép người dùng đọc hoặc thay đổi các bản ghi thuộc quyền của mình.

Các nghiệp vụ cần phối hợp nhiều bước, kiểm tra quyền quản trị hoặc sử dụng thông tin xác thực riêng của dịch vụ bên ngoài được đặt trong Supabase Edge Functions. Ví dụ, `wishlist` xử lý danh sách yêu thích, `media-upload` tiếp nhận và tải tệp lên R2, `subscription-payment` làm việc với Stripe, còn `translate`, `currency-rates` và `ai-search` tích hợp các dịch vụ AI hoặc dữ liệu ngoài. Đối với function yêu cầu đăng nhập, backend nhận JWT từ tiêu đề `Authorization`, xác định người dùng hiện tại, kiểm tra dữ liệu đầu vào và quyền thực hiện trước khi truy cập dữ liệu hoặc gọi nhà cung cấp bên ngoài.

Các thông tin xác thực nhạy cảm của hệ thống gồm **khóa API, access token, service role key, chuỗi kết nối cơ sở dữ liệu và khóa truy cập R2**. Nếu bị lộ, các giá trị này có thể bị lợi dụng để sử dụng dịch vụ trả phí, thay đổi tệp hoặc truy cập dữ liệu với quyền cao. Vì vậy, chúng chỉ được lưu trong Supabase Secrets hoặc biến môi trường phía máy chủ, không được đưa vào mã Flutter. Ứng dụng phía người dùng chỉ chứa URL dịch vụ và khóa công khai do Supabase thiết kế cho client; quyền truy cập dữ liệu vẫn được kiểm soát bằng JWT và chính sách RLS.

**Lớp xử lý thuật toán.** Dịch vụ FastAPI Trip & Recommend Service được viết bằng Python để sử dụng các thư viện xử lý dữ liệu và thuật toán như scikit-learn. Flutter không gọi trực tiếp dịch vụ này. Khi người dùng tạo lịch trình hoặc yêu cầu gợi ý, ứng dụng gọi Edge Function `trip-planner` hoặc `recommend`; Edge Function xác thực yêu cầu rồi chuyển tiếp dữ liệu hợp lệ qua HTTP đến FastAPI. FastAPI thực hiện tính điểm gợi ý, phân cụm địa điểm theo ngày và tối ưu thứ tự tham quan, sau đó trả kết quả về Edge Function để chuyển lại cho ứng dụng. Cách bố trí này giữ URL nội bộ, khóa dịch vụ và thông tin kết nối cơ sở dữ liệu khỏi mã phía người dùng, đồng thời tạo một điểm kiểm soát quyền trước khi chạy thuật toán.

FastAPI sử dụng hai cơ chế truy cập dữ liệu. Các luồng lập lịch trình và gợi ý thông thường dùng thư viện `supabase-py` với service role key ở phía máy chủ. Service role có quyền cao và bỏ qua RLS, do đó dịch vụ phải tự kiểm tra định danh, quyền sở hữu và tham số truy vấn; khóa này tuyệt đối không được đưa vào Flutter. Tác vụ huấn luyện lại Collaborative Filtering chạy theo lô sử dụng `asyncpg` và `DATABASE_URL` để kết nối trực tiếp PostgreSQL. Kết nối trực tiếp cũng không dựa vào RLS của phiên người dùng, nhưng phù hợp với truy vấn tổng hợp có khối lượng lớn trong một tiến trình backend được kiểm soát.

**Lớp dữ liệu.** PostgreSQL do Supabase quản lý lưu dữ liệu tài khoản, nội dung du lịch, lịch trình, diễn đàn, wishlist, đánh giá, thanh toán, loyalty và thông báo. UUID được sử dụng làm khóa chính. Các trường `jsonb` chỉ dành cho dữ liệu có cấu trúc linh hoạt như gallery hoặc metadata; các quan hệ nghiệp vụ chính vẫn được thể hiện bằng khóa ngoại, ràng buộc `unique`, `check` và chỉ mục. Những truy vấn danh sách lớn như diễn đàn, wishlist và bảng quản trị được phân trang để tránh tải toàn bộ dữ liệu trong một lần.

**Lớp lưu trữ và tích hợp bên ngoài.** Cloudflare R2 lưu hình ảnh và tệp đa phương tiện; cơ sở dữ liệu chỉ lưu URL và metadata. OpenStreetMap cung cấp dữ liệu bản đồ; DeepSeek/Gemini hỗ trợ dịch và tìm kiếm AI; Vbee chuyển văn bản thành giọng nói; Stripe xử lý thanh toán; API tỷ giá cung cấp tỷ giá tiền tệ. Firebase Cloud Messaging đã được tích hợp để gửi thông báo Android. Khi có thông báo cần đẩy, backend lưu bản ghi trong PostgreSQL, Edge Function gửi nội dung qua FCM, thiết bị nhận thông báo và sử dụng dữ liệu điều hướng để mở màn hình liên quan khi người dùng nhấn vào.

Về khả năng chịu lỗi, frontend hiển thị trạng thái tải, lỗi và nút thử lại thay vì chờ vô hạn. Các dữ liệu tham chiếu ít thay đổi được lưu đệm tại ứng dụng; các danh sách lớn chỉ lấy từng trang và tải trang kế tiếp khi cần. Các dịch vụ trả phí và dịch vụ thuật toán được gọi qua backend, nhờ đó hệ thống có thể kiểm soát đầu vào, giới hạn tần suất, ghi log và thay đổi nhà cung cấp mà không làm lộ khóa truy cập.

## **3.2. Thuật toán gợi ý và tối ưu lịch trình**

Quy trình xây dựng lịch trình nhận các thông tin gồm tỉnh/thành phố hoặc vị trí xuất phát, ngày bắt đầu, ngày kết thúc, nhịp độ tham quan và sở thích của chuyến đi. Dữ liệu được xử lý qua ba module liên tiếp. Module 1 xếp hạng và chọn tập địa điểm phù hợp; Module 2 phân các địa điểm theo từng ngày dựa trên vị trí và tải tham quan; Module 3 tối ưu thứ tự ghé thăm trong từng ngày, đồng thời tạo mốc thời gian cụ thể. Kết quả cuối cùng là lịch trình có ngày, thứ tự, thời gian di chuyển, thời gian tham quan và cảnh báo ràng buộc.

### **3.2.1. Module 1 – Gợi ý và chọn địa điểm**

Module 1 tạo danh sách ứng viên phù hợp với người dùng. Đầu vào gồm hồ sơ sở thích dài hạn, sở thích riêng của chuyến đi, lịch sử hành vi, các địa điểm thuộc khu vực đã chọn và tập tag của từng địa điểm. Hồ sơ dài hạn được khởi tạo từ lựa chọn onboarding và được điều chỉnh bởi implicit feedback. Ví dụ, xem chi tiết làm tăng nhẹ trọng số liên quan, lưu yêu thích hoặc thêm vào chuyến đi làm tăng mạnh hơn, còn bỏ yêu thích hoặc đánh giá thấp làm giảm trọng số.

Khi người dùng chọn sở thích cho chuyến đi hiện tại, hệ thống kết hợp hai nguồn theo công thức:

$$
w_{eff}(u,t)=0.4\,w_{profile}(u,t)+0.6\,w_{trip}(t)
$$

Trong đó, \(w_{profile}(u,t)\) là trọng số tag \(t\) trong hồ sơ dài hạn của người dùng \(u\), \(w_{trip}(t)\) là trọng số của tag trong chuyến đi hiện tại và \(w_{eff}(u,t)\) là trọng số hiệu lực sau khi chuẩn hóa. Nếu người dùng không chọn sở thích riêng cho chuyến đi, hệ thống sử dụng hoàn toàn hồ sơ dài hạn.

Mỗi quan hệ giữa địa điểm và tag có độ tin cậy \(c(i,t)\). Điểm phù hợp dựa trên nội dung được tính bằng:

$$
TagMatch(u,i)=
\frac{\sum_{t \in T_i}w_{eff}(u,t)\,c(i,t)}
{\sum_{t \in T_u}w_{eff}(u,t)}
$$

Trong đó, \(T_i\) là tập tag của địa điểm \(i\), còn \(T_u\) là tập tag có trọng số trong hồ sơ hiệu lực. Phép chia cho tổng trọng số giúp điểm nằm trên cùng thang đo khi số lượng sở thích giữa các người dùng khác nhau.

Hệ thống tiếp tục kết hợp điểm Content-Based (CB) với điểm Collaborative Filtering (CF):

$$
FinalScore(u,i)=\alpha\,TagMatch(u,i)+(1-\alpha)\,CF(u,i)
$$

Hệ số \(\alpha\) thay đổi theo độ bao phủ của dữ liệu CF. Khi chưa có điểm CF, \(\alpha=1\) để dùng hoàn toàn CB. Khi độ bao phủ CF nhỏ hơn 10%, \(\alpha=0.7\); từ 10% đến dưới 30%, \(\alpha=0.5\); từ 30% trở lên, \(\alpha=0.3\). Cơ chế này xử lý cold-start: người dùng mới vẫn nhận được kết quả từ sở thích đã chọn, còn người dùng có đủ lịch sử sẽ nhận kết quả chịu ảnh hưởng nhiều hơn từ hành vi cộng đồng.

Sau khi sắp xếp theo `FinalScore`, hệ thống dùng điểm đánh giá trung bình và số lượt đánh giá làm tiêu chí phụ. Bước đa dạng hóa giới hạn việc một nhóm địa điểm hoặc một subcategory chiếm toàn bộ vị trí đầu. Đầu ra của Module 1 là tập ứng viên đã xếp hạng và đa dạng hóa để chuyển sang Module 2, chưa phải lịch trình cuối cùng.

### **3.2.2. Module 2 – Phân cụm địa điểm theo ngày**

Module 2 phân tập ứng viên thành các nhóm theo ngày sao cho địa điểm trong cùng ngày tương đối gần nhau và khối lượng tham quan phù hợp với nhịp độ người dùng. Trước khi phân cụm, các bản ghi thiếu tọa độ hợp lệ hoặc thiếu điểm Module 1 bị loại và ghi nhận lý do. Số ứng viên tối đa được tính theo:

$$
candidate\_limit=D \times 8
$$

Trong đó, \(D\) là số ngày của chuyến đi và 8 là số ứng viên dự phòng cho mỗi ngày. Ví dụ, chuyến đi 3 ngày đưa tối đa 24 địa điểm có thứ hạng cao vào bước phân cụm. Số lượng này lớn hơn số điểm ghé thăm thực tế để còn phương án thay thế khi cân bằng lịch trình.

Mỗi địa điểm \(i\) được biểu diễn bởi vector tọa độ:

$$
x_i=(latitude_i,longitude_i)
$$

Số cụm được chọn là \(k=\min(D,N)\), với \(N\) là số ứng viên có tọa độ hợp lệ. K-Means sử dụng `random_state=42` và `n_init=10` để kết quả có thể lặp lại giữa các lần chạy. Khoảng cách Euclid trên cặp tọa độ được dùng để tạo cụm ban đầu trong phạm vi một tỉnh/thành phố. Sau đó, khoảng cách Haversine được dùng khi đánh giá khoảng cách thực theo kilômét giữa địa điểm và tâm cụm.

Kết quả K-Means chưa xét đầy đủ số địa điểm và thời lượng của từng ngày. Vì vậy, hệ thống áp dụng Greedy Repair. Giới hạn được xác định theo nhịp độ: mức `easy` có mục tiêu 3 địa điểm/ngày, `balanced` là 4, còn `active` và `packed` là 5; mỗi mức có giới hạn tối thiểu và tối đa tương ứng. Trong từng cụm, địa điểm được ưu tiên theo điểm Module 1, điểm đánh giá và số lượt đánh giá. Các mục đầu tiên tạo thành `primary_places`, phần còn lại được đưa vào `backup_places`.

Greedy Repair lần lượt xử lý ngày thiếu, ngày quá nhiều địa điểm và ngày có tổng thời lượng quá cao. Với ngày thiếu, thuật toán chọn địa điểm từ danh sách dự phòng hoặc từ ngày khác nếu địa điểm đó còn nằm trong ngưỡng khoảng cách tới tâm cụm và không làm vượt giới hạn. Với ngày quá tải, thuật toán ưu tiên chuyển địa điểm sang ngày phù hợp khác; nếu không thể chuyển, địa điểm thứ hạng cao được giữ trong `optional_places`, còn địa điểm thứ hạng thấp hơn chuyển về `backup_places`. Mọi thao tác điều chỉnh được ghi trong `repair_logs` để có thể kiểm tra kết quả.

Đầu ra của Module 2 là danh sách các cụm ngày, mỗi cụm có ngày, tâm cụm, các địa điểm chính, tổng thời lượng dự kiến và cảnh báo. Các địa điểm dự phòng và tùy chọn được giữ lại để frontend có thể đề xuất thay thế khi cần.

### **3.2.3. Module 3 – Tối ưu lộ trình trong ngày (SA-TSPTW)**

Module 3 nhận từng nhóm địa điểm của Module 2 và tìm thứ tự ghé thăm phù hợp. Bài toán được mô hình hóa theo hướng Traveling Salesman Problem with Time Windows (TSPTW): ngoài việc giảm thời gian di chuyển, mỗi địa điểm còn có giờ mở cửa, giờ đóng cửa và thời lượng tham quan. Hệ thống cũng xét thời gian chờ, giờ nghỉ trưa và giới hạn kết thúc ngày.

Để tạo nghiệm ban đầu nhanh, thuật toán Greedy Nearest-Neighbour bắt đầu từ vị trí xuất phát và liên tục chọn địa điểm chưa ghé gần nhất theo khoảng cách Haversine. Nghiệm này có chi phí thấp hơn một thứ tự ngẫu nhiên và được dùng làm điểm bắt đầu cho Simulated Annealing (SA).

Hàm mục tiêu đánh giá một thứ tự \(R\) như sau:

$$
Cost(R)=Travel(R)+Wait(R)+Lunch(R)
+1000\,Violation(R)+1500\,Dropped(R)
$$

`Travel` là tổng thời gian di chuyển, `Wait` là thời gian phải chờ địa điểm mở cửa, `Lunch` là thời gian nghỉ trưa phát sinh trong lịch, `Violation` là số lần thời điểm kết thúc tham quan vượt giờ đóng cửa và `Dropped` là số địa điểm có thời điểm kết thúc dự kiến sau 20:00. Hệ số phạt lớn khiến thuật toán ưu tiên lịch trình khả thi thay vì chỉ tối thiểu hóa quãng đường.

Từ nghiệm hiện tại, SA sinh nghiệm lân cận bằng một trong ba phép biến đổi: đổi chỗ hai địa điểm, đảo ngược một đoạn hoặc lấy một địa điểm chèn sang vị trí khác. Nghiệm tốt hơn luôn được chấp nhận. Nghiệm xấu hơn có thể được chấp nhận với xác suất:

$$
P=\exp\left(-\frac{\Delta Cost}{T}\right)
$$

Khả năng chấp nhận nghiệm xấu ở nhiệt độ cao giúp thuật toán thoát khỏi cực tiểu cục bộ. Cấu hình hiện tại sử dụng \(T_0=1.0\), \(T_{min}=0.0001\), hệ số giảm nhiệt \(0.9\) và \(12n\) lần thử tại mỗi mức nhiệt, với \(n\) là số địa điểm trong ngày. Dịch vụ có thể chạy SA nhiều lần với seed khác nhau rồi chọn nghiệm có chi phí thấp nhất.

Sau khi chọn thứ tự tốt nhất, bộ dựng lịch bắt đầu ngày lúc 08:00, thêm thời gian đệm 15 phút giữa các điểm, ước lượng di chuyển với tốc độ trung bình 30 km/h và chèn 90 phút nghỉ trưa từ 12:00 khi phù hợp. Thời lượng mặc định là 60 phút nếu địa điểm chưa có dữ liệu. Địa điểm kết thúc sau giờ đóng cửa được gắn cảnh báo; địa điểm dự kiến kết thúc sau 20:00 bị loại khỏi lịch chính. Kết quả trả về gồm danh sách theo thời gian, tổng thời gian di chuyển, tổng thời gian chờ, số vi phạm và số địa điểm bị loại.

Module 3 hiện sử dụng Greedy Nearest-Neighbour kết hợp Simulated Annealing cho mọi ngày có từ hai địa điểm trở lên; hệ thống không có nhánh Brute Force. Vì vậy, báo cáo không đặt ngưỡng chuyển đổi giữa Brute Force và SA. Cách triển khai này phù hợp với số lượng địa điểm mỗi ngày đã được Module 2 giới hạn, đồng thời tránh chi phí giai thừa của vét cạn.

## **3.3.Thiết kế các thành phần**

### **3.3.1.Dữ liệu**

Dữ liệu của HelloVietnam được tổ chức thành hai nhóm chính: dữ liệu nội dung du lịch và dữ liệu phát sinh trong quá trình người dùng sử dụng hệ thống. Dữ liệu nội dung gồm tỉnh/thành phố, địa điểm, món ăn, hoạt động, văn hóa và sản phẩm địa phương. Các bản ghi được tổng hợp từ nguồn công khai, sau đó chuẩn hóa tên, mô tả, tọa độ, hình ảnh, mức giá, thời gian hoạt động và thông tin đánh giá trước khi đưa vào hệ thống.

Để phù hợp với dữ liệu địa giới hành chính hiện hành, bảng trung tâm được sử dụng là `province`. Các bảng `place`, `activity`, `culture` và `local_products` tham chiếu đến `province` thông qua khóa ngoại `id_province`. Bảng `place_subcategory` dùng để phân loại chi tiết địa điểm; cặp bảng `tag` và `place_tag` mô tả các thuộc tính như văn hóa, thiên nhiên, ẩm thực hoặc mua sắm. Trong lịch sử migration, một số đoạn mã cũ còn sử dụng tên `city_province`; đây là tên legacy và không phải tên bảng được ứng dụng hiện tại sử dụng.

Dữ liệu cá nhân hóa được lưu trong các bảng `user_travel_profile`, `user_interest_tag`, `user_location_preference` và `user_event_log`. Trong đó, `user_event_log` ghi nhận các tín hiệu ngầm như xem chi tiết, tìm kiếm, lưu yêu thích hoặc tương tác với nội dung. Những dữ liệu này được dùng để điều chỉnh điểm gợi ý thay vì yêu cầu người dùng nhập lại sở thích trong mỗi lần tạo lịch trình.

Kết quả tạo lịch trình được lưu theo mô hình master-detail. Bảng `plan` lưu thông tin chung của chuyến đi, còn `plan_component` lưu từng thành phần theo ngày, thứ tự và địa điểm. Cấu trúc này cho phép tải riêng từng lịch trình, cập nhật trạng thái và tiếp tục chuyến đi mà không phải lưu toàn bộ kết quả vào một trường văn bản lớn.

Các trường có cấu trúc linh hoạt như bộ sưu tập ảnh, giờ mở cửa hoặc metadata được lưu bằng `jsonb`. Khóa chính sử dụng UUID để hạn chế xung đột khi dữ liệu được tạo từ nhiều dịch vụ. Báo cáo không cố định số lượng bản ghi vì dữ liệu trên môi trường Supabase tiếp tục được bổ sung trong quá trình vận hành; quy mô tại thời điểm nghiệm thu có thể lấy trực tiếp bằng truy vấn thống kê trên cơ sở dữ liệu triển khai.

### **3.3.2.Sơ đồ use-case**

*\[Liệt kê các tác nhân (người dùng chưa đăng nhập, người dùng đã đăng nhập, admin) và các use-case tương ứng. Chèn sơ đồ use-case tổng quát và đặc tả chi tiết cho các use-case chính (Tạo lịch trình, Xem lịch trình đang đi, Khám phá địa điểm, Nhận dạng địa điểm bằng AI, v.v.).\]*

*Hình 3.3.2.1: Sơ đồ use-case tổng quát*

*\[\[Chèn bảng đặc tả use-case chi tiết cho từng chức năng\]\]*

### **3.3.3.Lược đồ cơ sở dữ liệu**

HelloVietnam sử dụng PostgreSQL do Supabase quản lý. Lược đồ đầy đủ gồm nhiều bảng phục vụ nội dung du lịch, cá nhân hóa, diễn đàn, đánh giá, wishlist, thanh toán và loyalty. Để sơ đồ trong báo cáo có thể đọc được khi in, Hình 3.3.3.1 trình bày các thực thể cốt lõi và quan hệ quan trọng; ảnh Schema Visualizer đầy đủ của môi trường triển khai được dùng làm minh chứng bổ sung trong phụ lục.

| Nhóm nghiệp vụ | Các bảng tiêu biểu |
|---|---|
| Tài khoản và cá nhân hóa | `user_account`, `user_setting`, `user_contact`, `user_accessibility`, `user_travel_profile`, `user_onboarding_choice`, `user_location_preference`, `user_interest_tag` |
| Nội dung du lịch | `province`, `place`, `place_subcategory`, `food`, `activity`, `culture`, `local_products`, `tag`, `place_tag` |
| Gợi ý và lập lịch trình | `user_event_log`, `plan`, `plan_component`, `cf_score_cache`, `cf_retrain_log` |
| Diễn đàn và báo cáo | `forum_post`, `forum_comment`, `forum_post_media`, `forum_post_like`, `forum_post_bookmark`, `forum_user_follow`, `report`, `notification` |
| Subscription và loyalty | `subscription_plan`, `premium_subscription`, `payment`, `user_loyalty_account`, `loyalty_transaction`, `voucher_config`, `voucher_wallet` |
| Đánh giá và wishlist | `reviews`, `rating_summary`, `favorite_place`, `favorite_food`, `favorite_city`, `favorite_activity`, `favorite_culture`, `favorite_local_product` |

`user_account` là thực thể trung tâm của dữ liệu người dùng và được liên kết với tài khoản Supabase Auth bằng UUID. Các chính sách Row Level Security (RLS) sử dụng định danh từ phiên đăng nhập để người dùng chỉ đọc hoặc thay đổi dữ liệu thuộc quyền sở hữu của mình. Các thao tác cần quyền cao hơn, chẳng hạn quản trị nội dung hoặc xác nhận thanh toán, được thực hiện qua Edge Function và khóa dịch vụ chỉ tồn tại ở phía máy chủ.

Trong nhóm nội dung, `province` có quan hệ một-nhiều với `place`, `activity`, `culture` và `local_products`. `place_subcategory` chuẩn hóa loại địa điểm để tránh lặp chuỗi phân loại trong từng bản ghi. Quan hệ nhiều-nhiều giữa địa điểm và thẻ sở thích được biểu diễn bằng bảng nối `place_tag`, nhờ đó một địa điểm có thể đồng thời thuộc nhiều nhóm sở thích.

`user_event_log` lưu implicit feedback theo người dùng, loại sự kiện, loại nội dung, định danh nội dung và thời điểm phát sinh. Dữ liệu này hỗ trợ tính điểm cá nhân hóa và có chỉ mục theo người dùng, loại sự kiện và thời gian để giảm chi phí truy vấn. Kết quả lập lịch trình dùng cặp bảng `plan` và `plan_component`: một `plan` có nhiều `plan_component`, mỗi thành phần tham chiếu đến địa điểm và lưu ngày cùng thứ tự tham quan.

Wishlist được thiết kế bằng các bảng yêu thích có kiểu rõ ràng thay vì một trường `target_type` duy nhất. Cách này giữ được khóa ngoại tới từng bảng nội dung và tránh tham chiếu đến bản ghi không tồn tại. Với đánh giá, bảng `reviews` dùng cặp `content_type` và `content_id` để hỗ trợ nhiều loại nội dung, còn `rating_summary` lưu số liệu tổng hợp nhằm tránh tính lại toàn bộ đánh giá trong mỗi lần tải danh sách.

Nhóm subscription lưu tách biệt danh mục gói (`subscription_plan`), trạng thái gói của người dùng (`premium_subscription`) và lịch sử giao dịch (`payment`). Loyalty cũng tách số dư hiện tại khỏi sổ giao dịch bằng `user_loyalty_account` và `loyalty_transaction`; voucher đã đổi được lưu trong `voucher_wallet`. Thiết kế này hỗ trợ kiểm toán thay đổi điểm và thanh toán thay vì chỉ ghi đè một giá trị cuối cùng.

Các ràng buộc khóa chính, khóa ngoại, `unique`, `check`, RLS và chỉ mục được khai báo trong migration. Những trường thường dùng để lọc hoặc phân trang như `created_at`, `id_user`, `status`, `id_province` và điểm đánh giá được lập chỉ mục. Việc thay đổi lược đồ được quản lý bằng các tệp migration có đánh số phiên bản để môi trường local và Supabase production có thể đồng bộ.

*Hình 3.3.3.1: Lược đồ cơ sở dữ liệu*

![Lược đồ cơ sở dữ liệu cốt lõi của HelloVietnam](report-assets/database-core-erd.png)

## 

## **Chương 4: CÀI ĐẶT VÀ ĐÁNH GIÁ** {#chương-4:-cài-đặt-và-đánh-giá}

## **4.1.Hướng dẫn cài đặt**

Quy trình cài đặt được chia thành hai trường hợp: cài ứng dụng để sử dụng và cài môi trường phát triển. Với người dùng cuối, ứng dụng Android được cung cấp dưới dạng APK. Thiết bị nên sử dụng Android 8.0 trở lên, còn ít nhất 300 MB dung lượng trống và có kết nối Internet cho các chức năng đồng bộ, diễn đàn, thanh toán, AI và tải ảnh. Sau khi nhận APK từ nguồn phát hành của nhóm, người dùng cho phép cài ứng dụng từ nguồn đã chọn, mở tệp APK và hoàn tất quá trình cài đặt. Trang quản trị được sử dụng trên trình duyệt Chrome hoặc Edge ở độ phân giải máy tính.

Đối với máy phát triển, các thành phần cần thiết gồm Flutter 3.38.9 trở lên, Dart 3.10.8 trở lên, JDK 17, Android Studio cùng Android SDK, Node.js/npm và Python 3.11. Sau khi tải mã nguồn, cài dependency và kiểm tra môi trường Flutter bằng các lệnh:

```powershell
cd frontend
flutter doctor
flutter pub get
flutter analyze
flutter test
```

Trong Visual Studio Code, cấu hình `User` chạy Flutter Web tại cổng 3000, còn cấu hình `Admin` chạy entrypoint quản trị tại cổng 3001. Khi kiểm thử trên điện thoại, bật Developer options và USB debugging, kết nối thiết bị, chạy `flutter devices`, sau đó dùng `flutter run -d <device-id>`.

Backend Supabase được liên kết và đồng bộ migration bằng Supabase CLI:

```powershell
cd backend
npx supabase login
npx supabase link --project-ref <PROJECT_REF>
npx supabase db push --include-all
```

Các khóa bí mật của DeepSeek, Gemini, Vbee, Stripe, Cloudflare R2 và service role phải được thiết lập bằng `npx supabase secrets set ...`; tuyệt đối không đưa vào mã Flutter hoặc Git. Sau khi thiết lập secret, triển khai các Edge Function bằng `npx supabase functions deploy` hoặc triển khai riêng từng function, ví dụ `npx supabase functions deploy trip-planner`. Flutter chỉ chứa URL công khai, Supabase publishable/anon key và các giá trị cấu hình không bí mật.

Dịch vụ tối ưu lịch trình chạy bằng FastAPI trong thư mục `cf_service`. Tạo tệp `.env` cục bộ với `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` và `DATABASE_URL`, sau đó thực hiện:

```powershell
cd cf_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Kiểm tra dịch vụ qua endpoint `/health`, triển khai dịch vụ lên host có HTTPS và đặt URL đó vào secret `CF_SERVICE_URL` của Supabase. Tunnel tạm chỉ phù hợp để phát triển vì URL thay đổi và phụ thuộc vào máy cá nhân đang hoạt động.

Để tạo bản cài thử nghiệm, chạy `flutter build apk --debug`; tệp kết quả nằm tại `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Bản Web được tạo bằng `flutter build web`. Trước khi phát hành chính thức, dự án cần cấu hình keystore release riêng vì cấu hình Android hiện tại vẫn dùng khóa debug cho build release.

*Hình 4.1.1: Quy trình cài đặt và triển khai hệ thống*

![Quy trình cài đặt và triển khai HelloVietnam](report-assets/installation-flow.png)

## **4.2.Cài đặt các màn hình**

Các màn hình phía người dùng được xây dựng bằng Flutter theo từng feature và điều hướng bằng GoRouter. Luồng xác thực gồm đăng ký, đăng nhập bằng email hoặc Google và onboarding để thu thập lựa chọn ban đầu. Sau khi xác thực, trang chủ hiển thị nội dung nổi bật lấy từ Supabase, cho phép tìm kiếm, khám phá, mở chi tiết nội dung và thêm vào wishlist.

Trip Planner được triển khai dưới dạng wizard nhiều bước. Người dùng lần lượt chọn điểm đến, thời lượng, ngân sách và sở thích; dữ liệu của các bước được giữ trong trạng thái wizard và chỉ gửi sang backend khi đủ thông tin. Kết quả trả về được trình bày theo từng ngày, có thể xem trên bản đồ, lưu vào tài khoản và mở lại trong danh sách chuyến đi.

Wishlist đọc dữ liệu từ các bảng yêu thích tương ứng với từng loại nội dung và tải theo trang để giảm thời gian chờ. Forum cũng sử dụng phân trang theo cursor và lazy loading: màn hình tải một lô bài viết đầu tiên, sau đó lấy lô tiếp theo khi người dùng cuộn gần cuối danh sách. Các tương tác thích, bình luận, lưu bài và theo dõi được đồng bộ với cơ sở dữ liệu.

Màn hình Translate hỗ trợ dịch offline bằng mô hình trên thiết bị và dịch online qua Edge Function. Người dùng nhập xong rồi bấm nút xác nhận; hệ thống mới gửi yêu cầu dịch và chuẩn bị audio Vbee nếu đang ở chế độ online, tránh gọi API liên tục khi đang gõ. Profile tập trung các tùy chọn tài khoản, tiền tệ, giao diện sáng/tối, loyalty và subscription. Tỷ giá được lấy qua backend và có cache/fallback để không chặn toàn bộ giao diện khi dịch vụ ngoài phản hồi chậm.

Trang quản trị sử dụng entrypoint Web riêng nhưng tái sử dụng các thành phần chung của ứng dụng. Admin có thể quản lý người dùng, báo cáo, món ăn, tỉnh/thành phố, địa điểm, hoạt động, văn hóa và sản phẩm địa phương. Danh sách quản trị được phân trang phía server, có trạng thái loading/error/empty rõ ràng và chỉ tải số bản ghi cần cho trang hiện tại.

Các hình giao diện nên được sắp theo cùng một kích thước và thứ tự sau:

| Số hình | Nội dung đề xuất |
|---|---|
| Hình 4.2.1 | Đăng nhập và onboarding |
| Hình 4.2.2 | Trang chủ và Explore |
| Hình 4.2.3 | Chi tiết địa điểm và thao tác thêm Wishlist |
| Hình 4.2.4 | Các bước nhập thông tin Trip Planner |
| Hình 4.2.5 | Kết quả lịch trình theo ngày và bản đồ |
| Hình 4.2.6 | Forum và chi tiết bài viết |
| Hình 4.2.7 | Translate ở chế độ online/offline |
| Hình 4.2.8 | Profile, Loyalty Rewards và Subscription |
| Hình 4.2.9 | Admin Dashboard và một màn hình quản lý dữ liệu |

Khi chụp hình, giao diện mobile nên đặt cùng viewport (ví dụ 400 × 800), giao diện admin nên dùng cùng độ phân giải desktop (ví dụ 1440 × 900), ẩn DevTools và che email, token hoặc dữ liệu cá nhân. Mỗi hình cần có chú thích ngắn mô tả thao tác chính thay vì chỉ ghi tên màn hình.

*Các ảnh chụp giao diện thực tế được bổ sung theo danh sách trên tại thời điểm hoàn thiện bản Word để bảo đảm phản ánh đúng phiên bản ứng dụng dùng trong buổi nghiệm thu.*

## **4.3.Đánh giá hiệu năng**

*\[Đo thời gian phản hồi API cho các endpoint chính (tạo lịch trình, gợi ý địa điểm, CF retrain). So sánh thời gian SA vs Brute Force theo số lượng địa điểm (n). Nêu điều kiện môi trường kiểm thử.\]*

*Hình 4.3.1: Thời gian phản hồi trung bình của API*

*\[\[Chèn biểu đồ hoặc bảng thời gian phản hồi\]\]*

## **4.4.Đánh giá thuật toán**

*\[Đánh giá Module 1 (gợi ý): sử dụng Precision@K, Recall@K, F1-score. Mô tả phương pháp: tập dữ liệu test, cách tính ground truth, kết quả theo từng tỉnh/thành phố đại diện.\]*

*\[Đánh giá Module 3 (tối ưu lộ trình): so sánh tổng quãng đường / thời gian di chuyển giữa SA và baseline (nearest neighbor greedy). Số lượng địa điểm test, số lần chạy, độ lệch chuẩn.\]*

*Hình 4.4.1: Minh họa Precision và Recall*

*\[\[Chèn hình minh họa và bảng kết quả đánh giá\]\]*

## **4.5.Đánh giá độ hữu ích**

*\[Trình bày kết quả khảo sát người dùng: phương pháp (số lượng người tham gia, câu hỏi, thang điểm), kết quả về độ hài lòng với lịch trình được gợi ý, mức độ sẵn sàng sử dụng ứng dụng thực tế.\]*

*Hình 4.5.1: Kết quả khảo sát người dùng*

*\[\[Chèn biểu đồ kết quả khảo sát\]\]*

# **Chương 5: KẾT LUẬN**

## **5.1.Kiến thức**

*\[Tổng hợp các kiến thức và kỹ năng nhóm tiếp thu và trau dồi được: thuật toán gợi ý (CF/WALS, CB), tối ưu tổ hợp (SA-TSPTW, K-Means), lập trình Flutter (mobile \+ web), Python FastAPI (async, microservice), Supabase (PostgreSQL, PostgREST, Auth), thu thập và làm sạch dữ liệu thực tế.\]*

## **5.2.Khó khăn trong quá trình thực hiện**

*\[Nêu những thách thức cụ thể nhóm đã gặp: chất lượng dữ liệu địa điểm (sáp nhập hành chính, thiếu nhất quán), tuning tham số SA, xử lý PostgREST schema cache, tích hợp cross-module giữa các thành viên, kinh phí hạ tầng cloud. Với mỗi khó khăn, nêu cách giải quyết và bài học rút ra.\]*

## **5.3.Sản phẩm đạt được**

*\[Liệt kê kết quả cụ thể: ứng dụng Flutter Android hoàn chỉnh với các module Explore, Recommendation, Trip Planner, AI Identify, Wishlist, Forum, Popular Apps; bảng điều khiển Admin web; API backend tích hợp ba module thuật toán; cơ sở dữ liệu địa điểm phủ \[N\] tỉnh thành Việt Nam.\]*

## **5.4. Hướng phát triển**  {#5.4.-hướng-phát-triển}

*\[Các điểm cần cải thiện: nâng cao chất lượng dữ liệu địa điểm (mở rộng phủ tỉnh thành, cập nhật giờ mở cửa thực tế), cải thiện cold start cho CF, tích hợp API bản đồ thực tế (Goong API) để tính thời gian di chuyển chính xác hơn Haversine, triển khai cron job retraining CF định kỳ, bổ sung Business Trip mode.\]*

*\[Tính năng mới dự kiến: tích hợp đặt phòng khách sạn và phương tiện, tính năng chia sẻ lịch trình với bạn đồng hành, gợi ý địa điểm ăn uống theo ngân sách, hỗ trợ đa ngôn ngữ (tiếng Anh), phiên bản iOS.\]*

**TÀI LIỆU THAM KHẢO**

1. **Cục Du lịch Quốc gia Việt Nam**, *Thông tin du lịch nổi bật năm 2024 \[[https://vietnamtourism.gov.vn/post/60707](https://vietnamtourism.gov.vn/post/60707) \]*

2. **Cổng Thông tin điện tử Chính phủ**, *Phát triển du lịch thông minh, đưa Việt Nam trở thành điểm đến đặc biệt hấp dẫn* \[[*https://xaydungchinhsach.chinhphu.vn/phat-trien-du-lich-thong-minh-dua-viet-nam-tro-thanh-diem-den-dac-biet-hap-dan-119221225083834129.htm*](https://xaydungchinhsach.chinhphu.vn/phat-trien-du-lich-thong-minh-dua-viet-nam-tro-thanh-diem-den-dac-biet-hap-dan-119221225083834129.htm) \]

3. **Booking.com, Lost in translation?** *Booking.com research exposes surprising gap between travel ambitions and reality,* 2018\. \[[https://news.booking.com/lost-in-translation-bookingcom-research-exposes-surprising-gap-between-travel-ambitions-and-reality/](https://news.booking.com/lost-in-translation-bookingcom-research-exposes-surprising-gap-between-travel-ambitions-and-reality/) \]

4.  **Booking.com**, *Booking.com Enhances Travel Planning with New AI-Powered Features for Easier, Smarter Decisions*. \[[https://news.booking.com/bookingcom-enhances-travel-planning-with-new-ai-powered-features--for-easier-smarter-decisions](https://news.booking.com/bookingcom-enhances-travel-planning-with-new-ai-powered-features--for-easier-smarter-decisions/)

5. **Decision Lab,** *The rise of independent travel in Vietnam is changing how destinations, airlines, and tour brands compete.* \[[https://www.decisionlab.co/blog/the-rise-of-independent-travel-in-vietnam-is-changing-how-destinations-airlines-and-tour-brands-compete](https://www.decisionlab.co/blog/the-rise-of-independent-travel-in-vietnam-is-changing-how-destinations-airlines-and-tour-brands-compete)\] 

**PHỤ LỤC**

**Đặc tả use-case**

*\[Chèn bảng đặc tả chi tiết cho từng use-case chính: tên, tóm tắt, tác nhân, điều kiện tiên quyết, hậu điều kiện, dòng sự kiện chính và phụ. Phải có các use-case: Đăng ký, Đăng nhập, Tạo lịch trình tự động, Xem lịch trình đang đi, Khám phá địa điểm, Nhận dạng địa điểm bằng AI.\]*

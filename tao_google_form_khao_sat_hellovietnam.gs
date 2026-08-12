/**
 * TẠO GOOGLE FORM KHẢO SÁT ĐÁNH GIÁ ỨNG DỤNG HELLOVIETNAM
 *
 * Cách sử dụng:
 * 1. Mở https://script.google.com/ và chọn New project.
 * 2. Xóa mã mẫu, dán toàn bộ file này vào Code.gs rồi bấm Save.
 * 3. Chọn hàm createHelloVietnamSurvey trong danh sách hàm và bấm Run.
 * 4. Cấp quyền cho Google Forms, Google Sheets và xem Execution log để lấy link.
 *
 * Mỗi lần chạy sẽ tạo một Google Form và một Google Sheets mới.
 */

const SURVEY_TITLE = 'KHẢO SÁT ĐÁNH GIÁ ỨNG DỤNG HELLOVIETNAM';
const SURVEY_DESCRIPTION = `Xin chào, chúng tôi là nhóm sinh viên thực hiện đề tài ứng dụng
gợi ý lịch trình cho khách du lịch tự túc tại Việt Nam. Biểu mẫu này được thực hiện
nhằm thu thập ý kiến người dùng sau khi trải nghiệm ứng dụng HelloVietnam.

Kết quả khảo sát chỉ được sử dụng cho mục đích nghiên cứu và đánh giá đồ án tốt nghiệp.
Thời gian trả lời dự kiến từ 5 đến 7 phút. Các câu trả lời sẽ được tổng hợp và không
sử dụng để xác định danh tính cá nhân.

Vui lòng trả lời dựa trên trải nghiệm thực tế của bạn với ứng dụng.`;

const LIKERT_COLUMNS = [
  '1 — Hoàn toàn không đồng ý',
  '2 — Không đồng ý',
  '3 — Trung lập',
  '4 — Đồng ý',
  '5 — Hoàn toàn đồng ý',
];

const LIKERT_HELP =
  'Vui lòng đánh giá theo thang điểm: 1 = Hoàn toàn không đồng ý; '
  + '2 = Không đồng ý; 3 = Trung lập; 4 = Đồng ý; '
  + '5 = Hoàn toàn đồng ý.';

/** Tạo Form khảo sát và Sheet nhận phản hồi. Đây là hàm duy nhất cần chạy. */
function createHelloVietnamSurvey() {
  let form = null;
  let spreadsheet = null;

  try {
    form = FormApp.create(SURVEY_TITLE);
    spreadsheet = SpreadsheetApp.create('Phản hồi khảo sát HelloVietnam');

    form
      .setDescription(SURVEY_DESCRIPTION)
      .setProgressBar(true)
      .setCollectEmail(false)
      .setLimitOneResponsePerUser(false)
      .setIsQuiz(false)
      .setShuffleQuestions(false)
      .setShowLinkToRespondAgain(false)
      .setPublishingSummary(false)
      .setConfirmationMessage(
        'Cảm ơn bạn đã tham gia khảo sát. Phản hồi của bạn sẽ giúp nhóm cải thiện HelloVietnam.',
      );
    form.setDestination(FormApp.DestinationType.SPREADSHEET, spreadsheet.getId());

    // Phần 1: giới thiệu và kiểm tra người trả lời đã trải nghiệm ứng dụng.
    const experience = form
      .addMultipleChoiceItem()
      .setTitle('Bạn đã trực tiếp trải nghiệm ứng dụng HelloVietnam chưa?')
      .setHelpText('Khảo sát này dành cho người đã sử dụng hoặc xem bản trình diễn ứng dụng.')
      .setRequired(true);

    const profilePage = form
      .addPageBreakItem()
      .setTitle('PHẦN 2 — THÔNG TIN NGƯỜI THAM GIA')
      .setHelpText('Chỉ cung cấp thông tin cần thiết cho việc phân tích khảo sát.');

    addProfileQuestions(form);

    const evaluationPage = form
      .addPageBreakItem()
      .setTitle('PHẦN 3 — ĐÁNH GIÁ ỨNG DỤNG')
      .setHelpText(LIKERT_HELP);
    addLikertQuestions(form);

    const overallPage = form
      .addPageBreakItem()
      .setTitle('PHẦN 4 — ĐÁNH GIÁ TỔNG THỂ')
      .setHelpText('Hãy trả lời dựa trên trải nghiệm vừa thực hiện.');
    addOverallQuestions(form);

    const feedbackPage = form
      .addPageBreakItem()
      .setTitle('PHẦN 5 — Ý KIẾN VÀ ĐỀ XUẤT')
      .setHelpText('Các câu hỏi mở giúp nhóm hiểu rõ hơn về ưu điểm và hạn chế của ứng dụng.');
    addOpenFeedbackQuestions(form);

    const ineligiblePage = form
      .addPageBreakItem()
      .setTitle('CẢM ƠN BẠN ĐÃ QUAN TÂM')
      .setHelpText(
        'Khảo sát này dành cho người đã trực tiếp trải nghiệm hoặc xem bản trình diễn '
        + 'ứng dụng HelloVietnam.',
      );

    // Chỉ người đã trải nghiệm mới đi tiếp vào các phần đánh giá.
    experience.setChoices([
      experience.createChoice(
        'Đã trải nghiệm đầy đủ các chức năng chính.',
        profilePage,
      ),
      experience.createChoice('Đã trải nghiệm một số chức năng.', profilePage),
      experience.createChoice('Chỉ xem bản trình diễn.', profilePage),
      experience.createChoice('Chưa trải nghiệm.', ineligiblePage),
    ]);

    // Kết thúc khảo sát hợp lệ trước khi tới trang dành cho người chưa trải nghiệm.
    feedbackPage.setGoToPage(FormApp.PageNavigationType.SUBMIT);
    ineligiblePage.setGoToPage(FormApp.PageNavigationType.SUBMIT);

    Logger.log('=== ĐÃ TẠO KHẢO SÁT HELLOVIETNAM ===');
    Logger.log('Link chỉnh sửa Form: %s', form.getEditUrl());
    Logger.log('Link gửi cho người trả lời: %s', form.getPublishedUrl());
    Logger.log('Link Google Sheets phản hồi: %s', spreadsheet.getUrl());
    return {
      editUrl: form.getEditUrl(),
      responseUrl: form.getPublishedUrl(),
      spreadsheetUrl: spreadsheet.getUrl(),
    };
  } catch (error) {
    Logger.log('Không thể tạo đầy đủ khảo sát: %s', error && error.stack ? error.stack : error);
    if (form) Logger.log('Form đã được tạo (nếu có): %s', form.getEditUrl());
    if (spreadsheet) Logger.log('Sheet đã được tạo (nếu có): %s', spreadsheet.getUrl());
    throw error;
  }
}

function addProfileQuestions(form) {
  addMultipleChoice(form, 'Độ tuổi của bạn', [
    'Dưới 18 tuổi.',
    'Từ 18 đến 22 tuổi.',
    'Từ 23 đến 30 tuổi.',
    'Từ 31 đến 40 tuổi.',
    'Trên 40 tuổi.',
    'Không muốn trả lời.',
  ], true);

  addMultipleChoice(form, 'Tần suất đi du lịch tự túc của bạn', [
    'Chưa từng.',
    'Ít hơn 1 lần mỗi năm.',
    'Từ 1 đến 2 lần mỗi năm.',
    'Từ 3 đến 5 lần mỗi năm.',
    'Trên 5 lần mỗi năm.',
  ], true);

  const planning = form
    .addCheckboxItem()
    .setTitle('Bạn thường lập kế hoạch chuyến đi bằng cách nào?')
    .setChoiceValues([
      'Tự tìm kiếm trên Google hoặc mạng xã hội.',
      'Sử dụng Google Maps.',
      'Sử dụng ứng dụng lập lịch trình du lịch.',
      'Tham khảo người quen hoặc cộng đồng.',
      'Sử dụng lịch trình có sẵn.',
      'Đặt tour trọn gói.',
    ])
    .showOtherOption(true)
    .setRequired(true);

  addMultipleChoice(form, 'Bạn đã từng sử dụng ứng dụng lập lịch trình du lịch chưa?', [
    'Đã sử dụng thường xuyên.',
    'Đã sử dụng một vài lần.',
    'Chỉ biết nhưng chưa sử dụng.',
    'Chưa từng biết hoặc sử dụng.',
  ], true);

  form
    .addCheckboxItem()
    .setTitle('Bạn đã trải nghiệm những chức năng nào của HelloVietnam?')
    .setChoiceValues([
      'Xem thông tin địa điểm.',
      'Chọn sở thích du lịch.',
      'Nhận gợi ý địa điểm.',
      'Tạo lịch trình tự động.',
      'Xem lịch trình theo ngày.',
      'Xem thứ tự di chuyển giữa các địa điểm.',
      'Chỉnh sửa hoặc lưu lịch trình.',
      'Tìm kiếm bằng AI.',
      'Xem cẩm nang hoặc thông tin hỗ trợ du lịch.',
    ])
    .showOtherOption(true)
    .setRequired(true);
}

function addLikertQuestions(form) {
  addLikertGrid(form, 'A. Mức độ hữu ích', [
    'Ứng dụng giúp tôi giảm thời gian tìm kiếm thông tin cho chuyến đi.',
    'Ứng dụng giúp tôi dễ dàng lựa chọn địa điểm phù hợp hơn.',
    'Ứng dụng giúp tôi hình dung rõ hơn kế hoạch của từng ngày.',
    'Ứng dụng hỗ trợ tốt cho người muốn tự tổ chức chuyến đi.',
  ]);

  addLikertGrid(form, 'B. Chất lượng gợi ý địa điểm', [
    'Các địa điểm được gợi ý phù hợp với sở thích tôi đã chọn.',
    'Danh sách gợi ý có sự đa dạng về loại hình địa điểm.',
    'Thông tin địa điểm được trình bày đủ để tôi cân nhắc lựa chọn.',
  ]);

  addLikertGrid(form, 'C. Chất lượng lịch trình', [
    'Số lượng địa điểm được sắp xếp trong mỗi ngày là hợp lý.',
    'Các địa điểm trong cùng một ngày có vị trí tương đối thuận tiện để di chuyển.',
    'Thứ tự tham quan các địa điểm trong ngày nhìn chung hợp lý.',
    'Lịch trình có thời gian bắt đầu và kết thúc phù hợp.',
    'Lịch trình có khả năng áp dụng cho một chuyến đi thực tế.',
  ]);

  addLikertGrid(form, 'D. Khả năng sử dụng', [
    'Tôi dễ dàng hiểu cách sử dụng các chức năng chính.',
    'Các bước tạo lịch trình được sắp xếp rõ ràng.',
    'Tôi có thể hoàn thành việc tạo lịch trình mà không cần nhiều hướng dẫn.',
    'Tôi dễ dàng chỉnh sửa hoặc thay đổi lựa chọn khi cần.',
  ]);

  addLikertGrid(form, 'E. Giao diện', [
    'Giao diện ứng dụng có bố cục rõ ràng.',
    'Thông tin lịch trình được trình bày trực quan.',
  ]);

  addLikertGrid(form, 'F. Hiệu năng cảm nhận', [
    'Các màn hình chính được tải trong thời gian chấp nhận được.',
    'Thời gian chờ khi tạo lịch trình là chấp nhận được.',
  ]);

  addLikertGrid(form, 'G. Ý định sử dụng', [
    'Tôi sẵn sàng sử dụng HelloVietnam cho một chuyến đi trong tương lai.',
    'Tôi sẵn sàng giới thiệu ứng dụng cho người khác.',
  ]);
}

function addOverallQuestions(form) {
  form
    .addScaleItem()
    .setTitle('Bạn đánh giá tổng thể lịch trình được tạo ở mức nào?')
    .setBounds(1, 5)
    .setLabels('Rất không hợp lý', 'Rất hợp lý')
    .setRequired(true);

  addMultipleChoice(form, 'Bạn có sẵn sàng sử dụng lịch trình này làm cơ sở cho chuyến đi thật không?', [
    'Có, gần như không cần chỉnh sửa.',
    'Có, nhưng cần chỉnh sửa một số nội dung.',
    'Chỉ dùng để tham khảo.',
    'Không sử dụng.',
    'Chưa thể đánh giá.',
  ], true);

  addMultipleChoice(form, 'Thời gian chờ lâu nhất mà bạn ghi nhận ở chức năng nào?', [
    'Mở ứng dụng hoặc đăng nhập.',
    'Tải danh sách địa điểm.',
    'Tạo lịch trình.',
    'Tìm kiếm bằng AI.',
    'Tải hình ảnh.',
    'Lưu hoặc chỉnh sửa dữ liệu.',
    'Không nhận thấy thời gian chờ đáng kể.',
  ], false, true);

  addMultipleChoice(form, 'Trong quá trình sử dụng, bạn có gặp khó khăn hoặc không biết phải thao tác tiếp như thế nào không?', [
    'Không gặp.',
    'Có gặp một lần.',
    'Có gặp một vài lần.',
    'Gặp thường xuyên.',
  ], true);

  form
    .addParagraphTextItem()
    .setTitle('Bạn gặp khó khăn ở bước nào?')
    .setHelpText('Không bắt buộc. Chỉ trả lời nếu bạn gặp khó khăn trong quá trình sử dụng.')
    .setRequired(false);
}

function addOpenFeedbackQuestions(form) {
  form
    .addParagraphTextItem()
    .setTitle('Điều bạn cảm thấy hữu ích nhất khi sử dụng HelloVietnam là gì?')
    .setRequired(true);

  form
    .addParagraphTextItem()
    .setTitle('Điểm nào của ứng dụng khiến bạn chưa hài lòng hoặc gặp khó khăn?')
    .setRequired(true);

  form
    .addParagraphTextItem()
    .setTitle('Theo bạn, lịch trình được tạo cần cải thiện điều gì?')
    .setHelpText('Ví dụ: địa điểm, số lượng điểm mỗi ngày, thứ tự di chuyển, thời gian tham quan hoặc khả năng chỉnh sửa.')
    .setRequired(false);

  form
    .addParagraphTextItem()
    .setTitle('Bạn phát hiện thông tin địa điểm nào chưa chính xác hoặc chưa đầy đủ không?')
    .setRequired(false);

  form
    .addCheckboxItem()
    .setTitle('Chức năng nào bạn mong muốn được bổ sung trong phiên bản tiếp theo?')
    .setChoiceValues([
      'Dữ liệu giao thông theo thời gian thực.',
      'Chỉ đường chi tiết.',
      'Dự báo thời tiết theo lịch trình.',
      'Đề xuất nhà hàng và nơi lưu trú.',
      'Chia sẻ lịch trình với bạn bè.',
      'Cộng tác chỉnh sửa lịch trình.',
      'Tải lịch trình để sử dụng ngoại tuyến.',
      'Tự động cập nhật khi địa điểm đóng cửa.',
      'Tùy chỉnh ngân sách chi tiết.',
    ])
    .showOtherOption(true)
    .setRequired(false);

  form
    .addParagraphTextItem()
    .setTitle('Ý kiến hoặc đề xuất khác')
    .setRequired(false);
}

function addLikertGrid(form, title, rows) {
  form
    .addGridItem()
    .setTitle(title)
    .setHelpText(LIKERT_HELP)
    .setRows(rows)
    .setColumns(LIKERT_COLUMNS)
    .setRequired(true);
}

function addMultipleChoice(form, title, choices, required, showOther) {
  const item = form
    .addMultipleChoiceItem()
    .setTitle(title)
    .setChoiceValues(choices)
    .setRequired(required);
  if (showOther) item.showOtherOption(true);
  return item;
}

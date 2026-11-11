/// Toàn văn điều khoản người dùng phải đồng ý trước khi dùng app (chủ hệ thống chốt 11/11/2026).
///
/// 🔴 **Đổi BẤT KỲ chữ nào trong file này ⇒ nâng [privacyConsentVersion].** Máy chủ (`dms_privacy_consent`) chỉ lưu số
/// phiên bản; người đối chiếu "nhân viên X đã đồng ý nội dung gì" tra toàn văn theo phiên bản trong lịch sử git của file
/// này. Nâng phiên bản thì mọi người phải đồng ý lại ở lần mở Trang chủ kế tiếp.
///
/// Nguồn: `legal_contract/Thỏa thuận xử lý dữ liệu cá nhân.docx` — phần "Áp dụng đối với Người lao động" (Điều 1–5 +
/// bảng xác nhận theo từng mục đích). Văn bản pháp lý giữ nguyên tiếng Việt ở cả hai ngôn ngữ giao diện.
library;

/// Phiên bản điều khoản hiện hành — định dạng `số[.số[.số]]` (máy chủ kiểm).
const String privacyConsentVersion = '1.0';

/// Một mục (điều) của văn bản.
class ConsentSection {
  final String heading;
  final List<String> paragraphs;

  const ConsentSection(this.heading, this.paragraphs);
}

/// Một văn bản người dùng tick đồng ý.
class ConsentDocument {
  final String title;
  final String? subtitle;
  final List<String> preamble;
  final List<ConsentSection> sections;

  const ConsentDocument({required this.title, this.subtitle, this.preamble = const [], required this.sections});
}

/// Điều khoản sử dụng phần mềm (cũng là nội dung mục "Điều khoản sử dụng" ở màn Cá nhân).
const ConsentDocument termsOfUseDocument = ConsentDocument(
  title: 'Điều khoản sử dụng phần mềm VTHM DMS',
  sections: [
    ConsentSection('', [
      '1. Ứng dụng dành riêng cho CBNV VTHM Group phục vụ công tác quản lý thị trường.',
      '2. Nghiêm cấm chia sẻ thông tin khách hàng và lộ trình ra bên ngoài doanh nghiệp.',
      '3. Vui lòng duy trì GPS và kết nối Internet trong suốt ca làm việc để dữ liệu đồng bộ chính xác.',
    ]),
  ],
);

/// Văn bản đồng ý xử lý dữ liệu cá nhân — áp dụng đối với Người lao động.
const ConsentDocument personalDataConsentDocument = ConsentDocument(
  title: 'Văn bản đồng ý xử lý dữ liệu cá nhân',
  subtitle: '(Áp dụng đối với Người lao động)',
  preamble: [
    'Căn cứ Luật Bảo vệ dữ liệu cá nhân năm 2025 (Luật số 91/2025/QH15);',
    'Căn cứ Nghị định 356/2025/NĐ-CP hướng dẫn Luật Bảo vệ dữ liệu cá nhân;',
    'Căn cứ Hợp đồng lao động và Quy chế nội bộ của Tập đoàn/Công ty,',
  ],
  sections: [
    ConsentSection('Điều 1. Phạm vi các loại dữ liệu cá nhân được xử lý', [
      'Tôi thừa nhận và đồng ý cho Tập đoàn/Công ty thu thập, lưu trữ và xử lý các nhóm dữ liệu cá nhân sau đây:',
      '1. Dữ liệu cá nhân cơ bản: Họ tên, ngày tháng năm sinh, giới tính, số CCCD/CMND, địa chỉ thường trú/liên hệ, '
          'số điện thoại, email, trình độ học vấn, quá trình công tác, thông tin tài khoản ngân hàng nhận lương, thông '
          'tin người phụ thuộc.',
      '2. Dữ liệu cá nhân nhạy cảm - Dữ liệu vị trí (GPS): Dữ liệu vị trí địa lý chi tiết được ghi nhận từ thiết bị '
          'khi tôi thực hiện thao tác check-in/check-out viếng thăm điểm bán trên ứng dụng Quản lý phân phối (DMS).',
      '3. Dữ liệu cá nhân nhạy cảm - Dữ liệu sinh trắc học: Dữ liệu vân tay ghi nhận trên máy chấm công; ảnh chụp '
          'khuôn mặt (Face-ID) khi check-in/check-out qua ứng dụng chấm công nội bộ.',
      '4. Dữ liệu quản lý nhân sự: Kết quả đánh giá hiệu suất, lịch sử đào tạo, khen thưởng, kỷ luật, nhật ký truy '
          'cập hệ thống công nghệ thông tin nội bộ.',
    ]),
    ConsentSection('Điều 2. Mục đích xử lý dữ liệu cá nhân', [
      'Việc xử lý dữ liệu cá nhân được thực hiện nghiêm ngặt cho các mục đích hợp pháp sau:',
      '1. Quản trị nhân sự & Chế độ chính sách: Thực hiện ký kết, quản lý Hợp đồng lao động; chi trả tiền lương, '
          'thưởng, phụ cấp; trích nộp bảo hiểm xã hội, bảo hiểm y tế, thuế thu nhập cá nhân theo quy định pháp luật.',
      '2. Ghi nhận công lao động & Công tác phí: Xác nhận thời gian làm việc thực tế, đối soát lộ trình viếng thăm '
          'điểm bán kinh doanh (DMS), tính công tác phí, phụ cấp di chuyển và đánh giá chỉ số hoàn thành công việc '
          '(KPI).',
      '3. Bảo đảm an ninh an toàn doanh nghiệp: Bảo đảm an toàn bảo mật hệ thống CNTT, kiểm soát quyền truy cập tài '
          'sản doanh nghiệp, phòng chống lộ lọt thông tin và điều tra sự cố an toàn thông tin.',
      '4. Tuân thủ nghĩa vụ pháp lý: Báo cáo cơ quan nhà nước có thẩm quyền khi có yêu cầu bằng văn bản theo luật '
          'định.',
    ]),
    ConsentSection('Điều 3. Bên xử lý dữ liệu và Chuyển dữ liệu ra nước ngoài', [
      '1. Dữ liệu của tôi có thể được xử lý bởi Công ty thành viên trực tiếp quản lý, Tập đoàn và các Bên xử lý dữ '
          'liệu được ủy quyền.',
      '2. Tôi được thông báo và đồng ý rằng các dữ liệu nhân sự cơ bản có thể được lưu trữ, sao lưu trên hạ tầng điện '
          'toán đám mây quốc tế đặt tại các trung tâm dữ liệu ngoài lãnh thổ Việt Nam phục vụ mục đích vận hành hệ '
          'thống CNTT tập trung của Tập đoàn.',
    ]),
    ConsentSection('Điều 4. Thời hạn lưu trữ và Quy trình xóa, hủy dữ liệu', [
      '1. Thời hạn lưu trữ: Dữ liệu cá nhân được lưu trữ trong suốt thời gian tôi làm việc tại Tập đoàn/Công ty và kéo '
          'dài theo quy định của pháp luật về lưu trữ chứng từ kế toán, lao động (tối thiểu 05 năm đến 10 năm sau khi '
          'chấm dứt HĐLĐ).',
      '2. Xóa dữ liệu nhạy cảm: Dữ liệu sinh trắc học (vân tay, ảnh chụp) và dữ liệu vị trí GPS chi tiết sẽ được tự '
          'động xóa/hủy hoặc đóng băng trên hệ thống trong thời hạn 30 ngày kể từ ngày chấm dứt HĐLĐ hoặc khi hoàn '
          'thành mục đích chấm công đối soát.',
    ]),
    ConsentSection('Điều 5. Quyền và Nghĩa vụ của Người lao động', [
      '1. Quyền của chủ thể dữ liệu: Tôi có quyền xem, chỉnh sửa, yêu cầu cung cấp, yêu cầu xóa dữ liệu, rút lại sự '
          'đồng ý hoặc hạn chế xử lý dữ liệu theo quy định tại Điều 4 Luật Bảo vệ dữ liệu cá nhân 2025.',
      '2. Quy trình rút lại sự đồng ý: Việc rút lại sự đồng ý được gửi bằng văn bản hoặc giao diện ứng dụng điện tử. '
          'Tôi hiểu rằng việc rút lại sự đồng ý đối với dữ liệu chấm công/GPS có thể dẫn đến việc Công ty không đủ cơ '
          'sở để ghi nhận ngày công hoặc chi trả phụ cấp công tác phí.',
    ]),
    ConsentSection('Xác nhận đồng ý theo từng mục đích', [
      'Theo quy định tại Điều 9 Luật số 91/2025/QH15 và Điều 6 Nghị định 356/2025/NĐ-CP, khi bấm "Đồng ý & Tiếp tục" '
          'tôi xác nhận ĐỒNG Ý với tất cả các nội dung sau:',
      '1. Xử lý Dữ liệu cá nhân cơ bản cho mục đích quản lý HĐLĐ, chi trả lương, bảo hiểm và thuế.',
      '2. Xử lý Dữ liệu vị trí (GPS DMS - Dữ liệu nhạy cảm) để đối soát viếng thăm điểm bán & tính công tác phí.',
      '3. Xử lý Dữ liệu sinh trắc học (Vân tay/Ảnh check-in - Dữ liệu nhạy cảm) cho mục đích chấm công.',
      '4. Lưu trữ sao lưu dữ liệu nhân sự trên hạ tầng Điện toán đám mây quốc tế.',
    ]),
  ],
);

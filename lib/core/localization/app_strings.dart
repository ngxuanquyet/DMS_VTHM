import 'app_language.dart';

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isVietnamese => language == AppLanguage.vi;

  // General
  String get appName => 'VTHM Group';
  String get appSubtitle => isVietnamese
      ? 'Hệ thống Quản lý Nhân viên Thị trường'
      : 'Field Operations Management System';
  String get cancel => isVietnamese ? 'Hủy' : 'Cancel';
  String get confirm => isVietnamese ? 'Xác nhận' : 'Confirm';
  String get close => isVietnamese ? 'Đóng' : 'Close';
  String get retry => isVietnamese ? 'Thử lại' : 'Retry';
  String get success => isVietnamese ? 'Thành công' : 'Success';
  String get error => isVietnamese ? 'Lỗi' : 'Error';
  String get unknown => isVietnamese ? 'Không xác định' : 'Unknown';
  String get notUpdated => isVietnamese ? 'Chưa cập nhật' : 'Not updated';
  String get status => isVietnamese ? 'Trạng thái' : 'Status';
  String get viewDetails => isVietnamese ? 'Xem chi tiết' : 'View details';
  String get viewAll => isVietnamese ? 'Xem tất cả' : 'View all';
  String get continueAction => isVietnamese ? 'Tiếp tục' : 'Continue';
  String get all => isVietnamese ? 'Tất cả' : 'All';
  String get unread => isVietnamese ? 'Chưa đọc' : 'Unread';
  String get work => isVietnamese ? 'Công việc' : 'Work';
  String get system => isVietnamese ? 'Hệ thống' : 'System';

  // Navigation
  String get navHome => isVietnamese ? 'Trang chủ' : 'Home';
  String get navRoutes => isVietnamese ? 'Tuyến' : 'Routes';
  String get navForms => isVietnamese ? 'Biểu mẫu' : 'Forms';
  String get navProfile => isVietnamese ? 'Cá nhân' : 'Profile';

  // Auth / Login
  String get login => isVietnamese ? 'Đăng nhập' : 'Log in';
  String get loginButton => isVietnamese ? 'ĐĂNG NHẬP' : 'LOG IN';
  String get usernameLabel =>
      isVietnamese ? 'Tài khoản / Mã nhân viên' : 'Account / Employee Code';
  String get usernameHint =>
      isVietnamese ? 'Nhập tài khoản' : 'Enter account';
  String get passwordLabel => isVietnamese ? 'Mật khẩu' : 'Password';
  String get passwordHint => isVietnamese ? 'Nhập mật khẩu' : 'Enter password';
  String get rememberLogin =>
      isVietnamese ? 'Ghi nhớ đăng nhập' : 'Remember login';
  String get forgotPassword =>
      isVietnamese ? 'Quên mật khẩu?' : 'Forgot password?';
  String get forgotPasswordMsg => isVietnamese
      ? 'Vui lòng liên hệ quản trị viên để cấp lại mật khẩu'
      : 'Please contact your administrator to reset password';
  String get emptyAuthWarning => isVietnamese
      ? 'Vui lòng điền đầy đủ tài khoản và mật khẩu'
      : 'Please enter both username and password';

  // Profile Screen
  String get accountSection => isVietnamese ? 'TÀI KHOẢN' : 'ACCOUNT';
  String get personalInfo =>
      isVietnamese ? 'Thông tin cá nhân' : 'Personal Information';
  String get changePassword =>
      isVietnamese ? 'Đổi mật khẩu' : 'Change Password';
  String get changePasswordNotice => isVietnamese
      ? 'Mở form đổi mật khẩu'
      : 'Opening change password form';
  String get appSettingsSection =>
      isVietnamese ? 'CÀI ĐẶT ỨNG DỤNG' : 'APP SETTINGS';
  String get languageTitle => isVietnamese ? 'Ngôn ngữ' : 'Language';
  String get selectLanguage =>
      isVietnamese ? 'Chọn ngôn ngữ' : 'Select Language';
  String get vietnamese => 'Tiếng Việt';
  String get english => 'English';
  String get darkMode => isVietnamese ? 'Chế độ tối' : 'Dark Mode';
  String get privacyPolicy =>
      isVietnamese ? 'Quyền riêng tư' : 'Privacy Policy';
  String get previewSplash => isVietnamese
      ? 'Xem Màn hình Khởi động (Splash)'
      : 'Preview Splash Screen';
  String get simulateOffline => isVietnamese
      ? 'Mô phỏng Mất mạng & Khôi phục (3s)'
      : 'Simulate Network Disconnection (3s)';
  String get supportFeedback =>
      isVietnamese ? 'Hỗ trợ & Góp ý' : 'Support & Feedback';
  String get helpGuide =>
      isVietnamese ? 'Trợ giúp & Hướng dẫn' : 'Help & Guide';
  String get termsOfService =>
      isVietnamese ? 'Điều khoản sử dụng' : 'Terms of Service';
  String get appInfoSection =>
      isVietnamese ? 'THÔNG TIN ỨNG DỤNG' : 'APP INFORMATION';
  String get versionLabel => isVietnamese ? 'Phiên bản' : 'Version';
  String get logout => isVietnamese ? 'Đăng xuất' : 'Log out';
  String get logoutConfirmTitle =>
      isVietnamese ? 'Xác nhận đăng xuất' : 'Confirm Logout';
  String get logoutConfirmMessage => isVietnamese
      ? 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'
      : 'Are you sure you want to log out of the application?';
  String get roleLabel => isVietnamese ? 'CHỨC VỤ' : 'POSITION';
  String get departmentLabel => isVietnamese ? 'PHÒNG BAN' : 'DEPARTMENT';
  String get companyLabel => isVietnamese ? 'CÔNG TY' : 'COMPANY';
  String get employeeTypeLabel =>
      isVietnamese ? 'LOẠI NHÂN VIÊN' : 'EMPLOYEE TYPE';

  // Personal Info Screen
  String get personalInfoTitle =>
      isVietnamese ? 'Thông tin cá nhân' : 'Personal Information';
  String get workInfoSection =>
      isVietnamese ? 'Thông tin công việc' : 'Work Information';
  String get contactInfoSection =>
      isVietnamese ? 'Thông tin liên hệ' : 'Contact Information';
  String get directManagerSection =>
      isVietnamese ? 'Quản lý trực tiếp' : 'Direct Manager';
  String get employeeCodePrefix =>
      isVietnamese ? 'Mã NV: ' : 'Employee Code: ';
  String get statusActive =>
      isVietnamese ? 'Đang hoạt động' : 'Active';
  String get phoneNumber => isVietnamese ? 'Số điện thoại' : 'Phone Number';
  String get companyEmail =>
      isVietnamese ? 'Email công ty' : 'Company Email';
  String get personalEmail =>
      isVietnamese ? 'Email cá nhân' : 'Personal Email';
  String get noManagerInfo => isVietnamese
      ? 'Không có thông tin cấp trên quản lý trực tiếp.'
      : 'No direct manager information available.';
  String get loadProfileError => isVietnamese
      ? 'Không thể tải thông tin cá nhân'
      : 'Unable to load personal information';

  // Home Screen
  String get greetingHello => isVietnamese ? 'Xin chào' : 'Hello';
  String get attendanceSection => isVietnamese ? 'Chấm công' : 'Attendance';
  String get checkedIn => isVietnamese ? 'Đã chấm công' : 'Checked In';
  String get checkInTime => isVietnamese ? 'Giờ vào' : 'Check-in Time';
  String get workDuration =>
      isVietnamese ? 'Thời gian làm việc' : 'Work Duration';
  String get workingTimeShort => isVietnamese ? 'Thời gian làm' : 'Work Time';
  String get routeProgress =>
      isVietnamese ? 'Tiến độ' : 'Progress';
  String get nextStopLabel => isVietnamese ? 'Điểm tiếp theo:' : 'Next stop:';
  String get pendingForms =>
      isVietnamese ? 'Biểu mẫu cần làm' : 'Pending Forms';
  String get formsOverview =>
      isVietnamese ? 'Tổng quan biểu mẫu' : 'Forms Overview';
  String get recentActivities =>
      isVietnamese ? 'Hoạt động gần đây' : 'Recent Activities';
  String get stopsUnit => isVietnamese ? 'điểm' : 'stops';
  String get checkInAction => isVietnamese ? 'Check-in' : 'Check-in';

  // Attendance Detail
  String get attendanceDetailTitle =>
      isVietnamese ? 'Chi tiết chấm công' : 'Attendance Details';
  String get checkInButton => isVietnamese ? 'CHẤM CÔNG VÀO' : 'CHECK IN';
  String get checkOutButton => isVietnamese ? 'CHẤM CÔNG RA' : 'CHECK OUT';
  String get attendanceHistory =>
      isVietnamese ? 'Lịch sử chấm công' : 'Attendance History';
  String get recentHistory =>
      isVietnamese ? 'Lịch sử gần đây' : 'Recent History';
  String get onTime => isVietnamese ? 'Đúng giờ' : 'On time';
  String get late => isVietnamese ? 'Đi muộn' : 'Late';
  String get workingDaysCaps => isVietnamese ? 'NGÀY CÔNG' : 'WORKING DAYS';
  String get lateDaysCaps => isVietnamese ? 'ĐI MUỘN' : 'LATE DAYS';
  String get workingStatus => isVietnamese ? 'Đang làm việc' : 'Working';
  String get shiftEnded => isVietnamese ? 'Đã kết thúc ca' : 'Shift Ended';
  String get currentLocation => isVietnamese ? 'Vị trí hiện tại' : 'Current Location';
  String get checkedInAt => isVietnamese ? 'Đã chấm công vào:' : 'Checked in at:';
  String get workingDurationFull => isVietnamese ? 'Thời gian làm việc:' : 'Working duration:';
  String get checkInSuccess => isVietnamese ? 'Chấm công vào thành công!' : 'Check-in successful!';
  String get checkOutSuccess => isVietnamese ? 'Chấm công ra thành công!' : 'Check-out successful!';
  String get monthlySummaryPrefix => isVietnamese ? 'Tổng kết' : 'Summary of';

  // Route & Check-in
  String get routeTitle => isVietnamese ? 'Tuyến làm việc' : 'Route Plan';
  String get routeListTab => isVietnamese ? 'Danh sách' : 'List';
  String get routeMapTab => isVietnamese ? 'Bản đồ' : 'Map';
  String get visitingStoreTitle => isVietnamese ? 'Đang ghé điểm bán' : 'Visiting Store';
  String get visitedStatus => isVietnamese ? 'Đã ghé' : 'Visited';
  String get pendingStatus => isVietnamese ? 'Chưa ghé' : 'Pending';
  String get inProgressStatus => isVietnamese ? 'Đang ghé' : 'In Progress';
  String get startVisit => isVietnamese ? 'Bắt đầu ghé thăm' : 'Start Visit';
  String get endVisit => isVietnamese ? 'Kết thúc ghé thăm' : 'End Visit';
  String get takePhoto => isVietnamese ? 'Chụp ảnh điểm bán' : 'Take Store Photo';
  String get visitNote => isVietnamese ? 'Ghi chú chuyến ghé' : 'Visit Notes';

  // Forms
  String get formsTitle => isVietnamese ? 'Danh sách Biểu mẫu' : 'Forms List';
  String get searchFormsHint =>
      isVietnamese ? 'Tìm kiếm biểu mẫu...' : 'Search forms...';
  String get todoStatus => isVietnamese ? 'Cần làm' : 'To Do';
  String get inProgressForm => isVietnamese ? 'Đang thực hiện' : 'In Progress';
  String get completedStatus => isVietnamese ? 'Hoàn thành' : 'Completed';
  String get overdueStatus => isVietnamese ? 'Quá hạn' : 'Overdue';
  String get questionsAnswered => isVietnamese ? 'câu đã trả lời' : 'questions answered';

  // Notifications
  String get notificationsTitle =>
      isVietnamese ? 'Thông báo' : 'Notifications';
  String get markAllAsRead =>
      isVietnamese ? 'Đánh dấu tất cả đã đọc' : 'Mark all as read';
  String get markAllSuccess =>
      isVietnamese ? 'Đã đánh dấu tất cả thông báo là đã đọc' : 'Marked all notifications as read';
  String get todaySection => isVietnamese ? 'Hôm nay' : 'Today';
  String get earlierSection => isVietnamese ? 'Trước đó' : 'Earlier';
  String get noNotifications =>
      isVietnamese ? 'Không có thông báo mới' : 'No new notifications';
}

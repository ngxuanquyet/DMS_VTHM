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
  String get understood => isVietnamese ? 'ĐÃ HIỂU' : 'UNDERSTOOD';

  // Navigation
  String get navHome => isVietnamese ? 'Trang chủ' : 'Home';
  String get navCustomers => isVietnamese ? 'Khách hàng' : 'Customers';
  String get navRoutes => isVietnamese ? 'Tuyến' : 'Routes';
  String get navForms => isVietnamese ? 'Biểu mẫu' : 'Forms';
  String get navProfile => isVietnamese ? 'Cá nhân' : 'Profile';

  // Customers
  String get customerScreenTitle => isVietnamese ? 'Khách hàng' : 'Customers';
  String get customerSubtitle => isVietnamese
      ? 'Danh sách phụ trách & định vị'
      : 'Assigned List & Location';
  String get customerSearchHint => isVietnamese
      ? 'Tìm tên, mã KH, số điện thoại, tuyến...'
      : 'Search name, code, phone, route...';
  String get filterToday => isVietnamese ? 'Hôm nay' : 'Today';
  String get filterVisited => isVietnamese ? 'Đã ghé' : 'Visited';
  String get filterPending => isVietnamese ? 'Chưa ghé' : 'Pending';
  String get editInfo => isVietnamese ? 'Sửa thông tin' : 'Edit info';
  String get directionsAction => isVietnamese ? 'Chỉ đường' : 'Directions';
  String get addCustomer => isVietnamese ? 'Thêm' : 'Add';
  String get scanQr => isVietnamese ? 'Quét QR' : 'Scan QR';

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
  String get simulateLocationOff => isVietnamese
      ? 'Mô phỏng Tắt GPS & Khôi phục (3s)'
      : 'Simulate Location Off (3s)';
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
  String get workplaceSectionTitle =>
      isVietnamese ? 'Đơn vị & Địa điểm làm việc' : 'Workplace & Location';
  String get workplaceCompanyLabel =>
      isVietnamese ? 'Công ty / Đơn vị làm việc' : 'Company / Work Unit';
  String get groupBadge =>
      isVietnamese ? 'Tập đoàn VTHM' : 'VTHM Group';
  String get validDistanceStatus =>
      isVietnamese ? 'Khoảng cách: 15m (Hợp lệ)' : 'Distance: 15m (Valid)';
  String get allowedRadiusDesc =>
      isVietnamese ? 'Bán kính cho phép: ≤ 50m quanh vị trí làm việc' : 'Allowed radius: ≤ 50m around workplace';
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

  // Location / GPS Dialog
  String get locationServiceDisabledTitle =>
      isVietnamese ? 'Chưa bật định vị GPS' : 'GPS Location Disabled';
  String get locationPermissionDeniedTitle =>
      isVietnamese ? 'Yêu cầu quyền vị trí' : 'Location Permission Required';
  String get locationServiceDisabledDesc => isVietnamese
      ? 'Hệ thống DMS VTHM cần định vị GPS để xác thực vị trí chấm công và check-in ghé thăm điểm bán trên tuyến. Vui lòng bật dịch vụ vị trí trên thiết bị.'
      : 'VTHM DMS requires GPS location to verify shift attendance and store check-ins on your route. Please enable location services on your device.';
  String get locationPermissionDeniedDesc => isVietnamese
      ? 'Vui lòng cấp quyền truy cập vị trí cho ứng dụng DMS VTHM để hệ thống ghi nhận chính xác tọa độ chấm công và lịch trình đi tuyến của bạn.'
      : 'Please grant location permission to VTHM DMS so the system can accurately verify your attendance and sales route itinerary.';
  String get locationPermissionDeniedForeverDesc => isVietnamese
      ? 'Quyền truy cập vị trí đang bị từ chối. Để tiếp tục chấm công và ghé thăm điểm bán, vui lòng mở Cài đặt ứng dụng và cấp quyền Vị trí.'
      : 'Location permission was denied. To continue attendance check-in and store visits, please open App Settings and allow Location permission.';
  String get enableGpsAction =>
      isVietnamese ? 'BẬT ĐỊNH VỊ' : 'ENABLE GPS';
  String get grantPermissionAction =>
      isVietnamese ? 'CẤP QUYỀN VỊ TRÍ' : 'GRANT PERMISSION';
  String get openSettingsAction =>
      isVietnamese ? 'MỞ CÀI ĐẶT' : 'OPEN SETTINGS';
  String get locationEnabledToast => isVietnamese
      ? 'Đã bật định vị GPS thành công'
      : 'GPS location enabled successfully';

  // Voice to Text (STT)
  String get voiceToTextTitle =>
      isVietnamese ? 'Thử nghiệm Voice to Text' : 'Voice to Text Testing';
  String get voiceToTextMenu =>
      isVietnamese ? 'Thử nghiệm Voice to Text (STT)' : 'Test Voice to Text (STT)';
  String get tapToSpeak =>
      isVietnamese ? 'Nhấn để bắt đầu nói' : 'Tap to start speaking';
  String get listening =>
      isVietnamese ? 'Đang lắng nghe bạn nói...' : 'Listening to your voice...';
  String get speechRecognized =>
      isVietnamese ? 'Văn bản nhận diện được' : 'Recognized Speech';
  String get noSpeechYet => isVietnamese
      ? 'Hãy nhấn vào nút micro bên dưới và nói điều gì đó...'
      : 'Tap the microphone button below and say something...';
  String get copyText => isVietnamese ? 'Sao chép' : 'Copy';
  String get textCopied =>
      isVietnamese ? 'Đã sao chép vào bộ nhớ tạm!' : 'Copied to clipboard!';
  String get clearText => isVietnamese ? 'Xóa nội dung' : 'Clear';
  String get micPermissionDenied =>
      isVietnamese ? 'Chưa cấp quyền micro' : 'Microphone permission denied';
  String get micPermissionRequired => isVietnamese
      ? 'Vui lòng cấp quyền micro để sử dụng tính năng giọng nói.'
      : 'Please grant microphone permission to use voice recognition.';
  String get speechNotAvailable => isVietnamese
      ? 'Thiết bị không hỗ trợ hoặc nhận diện giọng nói chưa sẵn sàng'
      : 'Speech recognition engine is not available on this device';
  String get vietnameseLocale => 'Tiếng Việt (vi-VN)';
  String get englishLocale => 'English (en-US)';
  String get confidenceScore =>
      isVietnamese ? 'Độ chính xác' : 'Confidence';
  String get recognitionLocaleLabel =>
      isVietnamese ? 'Ngôn ngữ nhận diện' : 'Recognition Language';

  // Distance Warning Dialog
  String get cannotCheckInTitle =>
      isVietnamese ? 'Không thể Check-in' : 'Cannot Check-in';
  String get distanceExceededDesc => isVietnamese
      ? 'Khoảng cách hiện tại vượt quá phạm vi cho phép (tối đa 100m). Vui lòng di chuyển đến gần điểm bán để thực hiện check-in.'
      : 'Current distance exceeds the allowed radius (max 100m). Please move closer to the store to check in.';
  String get currentDistance =>
      isVietnamese ? 'Khoảng cách hiện tại' : 'Current distance';
  String get invalidDistanceOver100m =>
      isVietnamese ? 'Không hợp lệ (> 100m)' : 'Invalid (> 100m)';
  String get yourLocation =>
      isVietnamese ? 'Vị trí của bạn' : 'Your location';
  String get directionsNowAction =>
      isVietnamese ? 'CHỈ ĐƯỜNG NGAY' : 'GET DIRECTIONS';
  String get closeActionCaps =>
      isVietnamese ? 'ĐÓNG' : 'CLOSE';
  String get noCoordsOrAddressForDirections => isVietnamese
      ? 'Điểm bán chưa có tọa độ hoặc địa chỉ để chỉ đường'
      : 'Store has no coordinates or address for directions';
  String get cannotOpenMapsApp => isVietnamese
      ? 'Không thể mở ứng dụng bản đồ Google Maps'
      : 'Cannot open Google Maps application';

  // Checkout Celebration Dialog
  String get checkoutSuccessTitle =>
      isVietnamese ? 'Check-out thành công!' : 'Check-out Successful!';
  String get checkoutSuccessDesc => isVietnamese
      ? 'Bạn đã hoàn tất phiên làm việc tại điểm bán. Toàn bộ dữ liệu chuyến ghé đã được lưu vào hệ thống.'
      : 'You have completed your store visit. All visit data has been saved to the system.';
  String get completeActionCaps =>
      isVietnamese ? 'HOÀN TẤT' : 'DONE';

  // Offline Dialog
  String get offlineTitle =>
      isVietnamese ? 'Đang ngoại tuyến' : 'Offline';
  String get offlineDesc => isVietnamese
      ? 'Bạn vẫn có thể tiếp tục làm việc. Dữ liệu sẽ tự động đồng bộ khi có kết nối mạng trở lại.'
      : 'You can continue working. Data will be synchronized automatically when network connection is restored.';

  // Exit Confirmation Dialogs
  String get leaveScreenTitle =>
      isVietnamese ? 'Rời khỏi màn hình?' : 'Leave Screen?';
  String get unsavedCustomerDataWarning => isVietnamese
      ? 'Dữ liệu điểm bán bạn đang nhập chưa được lưu. Nếu thoát ra, các thông tin đã nhập sẽ bị mất.'
      : 'The store data you entered has not been saved. If you leave, entered information will be lost.';
  String get stayAction =>
      isVietnamese ? 'Ở lại' : 'Stay';
  String get leaveAction =>
      isVietnamese ? 'Rời khỏi' : 'Leave';
  String get cancelCheckinTitle =>
      isVietnamese ? 'Hủy check-in?' : 'Cancel Check-in?';
  String get cancelCheckinDesc => isVietnamese
      ? 'Bạn có ghi chú/thông tin chưa lưu. Bạn có chắc chắn muốn thoát khỏi phiên check-in này không? Dữ liệu bạn vừa nhập sẽ bị mất.'
      : 'You have unsaved notes or changes. Are you sure you want to exit this check-in session? Entered data will be lost.';
  String get cancelCheckinAction =>
      isVietnamese ? 'Hủy check-in' : 'Cancel Check-in';
  String get checkinCancelledToast =>
      isVietnamese ? 'Đã hủy phiên check-in điểm bán.' : 'Check-in session cancelled.';

  // Visit Note Dialog & Screen Actions
  String get visitNoteDialogTitle =>
      isVietnamese ? 'Ghi chú chuyến ghé' : 'Visit Notes';
  String get visitNoteHint => isVietnamese
      ? 'Nhập ý kiến phản hồi hoặc ghi chú từ điểm bán...'
      : 'Enter feedback or notes from this store...';
  String get saveNoteActionCaps =>
      isVietnamese ? 'LƯU GHI CHÚ' : 'SAVE NOTE';
  String get leaveActionCaps =>
      isVietnamese ? 'RỜI KHỎI' : 'LEAVE';
  String get checkoutActionCaps =>
      isVietnamese ? 'CHECK-OUT' : 'CHECK-OUT';
  String get customerDefaultName =>
      isVietnamese ? 'Khách hàng' : 'Customer';

  // Circular Menus & Sync Toasts
  String get menuAddCustomer =>
      isVietnamese ? 'Thêm mới khách hàng' : 'Add New Customer';
  String get menuAddStore =>
      isVietnamese ? 'Thêm điểm bán' : 'Add Store';
  String get menuUpload =>
      isVietnamese ? 'Tải lên' : 'Upload';
  String get menuSendData =>
      isVietnamese ? 'Gửi dữ liệu' : 'Send Data';
  String get menuSync =>
      isVietnamese ? 'Đồng bộ' : 'Sync';
  String get menuSyncRoute =>
      isVietnamese ? 'Đồng bộ tuyến' : 'Sync Route';
  String get menuSyncing =>
      isVietnamese ? 'Đang đồng bộ...' : 'Syncing...';
  String get menuSortByDistance =>
      isVietnamese ? 'Sắp xếp theo khoảng cách' : 'Sort by Distance';
  String get menuSortRouteDistance =>
      isVietnamese ? 'Sắp xếp cự ly' : 'Sort Route Distance';
  String get menuCancelSortDistance =>
      isVietnamese ? 'Hủy xếp cự ly' : 'Reset Distance Sort';
  String get menuLocate =>
      isVietnamese ? 'Định vị' : 'Locate';
  String get menuGpsLocate =>
      isVietnamese ? 'Định vị GPS' : 'GPS Locate';
  String get allDataUploaded =>
      isVietnamese ? 'Tất cả dữ liệu đã được gửi lên máy chủ!' : 'All data has been uploaded to the server!';
  String get uploadingOfflineItems =>
      isVietnamese ? 'Đang tải lên dữ liệu ngoại tuyến...' : 'Uploading offline items...';
  String get allDataUploadedSuccess =>
      isVietnamese ? 'Đã tải lên thành công toàn bộ dữ liệu!' : 'Successfully uploaded all data!';
  String get canceledSortByDistance =>
      isVietnamese ? 'Đã hủy sắp xếp theo khoảng cách.' : 'Distance sorting cancelled.';
  String get sortedByDistanceSuccess =>
      isVietnamese ? 'Đã sắp xếp điểm bán theo khoảng cách gần nhất!' : 'Stores sorted by nearest distance!';
  String get noStoresOnRoute =>
      isVietnamese ? 'Không có điểm bán nào trên tuyến này' : 'No stores assigned to this route';

  // Voice Recording HUD Overlay
  String get recRecording =>
      isVietnamese ? 'REC ĐANG GHI ÂM' : 'REC RECORDING';
  String get recFinalizing =>
      isVietnamese ? 'ĐANG HOÀN TẤT...' : 'FINALIZING...';
  String get inputForFieldPrefix =>
      isVietnamese ? 'Nhập: ' : 'Input: ';
  String get speakIntoMicHint =>
      isVietnamese ? 'Hãy nói vào micro...' : 'Speak into the microphone...';
  String get voiceRecognizing =>
      isVietnamese ? 'Đang nhận diện giọng nói...' : 'Recognizing speech...';
  String get releaseToInsertText =>
      isVietnamese ? 'Thả tay ra để điền văn bản' : 'Release to insert text';
  String get updatingInput =>
      isVietnamese ? 'Đang cập nhật ô nhập...' : 'Updating input field...';
  String get holdMicGuidance =>
      isVietnamese ? 'Nhấn và giữ biểu tượng mic để nói, thả tay ra khi nói xong.' : 'Press and hold the mic icon to speak, release when finished.';
  String get speakNow =>
      isVietnamese ? 'Nói ngay' : 'Speak now';
  String get recognizedPrefix =>
      isVietnamese ? 'Đã nhập: ' : 'Recognized: ';

  // Add Customer Screen
  String get addNewStoreTitle =>
      isVietnamese ? 'Thêm mới điểm bán' : 'Add New Store';
  String get storeProfileDefault =>
      isVietnamese ? 'Hồ sơ điểm bán' : 'Store Profile';
  String get loadingFormSchema =>
      isVietnamese ? 'Đang tải cấu hình biểu mẫu...' : 'Loading form schema...';
  String get loadingDynamicFields =>
      isVietnamese ? 'Đang tải cấu hình trường nhập liệu động...' : 'Loading dynamic form fields...';
  String get errorLoadingFormSchema =>
      isVietnamese ? 'Không thể tải cấu hình form từ hệ thống' : 'Unable to load form schema from server';
  String get cancelActionCaps =>
      isVietnamese ? 'HỦY BỎ' : 'CANCEL';
  String get saveStoreActionCaps =>
      isVietnamese ? 'LƯU ĐIỂM BÁN' : 'SAVE STORE';
  String get storeNameRequired =>
      isVietnamese ? 'Tên điểm bán là bắt buộc.' : 'Store name is required.';
  String get storeSavedOnline =>
      isVietnamese ? 'Đã lưu điểm bán! Đang đồng bộ lên hệ thống...' : 'Store saved! Syncing to server...';
  String get storeSavedOffline =>
      isVietnamese ? 'Đã lưu trên máy! Điểm bán sẽ tự động đồng bộ khi có mạng.' : 'Saved locally! Will automatically sync when online.';

  // Customer Card
  String get editAction =>
      isVietnamese ? 'Sửa' : 'Edit';
  String get visitedTimePrefix =>
      isVietnamese ? 'Đã ghé: ' : 'Visited: ';
  String get notSynced =>
      isVietnamese ? 'Chưa đồng bộ' : 'Not synced';
  String get savingOffline =>
      isVietnamese ? 'Đang lưu offline' : 'Saving offline';

  // Form Card Item
  String get questionsUnit =>
      isVietnamese ? 'câu hỏi' : 'questions';
  String get notStarted =>
      isVietnamese ? 'Chưa thực hiện' : 'Not started';
  String get startAction =>
      isVietnamese ? 'Bắt đầu' : 'Start';
  String get redoAction =>
      isVietnamese ? 'Làm lại' : 'Redo';
  String get reviewAction =>
      isVietnamese ? 'Xem lại' : 'Review';

  // Dynamic Form Widgets
  String get cameraPermissionTitle =>
      isVietnamese ? 'Yêu cầu quyền Máy ảnh' : 'Camera Permission Required';
  String get cameraPermissionDesc => isVietnamese
      ? 'Ứng dụng cần quyền truy cập Camera để chụp ảnh thực tế tại điểm bán. Vui lòng cấp quyền trong Cài đặt thiết bị.'
      : 'The app needs Camera access to take store photos. Please grant permission in device Settings.';
  String get galleryPermissionTitle =>
      isVietnamese ? 'Yêu cầu quyền Thư viện ảnh' : 'Photo Library Permission Required';
  String get galleryPermissionDesc => isVietnamese
      ? 'Ứng dụng cần quyền truy cập Thư viện ảnh để chọn hình ảnh tải lên. Vui lòng cấp quyền trong Cài đặt thiết bị.'
      : 'The app needs Photo Library access to upload pictures. Please grant permission in device Settings.';
  String get openSettings =>
      isVietnamese ? 'Mở cài đặt' : 'Open settings';
  String get attachPhotoTitle =>
      isVietnamese ? 'Đính kèm hình ảnh' : 'Attach Photo';
  String get takePhotoFromCamera =>
      isVietnamese ? 'Chụp ảnh từ Camera' : 'Take photo with Camera';
  String get takePhotoCameraDesc =>
      isVietnamese ? 'Yêu cầu quyền truy cập Camera để chụp ảnh' : 'Requires Camera permission to take photos';
  String get chooseFromGallery =>
      isVietnamese ? 'Chọn từ Thư viện ảnh' : 'Choose from Photo Library';
  String get chooseFromGalleryDesc =>
      isVietnamese ? 'Chọn hình ảnh đã lưu trên thiết bị của bạn' : 'Select images saved on your device';
  String get photoCapturedSuccess =>
      isVietnamese ? 'Đã chụp và lưu ảnh thành công!' : 'Photo captured and saved successfully!';
  String get photoSelectedSuccess =>
      isVietnamese ? 'Đã chọn ảnh thành công!' : 'Photo selected successfully!';
  String get optionsAvailableSuffix =>
      isVietnamese ? 'tùy chọn khả dụng' : 'available options';
  String get searchOptionsHint =>
      isVietnamese ? 'Tìm kiếm tùy chọn...' : 'Search options...';
  String get noMatchingOptions =>
      isVietnamese ? 'Không tìm thấy tùy chọn phù hợp' : 'No matching options found';
  String get selectOptionPrefix =>
      isVietnamese ? 'Chọn ' : 'Select ';

  // Edit Customer Dialog
  String get editCustomerTitle =>
      isVietnamese ? 'Sửa thông tin khách hàng' : 'Edit Customer Information';
  String get noChangesMade =>
      isVietnamese ? 'Không có thay đổi nào được thực hiện.' : 'No changes were made.';
  String get fieldsUpdatedSuccess =>
      isVietnamese ? 'Đã cập nhật thông tin thành công!' : 'Customer information updated successfully!';
  String get updateError =>
      isVietnamese ? 'Lỗi cập nhật: ' : 'Update error: ';
  String get sectionIdentityCategory =>
      isVietnamese ? '1. Định danh & Phân loại' : '1. Identity & Classification';
  String get sectionContactAddress =>
      isVietnamese ? '2. Thông tin liên hệ & Địa chỉ' : '2. Contact & Address';
  String get sectionGpsCheckin =>
      isVietnamese ? '3. Tọa độ GPS & Check-in' : '3. GPS Coordinates & Check-in';
  String get saveChangesCaps =>
      isVietnamese ? 'LƯU THAY ĐỔI' : 'SAVE CHANGES';
  String get cancelAction =>
      isVietnamese ? 'HỦY' : 'CANCEL';
}


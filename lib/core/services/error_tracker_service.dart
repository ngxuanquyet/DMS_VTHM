import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/error_record.dart';
import '../utils/account_key.dart';

/// Gửi một mẻ lỗi lên máy chủ; trả về các mã lỗi máy chủ đã có (mới + trùng) để gỡ khỏi hàng đợi.
typedef ErrorUploader = Future<List<String>> Function(List<Map<String, dynamic>> errors);

/// Dịch vụ theo dõi, sinh mã lỗi định danh và gửi lỗi về máy chủ (`POST /dms/client-errors`).
///
/// Thay kênh Telegram cũ (26/10/2026): app không còn giữ bot token. Lỗi lưu trong máy trước, gửi theo mẻ khi đã đăng
/// nhập; gửi hỏng (mất mạng, chưa đăng nhập) thì để lại hàng đợi, lần ghi lỗi sau hoặc lần đăng nhập sau gửi bù.
class ErrorTrackerService {
  static final ErrorTrackerService instance = ErrorTrackerService._internal();

  ErrorTrackerService._internal();

  final List<ErrorRecord> _recentErrors = [];

  /// Trần một mẻ gửi — khớp `ClientErrorService::MAX_PER_CALL` phía máy chủ.
  static const int _maxPerUpload = 50;

  /// Khoá cấu hình Telegram của bản cũ — xoá khỏi máy ở lần mở đầu (có thể còn bot token người dùng đã lưu).
  static const List<String> _legacyTelegramPrefKeys = [
    'vthm_telegram_bot_token',
    'vthm_telegram_chat_id',
    'vthm_telegram_log_enabled',
  ];

  ErrorUploader? _uploader;
  Timer? _flushTimer;
  bool _flushing = false;

  bool _isInitialized = false;

  /// Giữ sẵn từ `initialize()` để các hàm ghi lỗi (đồng bộ) đọc được người đang đăng nhập.
  SharedPreferences? _prefs;

  /// Danh sách lỗi gần đây (tối đa 100 lỗi trong bộ nhớ)
  List<ErrorRecord> get recentErrors => List.unmodifiable(_recentErrors);

  /// Khởi tạo dịch vụ và tải lịch sử lỗi gần nhất từ bộ nhớ lưu trữ
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      for (final key in _legacyTelegramPrefKeys) {
        await prefs.remove(key);
      }
      final savedLogs = prefs.getString(AppConstants.keyRecentErrorLogs);
      if (savedLogs != null && savedLogs.isNotEmpty) {
        final decoded = jsonDecode(savedLogs);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _recentErrors.add(ErrorRecord.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ErrorTrackerService] Lỗi tải lịch sử lỗi: $e');
    }
  }

  /// Người đang đăng nhập để gắn vào lỗi: "Tên hiển thị (TK: username, mã NV: VTG123)" — đọc hồ sơ lưu trong máy
  /// (`AppConstants.keyUserData`). Bỏ phần trống; chưa đăng nhập / chưa khởi tạo ⇒ `null` (tin hiện "Chưa xác định").
  String? currentAccountLabel() => accountLabelFromJson(_prefs?.getString(AppConstants.keyUserData));

  /// Khoá tài khoản đang đăng nhập (`cacheAccountKey` — `usr_user.id`); `null` khi chưa đăng nhập.
  String? _ownerKey() => _prefs == null ? null : cacheAccountKey(_prefs!);

  /// Khoá tài khoản đang đăng nhập — màn nhật ký lỗi dùng để phân biệt lỗi "chờ chính chủ đăng nhập".
  String? get currentOwnerKey => _ownerKey();

  /// Định dạng của [currentAccountLabel] từ chuỗi JSON hồ sơ — tách riêng để test không phụ thuộc bộ nhớ máy.
  static String? accountLabelFromJson(String? raw) {
    try {
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final name = (map['display_name'] ?? map['name'])?.toString().trim() ?? '';
      final username = map['username']?.toString().trim() ?? '';
      final code = (map['employee_code'] ?? map['employeeId'])?.toString().trim() ?? '';
      final ids = [
        if (username.isNotEmpty) 'TK: $username',
        if (code.isNotEmpty) 'mã NV: $code',
      ].join(', ');
      if (name.isEmpty) return ids.isEmpty ? null : ids;
      return ids.isEmpty ? name : '$name ($ids)';
    } catch (_) {
      return null;
    }
  }

  /// Sinh mã lỗi duy nhất theo quy chuẩn: ERR-[MODULE]-[STATUS]-[HASH]
  String generateErrorId(String module, int? statusCode) {
    final statusStr = statusCode != null ? '$statusCode' : '000';
    final randomHex = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0').toUpperCase();
    return 'ERR-$module-$statusStr-$randomHex';
  }

  /// Nhận diện phân hệ từ đường dẫn endpoint hoặc loại lỗi
  String detectModule(String? path, {DioExceptionType? dioType}) {
    if (dioType == DioExceptionType.connectionTimeout ||
        dioType == DioExceptionType.receiveTimeout ||
        dioType == DioExceptionType.sendTimeout ||
        dioType == DioExceptionType.connectionError) {
      return 'NET';
    }
    if (path == null || path.isEmpty) return 'SYS';

    final p = path.toLowerCase();
    if (p.contains('/auth/')) return 'AUTH';
    if (p.contains('/visits') || p.contains('/dms/visits')) return 'VISIT';
    if (p.contains('/customer') || p.contains('/crm/customer') || p.contains('/dealers')) return 'CUST';
    if (p.contains('/attendance')) return 'ATTEND';
    if (p.contains('/location')) return 'LOC';
    if (p.contains('/form')) return 'FORM';
    if (p.contains('/sync')) return 'SYNC';
    if (p.contains('/route') || p.contains('/routes')) return 'ROUTE';
    if (p.contains('/notification')) return 'NOTIF';
    if (p.contains('/travel')) return 'TRAVEL';
    if (p.contains('/position')) return 'POS';
    if (p.contains('/profile') || p.contains('/user/')) return 'PROFILE';
    if (p.contains('/dashboard') || p.contains('/home')) return 'HOME';
    if (p.contains('/rule') || p.contains('/mobile-rules')) return 'RULES';

    return 'SYS';
  }

  /// Ghi nhận và theo dõi lỗi phát sinh từ Dio
  ErrorRecord trackDioError(
    DioException dioError, {
    String? currentUsername,
    double? lat,
    double? lng,
  }) {
    final path = dioError.requestOptions.path;
    final statusCode = dioError.response?.statusCode;
    final module = detectModule(path, dioType: dioError.type);
    final errorId = generateErrorId(module, statusCode);

    // Trích xuất server code và message
    String? serverCode;
    String message = dioError.message ?? 'Lỗi kết nối máy chủ';
    dynamic responseData = dioError.response?.data;

    if (responseData is Map) {
      serverCode = responseData['code']?.toString();
      if (responseData['message'] != null && responseData['message'].toString().isNotEmpty) {
        message = responseData['message'].toString();
      }
    } else if (dioError.type == DioExceptionType.connectionTimeout ||
        dioError.type == DioExceptionType.receiveTimeout ||
        dioError.error is SocketException) {
      message = 'Không có kết nối mạng hoặc kết nối máy chủ quá hạn (Timeout).';
    }

    final curl = _generateCurl(dioError.requestOptions);
    final sanitizedRequest = _maskSensitiveData(dioError.requestOptions.data);

    final record = ErrorRecord(
      id: errorId,
      timestamp: DateTime.now(),
      module: module,
      statusCode: statusCode,
      serverCode: serverCode,
      message: message,
      endpoint: dioError.requestOptions.uri.toString(),
      method: dioError.requestOptions.method.toUpperCase(),
      requestData: sanitizedRequest,
      responseData: responseData,
      curlCommand: curl,
      username: currentUsername ?? currentAccountLabel(),
      deviceInfo: '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      ownerAccountKey: _ownerKey(),
      lat: lat,
      lng: lng,
    );

    _addRecord(record);

    _scheduleFlush();

    return record;
  }

  /// Ghi nhận lỗi logic / Dart Exception nội bộ
  ErrorRecord trackCustomError({
    required String message,
    String module = 'SYS',
    int? statusCode,
    String? serverCode,
    String? endpoint,
    String? method,
    dynamic requestData,
    dynamic responseData,
    StackTrace? stackTrace,
    String? currentUsername,
  }) {
    final errorId = generateErrorId(module, statusCode);
    final record = ErrorRecord(
      id: errorId,
      timestamp: DateTime.now(),
      module: module,
      statusCode: statusCode,
      serverCode: serverCode,
      message: message,
      endpoint: endpoint,
      method: method,
      requestData: _maskSensitiveData(requestData),
      responseData: responseData,
      stackTrace: stackTrace?.toString(),
      username: currentUsername ?? currentAccountLabel(),
      deviceInfo: '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      ownerAccountKey: _ownerKey(),
    );

    _addRecord(record);
    _scheduleFlush();
    return record;
  }

  void _addRecord(ErrorRecord record) {
    _recentErrors.insert(0, record);
    if (_recentErrors.length > 100) {
      // Bỏ bản cũ nhất KHÔNG còn phải gửi (đã gửi, hoặc 401/404 không bao giờ gửi) trước; chỉ khi cả 100 đều đang chờ
      // gửi mới phải bỏ bản cũ nhất — không thì một màn hỏi 404 liên tục đẩy mất lỗi 500 thật đang chờ.
      final sentIdx = _recentErrors.lastIndexWhere((e) => e.sentToServer || !shouldUpload(e));
      _recentErrors.removeAt(sentIdx >= 0 ? sentIdx : _recentErrors.length - 1);
    }
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      // Lưu đủ cả 100 — cắt bớt ở đây là mất lỗi chưa gửi khi app bị tắt lúc đang mất sóng.
      final toSave = _recentErrors.map((e) => e.toJson()).toList();
      await prefs.setString(AppConstants.keyRecentErrorLogs, jsonEncode(toSave));
    } catch (_) {}
  }

  /// Xóa toàn bộ lịch sử lỗi
  Future<void> clearErrors() async {
    _recentErrors.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyRecentErrorLogs);
  }

  /// Gắn hàm gửi lỗi (do tầng mạng cung cấp — tránh phụ thuộc vòng với `api_client.dart`) rồi gửi bù hàng đợi.
  void attachUploader(ErrorUploader uploader) {
    _uploader = uploader;
    _scheduleFlush();
  }

  /// Lỗi có cần gửi lên máy chủ không.
  ///
  /// Bỏ 401 (hết phiên — luồng làm mới token tự xử lý) và 404 (không phải sự cố máy chủ hay sập app); lỗi của chính
  /// lời gọi gửi lỗi cũng bỏ, không thì gửi hỏng sinh lỗi mới để gửi, vòng lặp không dừng.
  static bool shouldUpload(ErrorRecord record) {
    if (record.statusCode == 404 || record.statusCode == 401) return false;
    if (record.endpoint?.contains('/dms/client-errors') ?? false) return false;
    return true;
  }

  /// Gom lỗi dồn dập (một màn gọi 5 API cùng hỏng) vào một lượt gửi.
  ///
  /// KHÔNG đặt lại hẹn giờ đang chờ: lỗi lặp mỗi 2 giây mà cứ dời hẹn thì không bao giờ gửi được, đúng lúc cần nhất.
  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(const Duration(seconds: 3), () => unawaited(flushPending()));
  }

  /// Gửi các lỗi chưa gửi (tối đa một mẻ). Gọi lại an toàn: đang gửi thì bỏ qua lượt này.
  Future<void> flushPending() async {
    final uploader = _uploader;
    if (uploader == null || _flushing) return;
    // Giữ cờ TRƯỚC mọi `await`: hai lượt gọi gần nhau (đăng nhập + hẹn giờ) không được cùng lọt qua và gửi trùng mẻ.
    _flushing = true;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken) ?? prefs.getString(AppConstants.keyAuthToken);
      if (token == null || token.isEmpty) return; // chưa đăng nhập — máy chủ chỉ nhận lỗi của người đã đăng nhập
      final me = cacheAccountKey(prefs);
      if (me == null) return;

      final pending = _recentErrors.where((e) => isQueuedFor(e, me)).take(_maxPerUpload).toList();
      if (pending.isEmpty) return;

      final refs = (await uploader(pending.map(toUploadJson).toList())).toSet();
      var acked = 0;
      for (final e in pending) {
        if (refs.contains(serverRef(e.id))) {
          e.sentToServer = true;
          acked++;
        }
      }
      await _saveToStorage();
      // Hàng đợi dài hơn một mẻ (máy mất sóng lâu) ⇒ gửi tiếp mẻ sau; mẻ này không được nhận thì dừng, chờ lần sau.
      if (acked > 0 && _recentErrors.any((e) => isQueuedFor(e, me))) {
        _scheduleFlush();
      }
    } catch (e) {
      debugPrint('[ErrorTrackerService] Chưa gửi được lỗi về máy chủ, giữ lại hàng đợi: $e');
    } finally {
      _flushing = false;
    }
  }

  /// Mã lỗi theo cách máy chủ lưu (cắt khoảng trắng, tối đa 40 ký tự) — so `refs` trả về bằng dạng này, không thì
  /// lỗi đã được nhận vẫn nằm hàng đợi và bị gửi lại mãi.
  static String serverRef(String id) {
    final t = id.trim();
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  /// Lỗi còn chờ gửi dưới phiên của [me]: của chính người đó, hoặc lỗi trước khi đăng nhập (chủ hệ thống chốt gửi bù
  /// khi đăng nhập, 26/10/2026). Lỗi của tài khoản khác nằm lại trong máy, chờ chính chủ đăng nhập.
  static bool isQueuedFor(ErrorRecord e, String me) =>
      !e.sentToServer && shouldUpload(e) && (e.ownerAccountKey == null || e.ownerAccountKey == me);

  /// Hình dạng một lỗi gửi lên máy chủ (khớp `ClientErrorReportForm`). Không gửi tên/TK — máy chủ lấy người từ phiên
  /// đăng nhập; không gửi toạ độ.
  static Map<String, dynamic> toUploadJson(ErrorRecord e) {
    final json = e.toJson()
      ..remove('username')
      ..remove('lat')
      ..remove('lng')
      ..remove('sentToServer')
      ..remove('ownerAccountKey');
    // Giờ máy kèm múi giờ (UTC) — `toIso8601String()` của giờ địa phương không có offset, máy chủ sẽ đoán sai múi.
    json['timestamp'] = e.timestamp.toUtc().toIso8601String();
    json['appVersion'] = AppConstants.appVersionBuild.replaceFirst('Phiên bản ', '');
    return json;
  }

  dynamic _maskSensitiveData(dynamic data) {
    if (data == null) return null;
    const sensitiveKeys = {
      'password',
      'pass',
      'token',
      'access_token',
      'refresh_token',
      'auth_token',
      'secret',
      'authorization',
    };

    if (data is Map) {
      final copy = <String, dynamic>{};
      data.forEach((key, value) {
        final k = key.toString().toLowerCase();
        if (sensitiveKeys.contains(k)) {
          copy[key.toString()] = '******';
        } else if (value is Map || value is List) {
          copy[key.toString()] = _maskSensitiveData(value);
        } else {
          copy[key.toString()] = value;
        }
      });
      return copy;
    } else if (data is List) {
      return data.map((e) => _maskSensitiveData(e)).toList();
    }
    return data;
  }

  String _generateCurl(RequestOptions options) {
    final components = <String>['curl -X ${options.method.toUpperCase()}'];

    // Headers (che Authorization)
    options.headers.forEach((k, v) {
      if (k.toLowerCase() == 'authorization') {
        components.add("-H '$k: Bearer <masked_token>'");
      } else if (k.toLowerCase() != 'content-length') {
        components.add("-H '$k: $v'");
      }
    });

    components.add("'${options.uri.toString()}'");

    final data = options.data;
    if (data != null) {
      final masked = _maskSensitiveData(data);
      try {
        final jsonStr = jsonEncode(masked).replaceAll("'", r"'\''");
        components.add("-d '$jsonStr'");
      } catch (_) {
        components.add("-d '${masked.toString()}'");
      }
    }

    return components.join(' ');
  }
}

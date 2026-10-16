import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';
import '../models/error_record.dart';

/// Dịch vụ theo dõi, sinh mã lỗi định danh và bắn cảnh báo về Telegram
class ErrorTrackerService {
  static final ErrorTrackerService instance = ErrorTrackerService._internal();

  ErrorTrackerService._internal();

  final List<ErrorRecord> _recentErrors = [];
  final Map<String, DateTime> _lastSentErrors = {};
  final Dio _telegramDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  bool _isInitialized = false;

  /// Danh sách lỗi gần đây (tối đa 100 lỗi trong bộ nhớ)
  List<ErrorRecord> get recentErrors => List.unmodifiable(_recentErrors);

  /// Khởi tạo dịch vụ và tải lịch sử lỗi gần nhất từ bộ nhớ lưu trữ
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
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
      username: currentUsername,
      deviceInfo: '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      lat: lat,
      lng: lng,
    );

    _addRecord(record);

    // Bắn thông báo về Telegram không đồng bộ (chạy ngầm không chặn luồng chính)
    unawaited(_sendToTelegram(record));

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
      username: currentUsername,
      deviceInfo: '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
    );

    _addRecord(record);
    unawaited(_sendToTelegram(record));
    return record;
  }

  void _addRecord(ErrorRecord record) {
    _recentErrors.insert(0, record);
    if (_recentErrors.length > 100) {
      _recentErrors.removeLast();
    }
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _recentErrors.take(50).map((e) => e.toJson()).toList();
      await prefs.setString(AppConstants.keyRecentErrorLogs, jsonEncode(toSave));
    } catch (_) {}
  }

  /// Xóa toàn bộ lịch sử lỗi
  Future<void> clearErrors() async {
    _recentErrors.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyRecentErrorLogs);
  }

  /// Lấy cấu hình Telegram hiện tại
  Future<Map<String, dynamic>> getTelegramConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyTelegramBotToken) ?? AppConstants.defaultTelegramBotToken;
    final chatId = prefs.getString(AppConstants.keyTelegramChatId) ?? AppConstants.defaultTelegramChatId;
    final enabled = prefs.getBool(AppConstants.keyTelegramLogEnabled) ?? true;
    return {
      'botToken': token,
      'chatId': chatId,
      'enabled': enabled,
    };
  }

  /// Cập nhật cấu hình Telegram
  Future<void> saveTelegramConfig({
    required String botToken,
    required String chatId,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyTelegramBotToken, botToken.trim());
    await prefs.setString(AppConstants.keyTelegramChatId, chatId.trim());
    await prefs.setBool(AppConstants.keyTelegramLogEnabled, enabled);
  }

  /// Gửi thử một tin nhắn test về Telegram để kiểm tra kết nối
  Future<bool> testTelegramConnection({
    String? botToken,
    String? chatId,
  }) async {
    final config = await getTelegramConfig();
    final token = (botToken != null && botToken.isNotEmpty) ? botToken : config['botToken'] as String;
    final chat = (chatId != null && chatId.isNotEmpty) ? chatId : config['chatId'] as String;

    if (token.isEmpty || chat.isEmpty) {
      throw const AppException('Vui lòng nhập Bot Token và Chat ID trước khi kiểm tra.');
    }

    final testMessage = '''
<b>[DMS TEST ALERT]</b>
Kính gửi Quản trị viên,
Đây là tin nhắn kiểm tra cấu hình cảnh báo lỗi hệ thống <b>DMS VTHM</b>.
• <b>Thời gian:</b> ${DateTime.now().toLocal()}
• <b>Trạng thái:</b> Kết nối thành công!
''';

    try {
      final response = await _telegramDio.post(
        'https://api.telegram.org/bot$token/sendMessage',
        data: {
          'chat_id': chat,
          'text': testMessage,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final desc = e.response?.data is Map ? e.response?.data['description'] : e.message;
      throw AppException('Telegram từ chối gửi tin: $desc');
    } catch (e) {
      throw AppException('Lỗi gửi tin Telegram: $e');
    }
  }

  /// Gửi tin nhắn lỗi về Telegram theo định dạng HTML
  Future<void> _sendToTelegram(ErrorRecord record) async {
    try {
      final config = await getTelegramConfig();
      final bool enabled = config['enabled'] as bool? ?? true;
      final String token = (config['botToken'] as String?)?.trim() ?? '';
      final String chatId = (config['chatId'] as String?)?.trim() ?? '';

      if (!enabled || token.isEmpty || chatId.isEmpty) {
        return;
      }

      // Bỏ qua gửi cảnh báo Telegram đối với mã 404 (Không tìm thấy tài nguyên / trang)
      // và mã 401 (Hết hạn phiên hoặc sai thông tin đăng nhập cần nhập lại).
      // Đây là các mã trạng thái chuẩn của HTTP/REST client, không phải sự cố máy chủ (5xx)
      // hay lỗi sập app. Lỗi này vẫn được lưu đầy đủ trong bộ nhớ Recent Errors của app để tra cứu.
      if (record.statusCode == 404 || record.statusCode == 401) {
        debugPrint('[ErrorTrackerService] Bỏ qua gửi Telegram đối với mã ${record.statusCode} (${record.endpoint})');
        return;
      }

      // Chống spam (Throttling): Không bắn lại cùng endpoint & statusCode trong vòng 30s
      final throttleKey = '${record.endpoint}_${record.statusCode}';
      final now = DateTime.now();
      if (_lastSentErrors.containsKey(throttleKey)) {
        final lastSent = _lastSentErrors[throttleKey]!;
        if (now.difference(lastSent).inSeconds < 30) {
          debugPrint('[ErrorTrackerService] Bỏ qua gửi Telegram do trùng lặp gần đây ($throttleKey)');
          return;
        }
      }
      _lastSentErrors[throttleKey] = now;

      final messageText = formatTelegramMessage(record);

      final response = await _telegramDio.post(
        'https://api.telegram.org/bot$token/sendMessage',
        data: {
          'chat_id': chatId,
          'text': messageText,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        },
      );

      if (response.statusCode == 200) {
        record.sentToTelegram = true;
      }
    } catch (e) {
      debugPrint('[ErrorTrackerService] Không thể gửi cảnh báo lỗi về Telegram: $e');
    }
  }

  /// Định dạng tin nhắn HTML theo chuẩn Telegram
  String formatTelegramMessage(ErrorRecord record) {
    final buffer = StringBuffer();
    final timeStr = _formatDateTime(record.timestamp);
    final userStr = record.username != null && record.username!.isNotEmpty ? record.username! : 'Chưa xác định';
    final deviceStr = record.deviceInfo ?? 'Thiết bị di động';

    buffer.writeln('🚨 <b>[DMS ERROR ALERT]</b> — <code>${record.id}</code>\n');

    buffer.writeln('📌 <b>1. THÔNG TIN ĐỊNH DANH</b>');
    buffer.writeln('• <b>Mã tra cứu:</b> <code>${record.id}</code>');
    buffer.writeln('• <b>Thời gian:</b> $timeStr');
    buffer.writeln('• <b>Tài khoản:</b> $userStr');
    buffer.writeln('• <b>Thiết bị:</b> ${_escapeHtml(deviceStr)}');

    buffer.writeln('\n🌐 <b>2. THÔNG TIN API & LỖI</b>');
    if (record.endpoint != null) {
      buffer.writeln('• <b>Endpoint:</b> <code>${record.method ?? 'GET'} ${_escapeHtml(record.endpoint!)}</code>');
    }
    buffer.writeln('• <b>Mã HTTP:</b> ${record.statusCode ?? 'N/A'}');
    if (record.serverCode != null) {
      buffer.writeln('• <b>Mã server (code):</b> <code>${_escapeHtml(record.serverCode!)}</code>');
    }
    buffer.writeln('• <b>Thông báo (message):</b>');
    buffer.writeln('  <i>${_escapeHtml(record.message)}</i>');

    // Chi tiết trường lỗi errors nếu có
    if (record.responseData is Map && (record.responseData as Map).containsKey('errors')) {
      final errors = (record.responseData as Map)['errors'];
      if (errors != null) {
        buffer.writeln('\n📋 <b>3. CHI TIẾT LỖI TỪNG TRƯỜNG (errors)</b>');
        final errorsStr = _formatJson(errors);
        buffer.writeln('<pre>${_escapeHtml(errorsStr)}</pre>');
      }
    }

    // Tọa độ GPS nếu có
    if (record.lat != null && record.lng != null) {
      buffer.writeln('\n📍 <b>4. TOẠ ĐỘ GPS</b>');
      buffer.writeln('• Vị trí: <code>${record.lat}, ${record.lng}</code>');
    }

    // Lệnh cURL sẵn sàng copy-paste
    if (record.curlCommand != null && record.curlCommand!.isNotEmpty) {
      buffer.writeln('\n💻 <b>5. LỆNH cURL ĐỂ TEST LẠI</b>');
      final safeCurl = record.curlCommand!.length > 800
          ? '${record.curlCommand!.substring(0, 800)}...'
          : record.curlCommand!;
      buffer.writeln('<pre>${_escapeHtml(safeCurl)}</pre>');
    } else if (record.stackTrace != null && record.stackTrace!.isNotEmpty) {
      buffer.writeln('\n💻 <b>5. STACK TRACE</b>');
      final lines = record.stackTrace!.split('\n').take(8).join('\n');
      buffer.writeln('<pre>${_escapeHtml(lines)}</pre>');
    }

    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min:$s';
  }

  String _formatJson(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
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

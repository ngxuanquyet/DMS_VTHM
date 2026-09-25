import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor chuyên biệt ghi log Request, Response và cURL ra Terminal.
/// - In chi tiết URL, Method, Headers, Body dưới dạng JSON đẹp mắt.
/// - Tự động tạo lệnh cURL sẵn sàng copy-paste để test trong Terminal hoặc Postman.
/// - Đo thời gian phản hồi (ms).
/// - Chia nhỏ các dòng dài để không bị Android/Flutter cắt bớt text.
class AppApiLoggerInterceptor extends Interceptor {
  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

  void _safePrint(String text) {
    // Tránh bị giới hạn buffer 1024 bytes của logcat/terminal
    const maxChunkSize = 800;
    if (text.length <= maxChunkSize) {
      debugPrint(text);
      return;
    }
    for (var i = 0; i < text.length; i += maxChunkSize) {
      final end = (i + maxChunkSize < text.length) ? i + maxChunkSize : text.length;
      debugPrint(text.substring(i, end));
    }
  }

  String _generateCurl(RequestOptions options) {
    final components = <String>['curl -X ${options.method.toUpperCase()}'];

    // Headers
    options.headers.forEach((k, v) {
      if (k.toLowerCase() != 'content-length') {
        components.add("-H '$k: $v'");
      }
    });

    // Query params & URL
    final uri = options.uri.toString();
    components.add("'$uri'");

    // Body
    final data = options.data;
    if (data != null) {
      if (data is FormData) {
        for (final field in data.fields) {
          components.add("-F '${field.key}=${field.value}'");
        }
        for (final file in data.files) {
          components.add("-F '${file.key}=@<binary_file: ${file.value.filename}>'");
        }
      } else if (data is Map || data is List) {
        try {
          final jsonStr = jsonEncode(data).replaceAll("'", r"'\''");
          components.add("-d '$jsonStr'");
        } catch (_) {
          components.add("-d '${data.toString()}'");
        }
      } else {
        components.add("-d '${data.toString().replaceAll("'", r"'\''")}'");
      }
    }

    return components.join(' \\\n  ');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['request_start_time'] = DateTime.now().millisecondsSinceEpoch;

    final buffer = StringBuffer();
    buffer.writeln('\n┌── 🌐 [API REQUEST] ${options.method.toUpperCase()} ${options.uri}');
    
    // Headers
    if (options.headers.isNotEmpty) {
      buffer.writeln('│ 🔹 Headers:');
      options.headers.forEach((k, v) {
        if (k.toLowerCase() == 'authorization' && v.toString().length > 30) {
          final masked = '${v.toString().substring(0, 15)}...${v.toString().substring(v.toString().length - 6)}';
          buffer.writeln('│    $k: $masked');
        } else {
          buffer.writeln('│    $k: $v');
        }
      });
    }

    // Body
    final data = options.data;
    if (data != null) {
      buffer.writeln('│ 📦 Body:');
      if (data is FormData) {
        buffer.writeln('│    [FormData] fields: ${data.fields.map((e) => "${e.key}: ${e.value}").join(", ")}');
        buffer.writeln('│    [FormData] files: ${data.files.map((e) => "${e.key}: ${e.value.filename} (${e.value.length} B)").join(", ")}');
      } else if (data is Map || data is List) {
        try {
          final formatted = _encoder.convert(data);
          for (final line in formatted.split('\n')) {
            buffer.writeln('│    $line');
          }
        } catch (_) {
          buffer.writeln('│    $data');
        }
      } else {
        buffer.writeln('│    $data');
      }
    }

    // cURL Command
    buffer.writeln('│ 📋 cURL Command:');
    for (final line in _generateCurl(options).split('\n')) {
      buffer.writeln('│    $line');
    }

    buffer.write('└── ──────────────────────────────────────────────');
    _safePrint(buffer.toString());

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra['request_start_time'] as int?;
    final elapsed = startTime != null ? DateTime.now().millisecondsSinceEpoch - startTime : null;
    final elapsedStr = elapsed != null ? '${elapsed}ms' : '';

    final buffer = StringBuffer();
    final statusCode = response.statusCode ?? 200;
    buffer.writeln('\n┌── 📥 [API RESPONSE $statusCode] ($elapsedStr) ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri}');

    final data = response.data;
    if (data != null) {
      buffer.writeln('│ 📄 Response Body:');
      if (data is Map || data is List) {
        try {
          final formatted = _encoder.convert(data);
          for (final line in formatted.split('\n')) {
            buffer.writeln('│    $line');
          }
        } catch (_) {
          buffer.writeln('│    $data');
        }
      } else {
        buffer.writeln('│    $data');
      }
    } else {
      buffer.writeln('│ (No Content)');
    }

    buffer.write('└── ──────────────────────────────────────────────');
    _safePrint(buffer.toString());

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra['request_start_time'] as int?;
    final elapsed = startTime != null ? DateTime.now().millisecondsSinceEpoch - startTime : null;
    final elapsedStr = elapsed != null ? '${elapsed}ms' : '';

    final buffer = StringBuffer();
    final statusCode = err.response?.statusCode ?? 'N/A';
    buffer.writeln('\n┌── ❌ [API ERROR $statusCode] ($elapsedStr) ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri}');
    buffer.writeln('│ ⚠️ Error Type: ${err.type}');
    buffer.writeln('│ ⚠️ Message: ${err.message}');

    final errData = err.response?.data;
    if (errData != null) {
      buffer.writeln('│ 📄 Error Response:');
      if (errData is Map || errData is List) {
        try {
          final formatted = _encoder.convert(errData);
          for (final line in formatted.split('\n')) {
            buffer.writeln('│    $line');
          }
        } catch (_) {
          buffer.writeln('│    $errData');
        }
      } else {
        buffer.writeln('│    $errData');
      }
    }

    buffer.write('└── ──────────────────────────────────────────────');
    _safePrint(buffer.toString());

    handler.next(err);
  }
}

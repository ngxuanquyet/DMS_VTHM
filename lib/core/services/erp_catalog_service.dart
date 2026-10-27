import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../utils/string_utils.dart';
import 'erp_link_request_service.dart';

/// Một khách ERP trong danh mục tải về máy (`GET /crm/customer-erp-link-requests/catalog`, #24327). Không có SĐT/MST.
class ErpCatalogItem {
  /// Mã khách ERP — CHUỖI, có thể có số 0 đầu.
  final String code;
  final String name;
  final String? shortName;
  final String? address;

  /// Kênh bán hàng Bravo (`sales_channel.id`) — quyết vai nào chọn được khách này.
  final int? channelId;
  final String? channelName;

  /// Chuỗi đã bỏ dấu + chữ thường để tìm (tên · mã · tên viết tắt · địa chỉ).
  final String _haystack;

  ErpCatalogItem({
    required this.code,
    required this.name,
    this.shortName,
    this.address,
    this.channelId,
    this.channelName,
  }) : _haystack = StringUtils.toUnaccentedLower([name, code, shortName ?? '', address ?? ''].join(' '));

  factory ErpCatalogItem.fromJson(Map<String, dynamic> json) => ErpCatalogItem(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        shortName: json['short_name']?.toString(),
        address: json['address']?.toString(),
        channelId: (json['channel_id'] as num?)?.toInt(),
        channelName: json['channel_name']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'short_name': shortName,
        'address': address,
        'channel_id': channelId,
        'channel_name': channelName,
      };
}

/// Danh mục khách ERP + bộ kênh của từng vai (`owner`/`showroom`/`c2`; danh sách rỗng = mọi kênh).
class ErpCatalog {
  final Map<String, List<int>> roles;
  final List<ErpCatalogItem> items;
  final Map<String, ErpCatalogItem> _byCode;

  ErpCatalog({required this.roles, required this.items}) : _byCode = {for (final i in items) i.code: i};

  factory ErpCatalog.fromJson(Map<String, dynamic> data) {
    final rawRoles = data['roles'] is Map ? Map<String, dynamic>.from(data['roles'] as Map) : const <String, dynamic>{};
    return ErpCatalog(
      roles: {
        for (final role in ErpLinkRole.all)
          role: rawRoles[role] is List
              ? (rawRoles[role] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList()
              : const <int>[],
      },
      items: data['items'] is List
          ? (data['items'] as List)
              .whereType<Map>()
              .map((e) => ErpCatalogItem.fromJson(Map<String, dynamic>.from(e)))
              .where((i) => i.code.isNotEmpty)
              .toList()
          : const [],
    );
  }

  ErpCatalogItem? byCode(String code) => _byCode[code];

  /// Các vai một khách thuộc kênh [channelId] được nối — theo thứ tự [ErpLinkRole.all]. Không có trong danh mục ⇒ không vai nào.
  List<String> rolesFor(int? channelId) => [
        for (final role in ErpLinkRole.all)
          if ((roles[role] ?? const []).isEmpty || (channelId != null && roles[role]!.contains(channelId))) role,
      ];

  /// Tìm trên máy theo tên/mã/tên viết tắt/địa chỉ, gõ không dấu được; từ 2 ký tự; khớp đầu tên/mã xếp trước.
  List<ErpCatalogItem> search(String query, {int limit = 30}) {
    final q = StringUtils.toUnaccentedLower(query).trim();
    if (q.length < 2) return const [];
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hits = items.where((i) => words.every(i._haystack.contains)).toList();
    int rank(ErpCatalogItem i) {
      if (i.code.toLowerCase() == q) return 0;
      if (i.code.toLowerCase().startsWith(q) || StringUtils.toUnaccentedLower(i.name).startsWith(q)) return 1;
      return StringUtils.toUnaccentedLower(i.name).contains(q) ? 2 : 3;
    }

    hits.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return hits.take(limit).toList();
  }
}

final erpCatalogServiceProvider = Provider<ErpCatalogService>((ref) {
  return ErpCatalogService(ref.watch(apiClientProvider));
});

/// Danh mục khách ERP cho bước nối điểm bán — CHẠY ĐƯỢC KHI MẤT MẠNG (chủ hệ thống chốt 27/10/2026, #24327).
///
/// Cùng khuôn với `GeoCatalogService`: bộ nhớ → tệp trong thư mục tài liệu của app → server (khi tới hạn hỏi lại). Lỗi mạng
/// KHÔNG ném — trả bản đang có; chưa từng tải ⇒ `null` (bước nối chỉ còn ô "Chưa xác định NPP").
class ErpCatalogService {
  final ApiClient _apiClient;

  ErpCatalogService(this._apiClient);

  static ErpCatalog? _memory;
  static Future<ErpCatalog?>? _loading;
  static DateTime? _checkedAt;

  /// Hỏi lại server sau 1 giờ — admin đổi kênh theo vai hoặc Bravo thêm khách thì app thấy trong ngày.
  static const _recheckAfter = Duration(hours: 1);

  static const _fileName = 'erp_catalog.json';

  /// Thời hạn làm MỚI khi máy đã có bản lưu — bấm Lưu không treo theo mạng yếu; quá hạn thì dùng bản đã lưu.
  static const _refreshTimeout = Duration(seconds: 6);

  /// Thời hạn tải LẦN ĐẦU (chưa có bản lưu, ~800 KB) — đủ cho mạng 3G; hỏng thì lần Lưu sau thử lại ngay.
  static const _firstTimeout = Duration(seconds: 25);

  /// Nạp danh mục: bộ nhớ → tệp → server (chỉ khi [online] và tới hạn, hoặc [force]). Không ném lỗi.
  Future<ErpCatalog?> load({required bool online, bool force = false}) {
    return _loading ??= _load(online, force).whenComplete(() => _loading = null);
  }

  Future<ErpCatalog?> _load(bool online, bool force) async {
    _memory ??= await _readFile();
    final due = _checkedAt == null || DateTime.now().difference(_checkedAt!) > _recheckAfter;
    if (!online || (_memory != null && !force && !due)) return _memory;

    // Đã có bản lưu ⇒ đóng dấu TRƯỚC khi gọi: lượt lỗi/quá hạn cũng lùi một giờ, không để mỗi lần bấm Lưu lại chờ mạng.
    // Chưa có ⇒ chỉ đóng dấu khi tải xong (bên dưới), lần sau thử lại ngay.
    final coBanLuu = _memory != null;
    if (coBanLuu) _checkedAt = DateTime.now();
    try {
      final response = await _apiClient
          .get('/crm/customer-erp-link-requests/catalog')
          .timeout(coBanLuu ? _refreshTimeout : _firstTimeout);
      final data = response is Map ? response['data'] : null;
      if (data is Map) {
        _checkedAt = DateTime.now();
        _memory = ErpCatalog.fromJson(Map<String, dynamic>.from(data));
        await _writeFile(_memory!);
      }
    } catch (_) {
      // Mất mạng / server lỗi: dùng bản đã lưu.
    }
    return _memory;
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<ErpCatalog?> _readFile() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      return raw is Map ? ErpCatalog.fromJson(Map<String, dynamic>.from(raw)) : null;
    } catch (_) {
      return null; // tệp hỏng ⇒ coi như chưa có
    }
  }

  Future<void> _writeFile(ErpCatalog catalog) async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'roles': catalog.roles,
        'items': catalog.items.map((i) => i.toJson()).toList(),
      }));
      await tmp.rename(f.path);
    } catch (_) {
      // Không ghi được — lần sau tải lại.
    }
  }
}

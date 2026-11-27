import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../utils/string_utils.dart';

/// Một mã hàng thành phẩm (`GET /formfield/product-options/catalog` của One — #25966): `id` = `item_id` (khoá server kiểm),
/// mã ERP, tên Bravo, kích thước + mã 5 số của mẫu (nhãn gọn).
class ProductSkuItem {
  final int id;
  final String code;
  final String name;
  final String size;
  final String design;

  /// Chuỗi đã bỏ dấu + chữ thường để tìm (mã · tên · kích thước · mã 5 số).
  final String _haystack;

  ProductSkuItem({required this.id, required this.code, required this.name, this.size = '', this.design = ''})
      : _haystack = StringUtils.toUnaccentedLower([code, name, size, design].join(' '));

  factory ProductSkuItem.fromJson(Map json) => ProductSkuItem(
        id: (json['id'] is num ? (json['id'] as num).toInt() : int.tryParse('${json['id']}')) ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        size: json['size']?.toString() ?? '',
        design: json['design']?.toString() ?? '',
      );

  /// Ảnh chụp gửi server / lưu trong giá trị ô — server chỉ đọc `id`, dựng lại mã + tên.
  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        if (size.isNotEmpty) 'size': size,
        if (design.isNotEmpty) 'design': design,
      };

  /// Nhãn GỌN `kích thước · mã 5 số` (cùng luật `ProductSkuField::label()` của server); thiếu ⇒ `mã ERP - tên`.
  static String labelOf(Map item) {
    final name = (item['name'] ?? '').toString().trim();
    var size = (item['size'] ?? '').toString().trim();
    var design = (item['design'] ?? '').toString().trim();
    if (size.isEmpty || design.isEmpty) {
      final ms = RegExp(r'([0-9]+[ \t]*[xX×][ \t]*[0-9]+)').firstMatch(name);
      final md = RegExp(r'mã[ \t]*([0-9]{5})(?![0-9])', caseSensitive: false).firstMatch(name);
      size = ms == null ? '' : ms.group(1)!.replaceAll('×', 'X').replaceAll(RegExp(r'[ \t]+'), '').toUpperCase();
      design = md == null ? '' : md.group(1)!;
    }
    if (size.isNotEmpty && design.isNotEmpty) return '$size · $design';
    final code = (item['code'] ?? '').toString();
    return name.isNotEmpty ? '$code - $name' : code;
  }
}

/// Danh mục mã hàng đang dùng (~12.500 mã) — tìm trên máy, chạy được khi mất sóng.
class ProductCatalog {
  final List<ProductSkuItem> items;

  ProductCatalog(this.items);

  factory ProductCatalog.fromJson(dynamic raw) => ProductCatalog([
        for (final e in (raw is List ? raw : const []))
          if (e is Map) ProductSkuItem.fromJson(e),
      ].where((i) => i.id > 0 && i.code.isNotEmpty).toList());

  /// Tìm theo mã / tên / kích thước / mã 5 số (không dấu, mọi từ phải khớp), từ 2 ký tự; mã khớp từ đầu xếp trước.
  List<ProductSkuItem> search(String query, {int limit = 50}) {
    final q = StringUtils.toUnaccentedLower(query).trim();
    if (q.length < 2) return const [];
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hits = items.where((i) => words.every(i._haystack.contains)).toList();
    int rank(ProductSkuItem i) {
      final c = i.code.toLowerCase();
      if (c == q) return 0;
      if (c.startsWith(q)) return 1;
      return 2;
    }

    hits.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.code.compareTo(b.code);
    });
    return hits.take(limit).toList();
  }
}

final productCatalogServiceProvider = Provider<ProductCatalogService>((ref) {
  return ProductCatalogService(ref.watch(apiClientProvider));
});

/// Danh mục mã hàng cho ô MÃ SKU hàng của ta trong ma trận SOS (27/11/2026) — cùng khuôn [ErpCatalogService]: bộ nhớ → tệp
/// trong máy → server (khi tới hạn). Lỗi mạng KHÔNG ném — trả bản đang có; chưa từng tải ⇒ `null` (ô mã báo cần mạng lần đầu).
class ProductCatalogService {
  final ApiClient _apiClient;

  ProductCatalogService(this._apiClient);

  static ProductCatalog? _memory;
  static Future<ProductCatalog?>? _loading;
  static DateTime? _checkedAt;

  /// Danh mục đồng bộ từ Bravo mỗi đêm — hỏi lại sau 12 giờ là đủ.
  static const _recheckAfter = Duration(hours: 12);

  static const _fileName = 'product_catalog.json';

  /// Thời hạn làm MỚI khi đã có bản lưu — không treo ô chọn theo mạng yếu.
  static const _refreshTimeout = Duration(seconds: 8);

  /// Thời hạn tải LẦN ĐẦU (~160 KB nén) — đủ cho mạng 3G.
  static const _firstTimeout = Duration(seconds: 30);

  /// Bản đang nhớ trong tiến trình — `null` khi chưa nạp.
  static ProductCatalog? get memory => _memory;

  /// Nạp danh mục: bộ nhớ → tệp → server (chỉ khi [online] và tới hạn, hoặc [force]). Không ném lỗi.
  Future<ProductCatalog?> load({required bool online, bool force = false}) {
    return _loading ??= _load(online, force).whenComplete(() => _loading = null);
  }

  Future<ProductCatalog?> _load(bool online, bool force) async {
    _memory ??= await _readFile();
    final due = _checkedAt == null || DateTime.now().difference(_checkedAt!) > _recheckAfter;
    if (!online || (_memory != null && !force && !due)) return _memory;
    final coBanLuu = _memory != null;
    if (coBanLuu) _checkedAt = DateTime.now();
    try {
      final response = await _apiClient
          .get('/formfield/product-options/catalog')
          .timeout(coBanLuu ? _refreshTimeout : _firstTimeout);
      final data = response is Map ? response['data'] : null;
      if (data is List) {
        final text = jsonEncode(data);
        final moi = await Isolate.run(() => ProductCatalog.fromJson(jsonDecode(text)));
        if (moi.items.isNotEmpty) {
          _checkedAt = DateTime.now();
          _memory = moi;
          await _writeFile(text);
        }
      }
    } catch (_) {
      // Mất mạng / server lỗi: dùng bản đã lưu.
    }
    return _memory;
  }

  /// Làm mới NGẦM (không chờ) — lúc vào app / nút "Đồng bộ".
  void refreshInBackground({required bool online}) {
    if (!online) return;
    final dangChay = _loading;
    unawaited(dangChay == null ? load(online: true) : dangChay.whenComplete(() => load(online: true)));
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<ProductCatalog?> _readFile() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      return await Isolate.run(() => ProductCatalog.fromJson(jsonDecode(text)));
    } catch (_) {
      return null; // tệp hỏng ⇒ coi như chưa có
    }
  }

  Future<void> _writeFile(String text) async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(text);
      await tmp.rename(f.path);
    } catch (_) {
      // Không ghi được — lần sau tải lại.
    }
  }
}

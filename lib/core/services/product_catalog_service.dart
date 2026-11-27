import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

/// Một mã hàng thành phẩm (`GET /formfield/product-options/catalog` của One — #25966): `id` = `item_id` (khoá server kiểm),
/// mã ERP, tên Bravo, kích thước + mã 5 số của mẫu (nhãn gọn).
class ProductSkuItem {
  final int id;
  final String code;
  final String name;
  final String size;
  final String design;

  ProductSkuItem({required this.id, required this.code, required this.name, this.size = '', this.design = ''});

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

  /// Tìm CHỈ theo KÍCH THƯỚC và MÃ THIẾT KẾ 5 số — cùng luật ô `ref_product` của server (`ReferenceResolver::searchProductItems`,
  /// chủ hệ thống chốt 27/11/2026: không tìm theo mã vật tư / tên hàng). Mỗi từ ([tokens]) phải nằm trong kích thước HOẶC mã thiết
  /// kế; gõ đủ kích thước / mã 5 số thì khớp đúng xếp trước, rồi theo kích thước, mã thiết kế, mã. Từ 2 ký tự.
  List<ProductSkuItem> search(String query, {int limit = 50}) {
    if (query.trim().length < 2) return const [];
    final words = tokens(query);
    if (words.isEmpty) return const [];
    final hits = items
        .where((i) => words.every((w) => i.size.toUpperCase().contains(w) || i.design.contains(w)))
        .toList();
    final sizes = words.where((w) => RegExp(r'^\d+X\d+$').hasMatch(w)).toSet();
    final designs = words.where((w) => RegExp(r'^\d{5}$').hasMatch(w)).toSet();
    // Số vế khớp ĐÚNG (mỗi từ một vế như server) — nhiều hơn xếp trước.
    int exact(ProductSkuItem i) =>
        (sizes.contains(i.size.toUpperCase()) ? 1 : 0) + (designs.contains(i.design) ? 1 : 0);
    // Trống xếp sau cùng (NULLS LAST của server).
    int byText(String a, String b) => a.isEmpty == b.isEmpty ? a.compareTo(b) : (a.isEmpty ? 1 : -1);

    hits.sort((a, b) {
      var r = exact(b).compareTo(exact(a));
      if (r == 0) r = byText(a.size, b.size);
      if (r == 0) r = byText(a.design, b.design);
      if (r == 0) r = a.code.compareTo(b.code);
      return r != 0 ? r : a.id.compareTo(b.id);
    });
    return hits.take(limit).toList();
  }

  /// Từ khoá thành các từ tìm — cùng luật `ReferenceResolver::productTokens()` của server: viết hoa, «×» «*» về «X», «600 x 600» gộp
  /// một từ, tách khoảng trắng / dấu phẩy / chấm phẩy, bỏ «X» đứng riêng, bỏ trùng, tối đa 5 từ.
  static List<String> tokens(String query) {
    final q = query.trim().toUpperCase().replaceAll('×', 'X').replaceAll('*', 'X').replaceAllMapped(
          RegExp(r'(\d)\s*X\s*(\d)'),
          (m) => '${m[1]}X${m[2]}',
        );
    final out = <String>[];
    for (final p in q.split(RegExp(r'[\s,;]+'))) {
      if (p.isEmpty || p == 'X' || out.contains(p)) continue;
      out.add(p);
      if (out.length == 5) break;
    }
    return out;
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

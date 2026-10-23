import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

/// Một đơn vị hành chính — tỉnh/thành (`provinceId == null`) hoặc xã/phường/đặc khu (#24072).
class GeoUnit {
  final int id;

  /// Tỉnh chứa xã; `null` với chính tỉnh.
  final int? provinceId;
  final String code;
  final String name;

  /// Tên đầy đủ hiện trên ô chọn ("Tỉnh Phú Thọ", "Phường Việt Trì").
  final String fullName;
  final String unitType;

  /// Còn chọn MỚI được không. Đơn vị đã tắt vẫn nằm trong danh mục để hồ sơ/phiếu cũ hiện được tên.
  final bool isActive;

  const GeoUnit({
    required this.id,
    required this.provinceId,
    required this.code,
    required this.name,
    required this.fullName,
    required this.unitType,
    required this.isActive,
  });

  factory GeoUnit.fromJson(Map<String, dynamic> json) => GeoUnit(
        id: (json['id'] as num).toInt(),
        provinceId: (json['province_id'] as num?)?.toInt(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        unitType: json['unit_type']?.toString() ?? '',
        isActive: json['is_active'] == true,
      );
}

/// Trọn danh mục đã tải về máy.
class GeoCatalog {
  final String version;
  final List<GeoUnit> provinces;
  final List<GeoUnit> wards;
  final Map<int, GeoUnit> _provinceById;
  final Map<int, GeoUnit> _wardById;

  GeoCatalog({required this.version, required this.provinces, required this.wards})
      : _provinceById = {for (final p in provinces) p.id: p},
        _wardById = {for (final w in wards) w.id: w};

  factory GeoCatalog.fromJson(Map<String, dynamic> data) {
    List<GeoUnit> list(dynamic raw) => raw is List
        ? raw.whereType<Map>().map((e) => GeoUnit.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
    return GeoCatalog(
      version: data['version']?.toString() ?? '',
      provinces: list(data['provinces']),
      wards: list(data['wards']),
    );
  }

  GeoUnit? province(int? id) => id == null ? null : _provinceById[id];

  GeoUnit? ward(int? id) => id == null ? null : _wardById[id];

  /// Xã của một tỉnh — cả đơn vị đã tắt; ô chọn tự lọc `isActive` (giữ lại giá trị đang chọn).
  List<GeoUnit> wardsOf(int? provinceId) =>
      provinceId == null ? const [] : wards.where((w) => w.provinceId == provinceId).toList();
}

final geoCatalogServiceProvider = Provider<GeoCatalogService>((ref) {
  return GeoCatalogService(ref.watch(apiClientProvider));
});

/// Danh mục đơn vị hành chính cho ô Tỉnh → Xã — CHẠY ĐƯỢC KHI MẤT MẠNG (chủ hệ thống chốt 23/10/2026).
///
/// Tải trọn `GET /geo/catalog` một lần (~450 KB), lưu vào tệp trong thư mục tài liệu của app kèm `version`. Lần sau gửi
/// `?version=<đang giữ>`: server trả `unchanged: true` thì dùng bản đã lưu. Mất mạng ⇒ dùng bản đã lưu; chưa từng tải ⇒
/// `null` (ô tỉnh/xã báo cần kết nối mạng một lần). Hợp đồng: `docs/reference/internal-api/API-DON-VI-HANH-CHINH-2026-10-23.md`.
class GeoCatalogService {
  final ApiClient _apiClient;

  GeoCatalogService(this._apiClient);

  /// Bản đang nhớ trong tiến trình — dùng chung mọi màn (một danh mục cho cả app).
  static GeoCatalog? _memory;

  /// Lượt tải đang chạy — nhiều ô cùng mở một lúc thì chờ chung một lượt.
  static Future<GeoCatalog?>? _loading;

  /// Thời điểm hỏi server gần nhất trong tiến trình — không hỏi lại mỗi lần mở form.
  static DateTime? _checkedAt;

  /// Khoảng tối thiểu giữa hai lượt hỏi server "danh mục có đổi không" (danh mục chỉ đổi khi có nghị quyết).
  static const _recheckAfter = Duration(hours: 6);

  static const _fileName = 'geo_catalog.json';

  /// Danh mục hiện có ngay (không chờ mạng) — `null` khi chưa nạp lần nào trong tiến trình.
  GeoCatalog? get cached => _memory;

  /// Như [cached] nhưng gọi được ở nơi không có `ref` (repository cập nhật bản nhớ điểm bán sau khi sửa).
  static GeoCatalog? get memory => _memory;

  /// Nạp danh mục: bộ nhớ → tệp trên máy → server (nếu tới hạn hỏi lại hoặc chưa có gì). Lỗi mạng KHÔNG ném — trả bản
  /// đang có (có thể `null`).
  Future<GeoCatalog?> load({bool force = false}) {
    return _loading ??= _load(force).whenComplete(() => _loading = null);
  }

  Future<GeoCatalog?> _load(bool force) async {
    _memory ??= await _readFile();
    final due = _checkedAt == null || DateTime.now().difference(_checkedAt!) > _recheckAfter;
    if (_memory != null && !force && !due) return _memory;

    try {
      final response = await _apiClient.get(
        '/geo/catalog',
        queryParameters: {if (_memory != null) 'version': _memory!.version},
      );
      _checkedAt = DateTime.now();
      final data = response is Map ? response['data'] : null;
      if (data is Map && data['unchanged'] != true) {
        final fresh = GeoCatalog.fromJson(Map<String, dynamic>.from(data));
        if (fresh.provinces.isNotEmpty) {
          _memory = fresh;
          await _writeFile(data);
        }
      }
    } catch (_) {
      // Mất mạng / server lỗi: dùng bản đã lưu — ô chọn vẫn chạy ngoài thị trường.
    }
    return _memory;
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<GeoCatalog?> _readFile() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      return raw is Map ? GeoCatalog.fromJson(Map<String, dynamic>.from(raw)) : null;
    } catch (_) {
      return null; // tệp hỏng ⇒ coi như chưa có, lần có mạng tải lại
    }
  }

  Future<void> _writeFile(Map data) async {
    try {
      final f = await _file();
      // Ghi tệp tạm rồi đổi tên: tắt app giữa chừng không để lại tệp dở dang.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'version': data['version'],
        'provinces': data['provinces'],
        'wards': data['wards'],
      }));
      await tmp.rename(f.path);
    } catch (_) {
      // Không ghi được (hết bộ nhớ) — lần sau tải lại, không chặn người dùng.
    }
  }
}

import '../rules/mobile_rules_model.dart';

/// Manifest APK Android do `scripts/publish_apk.sh dms` (repo One) ghi cạnh file APK ở `one.vthmgroup.vn/dl/`.
///
/// Số phiên bản đọc từ CHÍNH APK lúc phát hành (aapt2) ⇒ phát hành APK là app tự biết, không phải khai tham số.
class AndroidApkManifest {
  /// versionCode của APK = số build (`+N`) của phiên bản Flutter.
  final int versionCode;

  /// Tên phiên bản hiển thị (vd `1.0.14`).
  final String versionName;

  /// Tên file APK cạnh manifest (vd `vthm-dms.apk`).
  final String fileName;

  /// Tên gói — khác gói của app này thì bỏ qua (manifest trỏ nhầm app).
  final String packageName;

  /// Dung lượng (byte) — hiện cho người dùng biết sắp tải bao nhiêu.
  final int size;

  /// SHA-256 của APK — gói cài kiểm sau khi tải, lệch thì không cài (file hỏng / bị tráo giữa đường).
  final String sha256;

  /// Ghi chú phát hành (có thể rỗng).
  final String notes;

  const AndroidApkManifest({
    required this.versionCode,
    required this.versionName,
    required this.fileName,
    required this.packageName,
    required this.size,
    required this.sha256,
    this.notes = '',
  });

  /// `null` khi thiếu trường bắt buộc — manifest hỏng thì coi như không có bản mới, không đoán.
  static AndroidApkManifest? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = _int(json['versionCode']);
    final file = json['fileName']?.toString().trim() ?? '';
    final sha = json['sha256']?.toString().trim().toLowerCase() ?? '';
    // Tên file nằm trong URL tải: chỉ nhận tên trơn (không `/`, không `..`) — manifest không được trỏ đi chỗ khác.
    if (code <= 0 || !RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(file) || file.contains('..')) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
    return AndroidApkManifest(
      versionCode: code,
      versionName: json['versionName']?.toString().trim() ?? '',
      fileName: file,
      packageName: json['package']?.toString().trim() ?? '',
      size: _int(json['size']),
      sha256: sha,
      notes: json['notes']?.toString().trim() ?? '',
    );
  }

  /// Số đọc mềm (số hoặc chuỗi số) — ép `as num?` ném lỗi với chuỗi, bị coi nhầm là lỗi mạng.
  static int _int(Object? v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  /// URL APK = cùng thư mục với manifest (giải theo URI — query của link manifest không lẫn vào đường dẫn).
  String apkUrl(String manifestUrl) => Uri.parse(manifestUrl).resolve(fileName).toString();
}

/// Kết quả kiểm tra bản mới.
class AppUpdateOffer {
  /// `true` ⇒ màn chặn, không có nút «Để sau».
  final bool forced;

  /// Số build mới nhất có thể cài.
  final int latestBuild;

  /// Tên phiên bản mới (Android từ manifest; iPhone không có ⇒ rỗng).
  final String latestVersionName;

  /// Android: URL APK cần tải; iPhone: link TestFlight / App Store cần mở.
  final String url;

  /// Android: SHA-256 để gói cài kiểm; iPhone: rỗng.
  final String sha256;

  /// Android: dung lượng APK (byte); iPhone: 0.
  final int size;

  /// Ghi chú phát hành.
  final String notes;

  const AppUpdateOffer({
    required this.forced,
    required this.latestBuild,
    required this.url,
    this.latestVersionName = '',
    this.sha256 = '',
    this.size = 0,
    this.notes = '',
  });
}

/// Luật quyết định có báo cập nhật không — hàm thuần, không gọi mạng (test được).
class AppUpdateDecider {
  const AppUpdateDecider._();

  /// Android: có bản mới khi manifest đúng gói và versionCode > build đang chạy.
  ///
  /// [forced] chỉ khi bản CÀI ĐƯỢC đạt `min_build`: `min_build` nâng trước khi APK lên sóng mà chặn thì nhân viên kẹt (hoặc
  /// bị ép cài một bản vẫn dưới mức tối thiểu) — lúc đó chỉ nhắc.
  ///
  /// Chỉ nhận manifest + APK qua https: SHA-256 nằm ngay trong manifest, qua http thì kẻ giữa đường tráo được cả hai.
  static AppUpdateOffer? android({
    required int currentBuild,
    required String packageName,
    required AppUpdateRules rules,
    required AndroidApkManifest? manifest,
  }) {
    if (manifest == null || Uri.tryParse(rules.androidManifestUrl)?.scheme != 'https') return null;
    if (manifest.packageName.isNotEmpty && packageName.isNotEmpty && manifest.packageName != packageName) return null;
    if (manifest.versionCode <= currentBuild) return null;
    return AppUpdateOffer(
      forced: isForced(currentBuild, manifest.versionCode, rules.minBuild),
      latestBuild: manifest.versionCode,
      latestVersionName: manifest.versionName,
      url: manifest.apkUrl(rules.androidManifestUrl),
      sha256: manifest.sha256,
      size: manifest.size,
      notes: manifest.notes,
    );
  }

  /// Bắt buộc khi bản đang chạy dưới `min_build` VÀ bản cài được đạt `min_build`.
  static bool isForced(int currentBuild, int latestBuild, int minBuild) => currentBuild < minBuild && latestBuild >= minBuild;

  /// iPhone: có bản mới khi người vận hành khai build mới nhất > build đang chạy VÀ có link Apple để mở.
  static AppUpdateOffer? ios({required int currentBuild, required AppUpdateRules rules}) {
    final url = rules.iosUpdateUrl;
    final uri = Uri.tryParse(url);
    final okHost =
        uri != null && uri.scheme == 'https' && (uri.host == 'testflight.apple.com' || uri.host == 'apps.apple.com');
    if (!okHost || rules.iosLatestBuild <= currentBuild) return null;
    return AppUpdateOffer(
      forced: isForced(currentBuild, rules.iosLatestBuild, rules.minBuild),
      latestBuild: rules.iosLatestBuild,
      url: url,
    );
  }
}

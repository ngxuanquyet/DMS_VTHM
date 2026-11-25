import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/update/app_update_logic.dart';

/// App tự báo bản mới (25/11/2026): Android đọc manifest APK, iPhone đọc build + link do người vận hành khai.
void main() {
  const manifestUrl = 'https://one.vthmgroup.vn/dl/vthm-dms.json';
  const sha = 'e07f7f227a7ab20d3c41ff3897835e9085902048aabaf848516c95b8e838d548';
  Map<String, dynamic> manifestJson({int code = 16, String file = 'vthm-dms.apk', String s = sha, String pkg = 'vn.vthmgroup.dms'}) => {
        'versionCode': code,
        'versionName': '1.0.14',
        'fileName': file,
        'package': pkg,
        'size': 121413539,
        'sha256': s,
        'notes': '',
      };

  group('AndroidApkManifest.tryParse', () {
    test('manifest thật của publish_apk.sh đọc được, URL APK cùng thư mục', () {
      final m = AndroidApkManifest.tryParse(manifestJson())!;
      expect(m.versionCode, 16);
      expect(m.apkUrl(manifestUrl), 'https://one.vthmgroup.vn/dl/vthm-dms.apk');
      // Link manifest có query (kể cả có `/` trong query) ⇒ APK vẫn cùng thư mục, query không lẫn vào đường dẫn.
      expect(m.apkUrl('https://one.vthmgroup.vn/dl/vthm-dms.json?p=a/b'), 'https://one.vthmgroup.vn/dl/vthm-dms.apk');
    });

    test('tên file trỏ ra ngoài thư mục, sha sai dạng, thiếu versionCode ⇒ bỏ qua', () {
      expect(AndroidApkManifest.tryParse(manifestJson(file: '../evil.apk')), isNull);
      expect(AndroidApkManifest.tryParse(manifestJson(file: 'https://evil.vn/x.apk')), isNull);
      expect(AndroidApkManifest.tryParse(manifestJson(s: 'abc')), isNull);
      expect(AndroidApkManifest.tryParse(manifestJson(code: 0)), isNull);
      expect(AndroidApkManifest.tryParse('không phải JSON'), isNull);
    });
  });

  group('AppUpdateDecider.android', () {
    const rules = AppUpdateRules(androidManifestUrl: manifestUrl);
    AppUpdateOffer? decide(int build, {AppUpdateRules r = rules, Map<String, dynamic>? json, String pkg = 'vn.vthmgroup.dms'}) =>
        AppUpdateDecider.android(
          currentBuild: build,
          packageName: pkg,
          rules: r,
          manifest: AndroidApkManifest.tryParse(json ?? manifestJson()),
        );

    test('bản cũ hơn manifest ⇒ báo, không bắt buộc khi min_build = 0', () {
      final o = decide(15)!;
      expect(o.forced, isFalse);
      expect(o.url, 'https://one.vthmgroup.vn/dl/vthm-dms.apk');
      expect(o.sha256, sha);
    });

    test('đã là bản mới nhất / server cũ không gửi manifest / manifest khác gói ⇒ không báo', () {
      expect(decide(16), isNull);
      expect(decide(15, r: const AppUpdateRules()), isNull);
      expect(decide(15, pkg: 'vn.vthmgroup.other'), isNull);
    });

    test('min_build cao hơn bản đang chạy ⇒ bắt buộc; không có bản để cài thì KHÔNG chặn', () {
      expect(decide(15, r: const AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 16))!.forced, isTrue);
      // APK lên sóng vẫn DƯỚI min_build (17 < 18) ⇒ chỉ nhắc, không ép cài một bản vẫn dưới mức tối thiểu.
      expect(decide(15, r: const AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 18), json: manifestJson(code: 17))!.forced, isFalse);
      // Link manifest http ⇒ không tin (SHA nằm trong chính manifest).
      expect(decide(15, r: const AppUpdateRules(androidManifestUrl: 'http://one.vthmgroup.vn/dl/vthm-dms.json')), isNull);
      // Manifest ghi số dạng chuỗi vẫn đọc được.
      expect(decide(15, json: {...manifestJson(), 'versionCode': '16'})!.latestBuild, 16);
      // min_build nâng trước khi APK lên sóng: manifest vẫn là 15 ⇒ không có gì để cài ⇒ không chặn.
      expect(decide(15, r: const AppUpdateRules(androidManifestUrl: manifestUrl, minBuild: 16), json: manifestJson(code: 15)), isNull);
    });
  });

  group('AppUpdateDecider.ios', () {
    test('build khai > build đang chạy + link Apple ⇒ báo', () {
      final o = AppUpdateDecider.ios(
        currentBuild: 15,
        rules: const AppUpdateRules(iosLatestBuild: 16, iosUpdateUrl: 'https://testflight.apple.com/join/AbCd'),
      )!;
      expect(o.url, 'https://testflight.apple.com/join/AbCd');
      expect(o.forced, isFalse);
    });

    test('chưa khai link / link không phải Apple / đã mới nhất ⇒ không báo', () {
      expect(AppUpdateDecider.ios(currentBuild: 15, rules: const AppUpdateRules(iosLatestBuild: 16)), isNull);
      expect(
        AppUpdateDecider.ios(currentBuild: 15, rules: const AppUpdateRules(iosLatestBuild: 16, iosUpdateUrl: 'https://evil.vn/x')),
        isNull,
      );
      expect(
        AppUpdateDecider.ios(
          currentBuild: 16,
          rules: const AppUpdateRules(iosLatestBuild: 16, iosUpdateUrl: 'https://apps.apple.com/vn/app/id1'),
        ),
        isNull,
      );
    });
  });

  test('MobileRules đọc / ghi khối app_update; server cũ không gửi ⇒ mặc định tắt', () {
    final r = MobileRules.fromJson({
      'app_update': {'min_build': 16, 'android_manifest_url': manifestUrl, 'ios_latest_build': 17, 'ios_update_url': ''},
    });
    expect(r.appUpdate.minBuild, 16);
    expect(MobileRules.fromJson(r.toJson()).appUpdate, r.appUpdate);
    expect(MobileRules.fromJson(const {}).appUpdate, const AppUpdateRules());
    // Số build dạng chuỗi (proxy / server đời khác) không làm hỏng cả bộ luật.
    final s = MobileRules.fromJson({
      'visit': {'min_duration_minutes': 7},
      'app_update': {'min_build': '16', 'ios_latest_build': 'x'},
    });
    expect(s.appUpdate.minBuild, 16);
    expect(s.appUpdate.iosLatestBuild, 0);
    expect(s.visit.minDurationMinutes, 7);
  });
}

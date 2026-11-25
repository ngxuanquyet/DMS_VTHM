import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_strings.dart';
import '../localization/language_provider.dart';
import '../network/connectivity_provider.dart';
import '../rules/mobile_rules_model.dart';
import '../rules/mobile_rules_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import 'app_update_logic.dart';

/// Lớp phủ BÁO BẢN APP MỚI (25/11/2026) — bọc [child] ở `MaterialApp.builder`, trên lớp phủ đổi mật khẩu.
///
/// Nguồn: `GET /dms/mobile-rules` khối `app_update` (app nạp lúc mở + mỗi lần quay lại app).
/// * Android: đọc manifest APK (`one.vthmgroup.vn/dl/vthm-dms.json`) — bấm «Cập nhật» là app tự tải, kiểm SHA-256 rồi mở
///   màn cài của Android (gói `ota_update`). Lần đầu Android hỏi quyền «cài ứng dụng từ nguồn này» — quy định hệ điều hành.
/// * iPhone: Apple không cho app tự cài ⇒ nút mở link TestFlight / App Store người vận hành khai.
/// * Bắt buộc (`min_build`): không có nút «Để sau». CHỈ hiện khi có mạng (mất mạng thì ẩn — trừ lúc đang tải dở, để mạng chập
///   chờn không huỷ lượt tải): không mạng thì không tải được, chặn lúc đó là khoá nhân viên ngoài hiện trường mà không có lối ra
///   (hàng đợi ngoại tuyến giữ việc).
class AppUpdateOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateOverlay({super.key, required this.child});

  @override
  ConsumerState<AppUpdateOverlay> createState() => _AppUpdateOverlayState();
}

class _AppUpdateOverlayState extends ConsumerState<AppUpdateOverlay> with WidgetsBindingObserver {
  /// Quay lại app thì kiểm lại manifest tối đa chừng này một lần — APK mới có thể lên sóng mà luật không đổi.
  static const Duration _recheckEvery = Duration(minutes: 30);

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
  PackageInfo? _info;
  DateTime? _lastCheck;
  bool _checking = false;

  /// Luật tới trong lúc đang kiểm — kiểm lại ngay khi lượt đang chạy xong (bỏ đi thì lúc mở app có thể chỉ kiểm theo luật
  /// mặc định rỗng rồi thôi, không báo gì tới 30 phút sau).
  AppUpdateRules? _pending;

  /// Build nhân viên đã bấm «Để sau» trong phiên chạy này — không nhắc lại tới khi có build mới hơn hoặc mở lại app.
  int? _dismissedBuild;

  /// Lượt kiểm gần nhất KHÔNG xong (mất mạng / máy chủ tải lỗi) ⇒ có mạng lại / quay lại app thì kiểm ngay, không chờ 30 phút.
  bool _lastFetchFailed = false;

  /// Lời mời mới nhất tính được, và link manifest sinh ra nó (giữ lời mời cũ khi đọc hỏng chỉ khi link KHÔNG đổi).
  AppUpdateOffer? _offer;
  String _offerManifestUrl = '';

  /// Lời mời hộp đang hiện — ĐỨNG YÊN khi hộp đang hoạt động ([_panelActive]); chỉ đổi trong setState, không đổi trong build.
  AppUpdateOffer? _shownOffer;

  /// Hộp ĐANG TẢI APK ⇒ giữ hộp + lời mời kể cả khi mạng chập chờn hay có lời mời mới: gỡ / dựng lại hộp lúc đó là huỷ lượt
  /// tải ~120 MB. Hết tải (xong, lỗi, huỷ) là nhả ngay: hộp bắt buộc lỗi tải lúc mất mạng mà vẫn giữ là khoá app ngoài hiện
  /// trường; lời mời mới (người vận hành hạ `min_build`, rút bản) phải áp được.
  bool _panelActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AppUpdateRules>(
      mobileRulesProvider.select((r) => r.appUpdate),
      (_, next) => unawaited(_check(next)),
      fireImmediately: true,
    );
    ref.listenManual<bool>(connectivityProvider.select((s) => s.isOnline), (prev, online) {
      if (online && prev == false && _lastFetchFailed) unawaited(_check(ref.read(mobileRulesProvider).appUpdate));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dio.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (_lastFetchFailed || last == null || DateTime.now().difference(last) >= _recheckEvery) {
      unawaited(_check(ref.read(mobileRulesProvider).appUpdate));
    }
  }

  void _applyOffer(AppUpdateOffer? offer, String manifestUrl) {
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _offerManifestUrl = manifestUrl;
      if (!_panelActive) _shownOffer = offer;
    });
  }

  /// Hộp báo bắt đầu / thôi hoạt động. Hộp gọi `true` từ thao tác bấm (ngay, không lùi khung hình — lùi là có một khung hình
  /// lớp phủ chưa biết và gỡ hộp vừa bắt đầu tải); `false` từ dispose() thì hộp tự lùi sang sau khung hình.
  void _setPanelActive(bool active) {
    if (!mounted || active == _panelActive) return;
    setState(() {
      _panelActive = active;
      if (!active) _shownOffer = _offer;
    });
  }

  Future<void> _check(AppUpdateRules rules) async {
    if (_checking) {
      _pending = rules;
      return;
    }
    _checking = true;
    try {
      final info = _info ??= await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      if (Platform.isAndroid) {
        final url = rules.androidManifestUrl;
        final (ok, manifest) = await _fetchManifest(url);
        if (!ok) {
          _lastFetchFailed = true;
          // Không đọc được manifest: GIỮ lời mời đang có (một lần mạng hỏng không được gỡ màn bắt buộc) — chỉ khi link manifest
          // không đổi và vẫn https; cờ bắt buộc tính lại theo luật MỚI (hạ `min_build` để gỡ chặn thì phải ăn ngay).
          final old = _offer;
          // `_fetchManifest` chỉ trả `false` với link https hợp lệ — không kiểm lại ở đây.
          final keep = old != null && url == _offerManifestUrl;
          _applyOffer(
            keep
                ? AppUpdateOffer(
                    forced: AppUpdateDecider.isForced(build, old.latestBuild, rules.minBuild),
                    latestBuild: old.latestBuild,
                    latestVersionName: old.latestVersionName,
                    url: old.url,
                    sha256: old.sha256,
                    size: old.size,
                    notes: old.notes,
                  )
                : null,
            url,
          );
          return;
        }
        _applyOffer(
          AppUpdateDecider.android(currentBuild: build, packageName: info.packageName, rules: rules, manifest: manifest),
          url,
        );
      } else if (Platform.isIOS) {
        _applyOffer(AppUpdateDecider.ios(currentBuild: build, rules: rules), '');
      }
      _lastFetchFailed = false;
      _lastCheck = DateTime.now();
    } catch (e) {
      _lastFetchFailed = true;
      debugPrint('[AppUpdate] Không kiểm được bản mới: $e');
    } finally {
      _checking = false;
      final next = _pending;
      _pending = null;
      if (next != null && mounted) unawaited(_check(next));
    }
  }

  /// Manifest APK — gọi thẳng file tĩnh (không qua ApiClient: không cần token, khác máy chủ).
  ///
  /// Luật đơn giản, cố ý: CHỈ một lần máy chủ trả 200 qua https mới được đổi kết luận «có / không có bản mới».
  /// * Link cấu hình không phải https / thiếu máy chủ ⇒ `(true, null)` ngay, không gọi mạng (cấu hình sai, không có bản).
  /// * Mọi thứ khác — mất mạng, quá giờ, 4xx/5xx, bị chuyển hướng sang http (wifi công cộng bắt đăng nhập), lỗi bất kỳ ⇒
  ///   `(false, null)`: GIỮ lời mời đang có, thử lại khi có mạng / quay lại app. Mã lỗi của trang trung gian không được gỡ màn
  ///   bắt buộc; muốn gỡ thì người vận hành hạ `min_build` (áp ngay cả khi đọc hỏng — xem [_check]).
  /// * 200 qua https mà JSON hỏng ⇒ `(true, null)`.
  Future<(bool, AndroidApkManifest?)> _fetchManifest(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return (true, null);
    final Response<Object?> res;
    try {
      // `t` né bộ đệm trung gian — manifest đổi ngay khi phát hành APK.
      // Đọc THÔ rồi tự giải JSON: để Dio tự giải theo Content-Type thì cùng một file hỏng ra hai kết luận khác nhau.
      res = await _dio.getUri<Object?>(
        uri.replace(queryParameters: {...uri.queryParameters, 't': '${DateTime.now().millisecondsSinceEpoch}'}),
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      debugPrint('[AppUpdate] Không tải được manifest APK: $e');
      return (false, null);
    }
    // SHA-256 nằm trong chính manifest ⇒ địa chỉ CUỐI (sau chuyển hướng) cũng phải https.
    // Chỉ ĐÚNG 200 mới có thẩm quyền: 204/206 (proxy, tải dở) không được gỡ lời mời.
    if (res.realUri.scheme != 'https' || res.statusCode != 200) return (false, null);
    try {
      final data = jsonDecode(res.data as String? ?? '');
      return (true, AndroidApkManifest.tryParse(data));
    } catch (e) {
      debugPrint('[AppUpdate] Manifest APK hỏng: $e');
      return (true, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider.select((s) => s.isOnline));
    final offer = _shownOffer;
    final show = offer != null && (online || _panelActive) && (offer.forced || _dismissedBuild != offer.latestBuild);
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned.fill(
            // Khoá theo (build, sha, bắt buộc): bản khác / chuyển sang bắt buộc ⇒ hộp dựng lại với dữ liệu mới. Lời mời đứng yên
            // khi hộp đang hoạt động nên khoá không đổi giữa lượt tải.
            child: AppUpdatePanel(
              key: ValueKey('${offer.latestBuild}|${offer.sha256}|${offer.forced}'),
              offer: offer,
              onLater: offer.forced ? null : () => setState(() => _dismissedBuild = offer.latestBuild),
              // File tải về lệch SHA (APK vừa phát hành lại giữa chừng) ⇒ đọc lại manifest ngay.
              onStale: () => unawaited(_check(ref.read(mobileRulesProvider).appUpdate)),
              onActiveChanged: _setPanelActive,
            ),
          ),
      ],
    );
  }
}

/// Hộp báo cập nhật: nội dung + nút «Cập nhật» (Android: tải + cài kèm tiến độ; iPhone: mở link) + «Để sau» khi không bắt buộc.
class AppUpdatePanel extends ConsumerStatefulWidget {
  final AppUpdateOffer offer;

  /// `null` ⇒ bắt buộc, không có nút «Để sau».
  final VoidCallback? onLater;

  /// Gọi khi file tải về lệch SHA — lớp phủ thôi giữ lời mời này và đọc lại manifest.
  final VoidCallback? onStale;

  /// Báo lớp phủ hộp bắt đầu tải (`true`, lúc bấm Cập nhật) / thôi (`false`: tải xong, lỗi, huỷ, hoặc hộp bị gỡ) — xem lớp phủ.
  final ValueChanged<bool>? onActiveChanged;

  const AppUpdatePanel({super.key, required this.offer, this.onLater, this.onStale, this.onActiveChanged});

  @override
  ConsumerState<AppUpdatePanel> createState() => _AppUpdatePanelState();
}

class _AppUpdatePanelState extends ConsumerState<AppUpdatePanel> {
  /// Tên file CỐ ĐỊNH: gói chỉ xoá file trùng tên trước khi tải — tên theo build thì mỗi bản để lại ~120 MB trong máy.
  static const String _apkFileName = 'vthm-dms-update.apk';

  StreamSubscription<OtaEvent>? _sub;
  bool _busy = false;
  int _percent = 0;
  bool _installing = false;
  String? _error;

  @override
  void dispose() {
    // Hộp chỉ bị gỡ giữa lượt tải khi cả app tắt (lớp phủ giữ hộp suốt lượt tải). `_sub.cancel()` chỉ gỡ người nghe khỏi bộ
    // điều khiển trung gian của gói ⇒ huỷ tường minh lượt native nếu còn đang tải.
    if (_busy) unawaited(OtaUpdate().cancel().catchError((_) {}));
    _sub?.cancel();
    // Lùi sang sau khung hình: dispose() chạy giữa lúc lớp phủ đang dựng lại — setState của lớp phủ ngay lúc đó là ném lỗi.
    final onActive = widget.onActiveChanged;
    if (_busy && onActive != null) WidgetsBinding.instance.addPostFrameCallback((_) => onActive(false));
    super.dispose();
  }

  /// Đổi trạng thái «đang tải» và báo lớp phủ NGAY (gọi từ thao tác bấm / sự kiện luồng tải — không phải lúc dựng giao diện).
  void _setBusy(bool busy) {
    if (busy == _busy || !mounted) return;
    setState(() => _busy = busy);
    widget.onActiveChanged?.call(busy);
  }

  Future<void> _update() async {
    final strings = ref.read(stringsProvider);
    if (Platform.isIOS) {
      var opened = false;
      try {
        opened = await launchUrl(Uri.parse(widget.offer.url), mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[AppUpdate] Không mở được link cập nhật: $e');
      }
      if (!opened) _fail(strings.updateFailed, 'launchUrl false');
      return;
    }
    setState(() {
      _percent = 0;
      _installing = false;
      _error = null;
    });
    // Báo lớp phủ SAU setState của hộp (không lồng setState của hai State).
    _setBusy(true);
    await _sub?.cancel();
    // Hộp bị gỡ trong lúc chờ ⇒ dispose() đã chạy khi chưa có lượt native nào để huỷ — đừng mở lượt tải không ai nghe.
    if (!mounted) return;
    try {
      // Đối tượng MỚI mỗi lượt: `OtaUpdate` giữ luồng tiến độ theo đối tượng — dùng lại sau lượt hỏng là nhận luồng đã đóng.
      // `v=<sha>` né bộ đệm trung gian giữ APK cũ (tên file cố định vthm-dms.apk) — theo SHA chứ không theo build: phát hành
      // lại CÙNG build với file khác thì link cũng phải khác.
      final base = Uri.parse(widget.offer.url);
      final url = base.replace(queryParameters: {...base.queryParameters, 'v': widget.offer.sha256.substring(0, 12)}).toString();
      _sub = OtaUpdate()
          .execute(url, destinationFilename: _apkFileName, sha256checksum: widget.offer.sha256)
          .listen(
            (e) => _onEvent(e, strings),
            onError: (Object e) => _fail(strings.updateFailed, e),
            // Luồng đóng mà chưa tới trạng thái cuối ⇒ không để nút quay mãi.
            onDone: () {
              if (_busy) _fail(strings.updateFailed, 'stream closed');
            },
          );
    } catch (e) {
      _fail(strings.updateFailed, e);
    }
  }

  void _onEvent(OtaEvent e, AppStrings strings) {
    if (!mounted) return;
    switch (e.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _percent = int.tryParse(e.value ?? '') ?? _percent);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        // Màn cài của Android đã mở; người dùng bấm Huỷ ở đó thì bấm Cập nhật lại được.
        setState(() => _installing = true);
        _setBusy(false);
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail(strings.updatePermissionError, e.value);
      case OtaStatus.CHECKSUM_ERROR:
        _fail(strings.updateChecksumError, e.value);
        widget.onStale?.call();
      // 🔴 ota_update 7.1.0 khai enum Java và Dart LỆCH thứ tự đúng hai mục này (Java 3 = INSTALLATION_ERROR, 4 =
      // ALREADY_RUNNING_ERROR; Dart ngược lại) ⇒ không phân biệt được — xử lý chung là báo lỗi. KHÔNG gọi cancel() ở đây: lượt
      // huỷ báo lỗi muộn lẫn sang lượt tải sau. Hộp không bị gỡ khi đang tải nên không còn lượt mồ côi để huỷ.
      case OtaStatus.ALREADY_RUNNING_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.CANCELED:
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.INTERNAL_ERROR:
        _fail(strings.updateFailed, e.value);
    }
  }

  void _fail(String message, Object? detail) {
    debugPrint('[AppUpdate] Cập nhật hỏng: $detail');
    if (!mounted) return;
    setState(() {
      _installing = false;
      _error = message;
    });
    _setBusy(false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final offer = widget.offer;
    final theme = Theme.of(context);
    final status = _busy ? strings.updateDownloading(_percent) : (_installing ? strings.updateInstalling : null);
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.system_update, size: 48, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      offer.forced ? strings.updateForcedTitle : strings.updateTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer.forced ? strings.updateForcedMessage : strings.updateMessage(offer.latestVersionName, offer.size),
                      textAlign: TextAlign.center,
                    ),
                    if (offer.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(offer.notes, style: theme.textTheme.bodySmall),
                    ],
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 8),
                      Text(strings.updateIosHint, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _percent > 0 ? _percent / 100 : null),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 8),
                      Text(status, textAlign: TextAlign.center),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      text: _error != null ? strings.updateRetry : strings.updateNow,
                      icon: Icons.download,
                      isLoading: _busy,
                      onPressed: _busy ? null : _update,
                    ),
                    if (widget.onLater != null && !_busy) ...[
                      const SizedBox(height: 8),
                      AppButton(text: strings.updateLater, variant: AppButtonVariant.text, onPressed: widget.onLater),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

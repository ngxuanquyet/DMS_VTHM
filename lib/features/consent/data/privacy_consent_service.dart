import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/account_key.dart';
import '../../auth/presentation/states/auth_state.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import 'privacy_consent_content.dart';

/// Trạng thái đồng ý điều khoản của tài khoản đang đăng nhập — máy + máy chủ (`/dms/privacy-consents`).
///
/// Bằng chứng có giá trị là dòng `dms_privacy_consent` trên máy chủ; bản trong máy chỉ để KHÔNG hỏi lại khi mất mạng
/// và để gửi bù: đồng ý lúc ngoại tuyến được lưu `synced = false`, lần mở Trang chủ sau có mạng thì gửi lên.
class PrivacyConsentService {
  final ApiClient _api;

  PrivacyConsentService(this._api);

  /// Tiền tố khoá trong máy, nối mã tài khoản — hai người dùng chung máy thì mỗi người tự đồng ý.
  static const String _keyPrefix = 'dms_privacy_consent_v1';

  /// Trần chờ máy chủ trả lời khi hỏi trạng thái — quá thì coi như chưa rõ và hiện điều khoản (không treo Trang chủ).
  static const Duration _lookupTimeout = Duration(seconds: 8);

  /// `true` nếu tài khoản đang đăng nhập CẦN đồng ý phiên bản [privacyConsentVersion] (chưa đồng ý ở máy lẫn máy chủ).
  /// Đã đồng ý trong máy mà chưa gửi lên thì gửi bù ngầm.
  Future<bool> needsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);
    // Không rõ tài khoản (hồ sơ trong máy hỏng/thiếu) ⇒ bỏ qua bản trong máy, chỉ tin máy chủ (lấy người theo phiên);
    // máy chủ không trả lời thì hỏi — thu GPS mà chưa đồng ý là trái luật.
    final local = account == null ? null : _readLocal(prefs, account);
    if (account != null && local != null && local['version'] == privacyConsentVersion) {
      if (local['synced'] != true) unawaited(_send(account, local['accepted_at']?.toString()));
      return false;
    }

    try {
      final res = await _api.get(
        '/dms/privacy-consents',
        queryParameters: {'terms_version': privacyConsentVersion},
      ).timeout(_lookupTimeout);
      final data = res is Map ? res['data'] : null;
      if (data is Map && data['accepted'] == true) {
        // Đã đồng ý ở máy khác / trước khi cài lại app.
        if (account != null) await _writeLocal(prefs, account, data['accepted_at']?.toString(), synced: true);
        return false;
      }
    } catch (_) {
      // Mất mạng / máy chủ chưa có endpoint: không biết ⇒ hỏi lại cho chắc, đồng ý sẽ được gửi bù sau.
    }

    return true;
  }

  /// Ghi nhận người dùng vừa bấm "Đồng ý & Tiếp tục": lưu trong máy NGAY rồi mới gửi máy chủ.
  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    if (account != null) await _writeLocal(prefs, account, acceptedAt, synced: false);
    unawaited(_send(account, acceptedAt));
  }

  /// [account] `null` = không rõ tài khoản trong máy — vẫn gửi (máy chủ lấy người theo phiên), chỉ không đóng dấu máy.
  Future<void> _send(String? account, String? acceptedAt) async {
    try {
      final res = await _api.post('/dms/privacy-consents', data: {
        'terms_version': privacyConsentVersion,
        'accepted_at': acceptedAt,
        'app_version': AppConstants.versionName,
        'device_info': _clip('${Platform.operatingSystem} (${Platform.operatingSystemVersion})', 255),
      });
      if (res is! Map || res['success'] != true) return;

      final prefs = await SharedPreferences.getInstance();
      // Người dùng đã đổi tài khoản trong lúc chờ ⇒ đừng đóng dấu "đã gửi" vào ngăn của người khác.
      if (account == null || cacheAccountKey(prefs) != account) return;
      await _writeLocal(prefs, account, acceptedAt, synced: true);
    } catch (_) {
      // Giữ synced = false — lần mở Trang chủ sau gửi lại.
    }
  }

  /// Cắt theo trần cột máy chủ — quá trần là 422 mỗi lần gửi bù, đồng ý không bao giờ lên máy chủ.
  static String _clip(String v, int max) => v.length <= max ? v : v.substring(0, max);

  Map<String, dynamic>? _readLocal(SharedPreferences prefs, String account) {
    try {
      final raw = prefs.getString('${_keyPrefix}_$account');
      if (raw == null) return null;
      final map = jsonDecode(raw);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocal(SharedPreferences prefs, String account, String? acceptedAt, {required bool synced}) =>
      prefs.setString(
        '${_keyPrefix}_$account',
        jsonEncode({'version': privacyConsentVersion, 'accepted_at': acceptedAt, 'synced': synced}),
      );
}

final privacyConsentServiceProvider = Provider<PrivacyConsentService>(
  (ref) => PrivacyConsentService(ref.read(apiClientProvider)),
);

/// Trạng thái cổng đồng ý của phiên đăng nhập hiện tại.
enum ConsentGateStatus {
  /// Chưa kiểm (chưa đăng nhập / vừa đăng xuất) — chưa che app, nhưng Trang chủ chưa thu GPS/đồng bộ.
  unknown,

  /// Phải đồng ý — lớp phủ [PrivacyConsentOverlay] che TOÀN app (trên cả Navigator).
  required,

  /// Đã đồng ý phiên bản hiện hành.
  accepted,
}

/// Cổng đồng ý: Splash/Login gọi [check] trước khi vào app; lớp phủ đọc trạng thái để che app; Trang chủ chỉ thu GPS +
/// đồng bộ khi [ConsentGateStatus.accepted]. Rời trạng thái đăng nhập ⇒ tự về [ConsentGateStatus.unknown] để tài khoản
/// kế tiếp phải kiểm lại (không phụ thuộc màn nào gọi reset).
class PrivacyConsentGate extends StateNotifier<ConsentGateStatus> {
  final PrivacyConsentService _service;

  /// Thế hệ lượt kiểm: [reset]/[accept]/[check] mới làm kết quả của lượt [check] cũ (chờ mạng tới 8s) vô hiệu — không
  /// để câu trả lời của phiên trước đè trạng thái phiên sau.
  int _generation = 0;

  PrivacyConsentGate(this._service) : super(ConsentGateStatus.unknown) {
    _current = this;
    addListener((status) {
      if (status == ConsentGateStatus.accepted && identical(this, _current)) _scheduleDeferredOpen();
    }, fireImmediately: false);
  }

  /// Cổng hiện hành (instance tạo sau cùng, còn sống) — hai service thông báo là singleton không có `ref`, đọc cổng qua đây.
  static PrivacyConsentGate? _current;

  /// Lần chạm thông báo đang hoãn (chỉ giữ lần mới nhất). [reset] xoá — không bao giờ mở thông báo chạm lúc chưa đăng
  /// nhập / của người trước cho người sau.
  static void Function()? _deferred;
  static bool _openScheduled = false;

  static bool get _accepted => _current?.state == ConsentGateStatus.accepted;

  /// Mở màn từ thông báo: chưa đồng ý (hoặc đang chờ mở lần hoãn trước) thì GIỮ LẠI lần chạm mới nhất — màn mở dưới lớp
  /// phủ vẫn chạy `initState` (vd chấm công đọc GPS) trước khi người dùng đồng ý. Trả `true` nếu đã hoãn.
  static bool deferUntilAccepted(void Function() open) {
    if (_accepted && !_openScheduled) return false;
    if (_deferred != null) debugPrint('[PrivacyConsentGate] Bỏ thông báo hoãn trước, giữ lần chạm mới nhất');
    _deferred = open;
    return true;
  }

  /// Khung hình kế (lớp phủ gỡ xong) mở lần chạm MỚI NHẤT lúc đó; cổng đã rời accepted thì giữ nguyên chờ lần sau.
  static void _scheduleDeferredOpen() {
    if (_deferred == null || _openScheduled) return;
    _openScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openScheduled = false;
      if (!_accepted) return;
      final open = _deferred;
      _deferred = null;
      try {
        open?.call();
      } catch (e) {
        debugPrint('[PrivacyConsentGate] Mở thông báo hoãn lỗi: $e');
      }
    });
    // Callback sau khung hình không tự xin khung hình — app đang đứng yên thì lần chạm hoãn không bao giờ mở.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    if (identical(_current, this)) {
      _current = null;
      _deferred = null;
      _openScheduled = false;
    }
    super.dispose();
  }

  /// Hỏi trạng thái của tài khoản đang đăng nhập. Lỗi ⇒ phải đồng ý (fail-closed).
  Future<void> check() async {
    final generation = ++_generation;
    ConsentGateStatus result;
    try {
      result = await _service.needsConsent() ? ConsentGateStatus.required : ConsentGateStatus.accepted;
    } catch (_) {
      result = ConsentGateStatus.required;
    }
    if (generation == _generation && mounted) state = result;
  }

  /// Người dùng bấm "Đồng ý & Tiếp tục": lưu máy + gửi máy chủ (gửi bù nếu mất mạng), mở cổng.
  Future<void> accept() async {
    final generation = ++_generation;
    try {
      await _service.accept();
    } catch (_) {}
    if (generation == _generation && mounted) state = ConsentGateStatus.accepted;
  }

  /// Đăng xuất / phiên mất — bỏ cả thông báo đang hoãn (của người trước).
  void reset() {
    _generation++;
    _deferred = null;
    state = ConsentGateStatus.unknown;
  }
}

/// Cổng đồng ý — xem [PrivacyConsentGate].
final privacyConsentGateProvider = StateNotifierProvider<PrivacyConsentGate, ConsentGateStatus>((ref) {
  final gate = PrivacyConsentGate(ref.read(privacyConsentServiceProvider));
  ref.listen(authViewModelProvider.select((s) => s.status), (_, status) {
    if (status != AuthStatus.authenticated) gate.reset();
  });
  return gate;
});

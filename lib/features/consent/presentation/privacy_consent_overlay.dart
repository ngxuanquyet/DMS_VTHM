import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../data/privacy_consent_content.dart';
import '../data/privacy_consent_service.dart';

/// Lớp phủ BẮT BUỘC đồng ý điều khoản (chủ hệ thống chốt 11/11/2026) — bọc [child] (Navigator của app) ở
/// `MaterialApp.builder`, nằm TRÊN cả Navigator: mọi màn bên dưới bị che, không chạm/đọc màn hình/nhận focus được; không
/// phải route nên không bị hộp thoại khác pop nhầm. Hiện khi cổng = [ConsentGateStatus.required] và không ở màn
/// Splash/Đăng nhập. Nút Back khi đang hiện do [ConsentBackGuard] nhận (cài ở `main()` trước `runApp`).
///
/// Dạng bottom sheet trượt lên (chủ hệ thống chốt lại 11/11/2026): tiêu đề ghim trên; vùng cuộn liệt kê TOÀN VĂN Điều
/// khoản sử dụng rồi Văn bản xử lý dữ liệu cá nhân; Ở CUỐI vùng cuộn là MỘT ô tick gộp (không tick sẵn) + nút "Đồng ý &
/// Tiếp tục" (sáng khi đã tick) + chữ "Từ chối" ⇒ xác nhận: Xem lại hoặc Thoát (Android đóng app; iOS ⇒ đăng xuất). Nút
/// tròn mũi tên xuống nổi góc dưới: cuộn thẳng tới cuối, tự ẩn khi đã ở cuối.
class PrivacyConsentOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const PrivacyConsentOverlay({super.key, required this.child});

  @override
  ConsumerState<PrivacyConsentOverlay> createState() => _PrivacyConsentOverlayState();
}

enum _Panel { main, decline }

class _PrivacyConsentOverlayState extends ConsumerState<PrivacyConsentOverlay> {
  bool _agreed = false;
  bool _busy = false;
  bool _logoutFailed = false;
  _Panel _panel = _Panel.main;
  final ScrollController _scroll = ScrollController();

  /// Mốc 0px đặt ngay đầu khối ô tick/nút (cuối vùng cuộn) và khung nhìn của vùng cuộn — đo khối đã ló vào khung chưa.
  final GlobalKey _blockKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();
  bool _syncScheduled = false;

  /// Vùng cuộn đã ở (gần) cuối — ẩn nút mũi tên.
  bool _atEnd = false;

  late final GoRouter _router = ref.read(appRouterProvider);
  String _path = '';

  @override
  void initState() {
    super.initState();
    _path = _currentPath();
    _router.routerDelegate.addListener(_onRouteChanged);
    _scroll.addListener(_scheduleSync);
  }

  String _currentPath() {
    try {
      return _router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  /// Router báo đổi route NGAY trong lúc nó đang dựng (nó nằm trong cây con của lớp phủ) ⇒ setState sau khung hình.
  void _onRouteChanged() {
    // Đọc lại path TRONG callback: hai lần đổi trong một khung hình (A→B→A) phải ra path cuối, không phải path lúc báo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = _currentPath();
      if (path != _path) setState(() => _path = path);
    });
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    ConsentBackGuard.instance.handler = null;
    _scroll.dispose();
    super.dispose();
  }

  /// Back khi lớp phủ đang hiện: xác nhận từ chối ⇒ về màn chính; màn chính ⇒ mở xác nhận từ chối. Luôn nuốt phím.
  bool _onBack() {
    if (!_busy) _show(_panel == _Panel.main ? _Panel.decline : _Panel.main);
    return true;
  }

  void _show(_Panel p) {
    setState(() {
      _panel = p;
      _logoutFailed = false;
      // Vùng cuộn dựng MỚI ở đầu ⇒ khối ô tick chắc chắn chưa thấy; đặt ngay để khung hình đầu không thiếu mũi tên.
      if (p == _Panel.main) _atEnd = false;
    });
    _scheduleSync();
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    await ref.read(privacyConsentGateProvider.notifier).accept();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _exit() async {
    if (!Platform.isIOS) {
      await SystemNavigator.pop();
      return;
    }
    setState(() => _busy = true);
    var loggedOut = false;
    try {
      loggedOut = await ref.read(authViewModelProvider.notifier).logout();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logoutFailed = !loggedOut;
    });
    if (loggedOut) ref.read(appRouterProvider).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Lần hiện mới (tài khoản khác đăng nhập) phải tick lại từ đầu. Không setState: `ref.watch` dưới đây đã dựng lại.
    ref.listen(privacyConsentGateProvider, (prev, next) {
      if (next == ConsentGateStatus.required && prev != ConsentGateStatus.required) {
        FocusManager.instance.primaryFocus?.unfocus();
        _agreed = false;
        _atEnd = false;
        _panel = _Panel.main;
        _scheduleSync();
      }
    });
    final gate = ref.watch(privacyConsentGateProvider);
    final visible = gate == ConsentGateStatus.required && _path != '/splash' && _path != '/login';
    ConsentBackGuard.instance.handler = visible ? _onBack : null;

    return Stack(
      children: [
        ExcludeSemantics(
          excluding: visible,
          child: AbsorbPointer(absorbing: visible, child: widget.child),
        ),
        if (visible) Positioned.fill(child: _buildOverlay(context)),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    final panel = _panel == _Panel.decline
        ? _declinePanel(s, isDark)
        // Trừ tai thỏ/thanh trạng thái + đáy an toàn (SafeArea bên dưới cộng thêm đáy) — máy ngang/thấp không tràn lên trên.
        : SizedBox(height: (media.size.height - media.padding.vertical) * 0.92, child: _mainPanel(s, isDark));

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => FractionalTranslation(translation: Offset(0, t), child: child),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(top: false, child: panel),
          ),
        ),
      ),
    );
  }

  /// Đo lại ở khung hình KẾ (sau layout — vị trí con trong vùng cuộn chỉ đúng sau khi dựng xong); gộp nhiều lần gọi.
  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      _syncAtEnd();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// `_atEnd` = khối ô tick/nút ĐÃ LÓ vào khung nhìn (đo vị trí thật, không theo ngưỡng px) ⇒ ẩn mũi tên. Mũi tên chỉ hiện khi
  /// khối còn nằm HẲN dưới khung nên không bao giờ đè lên ô tick/nút, bất kể cỡ chữ; nội dung ngắn hơn khung ⇒ khối thấy
  /// ngay ⇒ không có mũi tên vô dụng.
  void _syncAtEnd() {
    if (!mounted) return;
    final marker = _blockKey.currentContext?.findRenderObject();
    final view = _viewportKey.currentContext?.findRenderObject();
    if (marker is! RenderBox || view is! RenderBox || !marker.attached || !view.attached) return;
    final blockTop = marker.localToGlobal(Offset.zero).dy;
    final viewBottom = view.localToGlobal(Offset(0, view.size.height)).dy;
    final atEnd = blockTop < viewBottom;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _mainPanel(AppStrings s, bool isDark) {
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline;
    final divider = isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.consentTitle, style: AppTypography.titleLarge(color: onSurface)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: divider),
        Expanded(
          child: Stack(
            key: _viewportKey,
            children: [
              // Cuộn đã do `_scroll.addListener`; ở đây bắt đổi KÍCH THƯỚC (xoay máy, cỡ chữ, đổi ngôn ngữ) không kèm cuộn.
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scheduleSync();
                  return false;
                },
                // KHÔNG ListView: dựng lười ⇒ `maxScrollExtent` chỉ là ước lượng, nút mũi tên cuộn tới đó là DỪNG TRƯỚC ô tick.
                // Văn bản ~40 đoạn — dựng hết một lần cho chiều dài chính xác.
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...consentDocumentChildren(termsOfUseDocument, s, isDark),
                      const SizedBox(height: 24),
                      ...consentDocumentChildren(personalDataConsentDocument, s, isDark),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: divider),
                      const SizedBox(height: 8),
                      // Mốc đo NGAY TRƯỚC hàng ô tick: mũi tên chỉ ẩn khi ô tick bắt đầu ló vào khung (thấy đường kẻ chưa đủ).
                      SizedBox(key: _blockKey, height: 0),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _busy ? null : () => setState(() => _agreed = !_agreed),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreed,
                              activeColor: AppColors.primary,
                              onChanged: _busy ? null : (v) => setState(() => _agreed = v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(s.consentAgreeAll, style: AppTypography.bodyMedium(color: onSurface)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.consentVersion(privacyConsentVersion),
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall(color: muted),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: s.consentAccept,
                        width: double.infinity,
                        height: 52,
                        isLoading: _busy,
                        onPressed: _agreed && !_busy ? _accept : null,
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy ? null : () => _show(_Panel.decline),
                        child: Text(s.consentDecline, style: AppTypography.labelLarge(color: muted)),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_atEnd)
                Positioned(
                  right: 16,
                  bottom: 16,
                  // KHÔNG `tooltip`: lớp phủ nằm TRÊN Navigator nên không có Overlay ⇒ Tooltip nổ "No Overlay widget found".
                  child: FloatingActionButton.small(
                    heroTag: null,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: _scrollToEnd,
                    // Nhãn đọc màn hình gắn vào Icon — FAB tự tạo node ngữ nghĩa riêng, bọc Semantics ngoài là gắn nhầm node.
                    child: Icon(Icons.keyboard_double_arrow_down_rounded, semanticLabel: s.consentScrollToEnd),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _declinePanel(AppStrings s, bool isDark) {
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.consentDeclineTitle, style: AppTypography.titleLarge(color: onSurface)),
          const SizedBox(height: 12),
          Text(s.consentDeclineMessage, style: AppTypography.bodyMedium(color: onSurface)),
          if (_logoutFailed) ...[
            const SizedBox(height: 8),
            Text(s.consentLogoutFailed, style: AppTypography.bodySmall(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          AppButton(text: s.consentReview, width: double.infinity, onPressed: _busy ? null : () => _show(_Panel.main)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy ? null : _exit,
            child: Text(s.consentExitApp, style: AppTypography.labelLarge(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

/// Nhận nút Back của hệ thống TRƯỚC Router khi lớp phủ đang hiện — lớp phủ nằm ngoài Navigator nên `PopScope` không
/// dùng được, mà Flutter gọi observer theo thứ tự đăng ký: phải [install] ở `main()` trước `runApp`.
class ConsentBackGuard with WidgetsBindingObserver {
  ConsentBackGuard._();

  static final ConsentBackGuard instance = ConsentBackGuard._();

  /// Lớp phủ đặt khi đang hiện (trả `true` = đã xử lý), `null` khi ẩn.
  bool Function()? handler;

  static void install() => WidgetsBinding.instance.addObserver(instance);

  @override
  Future<bool> didPopRoute() async => handler?.call() ?? false;
}

/// Mở toàn văn một văn bản trong bottom sheet — dùng ở màn Cá nhân (đọc lại điều khoản đã đồng ý).
Future<void> showConsentDocument(BuildContext context, ConsentDocument doc, AppStrings strings) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConsentDocumentView(doc: doc, strings: strings, onClose: () => Navigator.of(ctx).pop()),
      ),
    ),
  );
}

/// Toàn văn một văn bản + nút Đóng — đọc ngay trong app, không ra trình duyệt.
class ConsentDocumentView extends StatelessWidget {
  final ConsentDocument doc;
  final AppStrings strings;
  final VoidCallback onClose;

  const ConsentDocumentView({super.key, required this.doc, required this.strings, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: consentDocumentChildren(doc, strings, isDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: AppButton(
            text: strings.close,
            variant: AppButtonVariant.outline,
            width: double.infinity,
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}

/// Toàn văn một văn bản (tiêu đề, căn cứ, các điều) — dùng chung cho lớp phủ đồng ý và màn Cá nhân.
List<Widget> consentDocumentChildren(ConsentDocument doc, AppStrings strings, bool isDark) {
  final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
  final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline;

  return [
    // Tiêu đề văn bản: căn trái, đậm, gạch chân (chủ hệ thống chốt 11/11/2026).
    Text(
      doc.title,
      style: AppTypography.titleLarge(color: onSurface)
          .copyWith(fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: onSurface),
    ),
    if (doc.subtitle != null)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(doc.subtitle!, style: AppTypography.bodySmall(color: muted)),
      ),
    if (!strings.isVietnamese)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(strings.consentLegalNote, style: AppTypography.labelSmall(color: muted)),
      ),
    const SizedBox(height: 12),
    for (final p in doc.preamble)
      Text(
        p,
        style: AppTypography.bodySmall(color: muted).copyWith(fontStyle: FontStyle.italic),
      ),
    for (final section in doc.sections) ...[
      if (section.heading.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(section.heading, style: AppTypography.titleMedium(color: onSurface)),
        ),
      for (final p in section.paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(p, style: AppTypography.bodyMedium(color: onSurface).copyWith(height: 1.45)),
        ),
    ],
  ];
}

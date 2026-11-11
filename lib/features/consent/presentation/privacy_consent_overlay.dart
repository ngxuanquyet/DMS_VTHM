import 'dart:io';

import 'package:flutter/gestures.dart';
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
/// Dạng bottom sheet trượt lên: hai ô tick riêng (không tick sẵn), MỘT nút "Đồng ý & Tiếp tục" chỉ sáng khi đủ hai ô,
/// nút chữ "Từ chối" ⇒ xác nhận: Xem lại hoặc Thoát (Android đóng app; iOS không cho tự thoát ⇒ đăng xuất).
class PrivacyConsentOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const PrivacyConsentOverlay({super.key, required this.child});

  @override
  ConsumerState<PrivacyConsentOverlay> createState() => _PrivacyConsentOverlayState();
}

enum _Panel { main, terms, privacy, decline }

class _PrivacyConsentOverlayState extends ConsumerState<PrivacyConsentOverlay> {
  bool _termsChecked = false;
  bool _privacyChecked = false;
  bool _busy = false;
  bool _logoutFailed = false;
  _Panel _panel = _Panel.main;
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()..onTap = () => _show(_Panel.terms);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()..onTap = () => _show(_Panel.privacy);

  late final GoRouter _router = ref.read(appRouterProvider);
  String _path = '';

  @override
  void initState() {
    super.initState();
    _path = _currentPath();
    _router.routerDelegate.addListener(_onRouteChanged);
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
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// Back khi lớp phủ đang hiện: văn bản/xác nhận ⇒ về màn chính; màn chính ⇒ mở xác nhận từ chối. Luôn nuốt phím.
  bool _onBack() {
    if (!_busy) _show(_panel == _Panel.main ? _Panel.decline : _Panel.main);
    return true;
  }

  void _show(_Panel p) => setState(() {
        _panel = p;
        _logoutFailed = false;
      });

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
        _termsChecked = _privacyChecked = false;
        _panel = _Panel.main;
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

    Widget panel;
    switch (_panel) {
      case _Panel.terms:
      case _Panel.privacy:
        panel = SizedBox(
          height: media.size.height * 0.9,
          child: ConsentDocumentView(
            doc: _panel == _Panel.terms ? termsOfUseDocument : personalDataConsentDocument,
            strings: s,
            onClose: () => _show(_Panel.main),
          ),
        );
      case _Panel.decline:
        panel = _declinePanel(s, isDark);
      case _Panel.main:
        panel = _mainPanel(s, isDark, media);
    }

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

  Widget _mainPanel(AppStrings s, bool isDark, MediaQueryData media) {
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline;
    final canAccept = _termsChecked && _privacyChecked && !_busy;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(s.consentTitle, style: AppTypography.titleLarge(color: onSurface))),
              ],
            ),
            const SizedBox(height: 14),
            Text(s.consentSummary, style: AppTypography.bodyMedium(color: onSurface)),
            const SizedBox(height: 8),
            Text(s.consentReadHint, style: AppTypography.bodySmall(color: muted)),
            const SizedBox(height: 12),
            _checkRow(
              checked: _termsChecked,
              onChanged: (v) => setState(() => _termsChecked = v),
              prefix: s.consentAgreePrefix,
              link: s.consentTermsLink,
              linkTap: _termsTap,
              textColor: onSurface,
            ),
            _checkRow(
              checked: _privacyChecked,
              onChanged: (v) => setState(() => _privacyChecked = v),
              prefix: s.consentAgreePrefix,
              link: s.consentPrivacyLink,
              linkTap: _privacyTap,
              textColor: onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              s.consentVersion(privacyConsentVersion),
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall(color: muted),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: s.consentAccept,
              width: double.infinity,
              height: 52,
              isLoading: _busy,
              onPressed: canAccept ? _accept : null,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => _show(_Panel.decline),
              child: Text(s.consentDecline, style: AppTypography.labelLarge(color: muted)),
            ),
          ],
        ),
      ),
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
          AppButton(
            text: s.consentReview,
            width: double.infinity,
            onPressed: _busy ? null : () => _show(_Panel.main),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy ? null : _exit,
            child: Text(s.consentExitApp, style: AppTypography.labelLarge(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _checkRow({
    required bool checked,
    required ValueChanged<bool> onChanged,
    required String prefix,
    required String link,
    required TapGestureRecognizer linkTap,
    required Color textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              activeColor: AppColors.primary,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.bodyMedium(color: textColor),
                    children: [
                      TextSpan(text: prefix),
                      TextSpan(
                        text: link,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                        recognizer: linkTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Text(doc.title, textAlign: TextAlign.center, style: AppTypography.titleLarge(color: onSurface)),
              if (doc.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(doc.subtitle!, textAlign: TextAlign.center, style: AppTypography.bodySmall(color: muted)),
                ),
              if (!strings.isVietnamese)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(strings.consentLegalNote,
                      textAlign: TextAlign.center, style: AppTypography.labelSmall(color: muted)),
                ),
              const SizedBox(height: 12),
              for (final p in doc.preamble)
                Text(p, style: AppTypography.bodySmall(color: muted).copyWith(fontStyle: FontStyle.italic)),
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
            ],
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

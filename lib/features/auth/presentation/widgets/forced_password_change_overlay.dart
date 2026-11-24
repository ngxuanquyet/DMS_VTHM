import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../consent/data/privacy_consent_service.dart';
import '../states/auth_state.dart';
import '../viewmodels/auth_view_model.dart';

/// Lớp phủ ĐỔI MẬT KHẨU BẮT BUỘC (#25831) — bọc [child] (Navigator của app) ở `MaterialApp.builder`, nằm trên cả lớp phủ
/// đồng ý điều khoản: tài khoản bị buộc đổi mật khẩu thì máy chủ chặn mọi API (403 `PASSWORD_CHANGE_REQUIRED`), kể cả API
/// đồng ý điều khoản. Hiện khi đã đăng nhập và `user.mustChangePassword`; lối ra duy nhất ngoài đổi mật khẩu là Đăng xuất
/// (giữ hàng đợi — đúng người đăng nhập lại là gửi tiếp).
class ForcedPasswordChangeOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const ForcedPasswordChangeOverlay({super.key, required this.child});

  @override
  ConsumerState<ForcedPasswordChangeOverlay> createState() => _ForcedPasswordChangeOverlayState();
}

class _ForcedPasswordChangeOverlayState extends ConsumerState<ForcedPasswordChangeOverlay> {
  /// Lớp phủ đang hiện — mạng chập chờn sau đó KHÔNG gỡ nó (đang gõ / đang gửi đổi mật khẩu thì mất trắng).
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final mustChange = ref.watch(authViewModelProvider
        .select((s) => s.status == AuthStatus.authenticated && (s.user?.mustChangePassword ?? false)));
    // Chỉ MỞ khi có mạng: đổi mật khẩu cần mạng, còn việc ngoại tuyến (check-in, chấm công xếp hàng) vẫn làm được — hàng
    // đợi giữ mục chờ tới khi đổi xong. Che cả app lúc mất mạng là chặn nhân viên ngoài hiện trường mà không có lối ra.
    final online = ref.watch(connectivityProvider.select((s) => s.isOnline));
    _shown = mustChange && (_shown || online);
    return Stack(
      children: [
        widget.child,
        if (_shown)
          // Overlay riêng: lớp phủ nằm TRÊN Navigator nên không có Overlay của nó — ô nhập cần Overlay cho tay kéo / menu
          // chọn chữ.
          Positioned.fill(
            child: Overlay(initialEntries: [OverlayEntry(builder: (_) => const ForcedPasswordChangePanel())]),
          ),
      ],
    );
  }
}

/// Màn đổi mật khẩu bắt buộc: mật khẩu hiện tại + mới + nhập lại.
class ForcedPasswordChangePanel extends ConsumerStatefulWidget {
  const ForcedPasswordChangePanel({super.key});

  @override
  ConsumerState<ForcedPasswordChangePanel> createState() => _ForcedPasswordChangePanelState();
}

class _ForcedPasswordChangePanelState extends ConsumerState<ForcedPasswordChangePanel> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current = _current.text;
    final next = _next.text;
    String? error;
    if (current.isEmpty || next.isEmpty || _confirm.text.isEmpty) {
      error = 'Vui lòng nhập đủ mật khẩu hiện tại, mật khẩu mới và nhập lại mật khẩu mới.';
    } else if (next != _confirm.text) {
      error = 'Mật khẩu nhập lại không khớp mật khẩu mới.';
    } else if (next == current) {
      error = 'Mật khẩu mới phải khác mật khẩu hiện tại.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(authViewModelProvider.notifier).changePassword(currentPassword: current, newPassword: next);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result;
    });
    if (result == null) {
      // API đồng ý điều khoản cũng bị chặn lúc trước ⇒ kiểm lại (lớp phủ đồng ý tự hiện nếu còn phải đồng ý).
      if (ref.read(privacyConsentGateProvider) != ConsentGateStatus.accepted) {
        ref.read(privacyConsentGateProvider.notifier).check();
      }
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Đã đổi mật khẩu.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await ref.read(authViewModelProvider.notifier).logout();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'Không đăng xuất được, vui lòng thử lại.';
    });
    if (ok) ref.read(appRouterProvider).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toggle = IconButton(
      icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _visible = !_visible),
    );
    return Material(
      color: isDark ? AppColors.darkBackground : AppColors.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Đổi mật khẩu',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mật khẩu của bạn vừa được quản trị đặt lại. Vui lòng đổi mật khẩu mới để tiếp tục dùng ứng dụng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    key: const Key('forced_pw_current'),
                    label: 'Mật khẩu hiện tại',
                    hintText: 'Mật khẩu quản trị vừa cấp',
                    controller: _current,
                    obscureText: !_visible,
                    suffixIcon: toggle,
                    textInputAction: TextInputAction.next,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    key: const Key('forced_pw_new'),
                    label: 'Mật khẩu mới',
                    controller: _next,
                    obscureText: !_visible,
                    textInputAction: TextInputAction.next,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    key: const Key('forced_pw_confirm'),
                    label: 'Nhập lại mật khẩu mới',
                    controller: _confirm,
                    obscureText: !_visible,
                    textInputAction: TextInputAction.done,
                    enabled: !_busy,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFE11D48))),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    key: const Key('forced_pw_submit'),
                    text: 'Đổi mật khẩu',
                    isLoading: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Đăng xuất',
                    variant: AppButtonVariant.text,
                    onPressed: _busy ? null : _logout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

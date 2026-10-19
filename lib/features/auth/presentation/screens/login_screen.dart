import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';
import '../states/auth_state.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final savedUser = ref.read(authViewModelProvider).savedUsername;
    _usernameController = TextEditingController(text: savedUser);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authVM = ref.read(authViewModelProvider.notifier);
    final success = await authVM.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      ref.read(profileViewModelProvider.notifier).loadProfile();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.stackLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header / Logo Area
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                            child: SvgPicture.asset(
                              AppAssets.logo,
                              width: 90,
                              height: 90,
                            ),
                          ),
                        ),
                        Text(
                          strings.appSubtitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineSmallMobile(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Error Banner
                        if (authState.status == AuthStatus.error && authState.errorMessage != null) ...[
                          Builder(
                            builder: (context) {
                              String displayMsg = authState.errorMessage!;
                              String? code = authState.errorCode;
                              final codeRegex = RegExp(r'\(Mã lỗi:\s*([^)]+)\)');
                              final match = codeRegex.firstMatch(displayMsg);
                              if (match != null) {
                                code ??= match.group(1)?.trim();
                                displayMsg = displayMsg.replaceAll(codeRegex, '').trim();
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                                decoration: BoxDecoration(
                                  color: AppColors.errorContainer.withValues(alpha: 0.3),
                                  borderRadius: AppRadius.roundedMd,
                                  border: Border.all(color: AppColors.errorContainer),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayMsg,
                                            style: AppTypography.bodyMedium(color: AppColors.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (code != null && code.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.tag_rounded, size: 14, color: AppColors.error),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Mã lỗi: $code',
                                                  style: const TextStyle(
                                                    color: AppColors.error,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: code!));
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Đã sao chép mã lỗi vào bộ nhớ tạm.'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 13, color: AppColors.error),
                                            label: const Text(
                                              'Chép mã',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                            ),
                                            style: TextButton.styleFrom(
                                              backgroundColor: AppColors.error.withValues(alpha: 0.08),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // Username input
                        AppTextField(
                          label: strings.usernameLabel,
                          hintText: strings.usernameHint,
                          controller: _usernameController,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.outline,
                            size: 22,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.stackMd),

                        // Password input
                        AppTextField(
                          label: strings.passwordLabel,
                          hintText: strings.passwordHint,
                          controller: _passwordController,
                          obscureText: !authState.isPasswordVisible,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.outline,
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              authState.isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              color: AppColors.outline,
                              size: 20,
                            ),
                            onPressed: () {
                              ref.read(authViewModelProvider.notifier).togglePasswordVisibility();
                            },
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: AppSpacing.stackSm),

                        // Option: Forgot Password (đã bỏ Ghi nhớ đăng nhập trên giao diện)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(strings.forgotPasswordMsg),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              strings.forgotPassword,
                              style: AppTypography.labelLarge(
                                color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Submit Button
                        AppButton(
                          text: strings.loginButton,
                          height: 52,
                          isLoading: authState.status == AuthStatus.authenticating,
                          trailingIcon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.onPrimary,
                          ),
                          onPressed: _handleLogin,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackLg),
                  Text(
                    AppConstants.appVersion,
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
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

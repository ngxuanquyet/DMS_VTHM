import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../states/auth_state.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final savedUser = ref.read(authViewModelProvider).savedUsername;
    _usernameController = TextEditingController(text: savedUser.isNotEmpty ? savedUser : 'NV00128');
    _passwordController = TextEditingController(text: '123456');
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
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
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
                            width: 128,
                            height: 80,
                            margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                            child: Image.network(
                              AppConstants.logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.corporate_fare,
                                size: 54,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          AppConstants.appSubtitle,
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer.withValues(alpha: 0.3),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(color: AppColors.errorContainer),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: AppTypography.bodyMedium(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Username input
                        AppTextField(
                          label: 'Tài khoản / Mã nhân viên',
                          hintText: 'Nhập tài khoản',
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
                          label: 'Mật khẩu',
                          hintText: 'Nhập mật khẩu',
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

                        // Options: Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                ref.read(authViewModelProvider.notifier).setRememberMe(!authState.rememberMe);
                              },
                              borderRadius: AppRadius.roundedSm,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: authState.rememberMe,
                                        activeColor: AppColors.primaryContainer,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          ref.read(authViewModelProvider.notifier).setRememberMe(val ?? false);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ghi nhớ đăng nhập',
                                      style: AppTypography.bodyMedium(
                                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Vui lòng liên hệ quản trị viên để cấp lại mật khẩu'),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Quên mật khẩu?',
                                style: AppTypography.labelLarge(
                                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Submit Button
                        AppButton(
                          text: 'ĐĂNG NHẬP',
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

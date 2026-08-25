import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../profile/presentation/viewmodels/profile_view_model.dart';
import '../viewmodels/auth_view_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  bool _isAuthenticated = false;
  bool _authCheckFinished = false;

  @override
  void initState() {
    super.initState();

    // Progress bar animates strictly from 0.0 to 1.0
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );

    // Listen for animation completion: ONLY navigate after the progress bar reaches 100%
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateWhenReady();
      }
    });

    // Start loading progress immediately on Frame 1
    _progressController.forward();

    // Check auth in background
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      _isAuthenticated = await ref.read(authViewModelProvider.notifier).checkAuth();
      if (_isAuthenticated) {
        ref.read(profileViewModelProvider.notifier).loadProfile();
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _authCheckFinished = true;
      if (_progressController.isCompleted) {
        _navigateWhenReady();
      }
    }
  }

  void _navigateWhenReady() {
    if (!mounted) return;
    if (!_authCheckFinished) return;

    if (_isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBright,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // Instant-render Center Brand Logo (0ms latency, no blank wait)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon Shield
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryContainer,
                            AppColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.corporate_fare_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Primary Brand Name
                    Text(
                      'VTHM GROUP',
                      style: AppTypography.displayLarge(
                        color: AppColors.primary,
                      ).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      'HỆ THỐNG PHÂN PHỐI DMS',
                      style: AppTypography.labelSmall(
                        color: AppColors.onSurfaceVariant,
                      ).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Bottom Progress & Version Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: Column(
                children: [
                  // Animated Progress Bar (width: 220px, height: 5px)
                  Container(
                    width: 220,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E3E0),
                      borderRadius: AppRadius.roundedFull,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryContainer,
                                    AppColors.primary,
                                  ],
                                ),
                                borderRadius: AppRadius.roundedFull,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Version Text
                  Text(
                    'Phiên bản 2.4.1',
                    style: AppTypography.labelSmall(color: AppColors.outline).copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

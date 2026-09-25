import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/attendance/presentation/screens/attendance_detail_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/customer/domain/entities/customer_entity.dart';
import '../../features/customer/presentation/screens/add_customer_screen.dart';
import '../../features/customer/presentation/screens/customer_detail_screen.dart';
import '../../features/customer/presentation/screens/customer_screen.dart';
import '../../features/forms/presentation/screens/forms_screen.dart';
import '../../features/forms/presentation/screens/market_form_fill_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/dynamic_form_demo_screen.dart';
import '../../features/profile/presentation/screens/personal_info_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/voice_to_text_screen.dart';
import '../../features/route/presentation/screens/check_in_screen.dart';
import '../../features/route/presentation/screens/route_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'branch_animated_slide_container.dart';
import 'page_transitions.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: VthmBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) =>
            BranchAnimatedSlideContainer(
          navigationShell: navigationShell,
          children: children,
        ),
        builder: (context, state, navigationShell) =>
            MainShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CustomerScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/routes',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RouteScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/forms',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FormsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/attendance',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const AttendanceDetailScreen(),
        ),
      ),
      GoRoute(
        path: '/check-in',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const CheckInScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/add',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const AddCustomerScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/detail',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final customer = state.extra is CustomerEntity
              ? state.extra as CustomerEntity
              : null;
          if (customer == null) {
            return ZoomPageTransition(
              key: state.pageKey,
              child: Scaffold(
                appBar: AppBar(title: const Text('Chi tiết điểm bán')),
                body: const Center(
                  child: Text('Không tìm thấy thông tin điểm bán'),
                ),
              ),
            );
          }
          return ZoomPageTransition(
            key: state.pageKey,
            child: CustomerDetailScreen(customer: customer),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/personal-info',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const PersonalInfoScreen(),
        ),
      ),
      GoRoute(
        path: '/voice-to-text',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const VoiceToTextScreen(),
        ),
      ),
      GoRoute(
        path: '/forms/fill',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final args = state.extra is MarketFormFillArgs
              ? state.extra as MarketFormFillArgs
              : null;
          if (args == null) {
            return ZoomPageTransition(
              key: state.pageKey,
              child: Scaffold(
                appBar: AppBar(title: const Text('Biểu mẫu')),
                body: const Center(
                  child: Text('Không tìm thấy thông tin biểu mẫu'),
                ),
              ),
            );
          }
          return ZoomPageTransition(
            key: state.pageKey,
            child: MarketFormFillScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: '/dev/dynamic-form-demo',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => ZoomPageTransition(
          key: state.pageKey,
          child: const DynamicFormDemoScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Không tìm thấy trang: ${state.uri}'),
      ),
    ),
  );
});

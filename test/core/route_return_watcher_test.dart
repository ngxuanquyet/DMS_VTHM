import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vthm_dms/core/router/route_return_watcher.dart';

/// Màn Tuyến tính lại khoảng cách mỗi lần QUAY VỀ (29/10/2026) — từ tab khác hoặc sau khi đóng màn check-in.
void main() {
  testWidgets('gọi khi quay về /routes (đổi tab, đóng màn phủ lên); không gọi khi đi nơi khác hay đứng yên', (tester) async {
    Widget page(String name) => Scaffold(body: Text(name));
    final router = GoRouter(
      initialLocation: '/routes',
      routes: [
        GoRoute(path: '/routes', builder: (_, __) => page('routes')),
        GoRoute(path: '/customers', builder: (_, __) => page('customers')),
        GoRoute(path: '/check-in', builder: (_, __) => page('check-in')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    var returns = 0;
    final watcher = RouteReturnWatcher(router.routerDelegate, path: '/routes', onReturn: () => returns++);
    addTearDown(watcher.dispose);

    router.go('/customers'); // sang tab khác
    await tester.pumpAndSettle();
    expect(returns, 0);

    router.go('/routes'); // quay về
    await tester.pumpAndSettle();
    expect(returns, 1);

    router.push('/check-in'); // mở màn phủ lên
    await tester.pumpAndSettle();
    expect(returns, 1);
    router.pop(); // đóng ⇒ về lại /routes
    await tester.pumpAndSettle();
    expect(returns, 2);

    router.go('/routes'); // đang ở /routes, điều hướng lại chính nó ⇒ không tính là "quay về"
    await tester.pumpAndSettle();
    expect(returns, 2);
    expect(watcher.isAtPath, isTrue);

    router.push('/check-in');
    await tester.pumpAndSettle();
    expect(watcher.isAtPath, isFalse); // màn phủ lên ⇒ app quay lại từ nền không làm mới màn Tuyến
  });
}

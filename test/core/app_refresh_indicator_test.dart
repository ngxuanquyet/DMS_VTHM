import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/network/refresh_outcome.dart';
import 'package:vthm_dms/core/widgets/app_refresh_indicator.dart';

/// Kéo xuống làm mới ⇒ báo ĐÚNG theo server (29/10/2026): repository nuốt lỗi rồi trả dữ liệu trong máy, nên đếm chính
/// các lời gọi API phát ra trong lượt làm mới.
class _FakeConnectivity extends ConnectivityNotifier {
  _FakeConnectivity(bool online) {
    state = ConnectivityState(isOnline: online);
  }
}

class _Adapter implements HttpClientAdapter {
  int status = 200;
  bool connectionError = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (connectionError) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    return ResponseBody.fromString(jsonEncode({'success': status < 400}), status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late ApiClient api;

  setUp(() {
    adapter = _Adapter();
    api = ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter);
  });

  /// Như repository offline-first: gọi API, lỗi thì nuốt (trả dữ liệu trong máy).
  Future<void> repoLikeRefresh() async {
    try {
      await api.get('/dms/something');
    } catch (_) {}
  }

  Future<void> pull(WidgetTester tester, {required Future<void> Function() onRefresh, bool online = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivityProvider.overrideWith((ref) => _FakeConnectivity(online))],
        child: MaterialApp(
          home: Scaffold(
            body: AppRefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(children: const [SizedBox(height: 2000, child: Text('nội dung'))]),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('tới được server ⇒ "Làm mới thành công"', (tester) async {
    await pull(tester, onRefresh: repoLikeRefresh);
    expect(find.text('Làm mới thành công'), findsOneWidget);
  });

  testWidgets('server lỗi 5xx (repository nuốt lỗi, trả dữ liệu trong máy) ⇒ báo KHÔNG tải được, không báo thành công',
      (tester) async {
    adapter.status = 500;
    await pull(tester, onRefresh: repoLikeRefresh);
    expect(find.text('Làm mới thành công'), findsNothing);
    expect(find.textContaining('Không tải được dữ liệu mới'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5)); // Timer ghi lỗi của ErrorTrackerService
  });

  testWidgets('mất kết nối giữa chừng ⇒ báo KHÔNG tải được', (tester) async {
    adapter.connectionError = true;
    await pull(tester, onRefresh: repoLikeRefresh);
    expect(find.textContaining('Không tải được dữ liệu mới'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5)); // Timer ghi lỗi của ErrorTrackerService
  });

  testWidgets('màn chỉ đọc dữ liệu trong máy (không gọi server) khi đang online ⇒ "Làm mới thành công"', (tester) async {
    await pull(tester, onRefresh: () async {});
    expect(find.text('Làm mới thành công'), findsOneWidget);
  });

  testWidgets('phản hồi lỗi 4xx (vd 404/hết phiên) ⇒ báo KHÔNG tải được, không báo thành công', (tester) async {
    adapter.status = 404;
    await pull(tester, onRefresh: repoLikeRefresh);
    expect(find.text('Làm mới thành công'), findsNothing);
    expect(find.textContaining('Không tải được dữ liệu mới'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
  });

  testWidgets('lời gọi trong RefreshOutcome.untracked (đẩy hàng đợi) hỏng ⇒ không tính, vẫn "Làm mới thành công"',
      (tester) async {
    await pull(tester, onRefresh: () async {
      await repoLikeRefresh(); // tải dữ liệu: thành công
      adapter.status = 500;
      await RefreshOutcome.untracked(repoLikeRefresh); // gửi một mục hàng đợi: hỏng
    });
    expect(find.text('Làm mới thành công'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
  });

  testWidgets('không gọi server khi đang ngoại tuyến ⇒ báo đang ngoại tuyến', (tester) async {
    await pull(tester, onRefresh: () async {}, online: false);
    expect(find.textContaining('Đang ngoại tuyến'), findsOneWidget);
    expect(find.text('Làm mới thành công'), findsNothing);
  });

  testWidgets('màn gỡ AppRefreshIndicator khỏi cây trong lúc làm mới (đổi sang vòng tải) ⇒ vẫn báo', (tester) async {
    final showList = ValueNotifier(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivityProvider.overrideWith((ref) => _FakeConnectivity(true))],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showList,
              builder: (_, show, __) => show
                  ? AppRefreshIndicator(
                      onRefresh: () async {
                        showList.value = false; // như màn chuyển sang vòng tải
                        await repoLikeRefresh();
                      },
                      child: ListView(children: const [SizedBox(height: 2000, child: Text('nội dung'))]),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Làm mới thành công'), findsOneWidget);
  });
}

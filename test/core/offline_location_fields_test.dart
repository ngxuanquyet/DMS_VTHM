import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/map/app_map_location_card.dart';
import 'package:vthm_dms/core/map/goong_map_view.dart';
import 'package:vthm_dms/core/map/offline_gps_placeholder.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/widgets/location_field_widget.dart';

/// Ô LẤY vị trí khi mất mạng: cùng luật màn Chấm công — ẩn bản đồ, hiện toạ độ GPS + nút lấy lại, không tự điền địa
/// chỉ (chủ hệ thống chốt 02/11/2026: tạo/sửa điểm bán, biểu mẫu, khai báo vị trí, sửa vị trí ở chi tiết điểm bán).
class _FakeConnectivity extends ConnectivityNotifier {
  _FakeConnectivity(bool online) : super() {
    state = ConnectivityState(isOnline: online);
  }

  @override
  Future<bool> checkConnectivity() async => state.isOnline;

  @override
  void handleNetworkDisconnection() {}
}

Widget _host(Widget child, {required bool online}) => ProviderScope(
      overrides: [connectivityProvider.overrideWith((ref) => _FakeConnectivity(online))],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('LocationFieldWidget mất mạng ⇒ ẩn bản đồ, hiện toạ độ + nút lấy lại, gợi ý gõ tay địa chỉ', (tester) async {
    await tester.pumpWidget(_host(
      LocationFieldWidget(
        label: 'Vị trí điểm bán',
        value: const {'address': '', 'lat': 21.0285123, 'lng': 105.8542},
        onChanged: (_) {},
      ),
      online: false,
    ));
    await tester.pump();

    expect(find.byType(GoongMapView), findsNothing);
    expect(find.text('Định vị GPS ngoại tuyến'), findsOneWidget);
    expect(find.textContaining('21.02851, 105.85420'), findsWidgets);
    expect(find.text(OfflineGpsPlaceholder.addressHint), findsOneWidget);
    expect(find.text('Đang nhận diện địa chỉ vị trí...'), findsNothing, reason: 'không được gọi Goong khi mất mạng');
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('LocationFieldWidget có mạng ⇒ vẫn vẽ bản đồ như cũ', (tester) async {
    await tester.pumpWidget(_host(
      LocationFieldWidget(
        label: 'Vị trí điểm bán',
        value: const {'address': '12 Lý Thường Kiệt', 'lat': 21.0285123, 'lng': 105.8542},
        onChanged: (_) {},
      ),
      online: true,
    ));
    await tester.pump();

    expect(find.byType(GoongMapView), findsOneWidget);
    expect(find.text('Định vị GPS ngoại tuyến'), findsNothing);
  });

  testWidgets('AppMapLocationCard mất mạng ⇒ ẩn bản đồ, hiện toạ độ, không tra địa chỉ', (tester) async {
    await tester.pumpWidget(_host(
      const AppMapLocationCard(lat: 21.0285123, lng: 105.8542),
      online: false,
    ));
    await tester.pump();

    expect(find.byType(GoongMapView), findsNothing);
    expect(find.text('Định vị GPS ngoại tuyến'), findsOneWidget);
    expect(find.textContaining('Toạ độ: 21.02851, 105.85420'), findsOneWidget);
    expect(find.text('Đang nhận diện địa chỉ vị trí...'), findsNothing);
  });

  testWidgets('AppMapLocationCard có mạng ⇒ vẫn vẽ bản đồ như cũ', (tester) async {
    await tester.pumpWidget(_host(
      const AppMapLocationCard(lat: 21.0285123, lng: 105.8542, initialAddress: '12 Lý Thường Kiệt'),
      online: true,
    ));
    await tester.pump();

    expect(find.byType(GoongMapView), findsOneWidget);
    expect(find.text('Định vị GPS ngoại tuyến'), findsNothing);
  });

  testWidgets('LocationFieldWidget mất mạng, toạ độ ĐỔI ⇒ địa chỉ người dùng đã lưu/gõ được GIỮ (chỉ bỏ địa chỉ tự điền)',
      (tester) async {
    Map<String, dynamic>? last;
    Widget field(double lat) => LocationFieldWidget(
          label: 'Vị trí điểm bán',
          value: {'address': 'Số 15 Lê Lợi', 'lat': lat, 'lng': 105.8542},
          onChanged: (v) => last = v,
        );
    await tester.pumpWidget(_host(field(21.0285), online: false));
    await tester.pump();
    await tester.pumpWidget(_host(field(21.0300), online: false));
    await tester.pump(const Duration(milliseconds: 10));

    expect(last, isNull, reason: 'không được tự xoá địa chỉ người dùng đã lưu');
    expect(find.text('Số 15 Lê Lợi'), findsOneWidget);
  });

  testWidgets('Ô chỉ hiển thị (chi tiết điểm bán) mất mạng ⇒ "Bản đồ ngoại tuyến", không nói đang ghi nhận GPS, không nút',
      (tester) async {
    await tester.pumpWidget(_host(
      LocationFieldWidget(
        label: 'Vị trí',
        isReadOnly: true,
        value: const {'address': 'Số 15 Lê Lợi', 'lat': 21.0285, 'lng': 105.8542},
        onChanged: (_) {},
      ),
      online: false,
    ));
    await tester.pump();

    expect(find.text('Bản đồ ngoại tuyến'), findsOneWidget);
    expect(find.text('Định vị GPS ngoại tuyến'), findsNothing);
    expect(find.textContaining('vẫn được ghi nhận'), findsNothing);
    expect(find.byIcon(Icons.my_location), findsNothing);
  });
}

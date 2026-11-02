import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';

/// #24618 — đồng hồ hàng đợi ngoại tuyến lấy theo đồng hồ MÁY (kênh native), không theo Stopwatch của tiến trình.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vn.vthmgroup.dms/clock');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late int deviceElapsedMs;
  String? deviceBootId;

  setUp(() {
    SystemClock.resetForTest();
    deviceElapsedMs = 50 * 60 * 1000;
    deviceBootId = 'boot:aaaa';
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'snapshot');
      return {'elapsedMs': deviceElapsedMs, if (deviceBootId != null) 'bootId': deviceBootId};
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('máy NGỦ 2 giờ (Stopwatch không đếm) — neo lại theo đồng hồ máy ⇒ khoảng chờ đủ 2 giờ', () async {
    await SystemClock.init();
    expect(SystemClock.bootId, 'boot:aaaa');
    final created = SystemClock.nowMonotonicMs;
    expect(created, closeTo(deviceElapsedMs, 1000));

    deviceElapsedMs += 2 * 3600 * 1000; // máy ngủ 2 giờ: đồng hồ máy chạy, Stopwatch của tiến trình gần như đứng
    await SystemClock.refresh();

    final q = SystemClock.calculateQueuedSeconds(createdElapsedMs: created, entryBootId: 'boot:aaaa');
    expect(q, closeTo(7200, 2), reason: 'lỗi cũ: chỉ đếm vài giây app chạy');
  });

  test('mở lại app (tiến trình mới) cùng lần khởi động máy ⇒ vẫn so được (bootId của MÁY, không của tiến trình)',
      () async {
    await SystemClock.init();
    final created = SystemClock.nowMonotonicMs;

    SystemClock.resetForTest(); // như tiến trình mới
    deviceElapsedMs += 30 * 60 * 1000;
    await SystemClock.init();

    expect(SystemClock.calculateQueuedSeconds(createdElapsedMs: created, entryBootId: 'boot:aaaa'), closeTo(1800, 2),
        reason: 'lỗi cũ: bootId sinh mỗi lần mở app ⇒ rỗng');
  });

  test('máy khởi động lại ⇒ bootId khác ⇒ rỗng (không đoán)', () async {
    await SystemClock.init();
    final created = SystemClock.nowMonotonicMs;
    SystemClock.resetForTest();
    deviceBootId = 'boot:bbbb';
    deviceElapsedMs = 1000;
    await SystemClock.init();

    expect(SystemClock.calculateQueuedSeconds(createdElapsedMs: created, entryBootId: 'boot:aaaa'), isNull);
  });

  test('không có kênh native ⇒ rơi về đồng hồ tiến trình, refresh KHÔNG chuyển nguồn giữa chừng', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await SystemClock.init();
    final boot = SystemClock.bootId;
    expect(boot.startsWith('proc:'), isTrue);
    final created = SystemClock.nowMonotonicMs;

    messenger.setMockMethodCallHandler(channel, (call) async => {'elapsedMs': 999999999, 'bootId': 'boot:x'});
    await SystemClock.refresh();

    expect(SystemClock.bootId, boot);
    expect(SystemClock.calculateQueuedSeconds(createdElapsedMs: created, entryBootId: boot), lessThan(5));
  });

  test('máy không cho đọc định danh khởi động ⇒ bootId riêng của tiến trình (không ghép nhầm)', () async {
    deviceBootId = null;
    await SystemClock.init();
    expect(SystemClock.bootId.startsWith('native-proc:'), isTrue);
  });

  test('monotonicMsAt lùi về LÚC BẤM (lần gửi trực tuyến hỏng chờ ~30s), kẹp ở trần thay vì bỏ', () async {
    await SystemClock.init();
    final now = SystemClock.nowMonotonicMs;
    expect(SystemClock.monotonicMsAt(DateTime.now().subtract(const Duration(seconds: 30))), closeTo(now - 30000, 1000));
    expect(SystemClock.monotonicMsAt(DateTime.now().subtract(const Duration(hours: 2))), closeTo(now - 15 * 60000, 1000));
    expect(SystemClock.monotonicMsAt(DateTime.now().add(const Duration(minutes: 1))), closeTo(now, 1000));
    expect(SystemClock.monotonicMsAt(null), closeTo(now, 1000));
  });
}

import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound, .list])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VthmClock") {
      VthmClock.register(messenger: registrar.messenger())
    }
  }
}

/// Đồng hồ hàng đợi ngoại tuyến (#24618) — lib/core/utils/system_clock.dart.
enum VthmClock {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "vn.vthmgroup.dms/clock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "snapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      var payload: [String: Any] = [
        // CLOCK_MONOTONIC của Darwin đếm CẢ lúc máy ngủ, không đổi khi tắt/mở app hay chỉnh giờ (về 0 khi khởi động lại).
        "elapsedMs": Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000)
      ]
      if let boot = bootSessionUuid() {
        payload["bootId"] = "boot:\(boot)"
      }
      result(payload)
    }
  }

  /// Định danh LẦN KHỞI ĐỘNG máy (`kern.bootsessionuuid`).
  private static func bootSessionUuid() -> String? {
    var size = 0
    guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buf = [CChar](repeating: 0, count: size)
    guard sysctlbyname("kern.bootsessionuuid", &buf, &size, nil, 0) == 0 else { return nil }
    let id = String(cString: buf)
    return id.isEmpty ? nil : id
  }
}

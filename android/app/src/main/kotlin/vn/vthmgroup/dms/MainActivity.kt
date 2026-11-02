package vn.vthmgroup.dms

import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Đồng hồ hàng đợi ngoại tuyến (#24618) — lib/core/utils/system_clock.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.vthmgroup.dms/clock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "snapshot" -> result.success(
                        mapOf(
                            // Tính từ lúc BẬT MÁY, đếm CẢ lúc máy ngủ sâu, không đổi khi tắt/mở app hay chỉnh giờ.
                            "elapsedMs" to SystemClock.elapsedRealtime(),
                            "bootId" to bootId(),
                        )
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /** Định danh LẦN KHỞI ĐỘNG máy — đổi khi máy khởi động lại (elapsedRealtime về 0). */
    private fun bootId(): String? {
        try {
            val id = File("/proc/sys/kernel/random/boot_id").readText().trim()
            if (id.isNotEmpty()) return "boot:$id"
        } catch (_: Exception) {
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val count = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT)
                return "bootcount:$count"
            } catch (_: Exception) {
            }
        }
        return null
    }
}

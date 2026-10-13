package app.kinyangdeechao

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ระดับ API ของเครื่อง ใช้เลือก emoji ที่ฟอนต์ระบบแสดงได้
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.kinyangdeechao/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") result.success(Build.VERSION.SDK_INT)
                else result.notImplemented()
            }
    }
}

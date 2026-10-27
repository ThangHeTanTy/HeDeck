package __PACKAGE__

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Sinh tu android_patch/MainActivity.kt moi lan chay setup_app.bat.
// Sua o file do, dung sua o day.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Man hinh khong tat khi dang dung deck. Thay cho plugin wakelock,
        // von hay hong moi lan Flutter doi phien ban Kotlin.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    // Kenh hedeck/update: noi luu APK tai ve va mo trinh cai dat cua Android.
    // Tu viet thay vi dung plugin, vi plugin hay vo moi lan Flutter nang cap.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hedeck/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkDir" -> {
                        // Khop voi res/xml/update_paths.xml
                        val dir = File(cacheDir, "updates")
                        dir.mkdirs()
                        // Xoa APK cu, chi giu ban sap tai
                        dir.listFiles()?.forEach { it.delete() }
                        result.success(dir.absolutePath)
                    }
                    "install" -> try {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.updates", file)
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

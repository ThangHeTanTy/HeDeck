package __PACKAGE__

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.Executors
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

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

        // Kenh hedeck/relay: bat/tat tram bat may chay ngam (WakeRelayService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hedeck/relay")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(WakeRelayService.PREFS, MODE_PRIVATE)
                fun saveConfig() {
                    prefs.edit()
                        .putString("key", call.argument<String>("key") ?: "")
                        .putString("macs", (call.argument<List<String>>("macs")
                            ?: emptyList()).joinToString(","))
                        .putString("broadcast", call.argument<String>("broadcast") ?: "")
                        .putInt("port", call.argument<Int>("port") ?: 8788)
                        .apply()
                }
                when (call.method) {
                    "start" -> try {
                        saveConfig()
                        prefs.edit().putBoolean("on", true).apply()
                        call.argument<String>("page")?.let {
                            File(filesDir, "wake_page.html").writeText(it)
                        }
                        call.argument<ByteArray>("icon")?.let {
                            File(filesDir, "wake_icon.png").writeBytes(it)
                        }
                        // Chi hoi quyen khi nguoi dung vua bat tram, khong
                        // hoi lai moi lan mo app.
                        if (call.argument<Boolean>("ask") == true) {
                            askNotificationPermission()
                            askBatteryExemption()
                        }
                        WakeRelayService.start(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("relay", e.message, null)
                    }
                    "configure" -> {
                        saveConfig()
                        result.success(null)
                    }
                    "stop" -> {
                        prefs.edit().putBoolean("on", false).apply()
                        stopService(Intent(this, WakeRelayService::class.java))
                        result.success(null)
                    }
                    "running" -> result.success(WakeRelayService.running)
                    else -> result.notImplemented()
                }
            }
    }

    // Android 13+: phai xin quyen moi hien duoc thong bao "tram dang chay".
    // Tu choi thi tram van chay, chi la khong thay thong bao.
    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
    }

    // Xin cho HeDeck khoi bi toi uu pin: nhieu may (Samsung, Xiaomi, Oppo)
    // van tat dich vu nen sau vai gio neu khong co ngoai le nay.
    private fun askBatteryExemption() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        try {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")))
        } catch (e: Exception) {
            Log.w("HeDeck", "khong mo duoc cai dat pin: $e")
        }
    }
}

/**
 * Tram bat may chay ngam: dien thoai deck de o nha nhan lenh tu dien thoai
 * khac (qua Tailscale) roi phat goi Wake-on-LAN trong mang nha.
 *
 * Chay doc lap voi giao dien Flutter: man hinh tat, app bi vuot khoi danh
 * sach da nhiem, hay dien thoai khoi dong lai (BootReceiver) van chay. Giu
 * CPU va Wi-Fi thuc de luon nghe duoc lenh; tram vot cam sac nen khong lo pin.
 *
 * Giao thuc giong ban Dart (lib/services/platform/relay_io.dart):
 *   GET  /          trang "Bat PC" cho iPhone (Dart ghi ra file khi bat tram)
 *   GET  /icon.png  bieu tuong cua trang
 *   POST /wake      {"ts","nonce","sig"}: sig = HMAC-SHA256(khoa, "wake|ts|nonce")
 * Chi nhan tu mang nha va mang Tailscale; lenh qua 2 phut hoac dung lai nonce
 * thi tu choi.
 */
class WakeRelayService : Service() {
    companion object {
        const val PREFS = "hedeck_relay"
        @Volatile var running = false

        fun start(ctx: Context) {
            val intent = Intent(ctx, WakeRelayService::class.java)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent)
            else ctx.startService(intent)
        }
    }

    private var server: ServerSocket? = null
    private var started = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private val pool = Executors.newCachedThreadPool()
    private val seen = ArrayDeque<String>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        if (!started) {
            started = true
            startServer()
        }
        // Bi he thong dung vi thieu bo nho thi tu khoi dong lai.
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        try { server?.close() } catch (_: Exception) {}
        server = null
        pool.shutdownNow()
        wakeLock?.release()
        wifiLock?.release()
        super.onDestroy()
    }

    private fun goForeground() {
        val channel = "relay"
        if (Build.VERSION.SDK_INT >= 26) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(NotificationChannel(
                    channel, "Trạm bật máy", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
                      else Notification.Builder(this)
        val notification = builder
            .setContentTitle("HeDeck · Trạm bật máy đang chạy")
            .setContentText("Điện thoại khác có thể nhờ máy này bật máy tính")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }
    }

    private fun startServer() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val port = prefs.getInt("port", 8788)
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HeDeck:relay").apply {
            setReferenceCounted(false)
            acquire()
        }
        val wm = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "HeDeck:relay").apply {
            setReferenceCounted(false)
            acquire()
        }
        Thread {
            try {
                val ss = ServerSocket()
                ss.reuseAddress = true
                ss.bind(InetSocketAddress(port))
                server = ss
                running = true
                while (!ss.isClosed) {
                    val socket = ss.accept()
                    pool.execute { handle(socket) }
                }
            } catch (e: Exception) {
                Log.w("HeDeck", "tram bat may dung: $e")
            } finally {
                running = false
            }
        }.start()
    }

    private fun handle(socket: Socket) {
        try {
            socket.use { s ->
                s.soTimeout = 8000
                val input = BufferedInputStream(s.getInputStream())
                val out = s.getOutputStream()
                val requestLine = readLine(input) ?: return
                val headers = HashMap<String, String>()
                while (true) {
                    val line = readLine(input) ?: break
                    if (line.isEmpty()) break
                    val i = line.indexOf(':')
                    if (i > 0) headers[line.substring(0, i).trim().lowercase()] =
                        line.substring(i + 1).trim()
                }
                val parts = requestLine.split(" ")
                val method = parts.getOrElse(0) { "" }
                val path = parts.getOrElse(1) { "/" }.substringBefore('?')
                if (!trusted(s.inetAddress)) {
                    respond(out, 403, "application/json",
                        """{"ok":false,"error":"not_local"}""".toByteArray())
                    return
                }
                when {
                    method == "GET" && (path == "/" || path == "/index.html") -> {
                        val page = File(filesDir, "wake_page.html")
                        respond(out, 200, "text/html; charset=utf-8",
                            if (page.exists()) page.readBytes() else "HeDeck".toByteArray())
                    }
                    method == "GET" && path == "/icon.png" -> {
                        val icon = File(filesDir, "wake_icon.png")
                        if (icon.exists()) respond(out, 200, "image/png", icon.readBytes())
                        else respond(out, 404, "text/plain", ByteArray(0))
                    }
                    method == "POST" && path == "/wake" -> {
                        val len = headers["content-length"]?.toIntOrNull() ?: 0
                        if (len <= 0 || len > 4096) {
                            respond(out, 400, "application/json", """{"ok":false}""".toByteArray())
                            return
                        }
                        val body = ByteArray(len)
                        var read = 0
                        while (read < len) {
                            val n = input.read(body, read, len - read)
                            if (n < 0) break
                            read += n
                        }
                        val (code, json) = wake(String(body, 0, read, Charsets.UTF_8))
                        respond(out, code, "application/json", json.toByteArray())
                    }
                    else -> respond(out, 404, "text/plain", ByteArray(0))
                }
            }
        } catch (e: Exception) {
            Log.w("HeDeck", "tram bat may: $e")
        }
    }

    private fun readLine(input: InputStream): String? {
        val sb = StringBuilder()
        while (true) {
            val c = input.read()
            if (c < 0) return if (sb.isEmpty()) null else sb.toString()
            if (c == '\n'.code) return sb.toString()
            if (c != '\r'.code) sb.append(c.toChar())
            if (sb.length > 8192) return null
        }
    }

    private fun respond(out: OutputStream, code: Int, type: String, body: ByteArray) {
        val reason = when (code) { 200 -> "OK"; 403 -> "Forbidden"; 404 -> "Not Found"; else -> "Bad Request" }
        out.write(("HTTP/1.1 $code $reason\r\nContent-Type: $type\r\n" +
            "Content-Length: ${body.size}\r\nCache-Control: no-cache\r\n" +
            "Connection: close\r\n\r\n").toByteArray())
        out.write(body)
        out.flush()
    }

    private fun wake(text: String): Pair<Int, String> {
        val bad = 403 to """{"ok":false,"error":"bad_signature"}"""
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val key = prefs.getString("key", "") ?: ""
        val msg = try { JSONObject(text) } catch (e: Exception) {
            return 400 to """{"ok":false}"""
        }
        val ts = msg.optLong("ts")
        val nonce = msg.optString("nonce")
        val sig = try { Base64.decode(msg.optString("sig"), Base64.DEFAULT) } catch (e: Exception) {
            ByteArray(0)
        }
        val now = System.currentTimeMillis() / 1000
        if (key.isEmpty() || Math.abs(now - ts) > 120 || nonce.length < 8) return bad
        synchronized(seen) { if (seen.contains(nonce)) return bad }
        val expected = try {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(Base64.decode(key, Base64.DEFAULT), "HmacSHA256"))
            mac.doFinal("wake|$ts|$nonce".toByteArray(Charsets.UTF_8))
        } catch (e: Exception) {
            return bad
        }
        if (!MessageDigest.isEqual(expected, sig)) return bad
        synchronized(seen) {
            seen.addLast(nonce)
            while (seen.size > 256) seen.removeFirst()
        }
        val broadcast = prefs.getString("broadcast", "") ?: ""
        val macs = (prefs.getString("macs", "") ?: "").split(",").filter { it.isNotBlank() }
        val sent = sendWakeOnLan(macs, broadcast)
        // Tram bi mang ra ngoai thi tin hieu phat vao mang khac: bao thang.
        val home = onHomeNetwork(broadcast)
        val reply = JSONObject().put("ok", sent > 0 && home).put("sent", sent)
        if (!home) reply.put("away", true)
        return 200 to reply.toString()
    }

    private fun sendWakeOnLan(macs: List<String>, broadcast: String): Int {
        val packets = macs.mapNotNull { parseMac(it) }.map { mac ->
            ByteArray(102).also { p ->
                for (i in 0 until 6) p[i] = 0xFF.toByte()
                for (r in 0 until 16) System.arraycopy(mac, 0, p, 6 + r * 6, 6)
            }
        }
        if (packets.isEmpty()) return 0
        val targets = mutableListOf(InetAddress.getByName("255.255.255.255"))
        if (broadcast.isNotEmpty()) {
            try { targets.add(InetAddress.getByName(broadcast)) } catch (_: Exception) {}
        }
        var sent = 0
        try {
            DatagramSocket().use { sock ->
                sock.broadcast = true
                repeat(3) {
                    for (p in packets) for (t in targets) for (port in intArrayOf(9, 7)) {
                        try {
                            sock.send(DatagramPacket(p, p.size, t, port))
                            sent++
                        } catch (_: Exception) {}
                    }
                    Thread.sleep(120)
                }
            }
        } catch (e: Exception) {
            Log.w("HeDeck", "gui goi bat may loi: $e")
        }
        return sent
    }

    private fun parseMac(text: String): ByteArray? {
        val hex = text.filter { it.isLetterOrDigit() }
        if (hex.length != 12) return null
        return try {
            ByteArray(6) { i -> hex.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
        } catch (_: NumberFormatException) {
            null
        }
    }

    private fun isTailscale(b: ByteArray) =
        b.size == 4 && (b[0].toInt() and 0xFF) == 100 && (b[1].toInt() and 0xC0) == 64

    private fun trusted(a: InetAddress): Boolean {
        if (a.isLoopbackAddress || a.isLinkLocalAddress || a.isSiteLocalAddress) return true
        val b = a.address
        if (isTailscale(b)) return true
        // IPv6 cua Tailscale: fd7a:115c:a1e0::/48
        return b.size == 16 && (b[0].toInt() and 0xFF) == 0xfd && (b[1].toInt() and 0xFF) == 0x7a &&
            (b[2].toInt() and 0xFF) == 0x11 && (b[3].toInt() and 0xFF) == 0x5c &&
            (b[4].toInt() and 0xFF) == 0xa1 && (b[5].toInt() and 0xFF) == 0xe0
    }

    private fun onHomeNetwork(broadcast: String): Boolean {
        val parts = broadcast.split(".")
        if (parts.size != 4) return true
        val keep = parts.indexOf("255")
        val prefix = parts.take(if (keep < 1) 3 else keep).joinToString(".") + "."
        return try {
            NetworkInterface.getNetworkInterfaces().toList().any { nif ->
                nif.inetAddresses.toList().any { a ->
                    a is Inet4Address && !a.isLoopbackAddress && !isTailscale(a.address) &&
                        (a.hostAddress ?: "").startsWith(prefix)
                }
            }
        } catch (_: Exception) {
            true
        }
    }
}

/** Dien thoai khoi dong lai: mo lai tram neu dang bat. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (context.getSharedPreferences(WakeRelayService.PREFS, Context.MODE_PRIVATE)
                .getBoolean("on", false)) {
            WakeRelayService.start(context)
        }
    }
}

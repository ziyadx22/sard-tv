package com.mysard.mysard_tv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import org.json.JSONObject
import java.io.File
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random

private const val METHOD_CHANNEL = "com.mysard.tv/control"
private const val EVENT_CHANNEL = "com.mysard.tv/events"
private const val NOTIFICATION_CHANNEL = "mysard_overlay"
private const val NOTIFICATION_ID = 42
private const val BASE_PORT = 8765

data class HudStyle(
    val fontSp: Float = 32f,
    val opacity: Float = 0.62f,
    val neon: Int = Color.parseColor("#00F0FF"),
    val yFraction: Float = 0.78f,
)

object MysardRuntime {
    @Volatile var sink: EventChannel.EventSink? = null
    val mainHandler = Handler(Looper.getMainLooper())
    var server: TranslationServer? = null
    var overlay: HudOverlay? = null
    var pin: String = randomPin()
    var port: Int = BASE_PORT

    fun randomPin(): String = Random.nextInt(1000, 10000).toString()

    fun emit(event: Map<String, Any?>) {
        mainHandler.post { sink?.success(event) }
    }

    fun localIpv4(): String {
        return try {
            NetworkInterface.getNetworkInterfaces().toList()
                .flatMap { nif -> nif.inetAddresses.toList().map { nif to it } }
                .firstOrNull { (nif, addr) ->
                    !nif.isLoopback && nif.isUp && addr is Inet4Address && !addr.isLoopbackAddress &&
                        addr.hostAddress?.startsWith("169.254") != true
                }?.second?.hostAddress ?: "0.0.0.0"
        } catch (_: Exception) {
            "0.0.0.0"
        }
    }
}

class HudOverlay(val context: Context) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var container: LinearLayout? = null
    private var caption: TextView? = null
    private var style = HudStyle()
    private var attached = false

    private val fadeOut = Runnable {
        val view = container ?: return@Runnable
        view.animate().alpha(0f).setDuration(520).withEndAction {
            if (view.alpha == 0f) remove()
        }.start()
    }

    fun show(text: String, next: HudStyle) {
        MysardRuntime.mainHandler.post {
            style = next
            val view = ensure() ?: return@post
            applyChrome(view)
            caption?.text = text
            view.animate().cancel()
            view.alpha = 1f
            layoutAt(view)
            MysardRuntime.mainHandler.removeCallbacks(fadeOut)
            MysardRuntime.mainHandler.postDelayed(fadeOut, 5_000)
        }
    }

    fun applyStyle(next: HudStyle) {
        MysardRuntime.mainHandler.post {
            style = next
            val view = container ?: return@post
            applyChrome(view)
            layoutAt(view)
        }
    }

    fun remove() {
        MysardRuntime.mainHandler.post {
            MysardRuntime.mainHandler.removeCallbacks(fadeOut)
            val view = container ?: return@post
            if (attached) {
                try {
                    windowManager.removeView(view)
                } catch (_: Exception) {
                }
                attached = false
            }
            container = null
            caption = null
        }
    }

    private fun ensure(): LinearLayout? {
        container?.let { return it }
        if (!Settings.canDrawOverlays(context)) {
            MysardRuntime.emit(mapOf("type" to "overlay_denied"))
            return null
        }
        val label = TextView(context).apply {
            setTextColor(Color.WHITE)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            textDirection = View.TEXT_DIRECTION_RTL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            gravity = Gravity.CENTER
            setShadowLayer(18f, 0f, 6f, Color.argb(180, 0, 0, 0))
            setLineSpacing(0f, 1.15f)
        }
        val box = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(dp(28), dp(16), dp(28), dp(16))
            addView(label, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ))
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setRoundRect(0, 0, view.width, view.height, dp(22).toFloat())
                }
            }
            clipToOutline = true
            elevation = dp(18).toFloat()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                outlineAmbientShadowColor = Color.BLACK
                outlineSpotShadowColor = Color.argb(160, 0, 0, 0)
            }
        }
        caption = label
        container = box
        applyChrome(box)
        try {
            windowManager.addView(box, layoutParams(blur = true))
        } catch (_: Exception) {
            try {
                windowManager.addView(box, layoutParams(blur = false))
            } catch (_: Exception) {
                container = null
                caption = null
                MysardRuntime.emit(mapOf("type" to "overlay_denied"))
                return null
            }
        }
        attached = true
        return box
    }

    private fun applyChrome(view: LinearLayout) {
        val alpha = (style.opacity.coerceIn(0.2f, 0.92f) * 255).toInt()
        val fill = GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(Color.argb(alpha, 8, 16, 36), Color.argb((alpha * 0.92f).toInt(), 12, 28, 48)),
        ).apply {
            cornerRadius = dp(22).toFloat()
            setStroke(dp(2), style.neon)
        }
        view.background = fill
        caption?.setTextSize(TypedValue.COMPLEX_UNIT_SP, style.fontSp.coerceIn(16f, 72f))
        caption?.setShadowLayer(22f, 0f, 4f, style.neon and 0x00FFFFFF or 0x66000000)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            view.outlineSpotShadowColor = style.neon
        }
    }

    private fun layoutAt(view: View) {
        val params = view.layoutParams as? WindowManager.LayoutParams ?: return
        val metrics = context.resources.displayMetrics
        val maxWidth = (metrics.widthPixels * 0.78f).toInt()
        params.width = maxWidth
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        val y = (metrics.heightPixels * style.yFraction).toInt()
        params.y = y.coerceIn(dp(24), metrics.heightPixels - dp(80))
        try {
            windowManager.updateViewLayout(view, params)
        } catch (_: Exception) {
        }
    }

    private fun layoutParams(blur: Boolean): WindowManager.LayoutParams {
        val type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        val canBlur = blur && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        if (canBlur) flags = flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            flags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            if (canBlur) blurBehindRadius = 48
        }
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()
}

class TranslationServer(
    address: InetSocketAddress,
    private val pin: String,
) : WebSocketServer(address) {
    private val authed = ConcurrentHashMap.newKeySet<WebSocket>()

    init {
        isReuseAddr = true
    }

    fun clientCount(): Int = authed.size

    override fun onOpen(conn: WebSocket, handshake: ClientHandshake) {}

    override fun onClose(conn: WebSocket, code: Int, reason: String, remote: Boolean) {
        authed.remove(conn)
        publishStatus()
    }

    override fun onError(conn: WebSocket?, ex: Exception) {
        conn?.let { authed.remove(it) }
        publishStatus()
    }

    override fun onStart() {
        publishStatus()
    }

    override fun onMessage(conn: WebSocket, message: String) {
        val json = try {
            JSONObject(message)
        } catch (_: Exception) {
            return
        }
        when (json.optString("type")) {
            "auth" -> {
                if (json.optString("pin") == pin) {
                    authed.add(conn)
                    conn.send("""{"type":"auth_ok"}""")
                    publishStatus()
                } else {
                    conn.send("""{"type":"auth_fail"}""")
                    conn.close()
                }
            }
            "ping" -> if (authed.contains(conn)) conn.send("""{"type":"pong"}""")
            "subtitle" -> if (authed.contains(conn)) {
                val text = json.optString("text")
                if (text.isNotBlank()) {
                    MysardRuntime.overlay?.show(text, styleFrom(json))
                    MysardRuntime.emit(mapOf("type" to "subtitle", "text" to text))
                }
            }
            "style" -> if (authed.contains(conn)) {
                MysardRuntime.overlay?.applyStyle(styleFrom(json))
            }
        }
    }

    private fun publishStatus() {
        MysardRuntime.emit(
            mapOf(
                "type" to "status",
                "ip" to MysardRuntime.localIpv4(),
                "port" to MysardRuntime.port,
                "pin" to pin,
                "clients" to authed.size,
            ),
        )
    }

    private fun styleFrom(json: JSONObject): HudStyle {
        val color = try {
            Color.parseColor(json.optString("color", "#00F0FF"))
        } catch (_: Exception) {
            Color.parseColor("#00F0FF")
        }
        return HudStyle(
            fontSp = json.optDouble("fontSize", 32.0).toFloat(),
            opacity = json.optDouble("opacity", 0.62).toFloat(),
            neon = color,
            yFraction = json.optDouble("y", 0.78).toFloat(),
        )
    }
}

class KeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        MysardRuntime.overlay = HudOverlay(applicationContext)
        startForeground(NOTIFICATION_ID, buildNotification())
        val lock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "mysard:subtitle")
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
        startSocket()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (MysardRuntime.server == null) startSocket()
        return START_STICKY
    }

    override fun onDestroy() {
        MysardRuntime.server?.stop(400)
        MysardRuntime.server = null
        MysardRuntime.overlay?.remove()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    private fun startSocket() {
        if (MysardRuntime.server != null) return
        var port = BASE_PORT
        for (candidate in BASE_PORT until BASE_PORT + 8) {
            try {
                java.net.ServerSocket().use { probe ->
                    probe.reuseAddress = true
                    probe.bind(InetSocketAddress("0.0.0.0", candidate))
                }
                port = candidate
                break
            } catch (_: Exception) {
            }
        }
        val server = TranslationServer(InetSocketAddress("0.0.0.0", port), MysardRuntime.pin)
        server.start()
        MysardRuntime.port = port
        MysardRuntime.server = server
        MysardRuntime.emit(
            mapOf(
                "type" to "status",
                "ip" to MysardRuntime.localIpv4(),
                "port" to port,
                "pin" to MysardRuntime.pin,
                "clients" to 0,
            ),
        )
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL,
                "MySard overlay",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Arabic subtitles stay above the PlayStation HDMI input."
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val launch = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL)
            .setContentTitle("MySard")
            .setContentText("الترجمة العربية جاهزة فوق صورة البلايستيشن")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(launch)
            .build()
    }
}

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, KeepAliveService::class.java),
                        )
                        result.success(currentStatus())
                    }
                    "status" -> result.success(currentStatus())
                    "cacheDir" -> result.success(cacheDir.absolutePath)
                    "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("path", "Missing apk path", null)
                        } else {
                            installApk(File(path))
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    MysardRuntime.sink = events
                    events.success(currentStatus())
                }

                override fun onCancel(arguments: Any?) {
                    MysardRuntime.sink = null
                }
            })
    }

    override fun onResume() {
        super.onResume()
        MysardRuntime.emit(currentStatus())
    }

    private fun currentStatus(): Map<String, Any?> = mapOf(
        "type" to "status",
        "ip" to MysardRuntime.localIpv4(),
        "port" to MysardRuntime.port,
        "pin" to MysardRuntime.pin,
        "clients" to (MysardRuntime.server?.clientCount() ?: 0),
        "overlay" to Settings.canDrawOverlays(this),
        "running" to (MysardRuntime.server != null),
    )

    private fun installApk(file: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}

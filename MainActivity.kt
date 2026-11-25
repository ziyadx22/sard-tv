package com.ziyad.mysard.mysard_tv

import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ziyad.mysard/overlay"
    private var windowManager: WindowManager? = null
    private var subtitleView: TextView? = null
    private var params: WindowManager.LayoutParams? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOverlay" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        showOverlayWindow()
                        result.success(true)
                    }
                }
                "stopOverlay" -> {
                    removeOverlayWindow()
                    result.success(true)
                }
                "updateText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val fontSize = (call.argument<Double>("fontSize") ?: 28.0).toFloat()
                    val bottomPadding = call.argument<Int>("bottomPadding") ?: 60
                    val bgOpacity = call.argument<Double>("bgOpacity") ?: 0.80
                    val textColor = call.argument<String>("textColor") ?: "#FFFFFF"
                    updateOverlayView(text, fontSize, bottomPadding, bgOpacity, textColor)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showOverlayWindow() {
        if (subtitleView != null) return
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val bg = GradientDrawable().apply {
            setColor(Color.argb(204, 0, 0, 0))
            cornerRadius = 20f
        }

        subtitleView = TextView(this).apply {
            text = "وضع البلايستيشن نشط ✅ بانتظار الترجمة..."
            textSize = 26f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = bg
            gravity = Gravity.CENTER
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(36, 18, 36, 18)
        }

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 60
        }

        windowManager?.addView(subtitleView, params)
    }

    private fun removeOverlayWindow() {
        if (subtitleView != null) {
            windowManager?.removeView(subtitleView)
            subtitleView = null
        }
    }

    private fun updateOverlayView(text: String, fontSize: Float, bottomPadding: Int, bgOpacity: Double, colorHex: String) {
        subtitleView?.post {
            if (text.isNotEmpty()) subtitleView?.text = text
            subtitleView?.textSize = fontSize * 0.72f
            try {
                subtitleView?.setTextColor(Color.parseColor(colorHex))
            } catch (_: Exception) {}
            val alpha = (bgOpacity * 255).toInt().coerceIn(0, 255)
            val bg = GradientDrawable().apply {
                setColor(Color.argb(alpha, 0, 0, 0))
                cornerRadius = 20f
            }
            subtitleView?.background = bg
            params?.y = bottomPadding
            windowManager?.updateViewLayout(subtitleView, params)
        }
    }
}

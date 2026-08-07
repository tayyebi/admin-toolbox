package com.admin.toolbox

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val SECURE_DISPLAY_CHANNEL = "admin_toolbox/secure_display"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // FLAG_SECURE keeps the window out of screenshots and blanks the
        // task-switcher thumbnail. Applied by default and only relaxed if the
        // user turns the setting off, so a decrypted key is never the thing
        // sitting in a recents preview.
        setSecure(true)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_DISPLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        setSecure(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setSecure(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
                )
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}

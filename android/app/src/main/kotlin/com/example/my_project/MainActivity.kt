package com.example.muchet

import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "uchetsd/security"
    ).setMethodCallHandler { call, result ->
      if (call.method == "setSecureScreen") {
        val enabled = call.argument<Boolean>("enabled") ?: false
        runOnUiThread {
          if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
          } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
          }
        }
        result.success(true)
      } else {
        result.notImplemented()
      }
    }
  }
}

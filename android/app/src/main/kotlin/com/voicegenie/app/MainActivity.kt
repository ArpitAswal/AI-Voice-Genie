package com.voicegenie.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Security flag — uncomment to block screenshots and screen recording
        // window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.configureFlutterEngine(flutterEngine)

        // Register the native image-save MethodChannel.
        // This gives Flutter access to MediaStore on Android 10+ and the
        // legacy filesystem path on Android 9 and below.
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.voicegenie.app/image_save"
        )
        ImageSavePlugin.register(applicationContext, channel)
    }
}
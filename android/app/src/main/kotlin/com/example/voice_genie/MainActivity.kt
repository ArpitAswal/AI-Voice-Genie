package com.example.voice_genie

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // This line prevents screenshots and screen recording
//        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.configureFlutterEngine(flutterEngine)
    }
}
package com.example.counter

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "counter/wear",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWear" -> {
                    val isWatch =
                        packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH)
                    result.success(isWatch)
                }

                "isRound" -> {
                    result.success(resources.configuration.isScreenRound)
                }
                else -> result.notImplemented()
            }
        }
    }
}

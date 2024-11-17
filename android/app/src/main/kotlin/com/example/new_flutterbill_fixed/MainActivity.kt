package com.example.flutterbill

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rawbt.intent.channel"
    private val RAWBT_PACKAGE_NAME = "ru.a402d.rawbtprinter"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendToRawBT") {
                val text = call.argument<String>("text")
                val type = call.argument<String>("type") ?: "text/plain"

                if (text.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Text to print is missing", null)
                    return@setMethodCallHandler
                }

                // Check if RawBT is installed
                if (!isAppInstalled(RAWBT_PACKAGE_NAME)) {
                    result.error("UNAVAILABLE", "RawBT app not found", null)
                    return@setMethodCallHandler
                }

                val intent = Intent(Intent.ACTION_SEND).apply {
                    setType(type)
                    putExtra(Intent.EXTRA_TEXT, text)
                    setPackage(RAWBT_PACKAGE_NAME)
                }

                try {
                    startActivity(intent)
                    result.success("Sent to RawBT")
                } catch (e: Exception) {
                    result.error("FAILED", "Failed to send to RawBT: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}

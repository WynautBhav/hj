package com.saheli.saheli

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.view.Display
import android.telephony.SmsManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val SCREEN_EVENT_CHANNEL = "com.saheli.saheli/screen_events"
    private val METHOD_CHANNEL = "com.saheli.saheli/shield"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val app = application as? SaheliApplication

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    app?.screenStateListener = { isScreenOn ->
                        events?.success(isScreenOn)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    app?.screenStateListener = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isScreenOn" -> {
                    val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                    val isScreenOn = displayManager.getDisplay(Display.DEFAULT_DISPLAY).state != Display.STATE_OFF
                    result.success(isScreenOn)
                }
                "wakeUpScreen" -> {
                    try {
                        val intent = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WAKE_ERR", e.message, null)
                    }
                }
                "sendSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        sendSmsNatively(phone, message, result)
                    } else {
                        result.error("INVALID_ARGS", "Phone or message missing", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSmsNatively(phone: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
            return
        }

        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_ERR", e.message, null)
        }
    }
}

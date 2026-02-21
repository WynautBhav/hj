package com.saheli.saheli

import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
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
import android.media.AudioManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import androidx.core.content.ContextCompat
import android.app.PendingIntent
import android.telephony.TelephonyManager
import android.provider.Settings
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.app.Activity

class MainActivity : FlutterActivity() {
    private val SCREEN_EVENT_CHANNEL = "com.saheli.saheli/screen_events"
    private val METHOD_CHANNEL = "com.saheli.saheli/shield"

    // Volume Down ×3 SOS via MediaSession
    // MediaSession is Play-Protect safe — it's the official Android API
    // for receiving media key events, including volume keys, even when
    // the screen is locked or the app is backgrounded.
    private var mediaSession: MediaSession? = null
    private val volumeTimestamps = mutableListOf<Long>()
    private val VOLUME_PRESS_COUNT = 3
    private val VOLUME_TIME_WINDOW_MS = 2000L
    private val VOLUME_DEBOUNCE_MS = 300L
    private var lastVolumePress = 0L
    private var volumeSosMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val app = application as? SaheliApplication

        // Screen event channel (existing)
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

        // Method channel (existing + volume SOS)
        volumeSosMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        volumeSosMethodChannel!!.setMethodCallHandler { call, result ->
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
                "enableVolumeSos" -> {
                    initMediaSession()
                    result.success(true)
                }
                "disableVolumeSos" -> {
                    releaseMediaSession()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Intercept physical volume-down key presses.
    // This works when the app is in foreground and also supplements
    // MediaSession for locked-screen detection.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            handleVolumeDown()
            // Return false to allow normal volume change too
            return false
        }
        return super.onKeyDown(keyCode, event)
    }

    // MediaSession setup — receives media key events even when screen is locked
    private fun initMediaSession() {
        if (mediaSession != null) return

        try {
            mediaSession = MediaSession(this, "MedusaVolumeSOS").apply {
                // Set playback state to PLAYING so the session is "active"
                // and receives media button events from the system
                setPlaybackState(
                    PlaybackState.Builder()
                        .setState(PlaybackState.STATE_PLAYING, 0, 1f)
                        .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE)
                        .build()
                )

                setCallback(object : MediaSession.Callback() {
                    override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                        val event = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                        }

                        if (event?.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN &&
                            event.action == KeyEvent.ACTION_DOWN) {
                            handleVolumeDown()
                        }
                        return super.onMediaButtonEvent(mediaButtonIntent)
                    }
                })

                isActive = true
            }
        } catch (e: Exception) {
            // Log safely — do NOT crash. Shake + Power SOS remain active.
            android.util.Log.w("MedusaVolumeSOS", "MediaSession init failed: ${e.message}")
        }
    }

    private fun releaseMediaSession() {
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
            volumeTimestamps.clear()
        } catch (e: Exception) {
            android.util.Log.w("MedusaVolumeSOS", "MediaSession release failed: ${e.message}")
        }
    }

    // Track volume-down presses with timestamp window (same pattern as PowerButtonService)
    private fun handleVolumeDown() {
        val now = System.currentTimeMillis()

        // Debounce rapid duplicate events
        if (now - lastVolumePress < VOLUME_DEBOUNCE_MS) return
        lastVolumePress = now

        // Remove timestamps outside the detection window
        volumeTimestamps.removeAll { now - it > VOLUME_TIME_WINDOW_MS }
        volumeTimestamps.add(now)

        // Trigger SOS on 3 presses within window
        if (volumeTimestamps.size >= VOLUME_PRESS_COUNT) {
            volumeTimestamps.clear()
            triggerVolumeSos()
        }
    }

    // Notify Flutter to trigger SOS via MethodChannel
    private fun triggerVolumeSos() {
        try {
            runOnUiThread {
                volumeSosMethodChannel?.invokeMethod("onVolumeSosTriggered", null)
            }
        } catch (e: Exception) {
            android.util.Log.w("MedusaVolumeSOS", "SOS trigger failed: ${e.message}")
        }
    }

    private var smsRequestCodeCounter = 0

    private fun sanitizePhone(phone: String): String {
        return phone.trim().replace(Regex("[^+\\d]"), "")
    }

    private fun sendSmsNatively(phone: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.e("MedusaSMS", "Permission denied")
            result.success(false)
            return
        }

        try {
            val smsManager: SmsManager = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    this.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
            } catch (e: Exception) {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            
            val cleanPhone = sanitizePhone(phone)
            val parts = smsManager.divideMessage(message)
            val totalParts = parts.size
            
            val action = "com.saheli.saheli.SMS_SENT_${smsRequestCodeCounter++}"
            var partsCompleted = 0
            var anySuccess = false

            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    partsCompleted++
                    if (resultCode == Activity.RESULT_OK) {
                        anySuccess = true
                    } else {
                        android.util.Log.e("MedusaSMS", "SMS failed with resultCode: $resultCode")
                    }
                    
                    if (partsCompleted >= totalParts) {
                        try {
                            context?.unregisterReceiver(this)
                        } catch (e: Exception) {}
                        result.success(anySuccess)
                    }
                }
            }
            
            val intentFilter = IntentFilter(action)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                applicationContext.registerReceiver(receiver, intentFilter, Context.RECEIVER_EXPORTED)
            } else {
                applicationContext.registerReceiver(receiver, intentFilter)
            }
            
            val sentIntents = ArrayList<PendingIntent>()
            for (i in 0 until totalParts) {
                val intent = Intent(action)
                intent.setPackage(applicationContext.packageName) // Critical for routing system intent explicitly
                val pi = PendingIntent.getBroadcast(
                    applicationContext, i, intent, 
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                sentIntents.add(pi)
            }
            
            if (totalParts > 1) {
                smsManager.sendMultipartTextMessage(cleanPhone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(cleanPhone, null, message, sentIntents[0], null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MedusaSMS", "SMS send failed: ${e.message}")
            result.success(false)
        }
    }

    override fun onDestroy() {
        releaseMediaSession()
        super.onDestroy()
    }
}

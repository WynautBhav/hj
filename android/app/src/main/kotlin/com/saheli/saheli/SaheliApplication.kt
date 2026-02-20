package com.saheli.saheli

import io.flutter.app.FlutterApplication
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build

class SaheliApplication : FlutterApplication() {
    var screenStateListener: ((Boolean) -> Unit)? = null

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON -> screenStateListener?.invoke(true)
                Intent.ACTION_SCREEN_OFF -> screenStateListener?.invoke(false)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Screen events are system broadcasts, but on modern Android 
            // some devices require explicit flags even for system ones if registered in app process.
            // Using RECEIVER_EXPORTED as these are system-wide events we listen to.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onTerminate() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            // Ignore if not registered
        }
        super.onTerminate()
    }
}

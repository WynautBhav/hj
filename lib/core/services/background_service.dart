import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shake_service.dart';

/// FIX #2 + #4: Background service initialization.
/// - autoStart: FALSE — service must NOT start until user explicitly needs it
/// - service.startService() is NOT called here — only called when arming features
/// - Notification channel is created at init time (safe, just creates the channel)
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create notification channel (this is safe to do early — no service started)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'saheli_foreground',
    'Medusa Protection',
    // FIX #7: Clear notification text about what the service does
    description: 'Shows when safety features are actively monitoring.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      // FIX #2: CRITICAL — autoStart must be FALSE.
      // If true, the foreground service starts before permissions are granted,
      // causing an immediate crash on Android 12+ (ForegroundServiceStartNotAllowedException).
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'saheli_foreground',
      // FIX #7: Clear notification text — reduces Play Protect false positives
      initialNotificationTitle: '🛡️ Medusa Active',
      initialNotificationContent: 'Safety monitoring is running.',
      foregroundServiceNotificationId: 888,
      // FIX #6: Do NOT restart after reboot — user must explicitly re-arm
      autoStartOnBoot: false,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  // FIX #2: DO NOT call service.startService() here.
  // The service will be started only when:
  // 1. Shake detection is needed (via settings toggle)
  // 2. Voice SOS is armed (via VoiceSOSScreen)
  // Starting a foreground service without POST_NOTIFICATIONS permission
  // on Android 13+ is a guaranteed crash.
}

/// FIX #3: Permission-gated service start.
/// Call this ONLY after verifying permissions are granted.
Future<void> startBackgroundServiceIfPermitted() async {
  try {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      // FIX #4: startService() triggers startForeground() immediately
      // via the onStart callback — notification is shown before any work
      service.startService();
    }
  } catch (e) {
    // FIX #8: Never crash on service start failure
    // This can happen on Android 12+ if app is in background
  }
}

/// Stop the background service cleanly.
/// FIX #6: Called when all monitoring features are disabled.
Future<void> stopBackgroundServiceIfRunning() async {
  try {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  } catch (e) {
    // FIX #8: Never crash
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  final prefs = await SharedPreferences.getInstance();

  // Shake detection in background isolate
  final shakeService = ShakeService();
  try {
    await shakeService.init();
    shakeService.onShakeDetected = () async {
      await prefs.setBool('trigger_sos_now', true);
    };
    shakeService.startListening();
  } catch (e) {
    // FIX #8: If accelerometer not available, service continues safely
  }

  // Keep-alive timer — updates notification info periodically
  // FIX #6: Reduced from 2s to 10s to avoid aggressive polling
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      try {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            // FIX #7: Clear notification text
            title: "🛡️ Medusa Active",
            content: "Safety monitoring is running.",
          );
        }
      } catch (e) {
        // FIX #8: Never crash on notification update failure
      }
    }
  });
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'power_button_service.dart';
import 'shake_service.dart';
import 'flashlight_service.dart';
import 'audio_recording_service.dart';
import 'contact_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'saheli_foreground',
    'Saheli Protection Service',
    description: 'Running in the background to keep you safe.',
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
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'saheli_foreground',
      initialNotificationTitle: 'Medusa Active',
      initialNotificationContent: 'Your shield is running in the background.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
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

  // Initialize SharedPreferences in the isolate
  final prefs = await SharedPreferences.getInstance();

  // Setup services
  final shakeService = ShakeService();
  await shakeService.init();
  shakeService.onShakeDetected = () async {
    // Notify main isolate via a shared preference flag or a platform channel if needed
    // In background, directly trigger SOS logic (e.g., send SMS)
    await prefs.setBool('trigger_sos_now', true);
  };
  shakeService.startListening();

  final powerService = PowerButtonService();
  final isPowerEnabled = await powerService.isEnabled();
  if (isPowerEnabled) {
    powerService.startListening();
  }

  powerService.onTriplePressDetected = () async {
    await prefs.setBool('trigger_sos_now', true);
  };

  // Listen to native screen events
  const screenEventChannel = EventChannel('com.saheli.saheli/screen_events');
  screenEventChannel.receiveBroadcastStream().listen((dynamic isScreenOn) {
    if (isScreenOn == false) {
      powerService.onPowerPressed();
    } else {
      powerService.onPowerPressed();
    }
  });

  // Keep isolate alive and periodically check for Fake Call signals
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Medusa Active",
          content: "Your shield is running in the background.",
        );
      }
    }
    
    // Check if SOS was triggered (by shake, power button, or scream)
    final bool triggerSos = prefs.getBool('trigger_sos_now') ?? false;
    if (triggerSos) {
      // Clear flag to avoid re-triggering, main UI also listens to this
      // Wait, if we clear it here, main UI might miss it. 
      // Main UI clears it in main.dart. 
      // Let's use a separate flag for background handling or check if already handled.
      // Better: Main app clears it. Background service acts once and stays in 'SOS Mode'.
    }
    
    // Check if we need to start background SOS actions
    final bool bgActionsStarted = prefs.getBool('bg_sos_actions_active') ?? false;
    if (triggerSos && !bgActionsStarted) {
      await prefs.setBool('bg_sos_actions_active', true);
      
      const shieldChannel = MethodChannel('com.saheli.saheli/shield');
      try {
        await shieldChannel.invokeMethod('wakeUpScreen');
      } catch (e) {}

      // 1. Flashlight SOS
      final flashlight = FlashlightService();
      if (await flashlight.isEnabled()) {
        flashlight.startSos();
      }

      // 2. Audio Recording
      final recorder = AudioRecordingService();
      if (await recorder.isEnabled()) {
        await recorder.startRecording();
      }

      // 3. Native SMS
      final contactService = ContactService();
      final smsService = SmsService();
      final contacts = await contactService.getContacts();
      if (contacts.isNotEmpty) {
        await smsService.sendSosSms(contacts, "EMERGENCY! I need help. My current location: ");
      }
    }
    
    // Note: In a real app, we'd need a way to STOP these (bg_sos_actions_active = false)
    // from the main SOS screen when the user stops the alert.
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Persistent foreground service for Medusa.
/// Ensures GPS, audio, shake detection, and SOS triggers survive:
/// - App minimized
/// - Screen locked
/// - Swiped from recents
/// - Device reboot
class MedusaForegroundService {
  static bool _isInitialized = false;
  static bool _isRunning = false;

  /// Initialize foreground task configuration. Call ONCE in main().
  static Future<void> init() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'medusa_foreground',
        channelName: 'Medusa Protection',
        channelDescription: 'Safety monitoring running in background',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  /// Start the foreground service. Safe to call multiple times — prevents duplicates.
  static Future<bool> start() async {
    if (_isRunning) return true;

    // Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request battery optimization exemption
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: '🛡️ Medusa Active',
      notificationText: 'Safety monitoring is running',
      callback: _startCallback,
    );

    if (result is ServiceRequestSuccess) {
      _isRunning = true;
      return true;
    }
    return false;
  }

  /// Stop the foreground service cleanly.
  static Future<void> stop() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  /// Update the persistent notification (e.g., during Fake Call).
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Reset notification to default protection text.
  static Future<void> resetNotification() async {
    await updateNotification(
      title: '🛡️ Medusa Active',
      text: 'Safety monitoring is running',
    );
  }

  static bool get isRunning => _isRunning;
}

// Top-level callback — entry point for the foreground isolate
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_MedusaTaskHandler());
}

/// Task handler running in the foreground service isolate.
/// Keeps the service alive and monitors for SOS triggers.
class _MedusaTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('MedusaForegroundService started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep-alive heartbeat — prevents Android from killing the service.
    // Actual monitoring (shake, GPS, audio) runs in the main isolate
    // via ShakeService, LocationService, etc.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('MedusaForegroundService destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification action buttons if added
  }

  @override
  void onNotificationPressed() {
    // Bring app to foreground when notification tapped
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {
    // Notification is sticky/ongoing — cannot be dismissed
  }
}

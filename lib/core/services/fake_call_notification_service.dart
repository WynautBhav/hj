import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Full-screen intent notification service for fake incoming calls.
/// Uses fullScreenIntent: true to show on lockscreen and wake device.
class FakeCallNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _callChannelId = 'fake_call_channel';
  static const _callNotificationId = 999;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    // Create high-priority call channel
    const channel = AndroidNotificationChannel(
      _callChannelId,
      'Incoming Calls',
      description: 'Fake call alerts that show on lockscreen',
      importance: Importance.max,
      playSound: false, // app handles its own ringtone
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show an incoming call notification with full-screen intent.
  /// On lockscreen, this takes over the screen (like a real call).
  /// On Android 14+, if full-screen intent is denied, falls back to heads-up.
  static Future<void> showIncomingCall(String callerName) async {
    try {
      if (!_initialized) await init();

      await _plugin.show(
        _callNotificationId,
        '📞 Incoming Call',
        callerName,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _callChannelId,
            'Incoming Calls',
            channelDescription: 'Fake call alerts',
            category: AndroidNotificationCategory.call,
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            visibility: NotificationVisibility.public,
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'decline',
                'Decline',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'accept',
                'Accept',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Never crash on notification failure — fake call still works in foreground
    }
  }

  /// Dismiss the incoming call notification.
  static Future<void> dismissCall() async {
    try {
      await _plugin.cancel(_callNotificationId);
    } catch (e) {
      // Never crash
    }
  }
}

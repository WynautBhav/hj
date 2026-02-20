import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Volume Down ×3 SOS service.
/// Uses Android MediaSession via MethodChannel to detect volume-down
/// triple-press even when screen is locked or app is backgrounded.
/// This is Play-Protect safe — no accessibility services used.
class VolumeSosService {
  static const _channel = MethodChannel('com.saheli.saheli/shield');
  static const _enabledKey = 'volume_sos_enabled';
  static bool _isListening = false;

  /// Callback fired when volume-down is pressed 3× within 2 seconds
  static Function()? onTriplePressDetected;

  /// Enable volume SOS and start MediaSession listener
  static Future<void> start() async {
    if (_isListening) return;

    try {
      await _channel.invokeMethod('enableVolumeSos');
      _isListening = true;

      // Listen for SOS trigger from native side
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onVolumeSosTriggered') {
          onTriplePressDetected?.call();
        }
      });
    } catch (e) {
      // MediaSession failed — Shake + Power SOS remain active
    }
  }

  /// Disable volume SOS and release MediaSession
  static Future<void> stop() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod('disableVolumeSos');
      _isListening = false;
    } catch (e) {
      // Safe to ignore
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  static bool get isListening => _isListening;
}

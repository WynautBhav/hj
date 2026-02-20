import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central state manager for all SOS services.
/// Uses ValueNotifier for reactive UI updates without setState.
/// State is persisted in SharedPreferences for cross-isolate access.
class SosStateManager {
  static final SosStateManager _instance = SosStateManager._();
  factory SosStateManager() => _instance;
  SosStateManager._();

  // Observable state — UI binds via ValueListenableBuilder
  final ValueNotifier<bool> isServiceRunning = ValueNotifier(false);
  final ValueNotifier<bool> isShakeArmed = ValueNotifier(false);
  final ValueNotifier<bool> isVolumeArmed = ValueNotifier(false);
  final ValueNotifier<bool> isVoiceArmed = ValueNotifier(false);
  final ValueNotifier<bool> isPowerButtonArmed = ValueNotifier(false);
  final ValueNotifier<bool> isFakePowerOffActive = ValueNotifier(false);

  /// Load persisted state from SharedPreferences.
  /// Call once on app startup after services are initialized.
  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isShakeArmed.value = prefs.getBool('shake_armed') ?? true;
      isVolumeArmed.value = prefs.getBool('volume_sos_enabled') ?? true;
      isVoiceArmed.value = prefs.getBool('voice_sos_armed') ?? false;
      isPowerButtonArmed.value = prefs.getBool('power_button_enabled') ?? true;
    } catch (e) {
      debugPrint('SosStateManager.loadState failed: $e');
    }
  }

  /// Persist a single state change.
  Future<void> setShakeArmed(bool armed) async {
    isShakeArmed.value = armed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shake_armed', armed);
  }

  Future<void> setVolumeArmed(bool armed) async {
    isVolumeArmed.value = armed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('volume_sos_enabled', armed);
  }

  Future<void> setVoiceArmed(bool armed) async {
    isVoiceArmed.value = armed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_sos_armed', armed);
  }

  Future<void> setPowerButtonArmed(bool armed) async {
    isPowerButtonArmed.value = armed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('power_button_enabled', armed);
  }

  void setServiceRunning(bool running) {
    isServiceRunning.value = running;
  }

  void setFakePowerOffActive(bool active) {
    isFakePowerOffActive.value = active;
  }
}

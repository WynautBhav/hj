import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PowerButtonService {
  static const String _enabledKey = 'power_button_enabled';
  
  final List<DateTime> _pressTimestamps = [];
  Function()? onTriplePressDetected;
  
  static const int _requiredPresses = 3;
  static const Duration _timeWindow = Duration(seconds: 2);
  static const Duration _debounceTime = Duration(milliseconds: 800);
  
  bool _isListening = false;
  DateTime? _lastPressTime;

  PowerButtonService();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    
    if (enabled) {
      startListening();
    } else {
      stopListening();
    }
  }

  bool get isListening => _isListening;

  void startListening() {
    _isListening = true;
  }

  void onPowerPressed() {
    if (!_isListening) return;
    
    final now = DateTime.now();
    
    if (_lastPressTime != null && 
        now.difference(_lastPressTime!) < _debounceTime) {
      return;
    }
    
    _lastPressTime = now;
    
    _pressTimestamps.removeWhere((t) => now.difference(t) > _timeWindow);
    _pressTimestamps.add(now);
    
    if (_pressTimestamps.length >= _requiredPresses) {
      _pressTimestamps.clear();
      onTriplePressDetected?.call();
    }
  }

  void stopListening() {
    _isListening = false;
    _pressTimestamps.clear();
  }

  void dispose() {
    stopListening();
  }
}

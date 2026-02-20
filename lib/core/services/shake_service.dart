import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShakeSensitivity { low, medium, high }

class ShakeService {
  static const String _sensitivityKey = 'shake_sensitivity';
  
  StreamSubscription? _accelerometerSubscription;
  final List<DateTime> _shakeTimestamps = [];
  Function()? onShakeDetected;
  
  static const int _requiredShakes = 3;
  static const Duration _shakeWindow = Duration(seconds: 3);
  static const Duration _debounceTime = Duration(milliseconds: 400);
  
  static const Map<ShakeSensitivity, double> _thresholds = {
    ShakeSensitivity.low: 18.0,
    ShakeSensitivity.medium: 14.0,
    ShakeSensitivity.high: 10.0,
  };

  ShakeSensitivity _currentSensitivity = ShakeSensitivity.medium;
  bool _isListening = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final sensitivityStr = prefs.getString(_sensitivityKey);
    _currentSensitivity = ShakeSensitivity.values.firstWhere(
      (s) => s.name == sensitivityStr,
      orElse: () => ShakeSensitivity.medium,
    );
  }

  Future<void> setSensitivity(ShakeSensitivity sensitivity) async {
    _currentSensitivity = sensitivity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sensitivityKey, sensitivity.name);
  }

  ShakeSensitivity get sensitivity => _currentSensitivity;

  bool get isListening => _isListening;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen((event) {
        final magnitude = sqrt(
          event.x * event.x + 
          event.y * event.y + 
          event.z * event.z
        );
        
        final threshold = _thresholds[_currentSensitivity]!;
        
        if (magnitude > threshold) {
          _onShake();
        }
      });
    } catch (e) {
      _isListening = false;
    }
  }

  void _onShake() {
    final now = DateTime.now();
    
    if (_shakeTimestamps.isNotEmpty) {
      final lastShake = _shakeTimestamps.last;
      if (now.difference(lastShake) < _debounceTime) {
        return;
      }
    }
    
    _shakeTimestamps.add(now);
    
    _shakeTimestamps.removeWhere((t) => 
      now.difference(t) > _shakeWindow
    );
    
    if (_shakeTimestamps.length >= _requiredShakes) {
      _shakeTimestamps.clear();
      onShakeDetected?.call();
    }
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isListening = false;
  }

  void dispose() {
    stopListening();
  }
}

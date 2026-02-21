import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShakeSensitivity { low, medium, high }

class ShakeService {
  // Keys — must match sensitivity_settings_screen.dart exactly
  static const String _sensitivityKey = 'shake_sensitivity';   // stored as double
  static const String _countKey       = 'shake_count';          // stored as int
  static const String _timeoutKey     = 'shake_timeout';        // stored as double (seconds)

  StreamSubscription? _accelerometerSubscription;
  final List<DateTime> _shakeTimestamps = [];
  Function()? onShakeDetected;

  static const Duration _debounceTime = Duration(milliseconds: 400);

  // Loaded from prefs — gravity-free thresholds (userAccelerometer reads 0 at rest)
  double _thresholdG = 6.0;   // acceleration magnitude threshold (m/s²), gravity removed
  int _requiredShakes = 3;
  Duration _shakeWindow = const Duration(seconds: 3);

  bool _isListening = false;

  // For backward compat — derived from threshold
  ShakeSensitivity get sensitivity {
    if (_thresholdG >= 10.0) return ShakeSensitivity.low;
    if (_thresholdG >= 5.0) return ShakeSensitivity.medium;
    return ShakeSensitivity.high;
  }

  bool get isListening => _isListening;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Read double sensitivity (0.5–5.0 from settings screen)
    // Map to acceleration threshold (gravity-free):
    //   sensitivity 0.5 → threshold 12 (hard to trigger, need violent shake)
    //   sensitivity 5.0 → threshold 3  (easy to trigger, gentle shake)
    final sensitivityDouble = prefs.getDouble(_sensitivityKey) ?? 2.5;
    _thresholdG = (12.0 - (sensitivityDouble - 0.5) * (9.0 / 4.5)).clamp(3.0, 12.0);

    // Read shake count
    _requiredShakes = (prefs.getInt(_countKey) ?? 3).clamp(1, 10);

    // Read time window
    final timeoutSeconds = (prefs.getDouble(_timeoutKey) ?? 3.0).clamp(1.0, 10.0);
    _shakeWindow = Duration(milliseconds: (timeoutSeconds * 1000).toInt());
  }

  Future<void> setSensitivity(ShakeSensitivity sensitivity) async {
    final doubleValue = {
      ShakeSensitivity.low: 1.5,
      ShakeSensitivity.medium: 2.5,
      ShakeSensitivity.high: 4.0,
    }[sensitivity]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sensitivityKey, doubleValue);
    await init();
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _shakeTimestamps.clear();

    try {
      // userAccelerometerEventStream removes gravity automatically:
      //   - At rest: ~0 m/s² (not ~9.8)
      //   - SensorInterval enum (not Duration) for sensors_plus 5.x compat
      _accelerometerSubscription = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((event) {
        final magnitude = sqrt(
          event.x * event.x +
          event.y * event.y +
          event.z * event.z
        );
        if (magnitude > _thresholdG) {
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
      if (now.difference(lastShake) < _debounceTime) return;
    }

    _shakeTimestamps.add(now);
    _shakeTimestamps.removeWhere((t) => now.difference(t) > _shakeWindow);

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

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

class FlashlightService {
  static final FlashlightService _instance = FlashlightService._internal();
  factory FlashlightService() => _instance;
  FlashlightService._internal();

  static const String _enabledKey = 'flashlight_sos_enabled';
  
  Timer? _sosTimer;
  bool _isFlashing = false;
  int _patternIndex = 0;
  
  static const List<int> _sosPattern = [
    200, 200, 200, 200, 200, 200,
    600, 200, 600, 200, 600, 200,
    200, 200, 200, 200, 200, 200,
  ];

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<bool> _hasTorch() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      return false;
    }
  }

  Future<void> startSos() async {
    if (_isFlashing) return;
    
    final hasTorch = await _hasTorch();
    if (!hasTorch) return;
    
    _isFlashing = true;
    _patternIndex = 0;
    _playPattern();
  }

  void _playPattern() {
    if (!_isFlashing || _patternIndex >= _sosPattern.length) {
      _patternIndex = 0;
      if (_isFlashing) {
        _playPattern();
      }
      return;
    }

    final duration = _sosPattern[_patternIndex];
    final isOn = _patternIndex % 2 == 0;
    
    try {
      if (isOn) {
        TorchLight.enableTorch();
      } else {
        TorchLight.disableTorch();
      }
    } catch (e) {
      // Handle error
    }
    
    _patternIndex++;
    _sosTimer = Timer(Duration(milliseconds: duration), _playPattern);
  }

  void stopSos() {
    _isFlashing = false;
    _sosTimer?.cancel();
    _sosTimer = null;
    
    try {
      TorchLight.disableTorch();
    } catch (e) {
      // Handle error
    }
  }

  void dispose() {
    stopSos();
  }
}

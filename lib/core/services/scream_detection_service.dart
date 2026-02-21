import 'dart:async';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ScreamDetectionService {
  static const String _enabledKey = 'scream_detection_enabled';
  static const String _thresholdKey = 'scream_threshold';
  
  StreamSubscription? _amplitudeSubscription;
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _cancelTimer;
  bool _isDetecting = false;
  bool _isCountingDown = false;
  Function()? onScreamDetected;
  Function()? onCountdownStart;
  Function()? onCancel;
  
  static const double defaultThreshold = 80.0;

  ScreamDetectionService({this.onScreamDetected, this.onCountdownStart, this.onCancel});

  Future<void> init() async {}

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<double> getThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_thresholdKey) ?? defaultThreshold;
    return value.clamp(30.0, 100.0);
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

  Future<void> setThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, threshold);
  }

  bool get isActive => _isDetecting;
  bool get isCountingDown => _isCountingDown;

  Future<void> startListening() async {
    if (_isDetecting) return;
    
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
      
      _isDetecting = true;

      // FIX #3: The record package only emits amplitude events during
      // an active recording session. Without start(), the stream emits
      // nothing and scream detection is completely non-functional.
      final tempDir = await getTemporaryDirectory();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 16000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: '${tempDir.path}/scream_monitor.aac',
      );
      
      final stream = _recorder.onAmplitudeChanged(const Duration(milliseconds: 500));
      _amplitudeSubscription = stream.listen((amp) {
        final db = amp.current;
        _checkThreshold(db);
      });
    } catch (e) {
      _isDetecting = false;
    }
  }

  void stopListening() {
    _isDetecting = false;
    _isCountingDown = false;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _cancelTimer?.cancel();
    _recorder.stop();
  }

  void _checkThreshold(double db) async {
    if (_isCountingDown) return;
    
    final threshold = await getThreshold();
    
    if (db > threshold) {
      _triggerCountdown();
    }
  }

  void _triggerCountdown() {
    _isCountingDown = true;
    _amplitudeSubscription?.cancel();
    _recorder.stop();
    
    onCountdownStart?.call();
    
    _cancelTimer = Timer(const Duration(seconds: 3), () async {
      if (_isCountingDown) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('trigger_sos_now', true);
        onScreamDetected?.call();
      }
      _isCountingDown = false;
    });
  }

  void cancelDetection() {
    _cancelTimer?.cancel();
    _cancelTimer = null;
    _isCountingDown = false;
    onCancel?.call();
    startListening();
  }

  void dispose() {
    stopListening();
    _cancelTimer?.cancel();
  }
}

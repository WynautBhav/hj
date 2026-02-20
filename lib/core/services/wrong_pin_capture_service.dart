import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WrongPinCaptureService {
  static const String _enabledKey = 'wrong_pin_capture_enabled';
  static const String _attemptsKey = 'wrong_pin_attempts';
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  int _failedAttempts = 0;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await _initCamera();
    } else {
      await _disposeCamera();
    }
  }

  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey) ?? 0;
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;
      
      // FIX #2: Select FRONT camera for intruder selfie capture
      // Falls back to first available camera if no front camera found
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  Future<void> _disposeCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
  }

  Future<String?> capturePhoto() async {
    if (!_isInitialized || _cameraController == null) {
      await _initCamera();
      if (!_isInitialized) return null;
    }
    
    try {
      final image = await _cameraController!.takePicture();
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${directory.path}/intruder_$timestamp.jpg';
      
      final file = File(image.path);
      await file.copy(newPath);
      await file.delete();
      
      _failedAttempts++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_attemptsKey, _failedAttempts);
      
      return newPath;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getCapturedPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((f) => f.path.contains('intruder_'))
          .map((f) => f.path)
          .toList();
      return files;
    } catch (e) {
      return [];
    }
  }

  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> resetAttempts() async {
    _failedAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_attemptsKey, 0);
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
  }
}

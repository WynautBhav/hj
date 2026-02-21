import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  static const String _enabledKey = 'audio_recording_enabled';
  static const String _autoRecordKey = 'audio_auto_record';
  
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  
  static const int maxRecordingDurationMinutes = 30;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> isAutoRecord() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRecordKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setAutoRecord(bool autoRecord) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRecordKey, autoRecord);
  }

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    if (_isRecording) return false;
    
    final hasPermission = await this.hasPermission();
    if (!hasPermission) return false;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/sos_recording_$timestamp.m4a';
      
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    try {
      await _recorder.stop();
      _isRecording = false;
      final path = _currentRecordingPath;
      _currentRecordingPath = null;
      return path;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    
    try {
      await _recorder.stop();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore errors
    }
    _isRecording = false;
    _currentRecordingPath = null;
  }

  bool get isRecording => _isRecording;

  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  Future<List<String>> getRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((f) => f.path.contains('sos_recording_'))
          .map((f) => f.path)
          .toList();
      return files;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> deleteAllRecordings() async {
    final recordings = await getRecordings();
    for (final path in recordings) {
      await deleteRecording(path);
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_phrase.dart';
import 'speech_recognition_service.dart';

/// In-app Voice SOS service. Runs in the foreground (main isolate).
/// No background service — avoids conflict with the existing one.
class VoiceSOSService {
  static const String _phraseKey = 'voice_phrase';
  static const String _isArmedKey = 'voice_sos_armed';

  static VoiceSOSService? _instance;
  factory VoiceSOSService() => _instance ??= VoiceSOSService._();
  VoiceSOSService._();

  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  VoicePhrase? _storedPhrase;
  bool _isArmed = false;
  bool _isListening = false;

  // Callbacks
  Function(String)? onPhraseDetected;
  Function(String)? onRecognized;
  Function(String)? onError;
  Function()? onListeningStarted;
  Function()? onListeningStopped;

  bool get isArmed => _isArmed;
  bool get isListening => _isListening;

  Future<bool> arm() async {
    final prefs = await SharedPreferences.getInstance();
    final phraseJson = prefs.getString(_phraseKey);
    if (phraseJson == null) {
      onError?.call('No phrase configured');
      return false;
    }

    try {
      _storedPhrase = VoicePhrase.fromJsonString(phraseJson);
    } catch (e) {
      onError?.call('Invalid phrase data');
      return false;
    }

    final initialized = await _speechService.initialize();
    if (!initialized) {
      onError?.call('Speech recognition not available. Check internet.');
      return false;
    }

    _isArmed = true;
    await prefs.setBool(_isArmedKey, true);

    _setupCallbacks();
    await _startContinuousListening();
    return true;
  }

  void _setupCallbacks() {
    _speechService.onResult = (recognizedText) {
      onRecognized?.call(recognizedText);

      if (_storedPhrase != null &&
          _storedPhrase!.matchesRecognizedText(recognizedText)) {
        onPhraseDetected?.call(_storedPhrase!.phrase);
      }
    };

    _speechService.onListeningStopped = () {
      // Auto-restart listening if still armed
      if (_isArmed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isArmed) _startContinuousListening();
        });
      }
    };

    _speechService.onError = (error) {
      onError?.call(error);
      // Try to restart on recoverable errors
      if (_isArmed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_isArmed) _startContinuousListening();
        });
      }
    };
  }

  Future<void> _startContinuousListening() async {
    if (!_isArmed || _isListening) return;

    _isListening = true;
    onListeningStarted?.call();

    await _speechService.startListening(
      localeId: _storedPhrase?.language ?? 'en_US',
      targetPhrase: _storedPhrase,
    );
  }

  Future<void> disarm() async {
    _isArmed = false;
    _isListening = false;

    await _speechService.stopListening();
    onListeningStopped?.call();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isArmedKey, false);
  }

  Future<bool> isServiceArmed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isArmedKey) ?? false;
  }

  void dispose() {
    _isArmed = false;
    _isListening = false;
    _speechService.dispose();
  }
}

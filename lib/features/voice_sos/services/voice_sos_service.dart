import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_phrase.dart';
import 'speech_recognition_service.dart';

/// In-app Voice SOS service. Runs in the foreground (main isolate).
/// FIX #5: STT is initialized ONLY in main UI isolate — never in background.
/// FIX #3: Permissions are checked BEFORE starting any mic access.
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

  /// FIX #3: Permission-gated arm.
  /// Microphone + notification permissions must be granted before starting.
  Future<bool> arm() async {
    // FIX #3: Step 1 — Check microphone permission FIRST
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        onError?.call('Microphone permission required for Voice SOS');
        return false;
      }
    }

    // FIX #3: Step 2 — Check notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        // Non-fatal — warn user but allow arming (notifications optional)
        onError?.call('Enable notifications for reliable Voice SOS');
      }
    }

    // Step 3 — Load saved phrase
    final prefs = await SharedPreferences.getInstance();
    final phraseJson = prefs.getString(_phraseKey);
    if (phraseJson == null) {
      onError?.call('No phrase configured');
      return false;
    }

    try {
      _storedPhrase = VoicePhrase.fromJsonString(phraseJson);
    } catch (e) {
      // FIX #8: Graceful handling of corrupted data
      onError?.call('Invalid phrase data. Please reconfigure.');
      return false;
    }

    // FIX #5: Initialize STT only in main isolate, only after mic permission
    final initialized = await _initializeSpeech();
    if (!initialized) {
      return false;
    }

    // FIX #3: Step 3 — ONLY after permissions granted, start listening
    _isArmed = true;
    await prefs.setBool(_isArmedKey, true);

    _setupCallbacks();
    await _startContinuousListening();
    return true;
  }

  /// FIX #5: Safe STT initialization with graceful failure.
  Future<bool> _initializeSpeech() async {
    try {
      final initialized = await _speechService.initialize();
      if (!initialized) {
        onError?.call(
          'Speech recognition not available. Check microphone and internet.'
        );
        return false;
      }
      return true;
    } catch (e) {
      // FIX #8: STT init failure must never crash the app
      onError?.call('Speech recognition failed to start');
      return false;
    }
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
      _isListening = false;
      // FIX #6: Auto-restart listening ONLY if still armed
      if (_isArmed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isArmed) _startContinuousListening();
        });
      }
    };

    _speechService.onError = (error) {
      onError?.call(error);
      _isListening = false;
      // FIX #5: On STT error, retry safely after delay (not infinite loop)
      if (_isArmed) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_isArmed) _startContinuousListening();
        });
      }
    };
  }

  Future<void> _startContinuousListening() async {
    if (!_isArmed || _isListening) return;

    try {
      _isListening = true;
      onListeningStarted?.call();

      await _speechService.startListening(
        localeId: _storedPhrase?.language ?? 'en_US',
        targetPhrase: _storedPhrase,
      );
    } catch (e) {
      // FIX #8: Never crash on listen failure
      _isListening = false;
      onError?.call('Listening failed. Retrying...');
      // Retry after delay
      if (_isArmed) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_isArmed) _startContinuousListening();
        });
      }
    }
  }

  /// FIX #6: Clean disarm — stops listening and clears state.
  Future<void> disarm() async {
    _isArmed = false;
    _isListening = false;

    try {
      await _speechService.stopListening();
    } catch (e) {
      // FIX #8: Never crash on stop failure
    }
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
    try {
      _speechService.dispose();
    } catch (e) {
      // FIX #8: Never crash on dispose
    }
  }
}

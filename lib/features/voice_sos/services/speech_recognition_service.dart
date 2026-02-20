import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/voice_phrase.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  Function(String)? onResult;
  Function()? onListeningStarted;
  Function()? onListeningStopped;
  Function(String)? onError;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          onError?.call(error.errorMsg);
          _isListening = false;
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStopped?.call();
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  Future<void> startListening({
    String localeId = 'en_US',
    VoicePhrase? targetPhrase,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Speech recognition not available');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    _isListening = true;
    onListeningStarted?.call();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final recognizedText = result.recognizedWords;
        
        if (recognizedText.isNotEmpty) {
          onResult?.call(recognizedText);
        }

        if (result.finalResult && targetPhrase != null) {
          if (targetPhrase.matchesRecognizedText(recognizedText)) {
            _isListening = false;
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: localeId,
      listenMode: ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
    onListeningStopped?.call();
  }

  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speech.locales();
  }

  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}

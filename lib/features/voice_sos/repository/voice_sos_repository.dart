import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_phrase.dart';
import '../services/voice_sos_service.dart';

class VoiceSOSRepository {
  static const String _phraseKey = 'voice_phrase';
  static const String _isArmedKey = 'voice_sos_armed';

  final VoiceSOSService _voiceService = VoiceSOSService();

  Future<void> initialize() async {
    // No background service to initialize anymore
  }

  Future<VoicePhrase?> getStoredPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    final phraseJson = prefs.getString(_phraseKey);

    if (phraseJson == null) return null;

    try {
      return VoicePhrase.fromJsonString(phraseJson);
    } catch (e) {
      return null;
    }
  }

  Future<void> savePhrase(VoicePhrase phrase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phraseKey, phrase.toJsonString());
  }

  Future<void> deletePhrase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phraseKey);
    await prefs.setBool(_isArmedKey, false);
  }

  Future<bool> isArmed() async {
    return _voiceService.isArmed;
  }

  Future<bool> armVoiceSOS() async {
    return await _voiceService.arm();
  }

  Future<void> disarmVoiceSOS() async {
    await _voiceService.disarm();
  }

  /// Set callbacks on the underlying service
  void setOnPhraseDetected(Function(String) callback) {
    _voiceService.onPhraseDetected = callback;
  }

  void setOnRecognized(Function(String) callback) {
    _voiceService.onRecognized = callback;
  }

  void setOnError(Function(String) callback) {
    _voiceService.onError = callback;
  }

  void dispose() {
    _voiceService.dispose();
  }
}

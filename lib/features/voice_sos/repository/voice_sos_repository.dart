import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_phrase.dart';
import '../services/voice_sos_service.dart';

class VoiceSOSRepository {
  static const String _phraseKey = 'voice_phrase';
  static const String _isArmedKey = 'voice_sos_armed';

  final VoiceSOSService _voiceService;

  VoiceSOSRepository({VoiceSOSService? voiceService})
      : _voiceService = voiceService ?? VoiceSOSService();

  Future<void> initialize() async {
    await VoiceSOSService.initializeService();
  }

  Future<VoicePhrase?> getStoredPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    final phraseJson = prefs.getString(_phraseKey);
    
    if (phraseJson == null) return null;
    
    try {
      final Map<String, dynamic> phraseMap = jsonDecode(phraseJson);
      return VoicePhrase.fromJson(phraseMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> savePhrase(VoicePhrase phrase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phraseKey, jsonEncode(phrase.toJson()));
  }

  Future<void> deletePhrase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phraseKey);
    await prefs.setBool(_isArmedKey, false);
  }

  Future<bool> isArmed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isArmedKey) ?? false;
  }

  Future<void> setArmed(bool armed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isArmedKey, armed);
  }

  Future<bool> armVoiceSOS() async {
    final phrase = await getStoredPhrase();
    if (phrase == null) {
      return false;
    }

    final started = await VoiceSOSService.startService();
    if (started) {
      await setArmed(true);
      VoiceSOSService.startListening();
      return true;
    }
    return false;
  }

  Future<void> disarmVoiceSOS() async {
    VoiceSOSService.stopListening();
    await VoiceSOSService.stopService();
    await setArmed(false);
  }

  Future<bool> checkPermissions() async {
    return true;
  }

  Stream<Map<String, dynamic>?> get serviceEvents {
    return VoiceSOSService.onEvent;
  }

  void dispose() {
    VoiceSOSService.dispose();
  }
}

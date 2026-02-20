import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playRingtone() async {
    if (_isPlaying) return;
    
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setVolume(1.0);
      await _ringtonePlayer.play(UrlSource('https://www.soundjay.com/buttons/sounds/beep-07a.mp3'));
      _isPlaying = true;
    } catch (e) {
      HapticFeedback.vibrate();
      _startVibrationPattern();
    }
  }

  void _startVibrationPattern() {
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  Future<void> stopRingtone() async {
    if (!_isPlaying) return;
    
    try {
      await _ringtonePlayer.stop();
      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
    }
  }

  void dispose() {
    _ringtonePlayer.dispose();
  }
}

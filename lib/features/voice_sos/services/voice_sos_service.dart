import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_phrase.dart';
import '../services/speech_recognition_service.dart';

class VoiceSOSService {
  static const String _serviceName = 'voice_sos_service';
  static const String _phraseKey = 'voice_phrase';
  static const String _isArmedKey = 'voice_sos_armed';

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'voice_sos_channel',
      'Voice SOS Active',
      description: 'Listening for your safety phrase',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'voice_sos_channel',
        initialNotificationTitle: 'Voice SOS Active',
        initialNotificationContent: 'Listening for your safety phrase',
        foregroundServiceNotificationId: 889,
        foregroundServiceTypes: [AndroidForegroundType.microphone],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final speechService = SpeechRecognitionService();
    VoicePhrase? storedPhrase;
    bool isListening = false;

    service.on('start_listening').listen((event) async {
      if (isListening) return;

      final prefs = await SharedPreferences.getInstance();
      final phraseJson = prefs.getString(_phraseKey);
      
      if (phraseJson == null) {
        service.invoke('error', {'message': 'No phrase configured'});
        return;
      }

      try {
        final phraseMap = Map<String, dynamic>.from(
          (phraseJson as Map<String, dynamic>),
        );
        storedPhrase = VoicePhrase.fromJson(phraseMap);
      } catch (e) {
        service.invoke('error', {'message': 'Invalid phrase data'});
        return;
      }

      isListening = true;
      service.invoke('listening_started');

      await speechService.initialize();

      speechService.onResult = (recognizedText) {
        service.invoke('recognized', {'text': recognizedText});
        
        if (storedPhrase != null && 
            storedPhrase!.matchesRecognizedText(recognizedText)) {
          service.invoke('phrase_detected', {'phrase': storedPhrase!.phrase});
        }
      };

      speechService.onListeningStopped = () {
        if (isListening) {
          speechService.startListening(
            localeId: storedPhrase?.language ?? 'en_US',
            targetPhrase: storedPhrase,
          );
        }
      };

      speechService.onError = (error) {
        service.invoke('error', {'message': error});
      };

      await speechService.startListening(
        localeId: storedPhrase?.language ?? 'en_US',
        targetPhrase: storedPhrase,
      );
    });

    service.on('stop_listening').listen((event) async {
      isListening = false;
      await speechService.stopListening();
      service.invoke('listening_stopped');
    });

    service.on('dispose').listen((event) {
      speechService.dispose();
      service.stopSelf();
    });
  }

  static Future<bool> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      return await _service.startService();
    }
    return true;
  }

  static Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stop_listening');
    }
  }

  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  static Stream<Map<String, dynamic>?> get onEvent {
    return _service.on('update');
  }

  static void startListening() {
    _service.invoke('start_listening');
  }

  static void stopListening() {
    _service.invoke('stop_listening');
  }

  static Future<void> dispose() async {
    _service.invoke('dispose');
  }
}

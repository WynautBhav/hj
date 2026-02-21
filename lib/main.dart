import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/services/shake_service.dart';
import 'core/services/power_button_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/location_service.dart';
import 'core/services/contact_service.dart';
import 'core/services/guardian_service.dart';
import 'features/calculator_disguise/calculator_screen.dart';
import 'features/home/home_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/permission/permission_request_screen.dart';
import 'features/fake_call/fake_call_screen.dart';
import 'core/services/background_service.dart';
import 'core/services/foreground_service.dart';
import 'core/services/volume_sos_service.dart';
import 'core/services/sos_state_manager.dart';
import 'core/services/sos_history_service.dart';
import 'core/services/scream_detection_service.dart';
import 'features/voice_sos/services/voice_sos_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/services/supabase_service.dart';
import 'core/services/fake_call_notification_service.dart';
import 'features/area_safety/services/community_signal_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initializion failed: $e');
  }

  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('Background service init failed: $e');
  }

  try {
    await MedusaForegroundService.init();
  } catch (e) {
    debugPrint('Foreground task init failed: $e');
  }

  // Initialize fake call notification channel
  try {
    await FakeCallNotificationService.init();
  } catch (e) {
    debugPrint('Fake call notification init failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MedusaApp());
}

class MedusaApp extends StatefulWidget {
  const MedusaApp({super.key});

  @override
  State<MedusaApp> createState() => _MedusaAppState();
}

class _MedusaAppState extends State<MedusaApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _showOnboarding = false;
  bool _showPermissions = false;
  String _userName = '';
  late ShakeService _shakeService;
  late PowerButtonService _powerButtonService;
  Timer? _bgCheckTimer;
  bool _servicesStarted = false;
  DateTime? _lastSosTrigger;
  ScreamDetectionService? _screamService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _checkOnboarding();
    _startBackgroundListener();
  }

  void _startBackgroundListener() {
    _bgCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (prefs.getBool('trigger_sos_now') == true) {
          await prefs.setBool('trigger_sos_now', false);
          _triggerSos('shake');
        }
        if (prefs.getBool('trigger_fake_call_now') == true) {
          await prefs.setBool('trigger_fake_call_now', false);
          _triggerFakeCall();
        }
        // Fix 3A: Watch for force_relock signal from data wipe
        if (prefs.getBool('force_relock') == true) {
          await prefs.setBool('force_relock', false);
          if (mounted) {
            setState(() {
              _isUnlocked = false;
              _servicesStarted = false;
            });
          }
        }
      } catch (e) {
        // SharedPreferences can throw on concurrent access
      }
    });

    // Listen for foreground task heartbeat + trigger_sos pings
    try {
      FlutterForegroundTask.addTaskDataCallback((data) {
        final dataStr = data.toString();
        if (dataStr == 'voice_sos_check') {
          _checkAndRearmVoiceSos();
        } else if (dataStr.startsWith('trigger_sos:')) {
          final type = dataStr.split(':').length > 1 ? dataStr.split(':')[1] : 'shake';
          _triggerSos(type);
        }
      });
    } catch (e) {
      debugPrint('FG task callback setup failed: $e');
    }

    // Listen for network reconnect to sync offline Supabase data
    try {
      Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        if (!results.contains(ConnectivityResult.none)) {
          SosHistoryService().syncOfflineEvents();
          CommunitySignalService().syncOfflineSignals();
        }
      });
    } catch (e) {
      debugPrint('Connectivity listener setup failed: $e');
    }
  }

  void _checkAndRearmVoiceSos() async {
    try {
      final voiceSos = VoiceSOSService();
      if (voiceSos.isArmed && !voiceSos.isListening) {
        await voiceSos.rearm();
        voiceSos.onPhraseDetected = (_) => _triggerSos('voice');
      }
    } catch (e) {
      // Never crash on heartbeat callback
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgCheckTimer?.cancel();
    _shakeService.dispose();
    _powerButtonService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _safeResumeListeners();
    }
  }

  Future<void> _initServices() async {
    // Initialize shake service reference (startListening deferred to _startProtectionServices)
    _shakeService = ShakeService();

    try {
      _powerButtonService = PowerButtonService();
      _powerButtonService.onTriplePressDetected = () => _triggerSos('power');
      final isEnabled = await _powerButtonService.isEnabled();
      if (isEnabled) {
        _powerButtonService.startListening();
      }
    } catch (e) {
      _powerButtonService = PowerButtonService();
      debugPrint('Power button service init failed: $e');
    }
  }

  Future<void> _startProtectionServices() async {
    if (_servicesStarted) return;
    _servicesStarted = true;

    // Foreground task service (heartbeat pings)
    try {
      await MedusaForegroundService.start();
    } catch (e) {
      debugPrint('Foreground service start failed: $e');
    }

    // Background isolate (runs ShakeService in separate isolate for when app is killed)
    try {
      await startBackgroundServiceIfPermitted();
    } catch (e) {
      debugPrint('Background service start failed: $e');
    }

    // Volume Down ×3 SOS
    try {
      final volumeEnabled = await VolumeSosService.isEnabled();
      if (volumeEnabled) {
        VolumeSosService.onTriplePressDetected = () => _triggerSos('volume');
        await VolumeSosService.start();
      }
    } catch (e) {
      debugPrint('Volume SOS init failed: $e');
    }

    // Shake: arm after unlock
    try {
      await _shakeService.init();
      _shakeService.onShakeDetected = () => _triggerSos('shake');
      _shakeService.startListening();
    } catch (e) {
      debugPrint('Shake arm failed: $e');
    }

    // Scream detection
    try {
      _screamService = ScreamDetectionService();
      final screamEnabled = await _screamService!.isEnabled();
      if (screamEnabled) {
        _screamService!.onScreamDetected = () => _triggerSos('scream');
        await _screamService!.startListening();
      }
    } catch (e) {
      debugPrint('Scream detection init failed: $e');
    }
  }

  Future<void> _safeResumeListeners() async {
    try {
      if (_servicesStarted) {
        _shakeService.onShakeDetected = () => _triggerSos('shake');
        _shakeService.startListening();
      }
      final isEnabled = await _powerButtonService.isEnabled();
      if (isEnabled) {
        _powerButtonService.startListening();
      }
    } catch (e) {
      // Never crash on resume
    }

    // Voice SOS re-arm
    try {
      final voiceSos = VoiceSOSService();
      final wasArmed = await voiceSos.isServiceArmed();
      if (wasArmed && !voiceSos.isListening) {
        await voiceSos.arm();
        voiceSos.onPhraseDetected = (_) => _triggerSos('voice');
      }
    } catch (e) {
      debugPrint('Voice SOS resume failed: $e');
    }

    // Scream detection re-arm
    try {
      if (_screamService != null && _servicesStarted) {
        final screamEnabled = await _screamService!.isEnabled();
        if (screamEnabled && !_screamService!.isActive) {
          _screamService!.onScreamDetected = () => _triggerSos('scream');
          await _screamService!.startListening();
        }
      }
    } catch (e) {
      debugPrint('Scream re-arm failed: $e');
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final name = prefs.getString('user_name') ?? '';
    final permissionsAsked = prefs.getBool('permissions_asked') ?? false;

    setState(() {
      _showOnboarding = !onboardingComplete;
      _showPermissions = onboardingComplete && !permissionsAsked;
      _userName = name;
    });
  }

  void _triggerSos([String triggerType = 'manual']) {
    if (!mounted) return;
    if (!_isUnlocked) return; // Don't fire on calculator screen

    // Debounce: prevent double-trigger within 10 seconds
    final now = DateTime.now();
    if (_lastSosTrigger != null &&
        now.difference(_lastSosTrigger!) < const Duration(seconds: 10)) {
      return;
    }
    _lastSosTrigger = now;

    // Record SOS event in history with correct trigger type
    _recordSosHistory(triggerType);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SosScreen(
          autoTrigger: triggerType != 'manual',
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Notify guardian device via BLE if connected
    _notifyGuardian();
  }

  /// Records SOS to SQLite history asynchronously — never blocks the SOS trigger.
  void _recordSosHistory(String triggerType) {
    Future(() async {
      try {
        final locationService = LocationService();
        final contactService = ContactService();
        final pos = await locationService.getCurrentPosition();
        final contacts = await contactService.getContacts();
        await SosHistoryService().recordSos(
          triggerType: triggerType,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          contactsNotified: contacts.length,
        );
      } catch (e) {
        // Never crash on history recording
      }
    });
  }

  /// Notify guardian device via BLE if connected.
  void _notifyGuardian() {
    Future(() async {
      try {
        final guardianService = GuardianService();
        if (!await guardianService.isEnabled()) return;
        if (!guardianService.isConnected) return;

        final locationService = LocationService();
        final pos = await locationService.getCurrentPosition();
        final link = pos != null
            ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
            : 'Location unavailable';
        await guardianService.sendSosAlert(locationLink: link);
      } catch (e) {
        // Never crash on guardian notify failure
      }
    });
  }

  void _triggerFakeCall() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FakeCallScreen()),
      );
    }
  }

  void _onUnlocked() {
    setState(() => _isUnlocked = true);

    _startProtectionServices();

    SosStateManager().loadState();
    SosStateManager().setServiceRunning(true);

    _showBatteryOptimizationHint();
  }

  Future<void> _showBatteryOptimizationHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('battery_opt_dismissed') == true) return;

    final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
    if (isIgnoring) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_alert_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Background Protection', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          'To keep Medusa protection active in the background, '
          'please disable battery optimization for this app.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('battery_opt_dismissed', true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setBool('battery_opt_dismissed', true);
              await openAppSettings();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';

    setState(() {
      _showOnboarding = false;
      _showPermissions = true;
      _userName = name;
    });
  }

  void _onPermissionsComplete() async {
    await PermissionService.markPermissionsAsked();
    setState(() => _showPermissions = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: AppColors.lightTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: _showOnboarding
            ? OnboardingScreen(
                key: const ValueKey('onboarding'),
                onComplete: _onOnboardingComplete,
              )
            : _showPermissions
                ? PermissionRequestScreen(
                    key: const ValueKey('permissions'),
                    onComplete: _onPermissionsComplete,
                  )
                : _isUnlocked
                    ? HomeScreen(
                        key: const ValueKey('home'),
                        userName: _userName,
                      )
                    : CalculatorDisguiseScreen(
                        key: const ValueKey('calculator'),
                        onUnlocked: _onUnlocked,
                      ),
      ),
    );
  }
}

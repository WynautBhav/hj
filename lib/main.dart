import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/services/shake_service.dart';
import 'core/services/power_button_service.dart';
import 'core/services/permission_service.dart';
import 'features/calculator_disguise/calculator_screen.dart';
import 'features/home/home_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/permission/permission_request_screen.dart';
import 'features/fake_call/fake_call_screen.dart';
import 'core/services/background_service.dart';
import 'core/services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX #2 + #8: Initialize background service configuration ONLY.
  // This just creates the notification channel and configures the service.
  // The actual service is NOT started here (autoStart: false).
  // Wrapped in try-catch so init failure never kills the app.
  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('Background service init failed: $e');
  }

  // Initialize foreground task (just configures — does NOT start service yet)
  try {
    await MedusaForegroundService.init();
  } catch (e) {
    debugPrint('Foreground task init failed: $e');
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _checkOnboarding();
    _startBackgroundListener();
  }

  void _startBackgroundListener() {
    // FIX #6: Poll SharedPreferences for SOS/fake-call triggers from background.
    // This is the ONLY bridge between the background isolate and the UI.
    _bgCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('trigger_sos_now') == true) {
          await prefs.setBool('trigger_sos_now', false);
          _triggerSos();
        }
        if (prefs.getBool('trigger_fake_call_now') == true) {
          await prefs.setBool('trigger_fake_call_now', false);
          _triggerFakeCall();
        }
      } catch (e) {
        // FIX #8: SharedPreferences can throw on concurrent access
      }
    });
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
      _initBackgroundServices();
    }
  }

  Future<void> _initServices() async {
    // FIX #8: Wrap service init in try-catch — accelerometer may not be available
    try {
      _shakeService = ShakeService();
      await _shakeService.init();
      _shakeService.onShakeDetected = _triggerSos;
      _shakeService.startListening();
    } catch (e) {
      _shakeService = ShakeService(); // Fallback: create but don't listen
      debugPrint('Shake service init failed: $e');
    }

    try {
      _powerButtonService = PowerButtonService();
      _powerButtonService.onTriplePressDetected = _triggerSos;
      final isEnabled = await _powerButtonService.isEnabled();
      if (isEnabled) {
        _powerButtonService.startListening();
      }
    } catch (e) {
      _powerButtonService = PowerButtonService();
      debugPrint('Power button service init failed: $e');
    }

    // Start foreground service after other services are ready
    try {
      await MedusaForegroundService.start();
    } catch (e) {
      debugPrint('Foreground service start failed: $e');
    }
  }

  Future<void> _initBackgroundServices() async {
    try {
      _shakeService.startListening();
      final isEnabled = await _powerButtonService.isEnabled();
      if (isEnabled) {
        _powerButtonService.startListening();
      }
    } catch (e) {
      // FIX #8: Never crash on resume
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

  void _triggerSos() {
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SosScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
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

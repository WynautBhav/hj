import 'dart:math' show sin, cos;
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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

class _MedusaAppState extends State<MedusaApp> {
  bool _isUnlocked = false;
  bool _showOnboarding = false;
  bool _permissionsShown = false;
  String _userName = '';
  late ShakeService _shakeService;
  late PowerButtonService _powerButtonService;

  @override
  void initState() {
    super.initState();
    _setHighRefreshRate();
    _initServices();
    _checkOnboarding();
  }

  void _setHighRefreshRate() {
    // High refresh rate is automatically handled by Flutter on modern devices
    // The system will use the device's native refresh rate (60/90/120Hz)
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final name = prefs.getString('user_name') ?? '';
    
    setState(() {
      _showOnboarding = !onboardingComplete;
      _userName = name;
    });
  }

  Future<void> _initServices() async {
    _shakeService = ShakeService();
    await _shakeService.init();
    _shakeService.onShakeDetected = _triggerSos;
    _shakeService.startListening();

    _powerButtonService = PowerButtonService();
    _powerButtonService.onTriplePressDetected = _triggerSos;
    final isEnabled = await _powerButtonService.isEnabled();
    if (isEnabled) {
      _powerButtonService.startListening();
    }
  }

  @override
  void dispose() {
    _shakeService.dispose();
    _powerButtonService.dispose();
    super.dispose();
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

  void _onUnlocked() {
    setState(() => _isUnlocked = true);
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    
    setState(() {
      _showOnboarding = false;
      _userName = name;
    });

    if (!mounted) return;
    _showPermissionDialog();
  }

  void _showPermissionDialog() async {
    final shouldAsk = await PermissionService.shouldAskPermissions();
    if (shouldAsk && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PermissionRequestDialog(
          onComplete: (results) {
            setState(() => _permissionsShown = true);
          },
        ),
      );
    }
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

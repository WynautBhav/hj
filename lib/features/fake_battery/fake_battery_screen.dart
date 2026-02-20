import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/foreground_service.dart';
import '../../core/services/sos_state_manager.dart';

/// Fake Power Off screen — convincing phone shutdown illusion.
///
/// Two modes:
/// 1. SETUP: Shows instructions + activate button
/// 2. ACTIVE: Full immersive black overlay with:
///    - "Shutting down…" animation → total black screen
///    - Touch input absorbed (nothing happens on tap)
///    - Audio recording + GPS tracking continue underneath
///    - Exit ONLY via power button ×3 (via SharedPreferences trigger)
///    - Back button blocked (PopScope)
///    - No status bar, no navigation bar
class FakeBatteryScreen extends StatefulWidget {
  const FakeBatteryScreen({super.key});

  @override
  State<FakeBatteryScreen> createState() => _FakeBatteryScreenState();
}

class _FakeBatteryScreenState extends State<FakeBatteryScreen>
    with SingleTickerProviderStateMixin {
  bool _isActive = false;
  bool _isShuttingDown = false; // Animation phase
  bool _isFullBlack = false;    // After animation
  final AudioRecordingService _audioService = AudioRecordingService();
  final LocationService _locationService = LocationService();
  final SosStateManager _stateManager = SosStateManager();
  bool _isRecording = false;
  bool _isTracking = false;
  Timer? _exitCheckTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isActive) return _buildActiveOverlay();
    return _buildSetupScreen();
  }

  // ────────────── SETUP SCREEN ──────────────

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Fake Power Off'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.power_settings_new_rounded,
                      size: 64, color: AppColors.warning),
                  SizedBox(height: 16),
                  Text(
                    'Fake Power Off',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Shows a realistic shutdown animation, then goes '
                    'completely black. Audio recording and GPS tracking '
                    'continue silently underneath.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textSecondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Press power button 3 times quickly to exit the fake screen',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _activateFakePowerOff,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Activate Fake Power Off',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ────────────── ACTIVE OVERLAY ──────────────

  Widget _buildActiveOverlay() {
    return PopScope(
      canPop: false, // Block back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AbsorbPointer(
          // Absorb all touch input — nothing happens on tap
          absorbing: _isFullBlack,
          child: GestureDetector(
            onTap: () {}, // Eat taps during shutdown animation too
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                if (_isFullBlack) {
                  // Total black — nothing visible
                  return const SizedBox.expand(
                    child: ColoredBox(color: Colors.black),
                  );
                }

                if (_isShuttingDown) {
                  // Shutting down animation
                  return SizedBox.expand(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.power_settings_new_rounded,
                                  color: Colors.white54, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Shutting down…',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return const SizedBox.expand(
                  child: ColoredBox(color: Colors.black),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ────────────── ACTIVATION ──────────────

  Future<void> _activateFakePowerOff() async {
    // Enter immersive mode — hide ALL system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _isActive = true;
      _isShuttingDown = true;
    });
    _stateManager.setFakePowerOffActive(true);

    // Update foreground notification
    MedusaForegroundService.updateNotification(
      title: '🛡️ Medusa Active',
      text: 'Protection monitoring enabled',
    );

    // Start shutdown animation
    _fadeController.forward().then((_) {
      if (mounted) {
        setState(() {
          _isShuttingDown = false;
          _isFullBlack = true;
        });
      }
    });

    // Start background services
    try {
      final recording = await _audioService.startRecording();
      _isRecording = recording;
    } catch (e) {
      debugPrint('Audio recording failed: $e');
    }

    try {
      final tracking = await _locationService.startTracking();
      _isTracking = tracking;
    } catch (e) {
      debugPrint('Location tracking failed: $e');
    }

    // Poll for power button ×3 exit trigger (via SharedPreferences)
    _startExitListener();
  }

  /// Listen for power button ×3 trigger to exit fake power off.
  /// The PowerButtonService sets 'trigger_sos_now' in SharedPreferences
  /// which we repurpose here — if fake power off is active, exit instead
  /// of triggering SOS.
  void _startExitListener() {
    _exitCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (prefs.getBool('trigger_sos_now') == true) {
          // If fake power off is active, consume the trigger as exit signal
          await prefs.setBool('trigger_sos_now', false);
          _deactivateFakePowerOff();
        }
      } catch (e) {
        // Never crash
      }
    });
  }

  void _deactivateFakePowerOff() async {
    _exitCheckTimer?.cancel();
    _stateManager.setFakePowerOffActive(false);

    try {
      if (_isRecording) await _audioService.stopRecording();
    } catch (e) {
      debugPrint('Audio stop failed: $e');
    }

    _locationService.stopTracking();
    MedusaForegroundService.resetNotification();

    setState(() {
      _isActive = false;
      _isShuttingDown = false;
      _isFullBlack = false;
      _isRecording = false;
      _isTracking = false;
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _fadeController.reset();
  }

  @override
  void dispose() {
    _exitCheckTimer?.cancel();
    _fadeController.dispose();
    if (_isActive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _stateManager.setFakePowerOffActive(false);
    }
    if (_isRecording) {
      _audioService.stopRecording();
    }
    _locationService.stopTracking();
    _audioService.dispose();
    super.dispose();
  }
}

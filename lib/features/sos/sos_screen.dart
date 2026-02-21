import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/contact_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/flashlight_service.dart';
import '../../core/services/audio_recording_service.dart';

class SosScreen extends StatefulWidget {
  final bool autoTrigger;
  const SosScreen({super.key, this.autoTrigger = false});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

// FIX #1: TickerProviderStateMixin required when using multiple AnimationControllers
class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  bool _isActivating = false;
  int _countdown = 5;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Auto-trigger: when fired from shake/voice/scream, skip manual press
    if (widget.autoTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    FlashlightService().stopSos();
    AudioRecordingService().stopRecording();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _isActivating = true);
    HapticFeedback.heavyImpact();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        HapticFeedback.lightImpact();
      });
      
      if (_countdown <= 0) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _isActivating = false;
      _countdown = 5;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _triggerSos() async {
    int _successCount = 0;
    int _totalContacts = 0;

    // Always start evidence collection — regardless of contacts
    try {
      FlashlightService().startSos();
    } catch (e) {
      // Flashlight may not be available
    }
    try {
      AudioRecordingService().startRecording();
    } catch (e) {
      // Recording may fail
    }

    // Attempt SMS if contacts exist
    try {
      final contactService = ContactService();
      final contacts = await contactService.getContacts();
      _totalContacts = contacts.length;

      if (contacts.isNotEmpty) {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        ) ?? await locationService.getCachedPosition();

        final locationLink = position != null
            ? locationService.getGoogleMapsLink(position.latitude, position.longitude)
            : 'Location unavailable';

        final message = '🆘 I am in DANGER! Location: $locationLink — Medusa';

        final smsService = SmsService();
        _successCount = await smsService.sendSosSms(contacts, message);
      }
    } catch (e) {
      debugPrint('SOS SMS error: $e');
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final resetAction = () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('bg_sos_actions_active', false);
            await prefs.setBool('trigger_sos_now', false);
            FlashlightService().stopSos();
            AudioRecordingService().stopRecording();
            if (context.mounted) {
              Navigator.pop(context);
              Navigator.pop(context);
            }
          };

          if (_totalContacts == 0) {
            return _SosNoContactsDialog(onOk: resetAction);
          } else if (_successCount == _totalContacts && _totalContacts > 0) {
            return _SosSentDialog(onOk: resetAction, partial: false);
          } else if (_successCount > 0) {
            return _SosSentDialog(onOk: resetAction, partial: true);
          } else {
            return _SosFailureDialog(onOk: resetAction);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE53935),
              const Color(0xFFC62828),
              const Color(0xFF8E0000),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildSosButton(),
                const SizedBox(height: 32),
                _buildInstructions(),
                const Spacer(),
                if (_isActivating)
                  _buildCancelButton()
                else
                  _buildHoldButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Location Active',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: -0.3, end: 0);
  }

  Widget _buildSosButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ringController]),
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseController.value * 0.1);
        final ringScale = 1.0 + (_ringController.value * 0.15);
        final ringOpacity = 1.0 - _ringController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (_isActivating)
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: ringOpacity * 0.5),
                      width: 3,
                    ),
                  ),
                ),
              ),
            Transform.scale(
              scale: pulseScale,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isActivating) ...[
                        Text(
                          '$_countdown',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'seconds',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.shield_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SOS',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Column(
      children: [
        Text(
          _isActivating 
              ? 'SOS will be sent in $_countdown seconds'
              : 'Hold to activate SOS',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        )
        .animate(target: _isActivating ? 1 : 0)
        .fadeIn()
        .then()
        .animate(target: _isActivating ? 1 : 0)
        .shimmer(duration: 1000.ms, color: Colors.white30),
        
        const SizedBox(height: 8),
        
        Text(
          _isActivating
              ? 'Tap to cancel'
              : 'Or shake phone 3× / press power 3×',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    return GestureDetector(
      onLongPress: _startCountdown,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: Text(
            'HOLD FOR 5 SECONDS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 300.ms, duration: 400.ms)
    .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 400.ms);
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _cancelCountdown,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFE53935),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'CANCEL',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _SosSentDialog extends StatelessWidget {
  final VoidCallback onOk;
  final bool partial;

  const _SosSentDialog({required this.onOk, this.partial = false});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: partial ? Colors.orange.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                partial ? Icons.warning_rounded : Icons.check_rounded,
                color: partial ? Colors.orange : Colors.green,
                size: 48,
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              curve: Curves.elasticOut,
              duration: 600.ms,
            ),
            
            const SizedBox(height: 24),
            
            Text(
              partial ? 'Partial Success' : 'SOS Sent!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms),
            
            const SizedBox(height: 12),
            
            Text(
              partial 
                ? 'Some SMS alerts failed to send. Check network signal for fully reliable delivery.' 
                : 'Emergency alert has been sent to your trusted contacts with your live location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: partial ? Colors.orange : const Color(0xFF7C5FD6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _SosNoContactsDialog extends StatelessWidget {
  final VoidCallback onOk;

  const _SosNoContactsDialog({required this.onOk});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              curve: Curves.elasticOut,
              duration: 600.ms,
            ),

            const SizedBox(height: 24),

            const Text(
              'No Contacts!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms),

            const SizedBox(height: 12),

            Text(
              'SOS was activated but no emergency contacts are saved. '
              'Flashlight & audio recording started.\n\n'
              'Go to Settings → Emergency Contacts to add contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _SosFailureDialog extends StatelessWidget {
  final VoidCallback onOk;

  const _SosFailureDialog({required this.onOk});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              curve: Curves.elasticOut,
              duration: 600.ms,
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'SMS Failed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
            .animate()
            .fadeIn(delay: 200.ms),
            
            const SizedBox(height: 12),
            
            Text(
              'Could not send SMS to any emergency contacts. Check your SIM card, network signal, and Airplane Mode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/contact_service.dart';
import '../../../core/services/location_service.dart';

class VoiceSOSCountdownOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const VoiceSOSCountdownOverlay({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<VoiceSOSCountdownOverlay> createState() =>
      _VoiceSOSCountdownOverlayState();
}

class _VoiceSOSCountdownOverlayState extends State<VoiceSOSCountdownOverlay>
    with SingleTickerProviderStateMixin {
  int _countdown = 5;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    HapticFeedback.heavyImpact();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      HapticFeedback.lightImpact();
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        _triggerSOSReal();
        widget.onConfirm();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    widget.onCancel();
  }

  Future<void> _triggerSOSReal() async {
    try {
      final contactService = ContactService();
      final contacts = await contactService.getContacts();

      if (contacts.isNotEmpty) {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        String message = '🆘 I am in DANGER! My last location: ';

        if (position != null) {
          message += locationService.getGoogleMapsLink(
            position.latitude,
            position.longitude,
          );
        }

        final smsService = SmsService();
        await smsService.sendSosSms(contacts, message);
      }
    } catch (_) {
      // Don't crash on SOS trigger failure
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_countdown',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'seconds',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              const Text(
                'SOS Detected!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Emergency will be triggered in $_countdown seconds',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to cancel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cancelCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CANCEL SOS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

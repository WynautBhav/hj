import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/foreground_service.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {
  String _callerName = 'Mom';
  int _delaySeconds = 0;
  bool _isCallActive = false;
  bool _isRinging = false;
  int _callDuration = 0;
  Timer? _callTimer;
  Timer? _delayTimer;
  final AudioService _audioService = AudioService();
  late final TextEditingController _nameCtrl;

  // Call wave animation
  late AnimationController _waveController;

  final _delays = [0, 5, 15, 30];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _callerName);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('fake_caller_name') ?? 'Mom';
    setState(() {
      _callerName = name;
      _nameCtrl.text = name;
    });
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fake_caller_name', name);
    setState(() => _callerName = name);
  }

  void _startFakeCall() async {
    final prefs = await SharedPreferences.getInstance();
    if (_delaySeconds == 0) {
      _triggerRinging();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fake call starting in $_delaySeconds seconds…'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _delayTimer = Timer(Duration(seconds: _delaySeconds), () async {
        await prefs.setBool('trigger_fake_call_now', true);
        _triggerRinging();
      });
    }
  }

  void _triggerRinging() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _isCallActive = true;
      _isRinging = true;
      _callDuration = 0;
    });
    _audioService.playRingtone();
    _startVibration();

    // Update foreground notification to call style
    MedusaForegroundService.updateNotification(
      title: '📞 Incoming Call',
      text: _callerName,
    );
  }

  void _startVibration() {
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!_isRinging || count > 20) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      count++;
    });
  }

  void _acceptCall() {
    _audioService.stopRingtone();
    setState(() => _isRinging = false);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration++);
    });

    // Update notification to ongoing call
    MedusaForegroundService.updateNotification(
      title: '📞 Call in progress',
      text: 'Talking to $_callerName',
    );
  }

  void _endCall() {
    _callTimer?.cancel();
    _delayTimer?.cancel();
    _audioService.stopRingtone();
    setState(() {
      _isCallActive = false;
      _isRinging = false;
      _callDuration = 0;
    });

    // Reset notification
    MedusaForegroundService.resetNotification();

    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  String get _formatted {
    final m = _callDuration ~/ 60;
    final s = _callDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _delayTimer?.cancel();
    _waveController.dispose();
    _audioService.stopRingtone();
    _nameCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    MedusaForegroundService.resetNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCallActive) return _buildCallScreen();
    return _buildSetupScreen();
  }

  // ────────────── SETUP SCREEN (unchanged layout) ──────────────

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fake Call',
                  style: Theme.of(context).textTheme.headlineMedium)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
              
              const SizedBox(height: 4),
              
              Text('Pretend to receive a call to escape danger',
                  style: Theme.of(context).textTheme.bodyMedium)
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 24),

              _buildCallerNameCard()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              _buildDelayCard()
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              _buildStartButton()
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: 16),

              _buildTipCard()
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallerNameCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CALLER NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            onChanged: _saveName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter caller name',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.scaffold,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CALL DELAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _delays.map((d) {
              final selected = d == _delaySeconds;
              final label = d == 0 ? 'Now' : '$d sec';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d != _delays.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _delaySeconds = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startFakeCall,
        icon: const Icon(Icons.phone_rounded, size: 20),
        label: const Text(
          'Start Fake Call',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.safeGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                children: [
                  TextSpan(
                      text: 'Tip: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                  const TextSpan(
                      text:
                          'Use this when you feel unsafe. The realistic call screen gives you an excuse to leave.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────── REALISTIC CALL SCREEN ──────────────

  Widget _buildCallScreen() {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            // Animated gradient background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CallWavePainter(
                      progress: _waveController.value,
                      isRinging: _isRinging,
                    ),
                  );
                },
              ),
            ),

            // Main call content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Call status text
                  Text(
                    _isRinging ? 'Incoming Call' : 'Connected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Avatar with pulse animation when ringing
                  _buildCallerAvatar(),

                  const SizedBox(height: 24),
                  
                  // Caller name
                  Text(
                    _callerName,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 8),

                  // Status / timer
                  Text(
                    _isRinging
                        ? 'Mobile'
                        : _callDuration > 0
                            ? _formatted
                            : 'Connecting…',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),

                  const Spacer(),

                  // Call action buttons area
                  if (!_isRinging) ...[
                    // In-call action row (mute, speaker, keypad — decorative)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSmallAction(Icons.mic_off_rounded, 'Mute'),
                          _buildSmallAction(Icons.dialpad_rounded, 'Keypad'),
                          _buildSmallAction(Icons.volume_up_rounded, 'Speaker'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Main call buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: _isRinging
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallBtn(
                                icon: Icons.call_end_rounded,
                                label: 'Decline',
                                color: const Color(0xFFFF3B30),
                                onTap: _endCall,
                              ),
                              _CallBtn(
                                icon: Icons.call_rounded,
                                label: 'Accept',
                                color: const Color(0xFF34C759),
                                onTap: _acceptCall,
                              ),
                            ],
                          )
                        : Center(
                            child: _CallBtn(
                              icon: Icons.call_end_rounded,
                              label: 'End Call',
                              color: const Color(0xFFFF3B30),
                              onTap: _endCall,
                            ),
                          ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallerAvatar() {
    final avatar = CircleAvatar(
      radius: 52,
      backgroundColor: const Color(0xFF2C2C4A),
      child: Text(
        _callerName.isNotEmpty ? _callerName[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
    );

    if (_isRinging) {
      return AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          final scale = 1.0 + sin(_waveController.value * 2 * pi) * 0.06;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34C759).withValues(
                      alpha: 0.2 + sin(_waveController.value * 2 * pi) * 0.15,
                    ),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildSmallAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ────────────── CALL BUTTON ──────────────

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// ────────────── CALL WAVE PAINTER ──────────────

class _CallWavePainter extends CustomPainter {
  final double progress;
  final bool isRinging;

  _CallWavePainter({required this.progress, required this.isRinging});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRinging) return;

    final center = Offset(size.width / 2, size.height * 0.25);
    
    for (int i = 0; i < 3; i++) {
      final radius = 80.0 + (progress + i * 0.33) % 1.0 * 120;
      final alpha = (1.0 - ((progress + i * 0.33) % 1.0)) * 0.15;
      
      final paint = Paint()
        ..color = const Color(0xFF34C759).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CallWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

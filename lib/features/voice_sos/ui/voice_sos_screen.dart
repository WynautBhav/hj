import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../models/voice_phrase.dart';
import '../repository/voice_sos_repository.dart';
import '../services/voice_sos_service.dart';
import 'voice_phrase_setup_screen.dart';
import 'voice_sos_countdown_overlay.dart';

class VoiceSOSScreen extends StatefulWidget {
  const VoiceSOSScreen({super.key});

  @override
  State<VoiceSOSScreen> createState() => _VoiceSOSScreenState();
}

class _VoiceSOSScreenState extends State<VoiceSOSScreen> {
  final VoiceSOSRepository _repository = VoiceSOSRepository();
  
  VoicePhrase? _storedPhrase;
  bool _isArmed = false;
  bool _isLoading = true;
  bool _isArming = false;
  StreamSubscription? _eventSubscription;
  OverlayEntry? _countdownOverlay;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _repository.initialize();
    await _loadState();
    _listenToServiceEvents();
  }

  Future<void> _loadState() async {
    final phrase = await _repository.getStoredPhrase();
    final isArmed = await _repository.isArmed();
    
    if (mounted) {
      setState(() {
        _storedPhrase = phrase;
        _isArmed = isArmed;
        _isLoading = false;
      });
    }
  }

  void _listenToServiceEvents() {
    _eventSubscription = VoiceSOSService.onEvent.listen((event) {
      if (event == null) return;

      if (event.containsKey('phrase_detected')) {
        _onPhraseDetected(event['phrase'] as String);
      } else if (event.containsKey('error')) {
        _showError(event['message'] as String);
      }
    });
  }

  void _onPhraseDetected(String phrase) {
    _showCountdownOverlay();
  }

  void _showCountdownOverlay() {
    _countdownOverlay = OverlayEntry(
      builder: (context) => VoiceSOSCountdownOverlay(
        onCancel: _cancelSOS,
        onConfirm: _triggerSOS,
      ),
    );
    Overlay.of(context).insert(_countdownOverlay!);
  }

  void _cancelSOS() {
    _countdownOverlay?.remove();
    _countdownOverlay = null;
    _showMessage('SOS cancelled');
  }

  void _triggerSOS() {
    _countdownOverlay?.remove();
    _countdownOverlay = null;
    _showMessage('SOS triggered - Emergency contacts will be notified');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _toggleArmed() async {
    if (_isArming) return;

    if (_storedPhrase == null) {
      _navigateToPhraseSetup();
      return;
    }

    setState(() => _isArming = true);

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('Microphone permission is required for Voice SOS');
        setState(() => _isArming = false);
        return;
      }

      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        _showError('Notification permission is required for Voice SOS');
      }

      if (_isArmed) {
        await _repository.disarmVoiceSOS();
        if (mounted) {
          setState(() => _isArmed = false);
          _showMessage('Voice SOS disarmed');
        }
      } else {
        final success = await _repository.armVoiceSOS();
        if (mounted) {
          setState(() => _isArmed = success);
          if (success) {
            _showMessage('Voice SOS armed - Say your phrase to trigger');
          } else {
            _showError('Failed to start Voice SOS');
          }
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isArming = false);
      }
    }
  }

  void _navigateToPhraseSetup() async {
    final result = await Navigator.push<VoicePhrase>(
      context,
      MaterialPageRoute(builder: (_) => const VoicePhraseSetupScreen()),
    );
    
    if (result != null) {
      await _repository.savePhrase(result);
      setState(() => _storedPhrase = result);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _countdownOverlay?.remove();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Voice-Armed SOS'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildStatusCard(),
          const SizedBox(height: 24),
          _buildPhraseCard(),
          const SizedBox(height: 24),
          _buildArmButton(),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent,
            AppColors.accentDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice-Armed SOS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trigger SOS by speaking your custom phrase',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isArmed 
                  ? Colors.green.withValues(alpha: 0.1) 
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isArmed ? Icons.mic : Icons.mic_off,
              color: _isArmed ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArmed ? 'Listening...' : 'Not Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isArmed ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isArmed 
                      ? 'Say your trigger phrase to activate SOS'
                      : 'Tap the button below to arm Voice SOS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_isArmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ARMED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: 100.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }

  Widget _buildPhraseCard() {
    return GestureDetector(
      onTap: _navigateToPhraseSetup,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.record_voice_over,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trigger Phrase',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _storedPhrase?.phrase ?? 'No phrase set',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _storedPhrase != null 
                          ? AppColors.accent 
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 200.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }

  Widget _buildArmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isArming ? null : _toggleArmed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isArmed ? Colors.red : AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isArming
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isArmed ? Icons.stop : Icons.mic),
                  const SizedBox(width: 8),
                  Text(
                    _isArmed 
                        ? 'DISARM VOICE SOS' 
                        : _storedPhrase != null 
                            ? 'ARM VOICE SOS' 
                            : 'SET UP PHRASE FIRST',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    )
    .animate()
    .fadeIn(delay: 300.ms, duration: 400.ms)
    .slideY(begin: 0.1, end: 0);
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Voice SOS requires internet connection to work. It listens only when you explicitly arm it. Your privacy is protected.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: 400.ms, duration: 400.ms);
  }
}

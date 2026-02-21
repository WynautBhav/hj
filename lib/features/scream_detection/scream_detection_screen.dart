import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/scream_detection_service.dart';

class ScreamDetectionScreen extends StatefulWidget {
  const ScreamDetectionScreen({super.key});

  @override
  State<ScreamDetectionScreen> createState() => _ScreamDetectionScreenState();
}

class _ScreamDetectionScreenState extends State<ScreamDetectionScreen> {
  final ScreamDetectionService _service = ScreamDetectionService();
  bool _isEnabled = false;
  double _threshold = 80.0;
  bool _isActive = false;
  bool _isCountingDown = false;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.init();
    final isEnabled = await _service.isEnabled();
    final threshold = await _service.getThreshold();
    setState(() {
      _isEnabled = isEnabled;
      _threshold = threshold.clamp(30.0, 100.0);
      _isActive = _service.isActive;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    await _service.setEnabled(value);
    setState(() => _isEnabled = value);
  }

  Future<void> _setThreshold(double value) async {
    await _service.setThreshold(value);
    setState(() => _threshold = value);
  }

  void _testMicrophone() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing microphone... Speak loudly to test.'),
        duration: Duration(seconds: 2),
      ),
    );
    
    _service.onCountdownStart = () {
      if (mounted) {
        setState(() {
          _isCountingDown = true;
          _countdown = 3;
        });
        _startCountdown();
      }
    };
    
    _service.onScreamDetected = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scream detected! SOS would be triggered.'),
            backgroundColor: AppColors.warning,
          ),
        );
        setState(() => _isCountingDown = false);
      }
    };
    
    await _service.startListening();
    setState(() => _isActive = true);
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _countdown--);
        if (_countdown <= 0) {
          timer.cancel();
        }
      }
    });
  }

  void _cancelTest() {
    _service.cancelDetection();
    setState(() {
      _isActive = false;
      _isCountingDown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Scream Detection'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_isCountingDown)
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scream Detected!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SOS will be sent in $_countdown seconds',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cancelTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  _isActive ? Icons.mic : Icons.mic_none,
                  size: 64,
                  color: _isActive ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _isActive ? 'Listening...' : 'Not Active',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enable Scream Detection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: _toggleEnabled,
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Threshold: ${_threshold.toInt()} dB',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _threshold,
                  min: 30,
                  max: 100,
                  divisions: 14,
                  label: '${_threshold.toInt()} dB',
                  onChanged: _isEnabled ? _setThreshold : null,
                ),
                const Text(
                  '30 dB = very sensitive · 100 dB = only loud screams',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                    'A 3-second countdown will appear after detecting a scream. Tap cancel if it\'s a false positive.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isActive)
            ElevatedButton(
              onPressed: _cancelTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Stop Listening'),
            )
          else
            ElevatedButton(
              onPressed: _testMicrophone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Test Microphone'),
            ),
        ],
      ),
    );
  }
}

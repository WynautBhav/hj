import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/location_service.dart';

/// FIX #3: Fake Battery/Shutdown screen.
/// Now wires audio recording and location tracking when activated.
class FakeBatteryScreen extends StatefulWidget {
  const FakeBatteryScreen({super.key});

  @override
  State<FakeBatteryScreen> createState() => _FakeBatteryScreenState();
}

class _FakeBatteryScreenState extends State<FakeBatteryScreen> {
  bool _isActive = false;
  final AudioRecordingService _audioService = AudioRecordingService();
  final LocationService _locationService = LocationService();
  bool _isRecording = false;
  bool _isTracking = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Fake Battery Screen'),
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
              child: Column(
                children: [
                  Icon(
                    _isActive ? Icons.power_off : Icons.battery_alert,
                    size: 64,
                    color: _isActive ? AppColors.textSecondary : AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isActive ? 'Phone Appears Off' : 'Fake Shutdown',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Show a fake shutdown screen while recording audio and tracking location underneath',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // FIX #3: Status indicators showing what services are active
            if (_isActive) ...[
              _buildStatusRow(
                Icons.mic_rounded,
                'Audio Recording',
                _isRecording,
              ),
              const SizedBox(height: 8),
              _buildStatusRow(
                Icons.location_on_rounded,
                'Location Tracking',
                _isTracking,
              ),
              const SizedBox(height: 16),
            ],
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
                      'Triple press power button to cancel the fake screen',
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
            if (_isActive)
              ElevatedButton(
                onPressed: _deactivateFakeBattery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Exit Fake Screen'),
              )
            else
              ElevatedButton(
                onPressed: _activateFakeBattery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Activate Fake Screen'),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.success : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            active ? 'Active' : 'Waiting',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// FIX #3: Wire audio recording + location tracking on activation
  void _activateFakeBattery() async {
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _isActive = true);

    // Start audio recording (permission-gated inside the service)
    try {
      final recording = await _audioService.startRecording();
      if (mounted) setState(() => _isRecording = recording);
    } catch (e) {
      debugPrint('Audio recording failed: $e');
    }

    // Start location tracking (permission-gated inside the service)
    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        // Cache current position for SOS if needed
        await _locationService.getCurrentPosition();
        if (mounted) setState(() => _isTracking = true);
      }
    } catch (e) {
      debugPrint('Location tracking failed: $e');
    }
  }

  /// FIX #3: Stop services cleanly on deactivation
  void _deactivateFakeBattery() async {
    // Stop services first
    try {
      if (_isRecording) await _audioService.stopRecording();
    } catch (e) {
      debugPrint('Audio stop failed: $e');
    }

    setState(() {
      _isActive = false;
      _isRecording = false;
      _isTracking = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    if (_isActive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (_isRecording) {
      _audioService.stopRecording();
    }
    _audioService.dispose();
    super.dispose();
  }
}

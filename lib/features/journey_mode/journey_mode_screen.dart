import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/journey_service.dart';
import '../../core/services/location_service.dart';

class JourneyModeScreen extends StatefulWidget {
  const JourneyModeScreen({super.key});

  @override
  State<JourneyModeScreen> createState() => _JourneyModeScreenState();
}

class _JourneyModeScreenState extends State<JourneyModeScreen> {
  final JourneyModeService _journeyService = JourneyModeService();
  final LocationService _locationService = LocationService();
  bool _isJourneyActive = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _checkJourneyStatus();
  }

  Future<void> _checkJourneyStatus() async {
    final isActive = await _journeyService.isEnabled();
    if (isActive) {
      // Resume listening if journey was already active
      _startListening();
    }
    if (mounted) setState(() => _isJourneyActive = isActive);
  }

  Future<void> _startJourney() async {
    await _journeyService.startJourney();
    _startListening();
    if (mounted) setState(() => _isJourneyActive = true);
  }

  /// Wire the live position stream to the UI
  void _startListening() {
    _positionSub?.cancel();
    _positionSub = _locationService.positionStream.listen(
      (position) {
        if (mounted) {
          setState(() => _currentPosition = position);
        }
      },
      onError: (e) {
        debugPrint('Journey position error: $e');
      },
    );

    // Elapsed time timer
    _elapsedTimer?.cancel();
    _elapsed = Duration.zero;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopJourney() async {
    await _journeyService.stopJourney();
    _positionSub?.cancel();
    _positionSub = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    if (mounted) {
      setState(() {
        _isJourneyActive = false;
        _currentPosition = null;
        _elapsed = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _elapsedTimer?.cancel();
    _journeyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Journey Mode'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    _isJourneyActive ? Icons.directions_run : Icons.directions_walk,
                    size: 64,
                    color: _isJourneyActive ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isJourneyActive ? 'Journey in Progress' : 'Start Journey',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isJourneyActive 
                        ? 'Monitoring your route for safety'
                        : 'Track your journey and get safe arrival notification',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Live tracking info (shown when active)
            if (_isJourneyActive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'Elapsed: ${_formatDuration(_elapsed)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Acquiring GPS signal…',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Safety tip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isJourneyActive
                          ? 'If you deviate from your route, emergency contacts will be alerted automatically.'
                          : 'Journey Mode tracks your route and alerts contacts if you deviate unexpectedly.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action button
            if (_isJourneyActive)
              ElevatedButton(
                onPressed: _stopJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('End Journey'),
              )
            else
              ElevatedButton(
                onPressed: _startJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Start Journey'),
              ),
          ],
        ),
      ),
    );
  }
}

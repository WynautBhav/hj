import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/dead_man_switch_service.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/location_service.dart';

class DeadManSwitchScreen extends StatefulWidget {
  const DeadManSwitchScreen({super.key});

  @override
  State<DeadManSwitchScreen> createState() => _DeadManSwitchScreenState();
}

class _DeadManSwitchScreenState extends State<DeadManSwitchScreen> {
  late final DeadManSwitchService _service;
  bool _isEnabled = false;
  int _intervalMinutes = 10;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _service = DeadManSwitchService(
      onTimeout: () async {
        final contactService = ContactService();
        final contacts = await contactService.getContacts();
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
          await smsService.sendSosSms(contacts, message);
        }
      },
      onSafeCheckIn: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-in confirmed.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.init();
    final isEnabled = await _service.isEnabled();
    final interval = await _service.getIntervalMinutes();
    setState(() {
      _isEnabled = isEnabled;
      _intervalMinutes = interval;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    await _service.setEnabled(value);
    setState(() => _isEnabled = value);
  }

  Future<void> _setInterval(int minutes) async {
    await _service.setInterval(minutes);
    setState(() => _intervalMinutes = minutes);
  }

  void _activateNow() {
    _service.startMonitoring();
    setState(() => _isActive = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dead Man Switch activated. You will be checked in periodically.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _deactivateNow() {
    _service.stopMonitoring();
    setState(() => _isActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Dead Man Switch'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
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
                  _isActive ? Icons.timer : Icons.timer_outlined,
                  size: 64,
                  color: _isActive ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: _isActive ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isActive 
                      ? 'You will receive periodic check-ins'
                      : 'Enable to receive periodic safety check-ins',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
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
                  'Enable Dead Man Switch',
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
                  'Check-in Interval: $_intervalMinutes minutes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _intervalMinutes.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '$_intervalMinutes min',
                  onChanged: _isEnabled ? (value) => _setInterval(value.toInt()) : null,
                ),
                const Text(
                  'How often you need to confirm you are safe',
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
                    'If you don\'t respond within 60 seconds, SOS will be automatically triggered to your emergency contacts.',
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
              onPressed: _deactivateNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Deactivate Now'),
            )
          else if (_isEnabled)
            ElevatedButton(
              onPressed: _activateNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text('Activate Now'),
            ),
        ],
      ),
    );
  }
}

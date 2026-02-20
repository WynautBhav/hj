import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// Real screen imports
import '../journey_mode/journey_mode_screen.dart';
import '../guardian_mode/guardian_mode_screen.dart';
import '../safety_pulse/safety_pulse_screen.dart';
import '../audio_recording/audio_recording_screen.dart';
import '../wrong_pin_capture/wrong_pin_capture_screen.dart';
import '../evidence_locker/evidence_locker_screen.dart';
import '../voice_read/voice_read_screen.dart';
import '../pdf_generator/pdf_generator_screen.dart';
import '../legal_info/legal_info_screen.dart';
import '../personalized_sos_messages/personalized_sos_messages_screen.dart';
import '../app_lock_data_wipe/app_lock_data_wipe_screen.dart';
import '../smart_contact_priority/smart_contact_priority_screen.dart';
import '../sensitivity_settings/sensitivity_settings_screen.dart';
import '../dead_man_switch/dead_man_switch_screen.dart';
import '../scream_detection/scream_detection_screen.dart';
import '../fake_battery/fake_battery_screen.dart';
import '../flashlight_sos/flashlight_sos_screen.dart';
import '../battery_aware/battery_aware_screen.dart';
import '../safe_arrival/safe_arrival_screen.dart';
import '../sos/sos_screen.dart';
import '../voice_sos/ui/voice_sos_screen.dart';

class _FeatureEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;

  const _FeatureEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });
}

class AllFeaturesScreen extends StatelessWidget {
  const AllFeaturesScreen({super.key});

  // ── 5 smart groups ────────────────────────────────────────────────────────

  static const _sos = [
    _FeatureEntry(
      title: 'SOS Alert',
      subtitle: 'Multi-trigger emergency alert',
      icon: Icons.shield_rounded,
      screen: SosScreen(),
    ),
    _FeatureEntry(
      title: 'Shake-to-SOS',
      subtitle: 'Shake phone to trigger alert',
      icon: Icons.vibration_rounded,
      screen: SosScreen(),   // configured via ShakeService in background
    ),
    _FeatureEntry(
      title: 'Triple Power Press',
      subtitle: 'Press power button 3× for SOS',
      icon: Icons.power_settings_new_rounded,
      screen: SosScreen(),
    ),
    _FeatureEntry(
      title: 'Dead Man\'s Switch',
      subtitle: 'Auto-SOS if you stop responding',
      icon: Icons.access_alarm_rounded,
      screen: DeadManSwitchScreen(),
    ),
    _FeatureEntry(
      title: 'Scream Detector',
      subtitle: 'Auto-trigger on loud distress sound',
      icon: Icons.mic_rounded,
      screen: ScreamDetectionScreen(),
    ),
    _FeatureEntry(
      title: 'Battery-Aware SOS',
      subtitle: 'Auto-alert when battery is critically low',
      icon: Icons.battery_alert_rounded,
      screen: BatteryAwareScreen(),
    ),
    _FeatureEntry(
      title: 'Flashlight Morse SOS',
      subtitle: 'Flash SOS in Morse code using torch',
      icon: Icons.flashlight_on_rounded,
      screen: FlashlightSosScreen(),
    ),
    _FeatureEntry(
      title: 'Voice-Armed SOS',
      subtitle: 'Trigger SOS by speaking your phrase',
      icon: Icons.mic_rounded,
      screen: VoiceSOSScreen(),
    ),
  ];

  static const _disguise = [
    _FeatureEntry(
      title: 'Stealth Mode',
      subtitle: 'Fake shutdown + background recording',
      icon: Icons.power_off_rounded,
      screen: FakeBatteryScreen(),
    ),
    _FeatureEntry(
      title: 'Covert Audio Recording',
      subtitle: 'Silent background audio capture',
      icon: Icons.radio_button_checked_rounded,
      screen: AudioRecordingScreen(),
    ),
    _FeatureEntry(
      title: 'Safe Arrival',
      subtitle: 'Confirm arrival or auto-notify contacts',
      icon: Icons.where_to_vote_rounded,
      screen: SafeArrivalScreen(),
    ),
  ];

  static const _monitoring = [
    _FeatureEntry(
      title: 'Journey Mode',
      subtitle: 'Track route, alert on deviation',
      icon: Icons.directions_walk_rounded,
      screen: JourneyModeScreen(),
    ),
    _FeatureEntry(
      title: 'Guardian Mode',
      subtitle: 'Bluetooth proximity monitoring',
      icon: Icons.bluetooth_rounded,
      screen: GuardianModeScreen(),
    ),
    _FeatureEntry(
      title: 'Safety Pulse',
      subtitle: 'Periodic check-in, auto-alert if silent',
      icon: Icons.favorite_rounded,
      screen: SafetyPulseScreen(),
    ),
    _FeatureEntry(
      title: 'Intruder Alert',
      subtitle: 'Captures photo on wrong PIN entry',
      icon: Icons.camera_front_rounded,
      screen: WrongPinCaptureScreen(),
    ),
  ];

  static const _evidence = [
    _FeatureEntry(
      title: 'Evidence Locker',
      subtitle: 'Secure storage for photos & recordings',
      icon: Icons.lock_rounded,
      screen: EvidenceLockerScreen(),
    ),
    _FeatureEntry(
      title: 'Threat Detector',
      subtitle: 'Analyze suspicious messages for danger',
      icon: Icons.policy_rounded,
      screen: VoiceReadScreen(),   // repurposed
    ),
    _FeatureEntry(
      title: 'PDF Report Generator',
      subtitle: 'Generate incident reports for police',
      icon: Icons.description_rounded,
      screen: PdfGeneratorScreen(),
    ),
    _FeatureEntry(
      title: 'Legal Information',
      subtitle: 'Helplines, FIR guide, your rights',
      icon: Icons.balance_rounded,
      screen: LegalInfoScreen(),
    ),
  ];

  static const _settings = [
    _FeatureEntry(
      title: 'SOS Message Templates',
      subtitle: 'Personalise messages per contact',
      icon: Icons.chat_bubble_outline_rounded,
      screen: PersonalizedSosMessagesScreen(),
    ),
    _FeatureEntry(
      title: 'App Lock & Data Wipe',
      subtitle: 'PIN protection and panic wipe',
      icon: Icons.security_rounded,
      screen: AppLockDataWipeScreen(),
    ),
    _FeatureEntry(
      title: 'Contact Priority',
      subtitle: 'Set who gets alerted first',
      icon: Icons.sort_rounded,
      screen: SmartContactPriorityScreen(),
    ),
    _FeatureEntry(
      title: 'Sensitivity Settings',
      subtitle: 'Shake, scream and trigger sensitivity',
      icon: Icons.tune_rounded,
      screen: SensitivitySettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All Features',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('25 features. Zero internet required.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            _header('SOS Triggers'),
            _list(context, _sos),

            _header('Disguise & Escape'),
            _list(context, _disguise),

            _header('Monitoring & Tracking'),
            _list(context, _monitoring),

            _header('Evidence & Legal'),
            _list(context, _evidence),

            _header('Settings & Customisation'),
            _list(context, _settings),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _header(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _list(BuildContext context, List<_FeatureEntry> features) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: features.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return Column(
                children: [
                  _Tile(feature: f),
                  if (i < features.length - 1)
                    const Divider(height: 1, indent: 60),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final _FeatureEntry feature;
  const _Tile({required this.feature});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => feature.screen),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(feature.icon, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const SizedBox(height: 2),
                  Text(feature.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

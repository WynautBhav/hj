import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';

class AppLockDataWipeScreen extends StatefulWidget {
  const AppLockDataWipeScreen({super.key});

  @override
  State<AppLockDataWipeScreen> createState() => _AppLockDataWipeScreenState();
}

class _AppLockDataWipeScreenState extends State<AppLockDataWipeScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isPanicWipeEnabled = false;
  int _wrongAttemptsLimit = 3;
  bool _isLoading = true;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSettings();
  }

  Future<void> _checkBiometrics() async {
    try {
      _canCheckBiometrics = await _localAuth.canCheckBiometrics;
    } catch (e) {
      _canCheckBiometrics = false;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _isPanicWipeEnabled = prefs.getBool('panic_wipe_enabled') ?? false;
      _wrongAttemptsLimit = prefs.getInt('wrong_attempts_limit') ?? 3;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    setState(() => _isAppLockEnabled = value);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && _canCheckBiometrics) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() => _isBiometricEnabled = value);
  }

  Future<void> _togglePanicWipe(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Panic Wipe?'),
          content: const Text(
            'When enabled, shaking the phone vigorously 5 times will instantly wipe all app data. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('panic_wipe_enabled', value);
    setState(() => _isPanicWipeEnabled = value);
  }

  Future<void> _setWrongAttemptsLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wrong_attempts_limit', limit);
    setState(() => _wrongAttemptsLimit = limit);
  }

  Future<void> _wipeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.sosRed),
            SizedBox(width: 8),
            Text('Wipe All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All emergency contacts\n'
          '• All saved evidence\n'
          '• All app settings\n'
          '• All custom messages\n\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            child: const Text('WIPE EVERYTHING'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _performWipe();
    }
  }

  Future<void> _performWipe() async {
    try {
      // 1. Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Clear secure storage
      await _secureStorage.deleteAll();

      // 3. Delete SQLite database
      try {
        final dbPath = p.join(await getDatabasesPath(), 'sos_history.db');
        final dbFile = File(dbPath);
        if (await dbFile.exists()) await dbFile.delete();
      } catch (e) {
        // DB may not exist yet
      }

      // 4. Delete evidence locker files
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final lockerDir = Directory('${appDir.path}/evidence_locker');
        if (await lockerDir.exists()) await lockerDir.delete(recursive: true);
      } catch (e) {
        // Directory may not exist
      }

      // 5. Delete wrong-pin capture photos
      try {
        final tempDir = await getTemporaryDirectory();
        for (final f in tempDir.listSync()) {
          if (f.path.contains('intruder') || f.path.contains('capture')) {
            await f.delete();
          }
        }
      } catch (e) {
        // Temp files may not exist
      }
    } catch (e) {
      // Never crash on wipe failure
    }

    // Signal app root to reset to calculator state
    try {
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setBool('force_relock', true);
    } catch (e) {
      // prefs may already be cleared
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data wiped. App reset.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('App Lock & Security'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSecuritySection(),
                  const SizedBox(height: 24),
                  _buildWipeSection(),
                  const SizedBox(height: 24),
                  _buildPanicSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Lock',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          icon: Icons.lock_outline,
          title: 'App Lock',
          subtitle: 'Require PIN to open app (in addition to calculator)',
          value: _isAppLockEnabled,
          onChanged: _toggleAppLock,
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          icon: Icons.fingerprint,
          title: 'Biometric Lock',
          subtitle: _canCheckBiometrics 
              ? 'Use fingerprint or face to unlock' 
              : 'Biometrics not available on this device',
          value: _isBiometricEnabled,
          onChanged: _canCheckBiometrics ? _toggleBiometric : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wrong PIN Attempts Before Wipe',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [1, 2, 3, 5, 10].map((limit) {
                  final isSelected = _wrongAttemptsLimit == limit;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$limit'),
                        selected: isSelected,
                        onSelected: (_) => _setWrongAttemptsLimit(limit),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWipeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Wipe',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.delete_forever, color: AppColors.sosRed),
                  SizedBox(width: 8),
                  Text(
                    'Emergency Data Wipe',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.sosRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Permanently delete all app data including contacts, messages, and evidence.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _wipeAllData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sosRed,
                    side: const BorderSide(color: AppColors.sosRed),
                  ),
                  child: const Text('WIPE ALL DATA NOW'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Panic Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          icon: Icons.warning_amber,
          title: 'Panic Wipe',
          subtitle: 'Shake phone 5 times rapidly to wipe all data',
          value: _isPanicWipeEnabled,
          onChanged: _togglePanicWipe,
        ),
        const SizedBox(height: 12),
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
                  'Tip: Enable Panic Wipe for maximum security. When activated, all data is instantly deleted.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const PermissionRequestScreen({super.key, required this.onComplete});

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isRequesting = false;
  final Map<String, bool> _permissionStatus = {};
  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Location',
      description: 'Share your location during emergencies',
      permission: Permission.locationWhenInUse,
      color: Colors.green,
    ),
    _PermissionItem(
      icon: Icons.sms_rounded,
      title: 'SMS',
      description: 'Send emergency alerts to contacts',
      permission: Permission.sms,
      color: Colors.blue,
      requiresSpecialHandling: true,
      specialMessage: 'On Android 4.4+, you must set this app as your default SMS app to send messages. Go to Settings > Apps > Default apps > SMS.',
    ),
    _PermissionItem(
      icon: Icons.camera_alt_rounded,
      title: 'Camera',
      description: 'Capture evidence when needed',
      permission: Permission.camera,
      color: Colors.orange,
    ),
    _PermissionItem(
      icon: Icons.mic_rounded,
      title: 'Microphone',
      description: 'Record audio for evidence',
      permission: Permission.microphone,
      color: Colors.red,
    ),
    _PermissionItem(
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      description: 'Receive safety alerts',
      permission: Permission.notification,
      color: Colors.purple,
    ),
    _PermissionItem(
      icon: Icons.layers_rounded,
      title: 'Display Over Apps',
      description: 'Required for Fake Call & Background SOS',
      permission: Permission.systemAlertWindow,
      color: Colors.indigo,
      requiresSpecialHandling: true,
      specialMessage: 'Display over other apps requires special permission. After tapping Grant, you\'ll be redirected to settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF9172DB), // AppColors.accent
              Colors.white,
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      ..._permissions.map((p) => _buildPermissionTile(p)),
                    ],
                  ),
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.security_rounded,
            size: 40,
            color: Color(0xFF9172DB),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Permissions Required',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enable permissions for full protection',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(_PermissionItem item) {
    final isGranted = _permissionStatus[item.title] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted 
                    ? Colors.green.withValues(alpha: 0.1)
                    : item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGranted ? Icons.check_circle : item.icon,
                color: isGranted ? Colors.green : item.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isGranted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isGranted ? Colors.green : Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9172DB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isRequesting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Grant All Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Color(0xFF9172DB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    
    for (final item in _permissions) {
      try {
        PermissionStatus status;
        
        if (item.requiresSpecialHandling) {
          if (item.permission == Permission.systemAlertWindow) {
            status = await Permission.systemAlertWindow.request();
            if (status.isDenied && mounted) {
              _showSystemAlertWindowInstructions();
            }
          } else {
            status = await item.permission.request();
            if (status.isDenied && item.specialMessage != null && mounted) {
              _showSpecialPermissionDialog(item.title, item.specialMessage!);
            }
          }
        } else {
          status = await item.permission.request();
        }
        
        setState(() {
          _permissionStatus[item.title] = status.isGranted;
        });
      } catch (e) {
        debugPrint('Permission request error for ${item.title}: $e');
        setState(() {
          _permissionStatus[item.title] = false;
        });
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_asked', true);
    
    if (mounted) {
      widget.onComplete();
    }
  }

  void _showSystemAlertWindowInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Over Apps Permission'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To enable "Display Over Other Apps":'),
            SizedBox(height: 12),
            Text('1. Tap "Open Settings" below'),
            Text('2. Find this app in the list'),
            Text('3. Enable "Display over other apps"'),
            Text('4. Return to the app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openSystemAlertWindowSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSystemAlertWindowSettings() async {
    if (Platform.isAndroid) {
      try {
        final Uri uri = Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS&package=com.calculator.app');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await openAppSettings();
        }
      } catch (e) {
        debugPrint('Failed to open overlay settings: $e');
        await openAppSettings();
      }
    }
  }

  void _showSpecialPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title Permission'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  final Permission permission;
  final Color color;
  final bool requiresSpecialHandling;
  final String? specialMessage;

  _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
    required this.color,
    this.requiresSpecialHandling = false,
    this.specialMessage,
  });
}

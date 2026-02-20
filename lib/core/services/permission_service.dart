import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _permissionsAskedKey = 'permissions_asked';

  static Future<bool> shouldAskPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_permissionsAskedKey) ?? false);
  }

  static Future<void> markPermissionsAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsAskedKey, true);
  }

  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = {
      Permission.location: Permission.location,
      Permission.sms: Permission.sms,
      Permission.camera: Permission.camera,
      Permission.microphone: Permission.microphone,
      Permission.storage: Permission.storage,
      Permission.phone: Permission.phone,
      Permission.bluetooth: Permission.bluetooth,
      Permission.notification: Permission.notification,
    };

    final results = <Permission, PermissionStatus>{};

    for (final entry in permissions.entries) {
      final status = await entry.value.request();
      results[entry.key] = status;
    }

    return results;
  }

  static Future<PermissionStatus> requestLocation() async {
    final status = await Permission.location.request();
    return status;
  }

  static Future<PermissionStatus> requestCamera() async {
    final status = await Permission.camera.request();
    return status;
  }

  static Future<PermissionStatus> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status;
  }

  static Future<PermissionStatus> requestSms() async {
    final status = await Permission.sms.request();
    return status;
  }

  static Future<PermissionStatus> requestNotification() async {
    final status = await Permission.notification.request();
    return status;
  }

  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  static Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

class PermissionRequestDialog extends StatefulWidget {
  final Function(Map<Permission, PermissionStatus>) onComplete;
  
  const PermissionRequestDialog({super.key, required this.onComplete});

  @override
  State<PermissionRequestDialog> createState() => _PermissionRequestDialogState();
}

class _PermissionRequestDialogState extends State<PermissionRequestDialog> {
  bool _isRequesting = false;
  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Location',
      description: 'Share your location during emergencies',
      permission: Permission.location,
      color: Colors.green,
    ),
    _PermissionItem(
      icon: Icons.sms_rounded,
      title: 'SMS',
      description: 'Send emergency alerts to contacts',
      permission: Permission.sms,
      color: Colors.blue,
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
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.security_rounded,
              size: 48,
              color: Color(0xFF7C5FD6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Permissions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable permissions for full protection',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ..._permissions.map((p) => _buildPermissionTile(p)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isRequesting ? null : _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5FD6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        'Grant Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(_PermissionItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    
    final results = await PermissionService.requestAllPermissions();
    
    await PermissionService.markPermissionsAsked();
    
    if (mounted) {
      widget.onComplete(results);
      Navigator.of(context).pop();
    }
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  final Permission permission;
  final Color color;

  _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
    required this.color,
  });
}

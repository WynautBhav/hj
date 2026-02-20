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
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.sms,
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.phone,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
      Permission.accessNotificationPolicy,
    };

    final results = <Permission, PermissionStatus>{};

    for (final permission in permissions) {
      try {
        final status = await permission.request();
        results[permission] = status;
      } catch (e) {
        results[permission] = PermissionStatus.permanentlyDenied;
      }
    }

    return results;
  }

  static Future<bool> checkAndRequestLocation() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestCamera() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestMicrophone() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestSms() async {
    var status = await Permission.sms.status;
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestNotification() async {
    var status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

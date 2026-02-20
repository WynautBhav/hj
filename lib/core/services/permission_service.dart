import 'package:permission_handler/permission_handler.dart' as ph;
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

  static Future<Map<ph.Permission, ph.PermissionStatus>> requestAllPermissions() async {
    final permissions = {
      ph.Permission.locationWhenInUse,
      ph.Permission.locationAlways,
      ph.Permission.sms,
      ph.Permission.camera,
      ph.Permission.microphone,
      ph.Permission.storage,
      ph.Permission.phone,
      ph.Permission.bluetooth,
      ph.Permission.bluetoothConnect,
      ph.Permission.bluetoothScan,
      ph.Permission.notification,
      ph.Permission.ignoreBatteryOptimizations,
      ph.Permission.accessNotificationPolicy,
    };

    final results = <ph.Permission, ph.PermissionStatus>{};

    for (final permission in permissions) {
      try {
        final status = await permission.request();
        results[permission] = status;
      } catch (e) {
        results[permission] = ph.PermissionStatus.permanentlyDenied;
      }
    }

    return results;
  }

  static Future<bool> checkAndRequestLocation() async {
    var status = await ph.Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await ph.Permission.locationWhenInUse.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestCamera() async {
    var status = await ph.Permission.camera.status;
    if (status.isDenied) {
      status = await ph.Permission.camera.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestMicrophone() async {
    var status = await ph.Permission.microphone.status;
    if (status.isDenied) {
      status = await ph.Permission.microphone.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestSms() async {
    var status = await ph.Permission.sms.status;
    if (status.isDenied) {
      status = await ph.Permission.sms.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestNotification() async {
    var status = await ph.Permission.notification.status;
    if (status.isDenied) {
      status = await ph.Permission.notification.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkAndRequestSystemAlertWindow() async {
    var status = await ph.Permission.systemAlertWindow.status;
    if (status.isDenied) {
      status = await ph.Permission.systemAlertWindow.request();
    }
    return status.isGranted;
  }

  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}

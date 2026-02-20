import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuardianService {
  static const String _enabledKey = 'guardian_enabled';
  static const String _connectedDeviceKey = 'guardian_device';
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  Function(List<BluetoothDevice>)? onDevicesFound;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onError;
  
  bool _isScanning = false;
  bool _isConnected = false;

  GuardianService({this.onDevicesFound, this.onConnected, this.onDisconnected, this.onError});

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// FIX #5: Request BT runtime permissions before scanning (Android 12+ requires this)
  Future<bool> _requestBluetoothPermissions() async {
    try {
      final btScan = await Permission.bluetoothScan.request();
      final btConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.location.request();
      
      if (!btScan.isGranted || !btConnect.isGranted || !location.isGranted) {
        onError?.call('Bluetooth and location permissions are required');
        return false;
      }
      return true;
    } catch (e) {
      onError?.call('Failed to request permissions');
      return false;
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    
    // FIX #5: Request runtime permissions before scanning
    final hasPermissions = await _requestBluetoothPermissions();
    if (!hasPermissions) return;
    
    final isOn = await isBluetoothOn();
    if (!isOn) {
      onError?.call('Bluetooth is turned off');
      return;
    }

    _isScanning = true;
    _discoveredDevices.clear();

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices = results.map((r) => r.device).toList();
        onDevicesFound?.call(_discoveredDevices);
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      onError?.call('Scan failed: ${e.toString()}');
    }
    _isScanning = false;
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _isConnected = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_connectedDeviceKey, device.remoteId.str);
      
      onConnected?.call();
      return true;
    } catch (e) {
      onError?.call('Could not connect to device');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice == null) return;
    
    try {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _isConnected = false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_connectedDeviceKey);
      
      onDisconnected?.call();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> checkSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_connectedDeviceKey);
    
    if (savedDeviceId != null) {
      final devices = FlutterBluePlus.connectedDevices;
      final device = devices.where((d) => d.remoteId.str == savedDeviceId).firstOrNull;
      
      if (device != null) {
        _connectedDevice = device;
        _isConnected = true;
        onConnected?.call();
      }
    }
  }

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  void dispose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
  }
}

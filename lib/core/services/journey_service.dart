import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class JourneyModeService {
  static const String _enabledKey = 'journey_mode_enabled';
  static const String _startLatKey = 'journey_start_lat';
  static const String _startLngKey = 'journey_start_lng';
  static const String _startBearingKey = 'journey_start_bearing';
  static const String _destinationLatKey = 'journey_dest_lat';
  static const String _destinationLngKey = 'journey_dest_lng';
  
  StreamSubscription? _locationSubscription;
  final LocationService _locationService = LocationService();
  final Function()? onDeviationDetected;
  final Function()? onSafeArrival;
  
  bool _isMonitoring = false;
  double? _startBearing;
  static const double deviationThreshold = 45.0;
  static const int deviationDurationSeconds = 120;

  JourneyModeService({this.onDeviationDetected, this.onSafeArrival});

  Future<void> init() async {}

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> startJourney({double? destLat, double? destLng}) async {
    // FIX #4: Request location permission before tracking
    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) return;
    
    final position = await _locationService.getCurrentPosition();
    if (position == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setDouble(_startLatKey, position.latitude);
    await prefs.setDouble(_startLngKey, position.longitude);
    await prefs.setDouble(_startBearingKey, 0.0);
    
    if (destLat != null && destLng != null) {
      await prefs.setDouble(_destinationLatKey, destLat);
      await prefs.setDouble(_destinationLngKey, destLng);
    }
    
    _startBearing = 0.0;
    _startMonitoring();
  }

  Future<void> stopJourney() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_startLatKey);
    await prefs.remove(_startLngKey);
    await prefs.remove(_startBearingKey);
    await prefs.remove(_destinationLatKey);
    await prefs.remove(_destinationLngKey);
    
    _stopMonitoring();
  }

  void _startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      _checkPosition(position);
    });
  }

  void _stopMonitoring() {
    _isMonitoring = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _checkPosition(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final startLat = prefs.getDouble(_startLatKey);
    final startLng = prefs.getDouble(_startLngKey);
    
    if (startLat == null || startLng == null) return;
    
    final currentBearing = _calculateBearing(
      startLat, startLng,
      position.latitude, position.longitude,
    );
    
    final destLat = prefs.getDouble(_destinationLatKey);
    final destLng = prefs.getDouble(_destinationLngKey);
    
    if (destLat != null && destLng != null) {
      final distance = _calculateDistance(
        position.latitude, position.longitude,
        destLat, destLng,
      );
      
      if (distance < 50) {
        onSafeArrival?.call();
        await stopJourney();
        return;
      }
    }
    
    if (_startBearing != null) {
      final deviation = (currentBearing - _startBearing!).abs();
      if (deviation > deviationThreshold) {
        onDeviationDetected?.call();
      }
    }
  }

  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    
    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);
    
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  void dispose() {
    _stopMonitoring();
  }
}

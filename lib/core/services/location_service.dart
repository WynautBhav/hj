import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _latKey = 'cached_latitude';
  static const String _lngKey = 'cached_longitude';
  static const String _timeKey = 'cached_time';

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      await _cachePosition(position.latitude, position.longitude);
      return position;
    } catch (e) {
      return getCachedPosition();
    }
  }

  /// Continuous position stream for live tracking (Journey Mode, Fake Battery).
  /// Emits position updates every 10 meters of movement.
  Stream<Position> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Start continuous GPS tracking — caches each position update.
  /// Used by Fake Battery screen to silently track location.
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    final hasPermission = await checkPermission();
    if (!hasPermission) return false;

    try {
      _isTracking = true;
      _positionSubscription = positionStream.listen(
        (position) {
          _cachePosition(position.latitude, position.longitude);
        },
        onError: (e) {
          _isTracking = false;
        },
      );
      return true;
    } catch (e) {
      _isTracking = false;
      return false;
    }
  }

  /// Stop continuous GPS tracking. Must be called in dispose().
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  bool get isTracking => _isTracking;

  Future<void> _cachePosition(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Position?> getCachedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    final time = prefs.getInt(_timeKey);

    if (lat != null && lng != null && time != null) {
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.fromMillisecondsSinceEpoch(time),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    return null;
  }

  String getGoogleMapsLink(double lat, double lng) {
    return 'https://maps.google.com/?q=$lat,$lng';
  }

  void dispose() {
    stopTracking();
  }
}

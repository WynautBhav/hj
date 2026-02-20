import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_signal.dart';

class CommunitySignalService {
  static const String _signalsKey = 'community_signals';
  static const double _defaultRadiusKm = 3.0;

  Future<void> addSignal(CommunitySignal signal) async {
    final signals = await getSignals();
    signals.add(signal);
    await _saveSignals(signals);
  }

  Future<List<CommunitySignal>> getSignals() async {
    final prefs = await SharedPreferences.getInstance();
    final signalsJson = prefs.getString(_signalsKey);
    
    if (signalsJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(signalsJson);
      return decoded
          .map((s) => CommunitySignal.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CommunitySignal>> getSignalsInRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    final signals = await getSignals();
    return signals.where((signal) {
      final distance = _calculateDistance(
        centerLat,
        centerLng,
        signal.lat,
        signal.lng,
      );
      return distance <= radiusKm;
    }).toList();
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorCos(x);
  double _sqrt(double x) => _newtonSqrt(x);
  double _atan2(double y, double x) => _approximateAtan2(y, x);

  double _taylorSin(double x) {
    x = x % (2 * 3.141592653589793);
    if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    if (x < -3.141592653589793) x += 2 * 3.141592653589793;
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _taylorCos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _approximateAtan2(double y, double x) {
    if (x == 0) {
      if (y > 0) return 3.141592653589793 / 2;
      if (y < 0) return -3.141592653589793 / 2;
      return 0;
    }
    double atan = _approximateAtan(y / x);
    if (x < 0) {
      if (y >= 0) return atan + 3.141592653589793;
      return atan - 3.141592653589793;
    }
    return atan;
  }

  double _approximateAtan(double x) {
    if (x > 1) return 3.141592653589793 / 2 - _approximateAtan(1 / x);
    if (x < -1) return -3.141592653589793 / 2 - _approximateAtan(1 / x);
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  Future<void> removeSignal(String id) async {
    final signals = await getSignals();
    signals.removeWhere((s) => s.id == id);
    await _saveSignals(signals);
  }

  Future<void> clearAllSignals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_signalsKey);
  }

  Future<void> _saveSignals(List<CommunitySignal> signals) async {
    final prefs = await SharedPreferences.getInstance();
    final signalsJson = signals.map((s) => s.toJson()).toList();
    await prefs.setString(_signalsKey, jsonEncode(signalsJson));
  }

  Future<Map<String, int>> getAggregatedSignals() async {
    final signals = await getSignals();
    final Map<String, int> aggregated = {};
    
    for (final signal in signals) {
      final key = signal.category.name;
      aggregated[key] = (aggregated[key] ?? 0) + 1;
    }
    
    return aggregated;
  }
}

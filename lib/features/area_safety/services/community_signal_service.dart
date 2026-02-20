import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_signal.dart';

class CommunitySignalService {
  static const String _signalsKey = 'community_signals';

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
      final distance = _haversineDistance(
        centerLat,
        centerLng,
        signal.lat,
        signal.lng,
      );
      return distance <= radiusKm;
    }).toList();
  }

  /// Haversine formula using dart:math
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

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

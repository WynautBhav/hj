import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/community_signal.dart';
import '../../../core/services/supabase_service.dart';

class CommunitySignalService {
  static const String _signalsKey = 'community_signals';

  Future<void> addSignal(CommunitySignal signal) async {
    // 1. Save locally first (Offline-First)
    final signals = await getSignals();
    signals.add(signal);
    await _saveSignals(signals);

    // 2. Attempt sync to Supabase
    await _syncSingleSignal(signal);
  }

  Future<void> _syncSingleSignal(CommunitySignal signal) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      // Map domain model to Supabase schema 'safety_reports'
      // safety_score: we'll use a simple mapping based on category
      int score = 50; 
      // Safe categories don't explicitly exist in the enum, so default is 50.
      await SupabaseService.client.from('safety_reports').insert({
        'device_id': SupabaseService.deviceId, // Anonymous identifier
        'latitude': signal.lat,
        'longitude': signal.lng,
        'safety_score': score,
        'description': signal.categoryDisplayName, // Fallback since no description exists natively
        'timestamp': signal.timestamp.toIso8601String(),
      });
      
      // If we needed to mark as 'synced' locally we could add that property 
      // to CommunitySignal, but for now since it's shared preferences we just 
      // rely on the global backend to repopulate the map if needed, or 
      // treat local purely as a cache.
    } catch (e) {
      // Ignore network errors, it's saved locally
    }
  }

  /// Synchronize all local signals that might not be in the backend
  Future<void> syncOfflineSignals() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      final signals = await getSignals();
      // In a robust implementation, we'd check which ones are already synced
      // For this hackathon, we push the recent ones. Supabase UUIDs avoid some duplication if we mapped IDs.
      for (final signal in signals) {
        if (!signal.isSynced) {
           await _syncSingleSignal(signal);
        }
      }
    } catch (e) {
      // Handle gracefully
    }
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

  /// Get signals from both Local Storage and Supabase
  Future<List<CommunitySignal>> getSignalsInRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    List<CommunitySignal> allSignals = await getSignals();

    // Fetch from Supabase
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final response = await SupabaseService.client
            .from('safety_reports')
            .select()
            .order('timestamp', ascending: false)
            .limit(500);
            
        final remoteSignals = (response as List).map((row) {
          // Simplistic mapping back to local domain model
          return CommunitySignal(
            id: row['id'] as String,
            lat: (row['latitude'] as num).toDouble(),
            lng: (row['longitude'] as num).toDouble(),
            category: CommunitySignalCategory.otherEnvironment, // default map since enum doesn't map perfectly from int score
            timestamp: DateTime.parse(row['timestamp']).toLocal(),
            isSynced: true,
          );
        }).toList();

        // Merge and deduplicate by ID if necessary
        allSignals.addAll(remoteSignals);
      }
    } catch (e) {
      // Fallback to local only
    }

    return allSignals.where((signal) {
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

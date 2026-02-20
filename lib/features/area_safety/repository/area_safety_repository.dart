import 'dart:math';
import '../models/heatmap_zone.dart';
import '../models/community_signal.dart';
import '../services/public_data_api_service.dart';
import '../services/public_data_cache_service.dart';
import '../services/community_signal_service.dart';

class AreaSafetyRepository {
  final PublicDataApiService _apiService;
  final PublicDataCacheService _cacheService;
  final CommunitySignalService _communityService;
  static const double _defaultRadiusKm = 3.0;

  AreaSafetyRepository({
    PublicDataApiService? apiService,
    PublicDataCacheService? cacheService,
    CommunitySignalService? communityService,
  })  : _apiService = apiService ?? PublicDataApiService(),
        _cacheService = cacheService ?? PublicDataCacheService(),
        _communityService = communityService ?? CommunitySignalService();

  Future<AreaSafetyData> loadData({
    required double userLat,
    required double userLng,
    double radiusKm = _defaultRadiusKm,
  }) async {
    final isOnline = await _checkConnectivity();

    List<HeatmapZone> publicZones = [];
    DateTime? lastUpdated;
    bool isUsingCached = false;

    if (isOnline) {
      try {
        final response = await _apiService.fetchPublicData();
        final cachedTimestamp = await _cacheService.getLastUpdateTime();

        if (cachedTimestamp == null ||
            response.updatedOn.isAfter(cachedTimestamp)) {
          publicZones = response.zones;
          await _cacheService.cacheZones(response.zones);
          lastUpdated = response.updatedOn;
        } else {
          publicZones = await _cacheService.getCachedZones();
          lastUpdated = cachedTimestamp;
        }
      } catch (e) {
        publicZones = await _cacheService.getCachedZones();
        lastUpdated = await _cacheService.getLastUpdateTime();
        isUsingCached = true;
      }
    } else {
      publicZones = await _cacheService.getCachedZones();
      lastUpdated = await _cacheService.getLastUpdateTime();
      isUsingCached = true;
    }

    final filteredPublicZones = _filterZonesByRadius(
      publicZones,
      userLat,
      userLng,
      radiusKm,
    );

    final communitySignals = await _communityService.getSignalsInRadius(
      userLat,
      userLng,
      radiusKm,
    );

    return AreaSafetyData(
      publicZones: filteredPublicZones,
      communitySignals: communitySignals,
      lastUpdated: lastUpdated,
      isOnline: isOnline,
      isUsingCached: isUsingCached,
      hasPublicData: publicZones.isNotEmpty,
      hasDataInRange:
          filteredPublicZones.isNotEmpty || communitySignals.isNotEmpty,
    );
  }

  Future<bool> _checkConnectivity() async {
    try {
      return await _apiService.checkConnectivity();
    } catch (_) {
      return false;
    }
  }

  List<HeatmapZone> _filterZonesByRadius(
    List<HeatmapZone> zones,
    double centerLat,
    double centerLng,
    double radiusKm,
  ) {
    return zones.where((zone) {
      final distance = _haversineDistance(
        centerLat,
        centerLng,
        zone.lat,
        zone.lng,
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

  Future<void> addCommunitySignal(CommunitySignal signal) async {
    await _communityService.addSignal(signal);
  }

  Future<List<CommunitySignal>> getCommunitySignals({
    required double userLat,
    required double userLng,
    double radiusKm = _defaultRadiusKm,
  }) async {
    return _communityService.getSignalsInRadius(userLat, userLng, radiusKm);
  }

  Future<DateTime?> getLastUpdateTime() async {
    return _cacheService.getLastUpdateTime();
  }
}

class AreaSafetyData {
  final List<HeatmapZone> publicZones;
  final List<CommunitySignal> communitySignals;
  final DateTime? lastUpdated;
  final bool isOnline;
  final bool isUsingCached;
  final bool hasPublicData;
  final bool hasDataInRange;

  AreaSafetyData({
    required this.publicZones,
    required this.communitySignals,
    this.lastUpdated,
    required this.isOnline,
    required this.isUsingCached,
    required this.hasPublicData,
    required this.hasDataInRange,
  });
}

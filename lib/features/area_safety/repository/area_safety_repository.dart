import 'package:geolocator/geolocator.dart';
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
      hasDataInRange: filteredPublicZones.isNotEmpty || communitySignals.isNotEmpty,
    );
  }

  Future<bool> _checkConnectivity() async {
    try {
      final response = await _apiService.checkConnectivity();
      return response;
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
      final distance = calculateDistance(
        centerLat,
        centerLng,
        zone.lat,
        zone.lng,
      );
      return distance <= radiusKm;
    }).toList();
  }

  double calculateDistance(
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
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
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

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/heatmap_zone.dart';

class PublicDataCacheService {
  static const String _zonesKey = 'cached_safety_zones';
  static const String _timestampKey = 'safety_data_timestamp';

  Future<void> cacheZones(List<HeatmapZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    final zonesJson = zones.map((z) => z.toJson()).toList();
    await prefs.setString(_zonesKey, jsonEncode(zonesJson));
    await prefs.setInt(
      _timestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<HeatmapZone>> getCachedZones() async {
    final prefs = await SharedPreferences.getInstance();
    final zonesJson = prefs.getString(_zonesKey);
    
    if (zonesJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(zonesJson);
      return decoded
          .map((z) => HeatmapZone.fromJson(z as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<bool> hasCachedData() async {
    final zones = await getCachedZones();
    return zones.isNotEmpty;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_zonesKey);
    await prefs.remove(_timestampKey);
  }
}

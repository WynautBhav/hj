import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/heatmap_zone.dart';

class PublicDataApiService {
  // Public safety data endpoint (replace with real one when available)
  static const String _baseUrl = 'https://data.gov.in/api/safety';

  final http.Client _client;

  PublicDataApiService({http.Client? client})
      : _client = client ?? http.Client();

  Future<PublicDataResponse> fetchPublicData() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/zones'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PublicDataResponse.fromJson(json);
      } else {
        // API not available — return demo data for hackathon
        return _getDemoData();
      }
    } catch (e) {
      // Network error — return demo data for hackathon
      return _getDemoData();
    }
  }

  /// Demo data for hackathon — simulates government safety zones
  PublicDataResponse _getDemoData() {
    return PublicDataResponse(
      updatedOn: DateTime.now().subtract(const Duration(hours: 6)),
      zones: [
        HeatmapZone(
          id: 'demo_1',
          lat: 28.6139,
          lng: 77.2090,
          intensity: 0.8,
          category: SafetyCategory.harassment,
        ),
        HeatmapZone(
          id: 'demo_2',
          lat: 28.6200,
          lng: 77.2150,
          intensity: 0.5,
          category: SafetyCategory.lighting,
        ),
        HeatmapZone(
          id: 'demo_3',
          lat: 28.6080,
          lng: 77.2000,
          intensity: 0.3,
          category: SafetyCategory.infrastructure,
        ),
        HeatmapZone(
          id: 'demo_4',
          lat: 26.9124,
          lng: 75.7873,
          intensity: 0.7,
          category: SafetyCategory.assault,
        ),
        HeatmapZone(
          id: 'demo_5',
          lat: 26.9200,
          lng: 75.7900,
          intensity: 0.4,
          category: SafetyCategory.harassment,
        ),
        HeatmapZone(
          id: 'demo_6',
          lat: 19.0760,
          lng: 72.8777,
          intensity: 0.6,
          category: SafetyCategory.lighting,
        ),
        HeatmapZone(
          id: 'demo_7',
          lat: 12.9716,
          lng: 77.5946,
          intensity: 0.9,
          category: SafetyCategory.assault,
        ),
        HeatmapZone(
          id: 'demo_8',
          lat: 12.9750,
          lng: 77.6000,
          intensity: 0.35,
          category: SafetyCategory.infrastructure,
        ),
      ],
    );
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _client
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

class PublicDataResponse {
  final DateTime updatedOn;
  final List<HeatmapZone> zones;

  PublicDataResponse({
    required this.updatedOn,
    required this.zones,
  });

  factory PublicDataResponse.fromJson(Map<String, dynamic> json) {
    final zonesJson = json['zones'] as List<dynamic>? ?? [];
    return PublicDataResponse(
      updatedOn: json['updated_on'] != null
          ? DateTime.parse(json['updated_on'] as String)
          : DateTime.now(),
      zones: zonesJson
          .map((z) => HeatmapZone.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PublicDataException implements Exception {
  final String message;
  PublicDataException(this.message);

  @override
  String toString() => message;
}

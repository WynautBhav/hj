import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/heatmap_zone.dart';

class PublicDataApiService {
  static const String _baseUrl = 'https://api.example.com/safety';
  
  final http.Client _client;

  PublicDataApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<PublicDataResponse> fetchPublicData() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/zones'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PublicDataResponse.fromJson(json);
      } else {
        throw PublicDataException('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      if (e is PublicDataException) rethrow;
      throw PublicDataException('Network error: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _client.get(
        Uri.parse('https://api.example.com/health'),
      ).timeout(const Duration(seconds: 5));
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

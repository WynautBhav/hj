enum SafetyCategory {
  harassment,
  assault,
  infrastructure,
  lighting,
}

class HeatmapZone {
  final String id;
  final double lat;
  final double lng;
  final double intensity;
  final SafetyCategory category;
  final DateTime? timestamp;

  HeatmapZone({
    required this.id,
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.category,
    this.timestamp,
  });

  factory HeatmapZone.fromJson(Map<String, dynamic> json) {
    return HeatmapZone(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      intensity: (json['intensity'] as num).toDouble(),
      category: _categoryFromString(json['category'] as String),
      timestamp: json['updated_on'] != null
          ? DateTime.tryParse(json['updated_on'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'intensity': intensity,
      'category': _categoryToString(category),
    };
  }

  static SafetyCategory _categoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'harassment':
        return SafetyCategory.harassment;
      case 'assault':
        return SafetyCategory.assault;
      case 'infrastructure':
        return SafetyCategory.infrastructure;
      case 'lighting':
        return SafetyCategory.lighting;
      default:
        return SafetyCategory.harassment;
    }
  }

  static String _categoryToString(SafetyCategory category) {
    switch (category) {
      case SafetyCategory.harassment:
        return 'harassment';
      case SafetyCategory.assault:
        return 'assault';
      case SafetyCategory.infrastructure:
        return 'infrastructure';
      case SafetyCategory.lighting:
        return 'lighting';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case SafetyCategory.harassment:
        return 'Harassment';
      case SafetyCategory.assault:
        return 'Assault';
      case SafetyCategory.infrastructure:
        return 'Infrastructure';
      case SafetyCategory.lighting:
        return 'Lighting';
    }
  }

  RiskLevel get riskLevel {
    if (intensity >= 0.7) return RiskLevel.high;
    if (intensity >= 0.4) return RiskLevel.medium;
    return RiskLevel.low;
  }
}

enum RiskLevel {
  low,
  medium,
  high,
}

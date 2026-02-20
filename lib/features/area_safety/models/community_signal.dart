enum CommunitySignalCategory {
  poorLighting,
  isolatedArea,
  infrastructureIssue,
  suspiciousActivity,
  harassmentReports,
  otherEnvironment,
}

class CommunitySignal {
  final String id;
  final double lat;
  final double lng;
  final CommunitySignalCategory category;
  final DateTime timestamp;
  final bool isSynced;

  CommunitySignal({
    required this.id,
    required this.lat,
    required this.lng,
    required this.category,
    required this.timestamp,
    this.isSynced = false,
  });

  factory CommunitySignal.fromJson(Map<String, dynamic> json) {
    return CommunitySignal(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      category: _categoryFromString(json['category'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['is_synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'category': _categoryToString(category),
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  static CommunitySignalCategory _categoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'poor_lighting':
        return CommunitySignalCategory.poorLighting;
      case 'isolated_area':
        return CommunitySignalCategory.isolatedArea;
      case 'infrastructure_issue':
        return CommunitySignalCategory.infrastructureIssue;
      case 'suspicious_activity':
        return CommunitySignalCategory.suspiciousActivity;
      case 'harassment_reports':
        return CommunitySignalCategory.harassmentReports;
      case 'other_environment':
        return CommunitySignalCategory.otherEnvironment;
      default:
        return CommunitySignalCategory.otherEnvironment;
    }
  }

  static String _categoryToString(CommunitySignalCategory category) {
    switch (category) {
      case CommunitySignalCategory.poorLighting:
        return 'poor_lighting';
      case CommunitySignalCategory.isolatedArea:
        return 'isolated_area';
      case CommunitySignalCategory.infrastructureIssue:
        return 'infrastructure_issue';
      case CommunitySignalCategory.suspiciousActivity:
        return 'suspicious_activity';
      case CommunitySignalCategory.harassmentReports:
        return 'harassment_reports';
      case CommunitySignalCategory.otherEnvironment:
        return 'other_environment';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case CommunitySignalCategory.poorLighting:
        return 'Poor Lighting';
      case CommunitySignalCategory.isolatedArea:
        return 'Isolated Area';
      case CommunitySignalCategory.infrastructureIssue:
        return 'Infrastructure Issue';
      case CommunitySignalCategory.suspiciousActivity:
        return 'Suspicious Activity';
      case CommunitySignalCategory.harassmentReports:
        return 'Harassment Reports';
      case CommunitySignalCategory.otherEnvironment:
        return 'Other Environment';
    }
  }

  String get categoryIcon {
    switch (category) {
      case CommunitySignalCategory.poorLighting:
        return '💡';
      case CommunitySignalCategory.isolatedArea:
        return '🏚️';
      case CommunitySignalCategory.infrastructureIssue:
        return '🚧';
      case CommunitySignalCategory.suspiciousActivity:
        return '👁️';
      case CommunitySignalCategory.harassmentReports:
        return '⚠️';
      case CommunitySignalCategory.otherEnvironment:
        return '📍';
    }
  }
}

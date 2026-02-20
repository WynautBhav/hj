import 'dart:convert';

class VoicePhrase {
  final String id;
  final String phrase;
  final String language;
  final DateTime createdAt;
  final bool isActive;

  VoicePhrase({
    required this.id,
    required this.phrase,
    required this.language,
    required this.createdAt,
    this.isActive = true,
  });

  factory VoicePhrase.fromJson(Map<String, dynamic> json) {
    return VoicePhrase(
      id: json['id'] as String,
      phrase: json['phrase'] as String,
      language: json['language'] as String? ?? 'en_US',
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phrase': phrase,
      'language': language,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  VoicePhrase copyWith({
    String? id,
    String? phrase,
    String? language,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return VoicePhrase(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool matchesRecognizedText(String recognizedText) {
    final normalizedPhrase = phrase.toLowerCase().trim();
    final normalizedRecognized = recognizedText.toLowerCase().trim();
    
    return normalizedRecognized.contains(normalizedPhrase) ||
           normalizedPhrase.contains(normalizedRecognized);
  }
}

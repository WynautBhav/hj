import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/location_service.dart';

class Contact {
  final String name;
  final String phone;
  final String? photoUrl;

  Contact({required this.name, required this.phone, this.photoUrl});

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'photoUrl': photoUrl,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    photoUrl: json['photoUrl'],
  );
}

class ContactService {
  static const String _contactsKey = 'emergency_contacts';
  static const int maxContacts = 5;

  Future<List<Contact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList(_contactsKey) ?? [];
    List<Contact> contacts = [];
    for (String c in contactsJson) {
      try {
        contacts.add(Contact.fromJson(jsonDecode(c)));
      } catch (_) {
        // Fallback for older URL-encoded data
        try {
          final decoded = Map<String, dynamic>.from(
            Uri.splitQueryString(c).map((k, v) => MapEntry(k, v))
          );
          contacts.add(Contact.fromJson(decoded));
        } catch (_) {}
      }
    }
    return contacts;
  }

  Future<void> saveContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_contactsKey, contactsJson);
  }

  Future<void> addContact(Contact contact) async {
    final contacts = await getContacts();
    if (contacts.length < maxContacts) {
      contacts.add(contact);
      await saveContacts(contacts);
    }
  }

  Future<void> removeContact(int index) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts.removeAt(index);
      await saveContacts(contacts);
    }
  }
}

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final LocationService _locationService = LocationService();
  bool _isSendingSos = false;
  
  Future<int> sendSosSms(List<Contact> contacts, String defaultMessage) async {
    if (_isSendingSos) return 0;
    _isSendingSos = true;
    int successCount = 0;

    try {
      final permGranted = await PermissionService.checkAndRequestSms();
      if (!permGranted) return 0;

      final prefs = await SharedPreferences.getInstance();

      for (final contact in contacts) {
        final customMsg = prefs.getString('sos_message_${contact.phone}');
        String finalMsg = defaultMessage;
        
        if (customMsg != null && customMsg.isNotEmpty) {
          final linkMatch = RegExp(r'https://[^\s]+').firstMatch(defaultMessage);
          final link = linkMatch?.group(0) ?? '';
          finalMsg = link.isNotEmpty ? '$customMsg\nLocation: $link' : customMsg;
        }

        final success = await _sendSms(contact.phone, finalMsg);
        if (success) successCount++;
      }
    } finally {
      _isSendingSos = false;
    }
    return successCount;
  }

  String _sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<bool> _sendSms(String phone, String message) async {
    const shieldChannel = MethodChannel('com.saheli.saheli/shield');
    try {
      final result = await shieldChannel.invokeMethod<bool>('sendSms', {
        'phone': _sanitizePhone(phone),
        'message': message,
      }).timeout(const Duration(seconds: 5));
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to send native SMS to $phone: $e');
      return false;
    }
  }

  Future<void> sendLocationSms(List<Contact> contacts, String message) async {
    final permGranted = await PermissionService.checkAndRequestSms();
    if (!permGranted) return;

    for (final contact in contacts) {
      await _sendSms(contact.phone, message);
    }
  }
}

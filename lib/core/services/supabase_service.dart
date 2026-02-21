import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://oifcaqysirzmorrktaen.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pZmNhcXlzaXJ6bW9ycmt0YWVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MjEyMjUsImV4cCI6MjA4NzE5NzIyNX0.yapl69uRlJfmuyYllAwshY7I029vnceJF_RFrb5RcQM';
  
  static late final SupabaseClient client;
  static late final String deviceId;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    client = Supabase.instance.client;
    
    // Manage anonymous device ID
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('device_id');
    
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('device_id', storedId);
    }
    
    deviceId = storedId;
  }
}

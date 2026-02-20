import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SOS event recorded in SQLite history.
class SosEvent {
  final int? id;
  final String triggerType;   // 'shake', 'voice', 'volume', 'manual', 'scream', 'dead_man'
  final String timestamp;     // ISO8601
  final double? latitude;
  final double? longitude;
  final int contactsNotified;

  SosEvent({
    this.id,
    required this.triggerType,
    required this.timestamp,
    this.latitude,
    this.longitude,
    required this.contactsNotified,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'trigger_type': triggerType,
    'timestamp': timestamp,
    'latitude': latitude,
    'longitude': longitude,
    'contacts_notified': contactsNotified,
  };

  factory SosEvent.fromMap(Map<String, dynamic> m) => SosEvent(
    id: m['id'] as int?,
    triggerType: m['trigger_type'] as String,
    timestamp: m['timestamp'] as String,
    latitude: m['latitude'] as double?,
    longitude: m['longitude'] as double?,
    contactsNotified: m['contacts_notified'] as int,
  );
}

/// SQLite-backed SOS history service.
/// Records every SOS trigger with type, timestamp, location, and contacts notified.
class SosHistoryService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'sos_history.db'),
      version: 1,
      onCreate: (db, v) => db.execute(
        'CREATE TABLE sos_events('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'trigger_type TEXT, '
        'timestamp TEXT, '
        'latitude REAL, '
        'longitude REAL, '
        'contacts_notified INTEGER'
        ')',
      ),
    );
    return _db!;
  }

  /// Record an SOS event after it's triggered.
  Future<void> recordSos({
    required String triggerType,
    double? latitude,
    double? longitude,
    required int contactsNotified,
  }) async {
    try {
      final database = await db;
      await database.insert('sos_events', SosEvent(
        triggerType: triggerType,
        timestamp: DateTime.now().toIso8601String(),
        latitude: latitude,
        longitude: longitude,
        contactsNotified: contactsNotified,
      ).toMap());
    } catch (e) {
      // Never crash on history recording failure
    }
  }

  /// Get last 100 SOS events, newest first.
  Future<List<SosEvent>> getHistory() async {
    try {
      final database = await db;
      final maps = await database.query(
        'sos_events',
        orderBy: 'id DESC',
        limit: 100,
      );
      return maps.map(SosEvent.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear all SOS history.
  Future<void> clearHistory() async {
    try {
      final database = await db;
      await database.delete('sos_events');
    } catch (e) {
      // Never crash
    }
  }
}

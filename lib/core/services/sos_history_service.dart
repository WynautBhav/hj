import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';

/// SOS event recorded in SQLite history.
class SosEvent {
  final int? id;
  final String triggerType;   // 'shake', 'voice', 'volume', 'manual', 'scream', 'dead_man'
  final String timestamp;     // ISO8601
  final double? latitude;
  final double? longitude;
  final int contactsNotified;
  final bool synced;

  SosEvent({
    this.id,
    required this.triggerType,
    required this.timestamp,
    this.latitude,
    this.longitude,
    required this.contactsNotified,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'trigger_type': triggerType,
    'timestamp': timestamp,
    'latitude': latitude,
    'longitude': longitude,
    'contacts_notified': contactsNotified,
    'synced': synced ? 1 : 0,
  };

  factory SosEvent.fromMap(Map<String, dynamic> m) => SosEvent(
    id: m['id'] as int?,
    triggerType: m['trigger_type'] as String,
    timestamp: m['timestamp'] as String,
    latitude: m['latitude'] as double?,
    longitude: m['longitude'] as double?,
    contactsNotified: m['contacts_notified'] as int,
    synced: (m['synced'] ?? 0) == 1,
  );
}

/// SQLite-backed SOS history service with Supabase offline-first sync.
class SosHistoryService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'sos_history.db'),
      version: 2,
      onCreate: (db, v) => db.execute(
        'CREATE TABLE sos_events('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'trigger_type TEXT, '
        'timestamp TEXT, '
        'latitude REAL, '
        'longitude REAL, '
        'contacts_notified INTEGER, '
        'synced INTEGER DEFAULT 0'
        ')',
      ),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE sos_events ADD COLUMN synced INTEGER DEFAULT 0');
        }
      },
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
      final timestamp = DateTime.now().toIso8601String();
      
      final id = await database.insert('sos_events', SosEvent(
        triggerType: triggerType,
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        contactsNotified: contactsNotified,
        synced: false,
      ).toMap());

      // Attempt to sync immediately
      _syncSingleEvent(SosEvent(
        id: id,
        triggerType: triggerType,
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        contactsNotified: contactsNotified,
      ));
    } catch (e) {
      // Never crash on history recording failure
    }
  }

  Future<void> _syncSingleEvent(SosEvent event) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      await SupabaseService.client.from('sos_events').insert({
        'device_id': SupabaseService.deviceId,
        'trigger_type': event.triggerType,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'timestamp': event.timestamp,
      });

      // Mark as synced locally
      final database = await db;
      await database.update(
        'sos_events',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e) {
      // Ignore network errors; will retry later
    }
  }

  /// Synchronize all pending offline SOS events to Supabase
  Future<void> syncOfflineEvents() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      final database = await db;
      final unsynced = await database.query(
        'sos_events',
        where: 'synced = ?',
        whereArgs: [0],
      );

      for (final map in unsynced) {
        await _syncSingleEvent(SosEvent.fromMap(map));
      }
    } catch (e) {
      // Handle gracefully
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

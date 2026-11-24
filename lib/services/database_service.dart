import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/location_record.dart';

/// Handles all SQLite operations for [LocationRecord] persistence.
///
/// Single-table design keeps things simple while supporting:
/// - Insert on capture
/// - Batch fetch of pending records
/// - Status updates (synced / failed)
/// - Retry-count increment
class DatabaseService {
  static const String _dbName = 'track_drive.db';
  static const String _tableName = 'location_records';
  static const int _maxRetries = 3;

  Database? _db;

  /// Lazy-initialises and returns the database instance.
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id           TEXT PRIMARY KEY,
            latitude     REAL NOT NULL,
            longitude    REAL NOT NULL,
            accuracy     REAL NOT NULL,
            speed        REAL NOT NULL,
            timestamp    TEXT NOT NULL,
            sync_status  TEXT NOT NULL DEFAULT 'pending',
            retry_count  INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // Index to quickly fetch pending rows.
        await db.execute('''
          CREATE INDEX idx_sync_status ON $_tableName(sync_status)
        ''');
      },
    );
  }

  /// Insert a new location record.
  /// Skips insertion if a record with the same [id] already exists
  /// (idempotent, prevents duplicate storage).
  Future<void> insertRecord(LocationRecord record) async {
    final db = await database;
    await db.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Fetch all records with [SyncStatus.pending] that have not exceeded
  /// [_maxRetries].
  Future<List<LocationRecord>> getPendingRecords() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: "sync_status = ? AND retry_count <= ?",
      whereArgs: [SyncStatus.pending.name, _maxRetries],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocationRecord.fromMap).toList();
  }

  /// Mark a record as successfully synced.
  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update(
      _tableName,
      {'sync_status': SyncStatus.synced.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment retry count. If count now exceeds [_maxRetries], mark as
  /// [SyncStatus.failed] so we stop retrying.
  Future<void> incrementRetry(String id) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      columns: ['retry_count'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;

    final current = (rows.first['retry_count'] as int?) ?? 0;
    final newCount = current + 1;
    final newStatus = newCount > _maxRetries
        ? SyncStatus.failed.name
        : SyncStatus.pending.name;

    await db.update(
      _tableName,
      {'retry_count': newCount, 'sync_status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns all records (for display purposes).
  Future<List<LocationRecord>> getAllRecords({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(LocationRecord.fromMap).toList();
  }

  /// Delete all synced records to keep storage lean (optional housekeeping).
  Future<int> clearSyncedRecords() async {
    final db = await database;
    return db.delete(
      _tableName,
      where: "sync_status = ?",
      whereArgs: [SyncStatus.synced.name],
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  /// Used in tests: drop and re-create all tables.
  Future<void> resetForTesting() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS $_tableName');
    await db.execute('''
      CREATE TABLE $_tableName (
        id           TEXT PRIMARY KEY,
        latitude     REAL NOT NULL,
        longitude    REAL NOT NULL,
        accuracy     REAL NOT NULL,
        speed        REAL NOT NULL,
        timestamp    TEXT NOT NULL,
        sync_status  TEXT NOT NULL DEFAULT 'pending',
        retry_count  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_status ON $_tableName(sync_status)');
  }
}

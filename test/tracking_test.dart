import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:track_drive/models/location_record.dart';
import 'package:track_drive/services/database_service.dart';
import 'package:track_drive/services/api_service.dart';
import 'package:track_drive/services/sync_service.dart';
import 'package:track_drive/services/connectivity_service.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

LocationRecord _fakeRecord({
  String id = 'test-id-001',
  SyncStatus status = SyncStatus.pending,
  int retryCount = 0,
}) =>
    LocationRecord(
      id: id,
      latitude: 12.9716,
      longitude: 77.5946,
      accuracy: 5.0,
      speed: 10.0,
      timestamp: DateTime(2024, 1, 15, 10, 0),
      syncStatus: status,
      retryCount: retryCount,
    );

// Always-online mock connectivity
class _AlwaysOnlineConnectivity extends ConnectivityService {
  @override
  Stream<bool> get onlineStatusStream => Stream.value(true);

  @override
  Future<bool> isCurrentlyOnline() async => true;
}

class _AlwaysOfflineConnectivity extends ConnectivityService {
  @override
  Stream<bool> get onlineStatusStream => Stream.value(false);

  @override
  Future<bool> isCurrentlyOnline() async => false;
}

// ─── Main ────────────────────────────────────────────────────────────────────

void main() {
  // Required for sqflite in a non-Flutter test environment.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Fresh DB per test.
  late DatabaseService db;
  setUp(() async {
    db = DatabaseService();
    await db.resetForTesting();
  });
  tearDown(() => db.close());

  // ══════════════════════════════════════════════════════════════════════════
  //  GROUP 1 – Offline Storage
  // ══════════════════════════════════════════════════════════════════════════
  group('Offline Storage', () {
    test('inserts a location record into SQLite', () async {
      final record = _fakeRecord();
      await db.insertRecord(record);

      final all = await db.getAllRecords();
      expect(all, hasLength(1));
      expect(all.first.id, equals(record.id));
      expect(all.first.latitude, equals(record.latitude));
    });

    test('new records default to SyncStatus.pending', () async {
      await db.insertRecord(_fakeRecord());

      final pending = await db.getPendingRecords();
      expect(pending, hasLength(1));
      expect(pending.first.syncStatus, equals(SyncStatus.pending));
    });

    test('duplicate record (same id) is ignored', () async {
      final record = _fakeRecord();
      await db.insertRecord(record);
      await db.insertRecord(record); // second insert with same id

      final all = await db.getAllRecords();
      expect(all, hasLength(1), reason: 'Duplicate id must not create a second row');
    });

    test('markSynced changes status to synced', () async {
      final record = _fakeRecord();
      await db.insertRecord(record);
      await db.markSynced(record.id);

      final all = await db.getAllRecords();
      expect(all.first.syncStatus, equals(SyncStatus.synced));

      final pending = await db.getPendingRecords();
      expect(pending, isEmpty, reason: 'Synced records must not appear in pending list');
    });

    test('clearSyncedRecords removes only synced rows', () async {
      await db.insertRecord(_fakeRecord(id: 'p1', status: SyncStatus.pending));
      await db.insertRecord(_fakeRecord(id: 's1', status: SyncStatus.synced));
      await db.insertRecord(_fakeRecord(id: 's2', status: SyncStatus.synced));

      final deleted = await db.clearSyncedRecords();
      expect(deleted, equals(2));

      final remaining = await db.getAllRecords();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, equals('p1'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  GROUP 2 – Retry Logic
  // ══════════════════════════════════════════════════════════════════════════
  group('Retry Logic', () {
    test('incrementRetry increases retry_count by one', () async {
      await db.insertRecord(_fakeRecord());
      await db.incrementRetry('test-id-001');

      final rows = await db.getAllRecords();
      expect(rows.first.retryCount, equals(1));
    });

    test('record is marked failed after exceeding max retries (3)', () async {
      await db.insertRecord(_fakeRecord());

      // Simulate 4 failures (3 is the threshold, 4th push should flip to failed)
      for (var i = 0; i < 4; i++) {
        await db.incrementRetry('test-id-001');
      }

      final rows = await db.getAllRecords();
      expect(rows.first.syncStatus, equals(SyncStatus.failed));
    });

    test('failed records do not appear in getPendingRecords', () async {
      await db.insertRecord(_fakeRecord(id: 'ok'));
      await db.insertRecord(_fakeRecord(id: 'bad', status: SyncStatus.failed));

      final pending = await db.getPendingRecords();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('ok'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  GROUP 3 – Synchronization
  // ══════════════════════════════════════════════════════════════════════════
  group('Synchronization', () {
    test('syncPending marks records synced when API returns 201', () async {
      final record = _fakeRecord();
      await db.insertRecord(record);

      final mockClient = MockClient((_) async {
        return http.Response(jsonEncode({'id': 101}), 201);
      });

      final api = ApiService(client: mockClient);
      final sync = SyncService(
        db: db,
        api: api,
        connectivity: _AlwaysOnlineConnectivity(),
      );

      await sync.syncPending();

      final remaining = await db.getPendingRecords();
      expect(remaining, isEmpty, reason: 'Pending list should be empty after successful sync');

      final all = await db.getAllRecords();
      expect(all.first.syncStatus, equals(SyncStatus.synced));

      mockClient.close();
    });

    test('syncPending increments retry on API failure (500)', () async {
      await db.insertRecord(_fakeRecord());

      final mockClient = MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final api = ApiService(client: mockClient);
      final sync = SyncService(
        db: db,
        api: api,
        connectivity: _AlwaysOnlineConnectivity(),
      );

      await sync.syncPending();

      final rows = await db.getAllRecords();
      expect(rows.first.retryCount, equals(1));
      expect(rows.first.syncStatus, equals(SyncStatus.pending));

      mockClient.close();
    });

    test('syncPending does nothing when no pending records exist', () async {
      // DB is empty.
      final logs = <String>[];
      final api = ApiService(
        client: MockClient((_) async => http.Response('', 201)),
      );
      final sync = SyncService(
        db: db,
        api: api,
        connectivity: _AlwaysOnlineConnectivity(),
      )..onLog = logs.add;

      await sync.syncPending();

      expect(logs, anyElement(contains('Nothing to sync')));
    });

    test('duplicate upload is prevented by SQLite unique-id constraint', () async {
      final record = _fakeRecord();

      int uploadCount = 0;
      final mockClient = MockClient((_) async {
        uploadCount++;
        return http.Response(jsonEncode({'id': 101}), 201);
      });

      final api = ApiService(client: mockClient);
      final sync = SyncService(
        db: db,
        api: api,
        connectivity: _AlwaysOnlineConnectivity(),
      );

      // Insert the same record twice, then sync.
      await db.insertRecord(record);
      await db.insertRecord(record); // duplicate – ignored by DB
      await sync.syncPending();

      expect(uploadCount, equals(1), reason: 'API must be called only once per unique record');
      mockClient.close();
    });

    test('records are stored locally when offline and synced when back online',
        () async {
      // --- PHASE 1: offline capture ---
      final offlineApi = ApiService(
        client: MockClient((_) async => throw Exception('no internet')),
      );
      final offlineSync = SyncService(
        db: db,
        api: offlineApi,
        connectivity: _AlwaysOfflineConnectivity(),
      );

      await db.insertRecord(_fakeRecord(id: 'loc-1'));
      await db.insertRecord(_fakeRecord(id: 'loc-2'));

      // Both should still be pending (no auto-sync while offline).
      final pendingBeforeSync = await db.getPendingRecords();
      expect(pendingBeforeSync, hasLength(2));

      offlineSync.stop();

      // --- PHASE 2: back online, sync ---
      final onlineClient = MockClient((_) async {
        return http.Response(jsonEncode({'id': 999}), 201);
      });
      final onlineApi = ApiService(client: onlineClient);
      final onlineSync = SyncService(
        db: db,
        api: onlineApi,
        connectivity: _AlwaysOnlineConnectivity(),
      );

      await onlineSync.syncPending();

      final remaining = await db.getPendingRecords();
      expect(remaining, isEmpty, reason: 'All records should be synced after reconnect');
      onlineClient.close();
    });
  });
}

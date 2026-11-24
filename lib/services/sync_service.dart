import 'dart:async';
import '../models/location_record.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';

/// Orchestrates syncing of pending [LocationRecord]s with the backend.
///
/// Responsibilities:
/// 1. Watch connectivity and trigger sync when going online.
/// 2. Upload pending records one-by-one (preserves order, easy to retry).
/// 3. Mark each record synced or increment its retry counter.
/// 4. Avoid duplicate uploads via the SQLite unique-id constraint.
class SyncService {
  final DatabaseService _db;
  final ApiService _api;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySub;
  bool _syncing = false;

  // Notifier callbacks so the UI can react without tight coupling.
  void Function(String message)? onLog;
  void Function()? onSyncComplete;

  SyncService({
    required DatabaseService db,
    required ApiService api,
    required ConnectivityService connectivity,
  })  : _db = db,
        _api = api,
        _connectivity = connectivity;

  /// Begin listening for connectivity changes and auto-sync on reconnect.
  void start() {
    _connectivitySub =
        _connectivity.onlineStatusStream.listen((isOnline) async {
      if (isOnline) {
        _log('🌐 Back online – triggering sync…');
        await syncPending();
      } else {
        _log('📵 Offline – records will be stored locally.');
      }
    });
  }

  /// Stop the connectivity listener.
  void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Upload all pending records. Re-entrant calls are ignored while a sync
  /// is already in progress.
  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final pending = await _db.getPendingRecords();
      if (pending.isEmpty) {
        _log('✅ Nothing to sync.');
        return;
      }

      _log('⬆️  Syncing ${pending.length} record(s)…');
      int successCount = 0;

      for (final record in pending) {
        try {
          final ok = await _api.uploadRecord(record);
          if (ok) {
            await _db.markSynced(record.id);
            successCount++;
          }
        } on ApiException catch (e) {
          _log('⚠️  Failed to upload ${record.id.substring(0, 8)}: $e');
          await _db.incrementRetry(record.id);
        }
      }

      _log('✅ Synced $successCount / ${pending.length} records.');
      onSyncComplete?.call();
    } finally {
      _syncing = false;
    }
  }

  void _log(String message) => onLog?.call(message);
}

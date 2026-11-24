import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location_record.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

/// Central state manager for the tracking screen.
///
/// Uses [ChangeNotifier] (Provider pattern) so widgets rebuild only when
/// [notifyListeners] is called – no unnecessary rebuilds.
class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;
  final DatabaseService _databaseService;
  final ConnectivityService _connectivityService;
  final SyncService _syncService;

  TrackingProvider({
    required LocationService locationService,
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
    required SyncService syncService,
  })  : _locationService = locationService,
        _databaseService = databaseService,
        _connectivityService = connectivityService,
        _syncService = syncService;

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isTracking = false;
  bool _isOnline = false;
  bool _isSyncing = false;
  LocationRecord? _latestRecord;
  final List<LocationRecord> _recentRecords = [];
  final List<String> _logs = [];
  int _pendingCount = 0;
  int _syncedCount = 0;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isTracking => _isTracking;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  LocationRecord? get latestRecord => _latestRecord;
  List<LocationRecord> get recentRecords => List.unmodifiable(_recentRecords);
  List<String> get logs => List.unmodifiable(_logs);
  int get pendingCount => _pendingCount;
  int get syncedCount => _syncedCount;

  // ── Subscriptions ───────────────────────────────────────────────────────────

  StreamSubscription<LocationRecord>? _locationSub;
  StreamSubscription<bool>? _connectivitySub;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isOnline = await _connectivityService.isCurrentlyOnline();

    // Wire sync-service logs into our log list.
    _syncService.onLog = (msg) {
      _addLog(msg);
      notifyListeners();
    };
    _syncService.onSyncComplete = () async {
      await _refreshCounts();
      notifyListeners();
    };

    // Start auto-sync listener.
    _syncService.start();

    // Watch connectivity for UI badge.
    _connectivitySub =
        _connectivityService.onlineStatusStream.listen((online) {
      _isOnline = online;
      notifyListeners();
    });

    await _refreshCounts();
    notifyListeners();
  }

  // ── Tracking control ────────────────────────────────────────────────────────

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _addLog('▶ Tracking started.');
    notifyListeners();

    _locationSub = _locationService.startTracking().listen(
      _onLocationUpdate,
      onError: (e) => _addLog('❌ Location error: $e'),
    );
  }

  void stopTracking() {
    if (!_isTracking) return;
    _isTracking = false;
    _locationService.stopTracking();
    _locationSub?.cancel();
    _locationSub = null;
    _addLog('⏹ Tracking stopped.');
    notifyListeners();
  }

  // ── Manual sync ─────────────────────────────────────────────────────────────

  Future<void> manualSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    await _syncService.syncPending();

    _isSyncing = false;
    await _refreshCounts();
    notifyListeners();
  }

  // ── Clear synced records ────────────────────────────────────────────────────

  Future<void> clearSynced() async {
    await _databaseService.clearSyncedRecords();
    await _refreshCounts();
    _addLog('🗑 Cleared synced records.');
    notifyListeners();
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _onLocationUpdate(LocationRecord record) async {
    _latestRecord = record;

    // Persist first (offline-safe).
    await _databaseService.insertRecord(record);

    // If online, attempt immediate sync.
    if (_isOnline) {
      await _syncService.syncPending();
    }

    await _refreshCounts();

    // Keep the last 20 for the list view.
    _recentRecords.insert(0, record);
    if (_recentRecords.length > 20) _recentRecords.removeLast();

    notifyListeners();
  }

  Future<void> _refreshCounts() async {
    final pending = await _databaseService.getPendingRecords();
    final all = await _databaseService.getAllRecords(limit: 500);
    _pendingCount = pending.length;
    _syncedCount = all.where((r) => r.syncStatus == SyncStatus.synced).length;
  }

  void _addLog(String message) {
    _logs.insert(0, '[${_time()}] $message');
    if (_logs.length > 100) _logs.removeLast();
  }

  String _time() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    stopTracking();
    _syncService.stop();
    _connectivitySub?.cancel();
    super.dispose();
  }
}

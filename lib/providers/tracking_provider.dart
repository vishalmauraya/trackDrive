import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location_record.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/permission_service.dart';

/// Central state manager for the tracking screen.
///
/// Uses [ChangeNotifier] (Provider pattern) so widgets rebuild only when
/// [notifyListeners] is called – no unnecessary rebuilds.
class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;
  final DatabaseService _databaseService;
  final ConnectivityService _connectivityService;
  final SyncService _syncService;
  final PermissionService _permissionService;

  TrackingProvider({
    required LocationService locationService,
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
    required SyncService syncService,
    PermissionService? permissionService,
  })  : _locationService = locationService,
        _databaseService = databaseService,
        _connectivityService = connectivityService,
        _syncService = syncService,
        _permissionService = permissionService ?? PermissionService();

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isTracking = false;
  bool _isOnline = false;
  bool _isSyncing = false;
  bool _hasForegroundPermission = false;
  bool _hasBackgroundPermission = false;
  TrackingMode _trackingMode = TrackingMode.simulated;

  LocationRecord? _latestRecord;
  final List<LocationRecord> _recentRecords = [];
  final List<LocationRecord> _routeHistory = [];
  final List<String> _logs = [];
  int _pendingCount = 0;
  int _syncedCount = 0;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isTracking => _isTracking;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get hasForegroundPermission => _hasForegroundPermission;
  bool get hasBackgroundPermission => _hasBackgroundPermission;
  TrackingMode get trackingMode => _trackingMode;
  LocationRecord? get latestRecord => _latestRecord;
  List<LocationRecord> get recentRecords => List.unmodifiable(_recentRecords);
  List<LocationRecord> get routeHistory => List.unmodifiable(_routeHistory);
  List<String> get logs => List.unmodifiable(_logs);
  int get pendingCount => _pendingCount;
  int get syncedCount => _syncedCount;

  // ── Subscriptions ───────────────────────────────────────────────────────────

  StreamSubscription<LocationRecord>? _locationSub;
  StreamSubscription<bool>? _connectivitySub;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isOnline = await _connectivityService.isCurrentlyOnline();
    await checkPermissions();

    // Load existing history from DB for polyline display
    final existing = await _databaseService.getAllRecords(limit: 500);
    _routeHistory.clear();
    _routeHistory.addAll(existing.reversed);
    if (_routeHistory.isNotEmpty) {
      _latestRecord = _routeHistory.last;
    }

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

  // ── Permissions ─────────────────────────────────────────────────────────────

  Future<void> checkPermissions() async {
    try {
      _hasForegroundPermission =
          await _permissionService.hasLocationPermission();
      _hasBackgroundPermission =
          await _permissionService.hasBackgroundPermission();
      notifyListeners();
    } catch (_) {
      // Running in unit test or unsupported platform
    }
  }

  Future<void> requestPermissions() async {
    try {
      _addLog('🛡️ Requesting location permissions…');
      final result =
          await _permissionService.requestAllLocationPermissions();
      _hasForegroundPermission = result.foreground;
      _hasBackgroundPermission = result.background;

      if (result.foreground) {
        _addLog('✅ Foreground location granted.');
      } else {
        _addLog('⚠️ Foreground location denied.');
      }

      if (result.background) {
        _addLog('✅ Background location tracking enabled.');
      } else {
        _addLog('ℹ️ Background location not granted (foreground only).');
      }

      notifyListeners();
    } catch (e) {
      _addLog('⚠️ Permission check skipped ($e)');
    }
  }

  void setTrackingMode(TrackingMode mode) {
    if (_trackingMode == mode) return;
    _trackingMode = mode;
    _addLog('⚙️ Mode set to: ${mode == TrackingMode.realGps ? "Real GPS" : "Simulated GPS"}');
    if (_isTracking) {
      stopTracking();
      startTracking();
    } else {
      notifyListeners();
    }
  }

  // ── Tracking control ────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    if (_isTracking) return;

    // If using Real GPS, request permissions first if not yet granted
    if (_trackingMode == TrackingMode.realGps && !_hasForegroundPermission) {
      await requestPermissions();
    }

    _isTracking = true;
    _addLog('▶ Tracking started (${_trackingMode == TrackingMode.realGps ? "Real GPS" : "Simulated"}).');
    notifyListeners();

    _locationSub = _locationService
        .startTracking(targetMode: _trackingMode)
        .listen(
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

    // Append to live route history for map polyline
    _routeHistory.add(record);

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

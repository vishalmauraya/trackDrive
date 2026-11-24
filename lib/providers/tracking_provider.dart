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
  bool _permissionChecked = false;
  bool _hasForegroundPermission = false;
  bool _hasBackgroundPermission = false;
  bool _isPermanentlyDenied = false;

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
  bool get permissionChecked => _permissionChecked;
  bool get hasForegroundPermission => _hasForegroundPermission;
  bool get hasBackgroundPermission => _hasBackgroundPermission;
  bool get isPermanentlyDenied => _isPermanentlyDenied;
  bool get isLocationPermissionRequired =>
      _permissionChecked && !_hasForegroundPermission;

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

    // Auto-check and request location permissions on app open
    await _autoCheckPermissions();

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

  Future<void> _autoCheckPermissions() async {
    try {
      _addLog('🔍 Checking location permissions on open…');
      final result = await _permissionService.autoCheckAndRequestOnOpen();
      _hasForegroundPermission = result.foreground;
      _hasBackgroundPermission = result.background;
      _isPermanentlyDenied = result.isPermanentlyDenied;
      _permissionChecked = true;

      if (_hasForegroundPermission) {
        _addLog('✅ Location permission verified.');
      } else {
        _addLog('⚠️ Location permission denied. Permission is necessary to continue.');
      }
    } catch (_) {
      _permissionChecked = true;
      _hasForegroundPermission = true;
    }
  }

  Future<void> requestPermissions() async {
    try {
      _addLog('🛡️ Requesting location permissions…');
      final result =
          await _permissionService.requestAllLocationPermissions();
      _hasForegroundPermission = result.foreground;
      _hasBackgroundPermission = result.background;
      _isPermanentlyDenied = result.isPermanentlyDenied;
      _permissionChecked = true;

      if (result.foreground) {
        _addLog('✅ Location permission granted.');
      } else {
        _addLog('⚠️ Location permission denied.');
      }

      if (result.background) {
        _addLog('✅ Background location tracking enabled.');
      } else {
        _addLog('ℹ️ Background location not granted (foreground only).');
      }

      notifyListeners();
    } catch (e) {
      _addLog('⚠️ Permission request failed ($e)');
    }
  }

  Future<void> openAppSettings() async {
    await _permissionService.openSettings();
  }

  // ── Tracking control ────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    if (_isTracking) return;

    // Verify location permissions
    if (!_hasForegroundPermission) {
      await requestPermissions();
      if (!_hasForegroundPermission) {
        _addLog('❌ Cannot start tracking without location permission.');
        return;
      }
    }

    // Check if hardware GPS is enabled
    final isGpsOn = await _locationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      _addLog('⚠️ Device GPS is turned off. Opening location settings…');
      await _locationService.openLocationSettings();
      return;
    }

    _isTracking = true;
    _addLog('▶ Real GPS tracking started.');
    notifyListeners();

    _locationSub = _locationService.startTracking().listen(
      _onLocationUpdate,
      onError: (e) {
        _addLog('❌ Real GPS error: $e');
        stopTracking();
      },
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

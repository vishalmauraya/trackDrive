# TrackDrive

> **Flutter Assessment** — Driver Location Tracking & Offline Synchronisation

A Flutter application demonstrating real-time GPS tracking, offline-first SQLite storage, and automatic background synchronisation with a mock REST API.

---

## 📋 Table of Contents
- [Features](#features)
- [Architecture](#architecture)
- [Setup & Run](#setup--run)
- [Running Tests](#running-tests)
- [Background Tracking on Android & iOS](#background-tracking-on-android--ios)
- [Design Decisions](#design-decisions)

---

## ✅ Features

| Requirement | Implementation |
|---|---|
| Start / Stop GPS tracking | Simulated GPS stream via `LocationService` (3 s interval) |
| Capture location records | `TrackingProvider` stores every emission |
| Offline storage | `DatabaseService` (SQLite via `sqflite`) with `ConflictAlgorithm.ignore` |
| Auto-sync on reconnect | `SyncService` listens to `connectivity_plus` changes |
| Duplicate-upload prevention | SQLite `PRIMARY KEY` + `ConflictAlgorithm.ignore` |
| Retry with failure handling | `incrementRetry` → marks `failed` after 3 attempts |
| State management | `Provider` (`ChangeNotifier`) |
| Automated tests | 9 tests covering storage, sync, retry & offline→online flow |

---

## 🏗 Architecture

```
lib/
├── main.dart                   # DI wiring, MaterialApp
├── models/
│   └── location_record.dart    # Immutable data class + SyncStatus enum
├── services/
│   ├── location_service.dart   # Simulated GPS stream
│   ├── database_service.dart   # SQLite CRUD
│   ├── api_service.dart        # HTTP POST to mock REST endpoint
│   ├── connectivity_service.dart # connectivity_plus wrapper
│   └── sync_service.dart       # Orchestrates retry & upload logic
├── providers/
│   └── tracking_provider.dart  # ChangeNotifier — single source of truth
├── screens/
│   └── tracking_screen.dart    # Main UI
└── widgets/
    ├── location_card.dart      # Current fix display
    ├── location_list.dart      # Last 20 captures
    ├── stats_row.dart          # Pending / Synced counters
    ├── log_panel.dart          # Activity log
    └── status_badge.dart       # Online / Offline chip
```

### Data Flow

```
LocationService (Stream)
        │
        ▼
TrackingProvider ──► DatabaseService (SQLite INSERT, ConflictAlgorithm.ignore)
        │
        ├─ online?  ──► SyncService.syncPending()
        │                      │
        │               ApiService.uploadRecord()
        │                 ├─ 2xx  ──► markSynced()
        │                 └─ err  ──► incrementRetry() [→ failed after 3×]
        │
ConnectivityService ──► onlineStatusStream ──► auto-trigger syncPending()
```

### Why Provider (not Bloc/Riverpod)?

Provider keeps boilerplate minimal for a 90-minute assessment while still providing:
- Clean separation of UI ↔ business logic
- Fine-grained `context.select<>` rebuilds (no unnecessary widget repaints)
- Easy unit-testability (inject mocks via constructor)

---

## 🚀 Setup & Run

### Prerequisites
- Flutter ≥ 3.19 (`flutter --version`)
- Android SDK 21+ or iOS 12+
- Internet access (for `jsonplaceholder.typicode.com` mock API)

### Steps

```bash
git clone https://github.com/<your-handle>/track_drive.git
cd track_drive
flutter pub get
flutter run
```

The app targets **Android** and **iOS**. Chrome/Desktop work for UI exploration but `connectivity_plus` behaves differently on web.

---

## 🧪 Running Tests

```bash
flutter test
```

Expected output: **9 tests pass** covering:
1. SQLite insert & fetch
2. Duplicate-id rejection
3. `markSynced` status update
4. `clearSyncedRecords` housekeeping
5. `incrementRetry` counter
6. `failed` status after 3 retries
7. Successful sync marks record synced (mocked 201)
8. Failed API call (mocked 500) increments retry
9. Offline → online full round-trip

---

## 📡 Background Tracking on Android & iOS

> **Note:** This app uses simulated GPS. Below is how you would implement *real* continuous background location tracking in production.

### Android

1. **Foreground Service** (required for Android 8+):
   - Declare `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`
   - Add `android:foregroundServiceType="location"` to the service declaration
   - Show a persistent notification so Android doesn't kill the process
   - Use `flutter_foreground_task` or `WorkManager` via a Kotlin plugin

2. **Background execution**:
   - `WorkManager` with `setRequiredNetworkType(NetworkType.CONNECTED)` for sync tasks
   - Request `ACCESS_BACKGROUND_LOCATION` permission on Android 10+

3. **Recommended plugin**: `geolocator` (auto-manages foreground service on Android 8+)

### iOS

1. **Background Modes** in `Info.plist`:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>location</string>
   </array>
   ```
2. **Significant Location Change** API (`startMonitoringSignificantLocationChanges`) — wakes the app even after it's killed; ideal for coarse tracking.
3. **Standard Location Updates** with `allowsBackgroundLocationUpdates = true` for fine-grained (always-on) tracking — requires "Always" permission grant.
4. **Privacy strings** required:
   ```xml
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>TrackDrive needs your location to record your route.</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>TrackDrive needs your location while tracking.</string>
   ```
5. **Recommended plugin**: `geolocator` or `background_locator_2`

### Cross-Platform Sync in Background

- Use `WorkManager` (Android) / `BGTaskScheduler` (iOS) to periodically flush the SQLite queue to the server.
- The `SyncService` in this app is already decoupled from the UI — it can be called from a background isolate or native background task with zero refactoring.

---

## 🎯 Design Decisions

| Decision | Rationale |
|---|---|
| **Simulated GPS** | No location permissions needed; works in emulator/CI |
| **jsonplaceholder** as mock API | Zero setup, always-reachable, responds with 201 |
| **Single SQLite table** | Simple schema; `sync_status` index keeps queries fast |
| **Idempotent inserts** (`ConflictAlgorithm.ignore`) | Same UUID can never produce two DB rows |
| **Max 3 retries** | Prevents infinite loops; failed records visible in UI |
| **`ChangeNotifier` over Bloc** | Lower boilerplate for assessment scope |
| **Services injected via constructors** | Enables full unit testing without mocking framework |

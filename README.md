# TrackDrive

> **Flutter Assessment** — Driver Location Tracking, OpenStreetMap & Offline Synchronisation

A production-quality Flutter application demonstrating real-time GPS tracking, OpenStreetMap / OSRM rendering with live driving polylines, runtime background & foreground permission handling on Android & iOS, offline-first SQLite persistence, and automatic background synchronisation with a mock REST API.

---

## 📋 Table of Contents
- [Features](#features)
- [Architecture](#architecture)
- [OpenStreetMap, Polyline & Live Tracking](#openstreetmap-polyline--live-tracking)
- [Runtime & Background Location Permissions](#runtime--background-location-permissions)
- [Setup & Run](#setup--run)
- [Running Tests](#running-tests)
- [Continuous Background Tracking on Android & iOS](#continuous-background-tracking-on-android--ios)
- [Design Decisions](#design-decisions)

---

## ✅ Features

| Requirement | Implementation |
|---|---|
| **Start / Stop GPS tracking** | Dual-mode tracking via `LocationService` (Real GPS via `geolocator` or Simulated movement stream) |
| **Interactive Map (OSM)** | `flutter_map` (OpenStreetMap / OSRM tiles) with vehicle marker, auto-centering, and zoom controls |
| **Driving Polyline** | Live glowing polyline (`PolylineLayer`) tracing vehicle journey in real-time |
| **Foreground & Background Permissions** | `permission_handler` + `geolocator` requesting `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (Android) and `UIBackgroundModes` (iOS) |
| **Capture location records** | `TrackingProvider` records latitude, longitude, speed, heading, accuracy, and timestamp |
| **Offline local storage** | `DatabaseService` (SQLite via `sqflite`) storing records locally before sync attempt |
| **Auto-sync on reconnect** | `SyncService` monitors network status via `connectivity_plus` and auto-flushes pending queue |
| **Duplicate prevention** | SQLite `PRIMARY KEY (id)` with `ConflictAlgorithm.ignore` ensures strict idempotency |
| **Retry & Failure thresholds** | `incrementRetry` triggers up to 3 times before marking records as `failed` |
| **State management** | Clean `Provider` architecture with selective rebuilds |
| **Automated tests** | 14 automated tests covering storage, sync, retry, deduplication, and UI rendering |

---

## 🗺 OpenStreetMap, Polyline & Live Tracking

- **Map Engine**: Powered by `flutter_map` consuming standard OpenStreetMap tile servers (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
- **Live Polyline**: Every captured location fix appends to `routeHistory`, automatically plotting a dual-layer driving path (glow accent + core line) connecting all historical points.
- **Current Position Marker**: Pulsing radar ripple + vehicle navigation icon pointing along the trajectory.
- **Recenter & Zoom**: Interactive map controls allow zooming and instant re-centering onto the active vehicle position.

---

## 🛡 Runtime & Background Location Permissions

The application requests permissions dynamically following platform security best practices:

### Android
1. **Foreground Location (`ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`)**: Requested on-demand before tracking commences.
2. **Background Location (`ACCESS_BACKGROUND_LOCATION`)**: Android 10+ requires foreground access to be granted first before requesting background access.
3. **Foreground Service (`FOREGROUND_SERVICE_LOCATION`)**: Android 14 requirement configured with `GeolocatorLocationService` in `AndroidManifest.xml` to allow uninterrupted tracking when the screen locks.

### iOS
1. **Usage Descriptions**: Configured in `Info.plist`:
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `NSLocationAlwaysUsageDescription`
2. **Background Modes**: Configured with `location` and `fetch` under `UIBackgroundModes` to prevent OS termination when minimized.

---

## 🏗 Architecture

```
lib/
├── main.dart                   # DI wiring, Provider initialization, MaterialApp
├── models/
│   └── location_record.dart    # Immutable location record & SyncStatus enum
├── services/
│   ├── location_service.dart   # Dual-mode GPS (Real device GPS & Simulated movement)
│   ├── permission_service.dart # Runtime Android & iOS permission manager
│   ├── database_service.dart   # SQLite persistence & retry tracking
│   ├── api_service.dart        # HTTP client uploading to mock REST endpoint
│   ├── connectivity_service.dart # Real-time connectivity monitor
│   └── sync_service.dart       # Offline-to-online orchestrator
├── providers/
│   └── tracking_provider.dart  # ChangeNotifier — single source of truth
├── screens/
│   └── tracking_screen.dart    # Driver dashboard with map & telemetry
└── widgets/
    ├── tracking_map.dart       # FlutterMap with TileLayer, PolylineLayer & MarkerLayer
    ├── location_card.dart      # Real-time coordinates, speed & accuracy
    ├── location_list.dart      # List of recent location fixes
    ├── stats_row.dart          # Pending vs Synced metric badges
    ├── log_panel.dart          # Activity terminal log
    └── status_badge.dart       # Online / Offline chip
```

---

## 🚀 Setup & Run

### Prerequisites
- Flutter ≥ 3.19 (`flutter --version`)
- Android SDK 21+ or iOS 12+
- Internet access (for OSM tiles and `jsonplaceholder.typicode.com` mock API)

### Steps

```bash
cd trackDrive
flutter pub get
flutter run
```

---

## 🧪 Running Tests

```bash
flutter test
```

Expected output: **14 tests pass** covering SQLite storage, idempotency, retry thresholds, API upload mock, offline-to-online transition, and widget smoke tests.

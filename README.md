# TrackDrive

> **Flutter Driver Location Tracking, OpenStreetMap & Offline Synchronisation**

A production-quality Flutter application featuring real hardware GPS tracking, OpenStreetMap / OSRM rendering with live driving polylines, runtime background & foreground permission handling on Android & iOS, offline-first SQLite persistence, and automatic background synchronisation with a REST API.

---

## 📋 Table of Contents
- [Features](#features)
- [Architecture](#architecture)
- [OpenStreetMap, Polyline & Live Tracking](#openstreetmap-polyline--live-tracking)
- [Real GPS & Continuous Background Tracking](#real-gps--continuous-background-tracking)
- [Runtime Permissions & Mandatory Check](#runtime-permissions--mandatory-check)
- [Setup & Run](#setup--run)
- [Running Tests](#running-tests)
- [Design Decisions](#design-decisions)

---

## ✅ Features

| Requirement | Implementation |
|---|---|
| **Start / Stop GPS tracking** | Real hardware GPS position stream via `geolocator` with high accuracy and foreground service notification |
| **Interactive Map (OSM)** | `flutter_map` (OpenStreetMap / OSRM tiles) with vehicle marker, auto-centering, and zoom controls |
| **Driving Polyline** | Live glowing polyline (`PolylineLayer`) tracing real-time vehicle movement |
| **Auto Permission Check on Open** | Automatically checks & requests foreground and background location permissions on launch; displays blocking screen if denied |
| **Continuous Background Tracking** | Android Foreground Service (`GeolocatorLocationService`) and iOS `location` background modes |
| **Capture location records** | `TrackingProvider` records real latitude, longitude, speed, heading, accuracy, and timestamp |
| **Offline local storage** | `DatabaseService` (SQLite via `sqflite`) storing records locally before sync attempt |
| **Auto-sync on reconnect** | `SyncService` monitors network status via `connectivity_plus` and auto-flushes pending queue |
| **Duplicate prevention** | SQLite `PRIMARY KEY (id)` with `ConflictAlgorithm.ignore` ensures strict idempotency |
| **Retry & Failure thresholds** | `incrementRetry` triggers up to 3 times before marking records as `failed` |
| **State management** | Clean `Provider` architecture with selective rebuilds |
| **Automated tests** | 15 automated tests covering storage, sync, retry, deduplication, and UI rendering |

---

## 🗺 OpenStreetMap, Polyline & Live Tracking

- **Map Engine**: Powered by `flutter_map` consuming standard OpenStreetMap tile servers (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
- **Live Polyline**: Every captured real location fix appends to `routeHistory`, automatically plotting a dual-layer driving path (glow accent + core line) connecting all historical points.
- **Current Position Marker**: Pulsing radar wave + vehicle navigation icon pointing along the trajectory.
- **Recenter & Zoom**: Interactive map controls allow zooming and instant re-centering onto the active vehicle position.

---

## 🛰 Real GPS & Continuous Background Tracking

- **GPS Hardware Engine**: Direct stream from device GPS via `Geolocator.getPositionStream(locationSettings: ...)`.
- **Android Foreground Service**: Configured with `ForegroundNotificationConfig` on Android (`enableWakeLock: true`) so the OS doesn't sleep the GPS when the device is locked or minimized.
- **iOS Background Updates**: Configured with `showBackgroundLocationIndicator: true` and `pauseLocationUpdatesAutomatically: false`.

---

## 🛡 Runtime Permissions & Mandatory Check

1. **Auto-check on App Open**: Proactively triggers `autoCheckAndRequestOnOpen()` on launch.
2. **Permission Gated Access**: If location access is denied, a mandatory **"Location Permission Required"** view blocks the dashboard and explains why location is necessary to continue.
3. **App Settings Redirect**: If permission is permanently denied, a direct **"Open App Settings"** action button is provided.

---

## 🏗 Architecture

```
lib/
├── main.dart                   # DI wiring, Provider initialization, MaterialApp
├── models/
│   └── location_record.dart    # Immutable location record & SyncStatus enum
├── services/
│   ├── location_service.dart   # Real device hardware GPS stream via Geolocator
│   ├── permission_service.dart # Runtime Android & iOS permission manager
│   ├── database_service.dart   # SQLite persistence & retry tracking
│   ├── api_service.dart        # HTTP client uploading to REST endpoint
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
    ├── permission_required_view.dart # Mandatory permission blocking screen
    └── status_badge.dart       # Online / Offline chip
```

---

## 🚀 Setup & Run

### Prerequisites
- Flutter ≥ 3.19 (`flutter --version`)
- Android SDK 21+ or iOS 12+
- Physical device or emulator with location services enabled

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

Expected output: **15 tests pass** covering SQLite storage, idempotency, retry thresholds, API upload mock, offline-to-online transition, and widget verification.

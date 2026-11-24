import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/location_record.dart';

/// Provides real GPS position updates from device hardware via [Geolocator].
///
/// Configured for continuous tracking:
/// - Android: High accuracy + Foreground notification service for background tracking.
/// - iOS: High accuracy + Background location indicator.
class LocationService {
  final _uuid = const Uuid();

  StreamController<LocationRecord>? _controller;
  StreamSubscription<Position>? _gpsSubscription;

  bool get isTracking => _gpsSubscription != null;

  /// Check whether hardware GPS / location services are turned on on the device.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Direct the user to enable device GPS if switched off.
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  /// Streams real [LocationRecord] updates directly from device GPS hardware.
  Stream<LocationRecord> startTracking() {
    if (_controller != null && !_controller!.isClosed) {
      return _controller!.stream;
    }

    _controller = StreamController<LocationRecord>.broadcast();
    _startGpsStream();

    return _controller!.stream;
  }

  Future<void> _startGpsStream() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        if (_controller != null && !_controller!.isClosed) {
          _controller!.addError(
            const LocationServiceDisabledException(),
          );
        }
        return;
      }

      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // Emits update every 3 meters of movement
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'TrackDrive Active',
            notificationText: 'Real-time GPS tracking active in background',
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        );
      }

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          if (_controller == null || _controller!.isClosed) return;

          final record = LocationRecord(
            id: _uuid.v4(),
            latitude: double.parse(pos.latitude.toStringAsFixed(6)),
            longitude: double.parse(pos.longitude.toStringAsFixed(6)),
            accuracy: double.parse(pos.accuracy.toStringAsFixed(1)),
            speed: double.parse(pos.speed.clamp(0, 100).toStringAsFixed(2)),
            timestamp: pos.timestamp,
          );
          _controller!.add(record);
        },
        onError: (err) {
          if (_controller != null && !_controller!.isClosed) {
            _controller!.addError(err);
          }
        },
      );
    } catch (e) {
      if (_controller != null && !_controller!.isClosed) {
        _controller!.addError(e);
      }
    }
  }

  void stopTracking() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _controller?.close();
    _controller = null;
  }
}

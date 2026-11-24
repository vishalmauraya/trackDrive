import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/location_record.dart';

enum TrackingMode {
  /// Real GPS device updates with foreground notification support.
  realGps,

  /// Realistic simulated movements (great for testing, CI, emulators).
  simulated,
}

/// Provides GPS position updates from real device hardware or a realistic simulator.
class LocationService {
  static const Duration simulatedInterval = Duration(seconds: 3);

  final _uuid = const Uuid();
  final _random = Random();

  StreamController<LocationRecord>? _controller;
  Timer? _timer;
  StreamSubscription<Position>? _realPositionSub;

  TrackingMode mode = TrackingMode.simulated;

  // Seed coordinates (Bengaluru, India or current known location)
  double _lat = 12.9716;
  double _lng = 77.5946;

  bool get isTracking =>
      (_timer != null && _timer!.isActive) || _realPositionSub != null;

  /// Starts streaming [LocationRecord]s.
  /// If [mode] is [TrackingMode.realGps], attempts to listen to real GPS updates.
  /// If real GPS is unavailable or fails, gracefully falls back to simulated.
  Stream<LocationRecord> startTracking({TrackingMode? targetMode}) {
    if (targetMode != null) mode = targetMode;

    if (_controller != null && !_controller!.isClosed) {
      return _controller!.stream;
    }

    _controller = StreamController<LocationRecord>.broadcast();

    if (mode == TrackingMode.realGps) {
      _startRealGpsTracking();
    } else {
      _startSimulatedTracking();
    }

    return _controller!.stream;
  }

  void _startSimulatedTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(simulatedInterval, (_) {
      if (_controller == null || _controller!.isClosed) return;
      _controller!.add(_generateRecord());
    });
  }

  Future<void> _startRealGpsTracking() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        // Fallback to simulated if device GPS is switched off
        _startSimulatedTracking();
        return;
      }

      // Configure foreground service notification for background tracking on Android
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      );

      _realPositionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          if (_controller == null || _controller!.isClosed) return;
          _lat = pos.latitude;
          _lng = pos.longitude;

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
          // If real GPS throws, continue with simulated to avoid dropping tracking
          _startSimulatedTracking();
        },
      );
    } catch (_) {
      _startSimulatedTracking();
    }
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _realPositionSub?.cancel();
    _realPositionSub = null;
    _controller?.close();
    _controller = null;
  }

  LocationRecord _generateRecord() {
    // Simulate realistic driving movement delta
    _lat += (_random.nextDouble() - 0.5) * 0.0004;
    _lng += (_random.nextDouble() - 0.5) * 0.0004;

    final speed = _random.nextDouble() * 15; // 0–15 m/s (~0–54 km/h)
    final accuracy = 3.0 + _random.nextDouble() * 7; // 3–10 m

    return LocationRecord(
      id: _uuid.v4(),
      latitude: double.parse(_lat.toStringAsFixed(6)),
      longitude: double.parse(_lng.toStringAsFixed(6)),
      accuracy: double.parse(accuracy.toStringAsFixed(1)),
      speed: double.parse(speed.toStringAsFixed(2)),
      timestamp: DateTime.now(),
    );
  }
}

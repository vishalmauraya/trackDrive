import 'dart:async';
import 'dart:math';
import '../models/location_record.dart';
import 'package:uuid/uuid.dart';

/// Simulates GPS hardware updates.
///
/// In a real app this would use `geolocator` or `location` package
/// to request OS permissions and stream [Position] objects.
/// Here we emit realistic-looking coordinate shifts every [interval].
class LocationService {
  static const Duration interval = Duration(seconds: 3);

  final _uuid = const Uuid();
  final _random = Random();

  StreamController<LocationRecord>? _controller;
  Timer? _timer;

  // Seed coordinates (Bengaluru, India)
  double _lat = 12.9716;
  double _lng = 77.5946;

  bool get isTracking => _timer != null && !(_timer!.isActive == false);

  /// Returns a broadcast stream of [LocationRecord].
  /// Calling [startTracking] when already tracking is a no-op.
  Stream<LocationRecord> startTracking() {
    if (_controller != null && !_controller!.isClosed) {
      return _controller!.stream;
    }

    _controller = StreamController<LocationRecord>.broadcast();

    _timer = Timer.periodic(interval, (_) {
      if (_controller == null || _controller!.isClosed) return;
      _controller!.add(_generateRecord());
    });

    return _controller!.stream;
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }

  LocationRecord _generateRecord() {
    // Simulate small movement deltas (≈ 0–50 m per tick).
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

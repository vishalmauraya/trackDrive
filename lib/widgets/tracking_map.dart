import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_record.dart';

/// Interactive OpenStreetMap widget showing:
/// - Real-time map tiles (OSM / OSRM compatible)
/// - Driving polyline route history
/// - Live vehicle location marker with pulsing ripple
/// - Quick recenter button
class TrackingMap extends StatefulWidget {
  final LocationRecord? latestRecord;
  final List<LocationRecord> records;

  const TrackingMap({
    super.key,
    required this.latestRecord,
    required this.records,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  final MapController _mapController = MapController();
  bool _autoCenter = true;

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoCenter && widget.latestRecord != null) {
      final newPos = LatLng(
        widget.latestRecord!.latitude,
        widget.latestRecord!.longitude,
      );
      _mapController.move(newPos, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default center to Bengaluru if no records yet
    final center = widget.latestRecord != null
        ? LatLng(widget.latestRecord!.latitude, widget.latestRecord!.longitude)
        : const LatLng(12.9716, 77.5946);

    // Build polyline points in chronological order (earliest to latest)
    final polylinePoints = widget.records.reversed
        .map((r) => LatLng(r.latitude, r.longitude))
        .toList();

    return Container(
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00C896).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _autoCenter) {
                  setState(() => _autoCenter = false);
                }
              },
            ),
            children: [
              // 1. OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trackdrive.track_drive',
                tileBuilder: (context, tileWidget, tile) {
                  // Dark mode tint over OSM tiles for consistent dark theme
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, -40,
                      0.33, 0.33, 0.33, 0, -40,
                      0.33, 0.33, 0.33, 0, -40,
                      0,    0,    0,    1,   0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),

              // 2. Polyline driving path
              if (polylinePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    // Glow border
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 6.0,
                      color: const Color(0xFF00C896).withValues(alpha: 0.4),
                    ),
                    // Core line
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 3.5,
                      color: const Color(0xFF00C896),
                    ),
                  ],
                ),

              // 3. Current vehicle marker
              if (widget.latestRecord != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: _VehicleMarker(record: widget.latestRecord!),
                    ),
                  ],
                ),
            ],
          ),

          // Recenter / Map controls overlay
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_btn',
                  backgroundColor: _autoCenter
                      ? const Color(0xFF00C896)
                      : const Color(0xFF1A2635),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    setState(() => _autoCenter = true);
                    _mapController.move(center, 16.0);
                  },
                  child: Icon(
                    _autoCenter ? Icons.my_location : Icons.location_searching,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in_btn',
                  backgroundColor: const Color(0xFF1A2635),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add, size: 18),
                ),
                const SizedBox(height: 4),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_btn',
                  backgroundColor: const Color(0xFF1A2635),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove, size: 18),
                ),
              ],
            ),
          ),

          // Route statistics badge overlay
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1923).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, color: Color(0xFF00C896), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${polylinePoints.length} points plotted',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  final LocationRecord record;

  const _VehicleMarker({required this.record});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background ring
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00C896).withValues(alpha: 0.25),
          ),
        ),
        // Inner circle with vehicle icon
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00C896),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation,
            color: Colors.white,
            size: 16,
          ),
        ),
      ],
    );
  }
}

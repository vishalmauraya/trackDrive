import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/location_card.dart';
import '../widgets/stats_row.dart';
import '../widgets/log_panel.dart';
import '../widgets/location_list.dart';
import '../widgets/tracking_map.dart';
import '../widgets/permission_required_view.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2635),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.directions_car, color: Color(0xFF00C896), size: 24),
            SizedBox(width: 10),
            Text(
              'TrackDrive',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: const [_ConnectivityBadge()],
      ),
      body: Consumer<TrackingProvider>(
        builder: (context, provider, _) {
          // If permission auto-check ran and location was denied, show blocking permission view
          if (provider.isLocationPermissionRequired) {
            return PermissionRequiredView(provider: provider);
          }
          return const _Body();
        },
      ),
    );
  }
}

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge();

  @override
  Widget build(BuildContext context) {
    final isOnline = context.select<TrackingProvider, bool>((p) => p.isOnline);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: StatusBadge(
        label: isOnline ? 'ONLINE' : 'OFFLINE',
        color: isOnline ? const Color(0xFF00C896) : Colors.orangeAccent,
        icon: isOnline ? Icons.wifi : Icons.wifi_off,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Real GPS & Permission Status Bar ──────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => _GpsStatusBar(provider: p),
          ),
          const SizedBox(height: 16),

          // ── Interactive Map (OSM + Polyline + Current Location) ───────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => TrackingMap(
              latestRecord: p.latestRecord,
              records: p.routeHistory,
            ),
          ),
          const SizedBox(height: 16),

          // ── Current location card ────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => LocationCard(record: p.latestRecord),
          ),
          const SizedBox(height: 16),

          // ── Stats ────────────────────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => StatsRow(
              pendingCount: p.pendingCount,
              syncedCount: p.syncedCount,
            ),
          ),
          const SizedBox(height: 20),

          // ── Control buttons ──────────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => _ControlButtons(provider: p),
          ),
          const SizedBox(height: 20),

          // ── Recent locations ─────────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) =>
                LocationList(records: p.recentRecords),
          ),
          const SizedBox(height: 20),

          // ── Log panel ────────────────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => LogPanel(logs: p.logs),
          ),
        ],
      ),
    );
  }
}

class _GpsStatusBar extends StatelessWidget {
  final TrackingProvider provider;

  const _GpsStatusBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2635),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.satellite_alt, color: Color(0xFF00C896), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Source: Live Device GPS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'HIGH ACCURACY',
                  style: TextStyle(
                    color: Color(0xFF00C896),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white10),
          Row(
            children: [
              Icon(
                provider.hasBackgroundPermission
                    ? Icons.security
                    : (provider.hasForegroundPermission
                        ? Icons.lock_open
                        : Icons.lock),
                size: 14,
                color: provider.hasBackgroundPermission
                    ? const Color(0xFF00C896)
                    : (provider.hasForegroundPermission
                        ? Colors.orangeAccent
                        : Colors.white38),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  provider.hasBackgroundPermission
                      ? 'Background Location Granted'
                      : (provider.hasForegroundPermission
                          ? 'Foreground Only (Allow All-time in Settings)'
                          : 'Location Permissions Required'),
                  style: TextStyle(
                    color: provider.hasBackgroundPermission
                        ? const Color(0xFF00C896)
                        : (provider.hasForegroundPermission
                            ? Colors.orangeAccent
                            : Colors.white54),
                    fontSize: 11,
                  ),
                ),
              ),
              if (!provider.hasBackgroundPermission)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: provider.requestPermissions,
                  child: const Text(
                    'Grant',
                    style: TextStyle(
                      color: Color(0xFF4A9EFF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final TrackingProvider provider;

  const _ControlButtons({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: provider.isTracking ? 'Stop Tracking' : 'Start Tracking',
                icon: provider.isTracking ? Icons.stop_circle : Icons.play_circle,
                color: provider.isTracking
                    ? Colors.redAccent
                    : const Color(0xFF00C896),
                onPressed: provider.isTracking
                    ? provider.stopTracking
                    : provider.startTracking,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: provider.isSyncing ? 'Syncing…' : 'Sync Now',
                icon: Icons.cloud_upload_outlined,
                color: const Color(0xFF4A9EFF),
                onPressed: provider.isSyncing ? null : provider.manualSync,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: provider.clearSynced,
            icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.grey),
            label: const Text(
              'Clear synced',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey.shade800 : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

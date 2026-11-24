import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracking_provider.dart';
import '../services/location_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/location_card.dart';
import '../widgets/stats_row.dart';
import '../widgets/log_panel.dart';
import '../widgets/location_list.dart';
import '../widgets/tracking_map.dart';

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
      body: const _Body(),
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
          // ── Mode & Permission Bar ─────────────────────────────────────────
          Consumer<TrackingProvider>(
            builder: (_, p, __) => _PermissionAndModeBar(provider: p),
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

class _PermissionAndModeBar extends StatelessWidget {
  final TrackingProvider provider;

  const _PermissionAndModeBar({required this.provider});

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
              const Icon(Icons.tune, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Mode:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _ModeChip(
                label: 'Simulated',
                icon: Icons.alt_route,
                isSelected: provider.trackingMode == TrackingMode.simulated,
                onTap: () => provider.setTrackingMode(TrackingMode.simulated),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: 'Real GPS',
                icon: Icons.gps_fixed,
                isSelected: provider.trackingMode == TrackingMode.realGps,
                onTap: () => provider.setTrackingMode(TrackingMode.realGps),
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

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C896).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C896) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF00C896) : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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

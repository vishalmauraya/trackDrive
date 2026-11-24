import 'package:flutter/material.dart';
import '../models/location_record.dart';

class LocationCard extends StatelessWidget {
  final LocationRecord? record;

  const LocationCard({super.key, this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2635),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: record != null
              ? const Color(0xFF00C896).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: record == null
          ? const _EmptyState()
          : _RecordDetails(record: record!),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.location_off, color: Colors.white38, size: 48),
        SizedBox(height: 10),
        Text(
          'No location captured yet.\nPress Start Tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }
}

class _RecordDetails extends StatelessWidget {
  final LocationRecord record;

  const _RecordDetails({required this.record});

  @override
  Widget build(BuildContext context) {
    final speedKmh = (record.speed * 3.6).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF00C896), size: 20),
            const SizedBox(width: 6),
            Text(
              'Current Location',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            _SyncChip(status: record.syncStatus),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'LATITUDE',
                value: record.latitude.toStringAsFixed(5),
                icon: Icons.my_location,
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'LONGITUDE',
                value: record.longitude.toStringAsFixed(5),
                icon: Icons.explore,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'SPEED',
                value: '$speedKmh km/h',
                icon: Icons.speed,
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'ACCURACY',
                value: '±${record.accuracy.toStringAsFixed(1)} m',
                icon: Icons.radar,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          record.timestamp.toLocal().toString().substring(0, 19),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SyncChip extends StatelessWidget {
  final SyncStatus status;

  const _SyncChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SyncStatus.synced => ('SYNCED', const Color(0xFF00C896)),
      SyncStatus.pending => ('PENDING', Colors.orangeAccent),
      SyncStatus.failed => ('FAILED', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

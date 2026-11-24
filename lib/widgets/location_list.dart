import 'package:flutter/material.dart';
import '../models/location_record.dart';

class LocationList extends StatelessWidget {
  final List<LocationRecord> records;

  const LocationList({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'RECENT CAPTURES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2635),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: records.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white10),
            itemBuilder: (_, i) => _RecordTile(record: records[i]),
          ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final LocationRecord record;

  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = switch (record.syncStatus) {
      SyncStatus.synced => const Color(0xFF00C896),
      SyncStatus.pending => Colors.orangeAccent,
      SyncStatus.failed => Colors.redAccent,
    };

    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
      title: Text(
        '${record.latitude.toStringAsFixed(5)}, '
        '${record.longitude.toStringAsFixed(5)}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      subtitle: Text(
        record.timestamp.toLocal().toString().substring(11, 19),
        style: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
      trailing: Text(
        '${(record.speed * 3.6).toStringAsFixed(1)} km/h',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }
}

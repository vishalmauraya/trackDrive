/// Represents a single GPS location capture.
class LocationRecord {
  final String id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; // m/s
  final DateTime timestamp;
  final SyncStatus syncStatus;
  final int retryCount;

  const LocationRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
  });

  LocationRecord copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    DateTime? timestamp,
    SyncStatus? syncStatus,
    int? retryCount,
  }) {
    return LocationRecord(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Convert to a map for SQLite storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'sync_status': syncStatus.name,
      'retry_count': retryCount,
    };
  }

  /// Create from SQLite row map.
  factory LocationRecord.fromMap(Map<String, dynamic> map) {
    return LocationRecord(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      syncStatus: SyncStatus.values.byName(map['sync_status'] as String),
      retryCount: (map['retry_count'] as int?) ?? 0,
    );
  }

  /// Payload sent to the REST API.
  Map<String, dynamic> toApiPayload() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'LocationRecord(id: $id, lat: $latitude, lng: $longitude, '
      'status: ${syncStatus.name})';
}

enum SyncStatus {
  /// Waiting to be uploaded (offline or not yet attempted).
  pending,

  /// Successfully uploaded to the server.
  synced,

  /// Permanently failed after [maxRetries] attempts.
  failed,
}

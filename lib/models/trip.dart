class Trip {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double startBatterySoc;
  final double endBatterySoc;
  final double energyConsumedWh;
  final double startLat;
  final double startLng;
  final double? endLat;
  final double? endLng;
  final bool isActive;

  const Trip({
    required this.id,
    required this.startTime,
    this.endTime,
    this.totalDistanceKm = 0.0,
    this.avgSpeedKmh = 0.0,
    this.maxSpeedKmh = 0.0,
    this.startBatterySoc = 0.0,
    this.endBatterySoc = 0.0,
    this.energyConsumedWh = 0.0,
    this.startLat = 0.0,
    this.startLng = 0.0,
    this.endLat,
    this.endLng,
    this.isActive = false,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationFormatted {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  double get batteryUsed => startBatterySoc - endBatterySoc;

  String get distanceFormatted {
    if (totalDistanceKm >= 1.0) {
      return '${totalDistanceKm.toStringAsFixed(1)} km';
    }
    return '${(totalDistanceKm * 1000).toStringAsFixed(0)} m';
  }

  Trip copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistanceKm,
    double? avgSpeedKmh,
    double? maxSpeedKmh,
    double? startBatterySoc,
    double? endBatterySoc,
    double? energyConsumedWh,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    bool? isActive,
  }) {
    return Trip(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      startBatterySoc: startBatterySoc ?? this.startBatterySoc,
      endBatterySoc: endBatterySoc ?? this.endBatterySoc,
      energyConsumedWh: energyConsumedWh ?? this.energyConsumedWh,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'totalDistanceKm': totalDistanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'startBatterySoc': startBatterySoc,
      'endBatterySoc': endBatterySoc,
      'energyConsumedWh': energyConsumedWh,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
          : null,
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (map['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      startBatterySoc: (map['startBatterySoc'] as num?)?.toDouble() ?? 0.0,
      endBatterySoc: (map['endBatterySoc'] as num?)?.toDouble() ?? 0.0,
      energyConsumedWh: (map['energyConsumedWh'] as num?)?.toDouble() ?? 0.0,
      startLat: (map['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (map['startLng'] as num?)?.toDouble() ?? 0.0,
      endLat: (map['endLat'] as num?)?.toDouble(),
      endLng: (map['endLng'] as num?)?.toDouble(),
      isActive: (map['isActive'] as int?) == 1,
    );
  }
}

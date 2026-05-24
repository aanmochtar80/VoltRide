class TripPoint {
  final String id;
  final String tripId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final double batteryVoltage;
  final double batteryCurrent;
  final double batterySoc;
  final double powerWatt;
  final double temperature;
  final DateTime timestamp;

  const TripPoint({
    required this.id,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    this.accuracy = 0.0,
    this.batteryVoltage = 0.0,
    this.batteryCurrent = 0.0,
    this.batterySoc = 0.0,
    this.powerWatt = 0.0,
    this.temperature = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speedKmh': speedKmh,
      'heading': heading,
      'accuracy': accuracy,
      'batteryVoltage': batteryVoltage,
      'batteryCurrent': batteryCurrent,
      'batterySoc': batterySoc,
      'powerWatt': powerWatt,
      'temperature': temperature,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TripPoint.fromMap(Map<String, dynamic> map) {
    return TripPoint(
      id: map['id'] as String,
      tripId: map['tripId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (map['speedKmh'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      batteryVoltage: (map['batteryVoltage'] as num?)?.toDouble() ?? 0.0,
      batteryCurrent: (map['batteryCurrent'] as num?)?.toDouble() ?? 0.0,
      batterySoc: (map['batterySoc'] as num?)?.toDouble() ?? 0.0,
      powerWatt: (map['powerWatt'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

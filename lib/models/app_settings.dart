class AppSettings {
  final int gpsIntervalMs;
  final int blePollingIntervalMs;
  final bool useMetric;
  final bool autoStartTrip;
  final bool autoStopTrip;
  final String? lastConnectedDeviceId;
  final String? lastConnectedDeviceName;

  const AppSettings({
    this.gpsIntervalMs = 1000,
    this.blePollingIntervalMs = 1000,
    this.useMetric = true,
    this.autoStartTrip = false,
    this.autoStopTrip = true,
    this.lastConnectedDeviceId,
    this.lastConnectedDeviceName,
  });

  String get speedUnit => useMetric ? 'km/h' : 'mph';
  String get distanceUnit => useMetric ? 'km' : 'mi';

  double convertSpeed(double kmh) => useMetric ? kmh : kmh * 0.621371;
  double convertDistance(double km) => useMetric ? km : km * 0.621371;

  AppSettings copyWith({
    int? gpsIntervalMs,
    int? blePollingIntervalMs,
    bool? useMetric,
    bool? autoStartTrip,
    bool? autoStopTrip,
    String? lastConnectedDeviceId,
    String? lastConnectedDeviceName,
  }) {
    return AppSettings(
      gpsIntervalMs: gpsIntervalMs ?? this.gpsIntervalMs,
      blePollingIntervalMs: blePollingIntervalMs ?? this.blePollingIntervalMs,
      useMetric: useMetric ?? this.useMetric,
      autoStartTrip: autoStartTrip ?? this.autoStartTrip,
      autoStopTrip: autoStopTrip ?? this.autoStopTrip,
      lastConnectedDeviceId: lastConnectedDeviceId ?? this.lastConnectedDeviceId,
      lastConnectedDeviceName: lastConnectedDeviceName ?? this.lastConnectedDeviceName,
    );
  }
}

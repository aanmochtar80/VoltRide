class AppConstants {
  // App info
  static const String appName = 'VoltRide';
  static const String appVersion = '1.0.0';

  // GPS Settings
  static const int defaultGpsIntervalMs = 1000;
  static const double defaultDistanceFilter = 5.0; // meters
  static const double autoStartSpeedKmh = 5.0;
  static const int autoStopIdleMinutes = 5;

  // BLE Settings
  static const int defaultBlePollingIntervalMs = 1000;
  static const int bleConnectionTimeoutSeconds = 10;
  static const int bleAutoReconnectDelaySeconds = 3;

  // JK-BMS UUIDs
  static const String jkBmsServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String jkBmsCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // JK-BMS Protocol
  static const int jkBmsFrameHeader = 0x4E57;
  static const int jkBmsReadAll = 0x06;

  // Database
  static const int dbBatchInsertSize = 50;
  static const String dbName = 'voltride.db';

  // Map
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const double defaultMapZoom = 16.0;
  static const double defaultLat = -6.2088;
  static const double defaultLng = 106.8456;

  // Trip recording interval
  static const int tripRecordIntervalMs = 1000;

  // UI
  static const double cardBorderRadius = 20.0;
  static const double speedometerSize = 260.0;
}

class PrefsKeys {
  static const String gpsInterval = 'gps_interval';
  static const String blePollingInterval = 'ble_polling_interval';
  static const String useMetric = 'use_metric';
  static const String autoStartTrip = 'auto_start_trip';
  static const String autoStopTrip = 'auto_stop_trip';
  static const String lastConnectedDevice = 'last_connected_device';
}

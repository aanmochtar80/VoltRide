import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltride/database/app_database.dart';
import 'package:voltride/models/app_settings.dart';
import 'package:voltride/models/bms_data.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/models/trip_point.dart';
import 'package:voltride/services/ble_service.dart';
import 'package:voltride/services/gps_service.dart';
import 'package:voltride/services/jk_bms_service.dart';
import 'package:voltride/services/trip_service.dart';

// ── Database ──
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// ── GPS Service ──
final gpsServiceProvider = Provider<GpsService>((ref) {
  final service = GpsService();
  ref.onDispose(() => service.dispose());
  return service;
});

final gpsStreamProvider = StreamProvider<GpsData>((ref) {
  final gpsService = ref.watch(gpsServiceProvider);
  return gpsService.positionStream;
});

final currentSpeedProvider = Provider<double>((ref) {
  final gpsAsync = ref.watch(gpsStreamProvider);
  return gpsAsync.maybeWhen(
    data: (data) => data.speedKmh,
    orElse: () => 0.0,
  );
});

final currentPositionProvider = Provider<GpsData?>((ref) {
  final gpsAsync = ref.watch(gpsStreamProvider);
  return gpsAsync.maybeWhen(
    data: (data) => data,
    orElse: () => null,
  );
});

// ── BLE Service ──
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

final bleConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.connectionStateStream;
});

// ── JK-BMS Service ──
final jkBmsServiceProvider = Provider<JkBmsService>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final service = JkBmsService(bleService);
  ref.onDispose(() => service.dispose());
  return service;
});

final bmsDataStreamProvider = StreamProvider<BmsData>((ref) {
  final bmsService = ref.watch(jkBmsServiceProvider);
  return bmsService.bmsDataStream;
});

final currentBmsDataProvider = Provider<BmsData>((ref) {
  final bmsAsync = ref.watch(bmsDataStreamProvider);
  return bmsAsync.maybeWhen(
    data: (data) => data,
    orElse: () => BmsData.empty(),
  );
});

// ── Trip Service ──
final tripServiceProvider = Provider<TripService>((ref) {
  final db = ref.watch(databaseProvider);
  final gps = ref.watch(gpsServiceProvider);
  final service = TripService(db, gps, () => ref.read(currentBmsDataProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

final activeTripStreamProvider = StreamProvider<Trip?>((ref) {
  final tripService = ref.watch(tripServiceProvider);
  return tripService.tripStateStream;
});

final activeTripProvider = Provider<Trip?>((ref) {
  final activeTripAsync = ref.watch(activeTripStreamProvider);
  return activeTripAsync.maybeWhen(
    data: (trip) => trip,
    orElse: () => ref.read(tripServiceProvider).activeTrip,
  );
});

final isRecordingProvider = Provider<bool>((ref) {
  return ref.watch(activeTripProvider) != null;
});

// ── Trip History ──
final tripHistoryProvider = FutureProvider<List<Trip>>((ref) async {
  final tripService = ref.watch(tripServiceProvider);
  return tripService.getAllTrips();
});

final tripPointsProvider =
    FutureProvider.family<List<TripPoint>, String>((ref, tripId) async {
  final tripService = ref.watch(tripServiceProvider);
  return tripService.getTripPoints(tripId);
});

final selectedTripProvider = StateProvider<Trip?>((ref) => null);

// ── Settings ──
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setGpsInterval(int ms) {
    state = state.copyWith(gpsIntervalMs: ms);
  }

  void setBlePollingInterval(int ms) {
    state = state.copyWith(blePollingIntervalMs: ms);
  }

  void setUseMetric(bool value) {
    state = state.copyWith(useMetric: value);
  }

  void setAutoStartTrip(bool value) {
    state = state.copyWith(autoStartTrip: value);
  }

  void setAutoStopTrip(bool value) {
    state = state.copyWith(autoStopTrip: value);
  }

  void setLastConnectedDevice(String? id, String? name) {
    state = state.copyWith(
      lastConnectedDeviceId: id,
      lastConnectedDeviceName: name,
    );
  }
}

// ── Navigation ──
final currentPageIndexProvider = StateProvider<int>((ref) => 0);

// ── Track Points for current trip (for map polyline) ──
final currentTripPointsProvider = StateProvider<List<TripPoint>>((ref) => []);

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:voltride/database/app_database.dart';
import 'package:voltride/models/bms_data.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/models/trip_point.dart';
import 'package:voltride/services/gps_service.dart';

class TripService {
  final AppDatabase _database;
  final GpsService _gpsService;
  final _uuid = const Uuid();

  Trip? _activeTrip;
  final List<TripPoint> _pointBuffer = [];
  StreamSubscription<GpsData>? _gpsSubscription;
  Timer? _autoStopTimer;
  DateTime? _lastMovementTime;

  double _totalDistance = 0;
  double _maxSpeed = 0;
  double _speedSum = 0;
  int _speedCount = 0;
  double _lastLat = 0;
  double _lastLng = 0;

  final _tripStateController = StreamController<Trip?>.broadcast();
  Stream<Trip?> get tripStateStream => _tripStateController.stream;
  Trip? get activeTrip => _activeTrip;
  bool get isRecording => _activeTrip != null;

  final BmsData Function()? _getBmsData;

  TripService(this._database, this._gpsService, [this._getBmsData]);

  Future<Trip> startTrip({
    required double latitude,
    required double longitude,
    double batterySoc = 0,
  }) async {
    if (_activeTrip != null) {
      throw Exception('A trip is already active');
    }

    final trip = Trip(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      startLat: latitude,
      startLng: longitude,
      startBatterySoc: batterySoc,
      isActive: true,
    );

    await _database.insertTrip(trip);
    _activeTrip = trip;
    _totalDistance = 0;
    _maxSpeed = 0;
    _speedSum = 0;
    _speedCount = 0;
    _lastLat = latitude;
    _lastLng = longitude;
    _lastMovementTime = DateTime.now();
    _pointBuffer.clear();

    // Start listening to GPS
    _gpsSubscription?.cancel();
    _gpsSubscription = _gpsService.positionStream.listen(_onGpsData);

    _tripStateController.add(_activeTrip);
    return trip;
  }

  void _onGpsData(GpsData gps, {BmsData? bmsData}) {
    if (_activeTrip == null) return;

    final activeBmsData = bmsData ?? _getBmsData?.call();

    // Calculate distance from last point
    final distance = _calculateDistance(
      _lastLat, _lastLng,
      gps.latitude, gps.longitude,
    );

    if (distance > 0.001) { // > 1 meter
      _totalDistance += distance;
      _lastLat = gps.latitude;
      _lastLng = gps.longitude;
    }

    // Track speed
    if (gps.speedKmh > 0.5) {
      _speedSum += gps.speedKmh;
      _speedCount++;
      _lastMovementTime = DateTime.now();
    }
    if (gps.speedKmh > _maxSpeed) {
      _maxSpeed = gps.speedKmh;
    }

    // Create trip point
    final point = TripPoint(
      id: _uuid.v4(),
      tripId: _activeTrip!.id,
      latitude: gps.latitude,
      longitude: gps.longitude,
      altitude: gps.altitude,
      speedKmh: gps.speedKmh,
      heading: gps.heading,
      accuracy: gps.accuracy,
      batteryVoltage: activeBmsData?.voltageTotal ?? 0,
      batteryCurrent: activeBmsData?.current ?? 0,
      batterySoc: activeBmsData?.soc ?? 0,
      powerWatt: activeBmsData?.powerWatt ?? 0,
      temperature: activeBmsData?.avgTemperature ?? 0,
      timestamp: gps.timestamp,
    );

    _pointBuffer.add(point);

    // Batch insert when buffer is full
    if (_pointBuffer.length >= 10) {
      _flushBuffer();
    }

    // Update active trip
    _activeTrip = _activeTrip!.copyWith(
      totalDistanceKm: _totalDistance,
      maxSpeedKmh: _maxSpeed,
      avgSpeedKmh: _speedCount > 0 ? _speedSum / _speedCount : 0,
    );
    _tripStateController.add(_activeTrip);
  }

  /// Add a data point with BMS data
  void addDataPoint(GpsData gps, BmsData? bmsData) {
    _onGpsData(gps, bmsData: bmsData);
  }

  Future<void> _flushBuffer() async {
    if (_pointBuffer.isEmpty) return;
    final points = List<TripPoint>.from(_pointBuffer);
    _pointBuffer.clear();

    try {
      await _database.insertTripPointsBatch(points);
    } catch (e) {
      debugPrint('Trip buffer flush error: $e');
    }
  }

  Future<Trip?> stopTrip({double endBatterySoc = 0}) async {
    if (_activeTrip == null) return null;

    await _flushBuffer();
    _gpsSubscription?.cancel();
    _autoStopTimer?.cancel();

    final gps = _gpsService.lastData;
    
    final finishedTrip = _activeTrip!.copyWith(
      endTime: DateTime.now(),
      totalDistanceKm: _totalDistance,
      avgSpeedKmh: _speedCount > 0 ? _speedSum / _speedCount : 0,
      maxSpeedKmh: _maxSpeed,
      endBatterySoc: endBatterySoc,
      endLat: gps.latitude,
      endLng: gps.longitude,
      isActive: false,
    );

    await _database.updateTrip(finishedTrip);
    _activeTrip = null;
    _tripStateController.add(null);

    return finishedTrip;
  }

  /// Check for auto-stop (idle > 5 minutes)
  bool shouldAutoStop() {
    if (_lastMovementTime == null) return false;
    return DateTime.now().difference(_lastMovementTime!).inMinutes >= 5;
  }

  /// Calculate distance between two GPS coordinates in km (Haversine)
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Future<List<Trip>> getAllTrips() async {
    return _database.getAllTrips();
  }

  Future<List<TripPoint>> getTripPoints(String tripId) async {
    return _database.getTripPoints(tripId);
  }

  Future<void> deleteTrip(String tripId) async {
    await _database.deleteTrip(tripId);
  }

  void dispose() {
    _gpsSubscription?.cancel();
    _autoStopTimer?.cancel();
    _tripStateController.close();
  }
}

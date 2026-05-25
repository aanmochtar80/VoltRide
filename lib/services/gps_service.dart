import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  const GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    this.accuracy = 0.0,
    required this.timestamp,
  });

  factory GpsData.empty() => GpsData(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
      );
}

class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  final _controller = StreamController<GpsData>.broadcast();
  GpsData _lastData = GpsData.empty();
  bool _isTracking = false;

  Stream<GpsData> get positionStream => _controller.stream;
  GpsData get lastData => _lastData;
  bool get isTracking => _isTracking;

  Future<bool> checkAndRequestPermission() async {
    try {
      // On web, isLocationServiceEnabled may not work correctly, skip it
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('GPS permission check error: $e');
      // On web, permission errors should not crash the app
      return false;
    }
  }

  Future<void> startTracking({
    int intervalMs = 1000,
    double distanceFilter = 5.0,
  }) async {
    if (_isTracking) return;

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      debugPrint('GPS: Permission denied');
      return;
    }

    _isTracking = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // Convert m/s to km/h
        final speedKmh = (position.speed * 3.6).clamp(0.0, 200.0);
        
        final gpsData = GpsData(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          speedKmh: speedKmh,
          heading: position.heading,
          accuracy: position.accuracy,
          timestamp: position.timestamp ?? DateTime.now(),
        );

        _lastData = gpsData;
        _controller.add(gpsData);
      },
      onError: (error) {
        debugPrint('GPS Error: $error');
      },
    );
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<GpsData?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return GpsData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speedKmh: (position.speed * 3.6).clamp(0.0, 200.0),
        heading: position.heading,
        accuracy: position.accuracy,
        timestamp: position.timestamp ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('GPS getCurrentPosition error: $e');
      return null;
    }
  }

  void dispose() {
    stopTracking();
    _controller.close();
  }
}

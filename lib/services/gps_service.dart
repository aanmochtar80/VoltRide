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

/// GPS permission/service check result
enum GpsPermissionResult {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unsupported,
}

class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  final _controller = StreamController<GpsData>.broadcast();
  final _statusController = StreamController<GpsPermissionResult>.broadcast();
  GpsData _lastData = GpsData.empty();
  bool _isTracking = false;
  GpsPermissionResult _lastPermissionResult = GpsPermissionResult.permissionDenied;

  Stream<GpsData> get positionStream => _controller.stream;
  Stream<GpsPermissionResult> get statusStream => _statusController.stream;
  GpsData get lastData => _lastData;
  bool get isTracking => _isTracking;
  GpsPermissionResult get lastPermissionResult => _lastPermissionResult;

  /// Check and request location permission. Returns detailed result.
  Future<GpsPermissionResult> checkAndRequestPermission() async {
    if (kIsWeb) {
      _lastPermissionResult = GpsPermissionResult.unsupported;
      _statusController.add(_lastPermissionResult);
      return _lastPermissionResult;
    }

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('GPS: Location services are disabled');
        // Try to open location settings so the user can enable it
        try {
          await Geolocator.openLocationSettings();
          // Wait a moment for user to enable location
          await Future.delayed(const Duration(seconds: 3));
          // Re-check
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            _lastPermissionResult = GpsPermissionResult.serviceDisabled;
            _statusController.add(_lastPermissionResult);
            return _lastPermissionResult;
          }
        } catch (e) {
          debugPrint('GPS: Could not open location settings: $e');
          _lastPermissionResult = GpsPermissionResult.serviceDisabled;
          _statusController.add(_lastPermissionResult);
          return _lastPermissionResult;
        }
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('GPS: Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('GPS: Permission still denied after request');
          _lastPermissionResult = GpsPermissionResult.permissionDenied;
          _statusController.add(_lastPermissionResult);
          return _lastPermissionResult;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('GPS: Permission denied forever — user must enable in app settings');
        // Open app settings so user can manually grant permission
        try {
          await Geolocator.openAppSettings();
        } catch (e) {
          debugPrint('GPS: Could not open app settings: $e');
        }
        _lastPermissionResult = GpsPermissionResult.permissionDeniedForever;
        _statusController.add(_lastPermissionResult);
        return _lastPermissionResult;
      }

      _lastPermissionResult = GpsPermissionResult.granted;
      _statusController.add(_lastPermissionResult);
      return _lastPermissionResult;
    } catch (e) {
      debugPrint('GPS permission check error: $e');
      _lastPermissionResult = GpsPermissionResult.unsupported;
      _statusController.add(_lastPermissionResult);
      return _lastPermissionResult;
    }
  }

  Future<void> startTracking({
    int intervalMs = 1000,
    double distanceFilter = 5.0,
  }) async {
    if (_isTracking) return;

    final result = await checkAndRequestPermission();
    if (result != GpsPermissionResult.granted) {
      debugPrint('GPS: Cannot start tracking — permission result: $result');
      return;
    }

    _isTracking = true;
    debugPrint('GPS: Starting position tracking...');

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    try {
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
            timestamp: position.timestamp,
          );

          _lastData = gpsData;
          _controller.add(gpsData);
        },
        onError: (error) {
          debugPrint('GPS Stream Error: $error');
        },
      );
      debugPrint('GPS: Position tracking started successfully');
    } catch (e) {
      debugPrint('GPS getPositionStream Error: $e');
      _isTracking = false;
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('GPS: Tracking stopped');
  }

  Future<GpsData?> getCurrentPosition() async {
    if (kIsWeb) return null;
    
    try {
      final result = await checkAndRequestPermission();
      if (result != GpsPermissionResult.granted) return null;

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
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('GPS getCurrentPosition error: $e');
      return null;
    }
  }

  /// Retry permission and start tracking — useful after user has changed settings
  Future<bool> retryAndStart() async {
    final result = await checkAndRequestPermission();
    if (result == GpsPermissionResult.granted) {
      await startTracking();
      return true;
    }
    return false;
  }

  void dispose() {
    stopTracking();
    _controller.close();
    _statusController.close();
  }
}

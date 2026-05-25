import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/models/trip_point.dart';
import 'dart:async';

import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static AppDatabase? _instance;
  static Database? _database;

  // In-memory fallback for Web platform
  final List<Trip> _webTrips = [];
  final List<TripPoint> _webTripPoints = [];
  final List<Map<String, dynamic>> _webBatteryLogs = [];

  AppDatabase._();

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite database cannot be opened on web. Use in-memory fallback.');
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'voltride.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        totalDistanceKm REAL DEFAULT 0,
        avgSpeedKmh REAL DEFAULT 0,
        maxSpeedKmh REAL DEFAULT 0,
        startBatterySoc REAL DEFAULT 0,
        endBatterySoc REAL DEFAULT 0,
        energyConsumedWh REAL DEFAULT 0,
        startLat REAL DEFAULT 0,
        startLng REAL DEFAULT 0,
        endLat REAL,
        endLng REAL,
        isActive INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_points (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL DEFAULT 0,
        speedKmh REAL DEFAULT 0,
        heading REAL DEFAULT 0,
        accuracy REAL DEFAULT 0,
        batteryVoltage REAL DEFAULT 0,
        batteryCurrent REAL DEFAULT 0,
        batterySoc REAL DEFAULT 0,
        powerWatt REAL DEFAULT 0,
        temperature REAL DEFAULT 0,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE battery_logs (
        id TEXT PRIMARY KEY,
        tripId TEXT,
        voltageTotal REAL DEFAULT 0,
        current REAL DEFAULT 0,
        soc REAL DEFAULT 0,
        powerWatt REAL DEFAULT 0,
        temperature REAL DEFAULT 0,
        capacityRemaining REAL DEFAULT 0,
        isCharging INTEGER DEFAULT 0,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_trip_points_trip ON trip_points(tripId)');
    await db.execute(
        'CREATE INDEX idx_battery_logs_trip ON battery_logs(tripId)');
  }

  // ── Trip Operations ──
  Future<void> insertTrip(Trip trip) async {
    if (kIsWeb) {
      _webTrips.add(trip);
      return;
    }
    final db = await database;
    await db.insert('trips', trip.toMap());
  }

  Future<void> updateTrip(Trip trip) async {
    if (kIsWeb) {
      final index = _webTrips.indexWhere((t) => t.id == trip.id);
      if (index != -1) {
        _webTrips[index] = trip;
      }
      return;
    }
    final db = await database;
    await db.update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
  }

  Future<void> deleteTrip(String tripId) async {
    if (kIsWeb) {
      _webTrips.removeWhere((t) => t.id == tripId);
      _webTripPoints.removeWhere((tp) => tp.tripId == tripId);
      _webBatteryLogs.removeWhere((bl) => bl['tripId'] == tripId);
      return;
    }
    final db = await database;
    await db.delete('trip_points', where: 'tripId = ?', whereArgs: [tripId]);
    await db.delete('battery_logs', where: 'tripId = ?', whereArgs: [tripId]);
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  Future<Trip?> getActiveTrip() async {
    if (kIsWeb) {
      final index = _webTrips.indexWhere((t) => t.isActive);
      if (index == -1) return null;
      return _webTrips[index];
    }
    final db = await database;
    final results = await db.query('trips', where: 'isActive = 1', limit: 1);
    if (results.isEmpty) return null;
    return Trip.fromMap(results.first);
  }

  Future<List<Trip>> getAllTrips() async {
    if (kIsWeb) {
      final list = List<Trip>.from(_webTrips);
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      return list;
    }
    final db = await database;
    final results = await db.query('trips', orderBy: 'startTime DESC');
    return results.map((m) => Trip.fromMap(m)).toList();
  }

  Future<Trip?> getTripById(String id) async {
    if (kIsWeb) {
      final index = _webTrips.indexWhere((t) => t.id == id);
      if (index == -1) return null;
      return _webTrips[index];
    }
    final db = await database;
    final results = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Trip.fromMap(results.first);
  }

  // ── Trip Point Operations ──
  Future<void> insertTripPoint(TripPoint point) async {
    if (kIsWeb) {
      _webTripPoints.add(point);
      return;
    }
    final db = await database;
    await db.insert('trip_points', point.toMap());
  }

  Future<void> insertTripPointsBatch(List<TripPoint> points) async {
    if (kIsWeb) {
      _webTripPoints.addAll(points);
      return;
    }
    final db = await database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert('trip_points', point.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<TripPoint>> getTripPoints(String tripId) async {
    if (kIsWeb) {
      final list = _webTripPoints.where((tp) => tp.tripId == tripId).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    }
    final db = await database;
    final results = await db.query(
      'trip_points',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
    return results.map((m) => TripPoint.fromMap(m)).toList();
  }

  // ── Battery Log Operations ──
  Future<void> insertBatteryLog(Map<String, dynamic> log) async {
    if (kIsWeb) {
      _webBatteryLogs.add(log);
      return;
    }
    final db = await database;
    await db.insert('battery_logs', log);
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = await database;
    await db.close();
    _database = null;
  }
}

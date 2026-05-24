import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/models/trip_point.dart';

class ExportService {
  /// Export trip as GPX file
  static Future<String> exportGpx(Trip trip, List<TripPoint> points) async {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="VoltRide" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>VoltRide Trip ${dateFormat.format(trip.startTime)}</name>');
    buffer.writeln('    <time>${dateFormat.format(trip.startTime)}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Trip ${DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime)}</name>');
    buffer.writeln('    <trkseg>');

    for (final point in points) {
      buffer.writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln('        <ele>${point.altitude}</ele>');
      buffer.writeln('        <time>${dateFormat.format(point.timestamp)}</time>');
      buffer.writeln('        <speed>${point.speedKmh / 3.6}</speed>');
      buffer.writeln('        <extensions>');
      buffer.writeln('          <voltride:voltage>${point.batteryVoltage}</voltride:voltage>');
      buffer.writeln('          <voltride:current>${point.batteryCurrent}</voltride:current>');
      buffer.writeln('          <voltride:soc>${point.batterySoc}</voltride:soc>');
      buffer.writeln('          <voltride:power>${point.powerWatt}</voltride:power>');
      buffer.writeln('        </extensions>');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'voltride_${DateFormat('yyyyMMdd_HHmmss').format(trip.startTime)}.gpx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file.path;
  }

  /// Export trip as CSV file
  static Future<String> exportCsv(Trip trip, List<TripPoint> points) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'timestamp,latitude,longitude,altitude,speed_kmh,heading,voltage,current,soc,power_watt,temperature');

    // Data rows
    for (final point in points) {
      buffer.writeln([
        point.timestamp.toIso8601String(),
        point.latitude,
        point.longitude,
        point.altitude,
        point.speedKmh.toStringAsFixed(1),
        point.heading.toStringAsFixed(1),
        point.batteryVoltage.toStringAsFixed(1),
        point.batteryCurrent.toStringAsFixed(1),
        point.batterySoc.toStringAsFixed(1),
        point.powerWatt.toStringAsFixed(0),
        point.temperature.toStringAsFixed(1),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'voltride_${DateFormat('yyyyMMdd_HHmmss').format(trip.startTime)}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file.path;
  }

  /// Share exported file
  static Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }
}

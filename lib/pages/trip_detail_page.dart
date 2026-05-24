import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong2.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/models/trip_point.dart';
import 'package:voltride/providers/app_providers.dart';
import 'package:voltride/services/export_service.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(selectedTripProvider);
    final settings = ref.watch(settingsProvider);

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(
          child: Text('No trip selected', style: TextStyle(color: VoltRideTheme.textSecondary)),
        ),
      );
    }

    final pointsAsync = ref.watch(tripPointsProvider(trip.id));

    // Units
    final double displayDistance = settings.useMetric ? trip.totalDistanceKm : trip.totalDistanceKm * 0.621371;
    final String distanceUnit = settings.useMetric ? 'km' : 'mi';

    final double displayAvgSpeed = settings.useMetric ? trip.avgSpeedKmh : trip.avgSpeedKmh * 0.621371;
    final double displayMaxSpeed = settings.useMetric ? trip.maxSpeedKmh : trip.maxSpeedKmh * 0.621371;
    final String speedUnit = settings.useMetric ? 'km/h' : 'mph';

    final dateStr = DateFormat('EEEE, d MMMM yyyy • HH:mm').format(trip.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRIP SUMMARY'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Card ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: VoltRideTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trip duration was ${trip.durationFormatted}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Map View ──
              pointsAsync.when(
                data: (points) {
                  final List<LatLng> polylinePoints = points
                      .map((p) => LatLng(p.latitude, p.longitude))
                      .toList();

                  CameraFit? initialFit;
                  LatLng? startCenter;
                  if (polylinePoints.isNotEmpty) {
                    initialFit = CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(polylinePoints),
                      padding: const EdgeInsets.all(32.0),
                    );
                  } else {
                    startCenter = LatLng(trip.startLat, trip.startLng);
                  }

                  return Container(
                    height: 250,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: VoltRideTheme.glassCard(),
                    clipBehavior: Clip.antiAlias,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: startCenter ?? const LatLng(-6.2, 106.8),
                        initialCameraFit: initialFit,
                        initialZoom: startCenter != null ? 15.0 : 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.voltride.app',
                        ),
                        if (polylinePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polylinePoints,
                                color: VoltRideTheme.electricBlue,
                                strokeWidth: 4.5,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (polylinePoints.isNotEmpty) ...[
                              Marker(
                                point: polylinePoints.first,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: VoltRideTheme.neonGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.black, size: 12),
                                ),
                              ),
                              Marker(
                                point: polylinePoints.last,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: VoltRideTheme.alertRed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flag, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Container(
                  height: 250,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: VoltRideTheme.glassCard(),
                  child: const Center(
                    child: CircularProgressIndicator(color: VoltRideTheme.electricBlue),
                  ),
                ),
                error: (err, _) => Container(
                  height: 250,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: VoltRideTheme.glassCard(),
                  child: const Center(
                    child: Text('Map rendering error', style: TextStyle(color: VoltRideTheme.alertRed)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Key Statistics grid ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _buildStatCard('DISTANCE', displayDistance.toStringAsFixed(2), distanceUnit, VoltRideTheme.voltYellow),
                    _buildStatCard('AVG SPEED', displayAvgSpeed.toStringAsFixed(1), speedUnit, VoltRideTheme.electricBlue),
                    _buildStatCard('MAX SPEED', displayMaxSpeed.toStringAsFixed(1), speedUnit, VoltRideTheme.powerOrange),
                    _buildStatCard(
                      'BATTERY DRAIN',
                      trip.batteryUsed > 0 ? '${trip.batteryUsed.toStringAsFixed(0)}%' : '0%',
                      '${trip.startBatterySoc.toStringAsFixed(0)}% → ${trip.endBatterySoc.toStringAsFixed(0)}%',
                      VoltRideTheme.neonGreen,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Speed Chart ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'SPEED PROFILE',
                  style: TextStyle(
                    color: VoltRideTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              pointsAsync.when(
                data: (points) {
                  if (points.length < 2) {
                    return Container(
                      height: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: VoltRideTheme.glassCard(),
                      child: const Center(
                        child: Text(
                          'Insufficient points to draw chart',
                          style: TextStyle(color: VoltRideTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  // Downsample points if there are too many (limit to 40 points for smooth charts)
                  List<TripPoint> chartPoints = [];
                  if (points.length > 40) {
                    final int step = (points.length / 40).floor();
                    for (int i = 0; i < points.length; i += step) {
                      chartPoints.add(points[i]);
                    }
                  } else {
                    chartPoints = points;
                  }

                  final spots = List.generate(chartPoints.length, (index) {
                    final speedVal = settings.useMetric ? chartPoints[index].speedKmh : chartPoints[index].speedKmh * 0.621371;
                    return FlSpot(index.toDouble(), speedVal);
                  });

                  return Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                    decoration: VoltRideTheme.glassCard(),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 10,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: VoltRideTheme.cardBorder.withOpacity(0.3),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: (chartPoints.length / 4).clamp(1.0, 100.0),
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < chartPoints.length) {
                                  final pt = chartPoints[idx];
                                  final diff = pt.timestamp.difference(trip.startTime);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${diff.inMinutes}m',
                                      style: const TextStyle(
                                        color: VoltRideTheme.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: VoltRideTheme.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [VoltRideTheme.electricBlue, VoltRideTheme.purple],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  VoltRideTheme.electricBlue.withOpacity(0.2),
                                  VoltRideTheme.purple.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => Container(
                  height: 180,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: VoltRideTheme.glassCard(),
                  child: const Center(
                    child: CircularProgressIndicator(color: VoltRideTheme.electricBlue),
                  ),
                ),
                error: (err, _) => Container(
                  height: 180,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: VoltRideTheme.glassCard(),
                  child: const Center(
                    child: Text('Chart rendering error', style: TextStyle(color: VoltRideTheme.alertRed)),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Export Sharing Actions ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VoltRideTheme.electricBlue,
                          side: const BorderSide(color: VoltRideTheme.electricBlue, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('EXPORT GPX', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _exportTrip(context, trip, pointsAsync.value, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VoltRideTheme.voltYellow,
                          side: const BorderSide(color: VoltRideTheme.voltYellow, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.table_rows, size: 18),
                        label: const Text('EXPORT CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _exportTrip(context, trip, pointsAsync.value, false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: VoltRideTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: VoltRideTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportTrip(BuildContext context, Trip trip, List<TripPoint>? points, bool isGpx) async {
    if (points == null || points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot export trip with no telemetry points!'),
          backgroundColor: VoltRideTheme.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final String filePath = isGpx
          ? await ExportService.exportGpx(trip, points)
          : await ExportService.exportCsv(trip, points);

      await ExportService.shareFile(filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: VoltRideTheme.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

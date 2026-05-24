import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/pages/ble_scanner_page.dart';
import 'package:voltride/providers/app_providers.dart';
import 'package:voltride/widgets/battery_card_widget.dart';
import 'package:voltride/widgets/ble_status_indicator.dart';
import 'package:voltride/widgets/mini_map_widget.dart';
import 'package:voltride/widgets/speedometer_widget.dart';
import 'package:voltride/widgets/telemetry_card_widget.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _tripTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    final activeTrip = ref.read(activeTripProvider);
    if (activeTrip != null) {
      _tripTimer?.cancel();
      _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _elapsed = DateTime.now().difference(activeTrip.startTime);
          });
        }
      });
    } else {
      _tripTimer?.cancel();
      _tripTimer = null;
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _tripTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final speed = ref.watch(currentSpeedProvider);
    final bmsData = ref.watch(currentBmsDataProvider);
    final bleState = ref.watch(bleConnectionStateProvider).value ?? BleConnectionState.disconnected;
    final activeTrip = ref.watch(activeTripProvider);
    final isRecording = ref.watch(isRecordingProvider);
    final settings = ref.watch(settingsProvider);
    final gpsData = ref.watch(currentPositionProvider);

    // Restart timer when transition to recording happens
    ref.listen(activeTripProvider, (prev, next) {
      _startTimerIfNeeded();
    });

    // Units
    final double displaySpeed = settings.useMetric ? speed : speed * 0.621371;
    final String speedUnit = settings.useMetric ? 'km/h' : 'mph';

    final double displayDistance = activeTrip != null
        ? (settings.useMetric ? activeTrip.totalDistanceKm : activeTrip.totalDistanceKm * 0.621371)
        : 0.0;
    final String distanceUnit = settings.useMetric ? 'km' : 'mi';

    final double displayAvgSpeed = activeTrip != null
        ? (settings.useMetric ? activeTrip.avgSpeedKmh : activeTrip.avgSpeedKmh * 0.621371)
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // extra padding at bottom for FAB / TabBar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOLTRIDE',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, d MMMM').format(DateTime.now()),
                          style: const TextStyle(
                            color: VoltRideTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    BleStatusIndicator(
                      state: bleState,
                      deviceName: settings.lastConnectedDeviceName,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BleScannerPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Speedometer Widget
                Center(
                  child: SpeedometerWidget(
                    speed: displaySpeed,
                    unit: speedUnit,
                    maxSpeed: 80, // Target max Ev speed scale
                  ),
                ),
                const SizedBox(height: 10),

                // Telemetry Cards Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    TelemetryCardWidget(
                      label: 'TRIP TIME',
                      value: _formatDuration(_elapsed),
                      icon: Icons.timer_outlined,
                      color: VoltRideTheme.electricBlue,
                    ),
                    TelemetryCardWidget(
                      label: 'DISTANCE',
                      value: displayDistance.toStringAsFixed(2),
                      unit: distanceUnit,
                      icon: Icons.map_outlined,
                      color: VoltRideTheme.voltYellow,
                    ),
                    TelemetryCardWidget(
                      label: 'AVG SPEED',
                      value: displayAvgSpeed.toStringAsFixed(1),
                      unit: speedUnit,
                      icon: Icons.speed_outlined,
                      color: VoltRideTheme.purple,
                    ),
                    TelemetryCardWidget(
                      label: 'MAX SPEED',
                      value: (activeTrip != null
                              ? (settings.useMetric ? activeTrip.maxSpeedKmh : activeTrip.maxSpeedKmh * 0.621371)
                              : 0.0)
                          .toStringAsFixed(1),
                      unit: speedUnit,
                      icon: Icons.trending_up,
                      color: VoltRideTheme.powerOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Battery Status Card
                BatteryCardWidget(bmsData: bmsData),
                const SizedBox(height: 20),

                // Mini Map Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ROUTE TRACKING',
                      style: TextStyle(
                        color: VoltRideTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: VoltRideTheme.alertRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: VoltRideTheme.alertRed.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: VoltRideTheme.alertRed, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'RECORDING',
                              style: TextStyle(
                                color: VoltRideTheme.alertRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mini Map Widget
                const MiniMapWidget(height: 200),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final tripService = ref.read(tripServiceProvider);
          if (isRecording) {
            // STOP TRIP
            final completedTrip = await tripService.stopTrip(
              endBatterySoc: bmsData.soc,
            );
            if (completedTrip != null && mounted) {
              ref.invalidate(tripHistoryProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Trip recorded! ${completedTrip.totalDistanceKm.toStringAsFixed(2)} km'),
                  backgroundColor: VoltRideTheme.neonGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // START TRIP
            final currentGps = gpsData ?? await ref.read(gpsServiceProvider).getCurrentPosition();
            if (currentGps == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Waiting for active GPS location...'),
                    backgroundColor: VoltRideTheme.alertRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }

            await tripService.startTrip(
              latitude: currentGps.latitude,
              longitude: currentGps.longitude,
              batterySoc: bmsData.soc,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip tracking started!'),
                  backgroundColor: VoltRideTheme.electricBlue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        label: Text(
          isRecording ? 'STOP TRIP' : 'START TRIP',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 1.0,
            color: Colors.black,
          ),
        ),
        icon: Icon(
          isRecording ? Icons.stop : Icons.play_arrow,
          color: Colors.black,
        ),
        backgroundColor: isRecording ? VoltRideTheme.alertRed : VoltRideTheme.neonGreen,
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

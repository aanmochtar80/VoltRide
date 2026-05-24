import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/models/trip.dart';
import 'package:voltride/pages/trip_detail_page.dart';
import 'package:voltride/providers/app_providers.dart';

class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripHistoryProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRIP HISTORY'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tripHistoryProvider);
          },
          color: VoltRideTheme.electricBlue,
          backgroundColor: VoltRideTheme.surface,
          child: tripsAsync.when(
            data: (trips) {
              // Filter out active trip from history list, or show completed ones
              final completedTrips = trips.where((t) => !t.isActive).toList();

              if (completedTrips.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VoltRideTheme.cardBorder.withOpacity(0.2),
                            ),
                            child: const Icon(
                              Icons.history_outlined,
                              color: VoltRideTheme.textMuted,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No recorded trips',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Trips you record using the Start Trip button on the dashboard will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VoltRideTheme.textSecondary.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: completedTrips.length,
                itemBuilder: (context, index) {
                  final trip = completedTrips[index];
                  final dateStr = DateFormat('EEE, d MMM yyyy • HH:mm').format(trip.startTime);
                  
                  // Compute distance unit conversion
                  final double distance = settings.useMetric ? trip.totalDistanceKm : trip.totalDistanceKm * 0.621371;
                  final String unitStr = settings.useMetric ? 'km' : 'mi';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: VoltRideTheme.glassCard(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedTripProvider.notifier).state = trip;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TripDetailPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date and Delete Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route_outlined,
                                      color: VoltRideTheme.electricBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.inter(
                                        color: VoltRideTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: VoltRideTheme.alertRed,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDelete(context, ref, trip),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: VoltRideTheme.cardBorder, height: 1),
                            const SizedBox(height: 12),
                            // Quick Metrics row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricColumn(
                                  'DISTANCE',
                                  '${distance.toStringAsFixed(2)} $unitStr',
                                  VoltRideTheme.voltYellow,
                                ),
                                _buildMetricColumn(
                                  'DURATION',
                                  trip.durationFormatted,
                                  VoltRideTheme.electricBlue,
                                ),
                                _buildMetricColumn(
                                  'BATTERY USED',
                                  trip.batteryUsed > 0
                                      ? '${trip.batteryUsed.toStringAsFixed(0)}%'
                                      : '--',
                                  VoltRideTheme.neonGreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Details action label
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'View Detailed Telemetry',
                                  style: TextStyle(
                                    color: VoltRideTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: VoltRideTheme.textSecondary,
                                  size: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(VoltRideTheme.electricBlue),
              ),
            ),
            error: (err, stack) => Center(
              child: Text(
                'Error loading history: $err',
                style: const TextStyle(color: VoltRideTheme.alertRed),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VoltRideTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VoltRideTheme.surface,
        title: const Text('Delete Trip?'),
        content: const Text('This will permanently delete this trip and all its telemetry data.'),
        actions: [
          TextButton(
            child: const Text('CANCEL', style: TextStyle(color: VoltRideTheme.textSecondary)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('DELETE', style: TextStyle(color: VoltRideTheme.alertRed)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tripServiceProvider).deleteTrip(trip.id);
      ref.invalidate(tripHistoryProvider);
    }
  }
}

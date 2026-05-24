import 'package:flutter/material.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/models/trip.dart';

class TripSummaryWidget extends StatelessWidget {
  final Trip trip;
  final bool showBattery;

  const TripSummaryWidget({
    super.key,
    required this.trip,
    this.showBattery = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: VoltRideTheme.glassCard(),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryItem(
                icon: Icons.straighten,
                label: 'DISTANCE',
                value: trip.distanceFormatted,
                color: VoltRideTheme.electricBlue,
              ),
              _divider(),
              _SummaryItem(
                icon: Icons.timer,
                label: 'DURATION',
                value: trip.durationFormatted,
                color: VoltRideTheme.neonGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryItem(
                icon: Icons.speed,
                label: 'AVG SPEED',
                value: '${trip.avgSpeedKmh.toStringAsFixed(1)} km/h',
                color: VoltRideTheme.voltYellow,
              ),
              _divider(),
              _SummaryItem(
                icon: Icons.speed,
                label: 'MAX SPEED',
                value: '${trip.maxSpeedKmh.toStringAsFixed(1)} km/h',
                color: VoltRideTheme.powerOrange,
              ),
            ],
          ),
          if (showBattery && trip.batteryUsed > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryItem(
                  icon: Icons.battery_std,
                  label: 'BATTERY USED',
                  value: '${trip.batteryUsed.toStringAsFixed(1)}%',
                  color: VoltRideTheme.alertRed,
                ),
                _divider(),
                _SummaryItem(
                  icon: Icons.bolt,
                  label: 'ENERGY',
                  value: '${trip.energyConsumedWh.toStringAsFixed(0)} Wh',
                  color: VoltRideTheme.purple,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: VoltRideTheme.cardBorder,
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: VoltRideTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

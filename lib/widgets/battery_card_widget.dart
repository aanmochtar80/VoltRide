import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/models/bms_data.dart';
import 'package:voltride/providers/app_providers.dart';
class BatteryCardWidget extends StatelessWidget {
  final BmsData bmsData;
  final bool isConnected;

  const BatteryCardWidget({
    super.key,
    required this.bmsData,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: VoltRideTheme.glowCard(
        glowColor: _getBatteryColor(bmsData.soc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getBatteryIcon(bmsData.soc),
                    color: _getBatteryColor(bmsData.soc),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'BATTERY',
                    style: TextStyle(
                      color: VoltRideTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              _StatusChip(
                label: bmsData.statusText,
                color: bmsData.isCharging
                    ? VoltRideTheme.neonGreen
                    : bmsData.isDischarging
                        ? VoltRideTheme.electricBlue
                        : VoltRideTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SOC Bar
          _BatteryBar(soc: bmsData.soc),
          const SizedBox(height: 16),

          // Main stats
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'VOLTAGE',
                  value: '${bmsData.voltageTotal.toStringAsFixed(1)}V',
                  color: VoltRideTheme.electricBlue,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'CURRENT',
                  value: '${bmsData.current.toStringAsFixed(1)}A',
                  color: VoltRideTheme.neonGreen,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'POWER',
                  value: '${bmsData.powerWatt.toStringAsFixed(0)}W',
                  color: VoltRideTheme.powerOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Temperature
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'TEMP',
                  value: '${bmsData.avgTemperature.toStringAsFixed(1)}°C',
                  color: bmsData.avgTemperature > 40
                      ? VoltRideTheme.alertRed
                      : VoltRideTheme.voltYellow,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'REMAINING',
                  value: '${bmsData.capacityRemaining.toStringAsFixed(1)}Ah',
                  color: VoltRideTheme.purple,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'CELL Δ',
                  value: '${(bmsData.cellDelta * 1000).toStringAsFixed(0)}mV',
                  color: bmsData.cellDelta > 0.05
                      ? VoltRideTheme.alertRed
                      : VoltRideTheme.neonGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(double soc) {
    if (soc > 60) return VoltRideTheme.neonGreen;
    if (soc > 30) return VoltRideTheme.voltYellow;
    if (soc > 15) return VoltRideTheme.powerOrange;
    return VoltRideTheme.alertRed;
  }

  IconData _getBatteryIcon(double soc) {
    if (soc > 80) return Icons.battery_full;
    if (soc > 60) return Icons.battery_5_bar;
    if (soc > 40) return Icons.battery_4_bar;
    if (soc > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}

class _BatteryBar extends StatelessWidget {
  final double soc;

  const _BatteryBar({required this.soc});

  @override
  Widget build(BuildContext context) {
    Color barColor;
    if (soc > 60) {
      barColor = VoltRideTheme.neonGreen;
    } else if (soc > 30) {
      barColor = VoltRideTheme.voltYellow;
    } else if (soc > 15) {
      barColor = VoltRideTheme.powerOrange;
    } else {
      barColor = VoltRideTheme.alertRed;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${soc.toStringAsFixed(0)}%',
              style: TextStyle(
                color: barColor,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'SOC',
              style: TextStyle(
                color: VoltRideTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: VoltRideTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: (soc / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          barColor.withOpacity(0.8),
                          barColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VoltRideTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

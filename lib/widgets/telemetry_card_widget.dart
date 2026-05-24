import 'package:flutter/material.dart';
import 'package:voltride/core/theme.dart';

class TelemetryCardWidget extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;

  const TelemetryCardWidget({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: VoltRideTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: VoltRideTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/services/ble_service.dart';

class BleStatusIndicator extends StatefulWidget {
  final BleConnectionState state;
  final String? deviceName;
  final VoidCallback? onTap;

  const BleStatusIndicator({
    super.key,
    required this.state,
    this.deviceName,
    this.onTap,
  });

  @override
  State<BleStatusIndicator> createState() => _BleStatusIndicatorState();
}

class _BleStatusIndicatorState extends State<BleStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(BleStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == BleConnectionState.connecting ||
        widget.state == BleConnectionState.scanning) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();
    final icon = _getIcon();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1 * _pulseController.value),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3 * _pulseController.value),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getColor() {
    switch (widget.state) {
      case BleConnectionState.connected:
        return VoltRideTheme.neonGreen;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return VoltRideTheme.voltYellow;
      case BleConnectionState.disconnecting:
        return VoltRideTheme.powerOrange;
      case BleConnectionState.disconnected:
        return VoltRideTheme.textMuted;
    }
  }

  String _getLabel() {
    switch (widget.state) {
      case BleConnectionState.connected:
        return widget.deviceName ?? 'Connected';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.scanning:
        return 'Scanning...';
      case BleConnectionState.disconnecting:
        return 'Disconnecting...';
      case BleConnectionState.disconnected:
        return 'BLE Off';
    }
  }

  IconData _getIcon() {
    switch (widget.state) {
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return Icons.bluetooth_searching;
      case BleConnectionState.disconnecting:
      case BleConnectionState.disconnected:
        return Icons.bluetooth_disabled;
    }
  }
}

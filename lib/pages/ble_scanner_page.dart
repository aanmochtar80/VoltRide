import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voltride/core/theme.dart';
import 'package:voltride/providers/app_providers.dart';
import 'package:voltride/services/ble_service.dart';

class BleScannerPage extends ConsumerStatefulWidget {
  const BleScannerPage({super.key});

  @override
  ConsumerState<BleScannerPage> createState() => _BleScannerPageState();
}

class _BleScannerPageState extends ConsumerState<BleScannerPage> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    ref.read(bleServiceProvider).stopScan();
    super.dispose();
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    final bleService = ref.read(bleServiceProvider);
    
    // Subscribe to scan stream
    _scanSubscription?.cancel();
    _scanSubscription = bleService.scanStream(timeout: const Duration(seconds: 10)).listen(
      (results) {
        if (mounted) {
          setState(() {
            // Sort by signal strength (RSSI)
            _scanResults = List<ScanResult>.from(results)
              ..sort((a, b) => b.rssi.compareTo(a.rssi));
          });
        }
      },
      onError: (e) {
        debugPrint('Scan stream error: $e');
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
    );
  }

  void _stopScan() {
    ref.read(bleServiceProvider).stopScan();
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleConnectionStateProvider).value ?? BleConnectionState.disconnected;
    final bmsService = ref.watch(jkBmsServiceProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BMS SCANNER'),
        actions: [
          if (_isScanning)
            IconButton(
              icon: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              onPressed: _stopScan,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltRideTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // ── Connection Status Bar ──
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: VoltRideTheme.glassCard(
                borderColor: bleState == BleConnectionState.connected
                    ? VoltRideTheme.neonGreen.withOpacity(0.3)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STATUS',
                        style: TextStyle(
                          color: VoltRideTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bleState.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(bleState),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (bleState == BleConnectionState.connected)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VoltRideTheme.alertRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () async {
                        await ref.read(bleServiceProvider).disconnect();
                        ref.read(jkBmsServiceProvider).stopDummyMode();
                      },
                      child: const Text('DISCONNECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // ── EV Simulator Neon Mode ──
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: VoltRideTheme.glowCard(
                glowColor: bmsService.isUsingDummyData ? VoltRideTheme.electricBlue : VoltRideTheme.cardBorder,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VoltRideTheme.electricBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.electric_car,
                      color: VoltRideTheme.electricBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EV Simulator',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bmsService.isUsingDummyData ? 'Running virtual EV telemetry' : 'Run app in desktop simulator',
                          style: const TextStyle(
                            color: VoltRideTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: bmsService.isUsingDummyData,
                    activeColor: VoltRideTheme.neonGreen,
                    onChanged: (val) {
                      if (val) {
                        ref.read(jkBmsServiceProvider).startDummyMode();
                        // Automatically update settings with simulated info
                        ref.read(settingsProvider.notifier).setLastConnectedDevice('SIM-001', 'VoltRide EV Simulator');
                        // Set state as connected
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('EV Simulation mode activated!'),
                            backgroundColor: VoltRideTheme.electricBlue,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        ref.read(jkBmsServiceProvider).stopDummyMode();
                      }
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BLUETOOTH BLE DEVICES',
                  style: TextStyle(
                    color: VoltRideTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Scan results list ──
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            color: VoltRideTheme.textMuted.withOpacity(0.5),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning ? 'Scanning for BMS...' : 'No BLE devices found',
                            style: const TextStyle(color: VoltRideTheme.textMuted, fontSize: 13),
                          ),
                          if (!_isScanning) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _startScan,
                              child: const Text('SCAN AGAIN'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final device = result.device;
                        final name = result.advertisementData.localName.isNotEmpty
                            ? result.advertisementData.localName
                            : (device.platformName.isNotEmpty ? device.platformName : 'Unknown Device');

                        final isJkBms = name.toLowerCase().contains('jk') ||
                            name.toLowerCase().contains('bms');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: VoltRideTheme.glassCard(
                            borderColor: isJkBms ? VoltRideTheme.electricBlue.withOpacity(0.3) : null,
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isJkBms ? VoltRideTheme.electricBlue : VoltRideTheme.cardBorder).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isJkBms ? Icons.battery_charging_full : Icons.bluetooth,
                                color: isJkBms ? VoltRideTheme.electricBlue : VoltRideTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: isJkBms ? VoltRideTheme.textPrimary : VoltRideTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              device.remoteId.str,
                              style: const TextStyle(color: VoltRideTheme.textMuted, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.signal_cellular_alt,
                                  color: _getRssiColor(result.rssi),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${result.rssi} dBm',
                                  style: const TextStyle(color: VoltRideTheme.textMuted, fontSize: 10),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: bleState == BleConnectionState.disconnected
                                      ? () async {
                                          _stopScan();
                                          final bleService = ref.read(bleServiceProvider);
                                          final success = await bleService.connectToDevice(device);
                                          if (success) {
                                            ref.read(jkBmsServiceProvider).startListening();
                                            ref.read(settingsProvider.notifier).setLastConnectedDevice(
                                                  device.remoteId.str,
                                                  name,
                                                );
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Connected to $name!'),
                                                  backgroundColor: VoltRideTheme.neonGreen,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                              Navigator.pop(context);
                                            }
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Failed to connect! Check device.'),
                                                  backgroundColor: VoltRideTheme.alertRed,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      : null,
                                  child: const Text('CONNECT', style: TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BleConnectionState state) {
    switch (state) {
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

  Color _getRssiColor(int rssi) {
    if (rssi >= -60) return VoltRideTheme.neonGreen;
    if (rssi >= -80) return VoltRideTheme.voltYellow;
    return VoltRideTheme.alertRed;
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _listenAdapterState();
    // Delay scan slightly to let the page build first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    if (!kIsWeb) {
      FlutterBluePlus.stopScan();
    }
    super.dispose();
  }

  /// Listen to Bluetooth adapter on/off state
  void _listenAdapterState() {
    if (kIsWeb) return;
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
        // If Bluetooth was just turned on and we're not scanning, auto-scan
        if (state == BluetoothAdapterState.on && !_isScanning && _scanResults.isEmpty) {
          _startScan();
        }
      }
    });
  }

  void _startScan() {
    if (_isScanning) return;
    if (kIsWeb) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _scanError = null;
    });

    final bleService = ref.read(bleServiceProvider);
    
    // Subscribe to scan stream
    _scanSubscription?.cancel();
    _scanSubscription = bleService.scanStream(timeout: const Duration(seconds: 12)).listen(
      (results) {
        if (mounted) {
          setState(() {
            // Sort: JK-BMS devices first, then by signal strength (RSSI)
            _scanResults = List<ScanResult>.from(results)
              ..sort((a, b) {
                final aIsJk = _isJkBmsDevice(a);
                final bIsJk = _isJkBmsDevice(b);
                if (aIsJk && !bIsJk) return -1;
                if (!aIsJk && bIsJk) return 1;
                return b.rssi.compareTo(a.rssi);
              });
          });
        }
      },
      onError: (e) {
        debugPrint('Scan stream error: $e');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanError = e.toString();
          });
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

  /// Check if a scan result is likely a JK-BMS device
  bool _isJkBmsDevice(ScanResult result) {
    final name = _getDeviceName(result);
    final nameLower = name.toLowerCase();
    return nameLower.contains('jk') ||
        nameLower.contains('bms') ||
        nameLower.contains('jikong') ||
        nameLower.contains('jk-b') ||
        nameLower.contains('jk_b');
  }

  /// Get the best available device name
  String _getDeviceName(ScanResult result) {
    final advName = result.advertisementData.advName;
    if (advName.isNotEmpty) return advName;
    final platformName = result.device.platformName;
    if (platformName.isNotEmpty) return platformName;
    return 'Unknown Device';
  }

  void _turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please turn on Bluetooth from Settings: $e'),
            backgroundColor: VoltRideTheme.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            // ── Bluetooth Adapter State Warning ──
            if (!kIsWeb && _adapterState != BluetoothAdapterState.on && _adapterState != BluetoothAdapterState.unknown)
              _buildAdapterWarning(),

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

            // ── Section Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BLUETOOTH BLE DEVICES',
                    style: TextStyle(
                      color: VoltRideTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (_scanResults.isNotEmpty)
                    Text(
                      '${_scanResults.length} found',
                      style: const TextStyle(
                        color: VoltRideTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Scan Error ──
            if (_scanError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: VoltRideTheme.alertRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VoltRideTheme.alertRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: VoltRideTheme.alertRed, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Error',
                            style: TextStyle(color: VoltRideTheme.alertRed, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _scanError!,
                            style: const TextStyle(color: VoltRideTheme.textMuted, fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                            _isScanning 
                                ? 'Scanning for BMS devices...' 
                                : _adapterState != BluetoothAdapterState.on && !kIsWeb
                                    ? 'Turn on Bluetooth to scan'
                                    : 'No BLE devices found',
                            style: const TextStyle(color: VoltRideTheme.textMuted, fontSize: 13),
                          ),
                          if (_isScanning) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Make sure your JK-BMS is powered on',
                              style: TextStyle(color: VoltRideTheme.textMuted, fontSize: 11),
                            ),
                          ],
                          if (!_isScanning) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('SCAN AGAIN'),
                              onPressed: _startScan,
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
                        final name = _getDeviceName(result);
                        final isJkBms = _isJkBmsDevice(result);

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
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: isJkBms ? VoltRideTheme.textPrimary : VoltRideTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isJkBms)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: VoltRideTheme.electricBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BMS',
                                      style: TextStyle(
                                        color: VoltRideTheme.electricBlue,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
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

  /// Build warning banner when Bluetooth adapter is off
  Widget _buildAdapterWarning() {
    String message;
    IconData icon;
    Color color;

    switch (_adapterState) {
      case BluetoothAdapterState.off:
        message = 'Bluetooth is turned off';
        icon = Icons.bluetooth_disabled;
        color = VoltRideTheme.voltYellow;
        break;
      case BluetoothAdapterState.unauthorized:
        message = 'Bluetooth permission denied. Check app settings.';
        icon = Icons.lock_outline;
        color = VoltRideTheme.alertRed;
        break;
      case BluetoothAdapterState.unavailable:
        message = 'Bluetooth is not available on this device';
        icon = Icons.bluetooth_disabled;
        color = VoltRideTheme.alertRed;
        break;
      default:
        message = 'Bluetooth adapter: ${_adapterState.name}';
        icon = Icons.bluetooth_disabled;
        color = VoltRideTheme.voltYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (_adapterState == BluetoothAdapterState.off)
                  const Text(
                    'Tap the button to enable Bluetooth',
                    style: TextStyle(color: VoltRideTheme.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (_adapterState == BluetoothAdapterState.off)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: _turnOnBluetooth,
              child: const Text('TURN ON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
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

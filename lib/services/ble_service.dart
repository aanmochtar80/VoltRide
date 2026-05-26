import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
}

class BleService {
  BluetoothDevice? _connectedDevice;
  final List<BluetoothCharacteristic> _writeCharacteristics = [];
  final List<StreamSubscription<List<int>>> _notifySubscriptions = [];
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();
  
  BleConnectionState _state = BleConnectionState.disconnected;
  bool _autoReconnect = true;
  String? _lastDeviceId;
  Timer? _reconnectTimer;

  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<int>> get dataStream => _dataController.stream;
  BleConnectionState get state => _state;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _state == BleConnectionState.connected;

  /// Stream of Bluetooth adapter state (on/off/unauthorized etc.)
  Stream<BluetoothAdapterState> get adapterStateStream => FlutterBluePlus.adapterState;

  BleService() {
    // Listen to FlutterBluePlus isScanning to properly reset state
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _state == BleConnectionState.scanning) {
        _updateState(BleConnectionState.disconnected);
      }
    });
  }

  void _updateState(BleConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  /// Check if Bluetooth adapter is on and permissions are granted.
  /// Returns true if ready to scan, false otherwise.
  Future<bool> ensureBluetoothReady() async {
    if (kIsWeb) return false;

    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('BLE: Bluetooth is not supported on this device');
        return false;
      }

      // Check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('BLE: Adapter state is $adapterState, attempting to turn on...');
        try {
          // On Android, this shows a system dialog asking user to turn on Bluetooth
          await FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint('BLE: Could not turn on Bluetooth: $e');
        }

        // Wait briefly for adapter to turn on
        try {
          final state = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 5));
          if (state != BluetoothAdapterState.on) return false;
        } catch (e) {
          debugPrint('BLE: Bluetooth adapter did not turn on in time');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('BLE: ensureBluetoothReady error: $e');
      return false;
    }
  }

  /// Scan for BLE devices. Returns a stream of scan results.
  /// This properly handles permissions and adapter state.
  Stream<List<ScanResult>> scanStream({Duration timeout = const Duration(seconds: 10)}) {
    if (kIsWeb) {
      return Stream.periodic(const Duration(seconds: 1), (_) => <ScanResult>[]).take(1);
    }

    // Create a controller to manage the stream lifecycle
    final controller = StreamController<List<ScanResult>>();
    
    () async {
      try {
        // Ensure Bluetooth is ready (adapter on, permissions granted)
        final ready = await ensureBluetoothReady();
        if (!ready) {
          debugPrint('BLE: Bluetooth not ready, cannot scan');
          controller.add([]);
          await controller.close();
          return;
        }

        _updateState(BleConnectionState.scanning);

        // Stop any existing scan first
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }

        // Start scanning with proper parameters
        await FlutterBluePlus.startScan(
          timeout: timeout,
          androidUsesFineLocation: true, // Required for Android 12+ BLE scanning
        );

        // Forward scan results to the controller
        final subscription = FlutterBluePlus.onScanResults.listen(
          (results) {
            if (!controller.isClosed) {
              controller.add(results);
            }
          },
          onError: (e) {
            debugPrint('BLE Scan stream error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );

        // Wait for scan to complete
        await FlutterBluePlus.isScanning.where((s) => s == false).first;

        // Clean up
        await subscription.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e) {
        debugPrint('BLE Scan error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  void stopScan() {
    if (!kIsWeb) {
      FlutterBluePlus.stopScan();
    }
    if (_state == BleConnectionState.scanning) {
      _updateState(BleConnectionState.disconnected);
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (kIsWeb) return false;
    
    try {
      _updateState(BleConnectionState.connecting);
      _lastDeviceId = device.remoteId.str;

      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      _connectedDevice = device;

      // Listen for disconnection
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Request MTU 512 for large BMS data frames (JK BMS sends ~300 bytes)
      try {
        await device.requestMtu(512);
        debugPrint('BLE: Requested MTU 512');
        // Wait a tiny bit for MTU to negotiate
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('BLE: Failed to request MTU: $e');
      }

      _writeCharacteristics.clear();
      // Discover services and automatically find TX/RX characteristics
      final services = await device.discoverServices();
      bool foundAnyNotify = false;
      
      for (final service in services) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          
          // Try to listen to it if it supports notify/indicate OR if it's the known JK-BMS characteristic (ffe1/ffe2/ffe3)
          if (char.properties.notify || char.properties.indicate || uuid.contains('ffe1') || uuid.contains('ffe2') || uuid.contains('ffe3') || uuid.contains('ff10')) {
            try {
              await char.setNotifyValue(true);
              final sub = char.onValueReceived.listen((data) {
                _dataController.add(data);
              });
              _notifySubscriptions.add(sub);
              foundAnyNotify = true;
              debugPrint('BLE: Subscribed to Notify characteristic: $uuid');
            } catch (e) {
              debugPrint('BLE: Failed to subscribe to $uuid: $e');
            }
          }
          
          // Collect ALL writable characteristics, BUT ONLY from known BMS data services/characteristics
          // We MUST NOT write to Generic Access (0x1800) or Device Name (0x2A00) as it will rename the device!
          if (char.properties.writeWithoutResponse || char.properties.write) {
            if (uuid.contains('ffe1') || uuid.contains('ffe2') || uuid.contains('ffe3') || 
                uuid.contains('ff10') || uuid.contains('ff11') || uuid.contains('ff12') ||
                service.uuid.toString().toLowerCase().contains('ffe0') || 
                service.uuid.toString().toLowerCase().contains('ff10')) {
              _writeCharacteristics.add(char);
              debugPrint('BLE: Added Write characteristic: $uuid');
            }
          }
        }
      }

      if (!foundAnyNotify) {
        debugPrint('BLE: Connected but NO notify characteristics found at all!');
      }

      _updateState(BleConnectionState.connected);
      return true;
    } catch (e) {
      debugPrint('BLE Connect error: $e');
      _updateState(BleConnectionState.disconnected);
      return false;
    }
  }

  void _handleDisconnection() {
    _updateState(BleConnectionState.disconnected);
    for (final sub in _notifySubscriptions) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
    _writeCharacteristics.clear();
    _connectedDevice = null;

    // Auto-reconnect
    if (_autoReconnect && _lastDeviceId != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_state != BleConnectionState.disconnected) return;
      if (_lastDeviceId == null) return;

      debugPrint('BLE: Attempting auto-reconnect to $_lastDeviceId');
      try {
        final device = BluetoothDevice.fromId(_lastDeviceId!);
        await connectToDevice(device);
      } catch (e) {
        debugPrint('BLE Auto-reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    
    try {
      _updateState(BleConnectionState.disconnecting);
      for (final sub in _notifySubscriptions) {
        sub.cancel();
      }
      _notifySubscriptions.clear();
      _connectionSubscription?.cancel();
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('BLE Disconnect error: $e');
    }
    
    _connectedDevice = null;
    _writeCharacteristics.clear();
    _updateState(BleConnectionState.disconnected);
  }

  Future<void> writeData(List<int> data) async {
    if (_writeCharacteristics.isEmpty) return;
    for (final char in _writeCharacteristics) {
      try {
        final withoutResp = char.properties.writeWithoutResponse;
        await char.write(data, withoutResponse: withoutResp);
      } catch (e) {
        debugPrint('BLE Write error on ${char.uuid}: $e');
      }
    }
  }

  void setAutoReconnect(bool value) {
    _autoReconnect = value;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    for (final sub in _notifySubscriptions) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
    _connectionSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateController.close();
    _dataController.close();
  }
}

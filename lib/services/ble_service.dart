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
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
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

      // Discover services and automatically find TX/RX characteristics
      final services = await device.discoverServices();
      bool foundAnyNotify = false;
      
      for (final service in services) {
        for (final char in service.characteristics) {
          // If we can listen to it, subscribe to it!
          if (char.properties.notify || char.properties.indicate) {
            try {
              await char.setNotifyValue(true);
              _notifySubscription?.cancel(); // keep only the latest or you could list them
              _notifySubscription = char.onValueReceived.listen((data) {
                _dataController.add(data);
              });
              foundAnyNotify = true;
              debugPrint('BLE: Subscribed to Notify characteristic: ${char.uuid}');
            } catch (e) {
              debugPrint('BLE: Failed to subscribe to ${char.uuid}: $e');
            }
          }
          
          // If we can write to it without response (standard for fast BMS polling)
          // or with response, save it as our write characteristic
          if (char.properties.writeWithoutResponse || char.properties.write) {
            _notifyCharacteristic = char; // we'll use this for writing
            debugPrint('BLE: Found Write characteristic: ${char.uuid}');
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
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _notifyCharacteristic = null;
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
      _notifySubscription?.cancel();
      _connectionSubscription?.cancel();
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('BLE Disconnect error: $e');
    }
    
    _connectedDevice = null;
    _notifyCharacteristic = null;
    _updateState(BleConnectionState.disconnected);
  }

  Future<void> writeData(List<int> data) async {
    if (_notifyCharacteristic == null) return;
    try {
      await _notifyCharacteristic!.write(data, withoutResponse: true);
    } catch (e) {
      debugPrint('BLE Write error: $e');
    }
  }

  void setAutoReconnect(bool value) {
    _autoReconnect = value;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateController.close();
    _dataController.close();
  }
}

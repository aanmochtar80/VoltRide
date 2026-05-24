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

  void _updateState(BleConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  Future<List<ScanResult>> scanDevices({Duration timeout = const Duration(seconds: 5)}) async {
    _updateState(BleConnectionState.scanning);
    
    final results = <ScanResult>[];
    
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      
      await for (final scanResults in FlutterBluePlus.scanResults) {
        results.clear();
        results.addAll(scanResults);
      }
    } catch (e) {
      debugPrint('BLE Scan error: $e');
    }
    
    if (_state == BleConnectionState.scanning) {
      _updateState(BleConnectionState.disconnected);
    }
    
    return results;
  }

  Stream<List<ScanResult>> scanStream({Duration timeout = const Duration(seconds: 10)}) {
    _updateState(BleConnectionState.scanning);
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    if (_state == BleConnectionState.scanning) {
      _updateState(BleConnectionState.disconnected);
    }
  }

  Future<bool> connectToDevice(
    BluetoothDevice device, {
    String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb',
    String characteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb',
  }) async {
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

      // Discover services
      final services = await device.discoverServices();
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _notifyCharacteristic = char;
              
              // Enable notifications
              await char.setNotifyValue(true);
              _notifySubscription?.cancel();
              _notifySubscription = char.onValueReceived.listen((data) {
                _dataController.add(data);
              });
              
              _updateState(BleConnectionState.connected);
              return true;
            }
          }
        }
      }

      // Service/characteristic not found, but still connected
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
    _connectionStateController.close();
    _dataController.close();
  }
}

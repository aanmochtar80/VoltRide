import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:voltride/models/bms_data.dart';
import 'package:voltride/services/ble_service.dart';

/// JK-BMS Protocol Parser and Service
/// Supports JK-B1A8S, JK-B2A8S, and similar models
/// Falls back to dummy/simulation data when no BMS is connected
class JkBmsService {
  final BleService _bleService;
  final _dataController = StreamController<BmsData>.broadcast();
  final _rawHexController = StreamController<String>.broadcast();
  StreamSubscription<List<int>>? _dataSubscription;
  Timer? _dummyTimer;
  Timer? _pollingTimer;
  
  BmsData _lastData = BmsData.empty();
  bool _useDummyData = false;
  final List<int> _buffer = [];

  Stream<BmsData> get bmsDataStream => _dataController.stream;
  Stream<String> get rawHexStream => _rawHexController.stream;
  BmsData get lastData => _lastData;
  bool get isUsingDummyData => _useDummyData;

  JkBmsService(this._bleService);

  /// Start listening to BLE data and parse JK-BMS protocol
  void startListening() {
    _dataSubscription?.cancel();
    _dataSubscription = _bleService.dataStream.listen((data) {
      if (data.isNotEmpty) {
        String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _rawHexController.add(hex);
        debugPrint('BMS Raw Data: ${data.length} bytes (First byte: ${data[0]})');
      }
      _buffer.addAll(data);
      _tryParseFrame();
    });

    // Start polling the BMS every 1.5 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_bleService.isConnected) {
        _bleService.writeData(JkBmsService.buildReadCommand());
      }
    });
  }

  /// Start dummy/simulation mode for development
  void startDummyMode() {
    _useDummyData = true;
    _dummyTimer?.cancel();
    
    final random = Random();
    double speed = 0;
    double soc = 85.0;
    
    _dummyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate realistic EV battery data
      speed = (speed + (random.nextDouble() - 0.3) * 5).clamp(0.0, 80.0);
      final current = speed > 0 ? -(speed * 0.3 + random.nextDouble() * 5) : 0.0;
      final voltage = 48.0 + random.nextDouble() * 6 + (soc / 100) * 4;
      final power = (voltage * current.abs());
      soc = (soc + current * 0.001).clamp(0.0, 100.0);
      
      final cellCount = 16;
      final baseVoltage = voltage / cellCount;
      
      final data = BmsData(
        voltageTotal: double.parse(voltage.toStringAsFixed(1)),
        current: double.parse(current.toStringAsFixed(1)),
        soc: double.parse(soc.toStringAsFixed(1)),
        capacityRemaining: double.parse((soc / 100 * 20).toStringAsFixed(1)),
        capacityTotal: 20.0,
        powerWatt: double.parse(power.toStringAsFixed(0)),
        cellVoltages: List.generate(
          cellCount,
          (i) => double.parse(
            (baseVoltage + (random.nextDouble() - 0.5) * 0.02).toStringAsFixed(3),
          ),
        ),
        temperatures: [
          double.parse((25 + random.nextDouble() * 8).toStringAsFixed(1)),
          double.parse((24 + random.nextDouble() * 9).toStringAsFixed(1)),
          double.parse((26 + random.nextDouble() * 7).toStringAsFixed(1)),
        ],
        isCharging: current > 0,
        isDischarging: current < 0,
        cycleCount: 142,
        timestamp: DateTime.now(),
      );
      
      _lastData = data;
      _dataController.add(data);
    });
  }

  /// Stop dummy mode
  void stopDummyMode() {
    _useDummyData = false;
    _dummyTimer?.cancel();
    _dummyTimer = null;
  }

  /// Try to parse a complete JK-BMS frame from the buffer
  void _tryParseFrame() {
    // JK-BMS frame format:
    // Header: 0x4E 0x57 (NW)
    // Length: 2 bytes
    // Data...
    // Checksum
    
    while (_buffer.length >= 4) {
      // Find frame header 0x4E57
      int headerIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0x4E && _buffer[i + 1] == 0x57) {
          headerIndex = i;
          break;
        }
      }

      if (headerIndex == -1) {
        _buffer.clear();
        return;
      }

      if (headerIndex > 0) {
        _buffer.removeRange(0, headerIndex);
      }

      if (_buffer.length < 4) return;

      // Get frame length
      final frameLen = (_buffer[2] << 8) | _buffer[3];
      if (_buffer.length < frameLen) return;

      // Extract frame
      final frame = _buffer.sublist(0, frameLen);
      _buffer.removeRange(0, frameLen);

      // Parse the frame data
      _parseJkBmsFrame(Uint8List.fromList(frame));
    }
  }

  /// Parse JK-BMS response frame
  void _parseJkBmsFrame(Uint8List frame) {
    try {
      if (frame.length < 11) return;

      double voltage = 0;
      double current = 0;
      double soc = 0;
      double capacity = 0;
      double capacityTotal = 0;
      List<double> cellVoltages = [];
      List<double> temperatures = [];
      bool isCharging = false;
      bool isDischarging = false;
      int cycleCount = 0;

      int offset = 11; // Skip header + terminal info

      while (offset < frame.length - 1) {
        if (offset >= frame.length) break;
        
        final tag = frame[offset];
        offset++;

        switch (tag) {
          case 0x79: // Cell voltages
            if (offset >= frame.length) break;
            final cellCount = frame[offset] ~/ 3;
            offset++;
            for (int i = 0; i < cellCount && offset + 1 < frame.length; i++) {
              final cellIndex = frame[offset];
              final cellMv = (frame[offset + 1] << 8) | frame[offset + 2];
              cellVoltages.add(cellMv / 1000.0);
              offset += 3;
            }
            break;

          case 0x80: // Tube temperature
          case 0x81: // Battery temp 1  
          case 0x82: // Battery temp 2
            if (offset + 1 < frame.length) {
              final raw = (frame[offset] << 8) | frame[offset + 1];
              final temp = (raw > 100) ? raw - 100 : raw.toDouble();
              temperatures.add(temp.toDouble());
              offset += 2;
            }
            break;

          case 0x83: // Total voltage
            if (offset + 1 < frame.length) {
              voltage = ((frame[offset] << 8) | frame[offset + 1]) / 100.0;
              offset += 2;
            }
            break;

          case 0x84: // Current
            if (offset + 1 < frame.length) {
              final raw = (frame[offset] << 8) | frame[offset + 1];
              current = (raw > 32768) ? (raw - 65536) / 100.0 : raw / 100.0;
              isCharging = current > 0;
              isDischarging = current < 0;
              offset += 2;
            }
            break;

          case 0x85: // SOC
            if (offset < frame.length) {
              soc = frame[offset].toDouble();
              offset++;
            }
            break;

          case 0x86: // Number of temp sensors
            if (offset < frame.length) {
              offset++;
            }
            break;

          case 0x87: // Cycle count
            if (offset + 1 < frame.length) {
              cycleCount = (frame[offset] << 8) | frame[offset + 1];
              offset += 2;
            }
            break;

          case 0x89: // Total capacity
            if (offset + 3 < frame.length) {
              capacityTotal = ((frame[offset] << 24) |
                      (frame[offset + 1] << 16) |
                      (frame[offset + 2] << 8) |
                      frame[offset + 3]) /
                  1000.0;
              offset += 4;
            }
            break;

          default:
            // Skip unknown tags - try to advance
            offset++;
            break;
        }
      }

      capacity = capacityTotal * soc / 100.0;
      final power = voltage * current.abs();

      final bmsData = BmsData(
        voltageTotal: voltage,
        current: current,
        soc: soc,
        capacityRemaining: capacity,
        capacityTotal: capacityTotal,
        powerWatt: power,
        cellVoltages: cellVoltages,
        temperatures: temperatures,
        isCharging: isCharging,
        isDischarging: isDischarging,
        cycleCount: cycleCount,
        timestamp: DateTime.now(),
      );

      _lastData = bmsData;
      _dataController.add(bmsData);
    } catch (e) {
      debugPrint('JK-BMS Parse error: $e');
    }
  }

  /// Build JK-BMS read command
  static List<int> buildReadCommand() {
    // JK-BMS read all data command
    return [
      0x4E, 0x57, // Header
      0x00, 0x13, // Length
      0x00, 0x00, 0x00, 0x00, // Terminal number
      0x06, // Command: read all
      0x03, // Frame source: BMS
      0x00, // Transport type
      0x00, 0x00, 0x00, 0x00, // Record number
      0x00, 0x00, 0x00, 0x00, // End marker
      0x68, // Checksum
    ];
  }

  void stopListening() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stopListening();
    stopDummyMode();
    _dataController.close();
  }
}

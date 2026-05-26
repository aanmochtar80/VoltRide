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
    int _pollStep = 0;
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_bleService.isConnected) return;
      
      // Cycle through different known JK BMS polling commands
      switch (_pollStep % 11) {
        case 0:
          _bleService.writeData(JkBmsService.buildLegacyReadCommand(0x97)); // Init AA55
          break;
        case 1:
          _bleService.writeData(JkBmsService.buildLegacyReadCommand(0x96)); // Cell Info AA55
          break;
        case 2:
          _bleService.writeData(JkBmsService.buildLegacyReadCommand(0x95)); // Old All Data AA55
          break;
        case 3:
          _bleService.writeData(JkBmsService.buildLegacyL1V1Command(0x95)); // L1V1 AA55
          break;
        case 4:
          _bleService.writeData(JkBmsService.buildLegacyReverseReadCommand(0x97)); // Init 55AA
          break;
        case 5:
          _bleService.writeData(JkBmsService.buildLegacyReverseReadCommand(0x96)); // Cell Info 55AA
          break;
        case 6:
          _bleService.writeData(JkBmsService.buildLegacyReverseReadCommand(0x95)); // Old All Data 55AA
          break;
        case 7:
          _bleService.writeData([0x55, 0xAA, 0x00, 0xFF, 0x00, 0x00, 0xFE]); // Short RS485 Addr 0
          break;
        case 8:
          _bleService.writeData([0x55, 0xAA, 0x01, 0xFF, 0x00, 0x00, 0xFF]); // Short RS485 Addr 1
          break;
        case 9:
          _bleService.writeData([0x55, 0xAA, 0x10, 0xFF, 0x00, 0x00, 0x0E]); // Short RS485 Addr 16
          break;
        case 10:
          _bleService.writeData(JkBmsService.buildReadCommand()); // Modern 4E 57
          break;
      }
      _pollStep++;
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
    while (_buffer.length >= 4) {
      // Find frame header 0x4E57 (Modern) or 0x55AA (Legacy)
      int headerIndex = -1;
      bool isLegacy = false;
      
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0x4E && _buffer[i + 1] == 0x57) {
          headerIndex = i;
          isLegacy = false;
          break;
        }
        if (i < _buffer.length - 3 && 
            _buffer[i] == 0x55 && _buffer[i + 1] == 0xAA && 
            _buffer[i + 2] == 0xEB && _buffer[i + 3] == 0x90) {
          headerIndex = i;
          isLegacy = true;
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

      if (isLegacy) {
        if (_buffer.length < 300) return; // Legacy frame is always exactly 300 bytes
        final frame = _buffer.sublist(0, 300);
        _buffer.removeRange(0, 300);
        _parseLegacyJkBmsFrame(Uint8List.fromList(frame));
      } else {
        if (_buffer.length < 4) return;
        // Get frame length for modern protocol
        final frameLen = (_buffer[2] << 8) | _buffer[3];
        if (_buffer.length < frameLen) return;
        final frame = _buffer.sublist(0, frameLen);
        _buffer.removeRange(0, frameLen);
        _parseJkBmsFrame(Uint8List.fromList(frame));
      }
    }
  }

  void _parseLegacyJkBmsFrame(Uint8List frame) {
    if (frame.length < 300) return;
    
    // Verify CRC
    int crc = 0;
    for (int i = 0; i < 299; i++) {
      crc = (crc + frame[i]) & 0xFF;
    }
    if (crc != frame[299]) {
      debugPrint('Legacy JK-BMS CRC failed');
      return;
    }

    int frameType = frame[4];
    if (frameType != 0x02) return; // Only process cell info frame

    try {
      int get16(int i) => (frame[i + 1] << 8) | frame[i];
      int get32(int i) => (frame[i + 3] << 24) | (frame[i + 2] << 16) | (frame[i + 1] << 8) | frame[i];

      // Voltages
      List<double> cellVoltages = [];
      for (int i = 0; i < 24; i++) {
        int mv = get16(6 + i * 2);
        if (mv > 0) cellVoltages.add(mv / 1000.0);
      }

      double voltage = get32(118) * 0.001;
      if (cellVoltages.isNotEmpty) {
        double cellSum = cellVoltages.reduce((a, b) => a + b);
        // Validasi voltase total terhadap jumlah sel (bug di BMS lawas)
        if (voltage < 0.5 || voltage > cellVoltages.length * 4.5 || (voltage - cellSum).abs() > 5.0) {
          voltage = cellSum;
        }
      }

      double current = 0;
      double soc = 0;
      double capacity = 0;
      double capacityTotal = 0;
      int cycleCount = 0;
      double tempMos = 0;
      double temp1 = 0;
      double temp2 = 0;
      bool isCharging = false;
      bool isDischarging = false;

      // Detect firmware variant
      bool variantLayout = (frame[173] > 0 && frame[173] <= 100 && get32(174) > 1000 && get32(178) > 1000);

      if (variantLayout) {
        int curRaw = get32(158);
        if (curRaw > 0x7FFFFFFF) curRaw -= 0x100000000;
        current = curRaw * 0.001;

        soc = frame[173].toDouble();
        capacity = get32(174) * 0.001;
        capacityTotal = get32(178) * 0.001;
        cycleCount = get32(182);

        int mosRaw = get16(144);
        if (mosRaw > 0x7FFF) mosRaw -= 0x10000;
        tempMos = mosRaw * 0.1;

        int t1Raw = get16(162);
        if (t1Raw > 0x7FFF) t1Raw -= 0x10000;
        temp1 = t1Raw * 0.1;

        int t2Raw = get16(164);
        if (t2Raw > 0x7FFF) t2Raw -= 0x10000;
        temp2 = t2Raw * 0.1;

        isCharging = frame[198] != 0;
        isDischarging = frame[199] != 0;
      } else {
        int curRaw = get32(126); // Default layout uses 32-bit
        if (curRaw > 0x7FFFFFFF) curRaw -= 0x100000000;
        current = curRaw * 0.001;

        soc = frame[141].toDouble();
        capacity = get32(142) * 0.001;
        capacityTotal = get32(146) * 0.001;
        cycleCount = get32(150);

        int mosRaw = get16(134);
        if (mosRaw > 0x7FFF) mosRaw -= 0x10000;
        tempMos = mosRaw * 0.1;

        int b1Raw = get16(130);
        if (b1Raw > 0x7FFF) b1Raw -= 0x10000;
        temp1 = b1Raw * 0.1;

        int b2Raw = get16(132);
        if (b2Raw > 0x7FFF) b2Raw -= 0x10000;
        temp2 = b2Raw * 0.1;

        isCharging = frame[166] != 0;
        isDischarging = frame[167] != 0;
      }

      if (current.abs() < 0.05) current = 0;

      final bmsData = BmsData(
        voltageTotal: voltage,
        current: current,
        soc: soc,
        capacityRemaining: capacity,
        capacityTotal: capacityTotal,
        powerWatt: voltage * current.abs(),
        cellVoltages: cellVoltages,
        temperatures: [tempMos, temp1, temp2],
        isCharging: isCharging,
        isDischarging: isDischarging,
        cycleCount: cycleCount,
        timestamp: DateTime.now(),
      );

      _lastData = bmsData;
      _dataController.add(bmsData);
    } catch (e) {
      debugPrint('Legacy JK-BMS Parse error: $e');
    }
  }
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

  static List<int> buildReadCommand() {
    // JK-BMS read all data command (exact 21 bytes protocol)
    return [
      0x4E, 0x57, // Header
      0x00, 0x13, // Length (19 bytes)
      0x00, 0x00, 0x00, 0x00, // BMS Terminal number
      0x06, // Command: Read all data
      0x03, // Frame source: PC/Host
      0x00, // TX Type
      0x00, 0x00, 0x00, 0x00, // Record number
      0x00, 0x00, 0x00, 0x00, // Reserved
      0x68, // End Flag
      0x00, 0x00, 0x01, 0x29, // Calculated Checksum
    ];
  }

  /// Build legacy JK-BMS read command (AA 55 90 EB)
  static List<int> buildLegacyReadCommand(int command) {
    List<int> frame = [
      0xAA, 0x55, 0x90, 0xEB, command, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00 // index 19 will be checksum
    ];
    
    int crc = 0;
    for (int i = 0; i < 19; i++) {
      crc = (crc + frame[i]) & 0xFF;
    }
    frame[19] = crc;
    return frame;
  }

  static List<int> buildLegacyReverseReadCommand(int command) {
    List<int> frame = [
      0x55, 0xAA, 0xEB, 0x90, command, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00 // index 19 will be checksum
    ];
    
    int crc = 0;
    for (int i = 0; i < 19; i++) {
      crc = (crc + frame[i]) & 0xFF;
    }
    frame[19] = crc;
    return frame;
  }

  static List<int> buildLegacyL1V1Command(int command) {
    List<int> frame = [
      0xAA, 0x55, 0x90, 0xEB, command, 0x01,
      0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00 // index 19 will be checksum
    ];
    
    int crc = 0;
    for (int i = 0; i < 19; i++) {
      crc = (crc + frame[i]) & 0xFF;
    }
    frame[19] = crc;
    return frame;
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

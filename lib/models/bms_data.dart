class BmsData {
  final double voltageTotal;
  final double current;
  final double soc;
  final double capacityRemaining;
  final double capacityTotal;
  final double powerWatt;
  final List<double> cellVoltages;
  final List<double> temperatures;
  final bool isCharging;
  final bool isDischarging;
  final int cycleCount;
  final DateTime timestamp;

  const BmsData({
    this.voltageTotal = 0.0,
    this.current = 0.0,
    this.soc = 0.0,
    this.capacityRemaining = 0.0,
    this.capacityTotal = 0.0,
    this.powerWatt = 0.0,
    this.cellVoltages = const [],
    this.temperatures = const [],
    this.isCharging = false,
    this.isDischarging = false,
    this.cycleCount = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _DefaultDateTime();

  factory BmsData.empty() {
    return BmsData(timestamp: DateTime.now());
  }

  factory BmsData.dummy() {
    return BmsData(
      voltageTotal: 52.4,
      current: -12.5,
      soc: 78.0,
      capacityRemaining: 15.6,
      capacityTotal: 20.0,
      powerWatt: 655.0,
      cellVoltages: List.generate(16, (i) => 3.27 + (i % 3) * 0.01),
      temperatures: [28.5, 29.0, 27.8],
      isCharging: false,
      isDischarging: true,
      cycleCount: 142,
      timestamp: DateTime.now(),
    );
  }

  double get minCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a < b ? a : b);

  double get maxCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a > b ? a : b);

  double get cellDelta => maxCellVoltage - minCellVoltage;

  double get avgTemperature =>
      temperatures.isEmpty
          ? 0
          : temperatures.reduce((a, b) => a + b) / temperatures.length;

  String get statusText {
    if (isCharging) return 'Charging';
    if (isDischarging) return 'Discharging';
    return 'Idle';
  }

  BmsData copyWith({
    double? voltageTotal,
    double? current,
    double? soc,
    double? capacityRemaining,
    double? capacityTotal,
    double? powerWatt,
    List<double>? cellVoltages,
    List<double>? temperatures,
    bool? isCharging,
    bool? isDischarging,
    int? cycleCount,
    DateTime? timestamp,
  }) {
    return BmsData(
      voltageTotal: voltageTotal ?? this.voltageTotal,
      current: current ?? this.current,
      soc: soc ?? this.soc,
      capacityRemaining: capacityRemaining ?? this.capacityRemaining,
      capacityTotal: capacityTotal ?? this.capacityTotal,
      powerWatt: powerWatt ?? this.powerWatt,
      cellVoltages: cellVoltages ?? this.cellVoltages,
      temperatures: temperatures ?? this.temperatures,
      isCharging: isCharging ?? this.isCharging,
      isDischarging: isDischarging ?? this.isDischarging,
      cycleCount: cycleCount ?? this.cycleCount,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now().noSuchMethod(invocation);
}

class SensorData {
  final double soilMoisturePct;
  final double airTempC;
  final double humidityPct;
  final double lightLux;
  final double waterLevelCm;
  final double soilTempC;
  final bool pumpRunning;
  final DateTime lastUpdated;

  const SensorData({
    required this.soilMoisturePct,
    required this.airTempC,
    required this.humidityPct,
    required this.lightLux,
    required this.waterLevelCm,
    required this.soilTempC,
    required this.pumpRunning,
    required this.lastUpdated,
  });

  factory SensorData.fromMap(Map<dynamic, dynamic> map) {
    return SensorData(
      soilMoisturePct: (map['soilMoisture'] as num?)?.toDouble() ?? 0,
      airTempC: (map['airTemp'] as num?)?.toDouble() ?? 0,
      humidityPct: (map['humidity'] as num?)?.toDouble() ?? 0,
      lightLux: (map['lightLux'] as num?)?.toDouble() ?? 0,
      waterLevelCm: (map['waterLevelCm'] as num?)?.toDouble() ?? 0,
      soilTempC: (map['soilTemp'] as num?)?.toDouble() ?? 0,
      pumpRunning: (map['pumpStatus'] as bool?) ?? false,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'soilMoisture': soilMoisturePct,
        'airTemp': airTempC,
        'humidity': humidityPct,
        'lightLux': lightLux,
        'waterLevelCm': waterLevelCm,
        'soilTemp': soilTempC,
        'pumpStatus': pumpRunning,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      };

  SensorData copyWith({bool? pumpRunning}) => SensorData(
        soilMoisturePct: soilMoisturePct,
        airTempC: airTempC,
        humidityPct: humidityPct,
        lightLux: lightLux,
        waterLevelCm: waterLevelCm,
        soilTempC: soilTempC,
        pumpRunning: pumpRunning ?? this.pumpRunning,
        lastUpdated: lastUpdated,
      );
}

class SensorHistory {
  final DateTime timestamp;
  final double value;

  const SensorHistory({required this.timestamp, required this.value});
}

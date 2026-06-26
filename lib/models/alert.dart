enum AlertType { lowWater, drysoil, highTemp, lowLight, pumpOn, pumpOff, info }

class PlantAlert {
  final String id;
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final bool read;

  const PlantAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.read,
  });

  factory PlantAlert.fromMap(String id, Map<dynamic, dynamic> map) {
    return PlantAlert(
      id: id,
      type: _typeFromString(map['type'] as String? ?? 'info'),
      message: (map['message'] as String?) ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt())
          : DateTime.now(),
      read: (map['read'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'message': message,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'read': read,
      };

  static AlertType _typeFromString(String s) {
    return AlertType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AlertType.info,
    );
  }

  String get icon {
    switch (type) {
      case AlertType.lowWater:
        return '💧';
      case AlertType.drysoil:
        return '🌱';
      case AlertType.highTemp:
        return '🌡️';
      case AlertType.lowLight:
        return '☀️';
      case AlertType.pumpOn:
        return '🚰';
      case AlertType.pumpOff:
        return '🔴';
      case AlertType.info:
        return 'ℹ️';
    }
  }
}

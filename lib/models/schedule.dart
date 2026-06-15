class WateringSchedule {
  final String id;
  final String name;
  final int hour;
  final int minute;
  final int durationSeconds;
  final List<int> days; // 1=Mon … 7=Sun (ISO weekday)
  final bool enabled;

  const WateringSchedule({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.durationSeconds,
    required this.days,
    required this.enabled,
  });

  factory WateringSchedule.fromMap(String id, Map<dynamic, dynamic> map) {
    return WateringSchedule(
      id: id,
      name: (map['name'] as String?) ?? 'Schedule',
      hour: (map['hour'] as num?)?.toInt() ?? 8,
      minute: (map['minute'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 30,
      days: (map['days'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      enabled: (map['enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'hour': hour,
        'minute': minute,
        'durationSeconds': durationSeconds,
        'days': days,
        'enabled': enabled,
      };

  WateringSchedule copyWith({
    String? name,
    int? hour,
    int? minute,
    int? durationSeconds,
    List<int>? days,
    bool? enabled,
  }) =>
      WateringSchedule(
        id: id,
        name: name ?? this.name,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
      );

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get daysString {
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    if (days.toSet().containsAll({1, 2, 3, 4, 5}) && days.length == 5) return 'Weekdays';
    if (days.toSet().containsAll({6, 7}) && days.length == 2) return 'Weekends';
    return days.map((d) => names[d]).join(', ');
  }
}

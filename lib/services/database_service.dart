import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/sensor_data.dart';
import '../models/schedule.dart';
import '../models/alert.dart';
import 'auth_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  String get _uid => AuthService.instance.uid!;

  // ─── Sensor Data ───────────────────────────────────────────────────────────

  Stream<SensorData?> sensorStream() {
    return _db
        .ref('sensors/$_uid/latest')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return SensorData.fromMap(data as Map<dynamic, dynamic>);
    });
  }

  Future<List<SensorHistory>> fetchHistory(String field, {int limitHours = 24}) async {
    // Fetch latest 100 entries without orderByChild to avoid index requirement
    final snap = await _db
        .ref('sensors/$_uid/history')
        .limitToLast(100)
        .get();

    if (!snap.exists) return [];

    final since = DateTime.now()
        .subtract(Duration(hours: limitHours))
        .millisecondsSinceEpoch;

    final list = <SensorHistory>[];
    for (final child in snap.children) {
      final map = child.value as Map<dynamic, dynamic>;
      final ts = (map['lastUpdated'] as num?)?.toInt() ?? 0;
      if (ts < since) continue;
      final val = (map[field] as num?)?.toDouble();
      if (val != null) {
        list.add(SensorHistory(
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          value: val,
        ));
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  // ─── Pump Control ──────────────────────────────────────────────────────────

  Future<void> setPumpCommand(String command) async {
    // command: "on" | "off" | "auto"
    await _db.ref('pump/$_uid/command').set(command);
    await _db.ref('pump/$_uid/updatedAt').set(DateTime.now().millisecondsSinceEpoch);
  }

  Stream<String> pumpCommandStream() {
    return _db.ref('pump/$_uid/command').onValue.map(
      (event) => (event.snapshot.value as String?) ?? 'off',
    );
  }

  // ─── Schedules ─────────────────────────────────────────────────────────────

  Stream<List<WateringSchedule>> schedulesStream() {
    return _db.ref('schedules/$_uid').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => WateringSchedule.fromMap(
                e.key as String,
                e.value as Map<dynamic, dynamic>,
              ))
          .toList()
        ..sort((a, b) => a.hour == b.hour
            ? a.minute.compareTo(b.minute)
            : a.hour.compareTo(b.hour));
    });
  }

  Future<void> addSchedule(WateringSchedule schedule) async {
    final id = _uuid.v4();
    await _db.ref('schedules/$_uid/$id').set(schedule.toMap());
  }

  Future<void> updateSchedule(WateringSchedule schedule) async {
    await _db.ref('schedules/$_uid/${schedule.id}').set(schedule.toMap());
  }

  Future<void> deleteSchedule(String id) async {
    await _db.ref('schedules/$_uid/$id').remove();
  }

  Future<void> toggleSchedule(String id, bool enabled) async {
    await _db.ref('schedules/$_uid/$id/enabled').set(enabled);
  }

  // ─── Alerts ────────────────────────────────────────────────────────────────

  Stream<List<PlantAlert>> alertsStream() {
    return _db
        .ref('alerts/$_uid')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => PlantAlert.fromMap(
                e.key as String,
                e.value as Map<dynamic, dynamic>,
              ))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> markAlertRead(String id) async {
    await _db.ref('alerts/$_uid/$id/read').set(true);
  }

  Future<void> markAllAlertsRead() async {
    final snap = await _db.ref('alerts/$_uid').get();
    if (!snap.exists) return;
    final map = snap.value as Map<dynamic, dynamic>;
    final updates = <String, dynamic>{};
    for (final key in map.keys) {
      updates['alerts/$_uid/$key/read'] = true;
    }
    await _db.ref().update(updates);
  }

  Future<int> unreadAlertsCount() async {
    final snap = await _db
        .ref('alerts/$_uid')
        .orderByChild('read')
        .equalTo(false)
        .get();
    return snap.children.length;
  }

  Stream<int> unreadAlertsCountStream() {
    return _db
        .ref('alerts/$_uid')
        .orderByChild('read')
        .equalTo(false)
        .onValue
        .map((event) => event.snapshot.children.length);
  }

  // ─── User Profile ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile() async {
    final snap = await _db.ref('users/$_uid/profile').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<void> updateUserName(String name) async {
    await _db.ref('users/$_uid/profile/name').set(name);
  }

  // ─── Thresholds ────────────────────────────────────────────────────────────

  static const Map<String, dynamic> defaultThresholds = {
    'soilDry': 30.0,
    'waterLow': 5.0,
    'tempHigh': 35.0,
  };

  Future<Map<String, dynamic>> getThresholds() async {
    final snap = await _db.ref('users/$_uid/settings/thresholds').get();
    if (!snap.exists) return Map<String, dynamic>.from(defaultThresholds);
    final data = Map<String, dynamic>.from(snap.value as Map);
    return {
      'soilDry':  (data['soilDry']  as num?)?.toDouble() ?? 30.0,
      'waterLow': (data['waterLow'] as num?)?.toDouble() ?? 5.0,
      'tempHigh': (data['tempHigh'] as num?)?.toDouble() ?? 35.0,
    };
  }

  Stream<Map<String, dynamic>> thresholdsStream() {
    return _db.ref('users/$_uid/settings/thresholds').onValue.map((event) {
      if (!event.snapshot.exists) return Map<String, dynamic>.from(defaultThresholds);
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return {
        'soilDry':  (data['soilDry']  as num?)?.toDouble() ?? 30.0,
        'waterLow': (data['waterLow'] as num?)?.toDouble() ?? 5.0,
        'tempHigh': (data['tempHigh'] as num?)?.toDouble() ?? 35.0,
      };
    });
  }

  Future<void> updateThreshold(String key, double value) async {
    await _db.ref('users/$_uid/settings/thresholds/$key').set(value);
  }

  // ─── Tank Calibration ──────────────────────────────────────────────────────

  Future<void> triggerCalibration() async {
    await _db.ref('calibration/$_uid/calibrateNow').set(true);
    await _db.ref('calibration/$_uid/requestedAt')
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  Stream<Map<String, dynamic>?> calibrationStream() {
    return _db.ref('calibration/$_uid').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}

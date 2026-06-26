import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/schedule.dart';
import '../models/alert.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;

  SensorData? _sensorData;
  List<WateringSchedule> _schedules = [];
  List<PlantAlert> _alerts = [];
  String _pumpCommand = 'auto';
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  SensorData? get sensorData => _sensorData;
  List<WateringSchedule> get schedules => _schedules;
  List<PlantAlert> get alerts => _alerts;
  String get pumpCommand => _pumpCommand;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  String? get error => _error;

  StreamSubscription? _sensorSub;
  StreamSubscription? _scheduleSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _pumpSub;
  StreamSubscription? _unreadSub;

  void startListening() {
    _loading = true;
    _error = null;

    _sensorSub = _db.sensorStream().listen(
      (data) {
        _sensorData = data;
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );

    _scheduleSub = _db.schedulesStream().listen((list) {
      _schedules = list;
      notifyListeners();
    });

    _alertSub = _db.alertsStream().listen((list) {
      // Show local notification when a new alert arrives
      if (_alerts.isNotEmpty && list.length > _alerts.length) {
        final newest = list.first;
        NotificationService.instance.showLocalAlert(
          '${newest.icon} Smart Plant Alert',
          newest.message,
        );
      }
      _alerts = list;
      notifyListeners();
    });

    _pumpSub = _db.pumpCommandStream().listen((cmd) {
      _pumpCommand = cmd;
      notifyListeners();
    });

    _unreadSub = _db.unreadAlertsCountStream().listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  void stopListening() {
    _sensorSub?.cancel();
    _scheduleSub?.cancel();
    _alertSub?.cancel();
    _pumpSub?.cancel();
    _unreadSub?.cancel();
  }

  Future<void> setPump(String command) async {
    await _db.setPumpCommand(command);
  }

  Future<void> addSchedule(WateringSchedule s) => _db.addSchedule(s);
  Future<void> updateSchedule(WateringSchedule s) => _db.updateSchedule(s);
  Future<void> deleteSchedule(String id) => _db.deleteSchedule(id);
  Future<void> toggleSchedule(String id, bool enabled) =>
      _db.toggleSchedule(id, enabled);

  Future<void> markAlertRead(String id) => _db.markAlertRead(id);
  Future<void> markAllRead() => _db.markAllAlertsRead();

  Future<List<SensorHistory>> fetchHistory(String field) =>
      _db.fetchHistory(field);

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

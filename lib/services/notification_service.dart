import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance._showLocalNotification(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Android notification channel
    const channel = AndroidNotificationChannel(
      'plant_alerts',
      'Plant Alerts',
      description: 'Smart plant monitoring alerts',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(initSettings);

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) await AuthService.instance.saveFcmToken(token);

      _fcm.onTokenRefresh.listen(AuthService.instance.saveFcmToken);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> showLocalAlert(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'plant_alerts',
        'Plant Alerts',
        channelDescription: 'Smart plant monitoring alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'plant_alerts',
        'Plant Alerts',
        channelDescription: 'Smart plant monitoring alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}

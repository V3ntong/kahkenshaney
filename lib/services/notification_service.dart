import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('[NotificationService] Permission denied by user');
      return;
    }

    final token = await _messaging.getToken();
    debugPrint('[NotificationService] FCM Token: $token');

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[NotificationService] FCM Token refreshed: $newToken');
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[NotificationService] Foreground message: '
        '${message.notification?.title} - ${message.notification?.body}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[NotificationService] Notification tapped (background): '
        '${message.notification?.title}',
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[NotificationService] Notification opened from terminated: '
        '${initialMessage.notification?.title}',
      );
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// The most recent push notification received while the app was in the
  /// foreground. Widgets (e.g. [NotificationBannerHost]) listen to this to
  /// surface the message as an in-app banner. Static so any instance can
  /// publish and any widget can subscribe without sharing state manually.
  static final ValueNotifier<RemoteMessage?> lastForegroundMessage =
      ValueNotifier<RemoteMessage?>(null);
  /// Initializes notification permissions, saves FCM token to Firestore,
  /// and sets up message listeners.
  ///
  /// Call this after the user logs in with their [userId].
  Future<void> initialize({String? userId}) async {
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

    // Save token to Firestore if userId is provided
    if (userId != null && token != null) {
      await _saveTokenToFirestore(userId, token);
    }

    // Listen for token refresh and update Firestore
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[NotificationService] FCM Token refreshed: $newToken');
      if (userId != null) {
        await _saveTokenToFirestore(userId, newToken);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[NotificationService] Foreground message: '
        '${message.notification?.title} - ${message.notification?.body}',
      );
      // Surface the message to the UI so an in-app banner can be shown.
      lastForegroundMessage.value = message;
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

  /// Saves or updates the FCM token in the user's Firestore document.
  ///
  /// Uses arrayUnion to add the token if it doesn't already exist.
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      debugPrint('[NotificationService] FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error saving FCM token: $e');
    }
  }
}

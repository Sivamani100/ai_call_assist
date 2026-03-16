// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission for notifications
    await FirebaseMessaging.instance.requestPermission();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Handle background messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'New Call',
        body: notification.body ?? 'You received a call',
        payload: message.data['call_log_id'],
      );
    }
  }

  static void _onNotificationOpened(RemoteMessage message) {
    // Handle when user taps on notification
    final callLogId = message.data['call_log_id'];
    if (callLogId != null) {
      // This will be handled by the router in main.dart
      // For now, just mark as read in database
      _markCallAsRead(callLogId);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final callLogId = response.payload;
    if (callLogId != null) {
      _markCallAsRead(callLogId);
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ai_call_channel',
      'AI Call Assistant',
      channelDescription: 'Notifications for AI answered calls',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> _markCallAsRead(String callLogId) async {
    try {
      await Supabase.instance.client
          .from('call_logs')
          .update({'status': 'read'})
          .eq('id', callLogId);
    } catch (e) {
      print('Error marking call as read: $e');
    }
  }
}

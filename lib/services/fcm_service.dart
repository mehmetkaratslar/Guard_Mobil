// 📄 Dosya: fcm_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama: Firebase Cloud Messaging servis sınıfı
// 🔗 Bağlantılı: main.dart, notifications_screen.dart

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Singleton pattern
  factory FCMService() {
    return _instance;
  }

  FCMService._internal();

  // Initialize FCM service
  Future<void> init() async {
    // Request permission for iOS devices
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    // Configure local notifications
    await _configureLocalNotifications();

    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Get the initial message (app opened from terminated state)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleInitialMessage(initialMessage);
    }

    // Get FCM token
    final token = await _messaging.getToken();
    print('FCM Token: $token');
  }

  // Configure local notifications
  Future<void> _configureLocalNotifications() async {
    // Android initialization
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');



    // Initialize local notifications
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,

    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload != null) {
          print('Notification payload: ${response.payload}');
          // Navigate to notification detail page
        }
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel(
        id: 'fall_detection_channel',
        name: 'Düşme Algılama Bildirimleri',
        description: 'Düşme algılama sistemi bildirimleri',
        importance: Importance.high,
      );
    }
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel({
    required String id,
    required String name,
    required String description,
    required Importance importance,
  }) async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handle foreground message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling a foreground message: ${message.messageId}');

    // Display local notification
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && (Platform.isAndroid || Platform.isIOS)) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fall_detection_channel',
            'Düşme Algılama Bildirimleri',
            channelDescription: 'Düşme algılama sistemi bildirimleri',
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['event_id'],
      );
    }
  }

  // Handle when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Handling a message opened app: ${message.messageId}');

    // Navigate to notification detail page
    if (message.data.containsKey('event_id')) {
      final eventId = message.data['event_id'];
      print('Navigate to event detail: $eventId');

      // Navigate to notification detail page using navigator key or other method
    }
  }

  // Handle initial message
  void _handleInitialMessage(RemoteMessage message) {
    print('Handling an initial message: ${message.messageId}');

    // Navigate to notification detail page
    if (message.data.containsKey('event_id')) {
      final eventId = message.data['event_id'];
      print('Navigate to event detail from initial message: $eventId');

      // Store this information to navigate after app fully initialized
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}
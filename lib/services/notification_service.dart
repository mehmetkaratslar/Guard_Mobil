// =====================================================================
// 📄 Dosya: notification_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama: Gerçek zamanlı bildirim yönetimi - FCM, yerel bildirim, alarm sesi
// 🔗 Bağlantılı: main.dart, fall_event_model.dart, notifications_screen.dart
// =====================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/fall_event_model.dart';
import '../screens/notifications_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String _fallChannelId = 'fall_detection_channel';
  static const String _alertChannelId = 'alert_channel';
  static const String _generalChannelId = 'general_channel';

  bool _isInitialized = false;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _requestPermissions();
      await _configureLocalNotifications();
      _setupMessageHandlers();
      await _saveDeviceToken();
      _isInitialized = true;
      print('✅ NotificationService başarıyla başlatıldı');
    } catch (e) {
      print('❌ NotificationService başlatma hatası: $e');
      _showErrorSnackBar('Bildirim servisi başlatılamadı: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
        );
        print('FCM İzin Durumu (iOS): ${settings.authorizationStatus}');
      } else if (Platform.isAndroid) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print('FCM İzin Durumu (Android): ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ Bildirim izni alma hatası: $e');
    }
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fallChannelId,
          'Düşme Algılama',
          description: 'Düşme olayları için kritik bildirimler',
          importance: Importance.high,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFFFF0000),
          sound: RawResourceAndroidNotificationSound('fall_alarm'),
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          'Uyarılar',
          description: 'Önemli uyarı mesajları',
          importance: Importance.defaultImportance,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          'Genel Bildirimler',
          description: 'Genel bilgi mesajları',
          importance: Importance.low,
        ),
      );
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    _checkInitialMessage();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Ön planda mesaj: ${message.messageId}');
    if (message.data['type'] == 'fall_detection') {
      await _handleFallDetectionMessage(message);
    } else {
      await _showLocalNotification(message);
    }
  }

  Future<void> _handleFallDetectionMessage(RemoteMessage message) async {
    try {
      await _playAlarmSound();
      if (Platform.isAndroid || Platform.isIOS) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact();
      }
      await _showCriticalNotification(message);
      if (message.data['event_id'] != null) {
        await _saveFallEventFromNotification(message);
      }
    } catch (e) {
      print('❌ Düşme algılama mesajı hatası: $e');
      _showErrorSnackBar('Düşme bildirimi işlenemedi: $e');
    }
  }

  Future<void> _showCriticalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      _fallChannelId,
      'Düşme Algılama',
      channelDescription: 'Düşme olayları için kritik bildirimler',
      importance: Importance.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      enableLights: true,
      ledColor: const Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      sound: const RawResourceAndroidNotificationSound('fall_alarm'),
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'fall_alarm.aiff',
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚨 DÜŞME ALGILANDI!',
      message.notification?.body ?? 'Acil durum tespit edildi, lütfen kontrol edin.',
      details,
      payload: message.data['event_id'],
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final isAlert = message.data['priority'] == 'high';
    final channelId = isAlert ? _alertChannelId : _generalChannelId;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isAlert ? 'Uyarılar' : 'Genel Bildirimler',
      channelDescription: isAlert ? 'Önemli uyarı mesajları' : 'Genel bilgi mesajları',
      importance: isAlert ? Importance.defaultImportance : Importance.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Guard',
      message.notification?.body ?? '',
      details,
      payload: message.data['event_id'],
    );
  }

  Future<void> _playAlarmSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset('assets/fall_alarm.mp3');
      await _audioPlayer.setLoopMode(LoopMode.off);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ Alarm sesi çalma hatası: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Bildirime tıklandı: ${response.payload}');
    final navigator = navigatorKey.currentState;
    if (navigator != null && response.payload != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => NotificationsScreen(eventId: response.payload),
        ),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 Bildirime tıklandı (arka plan): ${message.messageId}');
    final navigator = navigatorKey.currentState;
    if (navigator != null && message.data['event_id'] != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => NotificationsScreen(eventId: message.data['event_id']),
        ),
      );
    }
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 İlk mesaj: ${initialMessage.messageId}');
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _saveDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      final user = _auth.currentUser;

      if (token != null && user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }, SetOptions(merge: true));

        print('📱 FCM Token kaydedildi: ${token.substring(0, 20)}...');
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmToken': newToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('📱 FCM Token güncellendi');
        }
      });
    } catch (e) {
      print('❌ Token kaydetme hatası: $e');
      _showErrorSnackBar('Token kaydedilemedi: $e');
    }
  }

  Future<void> _saveFallEventFromNotification(RemoteMessage message) async {
    try {
      final eventData = message.data;
      final user = _auth.currentUser;

      if (user == null) {
        print('❌ Kullanıcı giriş yapmamış');
        return;
      }

      if (eventData['event_id'] == null || eventData['image_url'] == null) {
        print('❌ Eksik veri: event_id veya image_url bulunamadı');
        return;
      }

      final fallEvent = {
        'id': eventData['event_id'],
        'user_id': user.uid,
        'probability': double.tryParse(eventData['probability'] ?? '0.0') ?? 0.0,
        'timestamp': FieldValue.serverTimestamp(),
        'image_url': eventData['image_url'],
        'is_read': false,
        'source': 'pc_detection',
        'created_at': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('fall_events')
          .doc(eventData['event_id'])
          .set(fallEvent, SetOptions(merge: true));

      print('📝 Düşme olayı Firestore\'a kaydedildi: ${eventData['event_id']}');
    } catch (e) {
      print('❌ Düşme olayı kaydetme hatası: $e');
      _showErrorSnackBar('Düşme olayı kaydedilemedi: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('📺 Konuya abone olundu: $topic');
    } catch (e) {
      print('❌ Konu aboneliği hatası: $e');
      _showErrorSnackBar('Konuya abone olunamadı: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('📺 Konudan çıkıldı: $topic');
    } catch (e) {
      print('❌ Konu çıkış hatası: $e');
      _showErrorSnackBar('Konudan çıkılamadı: $e');
    }
  }

  Future<void> sendTestNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _generalChannelId,
      'Genel Bildirimler',
      channelDescription: 'Test bildirimi',
      importance: Importance.defaultImportance,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Test Bildirimi',
      'Guard bildirim sistemi çalışıyor!',
      details,
    );
  }

  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  void _showErrorSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Arka planda mesaj alındı: ${message.messageId}');
}
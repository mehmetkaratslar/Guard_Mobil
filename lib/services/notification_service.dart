// =====================================================================
// 📄 Dosya: notification_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama: Gerçek zamanlı bildirim yönetimi - FCM, yerel bildirim, alarm sesi
// 🔗 Bağlantılı: main.dart, fall_event_model.dart, fcm_service.dart
// =====================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fall_event_model.dart';

class NotificationService {
  // Singleton yapı: sadece bir instance olacak
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Firebase ve bildirim servisleri örnekleri
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sesli uyarı için just_audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Bildirim kanalı ID'leri
  static const String _fallChannelId = 'fall_detection_channel';
  static const String _alertChannelId = 'alert_channel';
  static const String _generalChannelId = 'general_channel';

  bool _isInitialized = false;

  /// Servisi başlat (uygulamanın başında çağır)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _requestPermissions();          // Bildirim izinlerini al
      await _configureLocalNotifications(); // Bildirim altyapısını ayarla
      _setupMessageHandlers();              // FCM olay dinleyicileri
      await _saveDeviceToken();             // Tokenı kaydet
      _isInitialized = true;
      print('✅ NotificationService başarıyla başlatıldı');
    } catch (e) {
      print('❌ NotificationService başlatma hatası: $e');
    }
  }

  /// Bildirim izinlerini iste (Android ve iOS için ayrı ayrı)
  Future<void> _requestPermissions() async {
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
  }

  /// Yerel bildirim altyapısını kur
  Future<void> _configureLocalNotifications() async {
    // Android başlatma ayarları (ikon zorunlu)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS başlatma ayarları
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

    // Android için bildirim kanallarını oluştur
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Android için özel bildirim kanallarını oluştur
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Düşme algılama kanalı (kritik)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fallChannelId,
          'Düşme Algılama',
          description: 'Düşme olayları için kritik bildirimler',
          importance: Importance.high,
          // priority parametresi yok! Sadece importance kullanılır.
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFFFF0000),
          sound: RawResourceAndroidNotificationSound('fall_alarm'),
        ),
      );

      // Uyarı kanalı (orta öncelik)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          'Uyarılar',
          description: 'Önemli uyarı mesajları',
          importance: Importance.defaultImportance,
          enableVibration: true,
        ),
      );

      // Genel bildirim kanalı (düşük öncelik)
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

  /// FCM mesaj dinleyicilerini ayarla
  void _setupMessageHandlers() {
    // Uygulama açıkken gelen mesajlar
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Bildirime tıklandığında (uygulama arka planda)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Uygulama kapalıyken gelen ilk mesajı kontrol et
    _checkInitialMessage();
  }

  /// Uygulama açıkken gelen mesajı işle
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Ön planda mesaj: ${message.messageId}');
    if (message.data['type'] == 'fall_detection') {
      await _handleFallDetectionMessage(message);
    } else {
      await _showLocalNotification(message);
    }
  }

  /// Düşme algılama mesajı için özel işlemler
  Future<void> _handleFallDetectionMessage(RemoteMessage message) async {
    try {
      await _playAlarmSound(); // Alarm sesi
      if (Platform.isAndroid || Platform.isIOS) {
        HapticFeedback.heavyImpact(); // Titreşim efekti (1)
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact(); // Titreşim efekti (2)
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact(); // Titreşim efekti (3)
      }
      await _showCriticalNotification(message); // Kritik yerel bildirim göster
      if (message.data['event_id'] != null) {
        await _saveFallEventFromNotification(message); // Firestore'a kaydet
      }
    } catch (e) {
      print('❌ Düşme algılama mesajı hatası: $e');
    }
  }

  /// Düşme olayı için kritik bildirim (yüksek öncelik ve alarm sesi ile)
  Future<void> _showCriticalNotification(RemoteMessage message) async {
    // Android tarafı: importance ve sound ayarlı
    final androidDetails = AndroidNotificationDetails(
      _fallChannelId,
      'Düşme Algılama',
      channelDescription: 'Düşme olayları için kritik bildirimler',
      importance: Importance.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Farklı titreşim aralıkları
      enableLights: true,
      ledColor: Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      sound: RawResourceAndroidNotificationSound('fall_alarm'), // assets/fall_alarm.mp3
      ongoing: true,
      autoCancel: false,
    );

    // iOS tarafı: kritik seviye sesli bildirim
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'fall_alarm.aiff', // Eğer iOS'ta .aiff olarak eklediysen
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Benzersiz ID
      '🚨 DÜŞME ALGILANDI!',
      message.notification?.body ?? 'Acil durum tespit edildi, lütfen kontrol edin.',
      details,
      payload: message.data['event_id'],
    );
  }

  /// Normal yerel bildirim göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Öncelik: gelen mesajın priority bilgisine göre kanal seç (varsayılan: genel)
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
      message.hashCode, // Mesaja özel ID
      message.notification?.title ?? 'Guard',
      message.notification?.body ?? '',
      details,
      payload: message.data['event_id'],
    );
  }

  /// Alarm sesi çal
  Future<void> _playAlarmSound() async {
    try {
      await _audioPlayer.setAsset('assets/fall_alarm.mp3');
      await _audioPlayer.setLoopMode(LoopMode.off);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ Alarm sesi çalma hatası: $e');
    }
  }

  /// Bildirime tıklandığında çalışır (foreground/arka plan)
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Bildirime tıklandı: ${response.payload}');
    // Eğer bir navigation yapılacaksa, burada callback tanımlayabilirsin
  }

  /// Bildirime tıklandığında (uygulama arka planda)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 Bildirime tıklandı (arka plan): ${message.messageId}');
    // Navigation yapılacaksa burada kullanabilirsin
  }

  /// Uygulama ilk açıldığında FCM mesajı kontrolü
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 İlk mesaj: ${initialMessage.messageId}');
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Cihaz FCM token'ını Firestore'da sakla
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

      // Token yenilenirse Firestore'da güncelle
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
    }
  }

  /// PC'den gelen düşme olayını Firestore'a kaydet
  Future<void> _saveFallEventFromNotification(RemoteMessage message) async {
    try {
      final eventData = message.data;
      final user = _auth.currentUser;

      if (user == null) return;

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
    }
  }

  /// Bir FCM konusuna abone ol
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('📺 Konuya abone olundu: $topic');
    } catch (e) {
      print('❌ Konu aboneliği hatası: $e');
    }
  }

  /// Bir FCM konusundan çık
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('📺 Konudan çıkıldı: $topic');
    } catch (e) {
      print('❌ Konu çıkış hatası: $e');
    }
  }

  /// Lokal test bildirimi gönder (uygulama içi test için)
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

  /// Tüm bildirimleri temizle
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Belirli bildirimi iptal et
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Servisi temizle (kapanışta çağır)
  void dispose() {
    _audioPlayer.dispose();
  }
}

// =====================================================================
// 🔗 Bağımsız global arka plan mesaj işleyicisi
// =====================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Arka planda mesaj alındı: ${message.messageId}');
  // Burada kritik arka plan işlemleri yapılabilir (örn. Firestore güncelleme)
}

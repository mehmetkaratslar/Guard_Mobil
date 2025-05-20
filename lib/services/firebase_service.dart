// 📄 Dosya: firebase_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama:
// Firebase hizmetlerini yöneten servis sınıfı
// Düşme olaylarını gerçek zamanlı olarak izler ve bildirim gönderir
// 🔗 Bağlantılı: notifications_screen.dart, home_screen.dart, settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../models/fall_event_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  // Firebase hizmetleri
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Stream controllers
  final StreamController<List<FallEvent>> _fallEventsController = StreamController<List<FallEvent>>.broadcast();

  // Getters
  Stream<List<FallEvent>> get fallEvents => _fallEventsController.stream;
  User? get currentUser => _auth.currentUser;

  // Singleton constructor
  factory FirebaseService() {
    return _instance;
  }

  // Private constructor
  FirebaseService._internal() {
    _initializeLocalNotifications();
    _initializeFirebaseMessaging();
  }

  // Yerel bildirimleri başlat
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Tıklanan bildirimi işle
  void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında olacak işlemler
    if (response.payload != null) {
      // Olay ID'sini payload olarak aldık, detay sayfasına yönlendirilebilir
      print('Notification tapped with payload: ${response.payload}');
    }
  }

  // Firebase Messaging'i başlat
  Future<void> _initializeFirebaseMessaging() async {
    // İzinleri iste
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted notification permission: ${settings.authorizationStatus}');

    // Token al
    String? token = await _messaging.getToken();
    print('Firebase messaging token: $token');

    // Kullanıcı giriş yapmışsa token'ı kaydet
    await _saveToken(token);

    // Token yenilendiğinde
    _messaging.onTokenRefresh.listen(_saveToken);

    // Arka planda çalışırken mesaj geldiğinde
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Uygulama açıkken mesaj geldiğinde
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Bildirime tıklandığında
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Detay sayfasına yönlendirme yapılabilir
    });
  }

  // Yerel bildirim göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      'guard_fall_channel',
      'Düşme Bildirimleri',
      channelDescription: 'Düşme olayları hakkında bildirimler',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'guard',
    );

    final iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Yeni Bildirim',
      message.notification?.body ?? '',
      details,
      payload: message.data['event_id'] ?? '',
    );
  }

  // FCM token'ı kaydet
  Future<void> _saveToken(String? token) async {
    if (token == null) return;

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Firebase Auth işlemleri

  // Email ve şifre ile giriş
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      print('Giriş hatası: $e');
      rethrow;
    }
  }

  // Yeni hesap oluşturma
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      print('Kayıt hatası: $e');
      rethrow;
    }
  }

  // Oturumu kapat
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Firestore işlemleri

  // Düşme olaylarını gerçek zamanlı al
  Stream<List<FallEvent>> getFallEventsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('fall_events')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FallEvent.fromMap(doc.data()))
          .toList();
    });
  }

  // Son düşme olaylarını al (limit ile)
  Future<List<FallEvent>> getRecentFallEvents({int limit = 10}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('fall_events')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FallEvent.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Düşme olayları alınırken hata: $e');
      return [];
    }
  }

  // Düşme olayını okundu olarak işaretle
  Future<void> markFallEventAsRead(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('fall_events')
          .doc(eventId)
          .update({
        'is_read': true,
        'read_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Olay okundu olarak işaretlenirken hata: $e');
    }
  }

  // Düşme olayını sil
  Future<void> deleteFallEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Firestore'dan olayı sil
      await _firestore.collection('fall_events').doc(eventId).delete();

      // Storage'dan ekran görüntüsünü sil
      try {
        await _storage.ref('fall_screenshots/$eventId.jpg').delete();
      } catch (e) {
        // Dosya bulunamadı veya başka bir hata olabilir, önemli değil
        print('Ekran görüntüsü silinirken hata: $e');
      }
    } catch (e) {
      print('Olay silinirken hata: $e');
      rethrow;
    }
  }

  // Kullanıcı profil bilgilerini al
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Kullanıcı profili alınırken hata: $e');
      return null;
    }
  }

  // Kullanıcı profilini güncelle
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Profil güncellenirken hata: $e');
      rethrow;
    }
  }

  // Bildirim ayarlarını güncelle
  Future<void> updateNotificationSettings(Map<String, dynamic> settings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Bildirim ayarları güncellenirken hata: $e');
      rethrow;
    }
  }

  // Whatsapp üzerinden bildirim gönder
  Future<void> sendWhatsAppNotification(String phoneNumber, String message) async {
    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Kaynakları temizle
  void dispose() {
    _fallEventsController.close();
  }
}

// Arka planda bildirim işleyici
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Burada arka planda bildirim işleme yapılır
  print("Handling a background message: ${message.messageId}");
}
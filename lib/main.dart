// ====================================================================================
// 📄 Dosya: lib/main.dart
// 📁 Konum: /lib
// 📌 Açıklama:
// Guard uygulamasının giriş noktasıdır.
// Firebase başlatılır, App Check yapılır, bildirim sistemi (mobilde) yüklenir,
// intl yerel ayarları başlatılır, SplashScreen açılır.
// 🔗 Bağlantılı: firebase_options.dart, notification_service.dart, splash_screen.dart
// ====================================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Flutter framework başlatılır.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1️⃣ Firebase başlat
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase başarıyla başlatıldı');

    // 2️⃣ Türkçe yerel ayarları başlat (tarih/saat formatı için)
    await initializeDateFormatting('tr_TR', null);
    print('✅ Türkçe yerel ayarları başlatıldı');

    // 3️⃣ App Check başlat (Google Play koruması)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity, // veya safetyNet
      // appleProvider: AppleProvider.appAttest, // Eğer iOS destekliyorsan aç
    );
    print('✅ Firebase App Check başlatıldı');

    // 4️⃣ Bildirim sistemi sadece mobilde başlatılır!
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Arka plan mesaj işleyicisini tanımla
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print('✅ Arka plan mesaj işleyicisi kaydedildi');

      // NotificationService'i başlat
      final notificationService = NotificationService();
      await notificationService.initialize();
      // Farklı konulara abone ol
      await notificationService.subscribeToTopic('fall_alerts');
      await notificationService.subscribeToTopic('emergency_alerts');
      print('✅ Bildirim servisi başarıyla başlatıldı');
    }
  } catch (e) {
    // Herhangi bir başlatma hatasında burada loglanır
    print('❌ Firebase/Bildirim/Yerel ayar başlatma hatası: $e');
  }

  // Uygulama ana widget'ı çalıştırılır.
  runApp(const GuardApp());
}

// ====================================================================================
// Uygulamanın ana widget'ı (tema, yönlendirme, splash ekranı vs. burada)
// ====================================================================================
class GuardApp extends StatelessWidget {
  const GuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard',
      navigatorKey: NotificationService.navigatorKey, // Bildirimden ekran açmak için
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blueAccent,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.blueAccent,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.blue.shade800,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      themeMode: ThemeMode.system, // Cihazın temasına göre açık/koyu mod
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // İlk açılan ekran
    );
  }
}

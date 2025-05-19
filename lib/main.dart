// 📄 Dosya: lib/main.dart
// 📁 Konum: /lib
// 📌 Açıklama:
// Uygulama başlangıç dosyasıdır.
// Firebase başlatılır ve platforma özel bildirim servisi yüklenir.
// Ana ekran olarak SplashScreen gösterilir.

// 🔗 Bağlantılı: firebase_options.dart, fcm_service.dart, splash_screen.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase'i platforma özel başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );



  runApp(const GuardApp());
}

class GuardApp extends StatelessWidget {
  const GuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Açılışta yönlendirici ekran
    );
  }
}

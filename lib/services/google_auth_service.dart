// 📄 Dosya: lib/services/google_auth_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama:
// - Kullanıcının Google hesabıyla giriş/kayıt olmasını sağlar.
// - Android ve Web için desteklidir.
// - Başarılı giriş sonrası kullanıcı Firestore'a kaydedilir.
// 🔗 Bağlantılı: login_screen.dart, firebase_auth, google_sign_in, cloud_firestore

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔁 Firestore için
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
  );

  /// 🔐 Google ile giriş yapar (Web + Android)
  Future<User?> signInWithGoogle() async {
    try {
      // 🔁 Oturum çakışmalarını önlemek için önce çıkış yap
      await _googleSignIn.signOut();

      if (kIsWeb) {
        // 🌐 Web için giriş
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider
            .addScope('https://www.googleapis.com/auth/userinfo.profile');

        UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        final user = userCredential.user;

        if (user != null) {
          await _saveUserToFirestore(user); // ✅ Firestore'a kaydet
          print('✅ Web Google Sign-In: ${user.displayName}, ${user.email}');
        }
        return user;
      } else {
        // 📱 Android için Google hesabını seç
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print('⛔ Kullanıcı Google girişini iptal etti');
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('⛔ Giriş başarısız: Token alınamadı');
        }

        // 🔐 Firebase kimlik doğrulama bilgisi oluştur
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;

        if (user != null) {
          await _saveUserToFirestore(user); // ✅ Firestore'a kaydet
          print(
              '✅ Android Google Giriş Başarılı: ${user.displayName}, ${user.email}');
        } else {
          print('⛔ Android Google Giriş: kullanıcı nesnesi null');
        }

        return user;
      }
    } catch (e) {
      print('❌ Google Giriş Hatası: $e');
      if (e.toString().contains('ApiException: 10')) {
        throw Exception(
          'Google Giriş başarısız (ApiException: 10). Bu, büyük ihtimalle Firebase yapılandırma hatasıdır. '
          'SHA-1 fingerprint ve OAuth client ID ayarlarını kontrol etmelisin.',
        );
      }
      rethrow;
    }
  }

  /// 📤 Google ve Firebase oturumunu sonlandırır
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('✅ Kullanıcı çıkış yaptı');
    } catch (e) {
      print('❌ Çıkış hatası: $e');
      rethrow;
    }
  }

  /// 📦 Firestore'a kullanıcı bilgisini kaydeder
  Future<void> _saveUserToFirestore(User user) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('📝 Kullanıcı Firestore\'a kaydedildi');
    } else {
      print('ℹ️ Kullanıcı zaten kayıtlı');
    }
  }
}

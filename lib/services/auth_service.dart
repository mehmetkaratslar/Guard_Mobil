// 📄 Dosya: lib/services/auth_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama:
// Firebase Authentication işlemlerini (giriş, kayıt, çıkış) içerir.
// Yeni kullanıcıları Firestore’a kaydeder.
// 🔗 Bağlantılı Dosyalar: login_screen.dart, register_screen.dart, splash_screen.dart

import 'package:firebase_auth/firebase_auth.dart'; // 🔐 Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // 📦 Firestore veritabanı

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔄 Kullanıcının oturum durumunu dinler
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 🔍 Mevcut kullanıcıyı getir
  User? get currentUser => _auth.currentUser;

  // 🔑 E-posta ve şifre ile giriş yap
  Future<User?> signIn(String email, String password) async {
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        throw Exception('E-posta ve şifre alanları boş olamaz.');
      }
      if (!_isValidEmail(email)) {
        throw Exception('Geçersiz e-posta formatı.');
      }
      if (password.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır.');
      }

      print('🔐 Giriş deneniyor: $email');
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = result.user;

      if (user != null) {
        print('✅ Giriş başarılı: ${user.email}, UID: ${user.uid}');
      } else {
        print('⛔ Giriş başarısız: kullanıcı dönmedi');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('⚠️ Firebase giriş hatası: ${e.code}, ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception(
              'Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.');
        case 'wrong-password':
          throw Exception('Yanlış şifre girdiniz. Lütfen tekrar deneyin.');
        case 'invalid-email':
          throw Exception('Geçersiz e-posta adresi. Lütfen kontrol edin.');
        case 'user-disabled':
          throw Exception('Bu kullanıcı hesabı devre dışı bırakılmış.');
        default:
          throw Exception('Giriş başarısız: ${e.message}');
      }
    } catch (e) {
      print('⛔ Genel giriş hatası: $e');
      rethrow;
    }
  }

  // 🆕 Yeni kullanıcı kaydı ve Firestore’a ekleme
  Future<User?> register(String email, String password) async {
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        throw Exception('E-posta ve şifre alanları boş olamaz.');
      }
      if (!_isValidEmail(email)) {
        throw Exception('Geçersiz e-posta formatı.');
      }
      if (password.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır.');
      }

      print('📝 Kayıt deneniyor: $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = result.user;

      if (user != null) {
        print('✅ Kayıt başarılı: ${user.email}, UID: ${user.uid}');
        await _saveUserToFirestore(user); // 🔁 Firestore'a kaydet
      } else {
        print('⛔ Kayıt başarısız: kullanıcı dönmedi');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('⚠️ Firebase kayıt hatası: ${e.code}, ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Bu e-posta adresi zaten kullanımda.');
        case 'invalid-email':
          throw Exception('Geçersiz e-posta adresi. Lütfen kontrol edin.');
        case 'weak-password':
          throw Exception('Şifre çok zayıf. Daha güçlü bir şifre seçin.');
        default:
          throw Exception('Kayıt başarısız: ${e.message}');
      }
    } catch (e) {
      print('⛔ Genel kayıt hatası: $e');
      rethrow;
    }
  }

  // 🔓 Oturumu kapat
  Future<void> signOut() async {
    try {
      print('🚪 Oturum kapatılıyor: ${currentUser?.email}');
      await _auth.signOut();
      print('✅ Oturum başarıyla kapatıldı');
    } catch (e) {
      print('⛔ Oturum kapatma hatası: $e');
      rethrow;
    }
  }

  // 📦 Firestore’a kullanıcı kaydet
  Future<void> _saveUserToFirestore(User user) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('📦 Firestore’a kullanıcı kaydedildi');
    } else {
      print('ℹ️ Kullanıcı zaten Firestore’da kayıtlı');
    }
  }

  // 📧 E-posta doğrulama regex kontrolü
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }
}

// 📄 Dosya: lib/services/storage_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama: Firebase Storage işlemlerini yöneten servis
// 🔗 Bağlantılı: profile_settings_screen.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  // Profil fotoğrafı yükle
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      // Kullanıcı ID'sini kontrol et
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açık bir kullanıcı bulunamadı.');
      }

      // Dosya uzantısını al
      final fileExtension = path.extension(imageFile.path);

      // Storage referansını oluştur - UUID ile benzersiz isim oluştur
      final uuid = const Uuid().v4();
      final storageRef = _storage.ref()
          .child('profile_images')
          .child('${user.uid}_$uuid$fileExtension');

      // Metadata oluştur
      final metadata = SettableMetadata(
        contentType: 'image/${fileExtension.substring(1)}', // .jpg -> image/jpg
        customMetadata: {
          'userId': user.uid,
          'uploadDate': DateTime.now().toIso8601String(),
        },
      );

      // Dosyayı yükle
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Yükleme durumunu izle
      final taskSnapshot = await uploadTask;

      // İndirme URL'sini al
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      print('✅ Profil resmi başarıyla yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Profil resmi yüklenirken hata oluştu: $e');
      rethrow;
    }
  }

  // Profil fotoğrafını sil
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      // URL'den referansı al
      final ref = _storage.refFromURL(imageUrl);

      // Dosyayı sil
      await ref.delete();

      print('✅ Profil resmi başarıyla silindi: $imageUrl');
    } catch (e) {
      print('❌ Profil resmi silinirken hata oluştu: $e');
      rethrow;
    }
  }

  // Olay fotoğrafı yükle
  Future<String?> uploadEventImage(File imageFile, String eventId) async {
    try {
      // Kullanıcı ID'sini kontrol et
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açık bir kullanıcı bulunamadı.');
      }

      // Dosya uzantısını al
      final fileExtension = path.extension(imageFile.path);

      // Storage referansını oluştur
      final storageRef = _storage.ref()
          .child('event_images')
          .child('${eventId}$fileExtension');

      // Metadata oluştur
      final metadata = SettableMetadata(
        contentType: 'image/${fileExtension.substring(1)}',
        customMetadata: {
          'userId': user.uid,
          'eventId': eventId,
          'uploadDate': DateTime.now().toIso8601String(),
        },
      );

      // Dosyayı yükle
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Yükleme durumunu izle
      final taskSnapshot = await uploadTask;

      // İndirme URL'sini al
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      print('✅ Olay resmi başarıyla yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Olay resmi yüklenirken hata oluştu: $e');
      rethrow;
    }
  }
}
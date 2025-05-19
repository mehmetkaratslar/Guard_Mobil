// 📄 Dosya: firebase_service.dart
// 📁 Konum: lib/services/
// 📌 Açıklama:
// Firestore üzerinden düşme olaylarını gerçek zamanlı olarak çeker.
// 🔗 Bağlantılı Dosyalar: home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore paketi

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore örneği

  /// Kullanıcının düşme olaylarını zaman sırasına göre çeker
  Stream<List<Map<String, dynamic>>> getFallEvents(String userId) {
    return _firestore
        .collection('fall_events') // Koleksiyon adı
        .where('user_id', isEqualTo: userId) // Kullanıcıya özel filtreleme
        .orderBy('timestamp', descending: true) // En yeni en üstte olacak şekilde sırala
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => doc.data()).toList()); // Verileri listeye çevir
  }
}

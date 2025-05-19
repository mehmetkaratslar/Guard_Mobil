// 📄 Dosya: fall_event_model.dart
// 📁 Konum: lib/models/
// 📌 Açıklama:
// Düşme olaylarını temsil eden veri modeli
// 🔗 Bağlantılı: firebase_service.dart, home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FallEvent {
  final double probability; // Düşme olasılığı (0-1 arası)
  final DateTime timestamp; // Olay zamanı
  final String? screenshotUrl; // Görsel URL

  FallEvent({
    required this.probability,
    required this.timestamp,
    this.screenshotUrl,
  });

  // Firestore'dan veri alırken dönüşüm
  factory FallEvent.fromMap(Map<String, dynamic> data) {
    return FallEvent(
      probability: data['probability'] ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      screenshotUrl: data['screenshot_url'],
    );
  }
}

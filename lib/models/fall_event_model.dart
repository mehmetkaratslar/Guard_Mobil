// 📄 Dosya: fall_event_model.dart
// 📁 Konum: lib/models/
// 📌 Açıklama:
// Düşme olaylarını temsil eden veri modeli
// 🔗 Bağlantılı: firebase_service.dart, notifications_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FallEvent {
  final String id;
  final String userId;
  final double probability; // Düşme olasılığı (0-1 arası)
  final DateTime timestamp; // Olay zamanı
  final String? screenshotUrl; // Görsel URL
  final bool isRead; // Okundu durumu

  FallEvent({
    required this.id,
    required this.userId,
    required this.probability,
    required this.timestamp,
    this.screenshotUrl,
    this.isRead = false,
  });

  // Firestore'dan veri alırken dönüşüm
  factory FallEvent.fromMap(Map<String, dynamic> data) {
    return FallEvent(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      probability: data['probability'] is double
          ? data['probability']
          : (data['probability'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] ?? 0) * 1000,
      ),
      screenshotUrl: data['image_url'],
      isRead: data['is_read'] ?? false,
    );
  }

  // Firestore'a veri gönderirken dönüşüm
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'probability': probability,
      'timestamp': Timestamp.fromDate(timestamp),
      'image_url': screenshotUrl,
      'is_read': isRead,
    };
  }

  // Okundu durumunu güncellemek için yeni bir kopya oluştur
  FallEvent copyWith({
    String? id,
    String? userId,
    double? probability,
    DateTime? timestamp,
    String? screenshotUrl,
    bool? isRead,
  }) {
    return FallEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      probability: probability ?? this.probability,
      timestamp: timestamp ?? this.timestamp,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      isRead: isRead ?? this.isRead,
    );
  }
}
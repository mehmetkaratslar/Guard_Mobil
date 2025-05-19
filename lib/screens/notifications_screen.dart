// 📄 Dosya: notifications_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Bildirimler ekranı

import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.notifications),
            title: Text('Bildirim ${index + 1}'),
            subtitle: Text('Bildirim açıklaması ${index + 1}'),
            trailing: const Text('10:00'),
            onTap: () {
              // Bildirim detayı
            },
          );
        },
      ),
    );
  }
}
// 📄 Dosya: settings_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Ayarlar ekranı

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Profil ayarları
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Bildirimler'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Bildirim ayarları
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Güvenlik'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Güvenlik ayarları
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Hakkında'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Uygulama hakkında
            },
          ),
        ],
      ),
    );
  }
}
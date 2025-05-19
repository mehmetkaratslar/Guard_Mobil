// 📄 Dosya: app_layout.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Ana ekran olarak çalışan alt sayfaları içeren BottomNavigationBar yapısı
// 🔗 Bağlantılı: home_screen.dart, notifications_screen.dart, settings_screen.dart, live_view_screen.dart

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'live_view_screen.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({Key? key}) : super(key: key);

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int _selectedIndex = 0; // Seçili sekme

  // Sayfalar listesi - StatefulWidget'lar için final kullanıyoruz, const değil
  final List<Widget> _pages = [
    const HomeScreen(),
    const NotificationsScreen(),
    const LiveViewScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Tıklanan sekmeyi ayarla
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Dört sekme destekle
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white60,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Bildirimler'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Canlı'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}
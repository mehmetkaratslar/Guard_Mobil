// 📄 Dosya: home_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Ana ekran

import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home, size: 80, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Guard Düşme Algılama Sistemi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Güvendeyiz, sistem aktif olarak çalışıyor!',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
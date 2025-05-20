// 📄 Dosya: settings_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Ayarlar ekranı - profil, bildirim, güvenlik ve hakkında sayfalarına erişim

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings/profile_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/security_settings_screen.dart';
import 'settings/about_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Kullanıcı';
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Kullanıcı bilgileri
          _buildUserHeader(context, displayName, email, photoUrl),

          const Divider(),

          // Ayarlar bölümleri
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'AYARLAR',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),

          // Profil ayarları
          _buildSettingsItem(
            context,
            icon: Icons.person,
            title: 'Profil',
            subtitle: 'Kişisel bilgilerinizi düzenleyin',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            ),
          ),

          // Bildirim ayarları
          _buildSettingsItem(
            context,
            icon: Icons.notifications,
            title: 'Bildirimler',
            subtitle: 'Bildirim türleri ve kanallarını ayarlayın',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),

          // Güvenlik ayarları
          _buildSettingsItem(
            context,
            icon: Icons.security,
            title: 'Güvenlik',
            subtitle: 'Şifre ve güvenlik seçenekleri',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
            ),
          ),

          const Divider(),

          // Uygulama bölümü
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'UYGULAMA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),

          // Hakkında
          _buildSettingsItem(
            context,
            icon: Icons.info,
            title: 'Hakkında',
            subtitle: 'Uygulama bilgileri ve sürüm',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),

          // Çıkış yap
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showSignOutDialog(context),
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, String name, String email, String? photoUrl) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blueAccent),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _showSignOutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Guard uygulamasından çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
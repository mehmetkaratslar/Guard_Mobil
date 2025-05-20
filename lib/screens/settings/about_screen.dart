// 📄 Dosya: about_screen.dart
// 📁 Konum: lib/screens/settings/
// 📌 Açıklama: Uygulama hakkında bilgi ekranı - versiyon bilgisi, geliştirici iletişim bilgileri, gizlilik politikası bağlantısı

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';
  String _appName = 'Guard';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appName = packageInfo.appName;
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL açılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hakkında'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Uygulama logosu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.2),
                    Colors.transparent
                  ],
                  radius: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Uygulama adı ve versiyonu
            Text(
              _appName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Versiyon $_appVersion',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gerçek zamanlı düşme algılama ve bildirim sistemi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),

            // Bilgi kartları
            _buildInfoCard(
              'Uygulama Hakkında',
              'Guard uygulaması, yapay zeka tabanlı düşme algılama sistemi ile yaşlılar ve özel bakıma ihtiyaç duyan kişilerin güvenliğini sağlamak için tasarlanmıştır. Düşme olaylarını gerçek zamanlı olarak algılar ve acil durum kişilerine bildirimler gönderir.',
              Icons.info_outline,
              Colors.blue,
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              'Özellikler',
              '• Gerçek zamanlı düşme algılama\n• Anlık bildirimler ve uyarılar\n• Canlı kamera görüntüleme\n• Olay geçmişi ve analizi\n• Acil durum kişisi bildirimleri',
              Icons.star_outline,
              Colors.amber,
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              'İletişim',
              'Soru ve önerileriniz için bize ulaşabilirsiniz:',
              Icons.email_outlined,
              Colors.green,
              additionalWidget: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildContactButton(
                    'E-posta',
                    'mehmetkarataslar@gmail.com',
                    Icons.email,
                        () => _launchUrl('mehmetkarataslar@gmail.com'),
                  ),
                  const SizedBox(height: 8),
                  _buildContactButton(
                    'Web Sitesi',
                    'www.guarduygulama.com',
                    Icons.language,
                        () => _launchUrl('https://www.guarduygulama.com'),
                  ),
                  const SizedBox(height: 8),
                  _buildContactButton(
                    'Telefon',
                    '+905538366341',
                    Icons.phone,
                        () => _launchUrl('tel:+905538366341'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Yasal Bilgiler
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'YASAL BİLGİLER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),

            // Yasal butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildLegalButton(
                    'Kullanım Koşulları',
                    Icons.description,
                        () => _launchUrl('https://www.guarduygulama.com/terms'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLegalButton(
                    'Gizlilik Politikası',
                    Icons.privacy_tip,
                        () => _launchUrl('https://www.guarduygulama.com/privacy'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Telif hakkı
            const Text(
              '© 2025 Guard. Tüm hakları saklıdır.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title,
      String content,
      IconData icon,
      Color color, {
        Widget? additionalWidget,
      }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (additionalWidget != null) additionalWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalButton(
      String title,
      IconData icon,
      VoidCallback onTap,
      ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
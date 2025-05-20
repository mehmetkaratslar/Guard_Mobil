// 📄 Dosya: notification_settings_screen.dart
// 📁 Konum: lib/screens/settings/
// 📌 Açıklama: Bildirim ayarları ekranı - kullanıcı bildirim tercihlerini yönetir

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  // Bildirim ayarları
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _smsNotificationsEnabled = false;
  bool _whatsappNotificationsEnabled = false;

  // Bildirim tipleri
  bool _highRiskEnabled = true;
  bool _mediumRiskEnabled = true;
  bool _lowRiskEnabled = false;

  // İletişim bilgileri
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emergencyContactController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Kullanıcı email adresini varsayılan olarak doldur
        _emailController.text = user.email ?? '';

        // Firestore'dan ayarları yükle
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>;
          final settings = userData['notification_settings'] as Map<String, dynamic>? ?? {};
          final contacts = userData['contacts'] as Map<String, dynamic>? ?? {};

          setState(() {
            // Bildirim ayarları
            _pushNotificationsEnabled = settings['push_enabled'] ?? true;
            _emailNotificationsEnabled = settings['email_enabled'] ?? false;
            _smsNotificationsEnabled = settings['sms_enabled'] ?? false;
            _whatsappNotificationsEnabled = settings['whatsapp_enabled'] ?? false;

            // Bildirim tipleri
            _highRiskEnabled = settings['high_risk_enabled'] ?? true;
            _mediumRiskEnabled = settings['medium_risk_enabled'] ?? true;
            _lowRiskEnabled = settings['low_risk_enabled'] ?? false;

            // İletişim bilgileri
            _emergencyContactController.text = contacts['emergency_name'] ?? '';
            _phoneNumberController.text = contacts['phone'] ?? '';
            _whatsappNumberController.text = contacts['whatsapp'] ?? '';
          });
        }
      }
    } catch (e) {
      _showSnackBar('Ayarlar yüklenirken hata oluştu: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'notification_settings': {
            'push_enabled': _pushNotificationsEnabled,
            'email_enabled': _emailNotificationsEnabled,
            'sms_enabled': _smsNotificationsEnabled,
            'whatsapp_enabled': _whatsappNotificationsEnabled,
            'high_risk_enabled': _highRiskEnabled,
            'medium_risk_enabled': _mediumRiskEnabled,
            'low_risk_enabled': _lowRiskEnabled,
            'updated_at': FieldValue.serverTimestamp(),
          },
          'contacts': {
            'emergency_name': _emergencyContactController.text.trim(),
            'phone': _phoneNumberController.text.trim(),
            'email': _emailController.text.trim(),
            'whatsapp': _whatsappNumberController.text.trim(),
            'updated_at': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));

        _showSnackBar('Bildirim ayarları kaydedildi');
      }
    } catch (e) {
      _showSnackBar('Ayarlar kaydedilirken hata oluştu: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        actions: [
          if (!_isLoading && !_isSaving)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Değişiklikleri Kaydet',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Bildirim ayarları kaydediliyor...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Bildirim Kanalları'),

            // Push Bildirimleri
            _buildSwitchTile(
              title: 'Anlık Bildirimlere İzin Ver',
              subtitle: 'Telefonunuzda anlık bildirimleri görün',
              value: _pushNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _pushNotificationsEnabled = value;
                });
              },
              leadingIcon: Icons.notifications_active,
            ),

            // E-posta Bildirimleri
            _buildSwitchTile(
              title: 'E-posta Bildirimleri',
              subtitle: 'Düşme olayları için e-posta bildirimleri alın',
              value: _emailNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _emailNotificationsEnabled = value;
                });
              },
              leadingIcon: Icons.email,
            ),

            if (_emailNotificationsEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-posta Adresi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),

            // SMS Bildirimleri
            _buildSwitchTile(
              title: 'SMS Bildirimleri',
              subtitle: 'Düşme olayları için SMS bildirimleri alın',
              value: _smsNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _smsNotificationsEnabled = value;
                });
              },
              leadingIcon: Icons.sms,
            ),

            if (_smsNotificationsEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon Numarası',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: '+90 5XX XXX XX XX',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),

            // WhatsApp Bildirimleri
            _buildSwitchTile(
              title: 'WhatsApp Bildirimleri',
              subtitle: 'Yüksek risk durumlarında WhatsApp mesajı alın',
              value: _whatsappNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _whatsappNotificationsEnabled = value;
                });
              },
              leadingIcon: Icons.message,
            ),

            if (_whatsappNotificationsEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  controller: _whatsappNumberController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Numarası',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                    hintText: '+90 5XX XXX XX XX',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),

            const Divider(),
            _buildSectionTitle('Acil Durum Kişisi'),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Acil Durum Kişisi Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Acil durumlarda aranacak kişi',
                ),
              ),
            ),

            const Divider(),
            _buildSectionTitle('Bildirim Tipleri'),

            // Yüksek Risk
            _buildSwitchTile(
              title: 'Yüksek Risk (%80-100)',
              subtitle: 'Düşme olasılığı yüksekse bildirim al',
              value: _highRiskEnabled,
              onChanged: (value) {
                setState(() {
                  _highRiskEnabled = value;
                });
              },
              leadingIcon: Icons.warning,
              iconColor: Colors.red,
            ),

            // Orta Risk
            _buildSwitchTile(
              title: 'Orta Risk (%50-79)',
              subtitle: 'Düşme olasılığı orta seviyedeyse bildirim al',
              value: _mediumRiskEnabled,
              onChanged: (value) {
                setState(() {
                  _mediumRiskEnabled = value;
                });
              },
              leadingIcon: Icons.warning_amber,
              iconColor: Colors.orange,
            ),

            // Düşük Risk
            _buildSwitchTile(
              title: 'Düşük Risk (%10-49)',
              subtitle: 'Düşme olasılığı düşükse bildirim al',
              value: _lowRiskEnabled,
              onChanged: (value) {
                setState(() {
                  _lowRiskEnabled = value;
                });
              },
              leadingIcon: Icons.info,
              iconColor: Colors.yellow.shade800,
            ),

            const SizedBox(height: 30),

            // Kaydet Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Değişiklikleri Kaydet',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData leadingIcon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(leadingIcon, color: iconColor ?? Colors.blue),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
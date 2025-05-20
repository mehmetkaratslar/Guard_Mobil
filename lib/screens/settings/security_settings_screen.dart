// 📄 Dosya: security_settings_screen.dart
// 📁 Konum: lib/screens/settings/
// 📌 Açıklama: Güvenlik ayarları ekranı - şifre değiştirme ve güvenlik seçenekleri

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isSuccessful = false;

  // Şifre görünürlüğü
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  // Güvenlik ayarları
  bool _biometricAuthEnabled = false;
  bool _twoFactorAuthEnabled = false;
  bool _autoLogoutEnabled = true;
  int _autoLogoutTime = 30; // dakika

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _isSuccessful = false;
    });

    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        // E-posta ve şifre yeniden kimlik doğrulama
        final credentials = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        // Kullanıcıyı yeniden doğrula
        await user.reauthenticateWithCredential(credentials);

        // Şifreyi güncelle
        await user.updatePassword(_newPasswordController.text);

        setState(() {
          _isSuccessful = true;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreniz başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'wrong-password':
          message = 'Mevcut şifreniz yanlış.';
          break;
        case 'weak-password':
          message = 'Yeni şifre çok zayıf, lütfen daha güçlü bir şifre seçin.';
          break;
        case 'requires-recent-login':
          message = 'Bu işlem için yeniden oturum açmanız gerekiyor.';
          break;
        default:
          message = 'Bir hata oluştu: ${e.message}';
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Şifre değiştirme işlemi başarısız: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      try {
        await _auth.sendPasswordResetEmail(email: user.email!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şifre sıfırlama e-postası gönderilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Şifre gücünü ölç
  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    double strength = 0;

    // Minimum uzunluk kontrolü
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.2;

    // Karakter çeşitliliği kontrolü
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2; // Büyük harf
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1; // Küçük harf
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.1; // Rakam
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2; // Özel karakter

    return strength > 1.0 ? 1.0 : strength;
  }

  // Şifre gücü rengi
  Color _getPasswordStrengthColor(double strength) {
    if (strength <= 0.3) return Colors.red;
    if (strength <= 0.6) return Colors.orange;
    return Colors.green;
  }

  // Şifre gücü metni
  String _getPasswordStrengthText(double strength) {
    if (strength <= 0.3) return 'Zayıf';
    if (strength <= 0.6) return 'Orta';
    return 'Güçlü';
  }

  @override
  Widget build(BuildContext context) {
    // Şifre gücünü hesapla
    final passwordStrength = _calculatePasswordStrength(_newPasswordController.text);
    final strengthColor = _getPasswordStrengthColor(passwordStrength);
    final strengthText = _getPasswordStrengthText(passwordStrength);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik Ayarları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Şifre değiştirme bölümü
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Şifre Değiştir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mevcut şifre
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: !_currentPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Mevcut Şifre',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _currentPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _currentPasswordVisible = !_currentPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen mevcut şifrenizi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Yeni şifre
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: !_newPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _newPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _newPasswordVisible = !_newPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen yeni şifrenizi girin';
                          }
                          if (value.length < 8) {
                            return 'Şifre en az 8 karakter olmalıdır';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Değişikliği tetiklemek için setState kullan
                          setState(() {});
                        },
                      ),

                      // Şifre gücü göstergesi
                      if (_newPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strengthText,
                              style: TextStyle(
                                color: strengthColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'En az 8 karakter, büyük-küçük harf, rakam ve özel karakter içermeli',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Şifre onay
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre Tekrar',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _confirmPasswordVisible = !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen yeni şifrenizi tekrar girin';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                      ),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      if (_isSuccessful)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            'Şifreniz başarıyla değiştirildi!',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Değiştir butonu
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Şifreyi Değiştir'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Şifremi unuttum
                      Center(
                        child: TextButton.icon(
                          onPressed: _sendPasswordResetEmail,
                          icon: const Icon(Icons.email),
                          label: const Text('Şifremi unuttum'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Güvenlik seçenekleri
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Güvenlik Seçenekleri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Biyometrik kimlik doğrulama
                    SwitchListTile(
                      title: const Text('Biyometrik Kimlik Doğrulama'),
                      subtitle: const Text('Parmak izi veya yüz tanıma ile giriş yap'),
                      value: _biometricAuthEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _biometricAuthEnabled = value;
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.blue),
                      ),
                    ),

                    const Divider(),

                    // İki faktörlü kimlik doğrulama
                    SwitchListTile(
                      title: const Text('İki Faktörlü Kimlik Doğrulama'),
                      subtitle: const Text('SMS veya e-posta ile ek güvenlik katmanı'),
                      value: _twoFactorAuthEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _twoFactorAuthEnabled = value;
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.phone_android, color: Colors.purple),
                      ),
                    ),

                    const Divider(),

                    // Otomatik çıkış
                    SwitchListTile(
                      title: const Text('Otomatik Çıkış'),
                      subtitle: Text('Belirli bir süre sonra otomatik çıkış yap: $_autoLogoutTime dakika'),
                      value: _autoLogoutEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _autoLogoutEnabled = value;
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.timer, color: Colors.teal),
                      ),
                    ),

                    // Otomatik çıkış süresi ayarı
                    if (_autoLogoutEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Çıkış süresi: $_autoLogoutTime dakika',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            Slider(
                              value: _autoLogoutTime.toDouble(),
                              min: 1,
                              max: 60,
                              divisions: 59,
                              label: '$_autoLogoutTime dakika',
                              onChanged: (value) {
                                setState(() {
                                  _autoLogoutTime = value.round();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Hesap güvenliği
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hesap Güvenliği',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      title: const Text('Aktif Oturumlar'),
                      subtitle: const Text('Tüm cihazlardaki oturumlarınızı görüntüleyin'),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.devices, color: Colors.indigo),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Aktif oturumlar ekranına yönlendir
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bu özellik henüz geliştirme aşamasında'),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    ListTile(
                      title: const Text('Hesap Etkinliği'),
                      subtitle: const Text('Son giriş yapılan cihazlar ve lokasyonlar'),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history, color: Colors.amber),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Hesap etkinliği ekranına yönlendir
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bu özellik henüz geliştirme aşamasında'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
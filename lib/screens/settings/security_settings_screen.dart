// 📄 Dosya: security_settings_screen.dart
// 📁 Konum: lib/screens/settings/
// 📌 Açıklama: Güvenlik ayarları ekranı - şifre değiştirme ve güvenlik seçenekleri
// 🔗 Bağlantılı: settings_screen.dart, firebase_auth, package:flutter/services.dart, local_auth

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

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
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final settings = userDoc.data()?['securitySettings'] ?? {};
        setState(() {
          _biometricAuthEnabled = settings['biometricAuthEnabled'] ?? false;
          _twoFactorAuthEnabled = settings['twoFactorAuthEnabled'] ?? false;
          _autoLogoutEnabled = settings['autoLogoutEnabled'] ?? true;
          _autoLogoutTime = settings['autoLogoutTime'] ?? 30;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayarlar yüklenemedi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkBiometricSupport() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      print('Biyometrik destek kontrolü hatası: $e');
      return false;
    }
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    if (value) {
      bool isSupported = await _checkBiometricSupport();
      if (!isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu cihaz biyometrik doğrulamayı desteklemiyor.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Uygulamaya giriş için biyometrik doğrulama gerekli.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biyometrik doğrulama başarısız.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'securitySettings': {
            'biometricAuthEnabled': value,
            'twoFactorAuthEnabled': _twoFactorAuthEnabled,
            'autoLogoutEnabled': _autoLogoutEnabled,
            'autoLogoutTime': _autoLogoutTime,
          },
        }, SetOptions(merge: true));
        setState(() {
          _biometricAuthEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Biyometrik kimlik doğrulama ${value ? 'aktif edildi' : 'devre dışı bırakıldı'}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayar kaydedilemedi: $e')),
      );
    }
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
        final credentials = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credentials);
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

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.1;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;
    return strength > 1.0 ? 1.0 : strength;
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength <= 0.3) return Colors.red;
    if (strength <= 0.6) return Colors.orange;
    return Colors.green;
  }

  String _getPasswordStrengthText(double strength) {
    if (strength <= 0.3) return 'Zayıf';
    if (strength <= 0.6) return 'Orta';
    return 'Güçlü';
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _calculatePasswordStrength(_newPasswordController.text);
    final strengthColor = _getPasswordStrengthColor(passwordStrength);
    final strengthText = _getPasswordStrengthText(passwordStrength);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik Ayarları'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: !_currentPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Mevcut Şifre',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _currentPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
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
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: !_newPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _newPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
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
                          setState(() {});
                        },
                      ),
                      if (_newPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength,
                                backgroundColor: Colors.grey[300],
                                valueColor:
                                AlwaysStoppedAnimation<Color>(strengthColor),
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
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre Tekrar',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
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
                    SwitchListTile(
                      title: const Text('Biyometrik Kimlik Doğrulama'),
                      subtitle: const Text('Parmak izi veya yüz tanıma ile giriş yap'),
                      value: _biometricAuthEnabled,
                      onChanged: _toggleBiometricAuth,
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
                    SwitchListTile(
                      title: const Text('İki Faktörlü Kimlik Doğrulama'),
                      subtitle: const Text('SMS veya e-posta ile ek güvenlik katmanı'),
                      value: _twoFactorAuthEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _twoFactorAuthEnabled = value;
                        });
                        // TODO: İki faktörlü kimlik doğrulama ayarını Firestore'a kaydet
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
                    SwitchListTile(
                      title: const Text('Otomatik Çıkış'),
                      subtitle: Text(
                          'Belirli bir süre sonra otomatik çıkış yap: $_autoLogoutTime dakika'),
                      value: _autoLogoutEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _autoLogoutEnabled = value;
                        });
                        // TODO: Otomatik çıkış ayarını Firestore'a kaydet
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
                                // TODO: Çıkış süresi ayarını Firestore'a kaydet
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
                      subtitle: const Text(
                          'Tüm cihazlardaki oturumlarınızı görüntüleyin'),
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
                      subtitle: const Text(
                          'Son giriş yapılan cihazlar ve lokasyonlar'),
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
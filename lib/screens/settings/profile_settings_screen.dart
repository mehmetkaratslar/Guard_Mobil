// 📄 Dosya: profile_settings_screen.dart
// 📁 Konum: lib/screens/settings/
// 📌 Açıklama: Kullanıcı profil bilgilerini güncelleme ekranı

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicalConditionsController = TextEditingController();

  String? _gender;
  final List<String> _genders = ['Erkek', 'Kadın', 'Diğer', 'Belirtmek İstemiyorum'];
  bool _isLoading = true;
  bool _isSaving = false;
  File? _profileImage;
  String? _profileImageUrl;
  bool _hasMedicalInfo = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Firebase Auth verilerini al
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
        _profileImageUrl = user.photoURL;

        // Firestore verilerini al
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final profile = userData?['profile'] ?? {};

          setState(() {
            _phoneController.text = userData?['phoneNumber'] ?? '';
            _ageController.text = profile['age']?.toString() ?? '';
            _heightController.text = profile['height']?.toString() ?? '';
            _weightController.text = profile['weight']?.toString() ?? '';
            _gender = profile['gender'];
            _allergiesController.text = profile['allergies'] ?? '';
            _medicalConditionsController.text = profile['medicalConditions'] ?? '';
            _hasMedicalInfo = profile['medicalInfo'] ?? false;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Kullanıcı verileri yüklenemedi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Profil resmini yükle (varsa)
        String? photoURL = _profileImageUrl;
        if (_profileImage != null) {
          photoURL = await _uploadProfileImage(_profileImage!, user.uid);
        }

        // Firebase Auth profilini güncelle
        await user.updateDisplayName(_nameController.text.trim());
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }

        // Email değiştiyse
        if (_emailController.text.trim() != user.email && _emailController.text.trim().isNotEmpty) {
          await user.verifyBeforeUpdateEmail(_emailController.text.trim());
          _showSnackBar('E-posta adresinizi güncellemek için doğrulama e-postası gönderildi');
        }

        // Firestore verilerini güncelle
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'email': user.email,
          'photoURL': photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
          'profile': {
            'age': _ageController.text.isEmpty ? null : int.tryParse(_ageController.text),
            'height': _heightController.text.isEmpty ? null : double.tryParse(_heightController.text),
            'weight': _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
            'gender': _gender,
            'allergies': _allergiesController.text.trim(),
            'medicalConditions': _medicalConditionsController.text.trim(),
            'medicalInfo': _hasMedicalInfo,
          }
        }, SetOptions(merge: true));

        _showSnackBar('Profil bilgileriniz başarıyla güncellendi');
      }
    } catch (e) {
      _showSnackBar('Profil güncellenirken hata oluştu: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<String?> _uploadProfileImage(File imageFile, String userId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      _showSnackBar('Profil resmi yüklenirken hata oluştu: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnackBar('Resim seçilirken hata oluştu: $e');
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
        title: const Text('Profil Bilgileri'),
        actions: [
          if (!_isLoading && !_isSaving)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveUserData,
              tooltip: 'Kaydet',
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
            Text('Profil bilgileriniz kaydediliyor...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profil fotoğrafı
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 64,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : null),
                      child: (_profileImageUrl == null && _profileImage == null)
                          ? const Icon(Icons.person, size: 64, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickImage,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Temel bilgiler başlığı
              const Text(
                'Temel Bilgiler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Ad Soyad
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen ad soyad giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // E-posta
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen e-posta giriniz';
                  }

                  // Basit e-posta doğrulaması
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Geçerli bir e-posta adresi giriniz';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '+90 5XX XXX XX XX',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Kişisel bilgiler başlığı
              const Text(
                'Kişisel Bilgiler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Yaş, boy ve kilo - yan yana
              Row(
                children: [
                  // Yaş
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Yaş',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Boy
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Boy (cm)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Kilo
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Kilo (kg)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cinsiyet seçimi
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Cinsiyet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Sağlık bilgileri
              SwitchListTile(
                title: const Text(
                  'Sağlık Bilgilerini Ekle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Acil durumda önemli olabilecek sağlık bilgilerinizi ekleyin',
                ),
                value: _hasMedicalInfo,
                onChanged: (value) {
                  setState(() {
                    _hasMedicalInfo = value;
                  });
                },
              ),
              const SizedBox(height: 8),

              if (_hasMedicalInfo) ...[
                // Alerjiler
                TextFormField(
                  controller: _allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Alerjiler',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_amber),
                    hintText: 'Varsa alerjilerinizi yazın',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Sağlık durumları
                TextFormField(
                  controller: _medicalConditionsController,
                  decoration: const InputDecoration(
                    labelText: 'Sağlık Durumları',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                    hintText: 'Kronik hastalıklar, ilaçlar, vb.',
                  ),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 30),

              // Kaydet butonu
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saveUserData,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Değişiklikleri Kaydet',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
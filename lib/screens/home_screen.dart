
// 📄 Dosya: home_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Ana ekran - Modern tasarım, animasyonlar ve son olaylar

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/fall_event_model.dart';
import '../services/firebase_service.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Animasyon kontrolcüleri
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _cardController;
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _cardAnimation;

  // Kullanıcı bilgileri
  String _userName = '';
  String? _userPhotoUrl;

  // İstatistikler
  int _totalEvents = 0;
  int _todayEvents = 0;
  bool _systemActive = true;

  // Son olaylar
  List<FallEvent> _recentEvents = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadStatistics();
    _loadRecentEvents();
    _startSystemCheck();
  }

  // Animasyonları başlat
  void _initializeAnimations() {
    // Dalga animasyonu
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    );

    // Nabız animasyonu
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Kart animasyonu
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );
    _cardController.forward();
  }

  // Kullanıcı bilgilerini yükle
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? user.email?.split('@')[0] ?? 'Kullanıcı';
        _userPhotoUrl = user.photoURL;
      });
    }
  }

  // İstatistikleri yükle
  Future<void> _loadStatistics() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Toplam olay sayısı - basit bir query
      final totalSnapshot = await _firestore
          .collection('fall_events')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // Bugünkü olay sayısı
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      int todayCount = 0;
      for (var doc in totalSnapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          if (timestamp.isAfter(todayStart)) {
            todayCount++;
          }
        }
      }

      setState(() {
        _totalEvents = totalSnapshot.size;
        _todayEvents = todayCount;
      });
    } catch (e) {
      print('İstatistik yükleme hatası: $e');
    }
  }

  // Son olayları yükle
  Future<void> _loadRecentEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final events = await _firebaseService.getRecentFallEvents(limit: 5);
      setState(() {
        _recentEvents = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      print('Son olaylar yükleme hatası: $e');
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  // Sistem durumunu kontrol et
  void _startSystemCheck() {
    // Her 5 saniyede bir sistem durumunu kontrol et
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _systemActive = !_systemActive;
        });
        _startSystemCheck();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStatistics();
            await _loadRecentEvents();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Üst Başlık ve Hoşgeldin
                _buildHeader(screenHeight),

                // Güvenlik Durumu Kartı
                _buildSecurityStatusCard(screenWidth),

                // İstatistik Kartları
                _buildStatisticsCards(),

                // Son Olaylar Bölümü
                _buildRecentEventsSection(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Üst başlık widget'ı
  Widget _buildHeader(double screenHeight) {
    return Container(
      height: screenHeight * 0.25,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900,
            Colors.blueAccent,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Arka plan dalgaları
          ...List.generate(3, (index) =>
              AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      wavePhase: _waveAnimation.value + (index * 0.3),
                      waveHeight: 30,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    size: Size(MediaQuery.of(context).size.width, screenHeight * 0.25),
                  );
                },
              ),
          ),

          // İçerik
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white24,
                      backgroundImage: _userPhotoUrl != null
                          ? CachedNetworkImageProvider(_userPhotoUrl!)
                          : null,
                      child: _userPhotoUrl == null
                          ? const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTurkishDate(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Türkçe tarih formatı
  String _getTurkishDate() {
    final now = DateTime.now();
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    final days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];

    return '${now.day} ${months[now.month - 1]} ${now.year}, ${days[now.weekday - 1]}';
  }

  // Güvenlik durumu kartı
  Widget _buildSecurityStatusCard(double screenWidth) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ScaleTransition(
        scale: _cardAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _systemActive
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_systemActive ? Colors.green : Colors.orange).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _systemActive ? Icons.shield_outlined : Icons.warning_amber_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _systemActive ? 'Sistem Aktif' : 'Sistem Kontrol Ediliyor',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _systemActive
                          ? 'Güvendesiniz, her şey kontrol altında!'
                          : 'Lütfen bekleyin...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Animasyonlu çizgi
                    Container(
                      height: 4,
                      width: screenWidth * 0.6,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: _systemActive ? 1.0 : _waveAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // İstatistik kartları
  Widget _buildStatisticsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.event_available,
              title: 'Bugün',
              value: _todayEvents.toString(),
              color: Colors.blue,
              subtitle: 'Olay',
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildStatCard(
              icon: Icons.assessment,
              title: 'Toplam',
              value: _totalEvents.toString(),
              color: Colors.purple,
              subtitle: 'Olay',
            ),
          ),
        ],
      ),
    );
  }

  // İstatistik kartı widget'ı
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Son olaylar bölümü
  Widget _buildRecentEventsSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Olaylar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Bildirimler sayfasına gitmek için callback kullanabiliriz
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bildirimler sayfasına gitmek için alt menüyü kullanın'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 15),

          _isLoadingEvents
              ? const Center(child: CircularProgressIndicator())
              : _recentEvents.isEmpty
              ? _buildNoEventCard()
              : Column(
            children: _recentEvents
                .map((event) => _buildEventCard(event))
                .toList(),
          ),
        ],
      ),
    );
  }

  // Olay kartı
  Widget _buildEventCard(FallEvent event) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final probability = (event.probability * 100).toInt();
    final color = _getEventColor(event.probability);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Detay sayfasına git
              DefaultTabController.of(context).animateTo(1);
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  // Sol taraf - İkon ve yüzde
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: color,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '%$probability',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),

                  // Orta kısım - Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Düşme Algılandı',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(event.timestamp),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sağ taraf - Görsel varsa
                  if (event.screenshotUrl != null)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(event.screenshotUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Olay yok kartı
  Widget _buildNoEventCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Harika! Olay Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Henüz düşme olayı algılanmadı',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }



  // Selamlama mesajı
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Günaydın,';
    } else if (hour < 18) {
      return 'İyi günler,';
    } else {
      return 'İyi akşamlar,';
    }
  }

  // Olay rengi
  Color _getEventColor(double probability) {
    if (probability < 0.5) {
      return Colors.green;
    } else if (probability < 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

// Dalga animasyonu için custom painter
class WavePainter extends CustomPainter {
  final double wavePhase;
  final double waveHeight;
  final Color color;

  WavePainter({
    required this.wavePhase,
    required this.waveHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height -
          (waveHeight * math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi)));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return wavePhase != oldDelegate.wavePhase;
  }
}
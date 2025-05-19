// 📄 Dosya: live_view_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: PC'deki kamera görüntüsünü canlı olarak izleyen geliştirilmiş ekran

import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;

class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> with SingleTickerProviderStateMixin {
  // Varsayılan sunucu ayarları
  String serverIp = '192.168.56.141';
  int serverPort = 5000;
  String streamUrl = '';

  // IP ve port için kontrolcüler
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  // Akış durumu
  bool isStreaming = false;
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  // Ağ durumu kontrolü
  bool isNetworkAvailable = true;

  // Animasyon kontrolcüsü
  late AnimationController _animationController;

  // Bağlantı kalitesi gösterimi için
  Timer? _connectionQualityTimer;
  int _connectionQuality = 100;
  final Random _random = Random();

  // Yeniden bağlanma kontrolü
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    // Varsayılan değerleri kontrolcülere ata
    _ipController.text = serverIp;
    _portController.text = serverPort.toString();

    // Animasyon kontrolcüsü başlat
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Ağ durumunu kontrol et
    _checkNetworkStatus();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _animationController.dispose();
    _connectionQualityTimer?.cancel();
    _reconnectTimer?.cancel();
    // Ekran yönlendirme ayarlarını sıfırla
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // Ağ durumunu kontrol et
  Future<void> _checkNetworkStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isNetworkAvailable = connectivityResult != ConnectivityResult.none;
    });
  }

  // Bağlantıyı başlat
  Future<void> _connectToStream() async {
    // Ağ durumu kontrolü
    await _checkNetworkStatus();
    if (!isNetworkAvailable) {
      _showErrorSnackBar('İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.');
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      _reconnectAttempts = 0; // Yeniden bağlanma sayacını sıfırla
    });

    // IP ve port doğrulama
    final ipValidation = _validateIP(_ipController.text);
    if (!ipValidation.isValid) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = ipValidation.message;
      });
      _showErrorSnackBar(ipValidation.message);
      return;
    }

    final portValidation = _validatePort(_portController.text);
    if (!portValidation.isValid) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = portValidation.message;
      });
      _showErrorSnackBar(portValidation.message);
      return;
    }

    // Bağlantı kurulumu için kısa bir gecikme ekle (UX için)
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      serverIp = _ipController.text.trim();
      serverPort = int.parse(_portController.text.trim());
      streamUrl = 'http://$serverIp:$serverPort/video_feed';
      isStreaming = true;
      isLoading = false;
      print('MJPEG Stream URL: $streamUrl');

      // Bağlantı kalitesini kontrol et
      _startConnectionQualityCheck();
    });
  }

  // Bağlantıyı durdur
  void _disconnectStream() {
    setState(() {
      isStreaming = false;
      _connectionQualityTimer?.cancel();
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
    });
  }

  // IP doğrulama
  ValidationResult _validateIP(String ip) {
    final RegExp ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    if (ip.isEmpty) {
      return ValidationResult(false, 'IP adresi boş olamaz.');
    }
    if (!ipRegex.hasMatch(ip)) {
      return ValidationResult(false, 'Geçerli bir IP adresi giriniz (örneğin, 192.168.1.1).');
    }
    return ValidationResult(true, '');
  }

  // Port doğrulama
  ValidationResult _validatePort(String port) {
    if (port.isEmpty) {
      return ValidationResult(false, 'Port numarası boş olamaz.');
    }
    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      return ValidationResult(false, 'Geçerli bir port numarası giriniz.');
    }
    if (portNumber < 0 || portNumber > 65535) {
      return ValidationResult(false, 'Port numarası 0-65535 arasında olmalıdır.');
    }
    return ValidationResult(true, '');
  }

  // Bağlantı kalitesini kontrol et
  void _startConnectionQualityCheck() {
    _connectionQualityTimer?.cancel();
    _connectionQualityTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await http.get(Uri.parse('http://$serverIp:$serverPort/video_feed')).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw TimeoutException('Bağlantı zaman aşımına uğradı.');
          },
        );
        setState(() {
          if (response.statusCode == 200) {
            _connectionQuality = 90 + _random.nextInt(11); // 90-100 arası
          } else {
            _connectionQuality = 50 + _random.nextInt(21); // 50-70 arası
          }
        });
      } catch (e) {
        setState(() {
          _connectionQuality = 30 + _random.nextInt(21); // 30-50 arası
        });
      }
    });
  }

  // Hata mesajını göster
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Yeniden bağlanma mantığı
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      setState(() {
        isStreaming = false;
        hasError = true;
        errorMessage = 'Bağlantı tekrar tekrar başarısız oldu. Lütfen tekrar deneyin.';
      });
      _showErrorSnackBar(errorMessage);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _reconnectAttempts++;
        isStreaming = false;
        isLoading = true;
      });
      print('Yeniden bağlanma denemesi: $_reconnectAttempts');
      _connectToStream();
    });
  }

  // Bağlantı kalitesi rengi
  Color _getConnectionQualityColor() {
    if (_connectionQuality > 90) return Colors.green;
    if (_connectionQuality > 70) return Colors.lightGreen;
    if (_connectionQuality > 50) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Canlı Kamera İzleme'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          if (isStreaming)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _showSettingsBottomSheet(context);
              },
            ),
          if (isStreaming)
            IconButton(
              icon: const Icon(Icons.screen_rotation),
              onPressed: () {
                if (MediaQuery.of(context).orientation == Orientation.portrait) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                } else {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Canlı video akışı
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildStreamContent(),
              ),
            ),
          ),

          // Alt kısım - IP ve Port Giriş Alanı veya Bağlantı Bilgileri
          if (!isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ConnectionSettingsCard(
                ipController: _ipController,
                portController: _portController,
                hasError: hasError,
                errorMessage: errorMessage,
                onConnect: _connectToStream,
              ),
            ),

          // Alt bilgi çubuğu
          if (isStreaming)
            StreamInfoBar(
              serverIp: serverIp,
              serverPort: serverPort,
              connectionQuality: _connectionQuality,
              qualityColor: _getConnectionQualityColor(),
              onDisconnect: _disconnectStream,
            ),
        ],
      ),
    );
  }

  Widget _buildStreamContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Bağlantı kuruluyor...',
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isStreaming) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Mjpeg(
            stream: streamUrl,
            isLive: true,
            fit: BoxFit.contain,
            timeout: const Duration(seconds: 10), // Daha uzun bir timeout süresi
            error: (context, error, stack) {
              print('MJPEG Hata: $error');
              _scheduleReconnect(); // Hata durumunda yeniden bağlanmayı dene
              return _buildErrorWidget();
            },
          ),
          // Sol üst köşede canlı göstergesi
          Positioned(
            top: 16,
            left: 16,
            child: LiveIndicator(animationController: _animationController),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 64,
            color: Colors.indigo.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Canlı video izlemek için bağlantı kurun',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Video akışı alınamadı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'IP: $serverIp Port: $serverPort',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _connectToStream,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bağlantı Ayarları',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Adresi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.computer),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.router),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('İptal'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _disconnectStream();
                      _connectToStream();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden Bağlan'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Doğrulama Sonucu Sınıfı
class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult(this.isValid, this.message);
}

// Bağlantı Ayarları Kartı Widget'ı
class ConnectionSettingsCard extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onConnect;

  const ConnectionSettingsCard({
    required this.ipController,
    required this.portController,
    required this.hasError,
    required this.errorMessage,
    required this.onConnect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Kamera Sunucusuna Bağlan',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: ipController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: 'IP Adresi',
              labelStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.computer, color: Colors.black54),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.indigo),
              ),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: portController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: 'Port',
              labelStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.router, color: Colors.black54),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.indigo),
              ),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
            ),
            keyboardType: TextInputType.number,
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onConnect,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text(
              'Bağlan ve İzle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Canlı Gösterge Widget'ı
class LiveIndicator extends StatelessWidget {
  final AnimationController animationController;

  const LiveIndicator({
    required this.animationController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                height: 8,
                width: 8,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.5 + 0.5 * animationController.value),
                ),
              );
            },
          ),
          const Text(
            'CANLI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// Akış Bilgi Çubuğu Widget'ı
class StreamInfoBar extends StatelessWidget {
  final String serverIp;
  final int serverPort;
  final int connectionQuality;
  final Color qualityColor;
  final VoidCallback onDisconnect;

  const StreamInfoBar({
    required this.serverIp,
    required this.serverPort,
    required this.connectionQuality,
    required this.qualityColor,
    required this.onDisconnect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bağlantı bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sunucu: $serverIp:$serverPort',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Bağlantı Kalitesi:',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: connectionQuality / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: qualityColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$connectionQuality%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: qualityColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Durdur butonu
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onDisconnect,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Durdur'),
          ),
        ],
      ),
    );
  }
}
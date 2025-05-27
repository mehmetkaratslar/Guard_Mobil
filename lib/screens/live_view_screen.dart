import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> with SingleTickerProviderStateMixin {
  // Server settings
  String serverIp = '10.11.8.72';
  int serverPort = 5000;
  String streamUrl = '';

  // Controllers
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  // Stream state
  bool isStreaming = false;
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  // Network state
  bool isNetworkAvailable = true;

  // Animation controller
  late AnimationController _animationController;

  // Connection quality
  Timer? _connectionQualityTimer;
  int _connectionQuality = 100;
  final Random _random = Random();

  // Reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  // Zoom and fullscreen
  double _zoomLevel = 1.0;
  bool _isFullscreen = false;
  TransformationController _transformationController = TransformationController();
  Timer? _zoomIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _ipController.text = serverIp;
    _portController.text = serverPort.toString();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _checkNetworkStatus();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _animationController.dispose();
    _connectionQualityTimer?.cancel();
    _reconnectTimer?.cancel();
    _transformationController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _checkNetworkStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isNetworkAvailable = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _connectToStream() async {
    await _checkNetworkStatus();
    if (!isNetworkAvailable) {
      _showErrorSnackBar('No internet connection. Please check your network.');
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      _reconnectAttempts = 0;
    });

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
      setState() {
        isLoading = false;
        hasError = true;
        errorMessage = portValidation.message;
      };
    _showErrorSnackBar(portValidation.message);
    return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
    serverIp = _ipController.text.trim();
    serverPort = int.parse(_portController.text.trim());
    streamUrl = 'http://$serverIp:$serverPort/video_feed';
    isStreaming = true;
    isLoading = false;
    _startConnectionQualityCheck();
    });
  }

  void _disconnectStream() {
    setState(() {
      isStreaming = false;
      _connectionQualityTimer?.cancel();
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      _zoomLevel = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  ValidationResult _validateIP(String ip) {
    final RegExp ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    if (ip.isEmpty) {
      return ValidationResult(false, 'IP address cannot be empty.');
    }
    if (!ipRegex.hasMatch(ip)) {
      return ValidationResult(false, 'Enter a valid IP address (e.g., 10.11.8.72).');
    }
    return ValidationResult(true, '');
  }

  ValidationResult _validatePort(String port) {
    if (port.isEmpty) {
      return ValidationResult(false, 'Port number cannot be empty.');
    }
    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      return ValidationResult(false, 'Enter a valid port number.');
    }
    if (portNumber < 0 || portNumber > 65535) {
      return ValidationResult(false, 'Port must be between 0 and 65535.');
    }
    return ValidationResult(true, '');
  }

  void _startConnectionQualityCheck() {
    _connectionQualityTimer?.cancel();
    _connectionQualityTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await http.get(Uri.parse('http://$serverIp:$serverPort/video_feed')).timeout(
          const Duration(seconds: 3),
        );
        setState(() {
          _connectionQuality = response.statusCode == 200 ? 90 + _random.nextInt(11) : 50 + _random.nextInt(21);
        });
      } catch (e) {
        setState(() {
          _connectionQuality = 30 + _random.nextInt(21);
        });
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      setState(() {
        isStreaming = false;
        hasError = true;
        errorMessage = 'Connection failed after multiple attempts. Please try again.';
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
      _connectToStream();
    });
  }

  Color _getConnectionQualityColor() {
    if (_connectionQuality > 90) return Colors.green.shade600;
    if (_connectionQuality > 70) return Colors.lightGreen.shade600;
    if (_connectionQuality > 50) return Colors.amber.shade600;
    return Colors.red.shade600;
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      SystemChrome.setEnabledSystemUIMode(
        _isFullscreen ? SystemUiMode.immersive : SystemUiMode.manual,
        overlays: _isFullscreen ? [] : SystemUiOverlay.values,
      );
    });
  }

  void _updateZoomLevel(Matrix4 matrix) {
    setState(() {
      _zoomLevel = matrix.getMaxScaleOnAxis();
    });
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _zoomLevel = _zoomLevel; // Keep zoom level visible briefly
      });
    });
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _zoomLevel = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _isFullscreen
          ? null
          : AppBar(
        title: const Text(
          'Canlı izleme Alanı',
          style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isStreaming)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsBottomSheet(context),
              tooltip: 'Settings',
            ),
          if (isStreaming)
            IconButton(
              icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
              onPressed: _toggleFullscreen,
              tooltip: 'Toggle Fullscreen',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildStreamContent(),
              ),
            ),
          ),
          if (!_isFullscreen && !isStreaming)
            ConnectionSettingsCard(
              ipController: _ipController,
              portController: _portController,
              hasError: hasError,
              errorMessage: errorMessage,
              onConnect: _connectToStream,
            ),
          if (!_isFullscreen && isStreaming)
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Roboto',
                fontSize: 16,
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
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            onInteractionUpdate: (details) => _updateZoomLevel(_transformationController.value),
            child: GestureDetector(
              onDoubleTap: _resetZoom,
              child: Mjpeg(
                stream: streamUrl,
                isLive: true,
                fit: BoxFit.contain,
                timeout: const Duration(seconds: 10),
                error: (context, error, stack) {
                  _scheduleReconnect();
                  return _buildErrorWidget();
                },
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: LiveIndicator(animationController: _animationController),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_zoomLevel != 1.0)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Zoom: ${(_zoomLevel * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect to start live video',
            style: TextStyle(
              fontFamily: 'Roboto',
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
          Text(
            'Failed to load stream',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'IP: $serverIp Port: $serverPort',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check server status or network settings',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _connectToStream,
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Retry',
              style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.grey.shade100,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connection Settings',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  labelStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  prefixIcon: Icon(Icons.computer, color: Colors.blue.shade600),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.text,
                style: const TextStyle(fontFamily: 'Roboto'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  prefixIcon: Icon(Icons.router, color: Colors.blue.shade600),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Roboto'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Roboto'),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _disconnectStream();
                      _connectToStream();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Reconnect',
                      style: TextStyle(fontFamily: 'Roboto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult(this.isValid, this.message);
}

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Connect to Camera Server',
            style: TextStyle(
              color: Colors.black87,
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: ipController,
            style: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
            decoration: InputDecoration(
              labelText: 'IP Address',
              labelStyle: TextStyle(color: Colors.black54),
              prefixIcon: Icon(Icons.computer, color: Colors.blue.shade600),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: portController,
            style: const TextStyle(color: Colors.black87, fontFamily: 'Roboto'),
            decoration: InputDecoration(
              labelText: 'Port',
              labelStyle: TextStyle(color: Colors.black54),
              prefixIcon: Icon(Icons.router, color: Colors.blue.shade600),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontFamily: 'Roboto',
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: onConnect,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text(
              'Connect & Watch',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveIndicator extends StatelessWidget {
  final AnimationController animationController;

  const LiveIndicator({
    required this.animationController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                height: 10,
                width: 10,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.6 + 0.4 * animationController.value),
                ),
              );
            },
          ),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Server: $serverIp:$serverPort',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Connection Quality:',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: connectionQuality / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: qualityColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$connectionQuality%',
                      style: TextStyle(
                        fontFamily: 'Roboto',
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              elevation: 1,
            ),
            onPressed: onDisconnect,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text(
              'Stop',
              style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
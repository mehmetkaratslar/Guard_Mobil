// 📄 Dosya: notifications_screen.dart
// 📁 Konum: lib/screens/
// 📌 Açıklama: Bildirimler ekranı - Firebase'den düşme olaylarını gerçek zamanlı gösterir, ekran görüntüleriyle

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/fall_event_model.dart';

class NotificationsScreen extends StatefulWidget {
  final String? eventId;
  const NotificationsScreen({Key? key, this.eventId}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  final List<FallEvent> _events = [];

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _showEventDetailsById(widget.eventId!);
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_lastDocument == null || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final snapshot = await _firestore
            .collection('fall_events')
            .where('user_id', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize)
            .get();

        final newEvents = snapshot.docs
            .map((doc) => FallEvent.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        setState(() {
          _events.addAll(newEvents);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Daha fazla olay yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _showEventDetailsById(String eventId) async {
    try {
      final doc = await _firestore.collection('fall_events').doc(eventId).get();
      if (doc.exists) {
        final event = FallEvent.fromMap(doc.data() as Map<String, dynamic>);
        _showEventDetails(event);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Olay bulunamadı')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Olay detayları yüklenemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Lütfen giriş yapın')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Yenile',
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('fall_events')
            .where('user_id', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .limit(_pageSize)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            String errorMessage = 'Bir hata oluştu: ${snapshot.error}';
            if (snapshot.error.toString().contains('PERMISSION_DENIED')) {
              errorMessage = 'Erişim izni reddedildi. Lütfen Firebase izinlerini kontrol edin.';
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(errorMessage),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasData) {
            final newEvents = snapshot.data!.docs
                .map((doc) => FallEvent.fromMap(doc.data() as Map<String, dynamic>))
                .toList();

            if (_events.isEmpty) {
              _events.addAll(newEvents);
              _lastDocument = snapshot.data!.docs.isNotEmpty ? snapshot.data!.docs.last : null;
            }
          }

          if (_events.isEmpty) {
            return _buildEmptyState();
          }

          return _buildEventsList();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bildirim Bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Henüz düşme olayı algılanmadı.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _events.clear();
          _lastDocument = null;
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _events.length + (_lastDocument != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _events.length && _lastDocument != null) {
            return _buildLoadMoreButton();
          }
          final event = _events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _loadMoreEvents,
          child: const Text('Daha Fazla Yükle'),
        ),
      ),
    );
  }

  Widget _buildEventCard(FallEvent event) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final dateString = dateFormat.format(event.timestamp);
    final probabilityPercent = (event.probability * 100).toStringAsFixed(2);

    Color priorityColor;
    if (event.probability < 0.5) {
      priorityColor = Colors.green;
    } else if (event.probability < 0.8) {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: priorityColor,
                  size: 24,
                ),
              ),
              title: const Text(
                'Düşme Algılandı',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(dateString),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '%$probabilityPercent',
                  style: TextStyle(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (event.screenshotUrl != null)
              Container(
                width: double.infinity,
                height: 160,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: event.screenshotUrl!,
                  fit: BoxFit.cover,
                  memCacheHeight: 320,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(FallEvent event) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss');
    final dateString = dateFormat.format(event.timestamp);
    final probabilityPercent = (event.probability * 100).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      'Düşme Olayı Detayları',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (event.screenshotUrl != null)
                    Container(
                      width: double.infinity,
                      height: 250,
                      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: event.screenshotUrl!,
                        fit: BoxFit.cover,
                        memCacheHeight: 500,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            'Tarih ve Saat',
                            dateString,
                            Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoCard(
                            'Olasılık',
                            '%$probabilityPercent',
                            Icons.bar_chart,
                            valueColor: event.probability < 0.5
                                ? Colors.green
                                : event.probability < 0.8
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Kapat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _markEventAsRead(event);
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Okundu'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markEventAsRead(FallEvent event) async {
    try {
      await _firestore.collection('fall_events').doc(event.id).update({
        'is_read': true,
      });
      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          _events[index] = event.copyWith(isRead: true);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Olay okundu olarak işaretlendi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
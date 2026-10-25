import 'package:flutter/material.dart';

import '../api_service.dart';
import 'login_page.dart';
import 'event_detail_page.dart';
import 'order_history_page.dart';

const Color brandColor = Color(0xFF5B50E8);

class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  num parsePrice(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;

    final text = value.toString().trim();
    if (text.isEmpty) return 0;

    final direct = num.tryParse(text);
    if (direct != null) return direct;

    final cleaned = text
        .replaceAll(RegExp(r'rp', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .trim();

    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      return num.tryParse(
            cleaned.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    if (cleaned.contains('.')) {
      return num.tryParse(cleaned.replaceAll('.', '')) ?? 0;
    }

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        return num.tryParse('${parts[0]}.${parts[1]}') ?? 0;
      }
      return num.tryParse(cleaned.replaceAll(',', '')) ?? 0;
    }

    return num.tryParse(cleaned) ?? 0;
  }

  num eventPrice(Map<String, dynamic> event) {
    for (final key in [
      'price',
      'ticket_price',
      'price_per_ticket',
      'harga',
      'ticketPrice',
      'harga_tiket',
      'event_price',
      'amount',
    ]) {
      if (event[key] != null) {
        return parsePrice(event[key]);
      }
    }

    return 0;
  }

  String formatRupiah(dynamic value) {
    final amount = parsePrice(value).round();
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);

      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp $buffer';
  }

  String eventTitle(Map<String, dynamic> event) {
    return (event['title'] ??
            event['name'] ??
            event['event_name'] ??
            'Event')
        .toString();
  }

  String eventDescription(Map<String, dynamic> event) {
    return (event['description'] ??
            event['deskripsi'] ??
            'Belum ada deskripsi event.')
        .toString();
  }

  String eventDate(Map<String, dynamic> event) {
    final value = event['event_date'] ??
        event['date'] ??
        event['tanggal'] ??
        event['start_date'];

    if (value == null || value.toString().isEmpty) {
      return 'Tanggal belum tersedia';
    }

    return value.toString();
  }

  int availableTickets(Map<String, dynamic> event) {
    final value = event['available_tickets'] ??
        event['tickets_available'] ??
        event['stock'] ??
        0;

    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void openEventDetail(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event),
      ),
    );
  }

  Future<void> openOrderHistory() async {
    Navigator.pop(context);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrderHistoryPage(),
      ),
    );

    if (mounted) {
      loadEvents();
    }
  }

  Future<void> logout() async {
    Navigator.pop(context);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari akun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    await ApiService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Widget buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              color: brandColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.confirmation_number,
                      size: 34,
                      color: brandColor,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Event Ticketers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pesan tiket event dengan mudah',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Daftar Event'),
              selected: true,
              selectedColor: brandColor,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Riwayat Pesanan'),
              onTap: openOrderHistory,
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: logout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(
        title: const Text(
          'Event Ticketers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang event',
            icon: const Icon(Icons.refresh),
            onPressed: loadEvents,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 250),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.cloud_off,
            size: 64,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat event',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    if (events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Belum ada event tersedia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Silakan periksa kembali nanti.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brandColor, Color(0xFF958BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temukan Event Favoritmu!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Jelajahi event dan pesan tiketmu dengan mudah.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Daftar Event',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        ...events.map((item) {
          if (item is! Map) {
            return const SizedBox.shrink();
          }

          final event = Map<String, dynamic>.from(item);
          final price = eventPrice(event);
          final stock = availableTickets(event);
          final isSoldOut = stock <= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 30,
                          color: brandColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventTitle(event),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    eventDate(event),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    eventDescription(event),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isSoldOut
                            ? Icons.event_busy
                            : Icons.confirmation_number_outlined,
                        size: 18,
                        color: isSoldOut ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSoldOut
                            ? 'Tiket habis'
                            : 'Tersedia $stock tiket',
                        style: TextStyle(
                          color: isSoldOut ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatRupiah(price),
                          style: const TextStyle(
                            color: brandColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => openEventDetail(event),
                        child: const Text('Lihat Detail'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
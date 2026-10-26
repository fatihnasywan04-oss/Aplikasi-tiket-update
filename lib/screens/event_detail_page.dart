import 'package:flutter/material.dart';

import 'booking_page.dart';

const Color eventBrandColor = Color(0xFF5B50E8);

class EventDetailPage extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  String get title =>
      (event['title'] ?? event['name'] ?? 'Event').toString();

  String get description =>
      (event['description'] ?? 'Belum ada deskripsi event.').toString();

  String get location =>
      (event['location'] ?? 'Lokasi belum tersedia').toString();

  DateTime? get parsedDate {
    final value = event['event_date'] ?? event['date'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String get formattedDate {
    final date = parsedDate;
    if (date == null) return 'Tanggal belum tersedia';

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day ${months[date.month - 1]} ${date.year}, '
        'pukul $hour:$minute';
  }

  num get price {
    final value = event['price'] ?? 0;
    if (value is num) return value;

    final text = value.toString().trim();
    final direct = num.tryParse(text);
    if (direct != null) return direct;

    final cleaned = text
        .replaceAll(RegExp(r'Rp', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      return num.tryParse(
            cleaned.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        return num.tryParse('${parts[0]}.${parts[1]}') ?? 0;
      }
      return num.tryParse(cleaned.replaceAll(',', '')) ?? 0;
    }

    if (cleaned.contains('.')) {
      return num.tryParse(cleaned.replaceAll('.', '')) ?? 0;
    }

    return num.tryParse(cleaned) ?? 0;
  }

  int get stock {
    final value = event['available_tickets'] ??
        event['tickets_available'] ??
        event['stock'] ??
        0;

    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String formatRupiah(num amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp $buffer';
  }

  Widget buildEventImage() {
    final imageUrl = event['image_url']?.toString().trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 230,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return buildImagePlaceholder();
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return Container(
            height: 230,
            alignment: Alignment.center,
            color: const Color(0xFFECEAFF),
            child: const CircularProgressIndicator(
              color: eventBrandColor,
            ),
          );
        },
      );
    }

    return buildImagePlaceholder();
  }

  Widget buildImagePlaceholder() {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [eventBrandColor, Color(0xFF958BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        color: Colors.white,
        size: 82,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = stock <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Detail Event'),
        backgroundColor: eventBrandColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: buildEventImage(),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          _detailRow(
            Icons.calendar_month_outlined,
            formattedDate,
          ),
          const SizedBox(height: 14),
          _detailRow(
            Icons.location_on_outlined,
            location,
          ),
          const SizedBox(height: 14),
          _detailRow(
            soldOut
                ? Icons.event_busy
                : Icons.confirmation_number_outlined,
            soldOut ? 'Tiket habis' : 'Tersedia $stock tiket',
            color: soldOut ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 26),
          const Text(
            'Deskripsi Event',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECEBF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Harga Tiket',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 5),
                Text(
                  price == 0 ? 'Gratis' : formatRupiah(price),
                  style: const TextStyle(
                    fontSize: 25,
                    color: eventBrandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: soldOut
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingPage(event: event),
                        ),
                      );
                    },
              icon: Icon(
                soldOut
                    ? Icons.event_busy
                    : Icons.shopping_cart_outlined,
              ),
              label: Text(
                soldOut ? 'Tiket Habis' : 'Pesan Tiket',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: eventBrandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String text, {
    Color color = Colors.black87,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

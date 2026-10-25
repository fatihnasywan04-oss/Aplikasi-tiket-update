
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

  String get eventDate =>
      (event['event_date'] ?? event['date'] ?? 'Tanggal belum tersedia')
          .toString();

  num get price {
    final value = event['price'] ?? 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
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

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = stock <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Event'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  eventBrandColor,
                  Color(0xFF958BFF),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: Colors.white,
              size: 82,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _detailRow(Icons.calendar_month, eventDate),
          const SizedBox(height: 12),
          _detailRow(Icons.location_on_outlined, location),
          const SizedBox(height: 12),
          _detailRow(
            soldOut ? Icons.event_busy : Icons.confirmation_number,
            soldOut ? 'Tiket habis' : 'Tersedia $stock tiket',
            color: soldOut ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'Deskripsi Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Harga Tiket',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(price),
            style: const TextStyle(
              fontSize: 25,
              color: eventBrandColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
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
    Color color = Colors.grey,
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
              color: color == Colors.grey
                  ? Colors.black87
                  : color,
            ),
          ),
        ),
      ],
    );
  }
}

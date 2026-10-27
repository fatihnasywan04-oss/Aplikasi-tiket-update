
import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  String _getValue(
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  num _toNumber(dynamic value) {
    if (value is num) return value;

    if (value == null) return 0;

    var raw = value.toString().trim();

    if (raw.isEmpty) return 0;

    // Menghilangkan simbol mata uang dan spasi.
    raw = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');

    // Format API biasanya berupa angka biasa atau desimal.
    // Format Indonesia seperti 350.000 dibaca sebagai 350000.
    if (raw.contains('.') && raw.contains(',')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (raw.contains('.')) {
      final parts = raw.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        raw = raw.replaceAll('.', '');
      }
    } else if (raw.contains(',')) {
      final parts = raw.split(',');
      if (parts.length > 1 && parts.last.length == 3) {
        raw = raw.replaceAll(',', '');
      } else {
        raw = raw.replaceAll(',', '.');
      }
    }

    return num.tryParse(raw) ?? 0;
  }

  String _formatPrice(num value) {
    final digits = value.round().toString();
    final result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        result.write('.');
      }

      result.write(digits[i]);
    }

    return 'Rp $result';
  }

  String _getPriceRange() {
    // Cari daftar kelas tiket yang mungkin disertakan oleh API.
    dynamic rawClasses;

    for (final key in [
      'ticket_classes',
      'ticketClasses',
      'ticket_types',
      'ticketTypes',
      'tickets',
      'kelas_tiket',
    ]) {
      if (event[key] is List) {
        rawClasses = event[key];
        break;
      }
    }

    final prices = <num>[];

    if (rawClasses is List) {
      for (final item in rawClasses) {
        if (item is! Map) continue;

        final ticket = Map<String, dynamic>.from(item);
        final rawPrice = ticket['price'] ??
            ticket['ticket_price'] ??
            ticket['harga'];

        if (rawPrice == null) continue;

        final price = _toNumber(rawPrice);

        if (price >= 0) {
          prices.add(price);
        }
      }
    }

    if (prices.isNotEmpty) {
      prices.sort();

      if (prices.first == prices.last) {
        return 'Mulai dari ${_formatPrice(prices.first)}';
      }

      return 'Mulai dari ${_formatPrice(prices.first)} - '
          '${_formatPrice(prices.last)}';
    }

    // Fallback untuk API yang hanya mengirim satu harga event.
    final singlePrice = event['price'] ??
        event['ticket_price'] ??
        event['harga'];

    if (singlePrice != null) {
      return 'Mulai dari ${_formatPrice(_toNumber(singlePrice))}';
    }

    return 'Harga belum tersedia';
  }

  @override
  Widget build(BuildContext context) {
    final title = _getValue(
      ['title', 'name', 'nama_event'],
      fallback: 'Event',
    );

    final category = _getValue(
      ['category', 'kategori'],
      fallback: 'Event',
    );

    final location = _getValue(
      ['location', 'venue', 'lokasi'],
      fallback: 'Lokasi belum tersedia',
    );

    final image = _getValue(
      ['image_url', 'poster_url', 'image', 'gambar'],
      fallback: '',
    );

    final priceRange = _getPriceRange();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.5,
              child: image.isEmpty
                  ? _imagePlaceholder()
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE8FF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B50E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF282738),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF77778A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF77778A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    priceRange,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5B50E8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jangkauan harga tiket',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF77778A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEAE8FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        color: Color(0xFF5B50E8),
        size: 44,
      ),
    );
  }
}

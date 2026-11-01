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
        return value.toString().trim();
      }
    }

    return fallback;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDate(DateTime date) {
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

    return '$day ${months[date.month - 1]} ${date.year}';
  }

  String _getEventDateRange() {
    final startDate = _parseDate(
      event['event_date'] ?? event['start_date'] ?? event['date'],
    );

    final endDate = _parseDate(
      event['end_date'] ?? event['endDate'],
    );

    if (startDate == null) {
      return 'Tanggal belum tersedia';
    }

    if (endDate == null ||
        (startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day)) {
      return _formatDate(startDate);
    }

    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  num _toNumber(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;

    var raw = value.toString().trim();

    if (raw.isEmpty) return 0;

    raw = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');

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

        prices.add(_toNumber(rawPrice));
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

    final singlePrice = event['price'] ??
        event['ticket_price'] ??
        event['harga'];

    if (singlePrice != null) {
      return 'Mulai dari ${_formatPrice(_toNumber(singlePrice))}';
    }

    return 'Harga belum tersedia';
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEAE8FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        color: Color(0xFF5B50E8),
        size: 40,
      ),
    );
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

    final eventDate = _getEventDateRange();
    final priceRange = _getPriceRange();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GAMBAR EVENT
            AspectRatio(
              aspectRatio: 1.6,
              child: image.isEmpty
                  ? _imagePlaceholder()
                  : Image.network(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) {
                        return _imagePlaceholder();
                      },
                    ),
            ),

            // INFORMASI EVENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KATEGORI
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
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

                    // JUDUL EVENT
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF282738),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // TANGGAL EVENT
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF77778A),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            eventDate,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Color(0xFF77778A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // LOKASI
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF77778A),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Color(0xFF77778A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // HARGA TIKET
                    Text(
                      priceRange,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5B50E8),
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Jangkauan harga tiket',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF77778A),
                      ),
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
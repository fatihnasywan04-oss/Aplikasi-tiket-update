import 'package:flutter/material.dart';

import '../core/app_colors.dart';

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
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _getEventDateRange() {
    final startDate = _parseDate(
      event['event_date'] ?? event['start_date'] ?? event['date'],
    );

    final endDate = _parseDate(
      event['end_date'] ?? event['endDate'],
    );

    if (startDate == null) return 'Tanggal belum tersedia';

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

    for (var i = 0; i < digits.length; i++) {
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

        if (rawPrice != null) {
          prices.add(_toNumber(rawPrice));
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
      color: AppColors.surfaceDark,
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        color: AppColors.gold,
        size: 42,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.gold,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
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
      color: AppColors.surface,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // GAMBAR EVENT
            AspectRatio(
              aspectRatio: 1.65,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? _imagePlaceholder()
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return _imagePlaceholder();
                          },
                        ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // INFORMASI EVENT
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // KATEGORI
                  Container(
                    constraints: const BoxConstraints(maxWidth: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 11),

                  // JUDUL EVENT
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // TANGGAL
                  _buildInfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: eventDate,
                  ),

                  const SizedBox(height: 9),

                  // LOKASI
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),

                  const SizedBox(height: 13),

                  Container(
                    height: 1,
                    width: double.infinity,
                    color: AppColors.border,
                  ),

                  const SizedBox(height: 10),

                  // HARGA TIKET
                  Text(
                    priceRange,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Jangkauan harga tiket',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
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
}
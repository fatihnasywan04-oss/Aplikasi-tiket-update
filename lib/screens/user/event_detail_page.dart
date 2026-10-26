import 'package:flutter/material.dart';

import 'booking_page.dart';

class EventDetailPage extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  String _value(
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

  String _formatPrice(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final number = num.tryParse(cleaned);

    if (number == null) return 'Rp 0';

    final digits = number.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return 'Rp $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final title = _value(
      ['title', 'name', 'nama_event'],
      fallback: 'Event',
    );

    final image = _value(
      ['image_url', 'poster_url', 'image', 'gambar'],
      fallback: '',
    );

    final location = _value(
      ['location', 'venue', 'lokasi'],
      fallback: 'Lokasi belum tersedia',
    );

    final date = _value(
      ['date', 'event_date', 'tanggal'],
      fallback: 'Tanggal belum tersedia',
    );

    final description = _value(
      ['description', 'deskripsi'],
      fallback: 'Belum ada deskripsi event.',
    );

    final price = _value(
      ['price', 'ticket_price', 'harga'],
      fallback: '0',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: const Color(0xFF5B50E8),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: image.isEmpty
                  ? Container(
                      color: const Color(0xFFEAE8FF),
                      child: const Center(
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 76,
                          color: Color(0xFF5B50E8),
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return Container(
                          color: const Color(0xFFEAE8FF),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 70,
                              color: Color(0xFF5B50E8),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF282738),
                  ),
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi',
                  value: location,
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Tanggal',
                  value: date,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tentang event',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF282738),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    height: 1.6,
                    color: Color(0xFF77778A),
                  ),
                ),
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFEAEAF3)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga tiket',
                      style: TextStyle(
                        color: Color(0xFF77778A),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatPrice(price),
                      style: const TextStyle(
                        color: Color(0xFF5B50E8),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B50E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingPage(event: event),
                    ),
                  );
                },
                child: const Text(
                  'Pesan Tiket',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAE8FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5B50E8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF77778A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF282738),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

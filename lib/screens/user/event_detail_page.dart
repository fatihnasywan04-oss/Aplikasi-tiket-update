import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_page.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  static const Color primary = Color(0xFF5B50E8);
  static const Color background = Color(0xFFF7F7FC);
  static const Color dark = Color(0xFF282738);
  static const Color muted = Color(0xFF77778A);

  static const Duration _wibOffset = Duration(hours: 7);

  Map<String, dynamic> get event => widget.event;

  static const List<String> _months = [
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

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? get _eventId => _readInt(
        event['id'] ?? event['event_id'],
      );

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

  // ============================================================
  // INSTAGRAM
  // ============================================================

  String? get _instagramUsername {
    final rawUsername =
        event['instagram_username']?.toString().trim();

    if (rawUsername == null || rawUsername.isEmpty) {
      return null;
    }

    final username = rawUsername.replaceFirst(
      RegExp(r'^@'),
      '',
    );

    if (username.isEmpty) {
      return null;
    }

    return username;
  }

  Future<void> _openInstagram() async {
    final username = _instagramUsername;

    if (username == null) return;

    final uri = Uri.https(
      'www.instagram.com',
      '/$username/',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat membuka profil Instagram.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Terjadi kesalahan saat membuka Instagram.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FORMAT TANGGAL
  // ============================================================

  DateTime? _parseEventDate(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    final hasTimezone = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(raw);

    if (hasTimezone) {
      return parsed.toUtc().add(_wibOffset);
    }

    return parsed;
  }

  String _formatEventDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  String _formatEventDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${_formatEventDate(date)}, $hour:$minute';
  }

  String get _eventDateRange {
    final startDate = _parseEventDate(
      event['event_date'] ??
          event['start_date'] ??
          event['date'] ??
          event['tanggal'],
    );

    final endDate = _parseEventDate(
      event['end_date'] ?? event['endDate'],
    );

    if (startDate == null) {
      return 'Tanggal belum tersedia';
    }

    if (endDate == null || endDate.isAtSameMomentAs(startDate)) {
      return _formatEventDateTime(startDate);
    }

    final sameDay =
        startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    if (sameDay) {
      final startHour = startDate.hour.toString().padLeft(2, '0');
      final startMinute = startDate.minute.toString().padLeft(2, '0');
      final endHour = endDate.hour.toString().padLeft(2, '0');
      final endMinute = endDate.minute.toString().padLeft(2, '0');

      return '${_formatEventDate(startDate)}, '
          '$startHour:$startMinute - $endHour:$endMinute';
    }

    return '${_formatEventDateTime(startDate)}'
        ' - ${_formatEventDateTime(endDate)}';
  }

  // ============================================================
  // BOOKING
  // ============================================================

  void _openBooking() {
    final eventId = _eventId;

    if (eventId == null || eventId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID event tidak valid.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingPage(
          event: {
            ...event,
            'id': eventId,
          },
        ),
      ),
    );
  }
  // ============================================================
  // BUILD
  // ============================================================

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

    final description = _value(
      ['description', 'deskripsi'],
      fallback: 'Belum ada deskripsi event.',
    );

    final category = _value(
      ['category', 'kategori'],
      fallback: 'Event',
    );

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: image.isEmpty
                  ? Container(
                      color: const Color(0xFFEAE8FF),
                      child: const Center(
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 76,
                          color: primary,
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFEAE8FF),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 70,
                              color: primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  category,
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 22),

                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi',
                  value: location,
                ),
                const SizedBox(height: 16),

                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Tanggal event',
                  value: _eventDateRange,
                ),

                // Instagram hanya ditampilkan jika username tersedia.
                if (_instagramUsername != null) ...[
                  const SizedBox(height: 16),
                  _InstagramInfoRow(
                    username: _instagramUsername!,
                    onTap: _openInstagram,
                  ),
                ],

                const SizedBox(height: 26),

                const Text(
                  'Tentang event',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  description,
                  style: const TextStyle(
                    height: 1.6,
                    color: muted,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),

      // Tombol hanya mengarahkan pengguna ke halaman Booking.
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFEAEAF3),
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openBooking,
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text(
                'Beli Tiket Sekarang',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

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

// ============================================================
// INSTAGRAM INFO ROW
// ============================================================

class _InstagramInfoRow extends StatelessWidget {
  final String username;
  final VoidCallback onTap;

  const _InstagramInfoRow({
    required this.username,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFCE8F1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFFE1306C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instagram',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF77778A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE1306C),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new,
            size: 18,
            color: Color(0xFF77778A),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
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
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.text,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isEmpty)
                    Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 76,
                          color: AppColors.gold,
                        ),
                      ),
                    )
                  else
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 70,
                              color: AppColors.gold,
                            ),
                          ),
                        );
                      },
                    ),

                  // Overlay agar gambar menyatu dengan tema Hikari.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x220B0A14),
                          Color(0x000B0A14),
                          Color(0xCC0B0A14),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 13),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 24),

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

                const SizedBox(height: 28),

                Container(
                  height: 1,
                  color: AppColors.border,
                ),

                const SizedBox(height: 24),

                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'Tentang event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  description,
                  style: const TextStyle(
                    height: 1.7,
                    color: AppColors.textSecondary,
                    fontSize: 14,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              top: BorderSide(
                color: AppColors.border,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: AppColors.primaryLight,
                    width: 0.5,
                  ),
                ),
              ),
              onPressed: _openBooking,
              icon: const Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.gold,
              ),
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
            color: AppColors.primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.gold,
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
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.4,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.sakura.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.sakura.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.sakura,
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
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.sakura,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.sakura,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
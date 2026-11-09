
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_detail_page.dart';
import 'admin_event_form_page.dart';
import 'admin_event_drawer_page.dart';

class AdminEventEventsPage extends StatefulWidget {
  const AdminEventEventsPage({super.key});

  @override
  State<AdminEventEventsPage> createState() =>
      _AdminEventEventsPageState();
}

class _AdminEventEventsPageState
    extends State<AdminEventEventsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadEvents();
  }

  // Mengambil semua event milik Admin Event,
  // termasuk pending, approved, dan rejected.
  Future<List<Map<String, dynamic>>> _loadEvents() async {
    return ApiService.getMyEvents();
  }

  Future<void> _refresh() async {
    final future = _loadEvents();

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // Error ditampilkan melalui FutureBuilder.
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  String _eventName(Map<String, dynamic> event) {
    return (event['title'] ??
            event['name'] ??
            'Tanpa nama')
        .toString();
  }

  String _eventLocation(Map<String, dynamic> event) {
    return (event['location'] ??
            event['venue'] ??
            'Lokasi belum ditentukan')
        .toString();
  }

  // Mengubah tanggal menjadi WIB (UTC+7).
  DateTime? _parseWibDate(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    try {
      final parsed = DateTime.parse(raw);

      if (RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
        final wib = parsed.toUtc().add(
              const Duration(hours: 7),
            );

        return DateTime(
          wib.year,
          wib.month,
          wib.day,
          wib.hour,
          wib.minute,
          wib.second,
        );
      }

      // Tanggal tanpa informasi timezone dianggap WIB.
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDate(dynamic value) {
    final date = _parseWibDate(value);

    if (date == null) {
      return value?.toString() ?? 'Tanggal belum ditentukan';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _eventDate(Map<String, dynamic> event) {
    final start = event['event_date'] ??
        event['start_date'] ??
        event['date'];

    final end = event['end_date'];

    if (start == null) {
      return 'Tanggal belum ditentukan';
    }

    final startDate = _formatDate(start);

    if (end == null || end.toString().trim().isEmpty) {
      return startDate;
    }

    final parsedStart = _parseWibDate(start);
    final parsedEnd = _parseWibDate(end);

    if (parsedStart != null &&
        parsedEnd != null &&
        parsedStart.year == parsedEnd.year &&
        parsedStart.month == parsedEnd.month &&
        parsedStart.day == parsedEnd.day) {
      return '${parsedStart.day.toString().padLeft(2, '0')}/'
          '${parsedStart.month.toString().padLeft(2, '0')}/'
          '${parsedStart.year} '
          '${parsedStart.hour.toString().padLeft(2, '0')}:'
          '${parsedStart.minute.toString().padLeft(2, '0')} - '
          '${parsedEnd.hour.toString().padLeft(2, '0')}:'
          '${parsedEnd.minute.toString().padLeft(2, '0')} WIB';
    }

    return '$startDate - ${_formatDate(end)}';
  }

  String _formatRupiah(num amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return 'Rp $buffer';
  }

  List<Map<String, dynamic>> _getTicketClasses(
    Map<String, dynamic> event,
  ) {
    final raw = event['ticket_classes'] ??
        event['ticketClasses'] ??
        event['ticket_classes_list'] ??
        event['ticket_types'] ??
        event['ticketTypes'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  String _ticketPriceRange(Map<String, dynamic> event) {
    final ticketClasses = _getTicketClasses(event);
    final prices = <num>[];

    for (final ticket in ticketClasses) {
      final price = _toNum(
        ticket['price'] ??
            ticket['ticket_price'] ??
            ticket['harga'],
      );

      if (price != null && price >= 0) {
        prices.add(price);
      }
    }

    if (prices.isNotEmpty) {
      prices.sort();

      if (prices.first == prices.last) {
        return _formatRupiah(prices.first);
      }

      return '${_formatRupiah(prices.first)} - '
          '${_formatRupiah(prices.last)}';
    }

    final basePrice = _toNum(
          event['price'] ??
              event['ticket_price'] ??
              event['harga'],
        ) ??
        0;

    return _formatRupiah(basePrice);
  }

  String _eventStatus(Map<String, dynamic> event) {
    return (event['approval_status'] ??
            event['status'] ??
            'pending')
        .toString()
        .toLowerCase();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.white70;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
        return 'Menunggu Persetujuan';
      default:
        return status;
    }
  }

  Widget _buildStatus(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
          color: Colors.white54,
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = _eventStatus(event);
    final ticketClasses = _getTicketClasses(event);

    final isCancelled = event['is_cancelled'] == true;
    final isDeleted = event['is_deleted'] == true;

    final ticketCount = ticketClasses.isNotEmpty
        ? ticketClasses.length
        : _toInt(event['ticket_class_count'] ??
                event['ticket_classes_count']) ??
            0;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminEventDetailPage(
                event: event,
              ),
            ),
          );

          if (mounted) {
            await _refresh();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _eventName(event),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatus(status),
                ],
              ),

              if (isCancelled || isDeleted) ...[
                const SizedBox(height: 9),
                Text(
                  isDeleted
                      ? 'EVENT DIHAPUS'
                      : 'EVENT DIBATALKAN',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              _buildInfoRow(
                icon: Icons.location_on_outlined,
                text: _eventLocation(event),
              ),

              const SizedBox(height: 9),

              _buildInfoRow(
                icon: Icons.calendar_month_outlined,
                text: _eventDate(event),
              ),

              const SizedBox(height: 9),

              _buildInfoRow(
                icon: Icons.confirmation_number_outlined,
                text: 'Harga tiket: ${_ticketPriceRange(event)}',
              ),

              if (ticketCount > 0) ...[
                const SizedBox(height: 9),
                _buildInfoRow(
                  icon: Icons.category_outlined,
                  text: '$ticketCount kelas tiket',
                ),
              ],

              const SizedBox(height: 14),

              const Divider(
                color: Colors.white12,
                height: 1,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.white54,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Lihat detail event dan kelas tiket',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.event_busy_outlined,
          size: 65,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Belum Ada Event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 35),
          child: Text(
            'Buat event pertamamu beserta kelas tiketnya, '
            'kemudian tunggu persetujuan dari Super Admin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_outlined,
          color: Colors.white54,
          size: 55,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Gagal Memuat Event',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
        Center(
          child: FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AdminEventDrawerPage(),

      appBar: AppBar(
        title: const Text(
          'Event Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Event'),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminEventFormPage(),
            ),
          );

          if (result == true && mounted) {
            await _refresh();
          }
        },
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _buildError(
                snapshot.error.toString(),
              );
            }

            final events = snapshot.data ?? [];

            if (events.isEmpty) {
              return _buildEmpty();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event =
                    Map<String, dynamic>.from(events[index]);

                return _buildEventCard(event);
              },
            );
          },
        ),
      ),
    );
  }
}

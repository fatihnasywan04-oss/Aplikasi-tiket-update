
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
    return await ApiService.getMyEvents();
  }

  Future<void> _refresh() async {
    final future = _loadEvents();

    setState(() {
      _future = future;
    });

    await future;
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

  String _eventName(Map<String, dynamic> event) {
    return (event['name'] ??
            event['title'] ??
            'Tanpa nama')
        .toString();
  }

  String _eventLocation(Map<String, dynamic> event) {
    return (event['location'] ??
            event['venue'] ??
            'Lokasi belum ditentukan')
        .toString();
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

    if (end == null || end.toString().isEmpty) {
      return startDate;
    }

    return '$startDate - ${_formatDate(end)}';
  }

  String _formatDate(dynamic value) {
    try {
      final date = DateTime.parse(value.toString()).toLocal();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  String _eventStatus(Map<String, dynamic> event) {
    return (event['approval_status'] ??
            event['status'] ??
            'pending')
        .toString()
        .toLowerCase();
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

  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = _eventStatus(event);

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white54,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _eventLocation(event),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white54,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _eventDate(event),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

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
                      'Lihat detail event',
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
            'Buat event pertamamu dan tunggu persetujuan '
            'dari Super Admin.',
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
                return _buildEventCard(events[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

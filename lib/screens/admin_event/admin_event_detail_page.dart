
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';
import 'admin_event_form_page.dart';
import 'admin_event_orders_page.dart';
import 'admin_event_payments_page.dart';
import 'admin_event_ticket_classes_page.dart';

class AdminEventDetailPage extends StatelessWidget {
  final Map<String, dynamic> event;

  const AdminEventDetailPage({
    super.key,
    required this.event,
  });

  String _readValue(
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

  String _formatDate(String value) {
    if (value == '-') return value;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final date = parsed.toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu Persetujuan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _info(String label, String value) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String status) {
    final color = _statusColor(status);

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Persetujuan',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 10),
              const Text(
                'Event sedang menunggu pemeriksaan Super Admin.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
            if (status.toLowerCase() == 'rejected') ...[
              const SizedBox(height: 10),
              Text(
                'Alasan penolakan: ${_readValue([
                  'rejection_reason',
                  'approval_rejection_reason',
                  'admin_event_rejection_reason',
                ])}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitDeletion(
    BuildContext context,
    int eventId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan Penghapusan Event?'),
        content: const Text(
          'Permintaan penghapusan akan dikirim kepada Super Admin '
          'untuk ditinjau. Event tidak langsung dihapus dan '
          'riwayat transaksi tetap dipertahankan.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteEvent(eventId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan penghapusan berhasil dikirim.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengajukan penghapusan: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventId = int.tryParse(
      _readValue(['id', 'event_id'], fallback: ''),
    );

    if (eventId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        drawer: const AdminEventDrawerPage(),
        appBar: AppBar(
          title: const Text('Detail Event'),
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.text,
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Buka menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'ID event tidak valid.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final status = _readValue(
      ['approval_status'],
      fallback: 'pending',
    );

    final isCancelled = event['is_cancelled'] == true;
    final isDeleted = event['is_deleted'] == true;
    final isUnavailable = isCancelled || isDeleted;

    final eventName = _readValue(
      ['name', 'title'],
      fallback: 'Tanpa nama',
    );
    final location = _readValue(['location', 'venue']);
    final startDate = _formatDate(
      _readValue(['event_date', 'start_date']),
    );
    final endDate = _formatDate(
      _readValue(['end_date']),
    );
    final description = _readValue(['description']);
    final price = _readValue(['price', 'ticket_price']);
    final availableTickets = _readValue([
      'available_tickets',
      'stock',
    ]);

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AdminEventDrawerPage(),
      appBar: AppBar(
        title: const Text('Detail Event'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Buka menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            eventName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _statusCard(status),

          if (isCancelled)
            _info('Kondisi Event', 'Event dibatalkan'),

          if (isDeleted)
            _info('Kondisi Event', 'Event telah dihapus'),

          _info('Lokasi', location),
          _info('Tanggal Mulai', startDate),
          _info('Tanggal Selesai', endDate),
          _info('Deskripsi', description),
          _info('Harga', price),
          _info('Tiket Tersedia', availableTickets),

          const SizedBox(height: 16),

          if (!isUnavailable) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEventFormPage(
                      event: event,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Ajukan Perubahan Event'),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEventTicketClassesPage(
                      eventId: eventId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Kelola Kelas Tiket'),
            ),

            const SizedBox(height: 8),
          ],

          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEventOrdersPage(
                    eventId: eventId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Lihat Pesanan'),
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEventPaymentsPage(
                    eventId: eventId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.payments),
            label: const Text('Lihat Pembayaran'),
          ),

          if (!isUnavailable) ...[
            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: () => _submitDeletion(
                context,
                eventId,
              ),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              label: const Text(
                'Ajukan Penghapusan Event',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

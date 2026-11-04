import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
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

  Widget _info(String label, String value) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventId = int.tryParse(event['id'].toString());

    if (eventId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Detail Event')),
        body: const Center(
          child: Text(
            'ID event tidak valid.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final status =
        event['approval_status']?.toString() ?? 'approved';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detail Event'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            event['name']?.toString() ?? 'Tanpa nama',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _info('Status', status),
          _info('Lokasi', event['location']?.toString() ?? '-'),
          _info('Tanggal', event['event_date']?.toString() ?? '-'),
          _info('Deskripsi', event['description']?.toString() ?? '-'),
          _info('Harga', event['price']?.toString() ?? '-'),
          _info(
            'Tiket tersedia',
            event['available_tickets']?.toString() ?? '-',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEventFormPage(event: event),
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
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminEventOrdersPage(eventId: eventId),
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
                  builder: (_) => AdminEventPaymentsPage(eventId: eventId),
                ),
              );
            },
            icon: const Icon(Icons.payments),
            label: const Text('Lihat Pembayaran'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Ajukan Penghapusan Event?'),
                  content: const Text(
                    'Penghapusan event harus disetujui Super Admin. '
                    'Riwayat transaksi tetap dipertahankan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, true),
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
                    content: Text('Permintaan penghapusan dikirim.'),
                  ),
                );

                Navigator.pop(context, true);
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal mengajukan penghapusan: $e')),
                );
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              'Ajukan Penghapusan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
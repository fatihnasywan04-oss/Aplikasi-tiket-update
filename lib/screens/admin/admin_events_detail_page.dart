import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../../core/currency_formatter.dart';
import 'admin_events_form_page.dart';
import 'admin_events_ticket_classes_page.dart';

class AdminEventsDetailPage extends StatelessWidget {
  final Map<String, dynamic> event;

  const AdminEventsDetailPage({
    super.key,
    required this.event,
  });

  // ============================================================
  // HELPERS
  // ============================================================

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

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
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
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _infoCard(String label, String value) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
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
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Persetujuan',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
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
                  fontSize: 13,
                ),
              ),
            ),
            if (status.toLowerCase() == 'rejected') ...[
              const SizedBox(height: 10),
              Text(
                'Alasan penolakan: ${_readValue([
                  'rejection_reason',
                  'approval_rejection_reason',
                  'admin_event_rejection_reason',
                ])}',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _confirmDelete(BuildContext context, int eventId) async {
    final title = _readValue(
      ['title', 'name', 'nama_event'],
      fallback: 'Event ini',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Hapus "$title"?'),
        content: const Text(
          'Event akan disembunyikan dari publik. Seluruh riwayat pesanan '
          'dan transaksi yang sudah ada akan tetap tersimpan di sistem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ApiService.deleteEvent(eventId);

      if (!context.mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Event berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus event: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final eventId = int.tryParse(
      _readValue(['id', 'event_id'], fallback: ''),
    );

    if (eventId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Detail Event'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.text,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'ID event tidak valid.',
            style: TextStyle(color: AppColors.text),
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
    final price = formatRupiah(
      num.tryParse(
        _readValue(['price', 'ticket_price'], fallback: '').trim(),
      ),
    );
    final availableTickets = _readValue([
      'available_tickets',
      'stock',
    ]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Event'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.text,
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            eventName,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _statusCard(status),

          if (isCancelled)
            _infoCard('Kondisi Event', 'Event dibatalkan'),

          if (isDeleted)
            _infoCard('Kondisi Event', 'Event telah dihapus'),

          _infoCard('Lokasi', location),
          _infoCard('Tanggal Mulai', startDate),
          _infoCard('Tanggal Selesai', endDate),
          _infoCard('Deskripsi', description),
          _infoCard('Harga', price),
          _infoCard('Tiket Tersedia', availableTickets),

          const SizedBox(height: 20),

          if (!isUnavailable) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEventsFormPage(
                      event: event,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Event'),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEventsTicketClassesPage(
                      eventId: eventId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Kelola Kelas Tiket'),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.6),
                ),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _confirmDelete(context, eventId),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus Event'),
            ),
          ],
        ],
      ),
    );
  }
}

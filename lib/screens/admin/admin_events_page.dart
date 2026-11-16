import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';
import 'admin_events_form_page.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _value(
    Map<String, dynamic> event,
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

  DateTime? _parseWibDateTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    try {
      final parsed = DateTime.parse(raw);

      if (RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
        final wib = parsed.toUtc().add(const Duration(hours: 7));

        return DateTime(
          wib.year,
          wib.month,
          wib.day,
          wib.hour,
          wib.minute,
          wib.second,
        );
      }

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

  DateTime? _eventDate(Map<String, dynamic> event) {
    final raw = _value(
      event,
      ['event_date', 'date', 'tanggal'],
      fallback: '',
    );

    if (raw.isEmpty) return null;
    return _parseWibDateTime(raw);
  }

  DateTime? _eventEndDate(Map<String, dynamic> event) {
    final raw = _value(event, ['end_date'], fallback: '');

    if (raw.isEmpty) return _eventDate(event);
    return _parseWibDateTime(raw) ?? _eventDate(event);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tanggal belum tersedia';

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

    return '${date.day} ${months[date.month - 1]} ${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return 'Tanggal belum tersedia';

    if (end == null ||
        (start.year == end.year &&
            start.month == end.month &&
            start.day == end.day &&
            start.hour == end.hour &&
            start.minute == end.minute)) {
      return _formatDate(start);
    }

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

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${start.day} ${months[start.month - 1]} ${start.year}, '
          '${start.hour.toString().padLeft(2, '0')}:'
          '${start.minute.toString().padLeft(2, '0')}–'
          '${end.hour.toString().padLeft(2, '0')}:'
          '${end.minute.toString().padLeft(2, '0')}';
    }

    return '${start.day} ${months[start.month - 1]} ${start.year} '
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')} – '
        '${end.day} ${months[end.month - 1]} ${end.year} '
        '${end.hour.toString().padLeft(2, '0')}:'
        '${end.minute.toString().padLeft(2, '0')}';
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

  String _priceRange(Map<String, dynamic> event) {
    final rawClasses = event['ticket_classes'] ??
        event['ticketClasses'] ??
        event['ticket_classes_list'] ??
        event['ticket_types'] ??
        event['ticketTypes'];

    final prices = <num>[];

    if (rawClasses is List) {
      for (final item in rawClasses) {
        if (item is! Map) continue;

        final ticket = Map<String, dynamic>.from(item);
        final rawPrice =
            ticket['price'] ?? ticket['ticket_price'] ?? ticket['harga'];

        if (rawPrice == null) continue;

        final price = num.tryParse(rawPrice.toString());
        if (price != null && price >= 0) prices.add(price);
      }
    }

    if (prices.isNotEmpty) {
      prices.sort();

      if (prices.first == prices.last) {
        return _formatRupiah(prices.first);
      }

      return '${_formatRupiah(prices.first)} – '
          '${_formatRupiah(prices.last)}';
    }

    final basePrice = _toNum(
      event['price'] ?? event['ticket_price'] ?? event['harga'],
    );

    return _formatRupiah(basePrice);
  }

  String _approvalStatus(Map<String, dynamic> event) {
    final status = (event['approval_status'] ??
            event['status'] ??
            'pending')
        .toString()
        .toLowerCase();

    switch (status) {
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

  Color _approvalColor(Map<String, dynamic> event) {
    final status = (event['approval_status'] ??
            event['status'] ??
            'pending')
        .toString()
        .toLowerCase();

    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return AppColors.error;
      default:
        return Colors.orange;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Mengambil event milik Admin Event,
      // termasuk event pending, approved, dan rejected.
      final result = await ApiService.getMyEvents();

      if (!mounted) return;

      setState(() {
        _events = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? event}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminEventsFormPage(event: event),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      _message(
        event == null
            ? 'Event dan kelas tiket berhasil diajukan.'
            : 'Perubahan event berhasil diajukan/disimpan.',
      );

      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> event) async {
    final id = _toInt(event['id'] ?? event['event_id']);

    if (id == null || id <= 0) {
      _message('ID event tidak valid.');
      return;
    }

    final title = _value(
      event,
      ['title', 'name', 'nama_event'],
      fallback: 'Event ini',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Apakah kamu yakin ingin menghapus "$title"?\n\n'),
        content: Text(
          'Event akan disembunyikan dari publik. Seluruh riwayat pesanan '
          'dan transaksi yang sudah ada akan tetap tersimpan di sistem. '
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

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteEvent(id);

      if (!mounted) return;

      _message('Permintaan penghapusan event berhasil diproses.');
      await _load();
    } catch (e) {
      if (!mounted) return;

      _message(
        'Gagal menghapus event: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _eventImagePlaceholder() {
    return const ColoredBox(
      color: AppColors.surfaceDark,
      child: Center(
        child: Icon(
          Icons.event_rounded,
          color: AppColors.gold,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final id = _toInt(event['id'] ?? event['event_id']);
    final title = _value(event, ['title', 'name', 'nama_event']);

    final location = _value(
      event,
      ['location', 'venue', 'lokasi'],
      fallback: 'Lokasi belum tersedia',
    );

    final image = _value(
      event,
      ['image_url', 'poster_url', 'image', 'gambar'],
      fallback: '',
    );

    final dateRange = _formatDateRange(
      _eventDate(event),
      _eventEndDate(event),
    );

    final priceRange = _priceRange(event);
    final isCancelled = event['is_cancelled'] == true;
    final isDeleted = event['is_deleted'] == true;
    final status = _approvalStatus(event);
    final statusColor = _approvalColor(event);

    final rejectionReason = _value(
      event,
      ['approval_rejection_reason'],
      fallback: '',
    );

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 104,
                    child: image.isEmpty
                        ? _eventImagePlaceholder()
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _eventImagePlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (status == 'Ditolak' &&
                          rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Alasan: $rejectionReason',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (isCancelled || isDeleted) ...[
                        const SizedBox(height: 6),
                        Text(
                          isDeleted
                              ? 'EVENT DIHAPUS'
                              : 'EVENT DIBATALKAN',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: location,
                      ),
                      const SizedBox(height: 7),
                      _InfoLine(
                        icon: Icons.calendar_month_outlined,
                        text: dateRange,
                      ),
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            size: 17,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Jangkauan Harga',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  priceRange,
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 26,
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: id == null || isCancelled || isDeleted
                        ? null
                        : () => _openForm(event: event),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Event'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Hapus event',
                  onPressed: isDeleted ? null : () => _delete(event),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kelola Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AdminDrawerPage(currentRoute: '/admin/events'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Event'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 44,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Event gagal dimuat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _events.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(28),
                      children: const [
                        SizedBox(height: 90),
                        Icon(
                          Icons.event_busy_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Belum ada event.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tekan Tambah Event untuk membuat event baru.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.gold,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 100,
                        ),
                        itemCount: _events.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final event =
                              Map<String, dynamic>.from(_events[index]);

                          return _buildEventCard(event);
                        },
                      ),
                    ),
    );
  }
}

// ============================================================
// MODEL INPUT KELAS TIKET
// ============================================================


class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';

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
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EventFormDialog(event: event),
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
        title: const Text('Hapus event?'),
        content: Text(
          'Apakah kamu yakin ingin menghapus "$title"?\n\n'
          'Jika event memiliki transaksi, backend harus '
          'menggunakan mekanisme soft-delete atau permintaan penghapusan '
          'agar riwayat pesanan dan pembayaran tetap dipertahankan.',
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

class _TicketClassInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController stockController;

  _TicketClassInput({
    String name = '',
    String price = '0',
    String stock = '0',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        stockController = TextEditingController(text: stock);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
  }
}

// ============================================================
// FORM EVENT DAN KELAS TIKET
// ============================================================

class _EventFormDialog extends StatefulWidget {
  final Map<String, dynamic>? event;

  const _EventFormDialog({required this.event});

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  static const List<String> _categories = [
    'Jejepangan',
    'Musik',
    'Gaming',
    'Anime & Cosplay',
    'Budaya',
    'Olahraga',
    'Seminar',
    'Teknologi',
    'Pendidikan',
    'Lainnya',
  ];

  String _selectedCategory = 'Lainnya';

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _instagramController;
  late final TextEditingController _imageController;

  final List<_TicketClassInput> _ticketClasses = [];

  XFile? _selectedImage;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;

  bool _saving = false;
  bool _removeExistingImage = false;

  bool get _isEditing => widget.event != null;

  DateTime _nowWib() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));

    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
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

  String _formatWibDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return '$year-$month-${day}T$hour:$minute:$second+07:00';
  }

  String _read(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  @override
  void initState() {
    super.initState();

    final event = widget.event ?? <String, dynamic>{};
    final existingCategory = _read(event, ['category']);

    _selectedCategory = _categories.contains(existingCategory)
        ? existingCategory
        : 'Lainnya';

    _titleController = TextEditingController(
      text: _read(event, ['title', 'name', 'nama_event']),
    );

    _descriptionController = TextEditingController(
      text: _read(event, ['description', 'deskripsi']),
    );

    _locationController = TextEditingController(
      text: _read(event, ['location', 'venue', 'lokasi']),
    );

    _instagramController = TextEditingController(
      text: _read(event, ['instagram_username']),
    );

    _imageController = TextEditingController(
      text: _read(event, ['image_url', 'poster_url', 'image', 'gambar']),
    );

    final parsedDate = _parseWibDateTime(
      _read(event, ['event_date', 'date', 'tanggal']),
    );

    if (parsedDate != null) {
      _selectedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );

      _selectedTime = TimeOfDay.fromDateTime(parsedDate);
    } else {
      final now = _nowWib();

      _selectedDate = DateTime(now.year, now.month, now.day + 1);
      _selectedTime = const TimeOfDay(hour: 19, minute: 0);
    }

    final parsedEndDate = _parseWibDateTime(
      _read(event, ['end_date']),
    );

    if (parsedEndDate != null) {
      _selectedEndDate = DateTime(
        parsedEndDate.year,
        parsedEndDate.month,
        parsedEndDate.day,
      );

      _selectedEndTime = TimeOfDay.fromDateTime(parsedEndDate);
    } else {
      _selectedEndDate = _selectedDate;
      _selectedEndTime = _selectedTime;
    }

    if (!_isEditing) {
      _ticketClasses.add(
        _TicketClassInput(
          name: 'Standard',
          price: '0',
          stock: '100',
        ),
      );
    }
  }

  num _toNumFallback(Map<String, dynamic>? event) {
    if (event == null) return 0;

    final value = event['price'] ??
        event['ticket_price'] ??
        event['harga'];

    if (value is num) return value;

    return num.tryParse(value?.toString() ?? '') ?? 0;
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

  String _ticketPriceRange() {
    final prices = <num>[];

    for (final ticket in _ticketClasses) {
      final price = num.tryParse(ticket.priceController.text.trim());

      if (price != null && price >= 0) {
        prices.add(price);
      }
    }

    if (prices.isEmpty) return 'Masukkan harga kelas tiket';

    prices.sort();

    if (prices.first == prices.last) {
      return 'Mulai dari ${_formatRupiah(prices.first)}';
    }

    return 'Mulai dari ${_formatRupiah(prices.first)} - '
        '${_formatRupiah(prices.last)}';
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Pilih tanggal';

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
    Future<void> _pickEventImage() async {
    if (_saving) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = image;
        _removeExistingImage = false;
      });
    } catch (e) {
      if (!mounted) return;

      _message(
        'Gagal memilih poster: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Widget _posterPlaceholder() {
    return const ColoredBox(
      color: AppColors.surfaceDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: AppColors.gold,
              size: 42,
            ),
            SizedBox(height: 8),
            Text(
              'Belum ada poster',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPicker() {
    final existingUrl = _removeExistingImage
        ? ''
        : _imageController.text.trim();

    Widget preview;

    if (_selectedImage != null) {
      preview = Image.file(
        File(_selectedImage!.path),
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _posterPlaceholder(),
      );
    } else if (existingUrl.isNotEmpty) {
      preview = Image.network(
        existingUrl,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _posterPlaceholder(),
      );
    } else {
      preview = _posterPlaceholder();
    }

    final hasPoster = _selectedImage != null || existingUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Poster Event (opsional)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 190,
              child: preview,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickEventImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    hasPoster ? 'Ganti Poster' : 'Pilih dari Galeri',
                  ),
                ),
              ),
              if (hasPoster) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Hapus poster',
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _selectedImage = null;
                            _removeExistingImage = true;
                          });
                        },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
          const Text(
            'Pilih gambar dari galeri. Poster baru akan diunggah '
            'ketika kamu menyimpan event.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _addTicketClass({
    String name = '',
    String price = '0',
    String stock = '0',
  }) {
    setState(() {
      _ticketClasses.add(
        _TicketClassInput(
          name: name,
          price: price,
          stock: stock,
        ),
      );
    });
  }

  void _removeTicketClass(int index) {
    if (_ticketClasses.length <= 1) {
      _message('Minimal harus ada satu jenis tiket.');
      return;
    }

    setState(() {
      final ticket = _ticketClasses.removeAt(index);
      ticket.dispose();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    _imageController.dispose();

    for (final ticket in _ticketClasses) {
      ticket.dispose();
    }

    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = _nowWib();
    final today = DateTime(now.year, now.month, now.day);

    final initial = _selectedDate ?? today.add(const Duration(days: 1));

    final firstDate = _isEditing ? DateTime(2000, 1, 1) : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 10),
      helpText: 'Pilih tanggal mulai event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = picked;

      if (_selectedEndDate == null ||
          _selectedEndDate!.isBefore(picked)) {
        _selectedEndDate = picked;
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ??
          const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Pilih waktu mulai event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() => _selectedTime = picked);
  }

  Future<void> _pickEndDate() async {
    final now = _nowWib();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = _selectedDate ?? today;
    final initial = _selectedEndDate ?? startDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(startDate) ? startDate : initial,
      firstDate: startDate,
      lastDate: DateTime(today.year + 10),
      helpText: 'Pilih tanggal selesai event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() => _selectedEndDate = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ??
          const TimeOfDay(hour: 21, minute: 0),
      helpText: 'Pilih waktu selesai event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() => _selectedEndTime = picked);
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }

    return null;
  }

  String? _instagramValidator(String? value) {
    final username = (value ?? '').trim().replaceFirst(
      RegExp(r'^@'),
      '',
    );

    if (username.isEmpty) return null;

    if (username.length > 30) {
      return 'Username Instagram maksimal 30 karakter.';
    }

    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return 'Username hanya boleh berisi huruf, angka, titik, dan underscore.';
    }

    return null;
  }

  String? _ticketNameValidator(String? value, int index) {
    final name = (value ?? '').trim();

    if (name.isEmpty) return 'Nama kelas tiket wajib diisi.';
    if (name.length > 30) {
      return 'Nama tiket maksimal 30 karakter.';
    }

    final normalized = name.toLowerCase();

    final duplicates = _ticketClasses.where((ticket) {
      return ticket.nameController.text.trim().toLowerCase() ==
          normalized;
    }).length;

    if (duplicates > 1) {
      return 'Nama kelas tiket tidak boleh duplikat.';
    }

    return null;
  }

  String? _ticketPriceValidator(String? value) {
    final price = num.tryParse((value ?? '').trim());

    if (price == null || !price.isFinite || price < 0) {
      return 'Masukkan harga yang valid.';
    }

    return null;
  }

  String? _ticketStockValidator(String? value) {
    final stock = int.tryParse((value ?? '').trim());

    if (stock == null || stock < 0) {
      return 'Stok harus bilangan bulat minimal 0.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null ||
        _selectedTime == null ||
        _selectedEndDate == null ||
        _selectedEndTime == null) {
      _message('Pilih tanggal dan waktu mulai serta selesai event.');
      return;
    }

    final chosenDateTime = _combineDateAndTime(
      _selectedDate!,
      _selectedTime!,
    );

    final chosenEndDateTime = _combineDateAndTime(
      _selectedEndDate!,
      _selectedEndTime!,
    );

    if (chosenEndDateTime.isBefore(chosenDateTime)) {
      _message(
        'Tanggal dan waktu selesai tidak boleh lebih awal '
        'dari tanggal dan waktu mulai.',
      );
      return;
    }

    if (!_isEditing && !chosenDateTime.isAfter(_nowWib())) {
      _message('Tanggal dan waktu mulai event harus di masa depan.');
      return;
    }

    num price;
    int totalStock = 0;

    // Data kelas tiket hanya disertakan ketika membuat event baru.
    if (_isEditing) {
      price = _toNumFallback(widget.event);
    } else {
      if (_ticketClasses.isEmpty) {
        _message('Tambahkan minimal satu jenis tiket.');
        return;
      }

      final ticketPrices = <num>[];
      final names = <String>[];

      for (final ticket in _ticketClasses) {
        final ticketName = ticket.nameController.text.trim();

        final ticketPrice = num.tryParse(
          ticket.priceController.text.trim(),
        );

        final ticketStock = int.tryParse(
          ticket.stockController.text.trim(),
        );

        if (ticketName.isEmpty ||
            ticketName.length > 30 ||
            ticketPrice == null ||
            !ticketPrice.isFinite ||
            ticketPrice < 0 ||
            ticketStock == null ||
            ticketStock < 0) {
          _message('Periksa kembali data setiap kelas tiket.');
          return;
        }

        ticketPrices.add(ticketPrice);
        names.add(ticketName.toLowerCase());

        totalStock += ticketStock;
      }

      if (names.toSet().length != names.length) {
        _message('Nama kelas tiket tidak boleh duplikat.');
        return;
      }

      ticketPrices.sort();
      price = ticketPrices.first;
    }

    final rawId = widget.event?['id'] ?? widget.event?['event_id'];

    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    if (_isEditing && (id == null || id <= 0)) {
      _message('ID event tidak valid untuk proses edit.');
      return;
    }

    setState(() => _saving = true);

    try {
      String? imageUrl = _removeExistingImage
          ? null
          : (_imageController.text.trim().isEmpty
              ? null
              : _imageController.text.trim());

      if (_selectedImage != null) {
        imageUrl = await ApiService.uploadEventImage(
          File(_selectedImage!.path),
        );
      }

      final instagramUsername = _instagramController.text
          .trim()
          .replaceFirst(RegExp(r'^@'), '');

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'image_url': imageUrl,
        'instagram_username':
            instagramUsername.isEmpty ? null : instagramUsername,
        'event_date': _formatWibDateTime(chosenDateTime),
        'end_date': _formatWibDateTime(chosenEndDateTime),
      };

      if (_isEditing) {
        // Edit event tetap mengikuti mekanisme update yang sudah ada.
        // Harga dan stok kelas tiket tidak diubah melalui form ini.
        await ApiService.updateEvent(id!, payload);
      } else {
        // Harga event = harga kelas tiket termurah.
        // Stok event = total stok seluruh kelas tiket.
        payload['price'] = price;
        payload['available_tickets'] = totalStock;

        // Semua kelas tiket dikirim bersama event dalam satu request.
        // Backend akan menyimpan event dan kelas tiket secara atomik.
        payload['ticket_classes'] = _ticketClasses.map((ticket) {
          return {
            'name': ticket.nameController.text.trim(),
            'price': num.parse(
              ticket.priceController.text.trim(),
            ),
            'available_tickets': int.parse(
              ticket.stockController.text.trim(),
            ),
          };
        }).toList();

        await ApiService.createEvent(payload);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _message(
        'Gagal ${_isEditing ? 'memperbarui event' : 'menyimpan event'}: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
          ),
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.gold,
              width: 1.4,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          labelText: 'Kategori Event *',
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.gold,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem<String>(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: _saving
            ? null
            : (value) {
                if (value == null) return;

                setState(() => _selectedCategory = value);
              },
      ),
    );
  }

  Widget _buildPriceRangeCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.gold,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Jangkauan Harga',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _ticketPriceRange(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dihitung otomatis dari harga kelas tiket termurah '
            'hingga termahal.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketClassFields(int index) {
    final ticket = _ticketClasses[index];

    return Card(
      key: ObjectKey(ticket),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kelas Tiket ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus kelas tiket',
                  onPressed: _saving
                      ? null
                      : () => _removeTicketClass(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: ticket.nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Nama tiket *',
                hintText: 'Standard, VIP, VVIP',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _ticketNameValidator(value, index),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ticket.priceController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Harga tiket (Rp) *',
                hintText: '100000',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: _ticketPriceValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ticket.stockController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Stok tiket *',
                hintText: '100',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: _ticketStockValidator,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String title,
    required String dateLabel,
    required String timeLabel,
    required VoidCallback onPickDate,
    required VoidCallback onPickTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateLabel),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : onPickTime,
            icon: const Icon(Icons.access_time),
            label: Text(timeLabel),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        _isEditing ? 'Edit Event' : 'Tambah Event',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  label: 'Nama event *',
                  controller: _titleController,
                  validator: (value) =>
                      _requiredValidator(value, 'Nama event'),
                ),
                _buildCategoryDropdown(),
                _field(
                  label: 'Deskripsi *',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) =>
                      _requiredValidator(value, 'Deskripsi'),
                ),
                _field(
                  label: 'Lokasi *',
                  controller: _locationController,
                  validator: (value) =>
                      _requiredValidator(value, 'Lokasi'),
                ),
                _field(
                  label: 'Username Instagram (opsional)',
                  controller: _instagramController,
                  hint: '@username',
                  validator: _instagramValidator,
                ),
                _buildPosterPicker(),

                if (!_isEditing) ...[
                  _buildPriceRangeCard(),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jenis Tiket',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tambahkan kelas tiket beserta harga dan stoknya. '
                      'Stok event dihitung dari total stok kelas tiket.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    _ticketClasses.length,
                    _buildTicketClassFields,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _addTicketClass(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Jenis Tiket'),
                    ),
                  ),
                ] else ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Harga dan stok kelas tiket tidak diubah melalui '
                      'form ini. Pengelolaan kelas tiket dilakukan '
                      'melalui fitur kelas tiket tersendiri.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                _buildDateTimePicker(
                  title: 'Tanggal dan waktu mulai event * (WIB)',
                  dateLabel: _dateLabel(_selectedDate),
                  timeLabel:
                      _selectedTime?.format(context) ?? 'Pilih waktu',
                  onPickDate: _pickStartDate,
                  onPickTime: _pickStartTime,
                ),
                const SizedBox(height: 16),
                _buildDateTimePicker(
                  title: 'Tanggal dan waktu selesai event * (WIB)',
                  dateLabel: _dateLabel(_selectedEndDate),
                  timeLabel: _selectedEndTime?.format(context) ??
                      'Pilih waktu',
                  onPickDate: _pickEndDate,
                  onPickTime: _pickEndTime,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Waktu yang dipilih menggunakan WIB (UTC+7). '
                  'Tanggal selesai harus sama atau setelah tanggal mulai. '
                  'Untuk event beberapa hari, pilih tanggal selesai '
                  'sesuai hari terakhir acara.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}

// ============================================================
// WIDGET BARIS INFORMASI EVENT
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
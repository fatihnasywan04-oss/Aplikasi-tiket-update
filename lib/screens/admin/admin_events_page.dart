
import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'admin_drawer_page.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  static const Color primary = Color(0xFF5B50E8);
  static const Color background = Color(0xFFF7F7FC);
  static const Color dark = Color(0xFF282738);
  static const Color muted = Color(0xFF77778A);

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

  DateTime? _eventDate(Map<String, dynamic> event) {
    final raw = _value(
      event,
      ['event_date', 'date', 'tanggal'],
      fallback: '',
    );

    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getEvents();

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
      builder: (_) => _EventFormDialog(
        event: event,
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      _message(
        event == null
            ? 'Event berhasil ditambahkan.'
            : 'Event berhasil diperbarui.',
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
        title: const Text('Hapus event?'),
        content: Text(
          'Event "$title" akan dihapus. '
          'Jika event sudah memiliki pesanan, gunakan pembatalan '
          'event agar riwayat pesanan tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
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

      _message('Event berhasil dihapus.');
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

    final date = _eventDate(event);

    final price = _toNum(
      event['price'] ?? event['ticket_price'] ?? event['harga'],
    );

    final isCancelled = event['is_cancelled'] == true;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAEAF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 82,
                    height: 96,
                    child: image.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFEAE8FF),
                            child: Icon(
                              Icons.event_rounded,
                              color: primary,
                              size: 34,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(
                              color: Color(0xFFEAE8FF),
                              child: Icon(
                                Icons.event_rounded,
                                color: primary,
                                size: 34,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
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
                          color: dark,
                          fontSize: 16,
                        ),
                      ),
                      if (isCancelled) ...[
                        const SizedBox(height: 5),
                        const Text(
                          'EVENT DIBATALKAN',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: location,
                      ),
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.calendar_month_outlined,
                        text: _formatDate(date),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatRupiah(price),
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: id == null || isCancelled
                        ? null
                        : () => _openForm(event: event),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Event'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Hapus event',
                  onPressed: () => _delete(event),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
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
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Kelola Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dark,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AdminDrawerPage(
        currentRoute: '/admin/events',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Event'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
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
                          color: muted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Event gagal dimuat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted),
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
                          color: muted,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Belum ada event.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tekan Tambah Event untuk membuat event baru.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 100,
                        ),
                        itemCount: _events.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final event = Map<String, dynamic>.from(
                            _events[index],
                          );
                          return _buildEventCard(event);
                        },
                      ),
                    ),
    );
  }
}

class _EventFormDialog extends StatefulWidget {
  final Map<String, dynamic>? event;

  const _EventFormDialog({
    required this.event,
  });

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _imageController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();

    final event = widget.event ?? <String, dynamic>{};

    _titleController = TextEditingController(
      text: _read(event, ['title', 'name', 'nama_event']),
    );

    _descriptionController = TextEditingController(
      text: _read(event, ['description', 'deskripsi']),
    );

    _locationController = TextEditingController(
      text: _read(event, ['location', 'venue', 'lokasi']),
    );

    _imageController = TextEditingController(
      text: _read(event, ['image_url', 'poster_url', 'image', 'gambar']),
    );

    _priceController = TextEditingController(
      text: _read(
        event,
        ['price', 'ticket_price', 'harga'],
        fallback: '0',
      ),
    );

    _stockController = TextEditingController(
      text: _read(
        event,
        ['available_tickets', 'stock', 'ticket_stock'],
        fallback: '0',
      ),
    );

    final rawDate = _read(
      event,
      ['event_date', 'date', 'tanggal'],
    );

    final parsedDate = DateTime.tryParse(rawDate);

    if (parsedDate != null) {
      _selectedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      _selectedTime = TimeOfDay.fromDateTime(parsedDate);
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day + 1);
      _selectedTime = const TimeOfDay(hour: 19, minute: 0);
    }
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _imageController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  String _dateLabel() {
    final date = _selectedDate;
    if (date == null) return 'Pilih tanggal event';

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate ?? today.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: 'Pilih tanggal event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Pilih waktu event',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked == null || !mounted) return;

    setState(() => _selectedTime = picked);
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }
    return null;
  }

  String? _numberValidator(
    String? value, {
    required String label,
    required bool allowZero,
  }) {
    final parsed = num.tryParse((value ?? '').trim());

    if (parsed == null) return '$label harus berupa angka.';

    if (parsed < 0 || (!allowZero && parsed == 0)) {
      return allowZero
          ? '$label tidak boleh negatif.'
          : '$label harus lebih dari nol.';
    }

    if (!allowZero && parsed != parsed.roundToDouble()) {
      return '$label harus berupa bilangan bulat.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      _message('Pilih tanggal dan waktu event.');
      return;
    }

    final now = DateTime.now();

    final chosenDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (!_isEditing && !chosenDateTime.isAfter(now)) {
      _message('Tanggal dan waktu event baru harus di masa depan.');
      return;
    }

    final price = num.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) {
      _message('Harga atau stok tidak valid.');
      return;
    }

    final eventId = widget.event?['id'] ?? widget.event?['event_id'];

    final id = eventId is int
        ? eventId
        : int.tryParse(eventId?.toString() ?? '');

    if (_isEditing && (id == null || id <= 0)) {
      _message('ID event tidak valid untuk proses edit.');
      return;
    }

    // FIX: backend menggunakan field event_date, bukan date.
    final dateIso = chosenDateTime.toIso8601String();

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'image_url': _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      'event_date': dateIso,
      'price': price,
      'available_tickets': stock,
    };

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await ApiService.updateEvent(id!, payload);
      } else {
        await ApiService.createEvent(payload);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _message(
        'Gagal ${_isEditing ? 'memperbarui' : 'membuat'} event: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String message) {
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
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Event' : 'Tambah Event',
        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  validator: (v) => _requiredValidator(v, 'Nama event'),
                ),
                _field(
                  label: 'Deskripsi *',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (v) => _requiredValidator(v, 'Deskripsi'),
                ),
                _field(
                  label: 'Lokasi *',
                  controller: _locationController,
                  validator: (v) => _requiredValidator(v, 'Lokasi'),
                ),
                _field(
                  label: 'URL gambar (opsional)',
                  controller: _imageController,
                  keyboardType: TextInputType.url,
                  hint: 'https://contoh.com/poster.jpg',
                  validator: (value) {
                    final text = (value ?? '').trim();

                    if (text.isEmpty) return null;

                    final uri = Uri.tryParse(text);

                    if (uri == null ||
                        !uri.hasScheme ||
                        !(uri.scheme == 'https' || uri.scheme == 'http') ||
                        uri.host.isEmpty) {
                      return 'Masukkan URL gambar yang valid.';
                    }

                    return null;
                  },
                ),
                _field(
                  label: 'Harga dasar (Rp) *',
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => _numberValidator(
                    v,
                    label: 'Harga',
                    allowZero: true,
                  ),
                ),
                _field(
                  label: 'Stok dasar *',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  validator: (v) => _numberValidator(
                    v,
                    label: 'Stok',
                    allowZero: true,
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tanggal event *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_dateLabel()),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Waktu event *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime?.format(context) ?? 'Pilih waktu',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Harga dan stok dasar digunakan jika backend '
                  'masih memerlukan field tersebut. Harga dan stok '
                  'kelas tiket dikelola melalui kelas tiket.',
                  style: TextStyle(
                    color: Colors.black54,
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
          label: Text(
            _saving ? 'Menyimpan...' : 'Simpan',
          ),
        ),
      ],
    );
  }
}

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
          color: const Color(0xFF77778A),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF77778A),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

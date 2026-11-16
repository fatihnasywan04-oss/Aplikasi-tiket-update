import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';

class _TicketClassInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController stockController;

  _TicketClassInput({String name = '', String price = '0', String stock = '0'})
    : nameController = TextEditingController(text: name),
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

class AdminEventsFormPage extends StatefulWidget {
  final Map<String, dynamic>? event;

  const AdminEventsFormPage({super.key, this.event});

  @override
  State<AdminEventsFormPage> createState() => _AdminEventsFormPageState();
}

class _AdminEventsFormPageState extends State<AdminEventsFormPage> {
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
  bool _loadingTickets = false;
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

    final parsedEndDate = _parseWibDateTime(_read(event, ['end_date']));

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
        _TicketClassInput(name: 'Standard', price: '0', stock: '100'),
      );
    } else {
      _loadExistingTicketClasses(event);
    }
  }

  void _populateTicketClasses(List<dynamic> classes) {
    for (final ticket in _ticketClasses) {
      ticket.dispose();
    }
    _ticketClasses.clear();

    for (final cls in classes) {
      if (cls is Map) {
        _ticketClasses.add(
          _TicketClassInput(
            name: cls['name']?.toString() ?? '',
            price: (cls['price'] ?? 0).toString(),
            stock: (cls['available_tickets'] ?? cls['stock'] ?? 0).toString(),
          ),
        );
      }
    }
  }

  Future<void> _loadExistingTicketClasses(Map<String, dynamic> event) async {
    final embedded = event['ticket_classes'];
    if (embedded is List && embedded.isNotEmpty) {
      _populateTicketClasses(embedded);
      return;
    }

    final rawId = event['id'] ?? event['event_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id <= 0) return;

    setState(() => _loadingTickets = true);
    try {
      final fetched = await ApiService.getTicketClasses(id);
      if (!mounted) return;
      setState(() {
        _populateTicketClasses(fetched);
      });
    } catch (_) {
      // Abaikan jika gagal memuat pratinjau kelas tiket
    } finally {
      if (mounted) {
        setState(() => _loadingTickets = false);
      }
    }
  }

  num _toNumFallback(Map<String, dynamic>? event) {
    if (event == null) return 0;

    final value = event['price'] ?? event['ticket_price'] ?? event['harga'];

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

    if (prices.isEmpty) {
      if (_isEditing) {
        final fallback = _toNumFallback(widget.event);
        if (fallback > 0) {
          return 'Mulai dari ${_formatRupiah(fallback)}';
        }
      }
      return 'Masukkan harga kelas tiket';
    }

    prices.sort();

    if (prices.first == prices.last) {
      return 'Mulai dari ${_formatRupiah(prices.first)}';
    }

    return 'Mulai dari ${_formatRupiah(prices.first)} - '
        '${_formatRupiah(prices.last)}';
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
            Icon(Icons.image_outlined, color: AppColors.gold, size: 42),
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
                  label: Text(hasPoster ? 'Ganti Poster' : 'Pilih dari Galeri'),
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
        _TicketClassInput(name: name, price: price, stock: stock),
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

      if (_selectedEndDate == null || _selectedEndDate!.isBefore(picked)) {
        _selectedEndDate = picked;
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 19, minute: 0),
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
      initialTime: _selectedEndTime ?? const TimeOfDay(hour: 21, minute: 0),
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
    final username = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');

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
      return ticket.nameController.text.trim().toLowerCase() == normalized;
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

    final chosenDateTime = _combineDateAndTime(_selectedDate!, _selectedTime!);

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

        final ticketPrice = num.tryParse(ticket.priceController.text.trim());

        final ticketStock = int.tryParse(ticket.stockController.text.trim());

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

    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

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

      final instagramUsername = _instagramController.text.trim().replaceFirst(
        RegExp(r'^@'),
        '',
      );

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'image_url': imageUrl,
        'instagram_username': instagramUsername.isEmpty
            ? null
            : instagramUsername,
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
            'price': num.parse(ticket.priceController.text.trim()),
            'available_tickets': int.parse(ticket.stockController.text.trim()),
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
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
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surfaceDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold),
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
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
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketClassFields(int index) {
    final ticket = _ticketClasses[index];
    final bool isEditing = _isEditing;

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
                if (!isEditing)
                  IconButton(
                    tooltip: 'Hapus kelas tiket',
                    onPressed: _saving ? null : () => _removeTicketClass(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
            if (isEditing) const SizedBox(height: 8),
            TextFormField(
              controller: ticket.nameController,
              enabled: !_saving && !isEditing,
              readOnly: isEditing,
              textCapitalization: TextCapitalization.words,
              maxLength: isEditing ? null : 30,
              style: TextStyle(
                color: isEditing ? AppColors.textSecondary : AppColors.text,
              ),
              decoration: const InputDecoration(
                labelText: 'Nama tiket *',
                hintText: 'Standard, VIP, VVIP',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: isEditing
                  ? null
                  : (value) => _ticketNameValidator(value, index),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ticket.priceController,
              enabled: !_saving && !isEditing,
              readOnly: isEditing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: isEditing ? AppColors.textSecondary : AppColors.text,
              ),
              decoration: const InputDecoration(
                labelText: 'Harga tiket (Rp) *',
                hintText: '100000',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: isEditing ? null : _ticketPriceValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ticket.stockController,
              enabled: !_saving && !isEditing,
              readOnly: isEditing,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isEditing ? AppColors.textSecondary : AppColors.text,
              ),
              decoration: const InputDecoration(
                labelText: 'Stok tiket *',
                hintText: '100',
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(),
              ),
              validator: isEditing ? null : _ticketStockValidator,
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(dateLabel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : onPickTime,
                icon: const Icon(Icons.access_time),
                label: Text(timeLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          _isEditing ? 'Edit Event' : 'Tambah Event',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
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
                      validator: (value) => _requiredValidator(value, 'Lokasi'),
                    ),
                    _field(
                      label: 'Username Instagram (opsional)',
                      controller: _instagramController,
                      hint: '@username',
                      validator: _instagramValidator,
                    ),
                    _buildPosterPicker(),

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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isEditing
                            ? 'Informasi kelas tiket bersifat tetap setelah event dipublikasikan.'
                            : 'Catatan: Stok event dihitung dari total stok kelas tiket.',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingTickets)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_ticketClasses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Belum ada data kelas tiket terdaftar.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(
                        _ticketClasses.length,
                        _buildTicketClassFields,
                      ),
                    if (!_isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _addTicketClass(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Jenis Tiket'),
                        ),
                      ),

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
                      timeLabel:
                          _selectedEndTime?.format(context) ?? 'Pilih waktu',
                      onPickDate: _pickEndDate,
                      onPickTime: _pickEndTime,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Menyimpan...' : 'Simpan Event',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
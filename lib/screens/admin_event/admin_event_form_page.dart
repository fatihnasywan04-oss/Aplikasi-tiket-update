
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';

class AdminEventFormPage extends StatefulWidget {
  final Map<String, dynamic>? event;

  const AdminEventFormPage({
    super.key,
    this.event,
  });

  @override
  State<AdminEventFormPage> createState() =>
      _AdminEventFormPageState();
}

class _TicketClassInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController stockController;

  _TicketClassInput({
    String name = '',
    String price = '0',
    String stock = '100',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        stockController = TextEditingController(text: stock);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
  }
}

class _AdminEventFormPageState extends State<AdminEventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _instagramController;

  final List<_TicketClassInput> _ticketClasses = [];

  DateTime? _eventDate;
  bool _loading = false;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _removeExistingImage = false;

  bool get _isEdit => widget.event != null;

  String _readEventValue(List<String> keys) {
    final event = widget.event ?? {};

    for (final key in keys) {
      final value = event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  DateTime _nowWib() {
    final now = DateTime.now().toUtc().add(
          const Duration(hours: 7),
        );

    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

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

  String _formatWibDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-${day}T00:00:00+07:00';
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: _readEventValue(['name', 'title']),
    );

    _descriptionController = TextEditingController(
      text: _readEventValue(['description']),
    );

    _locationController = TextEditingController(
      text: _readEventValue(['location', 'venue']),
    );

    _instagramController = TextEditingController(
      text: _readEventValue(['instagram_username']),
    );

    _existingImageUrl = _readEventValue([
      'image_url',
      'poster_url',
      'banner_url',
    ]).trim();

    final dateValue = _readEventValue([
      'event_date',
      'start_date',
    ]);

    if (dateValue.isNotEmpty) {
      _eventDate = _parseWibDate(dateValue);
    }

    if (!_isEdit) {
      _ticketClasses.add(
        _TicketClassInput(
          name: 'Regular',
          price: '100000',
          stock: '100',
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _instagramController.dispose();

    for (final ticket in _ticketClasses) {
      ticket.dispose();
    }

    super.dispose();
  }

  String? _resolveImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value.trim());

    if (uri == null) return null;

    if (uri.hasScheme) {
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      return uri.toString();
    }

    return Uri.parse(ApiService.baseUrl).resolve(value).toString();
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

  Future<void> _pickImage() async {
    if (_loading) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile == null || !mounted) return;

      final imageFile = File(pickedFile.path);

      if (!await imageFile.exists()) {
        throw Exception('File gambar tidak ditemukan.');
      }

      final fileSize = await imageFile.length();

      if (fileSize > 15 * 1024 * 1024) {
        _message('Ukuran banner maksimal 15 MB.');
        return;
      }

      setState(() {
        _selectedImage = imageFile;
        _removeExistingImage = false;
      });
    } catch (e) {
      _message('Gagal memilih gambar: $e');
    }
  }

  void _removeSelectedImage() {
    if (_loading) return;

    setState(() {
      _selectedImage = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _pickDate() async {
    final now = _nowWib();
    final today = DateTime(now.year, now.month, now.day);

    final currentDate = _eventDate ?? today;

    final firstDate = _isEdit
        ? DateTime(2000, 1, 1)
        : today;

    final initialDate = currentDate.isBefore(firstDate)
        ? firstDate
        : currentDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _eventDate = selected;
      });
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool required = true,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_loading,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: AppTheme.surface,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required &&
              (value == null || value.trim().isEmpty)) {
            return '$label wajib diisi';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildBannerPicker() {
    final existingUrl = _removeExistingImage
        ? null
        : _resolveImageUrl(_existingImageUrl);

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.image_outlined,
                color: Colors.white70,
              ),
              SizedBox(width: 10),
              Text(
                'Banner Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : existingUrl != null
                      ? Image.network(
                          existingUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (
                            context,
                            child,
                            loadingProgress,
                          ) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _emptyBanner();
                          },
                        )
                      : _emptyBanner(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _selectedImage != null || existingUrl != null
                        ? 'Ganti Banner'
                        : 'Pilih Banner',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              if (_selectedImage != null || existingUrl != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _removeSelectedImage,
                  tooltip: 'Hapus banner',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Pilih gambar dari galeri. Disarankan menggunakan '
            'gambar horizontal dengan rasio 16:9. '
            'Maksimal ukuran file 15 MB.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.background,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white38,
            size: 42,
          ),
          SizedBox(height: 8),
          Text(
            'Belum ada banner event',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PENGELOLAAN KELAS TIKET
  // ==========================================================

  void _addTicketClass() {
    if (_loading) return;

    setState(() {
      _ticketClasses.add(
        _TicketClassInput(
          name: '',
          price: '0',
          stock: '100',
        ),
      );
    });
  }

  void _removeTicketClass(int index) {
    if (_loading) return;

    if (_ticketClasses.length <= 1) {
      _message('Minimal harus ada satu kelas tiket.');
      return;
    }

    setState(() {
      final removed = _ticketClasses.removeAt(index);
      removed.dispose();
    });
  }

  String? _validateTicketName(
    String? value,
    int currentIndex,
  ) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Nama kelas tiket wajib diisi.';
    }

    if (name.length > 30) {
      return 'Nama kelas maksimal 30 karakter.';
    }

    final duplicate = _ticketClasses.asMap().entries.any((entry) {
      if (entry.key == currentIndex) return false;

      return entry.value.nameController.text
              .trim()
              .toLowerCase() ==
          name.toLowerCase();
    });

    if (duplicate) {
      return 'Nama kelas tiket tidak boleh sama.';
    }

    return null;
  }

  String? _validateTicketPrice(String? value) {
    final raw = value?.trim() ?? '';

    if (raw.isEmpty) {
      return 'Harga tiket wajib diisi.';
    }

    final price = num.tryParse(raw);

    if (price == null || !price.isFinite || price < 0) {
      return 'Masukkan harga tiket yang valid.';
    }

    return null;
  }

  String? _validateTicketStock(String? value) {
    final raw = value?.trim() ?? '';

    if (raw.isEmpty) {
      return 'Jumlah tiket wajib diisi.';
    }

    final stock = int.tryParse(raw);

    if (stock == null || stock < 0) {
      return 'Jumlah tiket harus berupa bilangan bulat >= 0.';
    }

    return null;
  }

  Widget _buildTicketClassCard(int index) {
    final ticket = _ticketClasses[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kelas Tiket ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_ticketClasses.length > 1)
                IconButton(
                  tooltip: 'Hapus kelas tiket',
                  onPressed: _loading
                      ? null
                      : () => _removeTicketClass(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ticket.nameController,
            enabled: !_loading,
            maxLength: 30,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nama Kelas Tiket',
              hintText: 'Contoh: VIP, Regular, Early Bird',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white38),
              counterStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                _validateTicketName(value, index),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: ticket.priceController,
            enabled: !_loading,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Harga Tiket',
              hintText: 'Contoh: 150000',
              prefixText: 'Rp ',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
            validator: _validateTicketPrice,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: ticket.stockController,
            enabled: !_loading,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Jumlah Stok Tiket',
              hintText: 'Contoh: 100',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
            validator: _validateTicketStock,
          ),
        ],
      ),
    );
  }

  Widget _buildTicketClasses() {
    return Container(
      margin: const EdgeInsets.only(top: 18, bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kelas Tiket Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${_ticketClasses.length} kelas',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tambahkan satu atau beberapa kelas tiket. '
            'Setiap kelas memiliki harga dan stok masing-masing.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            _ticketClasses.length,
            (index) => _buildTicketClassCard(index),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _addTicketClass,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kelas Tiket'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PENYIMPANAN EVENT
  // ==========================================================

  Future<void> _save() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_eventDate == null) {
      _message('Pilih tanggal event terlebih dahulu.');
      return;
    }

    if (!_isEdit) {
      if (_ticketClasses.isEmpty) {
        _message('Tambahkan minimal satu kelas tiket.');
        return;
      }

      for (var i = 0; i < _ticketClasses.length; i++) {
        final ticket = _ticketClasses[i];

        final name = ticket.nameController.text.trim();
        final price = num.tryParse(
          ticket.priceController.text.trim(),
        );
        final stock = int.tryParse(
          ticket.stockController.text.trim(),
        );

        if (name.isEmpty || name.length > 30) {
          _message('Periksa kembali nama kelas tiket.');
          return;
        }

        if (price == null || !price.isFinite || price < 0) {
          _message('Harga kelas tiket tidak valid.');
          return;
        }

        if (stock == null || stock < 0) {
          _message('Stok kelas tiket tidak valid.');
          return;
        }

        final duplicate = _ticketClasses.asMap().entries.any(
          (entry) {
            if (entry.key == i) return false;

            return entry.value.nameController.text
                    .trim()
                    .toLowerCase() ==
                name.toLowerCase();
          },
        );

        if (duplicate) {
          _message('Nama kelas tiket tidak boleh sama.');
          return;
        }
      }
    }

    setState(() {
      _loading = true;
    });

    try {
      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sedang mengunggah banner event...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        imageUrl = await ApiService.uploadEventImage(
          _selectedImage!,
        );
      } else if (_removeExistingImage) {
        imageUrl = null;
      }

      final eventDate = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
      );

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'event_date': _formatWibDate(eventDate),
        'instagram_username': _instagramController.text.trim(),
        'image_url': imageUrl,
      };

      if (_isEdit) {
        final eventId = int.tryParse(
          _readEventValue(['id', 'event_id']),
        );

        if (eventId == null) {
          throw Exception('ID event tidak valid.');
        }

        await ApiService.updateEvent(eventId, data);
      } else {
        final ticketClassPayload = _ticketClasses.map((ticket) {
          return <String, dynamic>{
            'name': ticket.nameController.text.trim(),
            'price': ticket.priceController.text.trim(),
            'available_tickets': int.parse(
              ticket.stockController.text.trim(),
            ),
          };
        }).toList();

        final prices = _ticketClasses.map(
          (ticket) => num.parse(
            ticket.priceController.text.trim(),
          ),
        );

        final minimumPrice = prices.reduce(
          (a, b) => a < b ? a : b,
        );

        final totalStock = _ticketClasses.fold<int>(
          0,
          (total, ticket) {
            return total +
                int.parse(ticket.stockController.text.trim());
          },
        );

        data['price'] = minimumPrice.toString();
        data['available_tickets'] = totalStock;
        data['ticket_classes'] = ticketClassPayload;

        await ApiService.createEvent(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Permintaan perubahan event berhasil dikirim.'
                : 'Event dan ${_ticketClasses.length} kelas tiket '
                    'berhasil dibuat. Menunggu persetujuan Super Admin.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan event: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================================
  // TAMPILAN FORM
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AdminEventDrawerPage(),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Ajukan Perubahan Event' : 'Buat Event',
        ),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _isEdit
                    ? 'Perubahan event akan dikirim kepada Super Admin '
                        'dan baru diterapkan setelah disetujui.'
                    : 'Lengkapi informasi event dan tambahkan kelas tiket. '
                        'Event akan berstatus menunggu persetujuan Super Admin '
                        'sebelum ditampilkan kepada pengguna.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),

            _buildBannerPicker(),

            _field('Nama Event', _nameController),

            _field(
              'Deskripsi',
              _descriptionController,
              maxLines: 4,
            ),

            _field('Lokasi', _locationController),

            _field(
              'Username Instagram (opsional)',
              _instagramController,
              required: false,
            ),

            const SizedBox(height: 4),

            const Text(
              'Tanggal Event',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _loading ? null : _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _eventDate == null
                    ? 'Pilih Tanggal Event'
                    : '${_eventDate!.day.toString().padLeft(2, '0')}/'
                        '${_eventDate!.month.toString().padLeft(2, '0')}/'
                        '${_eventDate!.year}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
              ),
            ),

            if (!_isEdit) _buildTicketClasses(),

            if (_isEdit)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Perubahan kelas tiket dilakukan melalui menu '
                        'Kelas Tiket. Pengajuan perubahan akan menunggu '
                        'persetujuan Super Admin.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),

            ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? 'Kirim Permintaan Perubahan'
                          : 'Buat Event dan Kelas Tiket',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';

class AdminEventFormPage extends StatefulWidget {
  final Map<String, dynamic>? event;

  const AdminEventFormPage({
    super.key,
    this.event,
  });

  @override
  State<AdminEventFormPage> createState() => _AdminEventFormPageState();
}

class _AdminEventFormPageState extends State<AdminEventFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _instagramController;

  DateTime? _eventDate;
  bool _loading = false;

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

    final dateValue = _readEventValue([
      'event_date',
      'start_date',
    ]);

    if (dateValue.isNotEmpty) {
      _eventDate = DateTime.tryParse(dateValue);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final currentDate = _eventDate ?? today;

    final firstDate = currentDate.isBefore(today)
        ? currentDate
        : today;

    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate,
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
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

  Future<void> _save() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal event terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'event_date': DateTime(
          _eventDate!.year,
          _eventDate!.month,
          _eventDate!.day,
        ).toIso8601String(),
        'instagram_username': _instagramController.text.trim(),
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
        await ApiService.createEvent(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Permintaan perubahan event berhasil dikirim.'
                : 'Event berhasil dibuat dan menunggu persetujuan Super Admin.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan event: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Ajukan Perubahan Event' : 'Buat Event',
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
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
                  color: AppTheme.primary.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Text(
                _isEdit
                    ? 'Perubahan event akan dikirim kepada Super Admin '
                        'dan baru diterapkan setelah disetujui.'
                    : 'Event yang dibuat akan berstatus menunggu persetujuan '
                        'Super Admin sebelum ditampilkan kepada pengguna.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),

            _field(
              'Nama Event',
              _nameController,
            ),

            _field(
              'Deskripsi',
              _descriptionController,
              maxLines: 4,
            ),

            _field(
              'Lokasi',
              _locationController,
            ),

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

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Harga tiket dan jumlah stok dikelola melalui '
                      'menu Kelas Tiket setelah event dibuat. '
                      'Perubahan kelas tiket juga memerlukan persetujuan '
                      'Super Admin.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                          : 'Buat Event',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
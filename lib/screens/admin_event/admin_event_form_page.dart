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
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _instagramController;

  DateTime? _eventDate;
  bool _loading = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();

    final event = widget.event ?? {};

    _nameController = TextEditingController(
      text: event['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: event['description']?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: event['location']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: event['price']?.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: event['available_tickets']?.toString() ?? '',
    );
    _instagramController = TextEditingController(
      text: event['instagram_username']?.toString() ?? '',
    );

    if (event['event_date'] != null) {
      _eventDate = DateTime.tryParse(event['event_date'].toString());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _eventDate = selected);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: AppTheme.surface,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return '$label wajib diisi';
          }

          if (keyboardType == TextInputType.number &&
              value != null &&
              value.trim().isNotEmpty &&
              num.tryParse(value.trim()) == null) {
            return '$label harus berupa angka';
          }

          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal event terlebih dahulu.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'available_tickets': int.parse(_stockController.text.trim()),
        'event_date': _eventDate!.toIso8601String(),
        'instagram_username': _instagramController.text.trim(),
      };

      if (_isEdit) {
        final eventId = int.tryParse(widget.event!['id'].toString());

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
                : 'Event berhasil dibuat dan dikirim untuk persetujuan.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan event: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Ajukan Perubahan Event' : 'Buat Event'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Perubahan akan menunggu persetujuan Super Admin.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            _field('Nama Event', _nameController),
            _field(
              'Deskripsi',
              _descriptionController,
              maxLines: 4,
            ),
            _field('Lokasi', _locationController),
            _field(
              'Harga',
              _priceController,
              keyboardType: TextInputType.number,
            ),
            _field(
              'Jumlah Tiket',
              _stockController,
              keyboardType: TextInputType.number,
            ),
            _field(
              'Username Instagram (opsional)',
              _instagramController,
              required: false,
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _eventDate == null
                    ? 'Pilih Tanggal Event'
                    : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEdit ? 'Kirim Perubahan' : 'Buat Event'),
            ),
          ],
        ),
      ),
    );
  }
}
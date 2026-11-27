import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../../core/currency_formatter.dart';

class AdminEventsTicketClassesPage extends StatefulWidget {
  final int eventId;

  const AdminEventsTicketClassesPage({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventsTicketClassesPage> createState() =>
      _AdminEventsTicketClassesPageState();
}

class _AdminEventsTicketClassesPageState
    extends State<AdminEventsTicketClassesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _future = _loadClasses();
  }

  Future<List<Map<String, dynamic>>> _loadClasses() {
    return ApiService.getTicketClasses(widget.eventId);
  }

  Future<void> _refresh() async {
    final future = _loadClasses();

    setState(() {
      _future = future;
    });

    await future;
  }

  String _readValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  num? _parseRupiah(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll('rp', '')
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();

    if (cleaned.isEmpty) return null;

    return num.tryParse(cleaned);
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _showClassForm({
    Map<String, dynamic>? ticketClass,
  }) async {
    if (_processing) return;

    final isEdit = ticketClass != null;

    // Delegate controller lifecycle to the dedicated StatefulWidget dialog.
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _TicketClassFormDialog(
        ticketClass: ticketClass,
        parseRupiah: _parseRupiah,
      ),
    );

    if (result == null) return;

    final name = result['name'] as String;
    final price = result['price'] as num;
    final stock = result['stock'] as int;

    if (!mounted) return;

    setState(() {
      _processing = true;
    });

    try {
      if (!isEdit) {
        await ApiService.createTicketClass(
          eventId: widget.eventId,
          name: name,
          price: price,
          availableTickets: stock,
        );
      } else {
        final classId = int.tryParse(
          ticketClass['id']?.toString() ?? '',
        );

        if (classId == null) {
          throw Exception('ID kelas tiket tidak valid.');
        }

        await ApiService.updateTicketClass(
          eventId: widget.eventId,
          ticketClassId: classId,
          name: name,
          price: price,
          availableTickets: stock,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Kelas tiket berhasil diperbarui.'
                : 'Kelas tiket berhasil ditambahkan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan kelas tiket: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deleteClass(
    Map<String, dynamic> ticketClass,
  ) async {
    if (_processing) return;

    final classId = int.tryParse(
      ticketClass['id']?.toString() ?? '',
    );

    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID kelas tiket tidak valid.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final className = _readValue(
      ticketClass,
      ['name'],
      fallback: 'Tanpa nama',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        title: const Text(
          'Hapus Kelas Tiket?',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          'Kelas tiket "$className" akan dihapus secara permanen.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processing = true;
    });

    try {
      await ApiService.deleteTicketClass(
        eventId: widget.eventId,
        ticketClassId: classId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kelas tiket berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus kelas tiket: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  // ============================================================
  // LIST WIDGETS
  // ============================================================

  Widget _buildClassCard(Map<String, dynamic> ticketClass) {
    final name = _readValue(
      ticketClass,
      ['name'],
      fallback: 'Tanpa nama',
    );

    final price = formatRupiah(
      num.tryParse(ticketClass['price']?.toString() ?? ''),
    );

    final stock = _readValue(
      ticketClass,
      ['available_tickets', 'stock'],
    );

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Harga: $price\n'
            'Tiket tersedia: $stock',
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !_processing,
          iconColor: AppColors.textMuted,
          onSelected: (value) {
            if (value == 'edit') {
              _showClassForm(ticketClass: ticketClass);
            } else if (value == 'delete') {
              _deleteClass(ticketClass);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Edit Kelas Tiket'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Hapus Kelas Tiket',
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 150),
        Center(
          child: Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.textMuted,
            size: 55,
          ),
        ),
        SizedBox(height: 14),
        Center(
          child: Text(
            'Belum ada kelas tiket.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.error_outline,
          color: AppColors.error,
          size: 45,
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Gagal memuat kelas tiket:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelas Tiket'),
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
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _processing ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _processing ? null : () => _showClassForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kelas Tiket'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return _buildError(snapshot.error!);
                }

                final classes = snapshot.data ?? [];

                if (classes.isEmpty) {
                  return _buildEmpty();
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    return _buildClassCard(classes[index]);
                  },
                );
              },
            ),
          ),
          if (_processing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// FORM DIALOG — dedicated StatefulWidget so TextEditingControllers
// are disposed safely when the dialog route is popped. Avoids
// "A TextEditingController was used after being disposed" assertions.
// ============================================================

class _TicketClassFormDialog extends StatefulWidget {
  final Map<String, dynamic>? ticketClass;
  final num? Function(String) parseRupiah;

  const _TicketClassFormDialog({
    this.ticketClass,
    required this.parseRupiah,
  });

  @override
  State<_TicketClassFormDialog> createState() => _TicketClassFormDialogState();
}

class _TicketClassFormDialogState extends State<_TicketClassFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  bool get _isEdit => widget.ticketClass != null;

  String _classValue(List<String> keys) {
    final data = widget.ticketClass;
    if (data == null) return '';
    for (final key in keys) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: _classValue(['name']),
    );

    _priceController = TextEditingController(
      text: widget.ticketClass == null
          ? ''
          : formatRupiah(
              num.tryParse(
                widget.ticketClass!['price']?.toString() ?? '',
              ),
            ),
    );

    _stockController = TextEditingController(
      text: _classValue(['available_tickets', 'stock']),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
    bool integerOnly = false,
    bool currency = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: !integerOnly)
          : TextInputType.text,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label wajib diisi.';
        }

        if (number) {
          final parsed = currency
              ? widget.parseRupiah(value)
              : num.tryParse(value.trim());

          if (parsed == null) return '$label harus berupa angka.';
          if (!parsed.isFinite) return '$label tidak valid.';
          if (parsed < 0) return '$label tidak boleh negatif.';
          if (integerOnly && parsed % 1 != 0) {
            return '$label harus berupa bilangan bulat.';
          }
        }

        return null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'price': widget.parseRupiah(_priceController.text)!,
      'stock': int.parse(_stockController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      title: Text(
        _isEdit ? 'Edit Kelas Tiket' : 'Tambah Kelas Tiket',
        style: const TextStyle(color: AppColors.text),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Nama Kelas', _nameController),
              const SizedBox(height: 12),
              _field(
                'Harga',
                _priceController,
                number: true,
                currency: true,
              ),
              const SizedBox(height: 12),
              _field(
                'Jumlah Tiket',
                _stockController,
                number: true,
                integerOnly: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

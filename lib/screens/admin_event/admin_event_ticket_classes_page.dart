
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';

class AdminEventTicketClassesPage extends StatefulWidget {
  final int eventId;

  const AdminEventTicketClassesPage({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventTicketClassesPage> createState() =>
      _AdminEventTicketClassesPageState();
}

class _AdminEventTicketClassesPageState
    extends State<AdminEventTicketClassesPage> {
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

  String _formatPrice(dynamic value) {
    final price = num.tryParse(value?.toString() ?? '');

    if (price == null) return '0';

    return price.toStringAsFixed(
      price % 1 == 0 ? 0 : 2,
    );
  }

  Future<void> _showClassForm({
    Map<String, dynamic>? ticketClass,
  }) async {
    if (_processing) return;

    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: ticketClass?['name']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: ticketClass?['price']?.toString() ?? '',
    );

    final stockController = TextEditingController(
      text: _readValue(
        ticketClass ?? {},
        ['available_tickets', 'stock'],
        fallback: '',
      ),
    );

    final isEdit = ticketClass != null;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            isEdit
                ? 'Ajukan Perubahan Kelas'
                : 'Ajukan Kelas Tiket Baru',
            style: const TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdit)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Perubahan akan menunggu persetujuan Super Admin.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _dialogField(
                    'Nama Kelas',
                    nameController,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    'Harga',
                    priceController,
                    number: true,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    'Jumlah Tiket',
                    stockController,
                    number: true,
                    integerOnly: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Kirim Permintaan'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final name = nameController.text.trim();
      final price = num.parse(priceController.text.trim());
      final stock = int.parse(stockController.text.trim());

      setState(() {
        _processing = true;
      });

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
                ? 'Permintaan perubahan kelas tiket berhasil dikirim.'
                : 'Permintaan penambahan kelas tiket berhasil dikirim.',
          ),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim permintaan: $e'),
        ),
      );
    } finally {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();

      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Widget _dialogField(
    String label,
    TextEditingController controller, {
    bool number = false,
    bool integerOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number
          ? TextInputType.numberWithOptions(
              decimal: !integerOnly,
            )
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label wajib diisi.';
        }

        if (number) {
          final parsed = num.tryParse(value.trim());

          if (parsed == null) {
            return '$label harus berupa angka.';
          }

          if (!parsed.isFinite) {
            return '$label tidak valid.';
          }

          if (parsed < 0) {
            return '$label tidak boleh negatif.';
          }

          if (integerOnly && parsed % 1 != 0) {
            return '$label harus berupa bilangan bulat.';
          }
        }

        return null;
      },
    );
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
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Ajukan Penghapusan Kelas?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Apakah Anda ingin mengajukan penghapusan kelas '
          '"$className"?\n\n'
          'Permintaan akan ditinjau oleh Super Admin. '
          'Kelas tidak langsung dihapus.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
          content: Text(
            'Permintaan penghapusan kelas tiket berhasil dikirim.',
          ),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengajukan penghapusan: $e'),
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

  Widget _buildClassCard(Map<String, dynamic> ticketClass) {
    final name = _readValue(
      ticketClass,
      ['name'],
      fallback: 'Tanpa nama',
    );

    final price = _formatPrice(ticketClass['price']);

    final stock = _readValue(
      ticketClass,
      ['available_tickets', 'stock'],
    );

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Harga: Rp $price\n'
            'Tiket tersedia: $stock',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !_processing,
          iconColor: Colors.white70,
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
                  Text('Ajukan Perubahan'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text('Ajukan Penghapusan'),
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
            color: Colors.white38,
            size: 55,
          ),
        ),
        SizedBox(height: 14),
        Center(
          child: Text(
            'Belum ada kelas tiket.',
            style: TextStyle(color: Colors.white70),
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
          color: Colors.redAccent,
          size: 45,
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Gagal memuat kelas tiket:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kelas Tiket'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
        actions: [
          IconButton(
            onPressed: _processing ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: _processing ? null : () => _showClassForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kelas'),
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

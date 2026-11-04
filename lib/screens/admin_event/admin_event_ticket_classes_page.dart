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

  @override
  void initState() {
    super.initState();
    _future = _loadClasses();
  }

  Future<List<Map<String, dynamic>>> _loadClasses() {
    return ApiService.getTicketClasses(widget.eventId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadClasses());
    await _future;
  }

  Future<void> _showClassForm({
    Map<String, dynamic>? ticketClass,
  }) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: ticketClass?['name']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: ticketClass?['price']?.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: ticketClass?['available_tickets']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          ticketClass == null ? 'Tambah Kelas Tiket' : 'Edit Kelas Tiket',
          style: const TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Nama Kelas', nameController),
                const SizedBox(height: 12),
                _dialogField('Harga', priceController, number: true),
                const SizedBox(height: 12),
                _dialogField('Jumlah Tiket', stockController, number: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();
      return;
    }

    try {
      final price = num.parse(priceController.text.trim());
      final stock = int.parse(stockController.text.trim());

      if (ticketClass == null) {
        await ApiService.createTicketClass(
          eventId: widget.eventId,
          name: nameController.text.trim(),
          price: price,
          availableTickets: stock,
        );
      } else {
        final classId = int.tryParse(ticketClass['id'].toString());

        if (classId == null) {
          throw Exception('ID kelas tiket tidak valid.');
        }

        await ApiService.updateTicketClass(
          eventId: widget.eventId,
          ticketClassId: classId,
          name: nameController.text.trim(),
          price: price,
          availableTickets: stock,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan kelas tiket berhasil dikirim.'),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan kelas tiket: $e')),
      );
    } finally {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();
    }
  }

  Widget _dialogField(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
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

        final parsed = number ? num.tryParse(value.trim()) : null;

        if (number && parsed == null) {
          return '$label harus berupa angka.';
        }

        if (number && parsed! < 0) {
          return '$label tidak boleh negatif.';
        }

        if (label == 'Jumlah Tiket' &&
            parsed != null &&
            parsed % 1 != 0) {
          return 'Jumlah tiket harus bilangan bulat.';
        }

        return null;
      },
    );
  }

  Future<void> _deleteClass(Map<String, dynamic> ticketClass) async {
    final classId = int.tryParse(ticketClass['id'].toString());

    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID kelas tiket tidak valid.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan Penghapusan'),
        content: Text(
          'Ajukan penghapusan kelas "${ticketClass['name'] ?? '-'}"? '
          'Permintaan ini akan diproses oleh Super Admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Ajukan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteTicketClass(
        eventId: widget.eventId,
        ticketClassId: classId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan penghapusan kelas tiket dikirim.'),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus kelas tiket: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kelas Tiket'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showClassForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kelas'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Gagal memuat kelas tiket:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            final classes = snapshot.data ?? [];

            if (classes.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 150),
                  Center(
                    child: Text(
                      'Belum ada kelas tiket.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final ticketClass = classes[index];

                return Card(
                  color: AppTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      ticketClass['name']?.toString() ?? 'Tanpa nama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Harga: Rp ${ticketClass['price'] ?? 0}\n'
                      'Tiket tersedia: '
                      '${ticketClass['available_tickets'] ?? '-'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
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
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Ajukan Hapus'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
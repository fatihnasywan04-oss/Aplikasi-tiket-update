import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_drawer.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  static const Color primary = Color(0xFF5B50E8);

  List<Map<String, dynamic>> events = [];
  bool loading = true;
  String? errorMessage;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadEvents() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  int stockOf(Map<String, dynamic> event) {
    return int.tryParse('${event['available_tickets'] ?? 0}') ?? 0;
  }

  String money(dynamic value) {
    final amount = (num.tryParse('$value') ?? 0).round();
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp $formatted';
  }

  String formatDate(dynamic value) {
    if (value == null || '$value'.isEmpty) {
      return 'Tanggal belum tersedia';
    }

    try {
      final date = DateTime.parse('$value').toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/${date.year} $hour:$minute';
    } catch (_) {
      return '$value';
    }
  }

  List<Map<String, dynamic>> get filteredEvents {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) return events;

    return events.where((event) {
      final title = '${event['title'] ?? ''}'.toLowerCase();
      final location = '${event['location'] ?? ''}'.toLowerCase();
      return title.contains(query) || location.contains(query);
    }).toList();
  }

  Future<void> openEventForm({Map<String, dynamic>? event}) async {
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(
      text: event?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: event?['description']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: event?['location']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: event?['price']?.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: event?['available_tickets']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: event?['image_url']?.toString() ?? '',
    );

    var selectedDate =
        DateTime.tryParse(event?['event_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 1));

    var saving = false;
    String? formError;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickDate() async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final initialDate = selectedDate.isBefore(today)
                    ? today
                    : selectedDate;

                final date = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: today,
                  lastDate: DateTime(2100),
                );

                if (date == null || !context.mounted) return;

                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(selectedDate),
                );

                if (time == null || !context.mounted) return;

                setDialogState(() {
                  selectedDate = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              }

              Future<void> saveEvent() async {
                if (saving) return;

                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                setDialogState(() {
                  saving = true;
                  formError = null;
                });

                final payload = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'location': locationController.text.trim(),
                  'event_date': selectedDate.toIso8601String(),
                  'price': num.parse(priceController.text.trim()),
                  'available_tickets': int.parse(stockController.text.trim()),
                  'image_url': imageController.text.trim().isEmpty
                      ? null
                      : imageController.text.trim(),
                };

                try {
                  if (event == null) {
                    await ApiService.createEvent(payload);
                  } else {
                    final id = int.tryParse('${event['id']}');

                    if (id == null) {
                      throw Exception('ID event tidak valid.');
                    }

                    await ApiService.updateEvent(id, payload);
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!context.mounted) return;

                  setDialogState(() {
                    formError = e.toString().replaceFirst('Exception: ', '');
                    saving = false;
                  });
                }
              }

              return AlertDialog(
                title: Text(event == null ? 'Tambah Event' : 'Edit Event'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Nama event',
                              prefixIcon: Icon(Icons.event),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length < 3) {
                                return 'Nama event minimal 3 karakter.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Deskripsi wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: locationController,
                            decoration: const InputDecoration(
                              labelText: 'Lokasi',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Lokasi wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.calendar_month,
                              color: primary,
                            ),
                            title: const Text('Tanggal dan waktu event'),
                            subtitle: Text(formatDate(selectedDate)),
                            trailing: IconButton(
                              onPressed: saving ? null : pickDate,
                              icon: const Icon(Icons.edit_calendar),
                            ),
                            onTap: saving ? null : pickDate,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Harga tiket (Rp)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            validator: (value) {
                              final price = num.tryParse(value?.trim() ?? '');

                              if (price == null || price < 0) {
                                return 'Masukkan harga yang valid.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah stok tiket',
                              prefixIcon: Icon(Icons.confirmation_number),
                            ),
                            validator: (value) {
                              final stock = int.tryParse(value?.trim() ?? '');

                              if (stock == null || stock < 0) {
                                return 'Stok harus bilangan bulat ≥ 0.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: imageController,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'URL gambar (opsional)',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;

                              final uri = Uri.tryParse(text);

                              if (uri == null ||
                                  !uri.hasAuthority ||
                                  (uri.scheme != 'http' &&
                                      uri.scheme != 'https')) {
                                return 'Masukkan URL HTTP/HTTPS yang valid.';
                              }

                              return null;
                            },
                          ),
                          if (formError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              formError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    onPressed: saving ? null : saveEvent,
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        await loadEvents();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null
                  ? 'Event berhasil ditambahkan.'
                  : 'Event berhasil diperbarui.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      priceController.dispose();
      stockController.dispose();
      imageController.dispose();
    }
  }

  Future<void> deleteEvent(Map<String, dynamic> event) async {
    final id = int.tryParse('${event['id']}');

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID event tidak valid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Event?'),
        content: Text(
          'Apakah kamu yakin ingin menghapus '
          '"${event['title'] ?? 'event ini'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

      await loadEvents();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event berhasil dihapus.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget eventCard(Map<String, dynamic> event) {
    final imageUrl = event['image_url']?.toString() ?? '';
    final stock = stockOf(event);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    width: 82,
                    height: 82,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: Color(0xFFEEECFF),
                                child: Icon(
                                  Icons.event,
                                  color: primary,
                                  size: 32,
                                ),
                              );
                            },
                          )
                        : const ColoredBox(
                            color: Color(0xFFEEECFF),
                            child: Icon(Icons.event, color: primary, size: 32),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['title'] ?? 'Tanpa judul'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${event['location'] ?? 'Lokasi belum tersedia'}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(event['event_date']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money(event['price']),
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stock > 0 ? 'Stok: $stock tiket' : 'Tiket habis',
                        style: TextStyle(
                          color: stock > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
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
                    onPressed: () => openEventForm(event: event),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(foregroundColor: primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => deleteEvent(event),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
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
    final data = filteredEvents;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Manajemen Event'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: loading ? null : loadEvents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentPage: 'Event'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEventForm(),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Event'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadEvents,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadEvents,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() => search = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama event atau lokasi...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${data.length} event ditemukan',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (data.isEmpty)
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_busy_outlined,
                              size: 48,
                              color: Colors.black38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              search.isEmpty
                                  ? 'Belum ada event.'
                                  : 'Event tidak ditemukan.',
                            ),
                            if (search.isEmpty) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => openEventForm(),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Event'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    ...data.map(eventCard),
                ],
              ),
            ),
    );
  }
}


import 'package:flutter/material.dart';

import 'booking_page.dart';
import '../../api_service.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  static const Color primary = Color(0xFF5B50E8);
  static const Color background = Color(0xFFF7F7FC);
  static const Color dark = Color(0xFF282738);
  static const Color muted = Color(0xFF77778A);

  bool _loadingClasses = true;
  String? _classError;

  List<Map<String, dynamic>> _ticketClasses = [];
  int? _selectedTicketClassId;

  Map<String, dynamic> get event => widget.event;

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? get _eventId => _readInt(
        event['id'] ?? event['event_id'],
      );

  String _value(
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

  num _number(dynamic value) {
    if (value is num) return value;

    final cleaned = value
        ?.toString()
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return num.tryParse(cleaned ?? '') ?? 0;
  }

  String _formatPrice(dynamic value) {
    final digits = _number(value).round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return 'Rp $buffer';
  }

  String _normalizeClassName(dynamic value) {
    final name = (value ?? '').toString().trim().toLowerCase();

    if (name == 'vvip') return 'VVIP';
    if (name == 'vip') return 'VIP';
    if (name == 'standard') return 'Standard';

    return (value ?? 'Tiket').toString();
  }

  Future<void> _loadTicketClasses() async {
    final id = _eventId;

    if (id == null || id <= 0) {
      setState(() {
        _loadingClasses = false;
        _classError = 'ID event tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _loadingClasses = true;
      _classError = null;
    });

    try {
      final result = await ApiService.getTicketClasses(id);

      if (!mounted) return;

      // Tampilkan kelas tiket yang dikenal terlebih dahulu.
      const priority = {
        'VVIP': 0,
        'VIP': 1,
        'Standard': 2,
      };

      result.sort((a, b) {
        final aName = _normalizeClassName(a['name']);
        final bName = _normalizeClassName(b['name']);

        return (priority[aName] ?? 99)
            .compareTo(priority[bName] ?? 99);
      });

      final availableClasses = result.where((ticket) {
        return _readInt(ticket['id']) != null;
      }).toList();

      int? selectedId;

      // Pertahankan pilihan lama jika stoknya masih tersedia.
      for (final ticket in availableClasses) {
        final id = _readInt(ticket['id']);
        final stock = _readInt(ticket['available_tickets']) ?? 0;

        if (id == _selectedTicketClassId && stock > 0) {
          selectedId = id;
          break;
        }
      }

      // Jika belum ada pilihan, pilih kelas pertama yang stoknya tersedia.
      if (selectedId == null) {
        for (final ticket in availableClasses) {
          final stock = _readInt(ticket['available_tickets']) ?? 0;

          if (stock > 0) {
            selectedId = _readInt(ticket['id']);
            break;
          }
        }
      }

      setState(() {
        _ticketClasses = availableClasses;
        _selectedTicketClassId = selectedId;
        _loadingClasses = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingClasses = false;
        _classError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic>? get _selectedTicketClass {
    for (final ticket in _ticketClasses) {
      if (_readInt(ticket['id']) == _selectedTicketClassId) {
        return ticket;
      }
    }

    return null;
  }

  void _openBooking() {
    final selected = _selectedTicketClass;
    final eventId = _eventId;

    if (eventId == null) {
      _showMessage('ID event tidak valid.');
      return;
    }

    if (selected == null) {
      _showMessage('Silakan pilih kelas tiket yang tersedia.');
      return;
    }

    final stock = _readInt(selected['available_tickets']) ?? 0;

    if (stock <= 0) {
      _showMessage('Stok tiket untuk kelas ini habis.');
      return;
    }

    // Teruskan kelas terpilih agar BookingPage dapat menggunakannya.
    final bookingEvent = <String, dynamic>{
      ...event,
      'id': eventId,
      'ticket_classes': _ticketClasses,
      'selected_ticket_class': selected,
      'ticket_class_id': _readInt(selected['id']),
      'ticket_class_name': _normalizeClassName(selected['name']),
      'ticket_price': selected['price'],
      'ticket_stock': stock,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingPage(event: bookingEvent),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTicketClasses();
  }

  @override
  Widget build(BuildContext context) {
    final title = _value(
      ['title', 'name', 'nama_event'],
      fallback: 'Event',
    );

    final image = _value(
      ['image_url', 'poster_url', 'image', 'gambar'],
      fallback: '',
    );

    final location = _value(
      ['location', 'venue', 'lokasi'],
      fallback: 'Lokasi belum tersedia',
    );

    final date = _value(
      ['date', 'event_date', 'tanggal'],
      fallback: 'Tanggal belum tersedia',
    );

    final description = _value(
      ['description', 'deskripsi'],
      fallback: 'Belum ada deskripsi event.',
    );

    final selected = _selectedTicketClass;
    final selectedPrice = selected?['price'] ?? 0;

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: image.isEmpty
                  ? Container(
                      color: const Color(0xFFEAE8FF),
                      child: const Center(
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 76,
                          color: primary,
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFEAE8FF),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 70,
                              color: primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 18),

                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi',
                  value: location,
                ),
                const SizedBox(height: 14),

                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Tanggal',
                  value: date,
                ),
                const SizedBox(height: 24),

                const Text(
                  'Tentang event',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  description,
                  style: const TextStyle(
                    height: 1.6,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Pilih kelas tiket',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 6),

                const Text(
                  'Pilih kelas sesuai anggaran dan ketersediaan stok.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 16),

                if (_loadingClasses)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(color: primary),
                    ),
                  )
                else if (_classError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 36,
                          color: muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _classError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadTicketClasses,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  )
                else if (_ticketClasses.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Belum ada kelas tiket untuk event ini. '
                      'Silakan hubungi admin event.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  )
                else
                  ..._ticketClasses.map((ticket) {
                    final ticketId = _readInt(ticket['id']);
                    final stock =
                        _readInt(ticket['available_tickets']) ?? 0;
                    final price = ticket['price'] ?? 0;
                    final name = _normalizeClassName(ticket['name']);
                    final isSelected =
                        ticketId == _selectedTicketClassId;
                    final isSoldOut = stock <= 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: isSoldOut
                            ? null
                            : () {
                                setState(() {
                                  _selectedTicketClassId = ticketId;
                                });
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSoldOut
                                ? const Color(0xFFF0F0F4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? primary
                                  : const Color(0xFFEAEAF3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEAE8FF)
                                      : const Color(0xFFF2F1FA),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  name == 'VVIP'
                                      ? Icons.workspace_premium
                                      : name == 'VIP'
                                          ? Icons.star_outline
                                          : Icons.confirmation_number_outlined,
                                  color: isSoldOut ? muted : primary,
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: dark,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      isSoldOut
                                          ? 'Stok habis'
                                          : 'Tersedia $stock tiket',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSoldOut
                                            ? Colors.red
                                            : muted,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _formatPrice(price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),
                              Icon(
                                isSoldOut
                                    ? Icons.block
                                    : isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                color: isSoldOut ? muted : primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFEAEAF3)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga tiket terpilih',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      selected == null
                          ? 'Belum dipilih'
                          : _formatPrice(selectedPrice),
                      style: const TextStyle(
                        color: primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (selected != null)
                      Text(
                        _normalizeClassName(selected['name']),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _loadingClasses ||
                        _classError != null ||
                        selected == null
                    ? null
                    : _openBooking,
                child: const Text(
                  'Pesan Tiket',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAE8FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF5B50E8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF77778A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF282738),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

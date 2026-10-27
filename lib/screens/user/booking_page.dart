import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'payment_page.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const BookingPage({
    super.key,
    required this.event,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _quantity = 1;
  bool _loading = false;
  bool _loadingClasses = true;

  List<Map<String, dynamic>> _ticketClasses = [];
  int? _selectedClassId;
  String? _classError;

  static const Color _primary = Color(0xFF5B50E8);
  static const Color _palePurple = Color(0xFFEAE8FF);
  static const Color _textColor = Color(0xFF282738);
  static const Color _secondaryText = Color(0xFF77778A);
  static const Color _background = Color(0xFFF7F7FC);
  static const Color _border = Color(0xFFEAEAF3);

  @override
  void initState() {
    super.initState();
    _loadTicketClasses();
  }

  // ============================================================
  // DATA HELPERS
  // ============================================================

  String _value(
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = widget.event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return fallback;
  }

  int? _parseId(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      if (!value.isFinite || value <= 0) return null;
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '');
  }

  int? get _eventId {
    final id = _parseId(
      widget.event['id'] ?? widget.event['event_id'],
    );

    if (id == null || id <= 0) return null;

    return id;
  }

  String get _eventTitle => _value(
        ['title', 'name', 'nama_event'],
        fallback: 'Event',
      );

  String get _eventLocation => _value(
        ['location', 'venue', 'lokasi'],
        fallback: 'Lokasi belum tersedia',
      );

  int _toInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value is int) return value;

    if (value is num) {
      if (!value.isFinite) return fallback;
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ??
        fallback;
  }

  num _toNum(
    dynamic value, {
    num fallback = 0,
  }) {
    if (value is num) {
      if (!value.isFinite) return fallback;
      return value;
    }

    if (value == null) return fallback;

    var raw = value.toString().trim();

    // Mendukung harga berupa angka atau string rupiah.
    raw = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');

    if (raw.isEmpty) return fallback;

    // Harga dari API sebaiknya berupa angka.
    // Untuk format string Indonesia seperti 150.000,00,
    // titik pemisah ribuan dihapus dan koma menjadi desimal.
    if (raw.contains(',') && raw.contains('.')) {
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }

    return num.tryParse(raw) ?? fallback;
  }

  Map<String, dynamic>? get _selectedClass {
    for (final ticketClass in _ticketClasses) {
      if (_toInt(ticketClass['id']) == _selectedClassId) {
        return ticketClass;
      }
    }

    return null;
  }

  num get _price {
    final ticketClass = _selectedClass;
    if (ticketClass == null) return 0;

    return _toNum(ticketClass['price']);
  }

  int get _stock {
    final ticketClass = _selectedClass;
    if (ticketClass == null) return 0;

    return _toInt(ticketClass['available_tickets']);
  }

  num get _total => _price * _quantity;

  String _formatRupiah(num amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return 'Rp $buffer';
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }

  // ============================================================
  // LOAD TICKET CLASSES
  // ============================================================

  Future<void> _loadTicketClasses() async {
    if (_loadingClasses) {
      // Tetap izinkan pemuatan awal dan refresh.
    }

    final eventId = _eventId;

    if (eventId == null) {
      if (!mounted) return;

      setState(() {
        _loadingClasses = false;
        _classError = 'ID event tidak valid.';
        _ticketClasses = [];
        _selectedClassId = null;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingClasses = true;
      _classError = null;
    });

    try {
      final response = await ApiService.getTicketClasses(eventId);

      if (!mounted) return;

      // Salin list sebelum diurutkan agar tidak mengubah list
      // milik pemanggil atau data yang digunakan di tempat lain.
      final classes = response
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => _toInt(item['id']) > 0)
          .toList();

      // Prioritaskan VVIP, VIP, lalu Standard.
      const priority = {
        'VVIP': 0,
        'VIP': 1,
        'STANDARD': 2,
      };

      classes.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().toUpperCase();
        final nameB = (b['name'] ?? '').toString().toUpperCase();

        final orderA = priority[nameA] ?? 99;
        final orderB = priority[nameB] ?? 99;

        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }

        return _toNum(a['price']).compareTo(
          _toNum(b['price']),
        );
      });

      setState(() {
        _ticketClasses = classes;
        _loadingClasses = false;
        _classError = null;

        final selectedStillExists = _selectedClassId != null &&
            classes.any(
              (item) => _toInt(item['id']) == _selectedClassId,
            );

        if (!selectedStillExists) {
          final available = classes.where(
            (item) => _toInt(item['available_tickets']) > 0,
          );

          if (available.isNotEmpty) {
            _selectedClassId = _toInt(available.first['id']);
          } else if (classes.isNotEmpty) {
            _selectedClassId = _toInt(classes.first['id']);
          } else {
            _selectedClassId = null;
          }
        }

        // Jika kelas yang dipilih sudah habis, pilih kelas lain
        // yang tersedia jika ada.
        if (_selectedClassId != null) {
          final currentClass = classes.cast<Map<String, dynamic>?>().firstWhere(
                (item) =>
                    _toInt(item?['id']) == _selectedClassId,
                orElse: () => null,
              );

          if (currentClass != null &&
              _toInt(currentClass['available_tickets']) <= 0) {
            final available = classes.where(
              (item) => _toInt(item['available_tickets']) > 0,
            );

            _selectedClassId = available.isNotEmpty
                ? _toInt(available.first['id'])
                : _toInt(currentClass['id']);
          }
        }

        _quantity = _stock > 0 ? 1 : 0;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingClasses = false;
        _classError = _cleanError(error);
      });
    }
  }

  // ============================================================
  // SELECT TICKET CLASS
  // ============================================================

  void _selectClass(Map<String, dynamic> ticketClass) {
    if (_loading) return;

    final id = _toInt(ticketClass['id']);
    final stock = _toInt(ticketClass['available_tickets']);

    if (id <= 0) {
      _showMessage('ID kelas tiket tidak valid.');
      return;
    }

    if (stock <= 0) {
      _showMessage('Stok tiket untuk kelas ini habis.');
      return;
    }

    setState(() {
      _selectedClassId = id;
      _quantity = 1;
    });
  }

  // ============================================================
  // CREATE ORDER
  // ============================================================

  Future<void> _createOrder() async {
    if (_loading) return;

    final eventId = _eventId;
    final ticketClass = _selectedClass;
    final ticketClassId = _selectedClassId;
    final quantity = _quantity;

    if (eventId == null || eventId <= 0) {
      _showMessage('ID event tidak valid.');
      return;
    }

    if (ticketClass == null ||
        ticketClassId == null ||
        ticketClassId <= 0) {
      _showMessage('Silakan pilih kelas tiket.');
      return;
    }

    if (quantity < 1) {
      _showMessage('Jumlah tiket minimal 1.');
      return;
    }

    if (quantity > 10) {
      _showMessage('Maksimal pemesanan 10 tiket.');
      return;
    }

    final stock = _toInt(ticketClass['available_tickets']);

    if (stock <= 0) {
      _showMessage('Stok tiket untuk kelas ini habis.');
      await _loadTicketClasses();
      return;
    }

    if (quantity > stock) {
      _showMessage(
        'Stok tiket tidak mencukupi. Tersedia: $stock tiket.',
      );
      await _loadTicketClasses();
      return;
    }

    if (_price < 0) {
      _showMessage('Harga tiket tidak valid.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final order = await ApiService.createOrder(
        eventId: eventId,
        ticketClassId: ticketClassId,
        quantity: quantity,
      );

      if (!mounted) return;

      final orderId = _parseId(
        order['id'] ?? order['order_id'],
      );

      if (orderId == null || orderId <= 0) {
        throw Exception(
          'ID pesanan tidak ditemukan pada respons server.',
        );
      }

      final orderForPayment = <String, dynamic>{
        ...order,
        'id': orderId,
        'order_id': orderId,
        'event_id': eventId,
        'ticket_class_id': ticketClassId,
        'ticket_class_name': ticketClass['name'] ?? 'Tiket',
        'quantity': quantity,
        'total_price': order['total_price'] ??
            order['total_amount'] ??
            _total,
        'event_title': _eventTitle,
      };

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            order: orderForPayment,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal membuat pesanan: ${_cleanError(error)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // TICKET CLASS CARD
  // ============================================================

  Widget _buildTicketClassCard(
    Map<String, dynamic> ticketClass,
  ) {
    final id = _toInt(ticketClass['id']);
    final name = (ticketClass['name'] ?? 'Tiket').toString();
    final price = _toNum(ticketClass['price']);
    final stock = _toInt(ticketClass['available_tickets']);
    final selected = _selectedClassId == id;
    final soldOut = stock <= 0;

    return Card(
      elevation: 0,
      color: selected
          ? const Color(0xFFF0EEFF)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? _primary : _border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (_loading || soldOut)
            ? null
            : () => _selectClass(ticketClass),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: soldOut
                      ? Colors.grey.shade100
                      : _palePurple,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  color: soldOut ? Colors.grey : _primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatRupiah(price),
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      soldOut
                          ? 'Stok habis'
                          : 'Tersedia: $stock tiket',
                      style: TextStyle(
                        color: soldOut
                            ? Colors.red
                            : _secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                soldOut
                    ? Icons.block
                    : selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                color: soldOut ? Colors.grey : _primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUANTITY SELECTOR
  // ============================================================

  Widget _buildQuantitySelector() {
    final noStock = _stock <= 0;

    final maxQuantity = _stock < 10 ? _stock : 10;

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Kurangi tiket',
          onPressed: !_loading &&
                  !noStock &&
                  _quantity > 1
              ? () {
                  setState(() {
                    _quantity--;
                  });
                }
              : null,
          style: IconButton.styleFrom(
            foregroundColor: _primary,
            backgroundColor: _palePurple,
          ),
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 18),
        Text(
          '$_quantity',
          style: const TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 18),
        IconButton.filledTonal(
          tooltip: 'Tambah tiket',
          onPressed: !_loading &&
                  !noStock &&
                  _quantity < 10 &&
                  _quantity < _stock
              ? () {
                  setState(() {
                    _quantity++;
                  });
                }
              : null,
          style: IconButton.styleFrom(
            foregroundColor: _primary,
            backgroundColor: _palePurple,
          ),
          icon: const Icon(Icons.add_rounded),
        ),
        const Spacer(),
        Text(
          'Maks. $maxQuantity tiket',
          style: const TextStyle(
            color: _secondaryText,
            fontSize: 12,
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
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Pesan Tiket',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: _textColor,
        ),
      ),
      body: _loadingClasses
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadTicketClasses,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // EVENT HEADER
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _primary,
                          Color(0xFF9187FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.confirmation_number_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pilih tiket favoritmu!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _eventTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _eventLocation,
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Pilih kelas tiket',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ERROR STATE
                  if (_classError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _classError!,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loadTicketClasses,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),

                  // EMPTY STATE
                  ] else if (_ticketClasses.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: const Text(
                        'Kelas tiket belum tersedia untuk event ini. '
                        'Admin perlu menambahkan kelas tiket terlebih dahulu.',
                        style: TextStyle(
                          color: _secondaryText,
                          height: 1.5,
                        ),
                      ),
                    ),

                  // TICKET CLASSES AND ORDER SUMMARY
                  ] else ...[
                    ..._ticketClasses.map(_buildTicketClassCard),

                    const SizedBox(height: 22),

                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: _border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan pesanan',
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Kelas tiket',
                                    style: TextStyle(
                                      color: _secondaryText,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    (_selectedClass?['name'] ?? '-')
                                        .toString(),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Harga per tiket',
                                    style: TextStyle(
                                      color: _secondaryText,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatRupiah(_price),
                                  style: const TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              'Jumlah tiket',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 8),

                            _buildQuantitySelector(),

                            const Divider(
                              height: 30,
                              color: _border,
                            ),

                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total pembayaran',
                                    style: TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    _formatRupiah(_total),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CREATE ORDER BUTTON
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loading ||
                              _selectedClass == null ||
                              _stock < 1 ||
                              _quantity < 1 ||
                              _quantity > _stock
                          ? null
                          : _createOrder,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                            ),
                      label: Text(
                        _loading
                            ? 'Memproses pesanan...'
                            : 'Buat Pesanan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: _secondaryText,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Stok akan dipotong setelah pembayaran dikonfirmasi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryText,
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
}
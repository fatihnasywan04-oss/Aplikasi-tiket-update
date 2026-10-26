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

  static const Color _primary = Color(0xFF5B50E8);
  static const Color _palePurple = Color(0xFFEAE8FF);
  static const Color _textColor = Color(0xFF282738);
  static const Color _secondaryText = Color(0xFF77778A);
  static const Color _background = Color(0xFFF7F7FC);
  static const Color _border = Color(0xFFEAEAF3);

  String _value(
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = widget.event[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  int? get _eventId {
    final rawId = _value(['id', 'event_id']);
    return int.tryParse(rawId);
  }

  num get _price {
    final raw = _value(
      ['price', 'ticket_price', 'harga'],
      fallback: '0',
    );

    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return num.tryParse(cleaned) ?? 0;
  }

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

  String get _formattedTotal => _formatRupiah(_price * _quantity);

  Future<void> _createOrder() async {
    if (_loading) return;

    final eventId = _eventId;

    if (eventId == null || eventId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID event tidak valid atau tidak ditemukan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_quantity < 1 || _quantity > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah tiket harus antara 1 sampai 10.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final Map<String, dynamic> order =
          await ApiService.createOrder(
        eventId: eventId,
        quantity: _quantity,
      );

      if (!mounted) return;

      final dynamic rawOrderId =
          order['id'] ?? order['order_id'];

      final int? orderId = rawOrderId is int
          ? rawOrderId
          : int.tryParse(rawOrderId?.toString() ?? '');

      if (orderId == null || orderId <= 0) {
        throw Exception(
          'ID pesanan tidak ditemukan pada respons server.',
        );
      }

      // Pastikan PaymentPage menerima ID pesanan yang valid.
      final Map<String, dynamic> orderForPayment = {
        ...order,
        'id': orderId,
      };

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(order: orderForPayment),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat pesanan: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
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
    final title = _value(
      ['title', 'name', 'nama_event'],
      fallback: 'Event',
    );

    final location = _value(
      ['location', 'venue', 'lokasi'],
      fallback: 'Lokasi belum tersedia',
    );

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
        iconTheme: const IconThemeData(color: _textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.confirmation_number_rounded,
                  size: 38,
                  color: Colors.white,
                ),
                SizedBox(height: 14),
                Text(
                  'Satu langkah lagi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Periksa detail pesanan sebelum melanjutkan.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Card(
            color: Colors.white,
            elevation: 0,
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
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: _primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            color: _secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _palePurple.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: _primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Harga per tiket',
                            style: TextStyle(color: _textColor),
                          ),
                        ),
                        Text(
                          _formatRupiah(_price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Jumlah tiket',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Kurangi tiket',
                        style: IconButton.styleFrom(
                          foregroundColor: _primary,
                          backgroundColor: _palePurple,
                        ),
                        onPressed: !_loading && _quantity > 1
                            ? () {
                                setState(() {
                                  _quantity--;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(width: 18),
                      IconButton.filledTonal(
                        tooltip: 'Tambah tiket',
                        style: IconButton.styleFrom(
                          foregroundColor: _primary,
                          backgroundColor: _palePurple,
                        ),
                        onPressed: !_loading && _quantity < 10
                            ? () {
                                setState(() {
                                  _quantity++;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const Spacer(),
                      const Text(
                        'Maks. 10 tiket',
                        style: TextStyle(
                          fontSize: 12,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
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
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      Text(
                        _formattedTotal,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _loading ? null : _createOrder,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _loading ? 'Memproses pesanan...' : 'Buat Pesanan',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: _secondaryText,
              ),
              SizedBox(width: 6),
              Text(
                'Pastikan detail pesanan sudah benar',
                style: TextStyle(
                  fontSize: 12,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
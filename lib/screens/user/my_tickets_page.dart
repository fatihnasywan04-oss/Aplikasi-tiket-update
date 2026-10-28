import 'dart:async';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _orders = [];

  final Map<int, Map<String, dynamic>> _eventCache = {};
  final Map<String, Map<String, dynamic>> _ticketClassCache = {};

  Timer? _timer;

  static const List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();

    _load();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD ORDERS DAN INFORMASI TAMBAHAN
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await ApiService.getMyOrders();

      await _enrichOrders(orders);

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _enrichOrders(
    List<Map<String, dynamic>> orders,
  ) async {
    for (final order in orders) {
      if (!mounted) return;

      final existingEvent = _map(order['event']);

      final existingClass = _map(
        order['ticket_class'] ??
            order['ticketClass'] ??
            order['ticket_type'] ??
            order['ticketType'],
      );

      final eventId = _int(
        _firstValue([
          order['event_id'],
          order['eventId'],
          existingEvent['id'],
        ]),
      );

      final ticketClassId = _int(
        _firstValue([
          order['ticket_class_id'],
          order['ticketClassId'],
          existingClass['id'],
          existingClass['ticket_class_id'],
        ]),
      );

      // Muat detail event jika tanggal atau lokasi belum tersedia.
      final hasEventDate = _hasAnyValue([
        existingEvent['event_date'],
        existingEvent['start_date'],
        existingEvent['start_datetime'],
        existingEvent['event_datetime'],
        existingEvent['date'],
      ]);

      final hasLocation = _hasAnyValue([
        existingEvent['location'],
        existingEvent['venue'],
        existingEvent['address'],
        existingEvent['event_location'],
      ]);

      if (eventId != null &&
          eventId > 0 &&
          (!hasEventDate || !hasLocation || existingEvent.isEmpty)) {
        try {
          var event = _eventCache[eventId];

          if (event == null) {
            event = await ApiService.getEventById(eventId);
            _eventCache[eventId] = event;
          }

          // Data dari API detail digunakan sebagai dasar.
          // Data order yang sudah tersedia tetap dipertahankan.
          order['event'] = {
            ...event,
            ...existingEvent,
          };
        } catch (_) {
          // Jangan gagalkan seluruh halaman jika detail event gagal.
        }
      }

      // Ambil kelas tiket jika nama atau harga belum tersedia.
      final updatedClass = _map(
        order['ticket_class'] ??
            order['ticketClass'] ??
            order['ticket_type'] ??
            order['ticketType'],
      );

      final hasClassName = _hasAnyValue([
        updatedClass['name'],
        updatedClass['ticket_class_name'],
        updatedClass['class_name'],
        updatedClass['ticket_type'],
        updatedClass['title'],
        updatedClass['class_name_display'],
      ]);

      final hasClassPrice = _hasAnyValue([
        updatedClass['price'],
        updatedClass['ticket_price'],
        updatedClass['unit_price'],
      ]);

      if (eventId != null &&
          eventId > 0 &&
          ticketClassId != null &&
          ticketClassId > 0 &&
          (!hasClassName || !hasClassPrice || updatedClass.isEmpty)) {
        try {
          final cacheKey = '${eventId}_$ticketClassId';

          var ticketClass = _ticketClassCache[cacheKey];

          if (ticketClass == null) {
            ticketClass = await ApiService.getTicketClassById(
              eventId: eventId,
              ticketClassId: ticketClassId,
            );

            _ticketClassCache[cacheKey] = ticketClass;
          }

          order['ticket_class'] = {
            ...ticketClass,
            ...updatedClass,
          };
        } catch (_) {
          // Informasi yang sudah tersedia tetap ditampilkan.
        }
      }
    }
  }

  // ============================================================
  // DATA HELPERS
  // ============================================================

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;

    if (value is String) {
      final text = value.trim().toLowerCase();

      return text.isEmpty ||
          text == 'null' ||
          text == 'none';
    }

    return false;
  }

  bool _hasAnyValue(List<dynamic> values) {
    return values.any((value) => !_isEmptyValue(value));
  }

  dynamic _firstValue(List<dynamic> values) {
    for (final value in values) {
      if (_isEmptyValue(value)) continue;
      return value;
    }

    return null;
  }

  String _text(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];

        if (value == null || value is Map || value is List) {
          continue;
        }

        final text = value.toString().trim();

        if (text.isNotEmpty &&
            text.toLowerCase() != 'null' &&
            text.toLowerCase() != 'none') {
          return text;
        }
      }
    }

    return fallback;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value == null) return null;

    return int.tryParse(value.toString().trim());
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();

    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return double.tryParse(text.replaceAll(',', ''));
  }

  String _money(dynamic value) {
    final amount = _number(value);

    if (amount == null) return '-';

    final rounded = amount.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return 'Rp ${rounded < 0 ? '-' : ''}$buffer';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(text);
  }

  String _dateTime(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) return '-';

    final date = parsed.toLocal();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${_months[date.month - 1]} '
        '${date.year} • $hour:$minute';
  }

  String _eventDate(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) return '-';

    final date = parsed.toLocal();

    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // STATUS PESANAN DAN PEMBAYARAN
  // ============================================================

  String _normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll('-', '_');
  }

  bool _isPaid(String status) {
    return const {
      'paid',
      'confirmed',
      'success',
      'successful',
      'completed',
      'settlement',
      'settled',
      'captured',
    }.contains(_normalizeStatus(status));
  }

  bool _isFailed(String status) {
    return const {
      'failed',
      'cancelled',
      'canceled',
      'expired',
      'deny',
      'denied',
      'rejected',
    }.contains(_normalizeStatus(status));
  }

  bool _isPending(String status) {
    return const {
      'pending',
      'unpaid',
      'waiting_for_payment',
      'waiting_payment',
    }.contains(_normalizeStatus(status));
  }

  String _statusLabel(String status) {
    switch (_normalizeStatus(status)) {
      case 'paid':
      case 'settlement':
      case 'settled':
        return 'Lunas';

      case 'confirmed':
        return 'Dikonfirmasi';

      case 'success':
      case 'successful':
      case 'completed':
      case 'captured':
        return 'Berhasil';

      case 'pending':
      case 'unpaid':
      case 'waiting_for_payment':
      case 'waiting_payment':
        return 'Menunggu pembayaran';

      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';

      case 'failed':
      case 'deny':
      case 'denied':
      case 'rejected':
        return 'Gagal';

      case 'expired':
        return 'Kedaluwarsa';

      case 'refunded':
        return 'Dana dikembalikan';

      case 'unknown':
      case '':
        return 'Status tidak tersedia';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    if (_isPaid(status)) return AppColors.success;
    if (_isFailed(status)) return AppColors.error;

    return AppColors.primary;
  }

  String _paymentStatus(
    Map<String, dynamic> order,
    Map<String, dynamic> payment,
  ) {
    final paymentStatus = _text(
      [payment],
      ['payment_status', 'paymentStatus', 'status'],
      fallback: '',
    );

    // Status pembayaran yang lunas harus diutamakan.
    if (paymentStatus.isNotEmpty && _isPaid(paymentStatus)) {
      return paymentStatus;
    }

    final orderPaymentStatus = _text(
      [order],
      ['payment_status', 'paymentStatus'],
      fallback: '',
    );

    if (orderPaymentStatus.isNotEmpty &&
        _isPaid(orderPaymentStatus)) {
      return orderPaymentStatus;
    }

    final orderStatus = _text(
      [order],
      ['status', 'order_status'],
      fallback: 'unknown',
    );

    if (_isPaid(orderStatus)) return orderStatus;

    if (paymentStatus.isNotEmpty) return paymentStatus;

    if (orderPaymentStatus.isNotEmpty) {
      return orderPaymentStatus;
    }

    return orderStatus;
  }

  // ============================================================
  // BATAS WAKTU PEMBAYARAN
  // ============================================================

  DateTime? _expirationTime(
    Map<String, dynamic> order,
    Map<String, dynamic> payment,
  ) {
    final value = _firstValue([
      order['expires_at'],
      order['expiration_time'],
      order['expiresAt'],
      payment['expires_at'],
      payment['expiration_time'],
      payment['expiresAt'],
    ]);

    final parsed = _parseDate(value);

    if (parsed == null) return null;

    return parsed.toLocal();
  }

  Duration? _remainingTime(DateTime? expiration) {
    if (expiration == null) return null;

    final remaining = expiration.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  String _countdownLabel(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  bool _canPay({
    required String paymentStatus,
    required String orderStatus,
    required DateTime? expiration,
  }) {
    if (_isPaid(paymentStatus) || _isPaid(orderStatus)) {
      return false;
    }

    if (_isFailed(paymentStatus) || _isFailed(orderStatus)) {
      return false;
    }

    if (!_isPending(paymentStatus) && !_isPending(orderStatus)) {
      return false;
    }

    // Tanpa waktu kedaluwarsa, jangan tampilkan tombol bayar.
    if (expiration == null) return false;

    return expiration.isAfter(DateTime.now());
  }

  // ============================================================
  // NAVIGASI PEMBAYARAN
  // ============================================================

  Future<void> _payNow(
    Map<String, dynamic> order,
    int orderId,
  ) async {
    final payment = _map(
      order['payment'] ??
          order['latest_payment'] ??
          order['latestPayment'],
    );

    final status = _paymentStatus(order, payment);

    final orderStatus = _text(
      [order],
      ['status', 'order_status'],
      fallback: 'unknown',
    );

    final expiration = _expirationTime(order, payment);

    if (!_canPay(
      paymentStatus: status,
      orderStatus: orderStatus,
      expiration: expiration,
    )) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Waktu pembayaran sudah habis atau pesanan '
            'tidak lagi menunggu pembayaran.',
          ),
        ),
      );

      await _load();
      return;
    }

    try {
      await Navigator.of(context).pushNamed(
        '/payment',
        arguments: {
          'orderId': orderId,
          'order': order,
        },
      );

      if (mounted) {
        await _load();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Halaman pembayaran belum terhubung. '
            'Periksa route /payment di aplikasi.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.text,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _paymentAction({
    required Map<String, dynamic> order,
    required int orderId,
    required String paymentStatus,
    required String orderStatus,
    required DateTime? expiration,
  }) {
    final remaining = _remainingTime(expiration);

    final canPay = _canPay(
      paymentStatus: paymentStatus,
      orderStatus: orderStatus,
      expiration: expiration,
    );

    if (canPay && remaining != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sisa waktu pembayaran',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _countdownLabel(remaining),
                  style: TextStyle(
                    color: remaining.inSeconds <= 10
                        ? AppColors.error
                        : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _payNow(order, orderId),
              icon: const Icon(Icons.payment_rounded),
              label: const Text('Bayar Sekarang'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isPaid(paymentStatus) &&
        !_isPaid(orderStatus) &&
        expiration != null &&
        !expiration.isAfter(DateTime.now())) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Waktu pembayaran telah habis. '
            'Silakan buat pesanan baru jika masih ingin membeli tiket.',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _ticketCard(Map<String, dynamic> order) {
    final event = _map(order['event']);

    final ticketClass = _map(
      order['ticket_class'] ??
          order['ticketClass'] ??
          order['ticket_type'] ??
          order['ticketType'],
    );

    final payment = _map(
      order['payment'] ??
          order['latest_payment'] ??
          order['latestPayment'],
    );

    // Data pemesan bisa berada di beberapa bentuk respons API.
    final buyer = _map(
      order['user'] ??
          order['buyer'] ??
          order['customer'] ??
          order['customer_info'] ??
          order['customerInfo'] ??
          order['purchaser'],
    );

    final orderId = _int(
      _firstValue([
        order['id'],
        order['order_id'],
      ]),
    );

    final eventName = _text(
      [event, order],
      [
        'title',
        'event_title',
        'event_name',
        'name',
        'nama_event',
      ],
      fallback: 'Event tidak diketahui',
    );

    final eventDateValue = _firstValue([
      event['event_date'],
      event['start_date'],
      event['start_datetime'],
      event['event_datetime'],
      event['event_start'],
      event['start_time'],
      event['date'],
      order['event_date'],
      order['start_date'],
      order['event_start'],
    ]);

    final eventDate = _eventDate(eventDateValue);

    final location = _text(
      [event, order],
      [
        'location',
        'venue',
        'address',
        'event_location',
        'lokasi',
      ],
    );

    // Prioritaskan nama kelas sebenarnya seperti VIP, Standard, VVIP.
    final ticketClassName = _text(
      [
        ticketClass,
        order,
        event,
      ],
      [
        'name',
        'ticket_class_name',
        'ticketClassName',
        'class_name',
        'className',
        'ticket_type',
        'ticketType',
        'ticket_class_title',
        'class_name_display',
        'category_name',
        'category',
        'type_name',
        'tier_name',
        'title',
        'nama_kelas',
      ],
      fallback: 'Kelas tiket #${order['ticket_class_id'] ?? '-'}',
    );

    final quantity = _int(
          _firstValue([
            order['quantity'],
            order['ticket_quantity'],
            order['ticketQuantity'],
          ]),
        ) ??
        0;

    final totalPrice = _firstValue([
      order['total_price'],
      order['total_amount'],
      order['total'],
      order['amount'],
      payment['amount'],
    ]);

    final unitPrice = _firstValue([
      ticketClass['price'],
      ticketClass['ticket_price'],
      ticketClass['unit_price'],
      order['ticket_price'],
      order['unit_price'],
      order['price'],
    ]);

    final createdAt = _firstValue([
      order['created_at'],
      order['order_date'],
      order['ordered_at'],
    ]);

    final orderStatus = _text(
      [order],
      ['status', 'order_status'],
      fallback: 'unknown',
    );

    final paymentStatus = _paymentStatus(order, payment);

    final expiration = _expirationTime(order, payment);

    final paymentMethod = _text(
      [payment, order],
      ['payment_method', 'method'],
      fallback: '',
    );

    final transactionId = _text(
      [payment, order],
      ['transaction_id'],
      fallback: '',
    );

    // Ambil nama/email dari objek user terlebih dahulu,
    // lalu gunakan field langsung pada order sebagai cadangan.
    final buyerName = _text(
      [
        buyer,
        order,
      ],
      [
        'full_name',
        'user_name',
        'buyer_name',
        'customer_name',
        'purchaser_name',
        'name',
        'username',
        'nama_pemesan',
      ],
    );

    final buyerEmail = _text(
      [
        buyer,
        order,
      ],
      [
        'email',
        'user_email',
        'buyer_email',
        'customer_email',
        'purchaser_email',
        'email_pemesan',
      ],
    );

    final imageUrl = _text(
      [event, order],
      ['image_url', 'event_image', 'poster_url'],
      fallback: '',
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey('order_$orderId'),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          18,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.confirmation_number_rounded,
            color: AppColors.primary,
            size: 27,
          ),
        ),
        title: Text(
          eventName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan #${orderId ?? '-'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              _statusChip(paymentStatus),
            ],
          ),
        ),
        children: [
          const Divider(height: 20),

          if (imageUrl.startsWith('https://') ||
              imageUrl.startsWith('http://'))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),

          _sectionTitle(
            'Informasi event',
            Icons.event_rounded,
          ),
          _detailRow('Nama event', eventName),
          _detailRow('Tanggal event', eventDate),
          _detailRow('Lokasi', location),

          _sectionTitle(
            'Informasi tiket',
            Icons.confirmation_number_outlined,
          ),
          _detailRow(
            'Nomor pesanan',
            '#${orderId ?? '-'}',
          ),
          _detailRow('Kelas tiket', ticketClassName),
          _detailRow('Jumlah tiket', '$quantity tiket'),
          _detailRow('Harga satuan', _money(unitPrice)),
          _detailRow(
            'Total pembayaran',
            _money(totalPrice),
            bold: true,
          ),
          _detailRow(
            'Waktu pemesanan',
            createdAt == null ? '-' : _dateTime(createdAt),
          ),

          _sectionTitle(
            'Informasi pemesan',
            Icons.person_outline_rounded,
          ),
          _detailRow('Nama pemesan', buyerName),
          _detailRow('Email pemesan', buyerEmail),

          _sectionTitle(
            'Informasi pembayaran',
            Icons.payment_rounded,
          ),
          _detailRow(
            'Status pesanan',
            _statusLabel(orderStatus),
          ),
          _detailRow(
            'Status pembayaran',
            _statusLabel(paymentStatus),
            bold: true,
          ),

          if (paymentMethod.isNotEmpty)
            _detailRow('Metode pembayaran', paymentMethod),

          if (transactionId.isNotEmpty)
            _detailRow('ID transaksi', transactionId),

          if (orderId != null)
            _paymentAction(
              order: order,
              orderId: orderId,
              paymentStatus: paymentStatus,
              orderStatus: orderStatus,
              expiration: expiration,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tiket Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 52,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gagal memuat tiket',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 140),
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 58,
                            color: AppColors.primaryLight,
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Belum ada tiket',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Pesananmu akan muncul di halaman ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: _orders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _ticketCard(_orders[index]);
                        },
                      ),
                    ),
    );
  }
}
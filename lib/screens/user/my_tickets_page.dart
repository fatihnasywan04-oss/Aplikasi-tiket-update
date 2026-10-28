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
  }

  // ============================================================
  // LOAD ORDERS
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await ApiService.getMyOrders();

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e
            .toString()
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
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

  dynamic _firstValue(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      if (value is String) {
        final text = value.trim();

        if (text.isEmpty || text.toLowerCase() == 'null') {
          continue;
        }
      }

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

        if (text.isNotEmpty && text.toLowerCase() != 'null') {
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
  // STATUS
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
    if (_isPaid(status)) {
      return AppColors.success;
    }

    if (_isFailed(status)) {
      return AppColors.error;
    }

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

    if (paymentStatus.isNotEmpty) {
      return paymentStatus;
    }

    final orderPaymentStatus = _text(
      [order],
      ['payment_status', 'paymentStatus'],
      fallback: '',
    );

    if (orderPaymentStatus.isNotEmpty) {
      return orderPaymentStatus;
    }

    // Backend menandai order.status = "paid" saat pembayaran sukses.
    final orderStatus = _text(
      [order],
      ['status', 'order_status'],
      fallback: 'unknown',
    );

    if (_isPaid(orderStatus) || _isFailed(orderStatus)) {
      return orderStatus;
    }

    return orderStatus;
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

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _ticketCard(Map<String, dynamic> order) {
    final event = _map(order['event']);

    final ticketClass = _map(
      order['ticket_class'] ?? order['ticketClass'],
    );

    final payment = _map(
      order['payment'] ??
          order['latest_payment'] ??
          order['latestPayment'],
    );

    final orderId = _firstValue([
      order['id'],
      order['order_id'],
    ]);

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
      event['date'],
      order['event_date'],
      order['start_date'],
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

    final ticketClassName = _text(
      [ticketClass, order],
      [
        'name',
        'ticket_class_name',
        'class_name',
        'ticket_type',
      ],
      fallback: 'Kelas tiket #${order['ticket_class_id'] ?? '-'}',
    );

    final quantity = _int(
          _firstValue([
            order['quantity'],
            order['ticket_quantity'],
          ]),
        ) ??
        0;

    final totalPrice = _firstValue([
      order['total_price'],
      order['total_amount'],
      order['total'],
      payment['amount'],
    ]);

    final unitPrice = _firstValue([
      ticketClass['price'],
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

    final buyer = _map(order['user']);

    final buyerName = _text(
      [buyer],
      ['name', 'full_name', 'username'],
      fallback: '-',
    );

    final buyerEmail = _text(
      [buyer],
      ['email'],
      fallback: '-',
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
                'Pesanan #$orderId',
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
          _detailRow('Nomor pesanan', '#$orderId'),
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
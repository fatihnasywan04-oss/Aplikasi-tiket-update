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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getMyOrders();

      if (!mounted) return;

      setState(() {
        _orders = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return fallback;
  }

  String _firstText(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final source in sources) {
      final value = _text(source, keys, fallback: '');

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
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

  String _date(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      return value == null || value.toString().trim().isEmpty
          ? '-'
          : value.toString();
    }

    final date = parsed.toLocal();

    const months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _dateTime(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      return value == null || value.toString().trim().isEmpty
          ? '-'
          : value.toString();
    }

    final date = parsed.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${_date(date)} • $hour:$minute';
  }

  String _eventTime(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) return '-';

    final date = parsed.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
      case 'confirmed':
      case 'success':
      case 'successful':
      case 'completed':
        return AppColors.success;

      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'expired':
        return AppColors.error;

      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
        return 'Sudah dibayar';

      case 'confirmed':
        return 'Dikonfirmasi';

      case 'success':
      case 'successful':
      case 'completed':
        return 'Berhasil';

      case 'pending':
        return 'Menunggu pembayaran';

      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';

      case 'failed':
        return 'Gagal';

      case 'expired':
        return 'Kedaluwarsa';

      case 'unknown':
      case '-':
      case '':
        return 'Status tidak tersedia';

      default:
        return status;
    }
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
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
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
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
          Icon(icon, size: 19, color: AppColors.primary),
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

  Widget _statusChip(String label, String rawStatus) {
    final color = _statusColor(rawStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _ticketCard(Map<String, dynamic> order) {
    final event = _map(order['event']);

    final ticketClass = _map(order['ticket_class'] ?? order['ticketClass']);

    final user = _map(order['user']);

    final payment = _map(
      order['payment'] ?? order['latest_payment'] ?? order['latestPayment'],
    );

    final orderId = _firstText([order], ['id', 'order_id']);

    final eventName = _firstText(
      [event, order],
      ['title', 'event_title', 'event_name', 'name', 'nama_event'],
      fallback: 'Event tidak diketahui',
    );

    final eventDate = _firstText(
      [event, order],
      ['event_date', 'date', 'tanggal', 'start_date'],
    );

    final eventLocation = _firstText(
      [event, order],
      ['location', 'venue', 'address', 'event_location', 'lokasi'],
    );

    final ticketName = _firstText(
      [ticketClass, order],
      ['name', 'ticket_class_name', 'ticket_name', 'class_name', 'ticket_type'],
      fallback: 'Kelas tiket tidak tersedia',
    );

    final quantityValue = _firstText(
      [order],
      ['quantity', 'ticket_quantity'],
      fallback: '0',
    );

    final quantity = _number(quantityValue) ?? 0;

    final orderStatus = _text(order, [
      'status',
      'order_status',
    ], fallback: 'unknown');

    final paymentStatus = _firstText(
      [payment, order],
      ['payment_status', 'status_pembayaran'],
      fallback: 'Belum ada informasi pembayaran',
    );

    final totalValue = _firstText(
      [order],
      ['total_price', 'total_amount', 'amount', 'total'],
      fallback: '',
    );

    final unitPriceValue = _firstText(
      [ticketClass, order],
      ['price', 'ticket_price', 'unit_price'],
      fallback: '',
    );

    final unitPrice = unitPriceValue.isNotEmpty
        ? unitPriceValue
        : (() {
            final total = _number(totalValue);

            if (total != null && quantity > 0) {
              return (total / quantity).toStringAsFixed(0);
            }

            return '-';
          })();

    final createdAt = _firstText(
      [order],
      ['created_at', 'order_date', 'ordered_at'],
    );

    final description = _firstText(
      [event, order],
      ['description', 'event_description', 'deskripsi'],
    );

    final buyerName = _firstText(
      [user, order],
      ['name', 'full_name', 'user_name', 'buyer_name', 'nama_pemesan'],
    );

    final buyerEmail = _firstText(
      [user, order],
      ['email', 'user_email', 'buyer_email'],
    );

    final imageUrl = _firstText(
      [event, order],
      ['image_url', 'event_image', 'poster_url'],
      fallback: '',
    );

    final paymentMethod = _firstText(
      [payment, order],
      ['payment_method', 'method'],
      fallback: '',
    );

    final transactionId = _firstText(
      [payment, order],
      ['transaction_id'],
      fallback: '',
    );

    final paidAt = _firstText([payment, order], ['paid_at'], fallback: '');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('order_$orderId'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                _statusChip(_statusLabel(orderStatus), orderStatus),
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

            _sectionTitle('Informasi event', Icons.event_rounded),
            _detailRow('Nama event', eventName),
            _detailRow('Tanggal event', _date(eventDate)),
            _detailRow('Waktu event', _eventTime(eventDate)),
            _detailRow('Lokasi', eventLocation),

            if (description != '-') _detailRow('Deskripsi', description),

            _sectionTitle(
              'Informasi tiket',
              Icons.confirmation_number_outlined,
            ),
            _detailRow('Nomor pesanan', '#$orderId'),
            _detailRow('Kelas tiket', ticketName),
            _detailRow('Jumlah tiket', '${quantity.toStringAsFixed(0)} tiket'),
            _detailRow('Harga satuan', _money(unitPrice)),
            _detailRow('Total pembayaran', _money(totalValue), bold: true),
            _detailRow('Waktu pemesanan', _dateTime(createdAt)),

            _sectionTitle('Informasi pemesan', Icons.person_outline_rounded),
            _detailRow('Nama pemesan', buyerName),
            _detailRow('Email pemesan', buyerEmail),

            _sectionTitle('Informasi pembayaran', Icons.payment_rounded),
            _detailRow('Status pesanan', _statusLabel(orderStatus)),
            _detailRow(
              'Status pembayaran',
              paymentStatus == 'Belum ada informasi pembayaran'
                  ? paymentStatus
                  : _statusLabel(paymentStatus),
            ),

            if (paymentMethod.isNotEmpty)
              _detailRow('Metode pembayaran', paymentMethod),

            if (transactionId.isNotEmpty)
              _detailRow('ID transaksi', transactionId),

            if (paidAt.isNotEmpty)
              _detailRow('Waktu pembayaran', _dateTime(paidAt)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tiket Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              child: CircularProgressIndicator(color: AppColors.primary),
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
                      style: const TextStyle(color: AppColors.textSecondary),
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
                physics: const AlwaysScrollableScrollPhysics(),
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
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _ticketCard(_orders[index]);
                },
              ),
            ),
    );
  }
}

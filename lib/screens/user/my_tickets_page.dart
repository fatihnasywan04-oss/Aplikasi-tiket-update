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

  Map<String, dynamic> _currentUser = {};

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
  // LOAD DATA
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ApiService.getMyOrders(),
        ApiService.getMe(),
      ]);

      if (!mounted) return;

      final orders =
          (results[0] as List<Map<String, dynamic>>);

      final user =
          Map<String, dynamic>.from(results[1] as Map);

      setState(() {
        _orders = orders;
        _currentUser = user;
      });

      // Lengkapi data yang belum disertakan endpoint daftar pesanan.
      await _enrichOrders();
    } catch (e) {
      if (!mounted) return;

      // Jika endpoint profil gagal, pesanan tetap dicoba dimuat.
      try {
        final orders = await ApiService.getMyOrders();

        if (!mounted) return;

        setState(() {
          _orders = orders;
          _currentUser = {};
        });

        await _enrichOrders();
      } catch (orderError) {
        if (!mounted) return;

        setState(() {
          _error = orderError
              .toString()
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _enrichOrders() async {
    if (_orders.isEmpty) return;

    final updatedOrders = <Map<String, dynamic>>[];

    for (final original in _orders) {
      final order = Map<String, dynamic>.from(original);

      try {
        final eventId = _int(
          _firstValue([
            order['event_id'],
            _map(order['event'])['id'],
          ]),
        );

        final classId = _int(
          _firstValue([
            order['ticket_class_id'],
            order['ticketClassId'],
            _map(order['ticket_class'])['id'],
            _map(order['ticketClass'])['id'],
          ]),
        );

        final event = _map(order['event']);
        final ticketClass = _map(
          order['ticket_class'] ?? order['ticketClass'],
        );

        // Ambil detail event jika pesanan hanya berisi event_id.
        if (eventId != null &&
            eventId > 0 &&
            !_hasEventDetails(event)) {
          try {
            final detail =
                await ApiService.getEventById(eventId);

            if (detail.isNotEmpty) {
              order['event'] = {
                ...event,
                ...detail,
              };
            }
          } catch (_) {
            // Informasi yang sudah ada tetap dipertahankan.
          }
        }

        // Ambil kelas tiket berdasarkan ID yang tersimpan di pesanan.
        if (eventId != null &&
            eventId > 0 &&
            classId != null &&
            classId > 0 &&
            !_hasClassName(ticketClass)) {
          try {
            final detail =
                await ApiService.getTicketClassById(
              eventId: eventId,
              ticketClassId: classId,
            );

            if (detail.isNotEmpty) {
              order['ticket_class'] = {
                ...ticketClass,
                ...detail,
              };
            }
          } catch (_) {
            // Gunakan ticket_class_name dari pesanan jika tersedia.
          }
        }

        // Ambil detail pembayaran jika belum tersedia.
        final payment = _map(
          order['payment'] ??
              order['latest_payment'] ??
              order['latestPayment'],
        );

        if (payment.isEmpty) {
          try {
            final payments = await ApiService.getMyPayments();

            final orderId = _int(
              _firstValue([order['id'], order['order_id']]),
            );

            if (orderId != null) {
              final matchingPayments = payments.where((item) {
                final paymentOrderId = _int(
                  _firstValue([
                    item['order_id'],
                    _map(item['order'])['id'],
                  ]),
                );

                return paymentOrderId == orderId;
              }).toList();

              if (matchingPayments.isNotEmpty) {
                order['payment'] = matchingPayments.last;
              }
            }
          } catch (_) {
            // Status pembayaran dari pesanan tetap digunakan.
          }
        }
      } catch (_) {
        // Jangan menghilangkan pesanan akibat detail tambahan gagal.
      }

      updatedOrders.add(order);
    }

    if (!mounted) return;

    setState(() {
      _orders = updatedOrders;
    });
  }

  bool _hasEventDetails(Map<String, dynamic> event) {
    return _firstValue([
          event['title'],
          event['name'],
          event['event_date'],
          event['date'],
          event['start_date'],
          event['location'],
          event['venue'],
        ]) !=
        null;
  }

  bool _hasClassName(Map<String, dynamic> ticketClass) {
    return _firstValue([
          ticketClass['name'],
          ticketClass['ticket_class_name'],
        ]) !=
        null;
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
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is Map || value is List) continue;

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
      final value = _text(
        source,
        keys,
        fallback: '',
      );

      if (value.isNotEmpty) {
        return value;
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

  // ============================================================
  // DATE AND TIME
  // ============================================================

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

    return '${date.day} '
        '${_months[date.month - 1]} '
        '${date.year}';
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

  String _time(dynamic value) {
    if (value == null) return '-';

    final raw = value.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return '-';
    }

    // Mendukung waktu berupa HH:mm atau HH:mm:ss.
    final timeOnly = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
    ).firstMatch(raw);

    if (timeOnly != null) {
      return '${timeOnly.group(1)!.padLeft(2, '0')}:'
          '${timeOnly.group(2)}';
    }

    final parsed = _parseDate(value);

    if (parsed == null) return raw;

    final date = parsed.toLocal();

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _eventDateTime(
    Map<String, dynamic> event,
    Map<String, dynamic> order,
  ) {
    final start = _firstValue([
      event['start_datetime'],
      event['start_at'],
      event['starts_at'],
      event['event_datetime'],
      event['event_date'],
      event['start_date'],
      event['date'],
      event['tanggal'],
      order['event_datetime'],
      order['event_date'],
      order['start_date'],
    ]);

    if (start == null) return '-';

    final startText = start.toString().trim();

    // Field tanggal event terkadang hanya berisi tanggal.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startText)) {
      final separateTime = _firstValue([
        event['start_time'],
        event['event_time'],
        event['time'],
        event['waktu'],
        order['start_time'],
        order['event_time'],
      ]);

      if (separateTime != null) {
        return '${_date(start)} • ${_time(separateTime)}';
      }
    }

    return _dateTime(start);
  }

  String _eventEndTime(Map<String, dynamic> event) {
    final end = _firstValue([
      event['end_datetime'],
      event['end_at'],
      event['ends_at'],
      event['end_date'],
      event['event_end'],
      event['end_time'],
      event['waktu_selesai'],
    ]);

    if (end == null) return '-';

    final text = end.toString().trim();

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return _date(end);
    }

    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(text)) {
      return _time(end);
    }

    return _dateTime(end);
  }

  // ============================================================
  // STATUS PEMESANAN DAN PEMBAYARAN
  // ============================================================

  String _normalizeStatus(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_');
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

      case '':
      case '-':
      case 'unknown':
        return 'Status tidak tersedia';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    final normalized = _normalizeStatus(status);

    if (_isPaid(normalized)) {
      return AppColors.success;
    }

    if (_isFailed(normalized)) {
      return AppColors.error;
    }

    return AppColors.primary;
  }

  String _effectivePaymentStatus(
    Map<String, dynamic> order,
    Map<String, dynamic> payment,
  ) {
    final paymentStatus = _firstText(
      [payment],
      [
        'status',
        'payment_status',
        'paymentStatus',
        'status_pembayaran',
      ],
      fallback: '',
    );

    final orderPaymentStatus = _firstText(
      [order],
      [
        'payment_status',
        'paymentStatus',
        'status_pembayaran',
      ],
      fallback: '',
    );

    // Status pembayaran diprioritaskan dari data pembayaran.
    if (paymentStatus.isNotEmpty) {
      return paymentStatus;
    }

    if (orderPaymentStatus.isNotEmpty) {
      return orderPaymentStatus;
    }

    final orderStatus = _firstText(
      [order],
      ['order_status', 'status'],
      fallback: '',
    );

    // Status order paid/confirmed dapat menjadi indikator pembayaran.
    if (_isPaid(orderStatus)) return orderStatus;

    if (_isFailed(orderStatus)) return orderStatus;

    return 'unknown';
  }

  String _buyerName(
    Map<String, dynamic> order,
    Map<String, dynamic> user,
  ) {
    return _firstText(
      [user, _currentUser, order],
      [
        'name',
        'full_name',
        'username',
        'user_name',
        'buyer_name',
        'nama_pemesan',
      ],
      fallback: '-',
    );
  }

  String _buyerEmail(
    Map<String, dynamic> order,
    Map<String, dynamic> user,
  ) {
    return _firstText(
      [user, _currentUser, order],
      [
        'email',
        'user_email',
        'buyer_email',
      ],
      fallback: '-',
    );
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

  Widget _statusChip(String label, String rawStatus) {
    final color = _statusColor(rawStatus);

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
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // TICKET CARD
  // ============================================================

  Widget _ticketCard(Map<String, dynamic> order) {
    final event = _map(order['event']);

    final ticketClass = _map(
      order['ticket_class'] ?? order['ticketClass'],
    );

    final user = _map(order['user']);

    final payment = _map(
      order['payment'] ??
          order['latest_payment'] ??
          order['latestPayment'],
    );

    final orderId = _firstText(
      [order],
      ['id', 'order_id'],
    );

    final eventName = _firstText(
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

    final eventDate = _eventDateTime(event, order);

    final eventEnd = _eventEndTime(event);

    final eventLocation = _firstText(
      [event, order],
      [
        'location',
        'venue',
        'address',
        'event_location',
        'lokasi',
      ],
    );

    final ticketName = _firstText(
      [ticketClass, order],
      [
        'ticket_class_name',
        'class_name',
        'ticket_name',
        'ticket_type',
        'name',
      ],
      fallback: 'Kelas tiket tidak tersedia',
    );

    final quantity = _number(
          _firstValue([
            order['quantity'],
            order['ticket_quantity'],
          ]),
        ) ??
        0;

    final orderStatus = _firstText(
      [order],
      ['order_status', 'status'],
      fallback: 'unknown',
    );

    final paymentStatus = _effectivePaymentStatus(
      order,
      payment,
    );

    final totalValue = _firstValue([
      order['total_price'],
      order['total_amount'],
      order['amount'],
      order['total'],
      payment['amount'],
    ]);

    final unitPriceValue = _firstValue([
      order['ticket_price'],
      order['unit_price'],
      ticketClass['price'],
      order['price'],
    ]);

    final unitPrice = unitPriceValue ??
        (() {
          final total = _number(totalValue);

          if (total != null && quantity > 0) {
            return total / quantity;
          }

          return null;
        })();

    final createdAt = _firstValue([
      order['created_at'],
      order['order_date'],
      order['ordered_at'],
    ]);

    final description = _firstText(
      [event, order],
      [
        'description',
        'event_description',
        'deskripsi',
      ],
      fallback: '',
    );

    final buyerName = _buyerName(order, user);

    final buyerEmail = _buyerEmail(order, user);

    final imageUrl = _firstText(
      [event, order],
      [
        'image_url',
        'event_image',
        'poster_url',
      ],
      fallback: '',
    );

    final paymentMethod = _firstText(
      [payment, order],
      [
        'payment_method',
        'method',
      ],
      fallback: '',
    );

    final paymentProvider = _firstText(
      [payment, order],
      [
        'payment_provider',
        'provider',
      ],
      fallback: '',
    );

    final transactionId = _firstText(
      [payment, order],
      [
        'transaction_id',
        'external_id',
      ],
      fallback: '',
    );

    final paidAt = _firstText(
      [payment, order],
      ['paid_at', 'settled_at'],
      fallback: '',
    );

    final orderCreatedAt = createdAt == null
        ? '-'
        : _dateTime(createdAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
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
                _statusChip(
                  _statusLabel(paymentStatus),
                  paymentStatus,
                ),
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
                  errorBuilder: (_, _, _) {
                    return const SizedBox.shrink();
                  },
                ),
              ),

            _sectionTitle(
              'Informasi event',
              Icons.event_rounded,
            ),
            _detailRow('Nama event', eventName),
            _detailRow('Tanggal dan waktu', eventDate),
            _detailRow('Waktu selesai', eventEnd),
            _detailRow('Lokasi', eventLocation),

            if (description.isNotEmpty)
              _detailRow('Deskripsi', description),

            _sectionTitle(
              'Informasi tiket',
              Icons.confirmation_number_outlined,
            ),
            _detailRow('Nomor pesanan', '#$orderId'),
            _detailRow('Kelas tiket', ticketName),
            _detailRow(
              'Jumlah tiket',
              '${quantity.toStringAsFixed(0)} tiket',
            ),
            _detailRow(
              'Harga satuan',
              _money(unitPrice),
            ),
            _detailRow(
              'Total pembayaran',
              _money(totalValue),
              bold: true,
            ),
            _detailRow(
              'Waktu pemesanan',
              orderCreatedAt,
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
              _detailRow(
                'Metode pembayaran',
                paymentMethod,
              ),

            if (paymentProvider.isNotEmpty)
              _detailRow(
                'Penyedia pembayaran',
                paymentProvider,
              ),

            if (transactionId.isNotEmpty)
              _detailRow(
                'ID transaksi',
                transactionId,
              ),

            if (paidAt.isNotEmpty)
              _detailRow(
                'Waktu pembayaran',
                _dateTime(paidAt),
              ),
          ],
        ),
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
                          icon: const Icon(
                            Icons.refresh_rounded,
                          ),
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
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _ticketCard(_orders[index]);
                        },
                      ),
                    ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';

class AdminEventPaymentsPage extends StatefulWidget {
  final int eventId;

  const AdminEventPaymentsPage({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventPaymentsPage> createState() =>
      _AdminEventPaymentsPageState();
}

class _AdminEventPaymentsPageState
    extends State<AdminEventPaymentsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPayments();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _readValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  int _getEventId(Map<String, dynamic> payment) {
    final directEventId = payment['event_id'];

    if (directEventId != null) {
      return _toInt(directEventId);
    }

    final event = _readValue(payment['event']);

    if (event['id'] != null) {
      return _toInt(event['id']);
    }

    final order = _readValue(payment['order']);

    if (order['event_id'] != null) {
      return _toInt(order['event_id']);
    }

    final nestedEvent = _readValue(order['event']);

    if (nestedEvent['id'] != null) {
      return _toInt(nestedEvent['id']);
    }

    final ticketClass = _readValue(order['ticket_class']);

    if (ticketClass['event_id'] != null) {
      return _toInt(ticketClass['event_id']);
    }

    return 0;
  }

  Future<List<Map<String, dynamic>>> _loadPayments() async {
    final payments = await ApiService.getOrganizerPayments();

    return payments.where((payment) {
      return _getEventId(payment) == widget.eventId;
    }).toList();
  }

  Future<void> _refresh() async {
    final future = _loadPayments();

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (e) {
      debugPrint('Refresh payments error: $e');
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = _toInt(value);

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'Rp $formatted';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  String _paymentStatus(Map<String, dynamic> payment) {
    return (payment['payment_status'] ??
            payment['status'] ??
            'pending')
        .toString()
        .toLowerCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'success':
      case 'paid':
        return 'Berhasil';
      case 'pending':
        return 'Menunggu';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'success':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String _paymentMethod(Map<String, dynamic> payment) {
    final method = payment['payment_method'] ??
        payment['payment_provider'] ??
        payment['method'];

    if (method == null || method.toString().isEmpty) {
      return '-';
    }

    return method.toString().replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentId =
        payment['id'] ?? payment['payment_id'] ?? '-';

    final order = _readValue(payment['order']);

    final orderId = payment['order_id'] ??
        order['id'] ??
        '-';

    final amount = payment['amount'] ??
        payment['total_amount'] ??
        order['total_price'] ??
        0;

    final status = _paymentStatus(payment);

    final createdAt = payment['created_at'] ??
        payment['paid_at'] ??
        payment['payment_date'];

    final method = _paymentMethod(payment);
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pembayaran #$paymentId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _buildInfoRow(
            Icons.receipt_long_outlined,
            'ID Pesanan',
            '#$orderId',
          ),

          _buildInfoRow(
            Icons.payments_outlined,
            'Jumlah Pembayaran',
            _formatCurrency(amount),
          ),

          _buildInfoRow(
            Icons.account_balance_wallet_outlined,
            'Metode Pembayaran',
            method,
          ),

          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Tanggal Pembayaran',
            _formatDate(createdAt),
          ),

          if (payment['transaction_id'] != null)
            _buildInfoRow(
              Icons.tag,
              'ID Transaksi',
              payment['transaction_id'].toString(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 130),
        Icon(
          Icons.payments_outlined,
          color: Colors.white38,
          size: 65,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada pembayaran untuk event ini.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AdminEventDrawerPage(),
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Pembayaran Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(
                  context,
                  '/admin-event',
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat data pembayaran.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Total ${payments.length} pembayaran',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 15),
                ...payments.map(_buildPaymentCard),
              ],
            ),
          );
        },
      ),
    );
  }
}
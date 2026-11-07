
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';

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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _readValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  int? _getEventId(Map<String, dynamic> payment) {
    final directId = _toInt(
      payment['event_id'] ?? payment['eventId'],
    );

    if (directId != null) return directId;

    final order = payment['order'];

    if (order is Map) {
      final orderEventId = _toInt(
        order['event_id'] ?? order['eventId'],
      );

      if (orderEventId != null) return orderEventId;

      final event = order['event'];

      if (event is Map) {
        return _toInt(event['id'] ?? event['event_id']);
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _loadPayments() async {
    // Endpoint pembayaran admin dan Admin Event.
    // Backend harus membatasi Admin Event berdasarkan event miliknya.
    final payments = await ApiService.getAdminPayments();

    return payments.where((payment) {
      return _getEventId(payment) == widget.eventId;
    }).toList();
  }

  Future<void> _refresh() async {
    final newFuture = _loadPayments();

    setState(() {
      _future = newFuture;
    });

    try {
      await newFuture;
    } catch (_) {
      // Error ditampilkan melalui FutureBuilder.
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return 'Berhasil';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'transfer_bank':
      case 'bank_transfer':
      case 'transfer':
        return 'Transfer Bank';
      case 'e_wallet':
      case 'ewallet':
      case 'e-wallet':
        return 'E-Wallet';
      case 'qris':
        return 'QRIS';
      default:
        return method;
    }
  }

  Widget _buildStatus(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: Colors.white54),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentId = _readValue(
      payment,
      ['id', 'payment_id'],
    );

    final orderId = _readValue(
      payment,
      ['order_id'],
    );

    final amount = _readValue(
      payment,
      ['amount', 'total_amount', 'total'],
    );

    final status = _readValue(
      payment,
      ['status', 'payment_status'],
      fallback: 'pending',
    );

    final method = _methodLabel(
      _readValue(
        payment,
        ['method', 'payment_method', 'method_name'],
        fallback: '-',
      ),
    );

    final transactionId = _readValue(
      payment,
      ['transaction_id'],
    );

    final paidAt = _formatDate(
      payment['paid_at'] ?? payment['created_at'],
    );

    final order = payment['order'];

    String customerName = '-';
    String eventName = '-';

    if (order is Map) {
      final user = order['user'];

      if (user is Map) {
        customerName = _readValue(
          user.cast<String, dynamic>(),
          ['name', 'username', 'full_name'],
        );
      }

      final event = order['event'];

      if (event is Map) {
        eventName = _readValue(
          event.cast<String, dynamic>(),
          ['name', 'title'],
        );
      }

      if (customerName == '-') {
        customerName = _readValue(
          order.cast<String, dynamic>(),
          ['username', 'user_name', 'customer_name'],
        );
      }
    }

    if (eventName == '-') {
      eventName = _readValue(
        payment,
        ['event_name', 'event_title'],
      );
    }

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.payments,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pembayaran #$paymentId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _buildStatus(status),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow('ID Pesanan', orderId),
            _detailRow('Nama Pembeli', customerName),
            _detailRow('Nama Event', eventName),
            _detailRow('Metode Pembayaran', method),
            _detailRow('Nominal', 'Rp $amount'),
            _detailRow('Tanggal', paidAt),
            if (transactionId != '-')
              _detailRow('ID Transaksi', transactionId),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 150),
        Icon(
          Icons.payments_outlined,
          color: Colors.white38,
          size: 55,
        ),
        SizedBox(height: 14),
        Center(
          child: Text(
            'Belum ada pembayaran untuk event ini.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 45,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Gagal memuat pembayaran:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pembayaran Event'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return _buildEmpty();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return _buildPaymentCard(payments[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

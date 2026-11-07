
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';

class AdminEventOrdersPage extends StatefulWidget {
  final int eventId;

  const AdminEventOrdersPage({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventOrdersPage> createState() =>
      _AdminEventOrdersPageState();
}

class _AdminEventOrdersPageState
    extends State<AdminEventOrdersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadOrders();
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

  int? _getOrderEventId(Map<String, dynamic> order) {
    final directId = _toInt(
      order['event_id'] ?? order['eventId'],
    );

    if (directId != null) return directId;

    final event = order['event'];

    if (event is Map) {
      return _toInt(event['id'] ?? event['event_id']);
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    // Endpoint ini mendukung admin dan admin_event.
    // Backend membatasi admin_event hanya pada event miliknya.
    final orders = await ApiService.getAdminOrders();

    return orders.where((order) {
      return _getOrderEventId(order) == widget.eventId;
    }).toList();
  }

  Future<void> _refresh() async {
    final newFuture = _loadOrders();

    setState(() {
      _future = newFuture;
    });

    try {
      await newFuture;
    } catch (_) {
      // Error ditampilkan oleh FutureBuilder.
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
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Lunas';
      case 'success':
        return 'Berhasil';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      case 'failed':
        return 'Gagal';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'canceled':
      case 'expired':
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.grey;
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = _readValue(
      order,
      ['id', 'order_id'],
    );

    final customerName = _readValue(
      order,
      ['username', 'user_name', 'customer_name', 'name'],
      fallback: 'Pembeli',
    );

    final quantity = _readValue(
      order,
      ['quantity', 'ticket_quantity'],
    );

    final totalPrice = _readValue(
      order,
      ['total_price', 'total_amount', 'total', 'amount'],
    );

    final status = _readValue(
      order,
      ['status', 'order_status'],
      fallback: 'pending',
    );

    final ticketClass = order['ticket_class'];

    final ticketClassName = ticketClass is Map
        ? _readValue(
            ticketClass.cast<String, dynamic>(),
            ['name'],
          )
        : _readValue(
            order,
            ['ticket_class_name', 'class_name'],
          );

    final createdAt = _readValue(
      order,
      ['created_at', 'createdAt', 'order_date'],
    );

    final event = order['event'];

    final eventName = event is Map
        ? _readValue(
            event.cast<String, dynamic>(),
            ['name', 'title'],
          )
        : _readValue(
            order,
            ['event_title', 'event_name'],
            fallback: 'Event',
          );

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
                  Icons.receipt_long,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pesanan #$orderId',
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
            _detailRow('Pembeli', customerName),
            _detailRow('Event', eventName),
            _detailRow('Kelas Tiket', ticketClassName),
            _detailRow('Jumlah Tiket', quantity),
            _detailRow('Total Pembayaran', 'Rp $totalPrice'),
            _detailRow('Tanggal Pesanan', _formatDate(createdAt)),
          ],
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

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 150),
        Icon(
          Icons.receipt_long_outlined,
          color: Colors.white38,
          size: 55,
        ),
        SizedBox(height: 14),
        Center(
          child: Text(
            'Belum ada pesanan untuk event ini.',
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
            'Gagal memuat pesanan:\n$error',
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
        title: const Text('Pesanan Event'),
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

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return _buildEmpty();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(orders[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

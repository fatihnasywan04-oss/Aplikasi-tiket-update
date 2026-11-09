
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';

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

  int _getOrderEventId(Map<String, dynamic> order) {
    final directId = order['event_id'];

    if (directId != null) {
      return _toInt(directId);
    }

    final event = _readValue(order['event']);

    if (event['id'] != null) {
      return _toInt(event['id']);
    }

    final ticketClass = _readValue(order['ticket_class']);

    if (ticketClass['event_id'] != null) {
      return _toInt(ticketClass['event_id']);
    }

    return 0;
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final orders = await ApiService.getOrganizerOrders();

    return orders.where((order) {
      return _getOrderEventId(order) == widget.eventId;
    }).toList();
  }

  Future<void> _refresh() async {
    final future = _loadOrders();

    if (!mounted) return;

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (e) {
      debugPrint('Refresh orders error: $e');
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/admin-event',
        (route) => false,
      );
    }
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

  String _formatCurrency(dynamic value) {
    final amount = _toInt(value);

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'Rp $formatted';
  }

  String _orderStatus(Map<String, dynamic> order) {
    return (order['status'] ??
            order['order_status'] ??
            'pending')
        .toString()
        .toLowerCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Sudah Dibayar';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? order['order_id'] ?? '-';
    final status = _orderStatus(order);

    final quantity = order['quantity'] ?? 0;
    final totalPrice =
        order['total_price'] ?? order['amount'] ?? 0;

    final createdAt =
        order['created_at'] ?? order['order_date'];

    final user = _readValue(order['user']);
    final ticketClass = _readValue(order['ticket_class']);

    final userName = user['name'] ??
        order['user_name'] ??
        order['customer_name'] ??
        'Pelanggan';

    final ticketName = ticketClass['name'] ??
        order['ticket_class_name'] ??
        'Tiket';

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
                  'Pesanan #$orderId',
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
            Icons.person_outline,
            'Pelanggan',
            userName.toString(),
          ),
          _buildInfoRow(
            Icons.confirmation_number_outlined,
            'Kelas Tiket',
            ticketName.toString(),
          ),
          _buildInfoRow(
            Icons.shopping_bag_outlined,
            'Jumlah Tiket',
            quantity.toString(),
          ),
          _buildInfoRow(
            Icons.payments_outlined,
            'Total Pembayaran',
            _formatCurrency(totalPrice),
          ),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Tanggal Pesanan',
            _formatDate(createdAt),
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
          Icons.receipt_long_outlined,
          color: Colors.white38,
          size: 65,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada pesanan untuk event ini.',
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
          'Pesanan Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Buka menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
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
                      'Gagal memuat data pesanan.',
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

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _buildEmpty(),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Total ${orders.length} pesanan',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 15),
                ...orders.map(_buildOrderCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

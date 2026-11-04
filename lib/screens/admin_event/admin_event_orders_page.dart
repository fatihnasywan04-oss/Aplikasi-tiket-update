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
  State<AdminEventOrdersPage> createState() => _AdminEventOrdersPageState();
}

class _AdminEventOrdersPageState extends State<AdminEventOrdersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final orders = await ApiService.getOrganizerOrders();

    return orders.where((order) {
      final orderEventId = order['event_id'] ??
          (order['event'] is Map ? order['event']['id'] : null);

      return orderEventId?.toString() == widget.eventId.toString();
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadOrders());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pesanan Event'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Gagal memuat pesanan:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 150),
                  Center(
                    child: Text(
                      'Belum ada pesanan untuk event ini.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
                  color: AppTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long,
                      color: Colors.white70,
                    ),
                    title: Text(
                      'Pesanan #${order['id'] ?? '-'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Status: ${order['status'] ?? '-'}\n'
                      'Jumlah: ${order['quantity'] ?? '-'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      'Rp ${order['total_price'] ?? order['total_amount'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
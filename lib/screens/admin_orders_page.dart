import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_drawer.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  static const Color primary = Color(0xFF5B50E8);

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;
  String filter = 'Semua';

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ApiService.getAdminOrders();

      if (!mounted) return;

      setState(() {
        orders = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'paid':
        return 'Dibayar';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case 'completed':
        return 'Selesai';
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String money(dynamic value) {
    final number = (num.tryParse('$value') ?? 0).round();
    return 'Rp ${number.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  List<Map<String, dynamic>> get filteredOrders {
    if (filter == 'Semua') return orders;

    return orders.where((order) {
      final status = '${order['status'] ?? ''}'.toLowerCase();

      switch (filter) {
        case 'Menunggu':
          return status == 'pending';
        case 'Dibayar':
          return status == 'paid';
        case 'Dibatalkan':
          return status == 'cancelled' || status == 'canceled';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Manajemen Pesanan'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loading ? null : loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentPage: 'Pesanan'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [
                    'Semua',
                    'Menunggu',
                    'Dibayar',
                    'Dibatalkan',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: filter == item,
                        onSelected: (_) {
                          setState(() => filter = item);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: loadOrders,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = filteredOrders;

                if (data.isEmpty) {
                  return const Center(child: Text('Belum ada pesanan.'));
                }

                return RefreshIndicator(
                  onRefresh: loadOrders,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final order = data[index];
                      final status = '${order['status'] ?? 'unknown'}';

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: primary.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.confirmation_number,
                              color: primary,
                            ),
                          ),
                          title: Text(
                            '${order['event_title'] ?? order['event_name'] ?? 'Event'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pesanan #${order['id'] ?? '-'}'),
                                Text('User ID: ${order['user_id'] ?? '-'}'),
                                Text('Jumlah tiket: ${order['quantity'] ?? 0}'),
                                Text(
                                  money(order['total_price']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor(status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusLabel(status),
                                    style: TextStyle(
                                      color: statusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

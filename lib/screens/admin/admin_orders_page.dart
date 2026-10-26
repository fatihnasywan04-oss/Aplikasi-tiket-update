
import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'admin_drawer_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getAdminOrders();
      if (!mounted) return;
      setState(() => _orders = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _value(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      if (item[key] != null) return item[key].toString();
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Data Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AdminDrawerPage(currentRoute: '/admin/orders'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Gagal memuat pesanan. Coba lagi'),
                  ),
                )
              : _orders.isEmpty
                  ? const Center(child: Text('Belum ada pesanan.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = Map<String, dynamic>.from(
                            _orders[index] as Map,
                          );

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFFEAE8FF),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          color: Color(0xFF5B50E8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _value(
                                            order,
                                            [
                                              'event_title',
                                              'event_name',
                                              'title',
                                            ],
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Pesanan #${_value(order, ['id', 'order_id'])}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pengguna: ${_value(order, ['username', 'user_name', 'customer_name'])}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Jumlah tiket: ${_value(order, ['quantity', 'ticket_quantity'])}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Total: Rp ${_value(order, ['total_price', 'total', 'amount'])}',
                                    style: const TextStyle(
                                      color: Color(0xFF5B50E8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Chip(
                                    label: Text(
                                      _value(
                                        order,
                                        ['status', 'order_status'],
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFEAE8FF),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF5B50E8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

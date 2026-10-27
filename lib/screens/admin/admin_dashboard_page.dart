
import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'admin_drawer_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  int _eventCount = 0;
  int _orderCount = 0;
  int _paymentCount = 0;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getEvents(),
        ApiService.getAdminOrders(),
        ApiService.getAdminPayments(),
      ]);

      List<dynamic> asList(dynamic result) {
        if (result is List) return result;
        if (result is Map && result['items'] is List) {
          return result['items'] as List;
        }
        if (result is Map && result['orders'] is List) {
          return result['orders'] as List;
        }
        if (result is Map && result['payments'] is List) {
          return result['payments'] as List;
        }
        if (result is Map && result['events'] is List) {
          return result['events'] as List;
        }
        return [];
      }

      final events = asList(results[0]);
      final orders = asList(results[1]);
      final payments = asList(results[2]);

      if (!mounted) return;

      setState(() {
        _eventCount = events.length;
        _orderCount = orders.length;
        _paymentCount = payments.length;
        _orders = orders
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .take(5)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AdminDrawerPage(currentRoute: '/admin'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Dashboard gagal dimuat.'),
                      TextButton(
                        onPressed: _loadDashboard,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF5B50E8),
                              Color(0xFF9187FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selamat datang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Pantau event, pesanan, dan pembayaran dari satu tempat.',
                              style: TextStyle(
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Ringkasan',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _stat(
                            'Total Event',
                            '$_eventCount',
                            Icons.event_outlined,
                          ),
                          _stat(
                            'Total Pesanan',
                            '$_orderCount',
                            Icons.receipt_long_outlined,
                          ),
                          _stat(
                            'Pembayaran',
                            '$_paymentCount',
                            Icons.payments_outlined,
                          ),
                          _stat(
                            'Status',
                            'Aktif',
                            Icons.verified_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Pesanan terbaru',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_orders.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Belum ada data pesanan.'),
                          ),
                        )
                      else
                        ..._orders.map((order) {
                          final id = order['id'] ?? order['order_id'] ?? '-';
                          final status =
                              order['status'] ?? order['order_status'] ?? '-';
                          final event = order['event_title'] ??
                              order['event_name'] ??
                              order['title'] ??
                              'Pesanan';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAE8FF),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFF5B50E8),
                                ),
                              ),
                              title: Text(
                                event.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('Pesanan #$id'),
                              trailing: Text(
                                status.toString(),
                                style: const TextStyle(
                                  color: Color(0xFF5B50E8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _stat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFF5B50E8), size: 28),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF282738),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF77778A),
            ),
          ),
        ],
      ),
    );
  }
}

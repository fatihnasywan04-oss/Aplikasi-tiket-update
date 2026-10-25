
import 'package:flutter/material.dart';

import '../api_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const Color primary = Color(0xFF5B50E8);
  int selectedIndex = 0;
  bool loading = true;
  String? error;

  Map<String, dynamic> dashboard = {};
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> payments = [];

  final titles = const [
    'Dashboard Admin',
    'Kelola Event',
    'Kelola Pesanan',
    'Kelola Pembayaran',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String money(dynamic value) {
    final amount = double.tryParse('$value') ?? 0;
    final digits = amount.round().toString();
    return 'Rp ${digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    )}';
  }

  String display(dynamic value, [String fallback = '-']) {
    if (value == null || '$value'.trim().isEmpty) return fallback;
    return '$value';
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAdminDashboard(),
        ApiService.getEvents(),
        ApiService.getAdminOrders(),
        ApiService.getAdminPayments(),
      ]);

      if (!mounted) return;

      setState(() {
        dashboard = results[0] as Map<String, dynamic>;
        events = results[1] as List<Map<String, dynamic>>;
        orders = results[2] as List<Map<String, dynamic>>;
        payments = results[3] as List<Map<String, dynamic>>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget statCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE8F5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primary, size: 28),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ringkasan Event Ticketers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pantau aktivitas event dan transaksi.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: [
            statCard(
              'Total Event',
              '${dashboard['total_events'] ?? 0}',
              Icons.event,
            ),
            statCard(
              'Total Pesanan',
              '${dashboard['total_orders'] ?? 0}',
              Icons.confirmation_number,
            ),
            statCard(
              'Tiket Terjual',
              '${dashboard['tickets_sold'] ?? 0}',
              Icons.local_activity,
            ),
            statCard(
              'Pendapatan',
              money(dashboard['revenue']),
              Icons.account_balance_wallet,
            ),
            statCard(
              'Pesanan Dibayar',
              '${dashboard['paid_orders'] ?? 0}',
              Icons.check_circle_outline,
            ),
            statCard(
              'Pembayaran Pending',
              '${dashboard['pending_payments'] ?? 0}',
              Icons.hourglass_empty,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: primary),
            title: const Text('Total Transaksi Pembayaran'),
            trailing: Text(
              '${dashboard['total_payments'] ?? 0}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget eventsView() {
    if (events.isEmpty) {
      return const Center(child: Text('Belum ada event.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEEBFF),
              child: Icon(Icons.event, color: primary),
            ),
            title: Text(
              display(event['title'], 'Event tanpa nama'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${display(event['location'])}\n'
              '${money(event['price'])} • '
              'Tiket tersedia: ${display(event['available_tickets'], '0')}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(display(event['title'])),
                  content: Text(
                    'ID event: ${display(event['id'])}\n'
                    'Lokasi: ${display(event['location'])}\n'
                    'Harga: ${money(event['price'])}\n'
                    'Stok: ${display(event['available_tickets'], '0')}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget ordersView() {
    if (orders.isEmpty) {
      return const Center(child: Text('Belum ada pesanan.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEEBFF),
              child: Icon(Icons.receipt_long, color: primary),
            ),
            title: Text(
              display(order['event_title'], 'Nama event tidak tersedia'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Pesanan #${display(order['id'])}\n'
              'Pemesan: ${display(order['customer_name'])}\n'
              'Jumlah tiket: ${display(order['quantity'], '0')}\n'
              'Total: ${money(order['total_price'])}',
            ),
            isThreeLine: true,
            trailing: statusChip(display(order['status'])),
          ),
        );
      },
    );
  }

  Widget paymentsView() {
    if (payments.isEmpty) {
      return const Center(child: Text('Belum ada pembayaran.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEEBFF),
              child: Icon(Icons.wallet, color: primary),
            ),
            title: Text(
              display(payment['event_title'], 'Nama event tidak tersedia'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Pembayaran #${display(payment['id'])}\n'
              'Pemesan: ${display(payment['customer_name'])}\n'
              'Metode: ${display(payment['payment_method'])}\n'
              'Nominal: ${money(payment['amount'])}',
            ),
            isThreeLine: true,
            trailing: statusChip(
              display(payment['payment_status']),
            ),
          ),
        );
      },
    );
  }

  Widget statusChip(String value) {
    final success = value.toLowerCase() == 'paid' ||
        value.toLowerCase() == 'success' ||
        value.toLowerCase() == 'completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: success ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: success ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget currentPage() {
    switch (selectedIndex) {
      case 1:
        return eventsView();
      case 2:
        return ordersView();
      case 3:
        return paymentsView();
      default:
        return dashboardView();
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Text(titles[selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: loadData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Event',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Pembayaran',
          ),
        ],
      ),
    );
  }
}

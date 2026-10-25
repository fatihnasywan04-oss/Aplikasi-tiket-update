import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_drawer.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const Color primary = Color(0xFF5B50E8);
  static const Color background = Color(0xFFF7F7FC);

  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> events = [];

  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAdminOrders(),
        ApiService.getAdminPayments(),
        ApiService.getEvents(),
      ]);

      if (!mounted) return;

      setState(() {
        orders = results[0];
        payments = results[1];
        events = results[2];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  String money(dynamic value) {
    final amount = (num.tryParse('$value') ?? 0).round();

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $formatted';
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'paid':
      case 'success':
        return 'Berhasil';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case 'failed':
        return 'Gagal';
      default:
        return status.isEmpty ? 'Tidak diketahui' : status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'success':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'canceled':
      case 'failed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String orderTitle(Map<String, dynamic> order) {
    return '${order['event_title'] ?? order['event_name'] ?? 'Event'}';
  }

  int ticketQuantity(Map<String, dynamic> order) {
    return int.tryParse('${order['quantity'] ?? 0}') ?? 0;
  }

  String paymentStatus(Map<String, dynamic> payment) {
    return '${payment['payment_status'] ?? 'unknown'}'.toLowerCase();
  }

  String orderStatus(Map<String, dynamic> order) {
    return '${order['status'] ?? 'unknown'}'.toLowerCase();
  }

  num paymentAmount(Map<String, dynamic> payment) {
    return num.tryParse('${payment['amount'] ?? 0}') ?? 0;
  }

  num orderAmount(Map<String, dynamic> order) {
    return num.tryParse('${order['total_price'] ?? 0}') ?? 0;
  }

  // Mengutamakan pembayaran sukses agar pendapatan tidak
  // dihitung dari pembayaran yang masih pending atau gagal.
  num get totalRevenue {
    final successfulPayments = payments.where((payment) {
      final status = paymentStatus(payment);
      return status == 'success' || status == 'paid';
    });

    if (payments.isNotEmpty) {
      return successfulPayments.fold<num>(
        0,
        (sum, payment) => sum + paymentAmount(payment),
      );
    }

    return orders
        .where((order) {
          final status = orderStatus(order);
          return status == 'paid' || status == 'completed';
        })
        .fold<num>(0, (sum, order) => sum + orderAmount(order));
  }

  int get successfulOrders {
    return orders.where((order) {
      final status = orderStatus(order);
      return status == 'paid' || status == 'completed';
    }).length;
  }

  int get pendingOrders {
    return orders.where((order) {
      return orderStatus(order) == 'pending';
    }).length;
  }

  int get cancelledOrders {
    return orders.where((order) {
      final status = orderStatus(order);
      return status == 'cancelled' || status == 'canceled';
    }).length;
  }

  int get totalTicketsOrdered {
    return orders.fold<int>(0, (sum, order) => sum + ticketQuantity(order));
  }

  List<Map<String, dynamic>> get recentOrders {
    final copy = List<Map<String, dynamic>>.from(orders);

    copy.sort((a, b) {
      final aId = int.tryParse('${a['id'] ?? 0}') ?? 0;
      final bId = int.tryParse('${b['id'] ?? 0}') ?? 0;
      return bId.compareTo(aId);
    });

    return copy.take(5).toList();
  }

  List<MapEntry<String, int>> get popularEvents {
    final counts = <String, int>{};

    for (final order in orders) {
      final title = orderTitle(order);
      counts[title] = (counts[title] ?? 0) + ticketQuantity(order);
    }

    final result = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return result.take(5).toList();
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...?trailing == null ? null : [trailing],
        ],
      ),
    );
  }

  Widget statusRow(String title, int count, Color color) {
    final total = orders.length;
    final fraction = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDashboard() {
    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B50E8), Color(0xFF8278F5)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.analytics_outlined, color: Colors.white, size: 36),
                SizedBox(height: 14),
                Text(
                  'Dashboard Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pantau pemesanan tiket, pendapatan, dan aktivitas event.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.22,
            children: [
              statCard(
                title: 'Total Pesanan',
                value: '${orders.length}',
                icon: Icons.shopping_bag_outlined,
                color: primary,
              ),
              statCard(
                title: 'Pendapatan',
                value: money(totalRevenue),
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.green,
              ),
              statCard(
                title: 'Pesanan Berhasil',
                value: '$successfulOrders',
                icon: Icons.check_circle_outline,
                color: Colors.teal,
              ),
              statCard(
                title: 'Menunggu',
                value: '$pendingOrders',
                icon: Icons.hourglass_top,
                color: Colors.orange,
              ),
              statCard(
                title: 'Tiket Dipesan',
                value: '$totalTicketsOrdered',
                icon: Icons.confirmation_number_outlined,
                color: Colors.indigo,
              ),
              statCard(
                title: 'Total Event',
                value: '${events.length}',
                icon: Icons.event_outlined,
                color: Colors.pink,
              ),
            ],
          ),

          const SizedBox(height: 24),

          sectionTitle('Status Pemesanan'),

          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  statusRow('Berhasil dibayar', successfulOrders, Colors.green),
                  statusRow(
                    'Menunggu pembayaran',
                    pendingOrders,
                    Colors.orange,
                  ),
                  statusRow('Dibatalkan', cancelledOrders, Colors.red),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          sectionTitle('Event Terpopuler'),

          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: popularEvents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Belum ada data pemesanan event.'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < popularEvents.length; i++)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primary.withValues(alpha: 0.10),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(popularEvents[i].key),
                          subtitle: Text(
                            '${popularEvents[i].value} tiket dipesan',
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          sectionTitle('Pesanan Terbaru'),

          if (recentOrders.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada pesanan.'),
              ),
            )
          else
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final order in recentOrders)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEEECFF),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          color: primary,
                        ),
                      ),
                      title: Text(orderTitle(order)),
                      subtitle: Text(
                        'Pesanan #${order['id'] ?? '-'}'
                        ' • ${ticketQuantity(order)} tiket'
                        '\n${money(order['total_price'])}',
                      ),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor(orderStatus(order))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel(orderStatus(order)),
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor(orderStatus(order)),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Event Ticketers • Admin',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang statistik',
            onPressed: loading ? null : loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentPage: 'Dashboard'),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dashboard gagal dimuat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: loadDashboard,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : buildDashboard(),
    );
  }
}

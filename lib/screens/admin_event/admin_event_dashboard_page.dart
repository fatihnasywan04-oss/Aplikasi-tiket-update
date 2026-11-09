import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';

class AdminEventDashboardPage extends StatefulWidget {
  const AdminEventDashboardPage({super.key});

  @override
  State<AdminEventDashboardPage> createState() =>
      _AdminEventDashboardPageState();
}

class _AdminEventDashboardPageState
    extends State<AdminEventDashboardPage> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final results = await Future.wait([
      ApiService.getMyEvents(),
      ApiService.getOrganizerOrders(),
      ApiService.getOrganizerPayments(),
    ]);

    final events = results[0];
    final orders = results[1];
    final payments = results[2];

    int pendingEvents = 0;
    int approvedEvents = 0;
    int rejectedEvents = 0;

    for (final event in events) {
      final status = (event['approval_status'] ??
              event['status'] ??
              'pending')
          .toString()
          .toLowerCase();

      if (status == 'approved') {
        approvedEvents++;
      } else if (status == 'rejected') {
        rejectedEvents++;
      } else {
        pendingEvents++;
      }
    }

    int paidOrders = 0;
    int pendingOrders = 0;
    int cancelledOrders = 0;

    for (final order in orders) {
      final status = (order['status'] ??
              order['order_status'] ??
              '')
          .toString()
          .toLowerCase();

      if (status == 'paid' || status == 'success') {
        paidOrders++;
      } else if (status == 'pending') {
        pendingOrders++;
      } else if (status == 'cancelled' ||
          status == 'canceled') {
        cancelledOrders++;
      }
    }

    int successfulPayments = 0;
    int pendingPayments = 0;
    int failedPayments = 0;

    for (final payment in payments) {
      final status = (payment['status'] ??
              payment['payment_status'] ??
              '')
          .toString()
          .toLowerCase();

      if (status == 'success' || status == 'paid') {
        successfulPayments++;
      } else if (status == 'pending') {
        pendingPayments++;
      } else if (status == 'failed' ||
          status == 'cancelled' ||
          status == 'canceled') {
        failedPayments++;
      }
    }

    return {
      'total_events': events.length,
      'pending_events': pendingEvents,
      'approved_events': approvedEvents,
      'rejected_events': rejectedEvents,
      'total_orders': orders.length,
      'paid_orders': paidOrders,
      'pending_orders': pendingOrders,
      'cancelled_orders': cancelledOrders,
      'total_payments': payments.length,
      'successful_payments': successfulPayments,
      'pending_payments': pendingPayments,
      'failed_payments': failedPayments,
    };
  }

  Future<void> _refresh() async {
    final future = _loadDashboard();

    setState(() {
      _dashboardFuture = future;
    });

    try {
      await future;
    } catch (error) {
      debugPrint('[AdminEventDashboard] Refresh gagal: $error');
    }
  }

  int _readNumber(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];

    if (value is num) return value.toInt();

    if (value != null) {
      return int.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }

  Widget _buildMetric({
    required String title,
    required int value,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String title,
    required int value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> data) {
    final totalEvents = _readNumber(data, 'total_events');
    final pendingEvents = _readNumber(data, 'pending_events');
    final approvedEvents = _readNumber(data, 'approved_events');
    final rejectedEvents = _readNumber(data, 'rejected_events');

    final totalOrders = _readNumber(data, 'total_orders');
    final paidOrders = _readNumber(data, 'paid_orders');
    final pendingOrders = _readNumber(data, 'pending_orders');
    final cancelledOrders = _readNumber(data, 'cancelled_orders');

    final totalPayments = _readNumber(data, 'total_payments');
    final successfulPayments =
        _readNumber(data, 'successful_payments');
    final pendingPayments =
        _readNumber(data, 'pending_payments');
    final failedPayments =
        _readNumber(data, 'failed_payments');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.28),
                  AppTheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HIKARI ORGANIZER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Dashboard Admin Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kelola event milikmu, pantau pesanan, '
                  'dan lihat aktivitas pembayaran.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Ringkasan Aktivitas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          _buildMetric(
            title: 'Total Event',
            value: totalEvents,
            icon: Icons.event,
            subtitle: 'Semua status pengajuan',
          ),

          const SizedBox(height: 12),

          _buildMetric(
            title: 'Total Pesanan',
            value: totalOrders,
            icon: Icons.confirmation_number_outlined,
          ),

          const SizedBox(height: 12),

          _buildMetric(
            title: 'Total Pembayaran',
            value: totalPayments,
            icon: Icons.payments_outlined,
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Pengajuan Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  title: 'Menunggu persetujuan',
                  value: pendingEvents,
                  color: Colors.orange,
                ),
                _buildStatusRow(
                  title: 'Disetujui',
                  value: approvedEvents,
                  color: Colors.green,
                ),
                _buildStatusRow(
                  title: 'Ditolak',
                  value: rejectedEvents,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Pesanan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  title: 'Sudah dibayar',
                  value: paidOrders,
                  color: Colors.green,
                ),
                _buildStatusRow(
                  title: 'Menunggu pembayaran',
                  value: pendingOrders,
                  color: Colors.orange,
                ),
                _buildStatusRow(
                  title: 'Dibatalkan',
                  value: cancelledOrders,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Pembayaran',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  title: 'Berhasil',
                  value: successfulPayments,
                  color: Colors.green,
                ),
                _buildStatusRow(
                  title: 'Menunggu',
                  value: pendingPayments,
                  color: Colors.orange,
                ),
                _buildStatusRow(
                  title: 'Gagal / dibatalkan',
                  value: failedPayments,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Event baru dari Admin Event harus menunggu '
                    'persetujuan Super Admin. Perubahan data event '
                    'dan kelas tiket juga diajukan untuk ditinjau. '
                    'Pastikan kamu memeriksa status pengajuan '
                    'secara berkala.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang dashboard'),
          ),

          const SizedBox(height: 20),
        ],
      ),
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
          'Hikari Organizer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
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
                      Icons.cloud_off_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dashboard belum dapat dimuat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
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
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildDashboard(snapshot.data ?? {});
        },
      ),
    );
  }
}
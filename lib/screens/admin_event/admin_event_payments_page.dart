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

  Future<List<Map<String, dynamic>>> _loadPayments() async {
    final payments = await ApiService.getOrganizerPayments();

    return payments.where((payment) {
      final order = payment['order'];

      final eventId = payment['event_id'] ??
          (order is Map
              ? order['event_id'] ??
                  (order['event'] is Map ? order['event']['id'] : null)
              : null);

      return eventId?.toString() == widget.eventId.toString();
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadPayments());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pembayaran Event'),
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
                      'Gagal memuat pembayaran:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 150),
                  Center(
                    child: Text(
                      'Belum ada pembayaran untuk event ini.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];

                return Card(
                  color: AppTheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.payments,
                      color: Colors.white70,
                    ),
                    title: Text(
                      'Pembayaran #${payment['id'] ?? '-'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Status: ${payment['status'] ?? '-'}\n'
                      'Order ID: ${payment['order_id'] ?? '-'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      'Rp ${payment['amount'] ?? '-'}',
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
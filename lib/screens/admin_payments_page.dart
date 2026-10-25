import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_drawer.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  static const Color primary = Color(0xFF5B50E8);

  List<Map<String, dynamic>> payments = [];
  bool loading = true;
  String? error;
  String filter = 'Semua';

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  Future<void> loadPayments() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ApiService.getAdminPayments();

      if (!mounted) return;

      setState(() {
        payments = result;
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

  String methodLabel(dynamic raw) {
    switch ('${raw ?? ''}'.toLowerCase()) {
      case 'transfer_bank':
        return 'Transfer Bank';
      case 'e_wallet':
        return 'E-Wallet';
      case 'qris':
        return 'QRIS';
      default:
        return '${raw ?? 'Tidak diketahui'}';
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'success':
      case 'paid':
        return 'Berhasil';
      case 'failed':
        return 'Gagal';
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String money(dynamic value) {
    final number = (num.tryParse('$value') ?? 0).round();
    return 'Rp ${number.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
  }

  List<Map<String, dynamic>> get filteredPayments {
    if (filter == 'Semua') return payments;

    return payments.where((payment) {
      final status = '${payment['payment_status'] ?? ''}'.toLowerCase();

      switch (filter) {
        case 'Berhasil':
          return status == 'success' || status == 'paid';
        case 'Menunggu':
          return status == 'pending';
        case 'Gagal':
          return status == 'failed';
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
        title: const Text('Manajemen Pembayaran'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loading ? null : loadPayments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentPage: 'Pembayaran'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in ['Semua', 'Berhasil', 'Menunggu', 'Gagal'])
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
                            onPressed: loadPayments,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = filteredPayments;

                if (data.isEmpty) {
                  return const Center(
                    child: Text('Belum ada data pembayaran.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: loadPayments,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final payment = data[index];
                      final status =
                          '${payment['payment_status'] ?? 'unknown'}';

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pembayaran #${payment['id'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
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
                              const Divider(height: 24),
                              _info(
                                'ID pesanan',
                                '${payment['order_id'] ?? '-'}',
                              ),
                              _info(
                                'Metode',
                                methodLabel(payment['payment_method']),
                              ),
                              _info('Nominal', money(payment['amount'])),
                              _info(
                                'ID transaksi',
                                '${payment['transaction_id'] ?? 'Belum tersedia'}',
                              ),
                              _info(
                                'Waktu pembayaran',
                                '${payment['paid_at'] ?? 'Belum tersedia'}',
                              ),
                            ],
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

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

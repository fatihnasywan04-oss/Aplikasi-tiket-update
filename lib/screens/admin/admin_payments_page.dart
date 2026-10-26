
import 'package:flutter/material.dart';

import '../../api_service.dart';
import 'admin_drawer_page.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _payments = [];

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
      final result = await ApiService.getAdminPayments();
      if (!mounted) return;
      setState(() => _payments = result);
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
          'Data Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AdminDrawerPage(currentRoute: '/admin/payments'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Gagal memuat pembayaran. Coba lagi'),
                  ),
                )
              : _payments.isEmpty
                  ? const Center(child: Text('Belum ada pembayaran.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _payments.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final payment = Map<String, dynamic>.from(
                            _payments[index] as Map,
                          );

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAE8FF),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                        ),
                                        child: const Icon(
                                          Icons.payments_outlined,
                                          color: Color(0xFF5B50E8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Pembayaran #${_value(payment, ['id', 'payment_id'])}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Pesanan: #${_value(payment, ['order_id'])}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Metode: ${_value(payment, ['method', 'payment_method', 'method_name'])}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Jumlah: Rp ${_value(payment, ['amount', 'total', 'total_amount'])}',
                                    style: const TextStyle(
                                      color: Color(0xFF5B50E8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Chip(
                                    label: Text(
                                      _value(
                                        payment,
                                        ['status', 'payment_status'],
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

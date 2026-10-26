import 'package:flutter/material.dart';

import '../api_service.dart';
import 'order_detail_page.dart';
import 'payment_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  static const Color primary = Color(0xFF5B50E8);

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;

  final Set<int> processingOrders = {};

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  int intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  double numberValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  dynamic pick(
    Map<String, dynamic> item,
    List<String> keys, {
    dynamic fallback,
  }) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String readableError(Object e) {
    return e.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
  }

  Future<void> loadOrders() async {
    if (loading && orders.isNotEmpty) return;

    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result = await ApiService.getMyOrders();

      if (!mounted) return;

      setState(() {
        orders = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = readableError(e);
        loading = false;
      });
    }
  }

  String titleOf(Map<String, dynamic> item) {
    final name = pick(item, ['event_title', 'event_name', 'title']);

    if (name != null) return name.toString();

    final event = item['event'];
    if (event is Map) {
      return (event['title'] ?? event['name'] ?? 'Event').toString();
    }

    return 'Event #${item['event_id'] ?? '-'}';
  }

  String money(dynamic value) {
    final digits = numberValue(value).round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $formatted';
  }

  String dateText(dynamic value) {
    if (value == null) return '-';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      String two(int n) => n.toString().padLeft(2, '0');

      return '${two(date.day)}/${two(date.month)}/${date.year} '
          '${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return value.toString();
    }
  }

  String statusOf(Map<String, dynamic> item) {
    return '${pick(
      item,
      ['status', 'order_status'],
      fallback: 'pending',
    )}'.toLowerCase().trim();
  }

  String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Sudah Dibayar';
      case 'success':
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
    switch (status) {
      case 'pending':
        return Colors.orange.shade800;
      case 'paid':
      case 'success':
      case 'completed':
        return Colors.green.shade700;
      case 'failed':
      case 'cancelled':
      case 'canceled':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> openDetail(Map<String, dynamic> item) async {
    final id = intValue(item['id'] ?? item['order_id']);

    if (id <= 0) {
      showMessage('ID pesanan tidak valid.');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(orderId: id),
      ),
    );

    if (mounted) await loadOrders();
  }

  Future<void> openPayment(Map<String, dynamic> item) async {
    final id = intValue(item['id'] ?? item['order_id']);

    if (id <= 0) {
      showMessage('ID pesanan tidak valid.');
      return;
    }

    if (statusOf(item) != 'pending') {
      showMessage('Hanya pesanan yang menunggu pembayaran yang dapat dibayar.');
      await loadOrders();
      return;
    }

    if (processingOrders.contains(id)) return;

    setState(() => processingOrders.add(id));

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: id,
            totalPrice: numberValue(
              pick(
                item,
                ['total_price', 'total_amount', 'total', 'amount'],
                fallback: 0,
              ),
            ),
            eventTitle: titleOf(item),
            quantity: intValue(
              pick(
                item,
                ['quantity', 'ticket_quantity'],
                fallback: 1,
              ),
            ),
          ),
        ),
      );

      if (!mounted) return;

      await loadOrders();

      if (result == true && mounted) {
        showMessage('Pembayaran dikonfirmasi. Riwayat telah diperbarui.');
      }
    } catch (e) {
      if (mounted) showMessage(readableError(e));
    } finally {
      if (mounted) {
        setState(() => processingOrders.remove(id));
      }
    }
  }

  Future<void> cancelOrder(Map<String, dynamic> item) async {
    final id = intValue(item['id'] ?? item['order_id']);

    if (id <= 0) {
      showMessage('ID pesanan tidak valid.');
      return;
    }

    if (statusOf(item) != 'pending') {
      showMessage('Hanya pesanan pending yang dapat dibatalkan.');
      await loadOrders();
      return;
    }

    if (processingOrders.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: Text(
          'Pesanan "${titleOf(item)}" akan dibatalkan. '
          'Pesanan yang dibatalkan tidak dapat dibayar lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => processingOrders.add(id));

    try {
      await ApiService.cancelOrder(id);

      if (!mounted) return;

      showMessage('Pesanan berhasil dibatalkan.');
      await loadOrders();
    } catch (e) {
      if (!mounted) return;

      showMessage(readableError(e));
      await loadOrders();
    } finally {
      if (mounted) {
        setState(() => processingOrders.remove(id));
      }
    }
  }

  Widget detailRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget orderCard(Map<String, dynamic> item) {
    final id = intValue(item['id'] ?? item['order_id']);
    final quantity = intValue(
      pick(item, ['quantity', 'ticket_quantity'], fallback: 0),
    );
    final total = pick(
      item,
      ['total_price', 'total_amount', 'total', 'amount'],
      fallback: 0,
    );
    final date = pick(item, ['created_at', 'order_date']);
    final status = statusOf(item);
    final canPay = status == 'pending';
    final isProcessing = processingOrders.contains(id);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEDEBFF),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleOf(item),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #$id',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor(status).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel(status),
                  style: TextStyle(
                    color: statusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            detailRow('Jumlah tiket', '$quantity tiket'),
            detailRow('Tanggal', dateText(date)),
            detailRow('Total', money(total), bold: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : () => openDetail(item),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Detail'),
              ),
            ),
            if (canPay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isProcessing ? null : () => openPayment(item),
                      icon: const Icon(Icons.payment),
                      label: const Text('Bayar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : () => cancelOrder(item),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text(
                        isProcessing ? 'Memproses' : 'Batalkan',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loading ? null : loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (loading && orders.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: primary),
              );
            }

            if (error != null && orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Riwayat pesanan gagal dimuat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: loadOrders,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (orders.isEmpty) {
              return RefreshIndicator(
                onRefresh: loadOrders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 140),
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 70,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Belum ada riwayat pesanan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tarik layar ke bawah untuk memuat ulang.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: loadOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Total ${orders.length} pesanan',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Pembaruan gagal: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ...orders.map(orderCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
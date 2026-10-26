import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_service.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;

  const OrderDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  static const Color primary = Color(0xFF5B50E8);

  Map<String, dynamic>? order;
  bool loading = true;
  String? error;

  final DateFormat dateFormatter =
      DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  Future<void> loadDetail() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ApiService.getOrderDetail(widget.orderId);

      if (!mounted) return;

      setState(() {
        order = Map<String, dynamic>.from(result);
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

  dynamic value(List<String> keys, {dynamic fallback}) {
    for (final key in keys) {
      final result = order?[key];

      if (result != null && result.toString().trim().isNotEmpty) {
        return result;
      }
    }

    return fallback;
  }

  Map<String, dynamic>? get payment {
    final direct = order?['payment'];

    if (direct is Map) {
      return Map<String, dynamic>.from(direct);
    }

    final payments = order?['payments'];

    if (payments is List && payments.isNotEmpty) {
      final validPayments = payments.whereType<Map>().toList();

      if (validPayments.isEmpty) return null;

      // Utamakan pembayaran yang sudah berhasil.
      for (final item in validPayments) {
        final paymentStatus =
            '${item['payment_status'] ?? ''}'.toLowerCase();

        if (paymentStatus == 'success' ||
            paymentStatus == 'paid' ||
            paymentStatus == 'completed') {
          return Map<String, dynamic>.from(item);
        }
      }

      return Map<String, dynamic>.from(validPayments.first);
    }

    // Mendukung respons API yang meletakkan field pembayaran
    // langsung pada objek pesanan.
    if (order?['payment_method'] != null ||
        order?['transaction_id'] != null ||
        order?['paid_at'] != null ||
        order?['payment_status'] != null) {
      return order;
    }

    return null;
  }

  dynamic paymentValue(
    List<String> keys, {
    dynamic fallback,
  }) {
    final data = payment;

    for (final key in keys) {
      final result = data?[key];

      if (result != null && result.toString().trim().isNotEmpty) {
        return result;
      }
    }

    return fallback;
  }

  String eventName() {
    final direct = value(['event_title', 'event_name', 'title']);

    if (direct != null) return direct.toString();

    final event = order?['event'];

    if (event is Map) {
      return (event['title'] ?? event['name'] ?? 'Event').toString();
    }

    return 'Event #${value(['event_id'], fallback: '-')}';
  }

  String money(dynamic amount) {
    final number = num.tryParse('$amount') ?? 0;
    final digits = number.round().toString();

    return 'Rp ${digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )}';
  }

  String dateText(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) {
      return 'Belum tersedia';
    }

    try {
      final parsed = DateTime.parse(raw.toString());

      // Backend menyimpan timestamp UTC. Konversi ke zona lokal
      // perangkat agar tanggal mengikuti waktu pengguna.
      return dateFormatter.format(parsed.toLocal());
    } catch (_) {
      return raw.toString();
    }
  }

  String methodLabel(dynamic raw) {
    final method = '${raw ?? ''}'.toLowerCase().trim();

    switch (method) {
      case 'transfer_bank':
        return 'Transfer Bank';
      case 'e_wallet':
        return 'E-Wallet';
      case 'qris':
        return 'QRIS';
      case '':
      case 'null':
        return 'Belum tersedia';
      default:
        return raw.toString();
    }
  }

  String orderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Sudah Dibayar';
      case 'success':
        return 'Pembayaran Berhasil';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case 'failed':
        return 'Gagal';
      default:
        return status.isEmpty ? 'Belum tersedia' : status;
    }
  }

  String paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'success':
      case 'paid':
      case 'completed':
        return 'Berhasil';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      case '':
      case 'null':
        return 'Belum Ada Pembayaran';
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade800;
      case 'paid':
      case 'success':
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
      case 'canceled':
      case 'failed':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Widget section(String title, List<Widget> rows) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 28),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget rowInfo(
    String label,
    String text, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
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

  Widget buildDetail() {
    final status = '${value(['status'], fallback: 'pending')}';

    final id = value(
      ['id', 'order_id'],
      fallback: widget.orderId,
    );

    final eventId = value(['event_id'], fallback: '-');
    final quantity = value(
      ['quantity', 'ticket_quantity'],
      fallback: 0,
    );

    final total = value(
      ['total_price', 'total_amount', 'total', 'amount'],
      fallback: 0,
    );

    final createdAt = value(['created_at', 'order_date']);

    final rawPaymentStatus =
        paymentValue(['payment_status'], fallback: '');

    final normalizedPaymentStatus =
        '$rawPaymentStatus'.toLowerCase();

    final isPaid = normalizedPaymentStatus == 'success' ||
        normalizedPaymentStatus == 'paid' ||
        normalizedPaymentStatus == 'completed';

    final hasPayment = payment != null;

    final method = methodLabel(
      paymentValue(['payment_method']),
    );

    final transactionId = paymentValue(
      ['transaction_id'],
      fallback: 'Belum tersedia',
    );

    final paidAt = paymentValue(['paid_at']);

    final displayPaymentStatus = hasPayment
        ? paymentStatusLabel('$rawPaymentStatus')
        : 'Belum Ada Pembayaran';

    return RefreshIndicator(
      onRefresh: loadDetail,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #$id',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Chip(
                  label: Text(
                    orderStatusLabel(status),
                    style: TextStyle(
                      color: statusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),

          section('Informasi Event', [
            rowInfo('Nama event', eventName()),
            rowInfo('ID event', '$eventId'),
          ]),

          section('Informasi Pesanan', [
            rowInfo('ID pesanan', '#$id'),
            rowInfo('Jumlah tiket', '$quantity tiket'),
            rowInfo('Tanggal pemesanan', dateText(createdAt)),
            rowInfo('Total pembayaran', money(total), bold: true),
          ]),

          section('Informasi Pembayaran', [
            rowInfo('Metode pembayaran', method),
            rowInfo(
              'Status pembayaran',
              displayPaymentStatus,
            ),
            rowInfo('ID transaksi', '$transactionId'),
            rowInfo(
              'Tanggal & waktu pembayaran',
              isPaid && paidAt != null
                  ? dateText(paidAt)
                  : 'Belum ada pembayaran berhasil',
            ),
          ]),

          if (isPaid && paidAt != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pembayaran berhasil pada ${dateText(paidAt)}.',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali ke Riwayat'),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loading ? null : loadDetail,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (error != null) {
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
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: loadDetail,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (order == null) {
              return const Center(
                child: Text('Pesanan tidak ditemukan.'),
              );
            }

            return buildDetail();
          },
        ),
      ),
    );
  }
}
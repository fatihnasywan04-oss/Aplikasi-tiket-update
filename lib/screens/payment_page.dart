import 'package:flutter/material.dart';

import '../api_service.dart';
import 'payment_instruction_page.dart';

class PaymentPage extends StatefulWidget {
  final int orderId;
  final double totalPrice;
  final String eventTitle;
  final int quantity;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.totalPrice,
    required this.eventTitle,
    required this.quantity,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const Color primary = Color(0xFF5B50E8);

  static const List<Map<String, dynamic>> methods = [
    {
      'value': 'transfer_bank',
      'title': 'Transfer Bank',
      'description': 'Pembayaran melalui transfer bank',
      'icon': Icons.account_balance,
    },
    {
      'value': 'e_wallet',
      'title': 'E-Wallet',
      'description': 'Pembayaran melalui dompet digital',
      'icon': Icons.account_balance_wallet,
    },
    {
      'value': 'qris',
      'title': 'QRIS',
      'description': 'Pembayaran menggunakan kode QR',
      'icon': Icons.qr_code_2,
    },
  ];

  String selectedMethod = 'transfer_bank';
  bool submitting = false;
  String? errorMessage;

  String money(num amount) {
    final digits = amount.round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $formatted';
  }

  String readableError(Object error) {
    return error.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
  }

  bool isSuccessfulStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'success' ||
        normalized == 'paid' ||
        normalized == 'completed';
  }

  Future<void> submitPayment() async {
    if (submitting) return;

    if (widget.orderId <= 0) {
      setState(() => errorMessage = 'ID pesanan tidak valid.');
      return;
    }

    if (widget.quantity < 1 || widget.quantity > 10) {
      setState(() => errorMessage = 'Jumlah tiket tidak valid.');
      return;
    }

    if (!methods.any((m) => m['value'] == selectedMethod)) {
      setState(() => errorMessage = 'Metode pembayaran tidak valid.');
      return;
    }

    if (widget.totalPrice < 0) {
      setState(() => errorMessage = 'Total pembayaran tidak valid.');
      return;
    }

    setState(() {
      submitting = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.createPayment(
        orderId: widget.orderId,
        paymentMethod: selectedMethod,
      );

      if (!mounted) return;

      final rawPaymentId = result['id'];
      final paymentId = rawPaymentId is int
          ? rawPaymentId
          : int.tryParse('$rawPaymentId') ?? 0;

      if (paymentId <= 0) {
        throw Exception('ID pembayaran tidak ditemukan dari server.');
      }

      final paymentStatus =
          '${result['payment_status'] ?? ''}'.toLowerCase().trim();

      if (isSuccessfulStatus(paymentStatus)) {
        setState(() {
          submitting = false;
          errorMessage =
              'Pembayaran sudah berhasil diproses. '
              'Silakan periksa riwayat pesanan.';
        });
        return;
      }

      final code = '${result['transaction_id'] ?? ''}'.trim();

      if (code.isEmpty) {
        throw Exception(
          'Kode transaksi tidak tersedia dari server.',
        );
      }

      final rawMethod = '${result['payment_method'] ?? selectedMethod}'
          .toLowerCase()
          .trim();

      if (!methods.any((m) => m['value'] == rawMethod)) {
        throw Exception('Metode pembayaran dari server tidak valid.');
      }

      final rawAmount = result['amount'];
      final serverAmount = rawAmount == null
          ? widget.totalPrice
          : num.tryParse('$rawAmount')?.toDouble();

      if (serverAmount == null || serverAmount < 0) {
        throw Exception('Nominal pembayaran dari server tidak valid.');
      }

      setState(() => submitting = false);

      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentInstructionPage(
            paymentId: paymentId,
            orderId: widget.orderId,
            eventTitle: widget.eventTitle,
            method: rawMethod,
            paymentCode: code,
            amount: serverAmount,
          ),
        ),
      );

      if (!mounted) return;

      if (paid == true) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        submitting = false;
        errorMessage = readableError(error);
      });
    } finally {
      if (mounted && submitting) {
        setState(() => submitting = false);
      }
    }
  }

  Widget buildMethod(Map<String, dynamic> method) {
    final selected = selectedMethod == method['value'];

    return InkWell(
      onTap: submitting
          ? null
          : () {
              setState(() {
                selectedMethod = method['value'] as String;
                errorMessage = null;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.06)
              : Colors.white,
          border: Border.all(
            color: selected ? primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              method['icon'] as IconData,
              color: primary,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    method['description'] as String,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? primary : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Pesanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 28),
                    Text(
                      widget.eventTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('ID pesanan: #${widget.orderId}'),
                    const SizedBox(height: 8),
                    Text('Jumlah tiket: ${widget.quantity}'),
                    const Divider(height: 28),
                    const Text(
                      'Total pembayaran',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      money(widget.totalPrice),
                      style: const TextStyle(
                        color: primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...methods.map(buildMethod),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: submitting ? null : submitPayment,
                icon: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  submitting
                      ? 'Memproses...'
                      : 'Lanjutkan Pembayaran',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pembayaran masih berupa simulasi dan belum terhubung '
              'ke penyedia pembayaran nyata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
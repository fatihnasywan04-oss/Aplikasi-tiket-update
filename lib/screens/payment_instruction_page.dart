
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api_service.dart';

class PaymentInstructionPage extends StatefulWidget {
  final int paymentId;
  final int orderId;
  final String eventTitle;
  final String method;
  final String paymentCode;
  final double amount;

  const PaymentInstructionPage({
    super.key,
    required this.paymentId,
    required this.orderId,
    required this.eventTitle,
    required this.method,
    required this.paymentCode,
    required this.amount,
  });

  @override
  State<PaymentInstructionPage> createState() =>
      _PaymentInstructionPageState();
}

class _PaymentInstructionPageState
    extends State<PaymentInstructionPage> {
  static const Color primary = Color(0xFF5B50E8);

  bool confirming = false;
  String? errorMessage;

  String money(double amount) {
    final digits = amount.round().toString();
    return 'Rp ${digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )}';
  }

  String get methodTitle {
    switch (widget.method) {
      case 'transfer_bank':
        return 'Transfer Bank';
      case 'e_wallet':
        return 'E-Wallet';
      case 'qris':
        return 'QRIS';
      default:
        return 'Pembayaran';
    }
  }

  String get codeLabel {
    return widget.method == 'qris'
        ? 'Kode QR pembayaran'
        : 'Nomor Virtual Account';
  }

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.paymentCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode berhasil disalin')),
    );
  }

  Future<void> confirmPayment() async {
    if (confirming) return;

    setState(() {
      confirming = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.confirmPayment(
        paymentId: widget.paymentId,
      );

      if (!mounted) return;

      final paymentStatus =
          '${result['payment_status'] ?? ''}'.toLowerCase();

      if (paymentStatus == 'success' ||
          paymentStatus == 'paid' ||
          paymentStatus == 'completed') {
        Navigator.pop(context, true);
      } else {
        setState(() {
          confirming = false;
          errorMessage = 'Pembayaran belum berhasil dikonfirmasi.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        confirming = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQris = widget.method == 'qris';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Instruksi Pembayaran'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.eventTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Pesanan #${widget.orderId}'),
                    const SizedBox(height: 18),
                    const Text(
                      'Total pembayaran',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      money(widget.amount),
                      style: const TextStyle(
                        color: primary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                methodTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isQris
                  ? 'Pindai kode berikut untuk melanjutkan pembayaran.'
                  : 'Gunakan kode berikut sesuai metode pembayaran yang dipilih.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (isQris)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: widget.paymentCode,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      codeLabel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      widget.paymentCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: copyCode,
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin Kode'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Periksa kembali nominal dan kode pembayaran sebelum melanjutkan.',
                    ),
                  ),
                ],
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: confirming ? null : confirmPayment,
                icon: confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  confirming
                      ? 'Memproses...'
                      : 'Saya Sudah Membayar',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  bool confirmed = false;
  String? errorMessage;

  String money(double amount) {
    final digits = amount.round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $formatted';
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
    switch (widget.method) {
      case 'qris':
        return 'Kode QR simulasi';
      case 'transfer_bank':
        return 'Kode transfer simulasi';
      case 'e_wallet':
        return 'Kode e-wallet simulasi';
      default:
        return 'Kode pembayaran';
    }
  }

  Future<void> copyCode() async {
    if (widget.paymentCode.trim().isEmpty) {
      setState(() {
        errorMessage = 'Kode pembayaran tidak tersedia.';
      });
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: widget.paymentCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode berhasil disalin')),
    );
  }

  Future<void> confirmPayment() async {
    if (confirming || confirmed) return;

    if (widget.paymentId <= 0) {
      setState(() {
        errorMessage = 'ID pembayaran tidak valid.';
      });
      return;
    }

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
          '${result['payment_status'] ?? ''}'.toLowerCase().trim();

      if (paymentStatus == 'success' ||
          paymentStatus == 'paid' ||
          paymentStatus == 'completed') {
        setState(() {
          confirming = false;
          confirmed = true;
        });

        // Beri kesempatan UI menampilkan status berhasil.
        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() {
          confirming = false;
          errorMessage =
              'Backend belum menyatakan pembayaran berhasil. '
              'Silakan periksa status pembayaran dan coba lagi.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        confirming = false;
        errorMessage = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQris = widget.method == 'qris';
    final hasPaymentCode = widget.paymentCode.trim().isNotEmpty;

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
                  ? 'Kode QR ini hanya untuk simulasi pembayaran aplikasi.'
                  : 'Kode berikut ditampilkan sebagai bagian dari simulasi pembayaran.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.5,
              ),
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
                  child: hasPaymentCode
                      ? QrImageView(
                          data: widget.paymentCode,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        )
                      : const SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(
                            child: Text('Kode QR tidak tersedia'),
                          ),
                        ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      codeLabel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      hasPaymentCode ? widget.paymentCode : 'Tidak tersedia',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: confirming || !hasPaymentCode
                          ? null
                          : copyCode,
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
                color: const Color(0xFFFFF4DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Color(0xFF946200),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pembayaran saat ini masih berupa simulasi. '
                      'Menekan tombol konfirmasi akan meminta backend '
                      'mengonfirmasi pembayaran, bukan memproses transfer '
                      'bank atau transaksi QRIS sungguhan.',
                      style: TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
            if (confirmed) ...[
              const SizedBox(height: 16),
              const Text(
                'Pembayaran berhasil dikonfirmasi.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: confirming || confirmed
                    ? null
                    : confirmPayment,
                icon: confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        confirmed
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                      ),
                label: Text(
                  confirming
                      ? 'Memproses...'
                      : confirmed
                          ? 'Pembayaran Terkonfirmasi'
                          : 'Konfirmasi Pembayaran Simulasi',
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
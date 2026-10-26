
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'my_tickets_page.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const PaymentPage({
    super.key,
    required this.order,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = false;
  String _method = 'transfer_bank';

  String _value(List<String> keys, {String fallback = '-'}) {
    for (final key in keys) {
      final value = widget.order[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  int? _idFrom(List<String> keys) {
    for (final key in keys) {
      final value = widget.order[key];
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  String _formatCurrency(String raw) {
    final number = num.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (number == null) return raw;

    final digits = number.round().toString();
    final output = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        output.write('.');
      }
      output.write(digits[i]);
    }

    return 'Rp ${output.toString()}';
  }

  Future<void> _submitPayment() async {
    final orderId = _idFrom(['id', 'order_id']);

    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID pesanan tidak valid.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final payment = await ApiService.createPayment(
        orderId: orderId,
        paymentMethod: _method,
      );

      if (!mounted) return;

      final paymentId = int.tryParse(
        (payment['id'] ?? payment['payment_id'] ?? '').toString(),
      );

      if (paymentId == null || paymentId <= 0) {
        throw Exception('ID pembayaran tidak ditemukan pada respons server.');
      }

      // Pembayaran dibuat terlebih dahulu. Jangan menganggapnya lunas
      // sebelum backend atau penyedia pembayaran memverifikasinya.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil dibuat. Periksa statusnya.'),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyTicketsPage(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat pembayaran: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _value(
      ['total_price', 'total', 'amount', 'total_amount'],
      fallback: '0',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Total pembayaran',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pesanan #${_value(['id', 'order_id'])}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pilih metode pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _methodTile(
            value: 'transfer_bank',
            title: 'Transfer Bank',
            subtitle: 'Pembayaran melalui transfer bank',
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(height: 10),
          _methodTile(
            value: 'e_wallet',
            title: 'E-Wallet',
            subtitle: 'Pembayaran melalui dompet digital',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 10),
          _methodTile(
            value: 'qris',
            title: 'QRIS',
            subtitle: 'Pembayaran dengan kode QR',
            icon: Icons.qr_code_2_rounded,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _submitPayment,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.lock_outline_rounded),
            label: Text(
              _loading ? 'Memproses...' : 'Buat Pembayaran',
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _method == value;

    return Card(
      child: ListTile(
        onTap: _loading ? null : () => setState(() => _method = value),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

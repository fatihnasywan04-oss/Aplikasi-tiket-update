
import 'dart:async';
import 'dart:ui' show FontFeature;

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
  bool _confirming = false;

  String _method = 'transfer_bank';
  String _provider = 'BCA';

  Map<String, dynamic>? _payment;
  String? _paymentError;
  Timer? _countdownTimer;
  DateTime? _deadline;
  Duration _remaining = const Duration(seconds: 30);
  bool _expired = false;
  bool _refreshingExpiredOrder = false;

  @override
  void initState() {
    super.initState();
    _deadline = _readDeadline();
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  DateTime _readDeadline() {
    final expiresAt = widget.order['expires_at']?.toString();
    if (expiresAt != null && expiresAt.isNotEmpty) {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) return parsed.toLocal();
    }

    final createdAt = widget.order['created_at']?.toString();
    if (createdAt != null && createdAt.isNotEmpty) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) {
        return parsed.toLocal().add(const Duration(seconds: 30));
      }
    }

    return DateTime.now().add(const Duration(seconds: 30));
  }

  void _updateCountdown() {
    if (!mounted || _expired) return;

    final remaining = (_deadline ?? DateTime.now())
        .difference(DateTime.now());

    if (remaining <= Duration.zero) {
      setState(() {
        _remaining = Duration.zero;
        _expired = true;
      });
      _countdownTimer?.cancel();
      _refreshExpiredOrder();
      return;
    }

    setState(() => _remaining = remaining);
  }

  Future<void> _refreshExpiredOrder() async {
    if (_refreshingExpiredOrder) return;
    _refreshingExpiredOrder = true;
    final orderId = _idFrom(['id', 'order_id']);
    if (orderId != null) {
      try {
        await ApiService.getOrderDetail(orderId);
      } catch (_) {
        // UI kedaluwarsa tetap ditampilkan meskipun refresh gagal.
      }
    }
    _refreshingExpiredOrder = false;
  }

  String get _countdownText {
    final seconds = _remaining.inSeconds.clamp(0, 30);
    final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsPart = (seconds % 60).toString().padLeft(2, '0');
    return '$minutesPart:$secondsPart';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Widget _expiredPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2D8D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D202040),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_off_rounded,
              size: 46,
              color: Color(0xFFD94848),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Waktu Pembayaran Habis',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Maaf, batas waktu pembayaran untuk pesanan ini sudah berakhir. '
            'Pesanan dibatalkan dan pembayaran tidak dapat dilanjutkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF9A6A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Silakan kembali ke halaman event, pilih tiket lagi, '
                    'lalu buat pesanan baru.',
                    style: TextStyle(height: 1.4, color: Color(0xFF795600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.confirmation_num_outlined),
              label: const Text('Kembali dan Pesan Ulang'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MyTicketsPage()),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Lihat Tiket Saya'),
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, List<String>> _providers = {
    'transfer_bank': ['BCA', 'BRI', 'Mandiri', 'BNI', 'BSI'],
    'e_wallet': ['DANA', 'OVO', 'GoPay', 'ShopeePay'],
    'qris': ['QRIS'],
  };

  String _value(
    List<String> keys, {
    String fallback = '-',
  }) {
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

      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  int? _paymentId() {
    final payment = _payment;
    if (payment == null) return null;

    for (final key in ['id', 'payment_id']) {
      final value = int.tryParse(
        (payment[key] ?? '').toString(),
      );

      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  String _formatCurrency(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');

    // Harga API biasanya berupa angka desimal, misalnya 250000.00.
    final normalized = cleaned.contains(',')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned;

    final number = num.tryParse(normalized);
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

  String _providerLabel() {
    switch (_method) {
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

  void _selectMethod(String method) {
    if (_expired || _loading || _confirming || _payment != null) return;

    setState(() {
      _method = method;
      _provider = _providers[method]!.first;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitPayment() async {
    if (_expired) {
      _showMessage('Waktu pembayaran habis. Silakan pesan ulang.');
      return;
    }
    final orderId = _idFrom(['id', 'order_id']);

    if (orderId == null) {
      _showMessage('ID pesanan tidak valid.');
      return;
    }

    if (_payment != null) {
      _showMessage('Pembayaran sudah dibuat.');
      return;
    }

    setState(() {
      _loading = true;
      _paymentError = null;
    });

    try {
      final payment = await ApiService.createPayment(
        orderId: orderId,
        paymentMethod: _method,
        paymentProvider: _provider,
      );

      if (!mounted) return;

      final paymentId = int.tryParse(
        (payment['id'] ?? payment['payment_id'] ?? '').toString(),
      );

      if (paymentId == null || paymentId <= 0) {
        throw Exception(
          'ID pembayaran tidak ditemukan pada respons server.',
        );
      }

      setState(() {
        _payment = payment;
      });

      _showMessage('Instruksi pembayaran simulasi berhasil dibuat.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _paymentError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });

      _showMessage('Gagal membuat pembayaran: $_paymentError');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmSimulation() async {
    if (_expired) {
      _showMessage('Waktu pembayaran habis. Silakan pesan ulang.');
      return;
    }
    final paymentId = _paymentId();

    if (paymentId == null) {
      _showMessage('ID pembayaran tidak valid.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi simulasi'),
          content: const Text(
            'Lanjutkan simulasi pembayaran? '
            'Jika backend menerima konfirmasi, status pesanan '
            'akan diperbarui dan stok tiket akan diproses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);

    try {
      final result = await ApiService.confirmPayment(
        paymentId: paymentId,
      );

      if (!mounted) return;

      final status = (result['payment_status'] ??
              result['status'] ??
              '')
          .toString()
          .toLowerCase();

      if (status != 'success' && status != 'paid') {
        _showMessage(
          'Server belum menyatakan pembayaran berhasil. '
          'Periksa status pembayaran.',
        );
        return;
      }

      _showMessage('Pembayaran simulasi berhasil dikonfirmasi.');

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyTicketsPage(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Konfirmasi gagal: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  Widget _methodTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _method == value;

    return Card(
      color: selected ? const Color(0xFFF0EEFF) : Colors.white,
      child: ListTile(
        onTap: () => _selectMethod(value),
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
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          color: selected
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _providerSelector() {
    final providers = _providers[_method]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _method == 'transfer_bank'
              ? 'Pilih bank'
              : _method == 'e_wallet'
                  ? 'Pilih e-wallet'
                  : 'Metode QR',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: providers.map((provider) {
            final selected = _provider == provider;

            return ChoiceChip(
              label: Text(provider),
              selected: selected,
              onSelected: (_loading ||
                      _confirming ||
                      _payment != null)
                  ? null
                  : (value) {
                      if (value) {
                        setState(() => _provider = provider);
                      }
                    },
              selectedColor: const Color(0xFFEAE8FF),
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _paymentInstructions() {
    final payment = _payment!;

    final transactionId = (
      payment['transaction_id'] ??
      payment['reference'] ??
      payment['id'] ??
      '-'
    ).toString();

    final status = (
      payment['payment_status'] ??
      payment['status'] ??
      'pending'
    ).toString();

    final amount = payment['amount'] ??
        payment['total_price'] ??
        widget.order['total_price'] ??
        0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instruksi pembayaran simulasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _instructionRow('Metode', _providerLabel()),
          _instructionRow('Penyedia', _provider),
          _instructionRow('Total', _formatCurrency(amount.toString())),
          _instructionRow('Referensi', transactionId),
          _instructionRow('Status', status.toUpperCase()),
          const SizedBox(height: 12),
          if (_method == 'transfer_bank')
            const Text(
              'Simulasi transfer: gunakan nomor referensi di atas '
              'sebagai identitas transaksi. Ini bukan nomor rekening '
              'atau virtual account bank sungguhan.',
              style: TextStyle(height: 1.5),
            )
          else if (_method == 'e_wallet')
            const Text(
              'Simulasi e-wallet: tidak ada saldo yang dipotong. '
              'Tekan tombol konfirmasi untuk menyimulasikan '
              'verifikasi pembayaran oleh backend.',
              style: TextStyle(height: 1.5),
            )
          else
            const Text(
              'Simulasi QRIS: pembayaran ini belum menggunakan '
              'QR pembayaran sungguhan. Kode referensi bukan QR '
              'yang dapat dipindai.',
              style: TextStyle(height: 1.5),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _confirming ? null : _confirmSimulation,
              icon: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _confirming
                    ? 'Mengonfirmasi...'
                    : 'Konfirmasi Pembayaran Simulasi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 18),
          if (!_expired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _remaining.inSeconds <= 10
                    ? const Color(0xFFFFF0F0)
                    : const Color(0xFFF2F0FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _remaining.inSeconds <= 10
                      ? const Color(0xFFF4CACA)
                      : const Color(0xFFE2DEFF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _remaining.inSeconds <= 10
                        ? const Color(0xFFD94848)
                        : AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selesaikan pembayaran sebelum',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 3),
                        Text('Jika habis, kamu perlu memesan ulang.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  Text(
                    _countdownText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _remaining.inSeconds <= 10
                          ? const Color(0xFFD94848)
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          if (_expired) ...[
            _expiredPanel(),
          ] else if (_payment == null) ...[
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
              subtitle: 'BCA, BRI, Mandiri, BNI, atau BSI',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 10),
            _methodTile(
              value: 'e_wallet',
              title: 'E-Wallet',
              subtitle: 'DANA, OVO, GoPay, atau ShopeePay',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 10),
            _methodTile(
              value: 'qris',
              title: 'QRIS',
              subtitle: 'Simulasi pembayaran QR',
              icon: Icons.qr_code_2_rounded,
            ),
            const SizedBox(height: 22),
            _providerSelector(),
            const SizedBox(height: 24),
            if (_paymentError != null) ...[
              Text(
                _paymentError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
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
            ),
          ] else ...[
            _paymentInstructions(),
          ],
        ],
      ),
    );
  }
}

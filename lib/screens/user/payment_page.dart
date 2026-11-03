import 'dart:async';

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
  bool _expired = false;
  bool _refreshingExpiredOrder = false;

  String _method = 'transfer_bank';
  String _provider = 'BCA';

  Map<String, dynamic>? _payment;
  String? _paymentError;

  Timer? _countdownTimer;
  DateTime? _deadline;
  Duration _remaining = ApiService.paymentExpiration;

  static const Map<String, List<String>> _providers = {
    'transfer_bank': ['BCA', 'BRI', 'Mandiri', 'BNI', 'BSI'],
    'e_wallet': ['DANA', 'OVO', 'GoPay', 'ShopeePay'],
    'qris': ['QRIS'],
  };

  @override
  void initState() {
    super.initState();

    _deadline = _readDeadline();
    _updateCountdown();

    if (!_expired) {
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateCountdown(),
      );
    }
  }

  // ============================================================
  // COUNTDOWN
  // ============================================================

  DateTime _readDeadline() {
    final expiresAt = widget.order['expires_at']?.toString();

    if (expiresAt != null && expiresAt.isNotEmpty) {
      final parsed = DateTime.tryParse(expiresAt);

      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    final createdAt = widget.order['created_at']?.toString();

    if (createdAt != null && createdAt.isNotEmpty) {
      final parsed = DateTime.tryParse(createdAt);

      if (parsed != null) {
        return parsed.toLocal().add(
              ApiService.paymentExpiration,
            );
      }
    }

    return DateTime.now().add(
      ApiService.paymentExpiration,
    );
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

    setState(() {
      _remaining = remaining;
    });
  }

  Future<void> _refreshExpiredOrder() async {
    if (_refreshingExpiredOrder) return;

    _refreshingExpiredOrder = true;

    try {
      final orderId = _idFrom(['id', 'order_id']);

      if (orderId != null) {
        await ApiService.getOrderDetail(orderId);
      }
    } catch (_) {
      // Tampilan kedaluwarsa tetap ditampilkan meskipun refresh gagal.
    } finally {
      _refreshingExpiredOrder = false;
    }
  }

  String get _countdownText {
    final seconds = _remaining.inSeconds.clamp(0, 359999);
    final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsPart = (seconds % 60).toString().padLeft(2, '0');

    return '$minutesPart:$secondsPart';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // DATA HELPERS
  // ============================================================

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
      final parsed = int.tryParse(
        widget.order[key]?.toString() ?? '',
      );

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
      final parsed = int.tryParse(
        payment[key]?.toString() ?? '',
      );

      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  String _formatCurrency(String raw) {
    final cleaned = raw.replaceAll(
      RegExp(r'[^0-9,.-]'),
      '',
    );

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

    return 'Rp $output';
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

  // ============================================================
  // PAYMENT METHOD
  // ============================================================

  void _selectMethod(String method) {
    if (_expired ||
        _loading ||
        _confirming ||
        _payment != null) {
      return;
    }

    setState(() {
      _method = method;
      _provider = _providers[method]!.first;
      _paymentError = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // CREATE PAYMENT
  // ============================================================

  Future<void> _submitPayment() async {
    if (_expired) {
      _showMessage(
        'Waktu pembayaran habis. Silakan pesan ulang.',
      );
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

    if (_loading || _confirming) return;

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
        (payment['id'] ?? payment['payment_id'] ?? '')
            .toString(),
      );

      if (paymentId == null || paymentId <= 0) {
        throw Exception(
          'ID pembayaran tidak ditemukan pada respons server.',
        );
      }

      if (_expired) {
        _showMessage(
          'Waktu pembayaran telah habis. '
          'Periksa status pesanan sebelum mencoba lagi.',
        );
        return;
      }

      setState(() {
        _payment = payment;
      });

      _showMessage(
        'Instruksi pembayaran simulasi berhasil dibuat.',
      );
    } catch (error) {
      if (!mounted) return;

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      setState(() {
        _paymentError = message;
      });

      _showMessage('Gagal membuat pembayaran: $message');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRM PAYMENT
  // ============================================================

  Future<void> _confirmSimulation() async {
    if (_expired) {
      _showMessage(
        'Waktu pembayaran habis. Silakan pesan ulang.',
      );
      return;
    }

    if (_confirming || _loading) return;

    final paymentId = _paymentId();

    if (paymentId == null) {
      _showMessage('ID pembayaran tidak valid.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          icon: const Icon(
            Icons.help_outline_rounded,
            color: AppColors.gold,
            size: 42,
          ),
          title: const Text(
            'Konfirmasi simulasi',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Lanjutkan simulasi pembayaran? '
            'Jika backend menerima konfirmasi, status pembayaran '
            'dan pesanan akan diperbarui.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    if (_expired) {
      _showMessage(
        'Waktu pembayaran habis. Silakan pesan ulang.',
      );
      return;
    }

    setState(() {
      _confirming = true;
    });

    try {
      final result = await ApiService.confirmPayment(
        paymentId: paymentId,
      );

      if (!mounted) return;

      final status = (
        result['payment_status'] ??
        result['status'] ??
        ''
      ).toString().toLowerCase();

      if (status != 'success' && status != 'paid') {
        _showMessage(
          'Server belum menyatakan pembayaran berhasil. '
          'Periksa kembali status pembayaran.',
        );
        return;
      }

      _countdownTimer?.cancel();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 54,
            ),
            title: const Text(
              'Pembayaran Berhasil!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Pembayaran berhasil dikonfirmasi. '
              'Sekarang kamu bisa kembali ke Home '
              'atau melihat tiket yang sudah dibeli.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Kembali ke Home'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const MyTicketsPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.confirmation_num_outlined,
                    ),
                    label: const Text('Lihat Tiket Saya'),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Konfirmasi gagal: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  // ============================================================
  // PAYMENT METHOD CARD
  // ============================================================

  Widget _methodTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _method == value;
    final disabled = _expired ||
        _loading ||
        _confirming ||
        _payment != null;

    return Card(
      elevation: 0,
      color: selected
          ? AppColors.primaryPale
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 5,
        ),
        onTap: disabled ? null : () => _selectMethod(value),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.gold,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          color: selected
              ? AppColors.primaryLight
              : AppColors.textMuted,
        ),
      ),
    );
  }

  // ============================================================
  // PROVIDER SELECTOR
  // ============================================================

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
            color: AppColors.text,
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
                      _expired ||
                      _payment != null)
                  ? null
                  : (value) {
                      if (!value) return;

                      setState(() {
                        _provider = provider;
                      });
                    },
              selectedColor: AppColors.primaryPale,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: selected
                    ? AppColors.primary
                    : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.text
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT INSTRUCTIONS
  // ============================================================

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.gold,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instruksi pembayaran simulasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _instructionRow('Metode', _providerLabel()),
          _instructionRow('Penyedia', _provider),
          _instructionRow(
            'Total',
            _formatCurrency(amount.toString()),
          ),
          _instructionRow('Referensi', transactionId),
          _instructionRow('Status', status.toUpperCase()),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.gold,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ini hanya simulasi. Tidak ada uang yang benar-benar '
                    'ditransfer melalui aplikasi ini.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_confirming || _expired)
                  ? null
                  : _confirmSimulation,
              icon: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.verified_outlined,
                      color: AppColors.gold,
                    ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPIRED PANEL
  // ============================================================

  Widget _expiredPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_off_rounded,
              size: 46,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Waktu Pembayaran Habis',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Maaf, batas waktu pembayaran untuk pesanan ini '
            'sudah berakhir. Pesanan tidak dapat dilanjutkan '
            'melalui halaman ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.gold,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kembali ke halaman event, pilih tiket, '
                    'lalu buat pesanan baru.',
                    style: TextStyle(
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
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
              icon: const Icon(
                Icons.confirmation_num_outlined,
                color: AppColors.gold,
              ),
              label: const Text('Kembali dan Pesan Ulang'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const MyTicketsPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.receipt_long_outlined,
              ),
              label: const Text('Lihat Tiket Saya'),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final total = _value(
      [
        'total_price',
        'total',
        'amount',
        'total_amount',
      ],
      fallback: '0',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pembayaran',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TOTAL PAYMENT HEADER
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  Color(0xFF7D292F),
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.gold,
                  size: 34,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Total pembayaran',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pesanan #${_value(['id', 'order_id'])}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // COUNTDOWN
          if (!_expired)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: _remaining.inSeconds <= 10
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _remaining.inSeconds <= 10
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _remaining.inSeconds <= 10
                        ? AppColors.error
                        : AppColors.gold,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selesaikan pembayaran sebelum',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Jika habis, kamu perlu memesan ulang.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _countdownText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                      color: _remaining.inSeconds <= 10
                          ? AppColors.error
                          : AppColors.gold,
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
                color: AppColors.text,
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
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _paymentError!,
                  style: const TextStyle(
                    color: AppColors.error,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.text,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _loading ? null : _submitPayment,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.gold,
                      ),
                label: Text(
                  _loading
                      ? 'Memproses...'
                      : 'Buat Pembayaran',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
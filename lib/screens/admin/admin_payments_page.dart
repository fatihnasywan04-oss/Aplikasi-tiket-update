import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() =>
      _AdminPaymentsPageState();
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

  // ============================================================
  // LOAD PAYMENTS
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getAdminPayments();

      if (!mounted) return;

      setState(() {
        _payments = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _value(
    Map<String, dynamic> item,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = item[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  String _nestedValue(
    Map<String, dynamic> item, {
    required String objectKey,
    required List<String> keys,
    String fallback = '-',
  }) {
    final nested = _asMap(item[objectKey]);

    return _value(
      nested,
      keys,
      fallback: fallback,
    );
  }

  String _paymentId(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['id', 'payment_id'],
    );
  }

  String _orderId(Map<String, dynamic> payment) {
    final direct = _value(
      payment,
      ['order_id'],
      fallback: '',
    );

    if (direct.isNotEmpty) return direct;

    return _nestedValue(
      payment,
      objectKey: 'order',
      keys: ['id', 'order_id'],
    );
  }

  String _paymentMethod(Map<String, dynamic> payment) {
    final method = _value(
      payment,
      ['method', 'payment_method', 'method_name'],
      fallback: '',
    );

    if (method.isNotEmpty) return method;

    return _nestedValue(
      payment,
      objectKey: 'payment',
      keys: ['method', 'payment_method'],
    );
  }

  String _paymentStatus(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['status', 'payment_status'],
      fallback: 'unknown',
    ).toLowerCase().trim();
  }

  String _transactionId(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['transaction_id', 'reference_id', 'reference'],
    );
  }

  String _paymentProvider(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['payment_provider', 'provider', 'gateway'],
    );
  }

  String _createdAt(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['created_at', 'payment_date', 'created'],
      fallback: '',
    );
  }

  String _paidAt(Map<String, dynamic> payment) {
    return _value(
      payment,
      ['paid_at', 'confirmed_at', 'settled_at'],
      fallback: '',
    );
  }

  // ============================================================
  // CURRENCY FORMAT
  // ============================================================

  String _formatRupiah(dynamic value) {
    if (value == null) return '0';

    final number = num.tryParse(
      value.toString().replaceAll(',', '.'),
    );

    if (number == null) {
      return value.toString();
    }

    final digits = number.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  String _paymentAmount(Map<String, dynamic> payment) {
    final value = payment['amount'] ??
        payment['total'] ??
        payment['total_amount'];

    return _formatRupiah(value);
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(String value) {
    if (value.trim().isEmpty || value == '-') {
      return '-';
    }

    final date = DateTime.tryParse(value);

    if (date == null) return value;

    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // ============================================================
  // PAYMENT METHOD LABEL
  // ============================================================

  String _methodLabel(String method) {
    switch (method.toLowerCase().trim()) {
      case 'transfer_bank':
      case 'bank_transfer':
      case 'transfer':
        return 'Transfer Bank';

      case 'e_wallet':
      case 'ewallet':
      case 'e-wallet':
        return 'E-Wallet';

      case 'qris':
        return 'QRIS';

      default:
        if (method == '-') return '-';

        return method
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  Color _statusColor(String status) {
    final normalized = status.toLowerCase().trim();

    if ([
      'paid',
      'success',
      'successful',
      'completed',
      'confirmed',
      'berhasil',
      'lunas',
    ].contains(normalized)) {
      return AppColors.success;
    }

    if ([
      'pending',
      'waiting',
      'waiting_payment',
      'menunggu',
      'belum_bayar',
    ].contains(normalized)) {
      return AppColors.warning;
    }

    if ([
      'failed',
      'expired',
      'cancelled',
      'canceled',
      'rejected',
      'gagal',
      'dibatalkan',
    ].contains(normalized)) {
      return AppColors.error;
    }

    return AppColors.textMuted;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
      case 'success':
      case 'successful':
        return 'BERHASIL';

      case 'completed':
        return 'SELESAI';

      case 'confirmed':
        return 'DIKONFIRMASI';

      case 'pending':
        return 'MENUNGGU';

      case 'waiting':
      case 'waiting_payment':
        return 'MENUNGGU PEMBAYARAN';

      case 'failed':
        return 'GAGAL';

      case 'expired':
        return 'KEDALUWARSA';

      case 'cancelled':
      case 'canceled':
        return 'DIBATALKAN';

      case 'rejected':
        return 'DITOLAK';

      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        _statusLabel(status),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT CARD
  // ============================================================

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentId = _paymentId(payment);
    final orderId = _orderId(payment);

    final method = _methodLabel(
      _paymentMethod(payment),
    );

    final amount = _paymentAmount(payment);
    final status = _paymentStatus(payment);

    final transactionId = _transactionId(payment);
    final provider = _paymentProvider(payment);

    final createdAt = _createdAt(payment);
    final paidAt = _paidAt(payment);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: AppColors.gold,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pembayaran #$paymentId',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.8),
            ),

            const SizedBox(height: 15),

            _buildInfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Pesanan',
              value: '#$orderId',
            ),

            _buildInfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Metode',
              value: method,
            ),

            if (provider != '-')
              _buildInfoRow(
                icon: Icons.business_outlined,
                label: 'Provider',
                value: provider,
              ),

            if (transactionId != '-')
              _buildInfoRow(
                icon: Icons.tag_outlined,
                label: 'ID Transaksi',
                value: transactionId,
              ),

            if (createdAt.isNotEmpty)
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Dibuat',
                value: _formatDate(createdAt),
              ),

            if (paidAt.isNotEmpty)
              _buildInfoRow(
                icon: Icons.check_circle_outline,
                label: 'Dibayar',
                value: _formatDate(paidAt),
              ),

            const SizedBox(height: 5),

            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: AppColors.gold,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Jumlah Pembayaran',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Rp $amount',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textMuted,
                  size: 17,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Status Pembayaran',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Flexible(
                  child: _buildStatusChip(status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
    // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            const Text(
              'Gagal memuat pembayaran',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 110),
        Icon(
          Icons.payments_outlined,
          size: 65,
          color: AppColors.textMuted,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada pembayaran',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Data pembayaran akan ditampilkan di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Data Pembayaran',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.gold,
            ),
          ),
        ],
      ),

      drawer: const AdminDrawerPage(
        currentRoute: '/admin/payments',
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _payments.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.gold,
                      backgroundColor: AppColors.surface,
                      child: _buildEmptyState(),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.gold,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          24,
                        ),
                        itemCount: _payments.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final payment = _asMap(
                            _payments[index],
                          );

                          return _buildPaymentCard(payment);
                        },
                      ),
                    ),
    );
  }
}
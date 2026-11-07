import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool _loading = true;
  String? _error;

  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // LOAD ORDERS
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getAdminOrders();

      if (!mounted) return;

      setState(() {
        _orders = result;
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

  String _orderId(Map<String, dynamic> order) {
    return _value(order, ['id', 'order_id']);
  }

  String _eventTitle(Map<String, dynamic> order) {
    final direct = _value(
      order,
      ['event_title', 'event_name', 'title'],
      fallback: '',
    );

    if (direct.isNotEmpty) return direct;

    return _nestedValue(
      order,
      objectKey: 'event',
      keys: ['title', 'name', 'event_title'],
    );
  }

  String _username(Map<String, dynamic> order) {
    final direct = _value(
      order,
      ['username', 'user_name', 'customer_name', 'name'],
      fallback: '',
    );

    if (direct.isNotEmpty) return direct;

    return _nestedValue(
      order,
      objectKey: 'user',
      keys: ['name', 'username', 'full_name'],
    );
  }

  String _ticketClassName(Map<String, dynamic> order) {
    final direct = _value(
      order,
      [
        'ticket_class_name',
        'ticket_name',
        'class_name',
      ],
      fallback: '',
    );

    if (direct.isNotEmpty) return direct;

    return _nestedValue(
      order,
      objectKey: 'ticket_class',
      keys: ['name', 'ticket_class_name'],
    );
  }

  String _quantity(Map<String, dynamic> order) {
    return _value(
      order,
      ['quantity', 'ticket_quantity'],
      fallback: '0',
    );
  }

  String _orderStatus(Map<String, dynamic> order) {
    return _value(
      order,
      ['status', 'order_status'],
      fallback: 'unknown',
    ).toLowerCase().trim();
  }

  String _createdAt(Map<String, dynamic> order) {
    return _value(
      order,
      ['created_at', 'order_date', 'created'],
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

  String _orderTotal(Map<String, dynamic> order) {
    final value = order['total_price'] ??
        order['total'] ??
        order['amount'];

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
      'cancelled',
      'canceled',
      'failed',
      'expired',
      'rejected',
      'dibatalkan',
      'gagal',
    ].contains(normalized)) {
      return AppColors.error;
    }

    return AppColors.textMuted;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
        return 'LUNAS';
      case 'success':
      case 'successful':
        return 'BERHASIL';
      case 'completed':
        return 'SELESAI';
      case 'confirmed':
        return 'DIKONFIRMASI';
      case 'pending':
        return 'MENUNGGU PEMBAYARAN';
      case 'waiting':
      case 'waiting_payment':
        return 'MENUNGGU';
      case 'cancelled':
      case 'canceled':
        return 'DIBATALKAN';
      case 'failed':
        return 'GAGAL';
      case 'expired':
        return 'KEDALUWARSA';
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
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final eventTitle = _eventTitle(order);
    final orderId = _orderId(order);
    final username = _username(order);
    final ticketClass = _ticketClassName(order);
    final quantity = _quantity(order);
    final total = _orderTotal(order);
    final status = _orderStatus(order);

    final createdAt = _createdAt(order);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.gold,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Pesanan #$orderId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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
              icon: Icons.person_outline_rounded,
              label: 'Pengguna',
              value: username,
            ),

            _buildInfoRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Jumlah tiket',
              value: quantity,
            ),

            if (ticketClass != '-') 
              _buildInfoRow(
                icon: Icons.local_activity_outlined,
                label: 'Kelas tiket',
                value: ticketClass,
              ),

            if (createdAt.isNotEmpty)
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal',
                value: _formatDate(createdAt),
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
                    Icons.payments_outlined,
                    color: AppColors.gold,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Total Pesanan',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Rp $total',
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
                    'Status Pesanan',
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
              'Gagal memuat pesanan',
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
          Icons.receipt_long_outlined,
          size: 65,
          color: AppColors.textMuted,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada pesanan',
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
            'Pesanan yang masuk akan ditampilkan di sini.',
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
          'Data Pesanan',
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
        currentRoute: '/admin/orders',
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _orders.isEmpty
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
                        itemCount: _orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _asMap(_orders[index]);

                          return _buildOrderCard(order);
                        },
                      ),
                    ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import 'admin_drawer_page.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _reports = [];

  static const double _feePercentage = 0.05;

  @override
  void initState() {
    super.initState();
    _loadReports();
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
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  num _toNumber(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;

    final normalized = value.toString().trim();

    if (normalized.isEmpty) return 0;

    return num.tryParse(normalized) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text)?.toLocal();
  }

  // ============================================================
  // CURRENCY FORMAT
  // ============================================================

  String _formatCurrency(num value) {
    final digits = value.round().toString();
    final result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        result.write('.');
      }

      result.write(digits[i]);
    }

    return 'Rp $result';
  }

  // ============================================================
  // EVENT HELPERS
  // ============================================================

  int? _eventId(Map<String, dynamic> event) {
    return _toInt(
      event['id'] ??
          event['event_id'],
    );
  }

  String _eventName(Map<String, dynamic> event) {
    return _value(
      event,
      [
        'title',
        'name',
        'event_title',
        'nama_event',
      ],
      fallback: 'Event tanpa nama',
    );
  }

  DateTime? _eventEndDate(Map<String, dynamic> event) {
    // Laporan menggunakan end_date sebagai tanggal selesai.
    // Tidak menggunakan event_date/start_date sebagai pengganti.
    return _parseDate(
      event['end_date'] ??
          event['endDate'],
    );
  }

  bool _isEventCancelled(Map<String, dynamic> event) {
    final value = event['is_cancelled'] ??
        event['isCancelled'] ??
        false;

    return value == true ||
        value.toString().toLowerCase() == 'true';
  }

  String _eventApprovalStatus(Map<String, dynamic> event) {
    return _value(
      event,
      ['approval_status', 'status'],
      fallback: 'approved',
    ).toLowerCase();
  }

  // ============================================================
  // ORDER HELPERS
  // ============================================================

  int? _orderEventId(Map<String, dynamic> order) {
    final directId = _toInt(
      order['event_id'],
    );

    if (directId != null) return directId;

    final event = _asMap(order['event']);

    return _toInt(
      event['id'] ?? event['event_id'],
    );
  }

  bool _isPaid(Map<String, dynamic> order) {
    final payment = _asMap(order['payment']);

    final paymentDetail = _asMap(order['latest_payment']);

    final statuses = [
      order['status'],
      order['order_status'],
      order['payment_status'],
      payment['status'],
      payment['payment_status'],
      paymentDetail['status'],
      paymentDetail['payment_status'],
    ];

    return statuses.any((value) {
      final status = value?.toString().trim().toLowerCase();

      return {
        'paid',
        'success',
        'successful',
        'completed',
        'completed_payment',
        'lunas',
      }.contains(status);
    });
  }

  num _orderTotal(Map<String, dynamic> order) {
    final payment = _asMap(order['payment']);
    final paymentDetail = _asMap(order['latest_payment']);

    return _toNumber(
      order['total_price'] ??
          order['total_amount'] ??
          order['total'] ??
          order['amount'] ??
          payment['amount'] ??
          paymentDetail['amount'],
    );
  }

  // ============================================================
  // LOAD REPORTS
  // ============================================================

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMyEvents(),
        ApiService.getAdminOrders(),
      ]);

      final events = results[0];
      final orders = results[1];

      final now = DateTime.now();

      final reports = <Map<String, dynamic>>[];

      for (final event in events) {
        final eventId = _eventId(event);

        if (eventId == null) continue;

        // Hanya event yang sudah disetujui.
        if (_eventApprovalStatus(event) != 'approved') {
          continue;
        }

        // Event yang dibatalkan tidak dihitung.
        if (_isEventCancelled(event)) {
          continue;
        }

        final endDate = _eventEndDate(event);

        // Event harus memiliki end_date dan sudah selesai.
        if (endDate == null || !endDate.isBefore(now)) {
          continue;
        }

        // Ambil hanya pesanan lunas untuk event ini.
        final eventOrders = orders.where((order) {
          return _orderEventId(order) == eventId &&
              _isPaid(order);
        }).toList();

        // Total penjualan berdasarkan total pesanan lunas.
        final totalSales = eventOrders.fold<num>(
          0,
          (total, order) {
            return total + _orderTotal(order);
          },
        );

        // Potongan platform 5% per event.
        final platformFee = totalSales * _feePercentage;

        // Pendapatan bersih event.
        final netIncome = totalSales - platformFee;

        reports.add({
          'event_id': eventId,
          'event_name': _eventName(event),
          'end_date': endDate,
          'order_count': eventOrders.length,
          'total_sales': totalSales,
          'platform_fee': platformFee,
          'net_income': netIncome,
        });
      }

      // Urutkan berdasarkan tanggal selesai terbaru.
      reports.sort((a, b) {
        final dateA = a['end_date'] as DateTime;
        final dateB = b['end_date'] as DateTime;

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _reports = reports;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
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
  // SUMMARY CALCULATIONS
  // ============================================================

  num get _totalSales {
    return _reports.fold<num>(
      0,
      (total, item) {
        return total + (item['total_sales'] as num);
      },
    );
  }

  num get _totalPlatformFee {
    return _reports.fold<num>(
      0,
      (total, item) {
        return total + (item['platform_fee'] as num);
      },
    );
  }

  num get _totalNetIncome {
    return _reports.fold<num>(
      0,
      (total, item) {
        return total + (item['net_income'] as num);
      },
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
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text(
          'Laporan Penjualan',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadReports,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.gold,
            ),
          ),
        ],
      ),

      drawer: const AdminDrawerPage(
        currentRoute: '/admin/reports',
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
              ),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 25),

                      const Text(
                        'Riwayat Event Selesai',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Potongan platform sebesar 5% dihitung '
                        'secara terpisah untuk setiap event '
                        'berdasarkan pesanan yang sudah lunas.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 15),

                      if (_reports.isEmpty)
                        _buildEmpty()
                      else
                        ..._reports.map(_buildReportCard),
                    ],
                  ),
                ),
    );
  }
    // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
                Icons.analytics_outlined,
                color: AppColors.gold,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                'Ringkasan Laporan',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _summaryRow(
            'Jumlah event selesai',
            '${_reports.length} event',
          ),

          const SizedBox(height: 13),

          _summaryRow(
            'Total penjualan',
            _formatCurrency(_totalSales),
          ),

          const SizedBox(height: 13),

          _summaryRow(
            'Total potongan platform',
            _formatCurrency(_totalPlatformFee),
            valueColor: AppColors.gold,
          ),

          const SizedBox(height: 13),

          _summaryRow(
            'Total pendapatan bersih',
            _formatCurrency(_totalNetIncome),
            valueColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String label,
    String value, {
    Color valueColor = AppColors.text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _buildReportCard(
    Map<String, dynamic> report,
  ) {
    final endDate = report['end_date'] as DateTime;

    final totalSales = report['total_sales'] as num;
    final platformFee = report['platform_fee'] as num;
    final netIncome = report['net_income'] as num;

    final orderCount = report['order_count'] as int;

    final formattedDate =
        '${endDate.day.toString().padLeft(2, '0')}-'
        '${endDate.month.toString().padLeft(2, '0')}-'
        '${endDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.gold,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['event_name'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Berakhir: $formattedDate',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(
              color: AppColors.border,
              height: 1,
            ),
          ),

          _summaryRow(
            'Pesanan lunas',
            '$orderCount pesanan',
          ),

          const SizedBox(height: 11),

          _summaryRow(
            'Total penjualan event',
            _formatCurrency(totalSales),
          ),

          const SizedBox(height: 11),

          _summaryRow(
            'Potongan platform (5%)',
            _formatCurrency(platformFee),
            valueColor: AppColors.gold,
          ),

          const SizedBox(height: 13),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Pendapatan bersih event (95%)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Flexible(
                  child: Text(
                    _formatCurrency(netIncome),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.description_outlined,
            color: AppColors.gold,
            size: 45,
          ),

          SizedBox(height: 13),

          Text(
            'Belum ada laporan event.',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 7),

          Text(
            'Laporan akan muncul setelah tanggal event '
            'berakhir dan terdapat pesanan yang sudah lunas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.error,
              size: 44,
            ),

            const SizedBox(height: 12),

            const Text(
              'Laporan gagal dimuat.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 15),

            FilledButton.icon(
              onPressed: _loadReports,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num _toNumber(dynamic value) {
    if (value is num) return value;
    if (value == null) return 0;

    return num.tryParse(value.toString()) ?? 0;
  }

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

  String _eventName(Map<String, dynamic> event) {
    return (event['title'] ??
            event['name'] ??
            event['nama_event'] ??
            'Event tanpa nama')
        .toString();
  }

  DateTime? _eventEndDate(Map<String, dynamic> event) {
    return _parseDate(
      event['end_date'] ??
          event['endDate'] ??
          event['event_date'] ??
          event['start_date'] ??
          event['date'],
    );
  }

  bool _isPaid(Map<String, dynamic> order) {
    final statuses = [
      order['status'],
      order['order_status'],
      order['payment_status'],
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
    return _toNumber(
      order['total_price'] ??
          order['total_amount'] ??
          order['total'] ??
          order['amount'],
    );
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getEvents(),
        ApiService.getAdminOrders(),
      ]);

      final events = results[0];
      final orders = results[1];

      final now = DateTime.now();
      final reports = <Map<String, dynamic>>[];

      for (final event in events) {
        final endDate = _eventEndDate(event);

        // Hanya event yang sudah melewati tanggal akhirnya.
        if (endDate == null || !endDate.isBefore(now)) {
          continue;
        }

        final eventId = _toInt(event['id'] ?? event['event_id']);

        if (eventId == null) continue;

        final eventOrders = orders.where((order) {
          final orderEventId = _toInt(
            order['event_id'] ??
                order['event']?['id'],
          );

          return orderEventId == eventId && _isPaid(order);
        }).toList();

        // Total penjualan khusus event ini.
        final totalSales = eventOrders.fold<num>(
          0,
          (total, order) => total + _orderTotal(order),
        );

        // Potongan platform 5% khusus event ini.
        final platformFee = totalSales * _feePercentage;

        // Pendapatan bersih khusus event ini.
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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Total penjualan seluruh event yang selesai.
  num get _totalSales => _reports.fold<num>(
        0,
        (total, item) => total + (item['total_sales'] as num),
      );

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
            onPressed: _loadReports,
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
                        'secara terpisah untuk setiap event.',
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

  // Ringkasan tidak lagi menampilkan total potongan gabungan.
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
            'Total penjualan seluruh event',
            _formatCurrency(_totalSales),
          ),
        ],
      ),
    );
  }

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
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Setiap kartu menghitung dan menampilkan potongan event masing-masing.
  Widget _buildReportCard(Map<String, dynamic> report) {
    final endDate = report['end_date'] as DateTime;

    final totalSales = report['total_sales'] as num;
    final platformFee = report['platform_fee'] as num;
    final netIncome = report['net_income'] as num;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
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
                      'Berakhir: ${endDate.day.toString().padLeft(2, '0')}-'
                      '${endDate.month.toString().padLeft(2, '0')}-'
                      '${endDate.year}',
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
            child: Divider(color: AppColors.border, height: 1),
          ),
          _summaryRow(
            'Pesanan lunas',
            '${report['order_count']} pesanan',
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
                Text(
                  _formatCurrency(netIncome),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
            'Laporan akan muncul setelah tanggal event berakhir.',
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
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
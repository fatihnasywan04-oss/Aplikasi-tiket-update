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

    int _totalEvents = 0;
    int _totalOrders = 0;
    int _totalTickets = 0;

    num _totalSales = 0;
    num _totalPlatformFee = 0;
    num _totalNetIncome = 0;

    @override
    void initState() {
      super.initState();
      _loadReports();
    }

    // ============================================================
    // RESPONSE HELPERS
    // ============================================================

    int _toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 0;
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
    // DATE FORMAT
    // ============================================================

    String _formatDate(dynamic value) {
      final date = _parseDate(value);

      if (date == null) {
        return 'Tanggal tidak tersedia';
      }

      return '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.year}';
    }

    // ============================================================
    // LOAD REPORTS DARI BACKEND
    // ============================================================

    Future<void> _loadReports() async {
      if (!mounted) return;

      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        // Mengambil laporan langsung dari endpoint khusus Super Admin.
        // Tidak menggunakan getEvents() karena endpoint publik
        // tidak menyertakan event yang sudah soft delete.
        final response = await ApiService.getAdminEventReports();

        final rawReports = response['reports'];

        final reports = <Map<String, dynamic>>[];

        if (rawReports is List) {
          for (final item in rawReports) {
            if (item is! Map) continue;

            final report = Map<String, dynamic>.from(item);

            final totalSales = _toNumber(
              report['total_sales'],
            );

            final platformFee = _toNumber(
              report['platform_fee'],
            );

            final netIncome = _toNumber(
              report['net_income'],
            );

            reports.add({
              ...report,
              'event_id': _toInt(report['event_id']),
              'event_name': _value(
                report,
                ['event_name', 'event_title', 'title', 'name'],
                fallback: 'Event tanpa nama',
              ),
              'end_date': report['end_date'] ??
                  report['event_date'],
              'paid_order_count': _toInt(
                report['paid_order_count'] ??
                    report['order_count'],
              ),
              'tickets_sold': _toInt(
                report['tickets_sold'] ??
                    report['ticket_count'],
              ),
              'total_sales': totalSales,
              'platform_fee': platformFee,
              'net_income': netIncome,
            });
          }
        }

        // Urutkan event berdasarkan tanggal selesai terbaru.
        reports.sort((a, b) {
          final dateA = _parseDate(a['end_date']);
          final dateB = _parseDate(b['end_date']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        // Ambil total ringkasan dari backend.
        // Jika backend belum mengirim nilai tertentu, gunakan
        // hasil penjumlahan data laporan sebagai fallback.
        final calculatedOrders = reports.fold<int>(
          0,
          (total, item) =>
              total + _toInt(item['paid_order_count']),
        );

        final calculatedTickets = reports.fold<int>(
          0,
          (total, item) =>
              total + _toInt(item['tickets_sold']),
        );

        final calculatedSales = reports.fold<num>(
          0,
          (total, item) =>
              total + _toNumber(item['total_sales']),
        );

        final calculatedFee = reports.fold<num>(
          0,
          (total, item) =>
              total + _toNumber(item['platform_fee']),
        );

        final calculatedNet = reports.fold<num>(
          0,
          (total, item) =>
              total + _toNumber(item['net_income']),
        );

        if (!mounted) return;

        setState(() {
          _reports = reports;

          _totalEvents = _toInt(
            response['total_events'],
          );

          _totalOrders = _toInt(
            response['total_paid_orders'],
          );

          _totalTickets = _toInt(
            response['total_tickets_sold'],
          );

          _totalSales = _toNumber(
            response['total_sales'],
          );

          _totalPlatformFee = _toNumber(
            response['total_platform_fee'],
          );

          _totalNetIncome = _toNumber(
            response['total_net_income'],
          );

          // Fallback jika backend tidak mengirim nilai ringkasan.
          if (!response.containsKey('total_events')) {
            _totalEvents = reports.length;
          }

          if (!response.containsKey('total_paid_orders')) {
            _totalOrders = calculatedOrders;
          }

          if (!response.containsKey('total_tickets_sold')) {
            _totalTickets = calculatedTickets;
          }

          if (!response.containsKey('total_sales')) {
            _totalSales = calculatedSales;
          }

          if (!response.containsKey('total_platform_fee')) {
            _totalPlatformFee = calculatedFee;
          }

          if (!response.containsKey('total_net_income')) {
            _totalNetIncome = calculatedNet;
          }
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
                          'Laporan menampilkan pesanan yang sudah lunas. '
                          'Potongan platform sebesar 5% dihitung dari '
                          'total penjualan setiap event.',
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
              '$_totalEvents event',
            ),
            const SizedBox(height: 13),
            _summaryRow(
              'Total pesanan lunas',
              '$_totalOrders pesanan',
            ),
            const SizedBox(height: 13),
            _summaryRow(
              'Total tiket terjual',
              '$_totalTickets tiket',
            ),
            const SizedBox(height: 13),
            _summaryRow(
              'Total penjualan',
              _formatCurrency(_totalSales),
            ),
            const SizedBox(height: 13),
            _summaryRow(
              'Total potongan platform (5%)',
              _formatCurrency(_totalPlatformFee),
              valueColor: AppColors.gold,
            ),
            const SizedBox(height: 13),
            _summaryRow(
              'Total pendapatan bersih (95%)',
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
      final totalSales = _toNumber(
        report['total_sales'],
      );

      final platformFee = _toNumber(
        report['platform_fee'],
      );

      final netIncome = _toNumber(
        report['net_income'],
      );

      final orderCount = _toInt(
        report['paid_order_count'],
      );

      final ticketCount = _toInt(
        report['tickets_sold'],
      );

      final eventName = _value(
        report,
        ['event_name', 'event_title', 'title', 'name'],
        fallback: 'Event tanpa nama',
      );

      final formattedDate = _formatDate(
        report['end_date'],
      );

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
                        eventName,
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
              'Tiket terjual',
              '$ticketCount tiket',
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
              'Laporan akan muncul setelah tanggal event berakhir. '
              'Event yang sudah selesai tetap dapat ditampilkan '
              'meskipun telah dihapus secara soft delete.',
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
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
  }
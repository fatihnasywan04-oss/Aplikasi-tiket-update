
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';

class AdminEventReportsPage extends StatefulWidget {
  const AdminEventReportsPage({super.key});

  @override
  State<AdminEventReportsPage> createState() =>
      _AdminEventReportsPageState();
}

class _AdminEventReportsPageState
    extends State<AdminEventReportsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _orders = [];

  static const double _platformFeeRate = 0.05;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value.toDouble();

    return double.tryParse(
          value.toString().replaceAll(',', ''),
        ) ??
        0;
  }

  String _readValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  int? _getEventId(Map<String, dynamic> order) {
    final directId = _toInt(
      order['event_id'] ?? order['eventId'],
    );

    if (directId != null) return directId;

    final event = order['event'];

    if (event is Map) {
      return _toInt(event['id'] ?? event['event_id']);
    }

    return null;
  }

  bool _isPaid(Map<String, dynamic> order) {
    final orderStatus = _readValue(
      order,
      ['status', 'order_status'],
      fallback: '',
    ).toLowerCase();

    if (orderStatus == 'paid') return true;

    final paymentStatus = _readValue(
      order,
      ['payment_status'],
      fallback: '',
    ).toLowerCase();

    if (paymentStatus == 'success' || paymentStatus == 'paid') {
      return true;
    }

    final payment = order['payment'] ?? order['latest_payment'];

    if (payment is Map) {
      final status = _readValue(
        payment.cast<String, dynamic>(),
        ['status', 'payment_status'],
        fallback: '',
      ).toLowerCase();

      return status == 'success' || status == 'paid';
    }

    return false;
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Endpoint ini hanya mengambil event milik Admin Event
      // yang sedang login.
      final myEvents = await ApiService.getMyEvents();

      // Endpoint ini dibatasi backend berdasarkan kepemilikan event.
      final allOrders = await ApiService.getAdminOrders();

      // Daftar ID event milik Admin Event yang sedang login.
      final myEventIds = myEvents
          .map((event) => _toInt(event['id'] ?? event['event_id']))
          .whereType<int>()
          .toSet();

      // Hanya mengambil pesanan dari event milik akun ini.
      final myOrders = allOrders.where((order) {
        final eventId = _getEventId(order);

        return eventId != null && myEventIds.contains(eventId);
      }).toList();

      if (!mounted) return;

      setState(() {
        _events = myEvents;
        _orders = myOrders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getPaidOrders(int eventId) {
    return _orders.where((order) {
      return _getEventId(order) == eventId && _isPaid(order);
    }).toList();
  }

  int _getTicketsSold(int eventId) {
    return _getPaidOrders(eventId).fold<int>(
      0,
      (total, order) {
        final quantity = _toInt(
              order['quantity'] ?? order['ticket_quantity'],
            ) ??
            0;

        return total + quantity;
      },
    );
  }

  double _getRevenue(int eventId) {
    return _getPaidOrders(eventId).fold<double>(
      0,
      (total, order) {
        final amount = _toDouble(
          order['total_price'] ??
              order['total_amount'] ??
              order['total'] ??
              order['amount'],
        );

        return total + amount;
      },
    );
  }

  String _formatRupiah(num value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      final remaining = text.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp ${buffer.toString()}';
  }

  String _eventStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu Persetujuan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _eventStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primary,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final eventId = _toInt(event['id'] ?? event['event_id']);

    if (eventId == null) {
      return const SizedBox.shrink();
    }

    final name = _readValue(
      event,
      ['name', 'title'],
      fallback: 'Tanpa nama',
    );

    final status = _readValue(
      event,
      ['approval_status'],
      fallback: 'pending',
    );

    final paidOrders = _getPaidOrders(eventId);
    final ticketsSold = _getTicketsSold(eventId);
    final revenue = _getRevenue(eventId);
    final fee = revenue * _platformFeeRate;
    final netIncome = revenue - fee;

    final color = _eventStatusColor(status);

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _eventStatus(status),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _detailRow(
              'Jumlah Pesanan Lunas',
              '${paidOrders.length}',
            ),
            _detailRow(
              'Tiket Terjual',
              '$ticketsSold tiket',
            ),
            _detailRow(
              'Total Omzet',
              _formatRupiah(revenue),
            ),
            _detailRow(
              'Biaya Platform (5%)',
              _formatRupiah(fee),
            ),
            const Divider(
              color: Colors.white24,
              height: 22,
            ),
            _detailRow(
              'Pendapatan Bersih (95%)',
              _formatRupiah(netIncome),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.greenAccent : Colors.white,
              fontSize: 12,
              fontWeight:
                  highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final approvedEvents = _events.where((event) {
      return event['approval_status']?.toString().toLowerCase() ==
          'approved';
    }).toList();

    final totalPaidOrders = approvedEvents.fold<int>(
      0,
      (total, event) {
        final id = _toInt(event['id'] ?? event['event_id']);

        if (id == null) return total;

        return total + _getPaidOrders(id).length;
      },
    );

    final totalTickets = approvedEvents.fold<int>(
      0,
      (total, event) {
        final id = _toInt(event['id'] ?? event['event_id']);

        if (id == null) return total;

        return total + _getTicketsSold(id);
      },
    );

    final totalRevenue = approvedEvents.fold<double>(
      0,
      (total, event) {
        final id = _toInt(event['id'] ?? event['event_id']);

        if (id == null) return total;

        return total + _getRevenue(id);
      },
    );

    final totalFee = totalRevenue * _platformFeeRate;
    final totalNet = totalRevenue - totalFee;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ringkasan Laporan Saya',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        _summaryCard(
          'Total Event Saya',
          '${_events.length}',
          Icons.event,
        ),

        _summaryCard(
          'Pesanan Lunas',
          '$totalPaidOrders',
          Icons.receipt_long,
        ),

        _summaryCard(
          'Tiket Terjual',
          '$totalTickets',
          Icons.confirmation_number,
        ),

        _summaryCard(
          'Total Omzet',
          _formatRupiah(totalRevenue),
          Icons.account_balance_wallet,
        ),

        _summaryCard(
          'Biaya Platform (5%)',
          _formatRupiah(totalFee),
          Icons.percent,
        ),

        _summaryCard(
          'Pendapatan Bersih',
          _formatRupiah(totalNet),
          Icons.payments,
        ),

        const SizedBox(height: 20),

        const Text(
          'Laporan Per Event Saya',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (_events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Anda belum memiliki event.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ..._events.map(_eventCard),

        const SizedBox(height: 20),

        const Text(
          '* Pendapatan dihitung dari pesanan berstatus lunas. '
          'Biaya platform 5% merupakan perhitungan laporan.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Laporan Event Saya'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang laporan',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 45,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat laporan:\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReports,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: _buildReportContent(),
                ),
    );
  }
}

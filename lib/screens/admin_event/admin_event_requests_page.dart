
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import 'admin_event_drawer_page.dart';

class AdminEventRequestsPage extends StatefulWidget {
  const AdminEventRequestsPage({super.key});

  @override
  State<AdminEventRequestsPage> createState() =>
      _AdminEventRequestsPageState();
}

class _AdminEventRequestsPageState
    extends State<AdminEventRequestsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getMyEvents();

      if (!mounted) return;

      setState(() {
        _events = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadRequests();
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

  String _status(Map<String, dynamic> event) {
    return _readValue(
      event,
      ['approval_status', 'status'],
      fallback: 'pending',
    ).toLowerCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
        return 'Menunggu Persetujuan';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
        return Colors.orangeAccent;
      default:
        return Colors.white70;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.year}';
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> event) {
    final status = _status(event);

    final eventName = _readValue(
      event,
      ['name', 'title'],
      fallback: 'Event tanpa nama',
    );

    final eventDate = _formatDate(
      event['event_date'] ??
          event['start_date'] ??
          event['date'],
    );

    final rejectionReason = _readValue(
      event,
      [
        'rejection_reason',
        'admin_event_rejection_reason',
      ],
      fallback: '',
    );

    final isCancelled = event['is_cancelled'] == true;
    final isDeleted = event['is_deleted'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_note,
                  color: AppTheme.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Tanggal event: $eventDate',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Divider(
            color: Colors.white12,
            height: 1,
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Pengajuan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),

          if (isCancelled || isDeleted) ...[
            const SizedBox(height: 12),
            Text(
              isDeleted
                  ? 'Event telah dihapus.'
                  : 'Event telah dibatalkan.',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ],

          if (status == 'rejected' &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.redAccent,
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Alasan Penolakan',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    rejectionReason,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'pending') ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Pengajuan event sedang menunggu persetujuan Super Admin.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'approved') ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 16,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Event telah disetujui oleh Super Admin.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 65,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 15),
            const Text(
              'Belum Ada Pengajuan Event',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Pengajuan event yang kamu buat akan ditampilkan di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Pengajuan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const AdminEventDrawerPage(),
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        title: const Text(
          'Pengajuan Perubahan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: _events.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height *
                                      0.55,
                              child: _buildEmpty(),
                            ),
                          ],
                        )
                      : ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(
                                bottom: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Halaman ini menampilkan status persetujuan event milikmu. '
                                      'Pengajuan perubahan detail event, kelas tiket, dan penghapusan '
                                      'secara terpisah akan ditampilkan setelah endpoint riwayat pengajuan tersedia.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ..._events.map(_buildRequestCard),
                          ],
                        ),
                ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_theme.dart';
import '../../core/currency_formatter.dart';
import 'admin_event_drawer_page.dart';

class AdminEventRequestsPage extends StatefulWidget {
  const AdminEventRequestsPage({super.key});

  @override
  State<AdminEventRequestsPage> createState() =>
      _AdminEventRequestsPageState();
}

class _AdminEventRequestsPageState extends State<AdminEventRequestsPage> {
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'event', 'ticket', 'deletion'

  List<Map<String, dynamic>> _requests = [];

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
      final result = await ApiService.getMyRequests();

      if (!mounted) return;

      setState(() {
        _requests = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
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

  String _status(Map<String, dynamic> req) {
    return _readValue(
      req,
      ['status'],
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

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value.toString().trim());
    if (parsed == null) return value.toString();

    final wib = parsed.toUtc().add(const Duration(hours: 7));
    final day = wib.day.toString().padLeft(2, '0');
    final month = wib.month.toString().padLeft(2, '0');
    final year = wib.year.toString();
    final hour = wib.hour.toString().padLeft(2, '0');
    final minute = wib.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute WIB';
  }

  String _formatFieldLabel(String key) {
    switch (key) {
      case 'title':
      case 'name':
        return 'Nama Event';
      case 'description':
        return 'Deskripsi';
      case 'location':
      case 'venue':
        return 'Lokasi';
      case 'event_date':
      case 'start_date':
        return 'Tanggal Mulai';
      case 'end_date':
        return 'Tanggal Selesai';
      case 'price':
        return 'Harga';
      case 'available_tickets':
        return 'Tiket Tersedia';
      default:
        return key;
    }
  }

  String _formatFieldValue(String key, dynamic value) {
    if (value == null) return '-';
    if (key == 'price') {
      final parsed = num.tryParse(value.toString());
      return parsed != null ? formatRupiah(parsed) : value.toString();
    }
    if (key == 'event_date' || key == 'start_date' || key == 'end_date') {
      return _formatDateTime(value);
    }
    return value.toString();
  }

  bool _hasEventChanges(Map<String, dynamic> req) {
    final rawProposed = req['proposed_data'];
    if (rawProposed is! Map) return false;
    final eventMap = rawProposed['event'];
    return eventMap is Map && eventMap.isNotEmpty;
  }

  bool _hasTicketChanges(Map<String, dynamic> req) {
    final rawProposed = req['proposed_data'];
    if (rawProposed is! Map) return false;
    final tickets = rawProposed['ticket_classes'];
    return tickets is List && tickets.isNotEmpty;
  }

  String _targetBadgeLabel(Map<String, dynamic> req) {
    final type = _readValue(req, ['request_type'], fallback: 'update');
    if (type == 'deletion') return 'Penghapusan Event';

    final hasEvent = _hasEventChanges(req);
    final hasTicket = _hasTicketChanges(req);

    if (hasEvent && hasTicket) return 'Event & Kelas Tiket';
    if (hasTicket) return 'Kelas Tiket';
    return 'Detail Event';
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((req) {
      final type = _readValue(req, ['request_type'], fallback: 'update');
      switch (_selectedFilter) {
        case 'event':
          return type == 'update' && _hasEventChanges(req);
        case 'ticket':
          return type == 'update' && _hasTicketChanges(req);
        case 'deletion':
          return type == 'deletion';
        default:
          return true;
      }
    }).toList();
  }

  List<String> _extractChangeSummary(Map<String, dynamic> req) {
    final type = _readValue(req, ['request_type'], fallback: 'update');

    if (type == 'deletion') {
      final reason = _readValue(req, ['reason'], fallback: '').trim();
      return [
        'Alasan penghapusan: ${reason.isEmpty ? 'Tidak dicantumkan' : reason}',
      ];
    }

    final rawProposed = req['proposed_data'];
    if (rawProposed is! Map) return ['Perubahan data event'];

    final proposed = Map<String, dynamic>.from(rawProposed);
    final lines = <String>[];

    // 1. Perubahan field event
    if (proposed['event'] is Map) {
      final eventChanges = Map<String, dynamic>.from(proposed['event']);
      eventChanges.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          lines.add(
            '${_formatFieldLabel(key)}: ${_formatFieldValue(key, val)}',
          );
        }
      });
    }

    // 2. Operasi kelas tiket
    if (proposed['ticket_classes'] is List) {
      for (final item in proposed['ticket_classes']) {
        if (item is! Map) continue;
        final op = Map<String, dynamic>.from(item);
        final action = (op['action'] ?? '').toString().toLowerCase();
        final data = op['data'] is Map
            ? Map<String, dynamic>.from(op['data'])
            : <String, dynamic>{};

        final actionLabel = switch (action) {
          'create' || 'add' => 'Tambah Kelas Tiket',
          'update' => 'Ubah Kelas Tiket',
          'delete' => 'Hapus Kelas Tiket',
          _ => 'Operasi Kelas Tiket',
        };

        final name = data['name']?.toString().trim();
        final priceNum = num.tryParse(data['price']?.toString() ?? '');
        final stock = data['available_tickets']?.toString();

        final parts = <String>[];
        if (name != null && name.isNotEmpty) parts.add(name);
        if (priceNum != null) parts.add(formatRupiah(priceNum));
        if (stock != null && stock.isNotEmpty) parts.add('Stok: $stock');

        lines.add(
          parts.isEmpty ? actionLabel : '$actionLabel (${parts.join(' • ')})',
        );
      }
    }

    return lines.isEmpty ? ['Perubahan data event'] : lines;
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'Semua (${_requests.length})'),
      ('event', 'Event'),
      ('ticket', 'Kelas Tiket'),
      ('deletion', 'Penghapusan'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: filters.map((item) {
          final value = item.$1;
          final label = item.$2;
          final selected = _selectedFilter == value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = value;
                });
              },
              selectedColor: AppTheme.primary.withValues(alpha: 0.25),
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: selected ? AppTheme.primary : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
              side: BorderSide(
                color: selected
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
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

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final status = _status(req);
    final requestType = _readValue(req, ['request_type'], fallback: 'update');
    final isDeletion = requestType == 'deletion';

    final eventTitle = _readValue(
      req,
      ['event_title'],
      fallback: 'Event #${req['event_id'] ?? '-'}',
    );

    final createdAt = _formatDateTime(req['created_at']);
    final reviewedAt = _formatDateTime(req['reviewed_at']);
    final reviewerName = _readValue(req, ['reviewer_name'], fallback: '').trim();
    final rejectionReason = _readValue(
      req,
      ['rejection_reason'],
      fallback: '',
    ).trim();

    final summaryLines = _extractChangeSummary(req);

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
                  color: (isDeletion ? Colors.redAccent : AppTheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDeletion ? Icons.delete_sweep_outlined : Icons.edit_note,
                  color: isDeletion ? Colors.redAccent : AppTheme.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDeletion
                          ? 'Penghapusan: $eventTitle'
                          : 'Perubahan: $eventTitle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Diajukan: $createdAt',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _targetBadgeLabel(req),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Kotak ringkasan pengajuan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: summaryLines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $line',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
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
                    'Menunggu tinjauan dari Super Admin.',
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
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    reviewerName.isNotEmpty
                        ? 'Disetujui oleh $reviewerName ($reviewedAt).'
                        : 'Pengajuan telah disetujui oleh Super Admin.',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'rejected') ...[
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
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.redAccent,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        reviewerName.isNotEmpty
                            ? 'Ditolak oleh $reviewerName'
                            : 'Alasan Penolakan',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    rejectionReason.isNotEmpty
                        ? rejectionReason
                        : 'Tidak ada alasan penolakan yang dicantumkan.',
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
              'Belum Ada Pengajuan Perubahan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Riwayat pengajuan perubahan event, kelas tiket, maupun '
              'penghapusan event akan ditampilkan di sini.',
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
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : _requests.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.55,
                            child: _buildEmpty(),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildFilterChips(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            child: _filteredRequests.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.45,
                                        child: const Center(
                                          child: Text(
                                            'Tidak ada pengajuan pada kategori ini.',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredRequests.length,
                                    itemBuilder: (context, index) {
                                      return _buildRequestCard(
                                        _filteredRequests[index],
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
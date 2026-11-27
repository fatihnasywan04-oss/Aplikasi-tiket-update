import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';
import '../../core/currency_formatter.dart';
import 'admin_drawer_page.dart';

class AdminEventApprovalPage extends StatefulWidget {
  const AdminEventApprovalPage({super.key});

  @override
  State<AdminEventApprovalPage> createState() => _AdminEventApprovalPageState();
}

class _AdminEventApprovalPageState extends State<AdminEventApprovalPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<dynamic> _pendingEvents = [];
  List<dynamic> _updateRequests = [];
  List<dynamic> _deletionRequests = [];
  Map<int, String> _eventTitlesById = {};
  
  String _getEventTitle(int eventId) {
    return _eventTitlesById[eventId] ?? 'Event #$eventId';
  }

  final Set<String> _processingKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();

    final wib = parsed.toUtc().add(const Duration(hours: 7));
    final d = wib.day.toString().padLeft(2, '0');
    final m = wib.month.toString().padLeft(2, '0');
    final y = wib.year.toString();
    final h = wib.hour.toString().padLeft(2, '0');
    final min = wib.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min WIB';
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getPendingEvents(),
        ApiService.getEventUpdateRequests(),
        ApiService.getEventDeletionRequests(),
        ApiService.getMyEvents(),
      ]);

      if (!mounted) return;

      final titleMap = <int, String>{};
      for (final ev in results[3]) {
        final id = _toInt(ev['id']);
        final title = (ev['title'] ?? '').toString().trim();
        if (id != null && title.isNotEmpty) {
          titleMap[id] = title;
        }
      }

      setState(() {
        _eventTitlesById = titleMap;
        _pendingEvents = results[0];
        // Filter agar yang berstatus pending tampil di paling atas
        _updateRequests = results[1]
            .where(
              (item) =>
                  (item['status'] ?? '').toString().toLowerCase() == 'pending',
            )
            .toList();
        _deletionRequests = results[2]
            .where(
              (item) =>
                  (item['status'] ?? '').toString().toLowerCase() == 'pending',
            )
            .toList();
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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

Future<String?> _askRejectionReason(String title) {
    return showDialog<String>(
      context: context,
      builder: (_) => _RejectionReasonDialog(title: title),
    );
  }

  Future<void> _handleReview({
    required String key,
    required String actionType, // 'new_event' | 'update' | 'delete'
    required int targetId,
    required bool approve,
  }) async {
    if (_processingKeys.contains(key)) return;

    String? rejectionReason;
    if (!approve) {
      rejectionReason = await _askRejectionReason(
        'Tolak Pengajuan ${actionType == 'new_event'
            ? 'Event'
            : actionType == 'update'
            ? 'Perubahan'
            : 'Penghapusan'}',
      );
      if (rejectionReason == null) return;
    }

    setState(() => _processingKeys.add(key));

    try {
      final status = approve ? 'approved' : 'rejected';

      if (actionType == 'new_event') {
        await ApiService.reviewEvent(
          eventId: targetId,
          status: status,
          rejectionReason: rejectionReason,
        );
      } else if (actionType == 'update') {
        await ApiService.reviewEventUpdateRequest(
          requestId: targetId,
          status: status,
          rejectionReason: rejectionReason,
        );
      } else {
        await ApiService.reviewEventDeletionRequest(
          requestId: targetId,
          status: status,
          rejectionReason: rejectionReason,
        );
      }

      if (!mounted) return;
      _showSnack(
        approve ? 'Pengajuan berhasil disetujui.' : 'Pengajuan berhasil ditolak.',
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _processingKeys.remove(key));
      }
    }
  }

  Widget _buildActionButtons({
    required String key,
    required String actionType,
    required int targetId,
  }) {
    final isBusy = _processingKeys.contains(key);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _handleReview(
                    key: key,
                    actionType: actionType,
                    targetId: targetId,
                    approve: false,
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Tolak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy
                ? null
                : () => _handleReview(
                    key: key,
                    actionType: actionType,
                    targetId: targetId,
                    approve: true,
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(isBusy ? 'Memproses...' : 'Setujui'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1: EVENT BARU PENDING
  // ============================================================

  Widget _buildPendingEventsTab() {
    if (_pendingEvents.isEmpty) {
      return _buildEmptyState('Tidak ada pengajuan event baru saat ini.');
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingEvents.length,
        itemBuilder: (context, index) {
          final event = _pendingEvents[index];
          final eventId = _toInt(event['id'] ?? event['event_id']) ?? 0;
          final title = (event['title'] ?? event['name'] ?? 'Tanpa Judul')
              .toString();
          final category = (event['category'] ?? 'Lainnya').toString();
          final location = (event['location'] ?? '-').toString();
          final creatorId = event['created_by']?.toString() ?? '-';

          final priceRaw = event['price'] ?? event['ticket_price'];

          final requesterName = event['requester_name']?.toString().trim();
          final senderLabel = (requesterName != null && requesterName.isNotEmpty)
            ? requesterName
            : 'Admin Event #$creatorId';

          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
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
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPale,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lokasi: $location',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Mulai: ${_formatDate(event['event_date'])}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Harga: ${formatRupiah(num.tryParse(priceRaw?.toString() ?? ''))}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Pengaju: $senderLabel',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildActionButtons(
                    key: 'new_$eventId',
                    actionType: 'new_event',
                    targetId: eventId,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// ============================================================
  // TAB 2: PENGAJUAN PERUBAHAN EVENT
  // ============================================================

  String _buildUpdateCardTitle(
    int eventId,
    Map<String, dynamic> eventChanges,
    List<Map<String, dynamic>> ticketOperations,
  ) {
    final eventTitle = _getEventTitle(eventId);

    if (eventChanges.isEmpty && ticketOperations.length == 1) {
      final action =
          (ticketOperations.first['action'] ?? '').toString().toLowerCase();
      if (action == 'create') {
        return 'Penambahan Kelas Tiket (Event: $eventTitle) ';
      } else if (action == 'delete') {
        return 'Penghapusan Kelas Tiket (Event: $eventTitle)';
      } else if (action == 'update') {
        return 'Perubahan Kelas Tiket (Event: $eventTitle)';
      }
    }

    if (eventChanges.isEmpty && ticketOperations.length > 1) {
      return 'Pembaruan Kelas Tiket: $eventTitle';
    }

    return 'Perubahan Event: $eventTitle';
  }
  
List<String> _formatTicketOperationLines(
    Map<String, dynamic> op, {
    bool showActionHeader = false,
  }) {
    final action = (op['action'] ?? '').toString().toLowerCase();
    final data = op['data'] is Map
        ? Map<String, dynamic>.from(op['data'])
        : <String, dynamic>{};

    final name = data['name']?.toString().trim();
    final price = data['price']?.toString();
    final stock = data['available_tickets']?.toString();

   final lines = <String>[
      if (showActionHeader)
        switch (action) {
          'create' => 'Tambah Kelas Tiket:',
          'update' => 'Ubah Kelas Tiket:',
          'delete' => 'Hapus Kelas Tiket',
          _ => 'Operasi: $action',
        },
      if (name != null && name.isNotEmpty) 'Nama: $name',
      if (price != null && price.isNotEmpty)
        'Harga: ${formatRupiah(num.tryParse(price))}',
      if (stock != null && stock.isNotEmpty) 'Stok: $stock',
    ];

    if (lines.isEmpty) {
      return ['Operasi kelas tiket ($action)'];
    }

    return lines;
  }

  String _formatChangeValue(String key, dynamic value) {
    final normalized = key.toLowerCase();

    if (normalized.contains('price') || normalized == 'harga') {
      return formatRupiah(num.tryParse(value?.toString() ?? ''));
    }

    return value?.toString() ?? '-';
  }

  Widget _buildUpdateRequestsTab() {
    if (_updateRequests.isEmpty) {
      return _buildEmptyState('Tidak ada pengajuan perubahan event saat ini.');
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _updateRequests.length,
        itemBuilder: (context, index) {
          final req = _updateRequests[index];
          final requestId = _toInt(req['id']) ?? 0;
          final eventId = _toInt(req['event_id']) ?? 0;
          final requestedBy = req['requested_by']?.toString() ?? '-';
          final requesterName = req['requester_name']?.toString().trim();
          final senderLabel = (requesterName != null && requesterName.isNotEmpty)
              ? requesterName
              : 'User #$requestedBy';

          final proposed = req['proposed_data'] is Map
              ? Map<String, dynamic>.from(req['proposed_data'])
              : <String, dynamic>{};
          final eventChanges = proposed['event'] is Map
              ? Map<String, dynamic>.from(proposed['event'])
              : <String, dynamic>{};
         final List<Map<String, dynamic>> ticketOperations = proposed['ticket_classes'] is List
              ? (proposed['ticket_classes'] as List)
                  .whereType()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : [];
              
          final hasChanges =
              eventChanges.isNotEmpty || ticketOperations.isNotEmpty;

          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _buildUpdateCardTitle(
                      eventId,
                      eventChanges,
                      ticketOperations,
                    ),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diajukan oleh $senderLabel • ${_formatDate(req['created_at'])}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: !hasChanges
                        ? const Text(
                            'Tidak ada detail field perubahan.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eventChanges.isNotEmpty) ...[
                                ...eventChanges.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• ${entry.key}: ${_formatChangeValue(entry.key, entry.value)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              if (eventChanges.isNotEmpty &&
                                  ticketOperations.isNotEmpty)
                                const SizedBox(height: 8),
                              if (ticketOperations.isNotEmpty) ...[
                                ...ticketOperations.expand((op) {
                                  final needHeader =
                                      eventChanges.isNotEmpty ||
                                      ticketOperations.length > 1;
                                  final lines = _formatTicketOperationLines(
                                    op,
                                    showActionHeader: needHeader,
                                  );
                                  return lines.map((line) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• $line',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  });
                                }),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _buildActionButtons(
                    key: 'upd_$requestId',
                    actionType: 'update',
                    targetId: requestId,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // TAB 3: PENGAJUAN PENGHAPUSAN EVENT
  // ============================================================

  Widget _buildDeletionRequestsTab() {
    if (_deletionRequests.isEmpty) {
      return _buildEmptyState(
        'Tidak ada pengajuan penghapusan event saat ini.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deletionRequests.length,
        itemBuilder: (context, index) {
          final req = _deletionRequests[index];
          final requestId = _toInt(req['id']) ?? 0;
          final eventId = _toInt(req['event_id']) ?? 0;
          final requestedBy = req['requested_by']?.toString() ?? '-';
          final reason = (req['reason'] ?? '').toString().trim();

          final requesterName = req['requester_name']?.toString().trim();
          final senderLabel = (requesterName != null && requesterName.isNotEmpty)
              ? requesterName
              : 'User #$requestedBy';

          final eventMap = req['event'] is Map
              ? Map<String, dynamic>.from(req['event'])
              : <String, dynamic>{};
          final rawTitle =
              (req['event_title'] ?? eventMap['title'] ?? '').toString().trim();
          final eventTitle =
              rawTitle.isNotEmpty ? rawTitle : 'Event #$eventId';

          final rawEventDate =
              (req['event_date'] ?? eventMap['event_date'] ?? eventMap['date'] ?? '')
                  .toString()
                  .trim();
          final rawLocation =
              (req['event_location'] ?? eventMap['location'] ?? '')
                  .toString()
                  .trim();

          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penghapusan Event $eventTitle',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diajukan oleh $senderLabel • ${_formatDate(req['created_at'])}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Nama Event: $eventTitle',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (rawEventDate.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '• Tanggal: ${_formatDate(rawEventDate)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (rawLocation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '• Lokasi: $rawLocation',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '• Alasan: ${reason.isEmpty ? 'Tidak dicantumkan' : reason}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildActionButtons(
                    key: 'del_$requestId',
                    actionType: 'delete',
                    targetId: requestId,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawerPage(currentRoute: '/admin/review-events'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: const Text(
          'Review Event & Tiket',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Event Baru (${_pendingEvents.length})'),
            Tab(text: 'Perubahan (${_updateRequests.length})'),
            Tab(text: 'Penghapusan (${_deletionRequests.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingEventsTab(),
                _buildUpdateRequestsTab(),
                _buildDeletionRequestsTab(),
              ],
            ),
    );
  }
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog({required this.title});

  final String title;

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.text, fontSize: 18),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          maxLines: 3,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan *',
            hintText: 'Jelaskan alasan penolakan secara singkat...',
            filled: true,
            fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Alasan penolakan wajib diisi.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('Tolak Pengajuan'),
        ),
      ],
    );
  }
}
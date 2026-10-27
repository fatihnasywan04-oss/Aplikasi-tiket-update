import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/app_colors.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // MEMUAT DATA PESANAN
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getMyOrders();

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
  // HELPER DATA
  // ============================================================

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is Map || value is List) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null' &&
          text.toLowerCase() != 'none') {
        return text;
      }
    }

    return fallback;
  }

  String _firstText(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final source in sources) {
      final value = _text(source, keys, fallback: '');

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;

    var text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    // Mendukung angka seperti 150000, "150000",
    // dan format desimal umum.
    text = text.replaceAll(' ', '');

    if (text.contains(',') && text.contains('.')) {
      // Contoh 1.500,50
      if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
        text = text.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Contoh 1,500.50
        text = text.replaceAll(',', '');
      }
    } else if (text.contains(',')) {
      final parts = text.split(',');
      if (parts.length == 2 && parts.last.length <= 2) {
        text = text.replaceAll(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    }

    return double.tryParse(text);
  }

  String _money(dynamic value) {
    final amount = _number(value);

    if (amount == null) return '-';

    final rounded = amount.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return 'Rp ${rounded < 0 ? '-' : ''}$buffer';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(text);
  }

  String _date(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      if (value == null || value.toString().trim().isEmpty) {
        return '-';
      }

      // Jika API mengirim tanggal dalam format lain,
      // tampilkan nilai aslinya daripada menghilangkan data.
      return value.toString();
    }

    final date = parsed.toLocal();

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _dateTime(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      if (value == null || value.toString().trim().isEmpty) {
        return '-';
      }

      return value.toString();
    }

    final date = parsed.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${_date(date.toIso8601String())} • $hour:$minute';
  }

  String _time(dynamic value) {
    if (value == null) return '-';

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    final parsed = _parseDate(value);

    if (parsed != null) {
      final date = parsed.toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    // Mendukung waktu yang dikirim terpisah, misalnya 19:30:00.
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);

    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
    }

    return text;
  }

  String _combineDateTime({
    required dynamic dateValue,
    required dynamic timeValue,
  }) {
    final dateText = _text(
      {'value': dateValue},
      ['value'],
      fallback: '',
    );

    final timeText = _text(
      {'value': timeValue},
      ['value'],
      fallback: '',
    );

    if (dateText.isEmpty) return '-';

    // Jika tanggal sudah mengandung jam, gunakan tanggal itu.
    final parsedDate = _parseDate(dateValue);

    if (parsedDate != null) {
      final hasTime = parsedDate.hour != 0 ||
          parsedDate.minute != 0 ||
          parsedDate.second != 0;

      if (hasTime) {
        return _dateTime(dateValue);
      }
    }

    if (timeText.isEmpty) {
      return _date(dateValue);
    }

    return '${_date(dateValue)} • ${_time(timeValue)}';
  }

  // ============================================================
  // STATUS PESANAN DAN PEMBAYARAN
  // ============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
      case 'confirmed':
      case 'success':
      case 'successful':
      case 'completed':
        return AppColors.success;

      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'expired':
      case 'rejected':
        return AppColors.error;

      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'paid':
        return 'Sudah dibayar';

      case 'confirmed':
        return 'Dikonfirmasi';

      case 'success':
      case 'successful':
      case 'completed':
        return 'Berhasil';

      case 'pending':
        return 'Menunggu pembayaran';

      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';

      case 'failed':
        return 'Gagal';

      case 'expired':
        return 'Kedaluwarsa';

      case 'rejected':
        return 'Ditolak';

      case 'unpaid':
        return 'Belum dibayar';

      case 'unknown':
      case '-':
      case '':
        return 'Status tidak tersedia';

      default:
        return status;
    }
  }

  Widget _statusChip(String label, String rawStatus) {
    final color = _statusColor(rawStatus);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // KOMPONEN TAMPILAN
  // ============================================================

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionalRow(
    String label,
    String value,
  ) {
    if (value.isEmpty || value == '-') {
      return const SizedBox.shrink();
    }

    return _detailRow(label, value);
  }

  // ============================================================
  // KARTU TIKET
  // ============================================================

  Widget _ticketCard(Map<String, dynamic> order) {
    final event = _map(order['event']);

    // Kelas tiket harus berasal dari pesanan yang bersangkutan.
    // Jangan mengambil kelas default dari daftar kelas event.
    final ticketClass = _map(
      order['ticket_class'] ??
          order['ticketClass'] ??
          order['ticket_class_detail'],
    );

    final user = _map(
      order['user'] ?? order['buyer'],
    );

    final payment = _map(
      order['payment'] ??
          order['latest_payment'] ??
          order['latestPayment'],
    );

    final orderId = _firstText(
      [order],
      ['id', 'order_id'],
    );

    final eventName = _firstText(
      [event, order],
      [
        'title',
        'event_title',
        'event_name',
        'name',
        'nama_event',
      ],
      fallback: 'Event tidak diketahui',
    );

    // Mendukung tanggal event dengan beberapa nama field.
    final eventDate = _firstText(
      [event, order],
      [
        'event_date',
        'date',
        'tanggal',
        'start_date',
        'event_start_date',
        'start_datetime',
        'start_at',
        'starts_at',
      ],
      fallback: '',
    );

    final eventStartTime = _firstText(
      [event, order],
      [
        'event_start_time',
        'start_time',
        'time',
        'waktu',
        'jam_mulai',
      ],
      fallback: '',
    );

    final eventEndDate = _firstText(
      [event, order],
      [
        'end_date',
        'event_end_date',
        'end_datetime',
        'end_at',
        'ends_at',
      ],
      fallback: '',
    );

    final eventEndTime = _firstText(
      [event, order],
      [
        'event_end_time',
        'end_time',
        'jam_selesai',
      ],
      fallback: '',
    );

    final eventLocation = _firstText(
      [event, order],
      [
        'location',
        'venue',
        'address',
        'event_location',
        'lokasi',
        'place',
      ],
    );

    final eventAddress = _firstText(
      [event, order],
      [
        'full_address',
        'event_address',
        'venue_address',
        'alamat',
        'address_detail',
      ],
      fallback: '',
    );

    final description = _firstText(
      [event, order],
      [
        'description',
        'event_description',
        'deskripsi',
      ],
      fallback: '',
    );

    // Ambil nama kelas dari relasi ticket_class terlebih dahulu.
    // Jika relasi tidak dikirim, gunakan nama kelas yang tersimpan
    // pada order. ticket_class_id saja bukan nama kelas.
    final ticketName = _firstText(
      [ticketClass, order],
      [
        'name',
        'ticket_class_name',
        'class_name',
        'ticket_name',
        'ticket_type',
      ],
      fallback: 'Kelas tiket tidak tersedia',
    );

    final quantityValue = _firstText(
      [order],
      [
        'quantity',
        'ticket_quantity',
        'qty',
      ],
      fallback: '0',
    );

    final quantity = _number(quantityValue) ?? 0;

    final orderStatus = _text(
      order,
      ['status', 'order_status'],
      fallback: 'unknown',
    );

    final paymentStatus = _firstText(
      [payment, order],
      [
        'payment_status',
        'status_pembayaran',
      ],
      fallback: 'Belum ada informasi pembayaran',
    );

    final totalValue = _firstText(
      [order, payment],
      [
        'total_price',
        'total_amount',
        'amount',
        'total',
      ],
      fallback: '',
    );

    // Prioritas harga satuan:
    // harga yang tersimpan pada detail kelas pesanan,
    // lalu harga tiket yang tersimpan di order.
    final unitPriceValue = _firstText(
      [ticketClass, order],
      [
        'price',
        'ticket_price',
        'unit_price',
        'price_per_ticket',
      ],
      fallback: '',
    );

    final total = _number(totalValue);
    final unitPrice = _number(unitPriceValue);

    // Jika harga satuan tidak tersedia, hitung dari total / jumlah.
    final calculatedUnitPrice =
        unitPrice ??
        (total != null && quantity > 0 ? total / quantity : null);

    final createdAt = _firstText(
      [order],
      [
        'created_at',
        'order_date',
        'ordered_at',
      ],
      fallback: '',
    );

    final buyerName = _firstText(
      [user, order],
      [
        'name',
        'full_name',
        'user_name',
        'buyer_name',
        'nama_pemesan',
      ],
    );

    final buyerEmail = _firstText(
      [user, order],
      [
        'email',
        'user_email',
        'buyer_email',
      ],
    );

    final imageUrl = _firstText(
      [event, order],
      [
        'image_url',
        'event_image',
        'poster_url',
        'image',
        'poster',
      ],
      fallback: '',
    );

    final paymentMethod = _firstText(
      [payment, order],
      [
        'payment_method',
        'method',
        'metode_pembayaran',
      ],
      fallback: '',
    );

    final transactionId = _firstText(
      [payment, order],
      [
        'transaction_id',
        'payment_id',
      ],
      fallback: '',
    );

    final paidAt = _firstText(
      [payment, order],
      ['paid_at', 'payment_date'],
      fallback: '',
    );

    final eventDateDisplay = eventDate.isEmpty
        ? '-'
        : _combineDateTime(
            dateValue: eventDate,
            timeValue: eventStartTime,
          );

    final eventEndDisplay = eventEndDate.isNotEmpty
        ? _combineDateTime(
            dateValue: eventEndDate,
            timeValue: eventEndTime,
          )
        : eventEndTime.isNotEmpty
            ? _time(eventEndTime)
            : '-';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey('order_$orderId'),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            18,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: AppColors.primary,
              size: 27,
            ),
          ),
          title: Text(
            eventName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesanan #$orderId',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                _statusChip(
                  _statusLabel(orderStatus),
                  orderStatus,
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 20),

            if (imageUrl.startsWith('https://') ||
                imageUrl.startsWith('http://'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),

            // ---------------- EVENT ----------------

            _sectionTitle(
              'Informasi event',
              Icons.event_rounded,
            ),
            _detailRow('Nama event', eventName),
            _detailRow('Tanggal dan waktu', eventDateDisplay),
            _detailRow('Waktu selesai', eventEndDisplay),
            _detailRow('Lokasi', eventLocation),
            _optionalRow('Alamat lengkap', eventAddress),
            _optionalRow('Deskripsi', description),

            // ---------------- TIKET ----------------

            _sectionTitle(
              'Informasi tiket',
              Icons.confirmation_number_outlined,
            ),
            _detailRow('Nomor pesanan', '#$orderId'),
            _detailRow('Kelas tiket', ticketName),
            _detailRow(
              'Jumlah tiket',
              '${quantity.toStringAsFixed(0)} tiket',
            ),
            _detailRow(
              'Harga satuan',
              calculatedUnitPrice == null
                  ? '-'
                  : _money(calculatedUnitPrice),
            ),
            _detailRow(
              'Total pembayaran',
              total == null ? '-' : _money(total),
              bold: true,
            ),
            _optionalRow(
              'Waktu pemesanan',
              createdAt.isEmpty ? '-' : _dateTime(createdAt),
            ),

            // ---------------- PEMESAN ----------------

            _sectionTitle(
              'Informasi pemesan',
              Icons.person_outline_rounded,
            ),
            _detailRow('Nama pemesan', buyerName),
            _detailRow('Email pemesan', buyerEmail),

            // ---------------- PEMBAYARAN ----------------

            _sectionTitle(
              'Informasi pembayaran',
              Icons.payment_rounded,
            ),
            _detailRow(
              'Status pesanan',
              _statusLabel(orderStatus),
            ),
            _detailRow(
              'Status pembayaran',
              paymentStatus == 'Belum ada informasi pembayaran'
                  ? paymentStatus
                  : _statusLabel(paymentStatus),
            ),
            _optionalRow('Metode pembayaran', paymentMethod),
            _optionalRow('ID transaksi', transactionId),
            _optionalRow(
              'Waktu pembayaran',
              paidAt.isEmpty ? '-' : _dateTime(paidAt),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAMPILAN LOADING, ERROR, KOSONG, DAN DAFTAR TIKET
  // ============================================================

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat tiket',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
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

  Widget _emptyView() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Icon(
            Icons.confirmation_number_outlined,
            size: 58,
            color: AppColors.primaryLight,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Belum ada tiket',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Pesananmu akan muncul di halaman ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _ticketCard(_orders[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tiket Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _error != null
              ? _errorView()
              : _orders.isEmpty
                  ? _emptyView()
                  : _ticketList(),
    );
  }
}
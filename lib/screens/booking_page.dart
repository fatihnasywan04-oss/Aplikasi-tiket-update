
import 'package:flutter/material.dart';
import '../api_service.dart';
import 'payment_page.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const BookingPage({
    super.key,
    required this.event,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int quantity = 1;
  bool submitting = false;
  String? errorMessage;

  static const Color primaryColor = Color(0xFF5B50E8);

  int get eventId {
    final value = widget.event['id'];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  num get ticketPrice {
    return num.tryParse('${widget.event['price'] ?? 0}') ?? 0;
  }

  num get totalPrice => ticketPrice * quantity;

  String rupiah(num value) {
    final digits = value.round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp $formatted';
  }

  Future<void> createBooking() async {
    if (submitting) return;

    if (eventId <= 0) {
      setState(() {
        errorMessage = 'ID event tidak valid.';
      });
      return;
    }

    if (ticketPrice <= 0) {
      setState(() {
        errorMessage = 'Harga tiket tidak valid.';
      });
      return;
    }

    if (quantity < 1 || quantity > 10) {
      setState(() {
        errorMessage = 'Jumlah tiket harus antara 1 sampai 10.';
      });
      return;
    }

    setState(() {
      submitting = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.createOrder(
        eventId: eventId,
        quantity: quantity,
      );

      if (!mounted) return;

      final orderIdValue = result['id'] ?? result['order_id'];

      final orderId = orderIdValue is int
          ? orderIdValue
          : int.tryParse('$orderIdValue') ?? 0;

      if (orderId <= 0) {
        setState(() {
          submitting = false;
          errorMessage =
              'ID pesanan tidak ditemukan pada respons backend. '
              'Periksa respons endpoint /orders/.';
        });
        return;
      }

      final selectedQuantity = quantity;
      final selectedTotalPrice = totalPrice.toDouble();
      final selectedTitle =
          widget.event['title']?.toString() ?? 'Tanpa judul';

      setState(() {
        submitting = false;
      });

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: orderId,
            totalPrice: selectedTotalPrice,
            eventTitle: selectedTitle,
            quantity: selectedQuantity,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
      });
    } finally {
      if (mounted && submitting) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title']?.toString() ?? 'Tanpa judul';

    final location =
        widget.event['location']?.toString() ??
        'Lokasi belum tersedia';

    final description =
        widget.event['description']?.toString() ??
        'Tidak ada deskripsi event.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Pemesanan Tiket'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Konfirmasi Pesanan',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Periksa detail event dan tentukan jumlah tiket '
              'yang ingin kamu pesan.',
              style: TextStyle(
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEAFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_available,
                        size: 64,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(location)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${rupiah(ticketPrice)} / tiket',
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Jumlah Tiket',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tiket',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kurangi tiket',
                      onPressed: submitting || quantity <= 1
                          ? null
                          : () {
                              setState(() {
                                quantity--;
                                errorMessage = null;
                              });
                            },
                      icon: const Icon(
                        Icons.remove_circle_outline,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tambah tiket',
                      onPressed: submitting || quantity >= 10
                          ? null
                          : () {
                              setState(() {
                                quantity++;
                                errorMessage = null;
                              });
                            },
                      icon: const Icon(
                        Icons.add_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              color: const Color(0xFFF3F1FF),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Harga per tiket',
                      rupiah(ticketPrice),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Jumlah tiket',
                      '$quantity tiket',
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Harga',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          rupiah(totalPrice),
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.shade200,
                  ),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: submitting ? null : createBooking,
                icon: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.confirmation_number_outlined,
                      ),
                label: Text(
                  submitting
                      ? 'Memproses Pesanan...'
                      : 'Buat Pesanan',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class TicketPdfService {
  static Future<void> shareTicket({
    required String eventName,
    required String customerName,
    required String ticketName,
    required String ticketCode,
    required String eventDate,
    required String eventLocation,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EVENT TICKETERS',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  eventName,
                  style: pw.TextStyle(
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Nama: $customerName'),
                pw.Text('Kategori Tiket: $ticketName'),
                pw.Text('Tanggal: $eventDate'),
                pw.Text('Lokasi: $eventLocation'),
                pw.SizedBox(height: 25),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: ticketCode,
                    width: 150,
                    height: 150,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    ticketCode,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 25),
                pw.Text(
                  'Tunjukkan QR Code ini kepada petugas '
                  'untuk validasi tiket.',
                ),
              ],
            ),
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'tiket_$ticketCode.pdf',
    );
  }
}

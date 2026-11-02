
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketPdfService {
  // ============================================================
  // MEMBUAT DATA PDF TIKET
  // ============================================================

  static Future<Uint8List> _generateTicket({
    required String eventName,
    required String customerName,
    required String customerEmail,
    required String ticketName,
    required String ticketCode,
    required String eventDate,
    required String eventLocation,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.deepPurple,
                width: 2,
              ),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'EVENT TICKETERS',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.deepPurple),
                pw.SizedBox(height: 20),
                pw.Text(
                  eventName,
                  style: pw.TextStyle(
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 24),
                _detail('Nama pemesan', customerName),
                _detail('Email pemesan', customerEmail),
                _detail('Kategori tiket', ticketName),
                _detail('Tanggal event', eventDate),
                _detail('Lokasi event', eventLocation),
                _detail('Kode tiket', ticketCode),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: ticketCode,
                    width: 150,
                    height: 150,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    ticketCode,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    'Tunjukkan QR Code ini kepada petugas '
                    'untuk validasi tiket.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Simpan tiket ini sebagai bukti pemesanan.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // DETAIL BARIS PDF
  // ============================================================

  static pw.Widget _detail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 115,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.Text(': '),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOWNLOAD / SIMPAN PDF KE FOLDER DOWNLOAD ANDROID
  // ============================================================

  static Future<void> downloadTicket({
    required String eventName,
    required String customerName,
    required String customerEmail,
    required String ticketName,
    required String ticketCode,
    required String eventDate,
    required String eventLocation,
  }) async {
    final Uint8List bytes = await _generateTicket(
      eventName: eventName,
      customerName: customerName,
      customerEmail: customerEmail,
      ticketName: ticketName,
      ticketCode: ticketCode,
      eventDate: eventDate,
      eventLocation: eventLocation,
    );

    final safeTicketCode = ticketCode.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    await FileSaver.instance.saveToDownloads(
      name: 'Tiket_$safeTicketCode',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      subfolder: 'EventTicketers',
    );
  }

  // ============================================================
  // BAGIKAN PDF
  // Fungsi ini tetap dipertahankan.
  // ============================================================

  static Future<void> shareTicket({
    required String eventName,
    required String customerName,
    required String customerEmail,
    required String ticketName,
    required String ticketCode,
    required String eventDate,
    required String eventLocation,
  }) async {
    final Uint8List bytes = await _generateTicket(
      eventName: eventName,
      customerName: customerName,
      customerEmail: customerEmail,
      ticketName: ticketName,
      ticketCode: ticketCode,
      eventDate: eventDate,
      eventLocation: eventLocation,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'tiket_$ticketCode.pdf',
    );
  }
}

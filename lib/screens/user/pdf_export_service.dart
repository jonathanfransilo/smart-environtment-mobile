import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'riwayat_pembayaran_service.dart';

class PdfExportService {
  static Future<File> generateRiwayatPembayaranPdf(
    List<Map<String, dynamic>> riwayatList,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Separate payments and waste pickups
    final payments = riwayatList
        .where((item) => item.containsKey('order_id'))
        .toList();
    final wastePickups = riwayatList
        .where((item) => !item.containsKey('order_id'))
        .toList();

    // Calculate totals
    double totalPayments = 0;
    for (final payment in payments) {
      if (payment['status'] == 'success') {
        totalPayments += ((payment['amount'] ?? 0) as num).toDouble();
      }
    }

    double totalWastePickups = 0;
    for (final pickup in wastePickups) {
      totalWastePickups += ((pickup['totalHarga'] ?? 0) as num).toDouble();
    }

    final totalKeseluruhan = totalPayments + totalWastePickups;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(fontBold, font),
            pw.SizedBox(height: 20),
            _buildSummary(
              payments.length + wastePickups.length,
              totalKeseluruhan,
              totalPayments,
              totalWastePickups,
              font,
              fontBold,
            ),
            pw.SizedBox(height: 30),

            // Payment transactions section
            if (payments.isNotEmpty) ...[
              _buildSectionTitle('PEMBAYARAN TAGIHAN', fontBold),
              pw.SizedBox(height: 10),
              _buildPaymentTableHeader(fontBold),
              ..._buildPaymentTableContent(payments, font),
              pw.SizedBox(height: 20),
            ],

            // Waste pickup transactions section
            if (wastePickups.isNotEmpty) ...[
              _buildSectionTitle('PENGAMBILAN SAMPAH (LOKAL)', fontBold),
              pw.SizedBox(height: 10),
              _buildTableHeader(fontBold),
              ..._buildTableContent(wastePickups, font),
            ],

            pw.SizedBox(height: 30),
            _buildFooter(font),
          ];
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File(
      '${output.path}/riwayat_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildHeader(pw.Font fontBold, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RIWAYAT PEMBAYARAN SAMPAH',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 24,
            color: PdfColors.teal700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Aplikasi Sirkular - Waste Management System',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Tanggal Cetak: ${RiwayatPembayaranService.formatDate(DateTime.now())}',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
        pw.Divider(thickness: 2, color: PdfColors.teal700),
      ],
    );
  }

  static pw.Widget _buildSummary(
    int totalTransaksi,
    double totalKeseluruhan,
    double totalPayments,
    double totalWastePickups,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.teal200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RINGKASAN PEMBAYARAN',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 16,
              color: PdfColors.teal700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Total Transaksi:',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    '$totalTransaksi transaksi',
                    style: pw.TextStyle(font: fontBold, fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Pembayaran Tagihan:',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    RiwayatPembayaranService.formatCurrency(totalPayments),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.teal600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Pengambilan Sampah:',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    RiwayatPembayaranService.formatCurrency(totalWastePickups),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.teal600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Keseluruhan:',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    RiwayatPembayaranService.formatCurrency(totalKeseluruhan),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: PdfColors.teal700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.teal700, width: 2),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 14,
          color: PdfColors.teal700,
        ),
      ),
    );
  }

  static pw.Widget _buildPaymentTableHeader(pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal700,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Tanggal',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Order ID',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Invoice',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Status',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Total',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildPaymentTableContent(
    List<Map<String, dynamic>> payments,
    pw.Font font,
  ) {
    return payments.asMap().entries.map((entry) {
      final index = entry.key;
      final payment = entry.value;
      final tanggal = DateTime.parse(
        payment['created_at'] ?? DateTime.now().toIso8601String(),
      );
      final invoice = payment['invoice'] as Map<String, dynamic>?;
      final status = payment['status'] ?? 'pending';
      final amount = (payment['amount'] ?? 0) as num;

      String statusText = '';
      PdfColor statusColor = PdfColors.grey700;

      switch (status.toLowerCase()) {
        case 'success':
          statusText = 'Lunas';
          statusColor = PdfColors.green700;
          break;
        case 'pending':
          statusText = 'Pending';
          statusColor = PdfColors.orange700;
          break;
        case 'failed':
          statusText = 'Gagal';
          statusColor = PdfColors.red700;
          break;
        case 'expired':
          statusText = 'Kadaluarsa';
          statusColor = PdfColors.red700;
          break;
        default:
          statusText = status;
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: index.isEven ? PdfColors.grey50 : PdfColors.white,
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                RiwayatPembayaranService.formatDate(tanggal),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                payment['order_id'] ?? '-',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                invoice?['invoice_number'] ?? '-',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                statusText,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: statusColor,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                RiwayatPembayaranService.formatCurrency(amount.toDouble()),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.teal700,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static pw.Widget _buildTableHeader(pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal700,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Tanggal',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Kolektor',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              'Alamat',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Items',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Total',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildTableContent(
    List<Map<String, dynamic>> riwayatList,
    pw.Font font,
  ) {
    return riwayatList.asMap().entries.map((entry) {
      final index = entry.key;
      final riwayat = entry.value;
      final tanggal = DateTime.parse(riwayat['tanggalPengambilan']);
      final items = List<Map<String, dynamic>>.from(riwayat['items'] ?? []);

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: index.isEven ? PdfColors.grey50 : PdfColors.white,
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                RiwayatPembayaranService.formatDate(tanggal),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                riwayat['namaKolektor'] ?? 'Kolektor',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.Expanded(
              flex: 4,
              child: pw.Text(
                riwayat['alamat'] ?? '',
                style: pw.TextStyle(font: font, fontSize: 10),
                maxLines: 2,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: items
                    .map(
                      (item) => pw.Text(
                        '${item['category']} (${item['quantity']}kg)',
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    )
                    .toList(),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                RiwayatPembayaranService.formatCurrency(
                  (riwayat['totalHarga'] as num).toDouble(),
                ),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.teal700,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text(
          'Dokumen ini dibuat secara otomatis oleh sistem Sirkular.',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Untuk informasi lebih lanjut, hubungi administrator sistem.',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  /// Print PDF langsung
  static Future<void> printRiwayatPembayaran(
    List<Map<String, dynamic>> riwayatList,
  ) async {
    final file = await generateRiwayatPembayaranPdf(riwayatList);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => file.readAsBytes(),
    );
  }

  /// Share PDF
  static Future<void> shareRiwayatPembayaran(
    List<Map<String, dynamic>> riwayatList,
  ) async {
    final file = await generateRiwayatPembayaranPdf(riwayatList);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename:
          'riwayat_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Share PDF to WhatsApp
  static Future<void> shareToWhatsApp(
    List<Map<String, dynamic>> riwayatList, {
    String? phoneNumber,
  }) async {
    try {
      // Generate PDF file
      final file = await generateRiwayatPembayaranPdf(riwayatList);

      // Use share functionality which will show WhatsApp as an option
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename:
            'riwayat_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      throw Exception('Gagal mengirim PDF ke WhatsApp: $e');
    }
  }
}

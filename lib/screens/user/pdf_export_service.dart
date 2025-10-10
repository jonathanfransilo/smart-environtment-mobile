import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'riwayat_pembayaran_service.dart';

class PdfExportService {
  static Future<File> generateRiwayatPembayaranPdf(List<Map<String, dynamic>> riwayatList) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    double totalKeseluruhan = 0;
    for (final riwayat in riwayatList) {
      totalKeseluruhan += (riwayat['totalHarga'] as num).toDouble();
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(fontBold, font),
            pw.SizedBox(height: 20),
            _buildSummary(riwayatList, totalKeseluruhan, font, fontBold),
            pw.SizedBox(height: 30),
            _buildTableHeader(fontBold),
            ..._buildTableContent(riwayatList, font),
            pw.SizedBox(height: 30),
            _buildFooter(font),
          ];
        },
      ),
    );
    
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/riwayat_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf');
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
          style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Tanggal Cetak: ${RiwayatPembayaranService.formatDate(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
        ),
        pw.Divider(thickness: 2, color: PdfColors.teal700),
      ],
    );
  }
  
  static pw.Widget _buildSummary(List<Map<String, dynamic>> riwayatList, double totalKeseluruhan, pw.Font font, pw.Font fontBold) {
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
            'RINGKASAN',
            style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.teal700),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Transaksi:', style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.Text('${riwayatList.length} transaksi', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Keseluruhan:', style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.Text(
                    RiwayatPembayaranService.formatCurrency(totalKeseluruhan),
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.teal700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
          pw.Expanded(flex: 2, child: pw.Text('Tanggal', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white))),
          pw.Expanded(flex: 3, child: pw.Text('Kolektor', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white))),
          pw.Expanded(flex: 4, child: pw.Text('Alamat', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white))),
          pw.Expanded(flex: 2, child: pw.Text('Items', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white))),
          pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white))),
        ],
      ),
    );
  }
  
  static List<pw.Widget> _buildTableContent(List<Map<String, dynamic>> riwayatList, pw.Font font) {
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
                children: items.map((item) => pw.Text(
                  '${item['category']} (${item['quantity']}kg)',
                  style: pw.TextStyle(font: font, fontSize: 9),
                )).toList(),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                RiwayatPembayaranService.formatCurrency((riwayat['totalHarga'] as num).toDouble()),
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.teal700),
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
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          'Untuk informasi lebih lanjut, hubungi administrator sistem.',
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  /// Print PDF langsung
  static Future<void> printRiwayatPembayaran(List<Map<String, dynamic>> riwayatList) async {
    final file = await generateRiwayatPembayaranPdf(riwayatList);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => file.readAsBytes());
  }

  /// Share PDF
  static Future<void> shareRiwayatPembayaran(List<Map<String, dynamic>> riwayatList) async {
    final file = await generateRiwayatPembayaranPdf(riwayatList);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'riwayat_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
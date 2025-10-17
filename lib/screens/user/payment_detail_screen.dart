import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/invoice_service.dart';
import '../../services/notification_helper.dart';
import 'riwayat_pembayaran_service.dart';

class PaymentDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> invoices;
  final double totalAmount;

  const PaymentDetailScreen({
    super.key,
    required this.invoices,
    required this.totalAmount,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  bool _isLoading = false;
  bool _isPaid = false;

  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _copyVAAndPay(String vaNumber, int invoiceId) async {
    // Get VA bank from first invoice
    final firstInvoice = widget.invoices.isNotEmpty
        ? widget.invoices.first
        : null;
    final vaBank = firstInvoice?['va_bank'] ?? 'BCA';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: vaNumber));

    if (!mounted) return;

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Nomor VA berhasil disalin', style: GoogleFonts.poppins()),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        duration: const Duration(seconds: 2),
      ),
    );

    // Simulate payment (dummy implementation)
    setState(() => _isLoading = true);

    try {
      // Pay all invoices
      for (var invoice in widget.invoices) {
        await _invoiceService.dummyPay(invoice['id']);

        // Save to riwayat pembayaran
        final riwayat = {
          'id': '${invoice['id']}_${DateTime.now().millisecondsSinceEpoch}',
          'namaKolektor':
              invoice['service_account']?['name'] ?? 'Layanan Sampah',
          'alamat': invoice['service_account']?['address'] ?? '-',
          'items': invoice['items'] ?? [],
          'totalHarga': (invoice['total_amount'] ?? 0).toDouble(),
          'tanggalPengambilan': DateTime.now().toIso8601String(),
          'status': 'Lunas',
          'metodePembayaran': 'Virtual Account $vaBank',
          'invoiceNumber': invoice['invoice_number'] ?? '-',
          'period': invoice['period'] ?? '-',
          'paidAt': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        await RiwayatPembayaranService.saveRiwayatPembayaran(riwayat);
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isPaid = true;
      });

      // Trigger notifikasi pembayaran berhasil
      final helper = NotificationHelper();
      for (var invoice in widget.invoices) {
        await helper.notifyPaymentSuccess(
          period: invoice['period'] ?? '',
          amount: invoice['amount'] ?? 0,
        );
      }

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 21, 145, 137),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Pembayaran Berhasil!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Semua tagihan telah dibayar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to home with success
              },
              child: Text(
                'Kembali ke Beranda',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 21, 145, 137),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pembayaran gagal: $e',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use first invoice VA number for display (in real app, might have multiple)
    final firstInvoice = widget.invoices.isNotEmpty
        ? widget.invoices.first
        : null;
    final vaNumber = firstInvoice?['va_number'] ?? '';
    final vaBank = firstInvoice?['va_bank'] ?? 'BCA';
    final vaFormatted = firstInvoice?['va_number_formatted'] ?? vaNumber;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Detail Pembayaran',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // VA Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 21, 145, 137),
                          Color.fromARGB(255, 16, 110, 103),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(
                            255,
                            21,
                            145,
                            137,
                          ).withAlpha(77),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vaBank,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nomor Virtual Account',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                vaFormatted,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _isPaid
                                  ? null
                                  : () => _copyVAAndPay(
                                      vaNumber,
                                      firstInvoice?['id'],
                                    ),
                              icon: Icon(
                                _isPaid ? Icons.check_circle : Icons.copy,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withAlpha(51),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.white.withAlpha(77)),
                        const SizedBox(height: 16),
                        Text(
                          'Total Pembayaran',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(widget.totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Klik ikon salin untuk menyalin nomor VA. Pembayaran akan otomatis diproses (dummy mode).',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Invoice List
                  Text(
                    'Detail Tagihan',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...widget.invoices.map((invoice) {
                    final amount = invoice['total_amount'] ?? 0.0;
                    final serviceAccount = invoice['service_account'] ?? {};
                    final invoiceNumber = invoice['invoice_number'] ?? '-';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  serviceAccount['name'] ?? 'Akun Layanan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                currencyFormat.format(amount),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(
                                    255,
                                    21,
                                    145,
                                    137,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            invoiceNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (serviceAccount['address'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              serviceAccount['address'],
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 24),

                  // Total Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(255, 21, 145, 137),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Tagihan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${widget.invoices.length} Akun Layanan',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          currencyFormat.format(widget.totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 21, 145, 137),
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'riwayat_pembayaran_service.dart';
import 'pdf_export_service.dart';
import 'payment_method_screen.dart';
import 'payment_process_screen.dart';
import '../../services/payment_service.dart';

class RiwayatPembayaranScreen extends StatefulWidget {
  const RiwayatPembayaranScreen({super.key});

  @override
  State<RiwayatPembayaranScreen> createState() => _RiwayatPembayaranScreenState();
}

class _RiwayatPembayaranScreenState extends State<RiwayatPembayaranScreen> {
  List<Map<String, dynamic>> _riwayatList = [];
  bool _isLoading = true;
  double _totalBulanIni = 0;
  int _jumlahTransaksi = 0;
  
  // Untuk sistem tagihan
  double _totalTagihanPending = 0;
  int _jumlahTagihanPending = 0;

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _loadRiwayatPembayaran();
  }

  Future<void> _loadRiwayatPembayaran() async {
    setState(() => _isLoading = true);
    
    try {
      // Load from API for invoice payments
      final service = RiwayatPembayaranService();
      final paymentHistory = await service.getPaymentHistory(page: 1, perPage: 50);
      
      // Load from local storage for waste pickups (legacy)
      final localRiwayat = await RiwayatPembayaranService.getRiwayatPembayaran();
      
      // Combine both lists
      final combined = [...paymentHistory, ...localRiwayat];
      
      // Sort by date
      combined.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
        final dateB = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
        return dateB.compareTo(dateA);
      });
      
      // Calculate totals for this month (only from payments)
      final now = DateTime.now();
      final thisMonth = paymentHistory.where((p) {
        final createdAt = DateTime.parse(p['created_at']);
        return createdAt.month == now.month && createdAt.year == now.year;
      }).toList();
      
      final totalBulanIni = thisMonth.where((p) => p['status'] == 'success').fold<double>(
        0.0,
        (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble(),
      );
      
      final jumlahTransaksi = thisMonth.where((p) => p['status'] == 'success').length;
      
      // Calculate pending invoices
      final pendingPayments = paymentHistory.where((p) => p['status'] == 'pending').toList();
      final totalTagihanPending = pendingPayments.fold<double>(
        0.0,
        (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble(),
      );
      
      if (mounted) {
        setState(() {
          _riwayatList = combined;
          _totalBulanIni = totalBulanIni;
          _jumlahTransaksi = jumlahTransaksi;
          _totalTagihanPending = totalTagihanPending;
          _jumlahTagihanPending = pendingPayments.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat riwayat pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRiwayat(String id) async {
    final success = await RiwayatPembayaranService.deleteRiwayatPembayaran(id);
    if (success) {
      _loadRiwayatPembayaran();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Riwayat berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _bayarSemuaTagihan() async {
    if (_jumlahTagihanPending == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada tagihan yang perlu dibayar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Check if there's a pending payment
      final pendingPayment = await _paymentService.checkPendingPayment();

      if (!mounted) return;

      if (pendingPayment != null) {
        // Show dialog asking if user wants to continue pending payment
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Pembayaran Belum Selesai',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Anda memiliki pembayaran yang belum selesai. Apakah ingin melanjutkan pembayaran tersebut?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                ),
                child: Text(
                  'Lanjutkan',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (shouldContinue == true) {
          // Navigate to payment process screen with pending payment
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentProcessScreen(
                payment: pendingPayment,
              ),
            ),
          );

          // Refresh if payment was successful
          if (result == true || mounted) {
            await _loadRiwayatPembayaran();
          }
          return;
        }
      }

      // No pending payment, proceed with new payment
      // Get pending payment invoices
      final pendingPayments = _riwayatList.where((item) {
        return item.containsKey('order_id') && item['status'] == 'pending';
      }).toList();

      if (pendingPayments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada tagihan pending yang ditemukan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Convert to invoice format for PaymentMethodScreen
      final invoices = pendingPayments.map((payment) {
        final invoice = payment['invoice'] as Map<String, dynamic>?;
        return {
          'id': invoice?['id'] ?? payment['id'],
          'invoice_number': invoice?['invoice_number'] ?? 'Invoice',
          'total_amount': payment['amount'] ?? 0,
          'status': 'unpaid',
        };
      }).toList();

      // Navigate to PaymentMethodScreen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(invoices: invoices),
        ),
      );

      // Refresh if payment was made
      if (result == true || mounted) {
        await _loadRiwayatPembayaran();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memeriksa status pembayaran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMenuAction(String value) async {
    try {
      switch (value) {
        case 'export_pdf':
          await _exportToPdf();
          break;
        case 'print_pdf':
          await _printPdf();
          break;
        case 'share_pdf':
          await _sharePdf();
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(
              color: Color.fromARGB(255, 21, 145, 137),
            ),
            const SizedBox(width: 20),
            Text(
              'Membuat PDF...',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
      ),
    );

    try {
      final file = await PdfExportService.generateRiwayatPembayaranPdf(_riwayatList);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF berhasil disimpan: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'BUKA',
              textColor: Colors.white,
              onPressed: () => _openPdf(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      await PdfExportService.printRiwayatPembayaran(_riwayatList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(
              color: Color.fromARGB(255, 21, 145, 137),
            ),
            const SizedBox(width: 20),
            Text(
              'Menyiapkan PDF untuk dibagikan...',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
      ),
    );

    try {
      await PdfExportService.shareRiwayatPembayaran(_riwayatList);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openPdf(String path) async {
    try {
      // You can use url_launcher or any other method to open PDF
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF tersimpan di: $path'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Tagihan & Pembayaran',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_riwayatList.isNotEmpty) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onSelected: _handleMenuAction,
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'export_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Export PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'print_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.print, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Print PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'share_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Share PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading ? _buildLoadingWidget() : _buildContent(),
      floatingActionButton: _riwayatList.isNotEmpty 
          ? FloatingActionButton.extended(
              onPressed: () => _handleMenuAction('export_pdf'),
              backgroundColor: const Color.fromARGB(255, 21, 145, 137),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                'Export PDF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color.fromARGB(255, 21, 145, 137),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRiwayatPembayaran,
      color: const Color.fromARGB(255, 21, 145, 137),
      child: CustomScrollView(
        slivers: [
          // Summary Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  
                  // Card untuk tagihan pending
                  if (_jumlahTagihanPending > 0) ...[
                    _buildTagihanPendingCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  Row(
                    children: [
                      Text(
                        'Riwayat Pembayaran',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (_riwayatList.isNotEmpty) ...[
                        IconButton(
                          onPressed: () => _handleMenuAction('export_pdf'),
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Export PDF',
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${_riwayatList.length} transaksi',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Riwayat List
          if (_riwayatList.isEmpty && _jumlahTagihanPending == 0)
            SliverToBoxAdapter(
              child: _buildEmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final riwayat = _riwayatList[index];
                  return _buildRiwayatItem(riwayat, index);
                },
                childCount: _riwayatList.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTagihanPendingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 152, 0), // Orange
            Color.fromARGB(255, 255, 193, 7),  // Amber
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Tagihan Belum Dibayar',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            RiwayatPembayaranService.formatCurrency(_totalTagihanPending),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_jumlahTagihanPending tagihan menunggu pembayaran',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bayarSemuaTagihan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Bayar Semua Tagihan Bulan Ini',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final now = DateTime.now();
    // Gunakan format sederhana tanpa locale untuk menghindari LocaleDataException
    final monthNames = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthName = '${monthNames[now.month]} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 21, 145, 137),
            Color.fromARGB(255, 26, 188, 156),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 21, 145, 137).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Pembayaran $monthName',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            RiwayatPembayaranService.formatCurrency(_totalBulanIni),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Lunas',
                  '$_jumlahTransaksi kali',
                  Icons.check_circle,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white30),
              Expanded(
                child: _buildSummaryItem(
                  'Pending',
                  '$_jumlahTagihanPending tagihan',
                  Icons.pending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatItem(Map<String, dynamic> riwayat, int index) {
    // Check if this is a payment from API or waste pickup from local storage
    final bool isPayment = riwayat.containsKey('order_id');
    
    if (isPayment) {
      return _buildPaymentItem(riwayat, index);
    } else {
      return _buildWastePickupItem(riwayat, index);
    }
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment, int index) {
    final tanggal = DateTime.parse(payment['created_at']);
    final invoice = payment['invoice'] as Map<String, dynamic>?;
    final status = payment['status'] ?? 'pending';
    final amount = (payment['amount'] ?? 0) as num;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPaymentDetailDialog(payment),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 21, 145, 137).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Color.fromARGB(255, 21, 145, 137),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice != null ? (invoice['invoice_number'] ?? 'Invoice') : 'Pembayaran Tagihan',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            RiwayatPembayaranService.formatDate(tanggal),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          RiwayatPembayaranService.formatCurrency(amount.toDouble()),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color.fromARGB(255, 21, 145, 137),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getPaymentStatusText(status),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: _getPaymentStatusColor(status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${payment['payment_channel']?.toUpperCase() ?? 'MIDTRANS'} - ${payment['payment_type']?.toUpperCase() ?? 'PAYMENT'}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWastePickupItem(Map<String, dynamic> riwayat, int index) {
    final tanggal = DateTime.parse(riwayat['tanggalPengambilan'] ?? DateTime.now().toIso8601String());
    final items = List<Map<String, dynamic>>.from(riwayat['items'] ?? []);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetailDialog(riwayat),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 21, 145, 137).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Color.fromARGB(255, 21, 145, 137),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riwayat['namaKolektor'] ?? 'Kolektor',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            RiwayatPembayaranService.formatDate(tanggal),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          RiwayatPembayaranService.formatCurrency(
                            (riwayat['totalHarga'] as num).toDouble(),
                          ),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color.fromARGB(255, 21, 145, 137),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(riwayat['status'] ?? 'Lunas').withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            riwayat['status'] ?? 'Lunas',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: _getStatusColor(riwayat['status'] ?? 'Lunas'),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  riwayat['alamat'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${items.length} jenis sampah',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      riwayat['metodePembayaran'] ?? 'Tunai',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Pembayaran',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'riwayat pembayaran akan muncul setelah kolektor membuat tagihan dari pengambilan sampah',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> riwayat) {
    final items = List<Map<String, dynamic>>.from(riwayat['items'] ?? []);
    final tanggal = DateTime.parse(riwayat['tanggalPengambilan']);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 21, 145, 137),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${riwayat['id']}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Kolektor', riwayat['namaKolektor'] ?? ''),
                      _buildDetailRow('Alamat', riwayat['alamat'] ?? ''),
                      _buildDetailRow('Tanggal', RiwayatPembayaranService.formatDate(tanggal)),
                      _buildDetailRow('Status', riwayat['status'] ?? ''),
                      _buildDetailRow('Metode Bayar', riwayat['metodePembayaran'] ?? ''),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Detail Sampah',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ...items.map((item) => _buildItemRow(item)).toList(),
                      
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Pembayaran',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            RiwayatPembayaranService.formatCurrency(
                              (riwayat['totalHarga'] as num).toDouble(),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 21, 145, 137),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteRiwayat(riwayat['id']);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text(
                          'Hapus',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Menunggu Pembayaran':
        return Colors.orange[700]!;
      case 'Lunas':
      case 'Selesai':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: item['category'] == 'Organik' 
                  ? Colors.green[100] 
                  : Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item['category'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: item['category'] == 'Organik' 
                    ? Colors.green[700] 
                    : Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${item['quantity']} kg × ${RiwayatPembayaranService.formatCurrency((item['price'] as num).toDouble())}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            RiwayatPembayaranService.formatCurrency((item['total'] as num).toDouble()),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color.fromARGB(255, 21, 145, 137),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed':
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'success': return 'Lunas';
      case 'pending': return 'Pending';
      case 'failed': return 'Gagal';
      case 'expired': return 'Kadaluarsa';
      default: return status;
    }
  }

  void _showPaymentDetailDialog(Map<String, dynamic> payment) {
    final invoice = payment['invoice'] as Map<String, dynamic>?;
    // final tanggal = DateTime.parse(payment['created_at']);
    showDialog(context: context, builder: (context) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color.fromARGB(255, 21, 145, 137), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Row(children: [const Icon(Icons.payment, color: Colors.white), const SizedBox(width: 12), Text('Detail Pembayaran', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])), SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildPaymentDetailRow('Order ID', payment['order_id'] ?? '-'), const SizedBox(height: 12), _buildPaymentDetailRow('Invoice', invoice?['invoice_number'] ?? '-'), const Divider(height: 30), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)), Text(RiwayatPembayaranService.formatCurrency(((payment['amount'] ?? 0) as num).toDouble()), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 21, 145, 137)))])])), Container(padding: const EdgeInsets.all(20), child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 21, 145, 137)), child: Text('Tutup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))))])));
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Row(children: [SizedBox(width: 120, child: Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]))), const Text(': '), Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)))]);
  }
}
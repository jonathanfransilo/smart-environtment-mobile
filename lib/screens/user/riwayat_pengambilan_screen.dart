import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/resident_pickup_service.dart';
import 'package:intl/intl.dart';

/// 🔹 Halaman Riwayat Pengambilan Sampah
class RiwayatPengambilanScreen extends StatefulWidget {
  final String serviceAccountId;
  final String accountName;

  const RiwayatPengambilanScreen({
    super.key,
    required this.serviceAccountId,
    required this.accountName,
  });

  @override
  State<RiwayatPengambilanScreen> createState() =>
      _RiwayatPengambilanScreenState();
}

class _RiwayatPengambilanScreenState extends State<RiwayatPengambilanScreen> {
  final ResidentPickupService _pickupService = ResidentPickupService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pickupHistory = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Muat riwayat pickup dari API
  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔄 [RiwayatPengambilan] Loading history for account: ${widget.accountName} (ID: ${widget.serviceAccountId})');
    
    // Kirim service_account_id ke API untuk filter data yang spesifik
    final (success, message, pickups) = await _pickupService.getPickupHistory(
      serviceAccountId: widget.serviceAccountId,
    );

    if (!mounted) return;

    print('📊 [RiwayatPengambilan] Result - Success: $success, Items: ${pickups?.length ?? 0}');

    if (success && pickups != null) {
      setState(() {
        _pickupHistory = pickups;
        _isLoading = false;
      });
      
      if (pickups.isEmpty) {
        print('⚠️ [RiwayatPengambilan] No pickup history found');
      } else {
        print('✅ [RiwayatPengambilan] Loaded ${pickups.length} pickup records');
      }
    } else {
      print('❌ [RiwayatPengambilan] Error: $message');
      setState(() {
        _isLoading = false;
        _errorMessage = message ?? 'Gagal memuat riwayat';
      });
    }
  }

  /// Format tanggal ke format Indonesia
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      case 'in_progress':
      case 'on_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'skipped':
        return Icons.info;
      case 'in_progress':
      case 'on_progress':
        return Icons.local_shipping;
      default:
        return Icons.help;
    }
  }

  /// Get status text
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
      case 'completed':
        return 'Sudah Diambil';
      case 'cancelled':
        return 'Dibatalkan';
      case 'skipped':
        return 'Dilewati';
      case 'in_progress':
      case 'on_progress':
        return 'Sedang Diambil';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Riwayat Pengambilan",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              widget.accountName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading ? _buildShimmer() : _buildContent(),
    );
  }

  /// Shimmer loading
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  /// Content
  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      );
    }

    if (_pickupHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Belum ada riwayat pengambilan",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _pickupHistory.length,
        itemBuilder: (context, index) {
          final pickup = _pickupHistory[index];
          return _buildPickupCard(pickup);
        },
      ),
    );
  }

  /// Card untuk setiap pickup
  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final status = pickup['status'] as String? ?? 'unknown';
    final totalAmount = pickup['total_amount'];
    final collectorNotes = pickup['collector_notes'] as String?;
    
    // Waste items
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusText = _getStatusText(status);

    return GestureDetector(
      onTap: () => _showDetailDialog(pickup),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header dengan status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        if (pickupDate != null)
                          Text(
                            _formatDate(pickupDate),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (totalAmount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rp ${_formatCurrency(totalAmount)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Body - Waste Items
            if (wasteItems != null && wasteItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Jenis Sampah",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...wasteItems.take(3).map((item) {
                      // Handle berbagai format dari API
                      final wasteName = item['waste_category'] ?? 
                                       item['waste_name'] ?? 
                                       item['waste']?['category'] ?? '-';
                      final quantity = item['quantity'] ?? 0;
                      // pocket_size bisa string langsung atau object dengan key 'name'
                      final pocketSize = (item['pocket_size'] is String) 
                          ? item['pocket_size']
                          : (item['pocket_size']?['name'] ?? '-');
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$wasteName - $pocketSize',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Text(
                              '${quantity}x',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (wasteItems.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${wasteItems.length - 3} item lainnya',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Catatan Kolektor
            if (collectorNotes != null && collectorNotes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        collectorNotes,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
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

  /// Format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    
    final number = amount is String ? double.tryParse(amount) ?? 0 : amount;
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(number);
  }

  /// Show detail dialog
  void _showDetailDialog(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final status = pickup['status'] as String? ?? 'unknown';
    final totalAmount = pickup['total_amount'];
    final collectorNotes = pickup['collector_notes'] as String?;
    final photoUrl = pickup['photo_url'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusText = _getStatusText(status);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withAlpha(26),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 48,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (pickupDate != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _formatDate(pickupDate),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Foto (jika ada)
                  if (photoUrl != null) ...[
                    Text(
                      "Foto Pengambilan",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Detail sampah
                  if (wasteItems != null && wasteItems.isNotEmpty) ...[
                    Text(
                      "Detail Sampah",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...wasteItems.map((item) {
                      // Handle berbagai format dari API
                      final wasteName = item['waste_category'] ?? 
                                       item['waste_name'] ?? 
                                       item['waste']?['category'] ?? '-';
                      final quantity = item['quantity'] ?? 0;
                      // pocket_size bisa string langsung atau object dengan key 'name'
                      final pocketSize = (item['pocket_size'] is String) 
                          ? item['pocket_size']
                          : (item['pocket_size']?['name'] ?? '-');
                      final totalPrice = item['total_price'];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  wasteName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${quantity}x',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  pocketSize,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (totalPrice != null)
                                  Text(
                                    'Rp ${_formatCurrency(totalPrice)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  // Total
                  if (totalAmount != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Harga",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rp ${_formatCurrency(totalAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Catatan
                  if (collectorNotes != null && collectorNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Catatan Kolektor",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        collectorNotes,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Tutup"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

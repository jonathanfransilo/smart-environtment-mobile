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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Riwayat Pengambilan Sampah",
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
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
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
                backgroundColor: const Color.fromARGB(255, 21, 145, 137),
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
            Image.asset(
              'assets/images/Riwayat pengambilan sampah.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
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

  /// Card untuk setiap pickup - Design seperti gambar
  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    
    if (wasteItems == null || wasteItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group waste items by category
    return Column(
      children: wasteItems.map((item) {
        final wasteCategory = item['waste_category'] ?? 
                             item['waste_name'] ?? 
                             item['waste']?['category'] ?? 'Sampah';
        final quantity = item['quantity'] ?? 0;
        final pocketSize = (item['pocket_size'] is String) 
            ? item['pocket_size']
            : (item['pocket_size']?['name'] ?? '-');
        final pricePerUnit = item['price_per_unit'] ?? 0;
        final totalPrice = item['total_price'] ?? (quantity * pricePerUnit);
        
        // Get waste type from API (Organik/Anorganik/B3)
        final wasteType = item['waste_type']?.toString() ?? 
                         item['waste']?['type']?.toString() ?? 
                         _getCategoryFromName(wasteCategory);
        
        // Get category color based on waste type
        final categoryColor = _getCategoryColor(wasteType);
        
        // Parse weight from pocket_size (e.g., "1.5 kg" -> 1.5)
        double weight = 0;
        if (pocketSize.contains('kg')) {
          final weightStr = pocketSize.replaceAll(RegExp(r'[^0-9.]'), '');
          weight = double.tryParse(weightStr) ?? 0;
        }
        final totalWeight = weight * quantity;

        return GestureDetector(
          onTap: () => _showDetailDialog(pickup),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge kategori dari API (Organik/Anorganik/B3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        wasteType,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    /* HIDDEN: Edit button
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    */
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Nama Sampah
                Text(
                  wasteCategory,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Berat dengan harga per kg
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Berat',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(pricePerUnit)}/ kg',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Total berat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${totalWeight.toStringAsFixed(1)} kg',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Tanggal (bukan Biaya)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tanggal',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Tampilkan tanggal dan total biaya
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pickupDate != null ? _formatDateShort(pickupDate) : '-',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Rp. ${_formatCurrency(totalPrice)}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Format tanggal pendek (contoh: Selasa, 27 Mei 2025 13:58)
  String _formatDateShort(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    
    try {
      final date = DateTime.parse(dateStr);
      final dayName = DateFormat('EEEE', 'id_ID').format(date);
      final dateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(date);
      return '$dayName, $dateFormatted';
    } catch (e) {
      return dateStr;
    }
  }

  /// Format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    
    final number = amount is String ? double.tryParse(amount) ?? 0 : amount;
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(number);
  }

  /// Get category from waste name (fallback jika tidak ada waste_type dari API)
  String _getCategoryFromName(String wasteName) {
    final lowerName = wasteName.toLowerCase();
    
    // Organik keywords
    if (lowerName.contains('dapur') || 
        lowerName.contains('sisa') || 
        lowerName.contains('makanan') ||
        lowerName.contains('organik')) {
      return 'Organik';
    }
    
    // B3 keywords
    if (lowerName.contains('baterai') || 
        lowerName.contains('elektronik') || 
        lowerName.contains('lampu') ||
        lowerName.contains('b3')) {
      return 'B3';
    }
    
    // Default: Anorganik (kertas, plastik, kaleng, dll)
    return 'Anorganik';
  }

  /// Get category color based on waste type
  Color _getCategoryColor(String wasteType) {
    final lowerType = wasteType.toLowerCase();
    
    if (lowerType.contains('organik')) {
      return const Color(0xFF4CAF50); // Green
    } else if (lowerType.contains('b3')) {
      return const Color(0xFFF44336); // Red
    } else {
      return const Color(0xFF2196F3); // Blue for Anorganik
    }
  }

  /// Show detail dialog - Design sesuai gambar
  void _showDetailDialog(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final photoUrl = pickup['photo_url'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    final serviceAccount = pickup['service_account'] as Map<String, dynamic>?;
    
    // Get address from service_account
    final address = serviceAccount?['address'] ?? 
                    serviceAccount?['alamat'] ?? 
                    'Alamat tidak tersedia';
    final accountId = pickup['id']?.toString() ?? '-';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan checkmark dan title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pengambilan Sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Foto (jika ada)
                if (photoUrl != null && photoUrl.isNotEmpty)
                  ClipRRect(
                    child: Image.network(
                      photoUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, 
                              size: 48, 
                              color: Colors.grey[400]
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Foto tidak tersedia',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alamat
                      Text(
                        address,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // ID Pickup
                      Text(
                        '#$accountId',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // Waktu Pengambilan
                      Row(
                        children: [
                          Icon(Icons.access_time, 
                            size: 18, 
                            color: Colors.grey[600]
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Waktu Pengambilan',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickupDate != null ? _formatDateWithTime(pickupDate) : '-',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // Sampah Header
                      Row(
                        children: [
                          Icon(Icons.delete_outline, 
                            size: 18, 
                            color: Colors.grey[600]
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sampah',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Detail Sampah List
                      if (wasteItems != null && wasteItems.isNotEmpty)
                        ...wasteItems.map((item) {
                          final wasteName = item['waste_category'] ?? 
                                           item['waste_name'] ?? 
                                           item['waste']?['category'] ?? '-';
                          final quantity = item['quantity'] ?? 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    wasteName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${quantity}x',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      
                      // Total (Jumlah)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jumlah',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${wasteItems?.length ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Close Button
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
                            elevation: 0,
                          ),
                          child: Text(
                            'Tutup',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
      },
    );
  }

  /// Format tanggal dengan waktu (contoh: Selasa, 27 Mei 2025 13:58)
  String _formatDateWithTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    
    try {
      final date = DateTime.parse(dateStr);
      final dayName = DateFormat('EEEE', 'id_ID').format(date);
      final dateFormatted = DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(date);
      return '$dayName, $dateFormatted';
    } catch (e) {
      return dateStr;
    }
  }
}

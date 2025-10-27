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
      // Debug: Print sample data structure
      if (pickups.isNotEmpty) {
        print('🔍 [RiwayatPengambilan] Sample pickup data:');
        print('   Keys: ${pickups[0].keys}');
        print('   Data: ${pickups[0]}');
        
        // Check for photo URL in different possible fields
        final samplePhoto = pickups[0]['photo_url'] ?? 
                           pickups[0]['image'] ?? 
                           pickups[0]['photo'] ?? 
                           pickups[0]['pickup_photo'];
        print('📷 [RiwayatPengambilan] Sample photo field: $samplePhoto');
      }
      
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

  /// Card untuk setiap pickup - Satu card per pickup (bukan per item)
  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    final serviceAccount = pickup['service_account'] as Map<String, dynamic>?;
    
    if (wasteItems == null || wasteItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate totals for this pickup
    int totalItems = wasteItems.length;
    double totalPrice = 0;
    
    // Get dominant waste type (yang paling banyak)
    Map<String, int> typeCount = {};
    
    for (var item in wasteItems) {
      // Calculate price
      final itemPrice = item['total_price'] ?? 0;
      totalPrice += itemPrice is String ? double.tryParse(itemPrice) ?? 0 : itemPrice;
      
      // Count waste types
      final wasteType = item['waste_type']?.toString() ?? 
                       item['waste']?['type']?.toString() ?? 
                       _getCategoryFromName(item['waste_category'] ?? '');
      typeCount[wasteType] = (typeCount[wasteType] ?? 0) + 1;
    }
    
    // Get dominant waste type
    String dominantType = 'Anorganik';
    int maxCount = 0;
    typeCount.forEach((type, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantType = type;
      }
    });
    
    final categoryColor = _getCategoryColor(dominantType);
    final address = serviceAccount?['address'] ?? 
                    serviceAccount?['alamat'] ?? 
                    widget.accountName;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan badge dan tanggal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
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
                      dominantType,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    pickupDate != null ? _formatDateShort(pickupDate) : '-',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            
            // Body dengan info ringkas
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alamat
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, 
                        size: 16, 
                        color: Colors.grey[600]
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info row (Total Items saja, tanpa berat)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Item',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalItems jenis sampah',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  // Total Harga & Lihat Detail
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Harga',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp. ${_formatCurrency(totalPrice)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Detail',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
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

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

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
    if (!mounted) {
      print('⚠️ [RiwayatPengambilan] Widget not mounted, aborting load');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
        '🔄 [RiwayatPengambilan] Loading history for account: ${widget.accountName} (ID: ${widget.serviceAccountId})',
      );

      // Validasi service account ID
      if (widget.serviceAccountId.isEmpty || widget.serviceAccountId == '0') {
        throw Exception('ID akun tidak valid');
      }

      // Kirim service_account_id ke API untuk filter data yang spesifik
      final (success, message, pickups) = await _pickupService.getPickupHistory(
        serviceAccountId: widget.serviceAccountId,
      );

      if (!mounted) {
        print('⚠️ [RiwayatPengambilan] Widget unmounted during API call');
        return;
      }

      print(
        '📊 [RiwayatPengambilan] API Result - Success: $success, Message: $message, Items: ${pickups?.length ?? 0}',
      );

      if (success && pickups != null) {
        // Debug: Print sample data structure
        if (pickups.isNotEmpty) {
          print('🔍 [RiwayatPengambilan] Sample pickup data:');
          print('   Keys: ${pickups[0].keys}');
          
          // ⚠️ PENTING: Cek confirmation_status dari API
          final confirmationStatus = pickups[0]['confirmation_status'];
          print('⚠️ [RiwayatPengambilan] CONFIRMATION STATUS dari API: $confirmationStatus');
          print('   ❌ Jika status = "confirmed", berarti BACKEND yang salah!');
          print('   ✅ Seharusnya status = "pending" agar user bisa konfirmasi manual');

          // Check ALL possible photo fields
          final photoUrl = pickups[0]['photo_url'];
          final image = pickups[0]['image'];
          final photo = pickups[0]['photo'];
          final pickupPhoto = pickups[0]['pickup_photo'];
          final photoPath = pickups[0]['photo_path'];
          final imagePath = pickups[0]['image_path'];

          print('📷 [RiwayatPengambilan] Photo fields:');
          print('   photo_url: $photoUrl');
          print('   image: $image');
          print('   photo: $photo');
          print('   pickup_photo: $pickupPhoto');
          print('   photo_path: $photoPath');
          print('   image_path: $imagePath');
        }

        setState(() {
          _pickupHistory = pickups;
          _isLoading = false;
        });

        if (pickups.isEmpty) {
          print('⚠️ [RiwayatPengambilan] No pickup history found');
        } else {
          print(
            '✅ [RiwayatPengambilan] Loaded ${pickups.length} pickup records',
          );
        }
      } else {
        throw Exception(message ?? 'Gagal memuat data dari server');
      }
    } catch (e, stackTrace) {
      print('❌ [RiwayatPengambilan] Error loading history: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🎨 [RiwayatPengambilan] Building widget - Loading: $_isLoading, Error: $_errorMessage, Items: ${_pickupHistory.length}',
    );

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('⬅️ [RiwayatPengambilan] Back button pressed');
            Navigator.of(context).pop();
          },
        ),
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
    try {
      final pickupDate = pickup['pickup_date'] as String?;
      final wasteItems = pickup['waste_items'] as List<dynamic>?;
      final serviceAccount = pickup['service_account'] as Map<String, dynamic>?;
      final pickupId = pickup['id']?.toString();
      final confirmationStatus = pickup['confirmation_status']?.toString() ?? 'pending';

      if (wasteItems == null || wasteItems.isEmpty) {
        print('⚠️ [RiwayatPengambilan] Empty waste items for pickup');
        return const SizedBox.shrink();
      }

      // Calculate totals for this pickup
      int totalItems = wasteItems.length;
      double totalPrice = 0;

      // Get dominant waste type (yang paling banyak)
      Map<String, int> typeCount = {};

      for (var item in wasteItems) {
        try {
          // Calculate price
          final itemPrice = item['total_price'] ?? 0;
          totalPrice += itemPrice is String
              ? double.tryParse(itemPrice) ?? 0
              : (itemPrice as num).toDouble();

          // Count waste types
          final wasteType =
              item['waste_type']?.toString() ??
              item['waste']?['type']?.toString() ??
              _getCategoryFromName(item['waste_category'] ?? '');
          typeCount[wasteType] = (typeCount[wasteType] ?? 0) + 1;
        } catch (e) {
          print('⚠️ [RiwayatPengambilan] Error processing waste item: $e');
        }
      }

      final address =
          serviceAccount?['address'] ??
          serviceAccount?['alamat'] ??
          widget.accountName;

      // Get photo URL - check multiple possible field names
      String? photoUrl =
          pickup['photo_url'] as String? ??
          pickup['pickup_photo'] as String? ??
          pickup['image'] as String? ??
          pickup['photo'] as String? ??
          pickup['photo_path'] as String? ??
          pickup['image_path'] as String?;

      // Jika photo URL relatif (tidak dimulai dengan http), tambahkan base URL
      if (photoUrl != null && photoUrl.isNotEmpty) {
        if (!photoUrl.startsWith('http')) {
          // Hapus leading slash jika ada
          if (photoUrl.startsWith('/')) {
            photoUrl = photoUrl.substring(1);
          }
          // Tambahkan base URL
          final baseUrl = 'https://smart-environment-web.citiasiainc.id';
          photoUrl = '$baseUrl/$photoUrl';
        }
      }

      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

      if (hasPhoto) {
        print('📷 [Card] Photo URL for pickup: $photoUrl');
      }

      return GestureDetector(
        onTap: () {
          try {
            print('👆 [RiwayatPengambilan] Card tapped, showing detail dialog');
            _showDetailDialog(pickup);
          } catch (e, stackTrace) {
            print('💥 [RiwayatPengambilan] Error opening detail dialog: $e');
            print('Stack trace: $stackTrace');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Gagal membuka detail: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
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
              // Header dengan tanggal saja (tanpa badge kategori)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pengambilan Sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Badge foto dihapus
                        Text(
                          pickupDate != null
                              ? _formatDateShort(pickupDate)
                              : '-',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body dengan info ringkas (tanpa foto thumbnail)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alamat
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
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

                    // Photo thumbnail jika ada
                    if (hasPhoto) ...[
                      Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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

                    // Tombol Konfirmasi (jika status masih pending - belum dikonfirmasi user)
                    if (confirmationStatus == 'pending') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kolektor telah menginput sampah. Konfirmasi apakah sudah diambil.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showConfirmationDialog(pickupId!, pickup),
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            'Konfirmasi Pengambilan',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Status badge jika sudah dikonfirmasi
                    if (confirmationStatus == 'confirmed') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sudah Dikonfirmasi - Tagihan telah dibuat',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Status badge jika tidak ada sampah
                    if (confirmationStatus == 'no_waste') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tidak Ada Sampah - Tidak ada tagihan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
    } catch (e, stackTrace) {
      print('💥 [RiwayatPengambilan] Error building pickup card: $e');
      print('Stack trace: $stackTrace');
      return const SizedBox.shrink();
    }
  }

  /// Tampilkan dialog konfirmasi pengambilan
  void _showConfirmationDialog(String pickupId, Map<String, dynamic> pickup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Pengambilan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah sampah sudah diambil oleh petugas kolektor?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setelah dikonfirmasi, tagihan akan dibuat dan muncul di menu pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showNoWasteDialog(pickupId);
            },
            child: Text(
              'Tidak Ada Sampah',
              style: GoogleFonts.poppins(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmPickup(pickupId, 'confirmed');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Ya, Sudah Diambil',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog untuk konfirmasi tidak ada sampah
  void _showNoWasteDialog(String pickupId) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tidak Ada Sampah',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Catatan (opsional):',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Sampah sudah dibuang sendiri',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmPickup(
                pickupId,
                'no_waste',
                residentNote: noteController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Konfirmasi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi pickup ke API
  Future<void> _confirmPickup(
    String pickupId,
    String confirmationStatus, {
    String? residentNote,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Memproses konfirmasi...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final (success, message) = await _pickupService.confirmPickup(
        pickupId: pickupId,
        confirmationStatus: confirmationStatus,
        residentNote: residentNote,
      );

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirmationStatus == 'confirmed'
                  ? '✅ Pengambilan sampah berhasil dikonfirmasi!\nTagihan akan dibuat dan muncul di menu Riwayat Pembayaran.'
                  : '✅ Status berhasil diperbarui. Tidak ada tagihan yang dibuat.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 4),
          ),
        );

        // Reload data
        await _loadHistory();
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Gagal mengkonfirmasi pengambilan',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terjadi kesalahan: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
  /// Show detail dialog - Design sesuai gambar
  void _showDetailDialog(Map<String, dynamic> pickup) {
    final pickupDate = pickup['pickup_date'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    final accountId = pickup['id']?.toString() ?? '-';

    // Get photo URL - check multiple possible field names
    String? photoUrl =
        pickup['photo_url'] as String? ??
        pickup['pickup_photo'] as String? ??
        pickup['image'] as String? ??
        pickup['photo'] as String? ??
        pickup['photo_path'] as String? ??
        pickup['image_path'] as String?;

    // Jika photo URL relatif (tidak dimulai dengan http), tambahkan base URL
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (!photoUrl.startsWith('http')) {
        // Hapus leading slash jika ada
        if (photoUrl.startsWith('/')) {
          photoUrl = photoUrl.substring(1);
        }
        // Tambahkan base URL
        final baseUrl = 'https://smart-environment-web.citiasiainc.id';
        photoUrl = '$baseUrl/$photoUrl';
      }
    }

    print('📷 [DetailDialog] Original pickup data: $pickup');
    print('📷 [DetailDialog] Final Photo URL: $photoUrl');

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
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
                      // Foto Bukti Pengambilan (jika ada)
                      if (photoUrl != null && photoUrl.isNotEmpty) ...[
                        Text(
                          'Foto Bukti Pengambilan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final imageUrl =
                                photoUrl!; // Capture non-null value
                            print('🖼️ [DetailDialog] Loading image from: $imageUrl');
                            return Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GestureDetector(
                                  onTap: () {
                                    // Show fullscreen photo
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          backgroundColor: Colors.black,
                                          appBar: AppBar(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            title: Text(
                                              'Foto Bukti Pengambilan',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ),
                                          body: Center(
                                            child: InteractiveViewer(
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Center(
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            const Icon(
                                                              Icons.broken_image,
                                                              size: 64,
                                                              color: Colors.white54,
                                                            ),
                                                            const SizedBox(height: 16),
                                                            Text(
                                                              'Foto tidak dapat dimuat',
                                                              style: GoogleFonts.poppins(
                                                                color: Colors.white70,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Center(
                                                    child: CircularProgressIndicator(
                                                      value:
                                                          loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                          : null,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('❌ [DetailDialog] Error loading image from: $imageUrl');
                                          print('❌ [DetailDialog] Error: $error');
                                          print('❌ [DetailDialog] StackTrace: $stackTrace');
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 48,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Foto tidak tersedia',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  child: Text(
                                                    'File mungkin sudah dihapus dari server',
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                      // Overlay untuk indicator bisa di-tap
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tap untuk perbesar',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Pesan jika foto tidak tersedia
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Foto bukti pengambilan tidak tersedia',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

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
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey[600],
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
                        pickupDate != null
                            ? _formatDateWithTime(pickupDate)
                            : '-',
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
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.grey[600],
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
                          // Get waste category (organic, anorganik, dll)
                          final wasteCategory =
                              item['waste_category'] ??
                              item['waste']?['category'] ??
                              item['waste_name'] ??
                              '-';

                          // Get pocket size (Besar, Sedang, Kecil)
                          final pocketSize =
                              item['pocket_size'] ??
                              item['size'] ??
                              item['waste_size'] ??
                              '';

                          // Combine category with size if available
                          final displayName = pocketSize.isNotEmpty
                              ? '$wasteCategory $pocketSize'
                              : wasteCategory;

                          final quantity = item['quantity'] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
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

                      // Total (Jumlah) - Sum of all quantities
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
                            '${wasteItems?.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0)) ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Tombol Konfirmasi atau Tutup (tergantung status)
                      Builder(
                        builder: (context) {
                          final pickupId = pickup['id']?.toString();
                          final confirmationStatus = pickup['confirmation_status']?.toString() ?? 'pending';
                          final isPending = confirmationStatus == 'pending';

                          if (isPending && pickupId != null) {
                            // Jika status pending, tampilkan tombol konfirmasi
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showConfirmationDialog(pickupId, pickup);
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 20),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                label: Text(
                                  'Konfirmasi Pengambilan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // Jika sudah dikonfirmasi, tampilkan tombol tutup
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF009688),
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
                            );
                          }
                        },
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
      final dateFormatted = DateFormat(
        'd MMMM yyyy HH:mm',
        'id_ID',
      ).format(date);
      return '$dayName, $dateFormatted';
    } catch (e) {
      return dateStr;
    }
  }
}

  import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'pembayaran_screen.dart';
import '../../services/pickup_service.dart';

class DetailSampahScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String address;
  final String idPengambilan;
  final Map<String, List<Map<String, dynamic>>> selectedSampah;
  final XFile imageFile;

  const DetailSampahScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    required this.selectedSampah,
    required this.imageFile,
  });

  @override
  State<DetailSampahScreen> createState() => _DetailSampahScreenState();
}

class _DetailSampahScreenState extends State<DetailSampahScreen> {
  int _currentStep = 2; // Still in Input Kantong Progress

  List<Map<String, dynamic>> _getSelectedItems() {
    List<Map<String, dynamic>> selectedItems = [];
    
    widget.selectedSampah.forEach((category, items) {
      for (var item in items) {
        if ((item['quantity'] as int) > 0) {
          selectedItems.add({
            'category': category,
            'name': item['name'],
            'quantity': item['quantity'],
            'price': item['price'],
            'total': (item['quantity'] as int) * (item['price'] as int),
            'waste_id': item['waste_id'],
            'pocket_size_id': item['pocket_size_id'],
          });
        }
      }
    });
    
    return selectedItems;
  }



  double _getTotalPrice() {
    double total = 0;
    List<Map<String, dynamic>> items = _getSelectedItems();
    for (var item in items) {
      total += item['total'] as int;
    }
    return total;
  }

  String _getCategoryTag(String category) {
    return category; // Return the actual category (Organik/Anorganik)
  }

  Future<void> _konfirmasi() async {
    final selectedItems = _getSelectedItems();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Menyimpan data...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('🔄 [DetailSampah] Starting to submit...');
      print('📷 [DetailSampah] Image name: ${widget.imageFile.name}');
      
      // Convert image to base64 (support web & mobile)
      final imageBytes = await widget.imageFile.readAsBytes();
      print('📦 [DetailSampah] Image bytes: ${imageBytes.length}');
      
      final base64Image = base64Encode(imageBytes);
      print('🔐 [DetailSampah] Base64 encoded: ${base64Image.substring(0, 50)}...');

      // Prepare waste items for API
      final wasteItems = selectedItems.map((item) {
        return {
          'waste_id': item['waste_id'],
          'pocket_size_id': item['pocket_size_id'],
          'quantity': item['quantity'],
        };
      }).toList();
      
      print('📋 [DetailSampah] Waste items: $wasteItems');
      print('🚀 [DetailSampah] Calling API...');

      // Call API to complete pickup
      final (success, message, data) = await PickupService.completePickup(
        id: widget.pickupId,
        photo: base64Image,
        wasteItems: wasteItems,
      );
      
      print('✅ [DetailSampah] API Response - Success: $success, Message: $message');

      // Close loading
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Navigate to Pembayaran screen with API response data
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PembayaranScreen(
                userName: widget.userName,
                address: widget.address,
                idPengambilan: widget.idPengambilan,
                selectedItems: selectedItems,
                totalPrice: data?['total_amount'] as double? ?? _getTotalPrice(),
                photoUrl: data?['photo_url'] as String?,
              ),
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal menyimpan data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('💥 [DetailSampah] Exception: $e');
      print('💥 [DetailSampah] StackTrace: $stackTrace');
      
      // Close loading if still open
      if (mounted) Navigator.of(context).pop();
      
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

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepItem(0, 'Datang', 'Selesai'),
          _buildStepLine(0),
          _buildStepItem(1, 'Foto', 'Selesai'),
          _buildStepLine(1),
          _buildStepItem(2, 'Input Kantong', 'Progress'),
          _buildStepLine(2),
          _buildStepItem(3, 'Selesai', 'Pending'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String status) {
    Color circleColor;
    Color textColor;
    
    if (step < _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else if (step == _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else {
      circleColor = Colors.grey[300]!;
      textColor = Colors.grey[500]!;
    }
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: step < _currentStep
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        Text(
          status,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    bool isCompleted = step < _currentStep;
    
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 40),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF009688) : Colors.grey[300],
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = _getSelectedItems();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Detail Sampah',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Stepper
          Container(
            color: Colors.white,
            child: _buildProgressStepper(),
          ),
          
          // Section Title
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jenis Sampah',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Tambah',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF009688),
                  ),
                ),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: selectedItems.length,
              itemBuilder: (context, index) {
                final item = selectedItems[index];
                
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      // Category Tag
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item['category'] == 'Organik' ? Colors.green[600] : Colors.blue[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getCategoryTag(item['category']),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Item Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${item['category']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Biaya',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Edit Button
                      Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF009688),
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      // Weight and Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rp ${(item['price'] as int)} / kantong',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${item['quantity']} kantong',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Rp ${item['total']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Detail Pengambilan Section
          Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pengangkutan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ongkos Sampah Organik',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Rp ${_getTotalPrice().toInt()}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Konfirmasi Button
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _konfirmasi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF009688),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Konfirmasi',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
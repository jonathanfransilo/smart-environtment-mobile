import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/pickup_service.dart';

class PembayaranScreen extends StatefulWidget {
  final String userName;
  final String address;
  final String idPengambilan;
  final List<Map<String, dynamic>> selectedItems;
  final double totalPrice;
  final String? photoUrl;

  const PembayaranScreen({
    super.key,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    required this.selectedItems,
    required this.totalPrice,
    this.photoUrl,
  });

  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  int _currentStep = 3; // Selesai

  Map<String, List<Map<String, dynamic>>> _groupItemsByCategory() {
    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    
    for (var item in widget.selectedItems) {
      String category = item['category'];
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }
    
    return groupedItems;
  }

  int _getTotalQuantity() {
    int total = 0;
    for (var item in widget.selectedItems) {
      total += item['quantity'] as int;
    }
    return total;
  }

  Future<void> _lanjutkan() async {
    // Simpan data pengambilan ke storage/database (simulasi)
    await _savePickupData();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Data pengambilan berhasil disimpan!',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate back to home and refresh
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      // Trigger refresh of home screen if possible
    }
  }

  Future<void> _savePickupData() async {
    // Simpan data pengambilan menggunakan PickupService
    await PickupService.savePickupData(
      userName: widget.userName,
      address: widget.address,
      idPengambilan: widget.idPengambilan,
      selectedItems: widget.selectedItems,
      totalPrice: widget.totalPrice,
      imagePath: widget.photoUrl ?? 'assets/images/dummy.jpg', // Use photo_url from API
    );

    // Tambahkan ke riwayat pembayaran user
    await _saveToUserRiwayatPembayaran();
    
    // Tambahkan notifikasi ke user
    await _addUserNotification();
  }

  Future<void> _saveToUserRiwayatPembayaran() async {
    try {
      // Import service (tambahkan di top file)
      // import '../user/riwayat_pembayaran_service.dart';
      
      // Buat data riwayat pembayaran
      final riwayatData = {
        'id': widget.idPengambilan,
        'namaKolektor': 'Kolektor Sampah', // Bisa diganti dengan nama kolektor yang login
        'alamat': widget.address,
        'items': widget.selectedItems,
        'totalHarga': widget.totalPrice,
        'tanggalPengambilan': DateTime.now().toIso8601String(),
        'status': 'Selesai',
        'metodePembayaran': 'Tunai',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Simpan menggunakan RiwayatPembayaranService
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getStringList('riwayat_pembayaran') ?? [];
      existingData.insert(0, jsonEncode(riwayatData));
      await prefs.setStringList('riwayat_pembayaran', existingData);
    } catch (e) {
      print('Error saving to riwayat pembayaran: $e');
    }
  }

  Future<void> _addUserNotification() async {
    try {
      final totalFormatted = 'Rp ${widget.totalPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
      
      final message = 'Pembayaran sampah sebesar $totalFormatted telah selesai. ID: ${widget.idPengambilan}';
      
      // Tambahkan notifikasi menggunakan NotificationService yang ada
      // Gunakan metode addNotification yang sudah ada
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getStringList('notifications') ?? [];
      
      final notificationData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'message': message,
        'time': DateTime.now().toIso8601String(),
        'isRead': false,
      };
      
      notifications.insert(0, jsonEncode(notificationData));
      await prefs.setStringList('notifications', notifications);
    } catch (e) {
      print('Error adding notification: $e');
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
          _buildStepItem(2, 'Input Kantong', 'Selesai'),
          _buildStepLine(2),
          _buildStepItem(3, 'Selesai', 'Progress'),
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
    final groupedItems = _groupItemsByCategory();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Pembayaran',
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
          // Progress Stepper (Selesai/Complete)
          Container(
            color: Colors.white,
            child: _buildProgressStepper(),
          ),
          
          // Success Icon and Title
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Pengambilan Sampah',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Photo Container
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage('assets/images/dummy.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Address and ID
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  widget.address,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '#${widget.idPengambilan}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Waktu Pengambilan
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waktu Pengambilan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Selasa, 27 Mei 2025 13.58',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Sampah List
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampah',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Sampah Items
                  for (var entry in groupedItems.entries) ...[
                    Column(
                      children: [
                        // Category Header
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sampah ${entry.key}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Items in category
                        for (var item in entry.value) 
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '${item['quantity']}x',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        SizedBox(height: 12),
                      ],
                    ),
                  ],
                  
                  // Total
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
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
                          '${_getTotalQuantity()}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Lanjutkan Button
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _lanjutkan,
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
                  'Lanjutkan',
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
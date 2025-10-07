import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pengambilan_sampah_screen.dart';
import '../../services/pickup_service.dart';
import 'profile_screen.dart';
import 'riwayat_sampah_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class HomeScreensKolektor extends StatefulWidget {
  const HomeScreensKolektor({super.key});

  @override
  State<HomeScreensKolektor> createState() => _HomeScreensKolektorState();
}

class _HomeScreensKolektorState extends State<HomeScreensKolektor> {
  List<Map<String, dynamic>> pengambilanList = [];
  List<Map<String, dynamic>> todayPickups = [];
  String _profileImagePath = '';
  bool _isLoadingPickups = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTodayPickups();
    _loadPengambilanData();
    _loadProfileImage();
  }

  Future<void> _loadTodayPickups() async {
    setState(() {
      _isLoadingPickups = true;
      _errorMessage = null;
    });

    final (success, message, data) = await PickupService.getTodayPickups();
    
    if (mounted) {
      setState(() {
        _isLoadingPickups = false;
        if (success && data != null) {
          todayPickups = data;
        } else {
          _errorMessage = message;
          todayPickups = [];
        }
      });
    }
  }

  Future<void> _loadPengambilanData() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final data = await PickupService.getPickupHistory();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        pengambilanList = data;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path') ?? '';
    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
      });
    }
  }

  void _onProfileUpdated(String imagePath) {
    setState(() {
      _profileImagePath = imagePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF009688);
    final TextStyle titleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: _profileImagePath.isNotEmpty
                              ? FileImage(File(_profileImagePath))
                              : const AssetImage("assets/images/dummy.jpg") as ImageProvider,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Raka Juliandra",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF009688),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Menteng, Jakarta Pusat",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined, size: 26),
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  onProfileUpdated: _onProfileUpdated,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person, size: 26),
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card Ringkasan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Tugas Hari Ini",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTodayDate(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(todayPickups.length.toString(), "Total"),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            _statItem(_getCompletedCount().toString(), "Selesai"),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            _statItem(_getPendingCount().toString(), "Belum"),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Daftar Tugas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daftar Tugas", style: titleStyle),
                    Text(
                      "Lainnya",
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _isLoadingPickups
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadTodayPickups,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                ),
                                child: Text(
                                  'Coba Lagi',
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ],
                          ),
                        )
                      : todayPickups.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'Tidak ada tugas pickup hari ini',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: todayPickups.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (context, index) {
                                final pickup = todayPickups[index];
                                final houseInfo = pickup['house_info'] as Map<String, dynamic>?;
                                return _taskCard(
                                  houseInfo?['resident_name']?.toString() ?? 'N/A',
                                  houseInfo?['address']?.toString() ?? 'N/A',
                                  pickup['id']?.toString() ?? '',
                                  pickup['status']?.toString() ?? 'scheduled',
                                  houseInfo?['latitude'] as double? ?? 0.0,
                                  houseInfo?['longitude'] as double? ?? 0.0,
                                  primaryColor,
                                  context,
                                  pickup,
                                );
                              },
                            ),

              const SizedBox(height: 24),

              // Pengambilan Terakhir
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pengambilan Terakhir", style: titleStyle),
                    Text(
                      "Lainnya",
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 180,
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : pengambilanList.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada pengambilan sampah',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: pengambilanList.length,
                        itemBuilder: (context, index) {
                          final item = pengambilanList[index];
                          return _pickupCard(
                            item["name"]?.toString() ?? "",
                            item["address"]?.toString() ?? "",
                            "Rp. ${(item["totalPrice"] as num?)?.toInt() ?? 0}",
                            item["image"]?.toString() ?? "assets/images/dummy.jpg",
                            primaryColor,
                            item, // Pass the full item data
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _taskCard(String name, String address, String pickupId, String status, double latitude, double longitude, Color primaryColor, BuildContext context, Map<String, dynamic> pickupData) {
    // Status badge configuration
    final statusConfig = _getStatusConfig(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusConfig['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusConfig['label'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: statusConfig['color'],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "#$pickupId",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: status == 'completed' || status == 'cancelled' || status == 'skipped'
                  ? null
                  : () {
                      final houseInfo = pickupData['house_info'] as Map<String, dynamic>?;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PengambilanSampahScreen(
                            pickupId: pickupData['id'] as int,
                            userName: name,
                            userPhone: houseInfo?['phone_number']?.toString() ?? '+62',
                            address: address,
                            idPengambilan: '#${pickupId}',
                            distance: '0 Km', // Will be calculated based on GPS
                            time: 'Hari ini',
                            latitude: latitude,
                            longitude: longitude,
                          ),
                        ),
                      ).then((_) {
                        // Refresh data when returning
                        _loadTodayPickups();
                        _loadPengambilanData();
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                status == 'on_progress' ? "Lanjutkan" : status == 'completed' ? "Selesai" : "Ambil",
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _pickupCard(String name, String address, String price, String image, Color primaryColor, Map<String, dynamic> fullData) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.asset(
              image,
              height: 180,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  width: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiwayatSampahScreen(
                            pickupData: fullData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Detail",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Helper methods
  String _formatTodayDate() {
    final now = DateTime.now();
    const List<String> months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  int _getCompletedCount() {
    return todayPickups.where((p) => p['status'] == 'completed').length;
  }

  int _getPendingCount() {
    return todayPickups.where((p) => 
      p['status'] == 'pending' || p['status'] == 'scheduled' || p['status'] == 'on_progress'
    ).length;
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
      case 'scheduled':
        return {
          'label': 'Dijadwalkan',
          'color': Colors.blue[600],
        };
      case 'on_progress':
        return {
          'label': 'Dalam Proses',
          'color': Colors.orange[600],
        };
      case 'completed':
        return {
          'label': 'Selesai',
          'color': Colors.green[600],
        };
      case 'cancelled':
        return {
          'label': 'Dibatalkan',
          'color': Colors.red[600],
        };
      case 'skipped':
        return {
          'label': 'Dilewati',
          'color': Colors.grey[600],
        };
      default:
        return {
          'label': status,
          'color': Colors.grey[600],
        };
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pengambilan_sampah_screen.dart';
import 'ambil_foto_screen.dart';
import '../../services/pickup_service.dart';
import '../../services/kolektor_notification_service.dart';
import '../../services/user_storage.dart';
import 'profile_screen.dart';
import 'riwayat_sampah_screen.dart';
import '../user/notification_screen.dart';
import '../user/notification_service.dart';
import 'dart:io';

class HomeScreensKolektor extends StatefulWidget {
  const HomeScreensKolektor({super.key});

  @override
  State<HomeScreensKolektor> createState() => _HomeScreensKolektorState();
}

class _HomeScreensKolektorState extends State<HomeScreensKolektor> {
  List<Map<String, dynamic>> pengambilanList = [];
  List<Map<String, dynamic>> todayPickups = [];
  String _userName = 'Kolektor';
  bool _isLoadingPickups = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;
  int _unreadNotifCount = 0;
  bool _hasShownWelcomeMessage = false;
  int _selectedIndex = 0;
  int _riwayatTabIndex = 0; // 0 = Pengambilan, 1 = Pengangkutan

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// Initialize semua data dan trigger notifikasi otomatis
  Future<void> _initializeData() async {
    await _loadUserData();
    await _loadTodayPickups();
    await _loadPengambilanData();

    // Trigger notifikasi otomatis setelah data dimuat
    await _checkAndTriggerNotifications();

    // Load unread notification count
    await _loadUnreadNotifCount();
  }

  /// Load user data dari UserStorage
  Future<void> _loadUserData() async {
    final name = await UserStorage.getUserName();
    if (mounted) {
      setState(() {
        _userName = name ?? 'Kolektor';
      });
    }
  }

  /// Check dan trigger notifikasi otomatis
  Future<void> _checkAndTriggerNotifications() async {
    try {
      await KolektorNotificationService.checkAndTriggerNotifications(
        todayPickups: todayPickups,
        recentHistory: pengambilanList,
      );

      // Send daily reminder jika perlu (pagi hari)
      await KolektorNotificationService.sendDailyReminders(todayPickups);

      // Refresh unread count setelah check notifikasi
      await _loadUnreadNotifCount();
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  /// Load unread notification count untuk badge
  Future<void> _loadUnreadNotifCount() async {
    final count = await NotificationService.getUnreadCount(isKolektor: true);
    if (mounted) {
      setState(() {
        _unreadNotifCount = count;
      });
    }
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

      // Trigger notifikasi setelah data pickup dimuat
      if (success && data != null && data.isNotEmpty) {
        await _checkAndTriggerNotifications();
      }
    }
  }

  Future<void> _loadPengambilanData() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final (success, message, data) =
        await PickupService.getPickupHistoryFromAPI();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (success && data != null) {
          pengambilanList = data;
        } else {
          pengambilanList = [];
        }
      });

      // Trigger notifikasi setelah data history dimuat
      if (success && data != null && data.isNotEmpty) {
        await _checkAndTriggerNotifications();
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Build image widget dengan handling untuk berbagai tipe path
  Widget _buildPickupImage(String imagePath) {
    print('📷 [HomeKolektor] Building pickup image: $imagePath');

    // Placeholder widget jika image kosong
    if (imagePath.isEmpty) {
      return Container(
        height: 180,
        width: 100,
        color: Colors.grey[300],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      );
    }

    // Convert relative URL to full URL if needed (from API)
    String finalImagePath = imagePath;
    if (!imagePath.startsWith('http') &&
        !imagePath.startsWith('assets/') &&
        imagePath.startsWith('/')) {
      finalImagePath = 'https://smart-environment-web.citiasiainc.id$imagePath';
      print('🔄 [HomeKolektor] Converted to full URL: $finalImagePath');
    }

    // HTTP/HTTPS URL - gunakan Image.network
    if (finalImagePath.startsWith('http://') ||
        finalImagePath.startsWith('https://')) {
      print('🌐 [HomeKolektor] Loading network image: $finalImagePath');
      return Image.network(
        finalImagePath,
        height: 180,
        width: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ [HomeKolektor] Image load error: $error');
          return Container(
            height: 180,
            width: 100,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Gagal memuat',
                    style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ [HomeKolektor] Image loaded successfully');
            return child;
          }
          return Container(
            height: 180,
            width: 100,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    // File path lokal (dimulai dengan / atau berisi path lengkap) - hanya untuk file lokal sebenarnya
    if (finalImagePath.startsWith('/') ||
        finalImagePath.contains('storagePickups')) {
      final file = File(finalImagePath);

      // Cek apakah file exists
      if (!file.existsSync()) {
        return Container(
          height: 180,
          width: 100,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'File tidak ditemukan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }

      return Image.file(
        file,
        height: 180,
        width: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            width: 100,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          );
        },
      );
    }

    // Asset path (fallback - untuk backward compatibility)
    return Image.asset(
      finalImagePath,
      height: 180,
      width: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          width: 100,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Asset tidak ditemukan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan welcome message jika ada dari login
    if (!_hasShownWelcomeMessage && !_isLoadingPickups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['welcomeMessage'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      args['welcomeMessage'],
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _hasShownWelcomeMessage = true;
          });
        }
      });
    }

    final Color primaryColor = const Color(0xFF009688);
    final TextStyle titleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _selectedIndex == 0
          ? _buildBerandaPage(primaryColor, titleStyle)
          : _selectedIndex == 1
          ? _buildPengangkutanPage(primaryColor, titleStyle)
          : _selectedIndex == 2
          ? _buildRiwayatPage(primaryColor)
          : ProfileScreen(onProfileUpdated: (_) {}),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Pengangkutan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildBerandaPage(Color primaryColor, TextStyle titleStyle) {
    return SafeArea(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
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
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification button dengan badge
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationScreen(
                                        isKolektor: true,
                                      ),
                                ),
                              );
                              // Refresh unread count setelah kembali dari notification screen
                              await _loadUnreadNotifCount();
                            },
                            icon: const Icon(
                              Icons.notifications_outlined,
                              size: 26,
                            ),
                            color: Colors.black87,
                          ),
                          // Badge untuk unread notifications
                          if (_unreadNotifCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    _unreadNotifCount > 9
                                        ? '9+'
                                        : _unreadNotifCount.toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                    colors: [primaryColor, primaryColor.withOpacity(0.85)],
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(todayPickups.length.toString(), "Total"),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _statItem(_getCompletedCount().toString(), "Selesai"),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _statItem(_getPendingCount().toString(), "Belum"),
                        ],
                      ),
                    ),
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
                      final houseInfo =
                          pickup['house_info'] as Map<String, dynamic>?;
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
                          item["image"]?.toString() ??
                              "assets/images/dummy.jpg",
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
    );
  }

  Widget _buildPengangkutanPage(Color primaryColor, TextStyle titleStyle) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Pengangkutan',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Fitur Belum Tersedia',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Fitur pengangkutan sedang dalam pengembangan dan akan segera hadir',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatPage(Color primaryColor) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Riwayat',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _riwayatTabIndex = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _riwayatTabIndex == 0
                                ? primaryColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pengambilan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _riwayatTabIndex == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _riwayatTabIndex == 0
                              ? primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _riwayatTabIndex = 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _riwayatTabIndex == 1
                                ? primaryColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pengangkutan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _riwayatTabIndex == 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _riwayatTabIndex == 1
                              ? primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content based on selected tab
          Expanded(
            child: _riwayatTabIndex == 0
                ? _buildRiwayatPengambilanContent(primaryColor)
                : _buildRiwayatPengangkutanContent(primaryColor),
          ),
        ],
      ),
    );
  }

  // Riwayat Pengambilan Content
  Widget _buildRiwayatPengambilanContent(Color primaryColor) {
    return _isLoadingHistory
        ? const Center(child: CircularProgressIndicator())
        : pengambilanList.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada riwayat pengambilan',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pengambilanList.length,
                itemBuilder: (context, index) {
                  final item = pengambilanList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: _buildPickupImage(
                            item["image"]?.toString() ??
                                "assets/images/dummy.jpg",
                          ),
                        ),
                      ),
                      title: Text(
                        item["name"]?.toString() ?? "Unknown",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            item["address"]?.toString() ?? "",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Rp. ${(item["totalPrice"] as num?)?.toInt() ?? 0}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RiwayatSampahScreen(pickupData: item),
                            ),
                          );
                        },
                        child: Text(
                          'Detail',
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
  }

  // Riwayat Pengangkutan Content (Fitur belum tersedia)
  Widget _buildRiwayatPengangkutanContent(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Fitur Belum Tersedia',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Riwayat pengangkutan akan tersedia setelah fitur pengangkutan aktif',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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

  Widget _taskCard(
    String name,
    String address,
    String pickupId,
    String status,
    double latitude,
    double longitude,
    Color primaryColor,
    BuildContext context,
    Map<String, dynamic> pickupData,
  ) {
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
          ),
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
              onPressed:
                  status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'skipped' ||
                      status == 'collected'
                  ? null
                  : () {
                      final houseInfo =
                          pickupData['house_info'] as Map<String, dynamic>?;

                      // Jika status on_progress, langsung ke halaman Ambil Foto
                      if (status == 'on_progress') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AmbilFotoScreen(
                              pickupId: pickupData['id'] as int,
                              userName:
                                  pickupData['user_name'] as String? ?? name,
                              address: address,
                              idPengambilan: pickupId,
                            ),
                          ),
                        ).then((_) {
                          // Refresh data setelah kembali dari foto screen
                          _loadTodayPickups();
                          _loadPengambilanData();
                        });
                        return;
                      }

                      // Untuk status pending/scheduled, navigasi ke PengambilanSampahScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PengambilanSampahScreen(
                            pickupId: pickupData['id'] as int,
                            userName:
                                pickupData['user_name'] as String? ?? name,
                            userPhone: houseInfo?['phone'] as String? ?? '-',
                            address: address,
                            idPengambilan: pickupId,
                            distance: '0.5 km',
                            time: '5 min',
                            latitude: houseInfo?['latitude'] as double? ?? 0.0,
                            longitude:
                                houseInfo?['longitude'] as double? ?? 0.0,
                            status: status, // Tambahkan parameter status
                          ),
                        ),
                      ).then((_) {
                        // Refresh list setelah kembali
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
                status == 'on_progress'
                    ? "Lanjutkan"
                    : status == 'completed'
                    ? "Selesai"
                    : "Ambil",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickupCard(
    String name,
    String address,
    String price,
    String image,
    Color primaryColor,
    Map<String, dynamic> fullData,
  ) {
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
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: _buildPickupImage(image),
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
                          builder: (context) =>
                              RiwayatSampahScreen(pickupData: fullData),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatTodayDate() {
    final now = DateTime.now();
    const List<String> months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  int _getCompletedCount() {
    return todayPickups
        .where((p) => p['status'] == 'completed' || p['status'] == 'collected')
        .length;
  }

  int _getPendingCount() {
    return todayPickups
        .where(
          (p) =>
              p['status'] == 'pending' ||
              p['status'] == 'scheduled' ||
              p['status'] == 'on_progress',
        )
        .length;
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
      case 'scheduled':
        return {'label': 'Dijadwalkan', 'color': Colors.blue[600]};
      case 'on_progress':
        return {'label': 'Dalam Proses', 'color': Colors.orange[600]};
      case 'collected':
        return {'label': 'Selesai', 'color': Colors.green[600]};
      case 'completed':
        return {'label': 'Selesai', 'color': Colors.green[600]};
      case 'cancelled':
        return {'label': 'Dibatalkan', 'color': Colors.red[600]};
      case 'skipped':
        return {'label': 'Dilewati', 'color': Colors.grey[600]};
      default:
        return {'label': status, 'color': Colors.grey[600]};
    }
  }
}

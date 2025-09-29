import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _username = "";
  List<Map<String, dynamic>> _akunList = []; // semua akun layanan
  Map<String, dynamic>? _selectedAkun; // akun yang dipilih

  // untuk deteksi penambahan akun baru (hindari notifikasi saat initial load)
  bool _hasLoadedAkunOnce = false;

  // unread notification counter
  int _unreadNotifCount = 0;

  // TIPS CARD: Page Controller dan state halaman saat ini
  final PageController _tipsController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initAll();

    // Inisialisasi listener untuk PageController Tips
    _tipsController.addListener(() {
      if (_tipsController.page != null) {
        int next = _tipsController.page!.round();
        if (_currentPage != next) {
          setState(() {
            _currentPage = next;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tipsController.dispose(); // Wajib dispose controller
    super.dispose();
  }

  Future<void> _initAll() async {
    // jalankan load secara berurutan agar logic deteksi tambahan akun benar
    await _loadUser();
    await _loadAkunLayanan(selectLastIfNotFound: true); // initial load akun
    await _loadUnreadNotif(); // load badge notif
    // tandai bahwa initial akun sudah di-load agar penambahan berikutnya memicu notif
    _hasLoadedAkunOnce = true;
  }

  // Initial loader (name + shimmer)
  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("name") ?? "User";

    await Future.delayed(const Duration(milliseconds: 300)); // kecilkan delay
    if (!mounted) return;
    setState(() {
      _username = savedName;
      _isLoading = false;
    });
  }

  // Refresh nama user
  Future<void> _refreshUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("name") ?? "User";
    if (!mounted) return;
    setState(() {
      _username = savedName;
    });
  }

  /// Load jumlah notifikasi (untuk badge)
  Future<void> _loadUnreadNotif() async {
    try {
      final list = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotifCount = list.where((n) => n['isRead'] == false).length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unreadNotifCount = 0;
      });
    }
  }

  /// Load akun layanan dari SharedPreferences.
  Future<bool> _loadAkunLayanan({bool selectLastIfNotFound = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final prevCount = _akunList.length;
    final data = prefs.getStringList('akun_layanan') ?? [];

    // convert safely
    final akunList = <Map<String, dynamic>>[];
    for (final s in data) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(s));
        akunList.add(m);
      } catch (_) {
        // ignore malformed entry
      }
    }

    if (!mounted) return false;
    setState(() {
      _akunList = akunList;
      if (akunList.isEmpty) {
        _selectedAkun = null;
      } else {
        if (_selectedAkun != null) {
          final idx = akunList.indexWhere(
              (a) => a['id']?.toString() == _selectedAkun!['id']?.toString());
          if (idx != -1) {
            _selectedAkun = akunList[idx];
          } else {
            _selectedAkun =
                selectLastIfNotFound ? akunList.last : akunList.first;
          }
        } else {
          // default pilih akun terakhir (jika ada)
          _selectedAkun = akunList.isNotEmpty ? akunList.last : null;
        }
      }
    });

    final added = (akunList.length > prevCount);
    // jika sudah pernah load sebelumnya dan sekarang ada tambahan akun -> simpan notifikasi
    if (_hasLoadedAkunOnce && added) {
      await NotificationService.addNotification("Akun layanan berhasil dibuat.");
      await _loadUnreadNotif();
    }
    return added;
  }

  void _showSnackBar(String message, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.cancel,
                color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.poppins())),
          ],
        ),
        backgroundColor: success
            ? const Color.fromARGB(255, 21, 145, 137)
            : Colors.red,
      ),
    );
  }

  /// Tampilkan bottom sheet untuk memilih akun.
  void _showAkunSelector() async {
    if (_akunList.isEmpty) {
      // langsung ke halaman tambah akun
      await Navigator.pushNamed(context, '/layanan-sampah');
      final added = await _loadAkunLayanan(selectLastIfNotFound: true);
      if (added) await _loadUnreadNotif();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 6,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 21, 145, 137),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text("Pilih Akun Layanan",
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.pushNamed(context, '/layanan-sampah');
                        final added =
                            await _loadAkunLayanan(selectLastIfNotFound: true);
                        if (added) await _loadUnreadNotif();
                      },
                      icon: const Icon(Icons.add),
                      label: Text("Tambah", style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _akunList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final akun = _akunList[index];
                    final isSelected = _selectedAkun != null &&
                        akun['id']?.toString() ==
                            _selectedAkun!['id']?.toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color.fromARGB(255, 21, 145, 137)
                                .withOpacity(0.12), // Sesuaikan warna
                        child: const Icon(Icons.home,
                            color: Color.fromARGB(255, 21, 145, 137)),
                      ),
                      title: Text(akun["nama"] ?? "Akun Layanan",
                          style: GoogleFonts.poppins(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600)),
                      subtitle: Text(akun["alamat lengkap"] ?? "-",
                          style: GoogleFonts.poppins(fontSize: 13)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Color.fromARGB(255, 21, 145, 137))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedAkun = akun;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // helper to open layanan-sampah and refresh states after return
  Future<void> _openLayananSampahAndRefresh() async {
    await Navigator.pushNamed(context, '/layanan-sampah');
    final added = await _loadAkunLayanan(selectLastIfNotFound: true);
    if (added) await _loadUnreadNotif();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo ${_isLoading ? 'User' : _username},", // tampilkan "User" jika loading
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              "Selamat Datang",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          // 🔔 Notifikasi dengan badge
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                  // refresh counter saat kembali dari screen notifikasi
                  await _loadUnreadNotif();
                },
                icon: const Icon(Icons.notifications, color: Colors.black),
              ),
              if (_unreadNotifCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                        minWidth: 16, minHeight: 16), // agar lebih rapi
                    child: Center(
                      child: Text(
                        _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                        style: const TextStyle(
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

          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/profile');
              await _refreshUser();
              await _loadAkunLayanan();
            },
            icon: const Icon(Icons.person, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading ? _buildShimmer() : _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Tagihan Sampah Card (tap untuk pilih / tambah akun) =====
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (_akunList.isEmpty) {
                  // langsung ke tambah akun
                  await _openLayananSampahAndRefresh();
                } else {
                  _showAkunSelector();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage("assets/images/bg1.png"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // icon box
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child:
                          Image.asset("assets/images/wallet.png", height: 40),
                    ),
                    const SizedBox(width: 12),

                    // account info (animated)
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        transitionBuilder: (child, anim) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                        child: _selectedAkun == null
                            ? Column(
                                key: const ValueKey('empty_card'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Belum ada akun",
                                      style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                  const SizedBox(height: 4),
                                  Text("Tambahkan akun dulu",
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color.fromARGB(
                                              255, 21, 145, 137))),
                                ],
                              )
                            : Column(
                                key: ValueKey(
                                    'akun_${_selectedAkun!['id'] ?? 'sel'}'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedAkun!["nama"] ?? "Akun Layanan",
                                      style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                  const SizedBox(height: 4),
                                  Text(
                                      _selectedAkun!["alamat lengkap"] ?? "-",
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color.fromARGB(
                                              255, 21, 145, 137))),
                                ],
                              ),
                      ),
                    ),

                    // tombol (AnimatedSwitcher)
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_selectedAkun == null) {
                            // buka halaman tambah akun
                            await _openLayananSampahAndRefresh();
                          } else {
                            // tambahkan notifikasi untuk pembayaran
                            await NotificationService.addNotification(
                                "Pembayaran untuk akun ${_selectedAkun!["nama"]} berhasil.");
                            await _loadUnreadNotif();
                            _showSnackBar(
                                "Pembayaran untuk akun ${_selectedAkun!["nama"]} berhasil!",
                                true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 21, 145, 137),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _selectedAkun == null
                              ? Row(
                                  key: const ValueKey('addBtn'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add,
                                        size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text("Create",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white))
                                  ],
                                )
                              : Text("Bayar",
                                  key: const ValueKey('payBtn'),
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)), // tambahkan bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ===== Daftar layanan (tetap seperti semula) =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Daftar Layanan",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Lainnya",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                _menuItem(
                  "assets/images/keranjang.png",
                  "Akun Layanan\nSampah",
                  onTap: () async {
                    await _openLayananSampahAndRefresh();
                  },
                ),
                _menuItem(
                  "assets/images/rekening.png",
                  "Riwayat Layanan\nSampah",
                  onTap: () {
                    _showSnackBar("Fitur Riwayat Layanan belum tersedia", false);
                  },
                ),
                _menuItem(
                  "assets/images/artikel.png",
                  "Artikel",
                  onTap: () {
                    _showSnackBar("Fitur Artikel belum tersedia", false);
                  },
                ),
                _menuItem(
                  "assets/images/pelanggaran.png",
                  "Pengaduan",
                  onTap: () async {
                    await NotificationService.addNotification("Pengaduan dikirim.");
                    await _loadUnreadNotif();
                    _showSnackBar("Fitur Pengaduan belum tersedia", false);
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ===== Serahkan Sampah (Pickup) =====
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage("assets/images/bg2.png"),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 170),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Serahkan Sampah disini",
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black)),
                              const SizedBox(height: 4),
                              Text("Agar Driver bisa menjemput sampahmu",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: Colors.black)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                             _showSnackBar("Fitur Serahkan Sampah belum tersedia", false);
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.green,
                          ),
                          child: const Icon(Icons.arrow_forward, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ===================================================
            // ===== TIPS RAMAH LINGKUNGAN (BARU) =====
            // ===================================================
            Text(
              "Tips Ramah Lingkungan",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // --- PageView Tips ---
            SizedBox(
              height: 180, // Ketinggian ditambah sedikit agar card lebih lega
              child: PageView(
                controller: _tipsController,
                children: [
                  _tipsCard(
                    icon: Icons.recycling,
                    title: "Pisahkan Sampah",
                    subtitle:
                        "Pisahkan sampah organik & anorganik agar mudah didaur ulang.",
                    index: 0,
                    backgroundColor: const Color.fromARGB(255, 21, 145, 137), // Hijau utama
                  ),
                  _tipsCard(
                    icon: Icons.lightbulb_outline,
                    title: "Hemat Energi",
                    subtitle: "Matikan lampu & cabut charger saat tidak digunakan.",
                    index: 1,
                    backgroundColor: Colors.blue.shade600, // Biru untuk energi
                  ),
                  _tipsCard(
                    icon: Icons.water_drop_outlined,
                    title: "Hemat Air",
                    subtitle: "Gunakan air seperlunya, perbaiki keran bocor segera.",
                    index: 2,
                    backgroundColor: Colors.orange.shade700, // Oranye untuk air
                  ),
                  _tipsCard(
                    icon: Icons.shopping_bag_outlined,
                    title: "Kurangi Plastik",
                    subtitle: "Bawa tas belanja sendiri untuk mengurangi sampah plastik.",
                    index: 3,
                    backgroundColor: Colors.purple.shade600, // Ungu/Pink untuk plastik
                  ),
                ],
              ),
            ),

            // --- Indikator Halaman ---
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4, // Jumlah tips = 4
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8, // Lebar memanjang jika aktif
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color.fromARGB(255, 21, 145, 137) // Warna aktif
                        : Colors.grey.shade300, // Warna tidak aktif
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Shimmer loading
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 20, width: 150),
          const SizedBox(height: 10),
          _shimmerBox(height: 16, width: 100),
          const SizedBox(height: 20),
          _shimmerBox(height: 80, width: double.infinity, radius: 16),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  _shimmerBox(height: 50, width: 50, radius: 16),
                  const SizedBox(height: 6),
                  _shimmerBox(height: 12, width: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          _shimmerBox(height: 180, width: double.infinity, radius: 16),
          const SizedBox(height: 30),
          _shimmerBox(height: 160, width: double.infinity, radius: 16),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // helper menu item
  static Widget _menuItem(String asset, String title, {VoidCallback? onTap}) {
    return Column(
      children: [
        Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Image.asset(asset, height: 40, filterQuality: FilterQuality.high),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // NEW: Tips Card Penuh Warna (Ide A)
  Widget _tipsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    required Color backgroundColor, // Parameter baru
  }) {
    // Hitung skala berdasarkan halaman saat ini (untuk efek 3D di PageView)
    final scale = (_currentPage == index) ? 1.0 : 0.95;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Margin vertikal ditambah agar efek bayangan tidak terpotong
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
      transform: Matrix4.identity()..scale(scale), // Terapkan skala
      alignment: Alignment.center,
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor, // Menggunakan warna latar penuh
        borderRadius: BorderRadius.circular(16),
        // Bayangan lebih kuat dan sesuai warna
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.4), 
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box HILANG, diganti Icon putih besar langsung
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white, // Teks warna putih
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70, // Teks subtitle lebih redup
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
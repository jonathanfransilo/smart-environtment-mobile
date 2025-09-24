import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔹 Dummy pages
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Halaman Status", style: TextStyle(fontSize: 18))),
    );
  }
}

class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Halaman Riwayat", style: TextStyle(fontSize: 18))),
    );
  }
}

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Halaman Profil", style: TextStyle(fontSize: 18))),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _username = "";
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.cancel, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("name") ?? "User";

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _username = savedName;
      _isLoading = false;
    });

    _showSnackBar("Halo $_username, selamat datang kembali!", true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Halo $_username,",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  const Text("Selamat Datang",
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    _showSnackBar("Fitur Notifikasi belum tersedia", true);
                  },
                  icon: const Icon(Icons.notifications, color: Colors.black),
                ),
              ],
            )
          : null,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return _isLoading ? _buildShimmer() : _buildHomeContent();
    } else if (_selectedIndex == 1) {
      return const StatusScreen();
    } else if (_selectedIndex == 2) {
      return const RiwayatScreen();
    } else {
      return const ProfilScreen();
    }
  }

  /// 🔹 Halaman Beranda (asli)
  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Rekening Sampah
            Container(
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset("assets/images/wallet.png", height: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tagihan Sampah",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        Text("Rp. 100.000",
                            style: TextStyle(
                                fontSize: 14,
                                color: Color.fromARGB(255, 21, 145, 137))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text("Bayar",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 🔹 Daftar Layanan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Daftar Layanan",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("Lainnya",
                    style: TextStyle(fontSize: 14, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _menuItem(
                  "assets/images/keranjang.png",
                  "Layanan\nSampah",
                  onTap: () {
                    Navigator.pushNamed(context, '/layanan-sampah');
                  },
                ),
                _menuItem(
                  "assets/images/rekening.png",
                  "Rekening",
                  onTap: () {
                    _showSnackBar("Fitur Rekening belum tersedia", false);
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
                  onTap: () {
                    _showSnackBar("Fitur Pengaduan belum tersedia", false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 🔹 Serahkan Sampah
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Serahkan Sampah disini",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black)),
                              SizedBox(height: 4),
                              Text("Agar Driver bisa menjemput sampahmu",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.green,
                          ),
                          child: const Icon(Icons.arrow_forward,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 🔹 Aktivitas Terakhir
            const Text("Aktivitas Terakhir",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _activityCard("Serah Sampah")),
                Expanded(child: _activityCard("Penghargaan")),
                Expanded(child: _activityCard("Rekening")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Shimmer Loading
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          _shimmerBox(height: 20, width: 150),
          const SizedBox(height: 10),
          _shimmerBox(height: 16, width: 100),
          const SizedBox(height: 20),

          // Rekening shimmer
          _shimmerBox(height: 80, width: double.infinity),
          const SizedBox(height: 30),

          // Menu shimmer
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

          // Banner shimmer
          _shimmerBox(height: 180, width: double.infinity, radius: 16),
          const SizedBox(height: 30),

          // Aktivitas shimmer
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: _shimmerBox(height: 80, width: double.infinity, radius: 12),
                ),
              ),
            ),
          ),
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
              child: Image.asset(asset, height: 40,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _activityCard(String title) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Center(
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: Colors.black87)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
        BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Status"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "Riwayat"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      ],
    );
  }
}

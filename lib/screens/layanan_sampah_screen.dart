import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tambah_akun_layanan_screen.dart'; // Pastikan file ini ada di project Anda

/// 🔹 Halaman utama daftar akun layanan
class LayananSampahScreen extends StatefulWidget {
  const LayananSampahScreen({super.key});

  @override
  State<LayananSampahScreen> createState() => _LayananSampahScreenState();
}

class _LayananSampahScreenState extends State<LayananSampahScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> akunLayanan = [];

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  /// 🔹 Simulasi shimmer loading sebelum load data
  Future<void> _startLoading() async {
    await Future.delayed(const Duration(seconds: 2)); // tampil shimmer 2 detik
    await _loadAkunLayanan();
  }

  /// 🔹 Muat data akun dari SharedPreferences
  Future<void> _loadAkunLayanan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('akun_layanan') ?? [];

    setState(() {
      akunLayanan =
          data.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
      _isLoading = false;
    });
  }

  /// 🔹 Simpan akun ke SharedPreferences
  Future<void> _saveAkunLayanan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = akunLayanan.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('akun_layanan', data);
  }

  void _showTambahAkunOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _optionCard(
                iconPath: "assets/images/terdaftar.svg",
                title: "Akun terdaftar",
                onTap: () {
                  Navigator.pop(context);

                  if (akunLayanan.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Harap membuat akun terlebih dahulu"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Akun sudah ada terdaftar"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _optionCard(
                iconPath: "assets/images/news.svg",
                title: "Buat akun baru",
                onTap: () async {
                  Navigator.pop(context);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TambahAkunLayananScreen(),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      result["hari_pengangkutan"] = "Senin & Kamis"; // dummy
                      akunLayanan.add(result);
                    });
                    await _saveAkunLayanan();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _optionCard({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconPath,
              height: 50,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Akun Layanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading ? _buildFullPageShimmer() : _buildContent(),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showTambahAkunOptions,
              icon: const Icon(Icons.add),
              label: const Text("Tambah Akun"),
              backgroundColor: const Color(0xFF4CAF50),
            )
          : null,
    );
  }

  /// 🔹 Shimmer fullscreen
  Widget _buildFullPageShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Konten utama
  Widget _buildContent() {
    final bool adaAkun = akunLayanan.isNotEmpty;

    if (!adaAkun) {
      return Center(
        child: Text(
          "Belum ada akun layanan.\nSilakan tambahkan akun baru.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: akunLayanan.length,
      itemBuilder: (context, index) {
        final akun = akunLayanan[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DetailAkunLayananScreen(akun: akun, onDelete: _loadAkunLayanan),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF4CAF50).withOpacity(0.15),
                  child: const Icon(Icons.home, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        akun["id"] ?? "ID",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        akun["nama"] ?? "-",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        akun["alamat lengkap"] ?? "-",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 18, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// DETAIL AKUN LAYANAN SCREEN (Diperbaiki di bagian _showStatusDialog)
// -----------------------------------------------------------------------------

/// 🔹 Halaman detail akun layanan
class DetailAkunLayananScreen extends StatelessWidget {
  final Map<String, dynamic> akun;
  final VoidCallback onDelete;

  const DetailAkunLayananScreen({
    super.key,
    required this.akun,
    required this.onDelete,
  });

  Future<void> _hapusAkun(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('akun_layanan') ?? [];

    data.removeWhere((item) {
      final map = Map<String, dynamic>.from(jsonDecode(item));
      return map["id"] == akun["id"];
    });

    await prefs.setStringList('akun_layanan', data);

    Navigator.pop(context);
    onDelete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Akun berhasil dihapus"),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _konfirmasiHapus(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Hapus Akun"),
          content: const Text("Apakah Anda yakin ingin menghapus akun ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _hapusAkun(context);
              },
              child: const Text(
                "Hapus",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Popup Status (TELAH DIPERBAIKI SESUAI PERMINTAAN)
  void _showStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Warna untuk status "Belum Diambil" (Oranye)
                    color: Colors.orange.withOpacity(0.1),
                  ),
                  child: const Icon(
                    // Ikon untuk status "Belum Diambil" (Jam Pasir/Menunggu)
                    Icons.hourglass_empty, 
                    size: 60,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  // Teks status yang diminta
                  "Sampah belum diambil Kolektor",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      // Warna tombol disesuaikan dengan status "Belum Diambil" (Oranye)
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Detail Akun Layanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.15),
                    child: const Icon(Icons.home,
                        size: 32, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          akun["nama"] ?? "-",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          akun["alamat lengkap"] ?? "-",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /// Info List
            _infoCard(Icons.badge, "ID Akun", akun["id"] ?? "-"),
            _infoCard(Icons.person, "Nama", akun["nama"] ?? "-"),
            _infoCard(Icons.location_on, "Alamat Lengkap",
                akun["alamat lengkap"] ?? "-"),

            const SizedBox(height: 24),

            /// Jadwal Angkut
            Text(
              "Hari Pengangkutan Sampah",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    akun["hari_pengangkutan"] ?? "Senin & Kamis",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            /// Tombol Aksi
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusDialog(context),
                    icon: const Icon(Icons.restore_from_trash),
                    label: const Text("Status Sampah"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _konfirmasiHapus(context),
                    icon: const Icon(Icons.delete),
                    label: const Text("Hapus Akun"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 220, 61, 61),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget info card dengan icon
  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
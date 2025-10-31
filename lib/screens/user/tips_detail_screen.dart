import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TipsDetailScreen extends StatelessWidget {
  // Variabel untuk menampung data yang dikirim dari HomeScreen
  final String tipTitle;
  final String tipContent;

  const TipsDetailScreen({
    super.key,
    required this.tipTitle,
    required this.tipContent,
  });

  // Method untuk mendapatkan path gambar berdasarkan tipTitle
  String _getImagePath() {
    switch (tipTitle) {
      case "Pisahkan Sampah":
        return 'assets/images/organik dan anorganik.jpg';
      case "Hemat Energi":
        return 'assets/images/hemat energi.jpeg';
      case "Hemat Air":
        return 'assets/images/hemat air.jpeg';
      case "Kurangi Plastik":
        return 'assets/images/kurangi plastik.jpeg';
      default:
        return ''; // Tidak ada gambar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar disesuaikan agar sesuai dengan tema hijau aplikasi Anda
      appBar: AppBar(
        title: Text(
          tipTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(
          255,
          21,
          145,
          137,
        ), // Warna hijau utama
        foregroundColor: Colors.white, // Warna ikon dan teks menjadi putih
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul Tips (diulang untuk penekanan)
            Text(
              "Detail Tips:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // Konten Tips
            Text(
              tipContent,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.5,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 30),

            // --- Gambar Terkait Tips ---
            // Tampilkan gambar berdasarkan tipTitle
            if (_getImagePath().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _getImagePath(),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Jika gambar tidak ditemukan, tampilkan placeholder
                    return Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Gambar tidak tersedia",
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              // Placeholder jika tidak ada gambar
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Area Gambar/Infografis Terkait Tips",
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Import ini dibutuhkan untuk format tanggal

// Fungsi utama untuk menjalankan aplikasi
void main() {
  // Pastikan Anda memiliki direktori assets/images/ dan file dummy.jpg
  // untuk menjalankan kode ini tanpa error.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Pelaporan',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        // Mengatur tema warna primer
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const PelaporanScreen(), // Mulai dari layar utama
    );
  }
}

// ====================================================================
// BAGIAN 0: MODEL DATA
// ====================================================================

// Model data untuk menyimpan satu laporan
class Laporan {
  final String id;
  final String kota;
  final String kategori;
  final String lokasi;
  final String waktuPelanggaran;
  final String ciriCiri;
  final File? imageFile;
  final bool isAsset;
  final DateTime createdAt; // Tambahkan timestamp

  Laporan({
    required this.kota,
    required this.kategori,
    required this.lokasi,
    required this.waktuPelanggaran,
    required this.ciriCiri,
    this.imageFile,
    required this.isAsset,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString(), // ID unik sederhana
       createdAt = DateTime.now();

  // Helper untuk mendapatkan deskripsi singkat
  String get shortDescription => "$kategori di $lokasi";
}

// ====================================================================
// BAGIAN 1: SCREEN FORM PENGISIAN LAPORAN (BuatLaporanScreen)
// ====================================================================

class BuatLaporanScreen extends StatefulWidget {
  final File? imageFile;
  final bool isAsset;

  const BuatLaporanScreen({
    super.key,
    required this.imageFile,
    required this.isAsset,
  });

  @override
  State<BuatLaporanScreen> createState() => _BuatLaporanScreenState();
}

class _BuatLaporanScreenState extends State<BuatLaporanScreen> {
  // Controller untuk mengelola input text dari TextField
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _waktuController = TextEditingController();
  final TextEditingController _jamController = TextEditingController();
  final TextEditingController _ciriCiriController = TextEditingController();
  
  // State untuk menyimpan tanggal yang dipilih (opsional, untuk logika)
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // Pilihan Data Dropdown
  static const String _fixedCity = 'Jakarta'; // Kota tetap Jakarta

  static const List<String> _categories = [
    'Sampah Liar', 'Fasilitas Rusak', 'Tempat Sampah Penuh',
    'Pengambilan sampah tidak sesuai SOP', 'Warga buang sampah sembarangan',
    'Warga merusak fasilitas', 'Petugas tidak ramah', 'Lainnya',
  ];

  // State untuk menyimpan nilai yang dipilih
  String? _selectedCategory;
  
  // Kunci form untuk validasi
  final _formKey = GlobalKey<FormState>();

  // Warna Utama (digunakan untuk tombol dan ikon, dll.)
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void dispose() {
    _lokasiController.dispose();
    _waktuController.dispose();
    _jamController.dispose();
    _ciriCiriController.dispose();
    super.dispose();
  }

  // Fungsi untuk menghasilkan DropdownMenuItem dari List<String>
  List<DropdownMenuItem<String>> _buildDropdownItems(List<String> options) {
    return options.map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }

  // Fungsi untuk menampilkan Date Picker (Kalender)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Hanya bisa memilih tanggal hari ini atau sebelumnya
      helpText: 'Pilih Tanggal Pelanggaran',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Format tanggal ke String dan masukkan ke controller
        _waktuController.text = DateFormat('dd MMMM yyyy').format(picked);
      });
    }
  }

  // Fungsi untuk menampilkan Time Picker (Jam)
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: 'Pilih Jam Pelanggaran',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.light(primary: primaryColor),
            buttonTheme: ButtonThemeData(
              colorScheme: ColorScheme.light(primary: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        // Format jam ke String dan masukkan ke controller
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _jamController.text = '$hour:$minute';
      });
    }
  }

  // Fungsi Navigasi ke DetailLaporanScreen
  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Pastikan semua dropdown terisi
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Mohon lengkapi semua field yang wajib diisi.", style: GoogleFonts.poppins()),
          ),
        );
        return;
      }

      // Ambil semua data dari state dan controller
      final waktuLengkap = '${_waktuController.text}${_jamController.text.isNotEmpty ? ' pukul ${_jamController.text}' : ''}';
      final reportData = {
        'kota': _fixedCity,
        'kategori': _selectedCategory!,
        'lokasi': _lokasiController.text,
        'waktu_pelanggaran': waktuLengkap, 
        'ciri_ciri': _ciriCiriController.text,
      };

      // Navigasi ke DetailLaporanScreen
      // ⭐️ BuatLaporanScreen menunggu hasil dari DetailLaporanScreen
      Navigator.of(context).push(
        MaterialPageRoute<Laporan>(
          builder: (ctx) => DetailLaporanScreen(
            reportData: reportData,
            imageFile: widget.imageFile,
            isAsset: widget.isAsset,
          ),
        ),
      ).then((newReport) {
        // Jika DetailLaporanScreen me-return objek Laporan (artinya dikonfirmasi)
        if (newReport is Laporan) {
          // Kirim objek Laporan ini kembali ke PelaporanScreen (pop dua kali)
          Navigator.of(context).pop(newReport);
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan (Image.file atau Image.asset)
    Widget imageWidget;
    if (widget.isAsset) {
      // Menggunakan Image.asset untuk dummy image (asumsi file ada di assets/images/dummy.jpg)
      imageWidget = Image.asset(
        "assets/images/dummy.jpg", 
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          color: Colors.grey.shade300,
          child: const Center(child: Text("Error: Asset dummy.jpg tidak ditemukan")),
        ),
      );
    } else if (widget.imageFile != null) {
      // Menggunakan Image.file untuk gambar dari galeri/kamera
      imageWidget = Image.file(
        widget.imageFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
      );
    } else {
      // Kasus fallback
      imageWidget = Container(
        width: double.infinity,
        height: 200, 
        color: Colors.grey.shade300,
        child: const Center(child: Text("Tidak ada gambar")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Area Foto dengan Tombol Ubah Foto
              Container(
                width: double.infinity,
                height: 200, // Fixed height untuk menjaga konsistensi
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand, // Memastikan stack mengisi container
                    children: [
                      // Pastikan image mengisi seluruh area
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: imageWidget,
                      ),
                      // Tombol Ubah Foto dengan posisi absolut
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            // Kembali ke PelaporanScreen untuk memilih foto baru
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              "UBAH FOTO",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- FORM FIELDS ---

              // KOTA TETAP (Jakarta)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kota',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fixedCity,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dropdown KATEGORI
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Kategori", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                items: _buildDropdownItems(_categories),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                hint: const Text('Pilih Kategori'),
                validator: (value) => value == null ? 'Kategori wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              // Lokasi 
              TextFormField(
                controller: _lokasiController,
                decoration: InputDecoration(
                  labelText: "Lokasi", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                validator: (value) => value!.isEmpty ? 'Lokasi wajib diisi.' : null, // Tambahkan validasi
              ),
              const SizedBox(height: 16),

              // Waktu Pelanggaran (MENGGUNAKAN DATE PICKER)
              TextFormField(
                controller: _waktuController,
                readOnly: true, // Agar keyboard tidak muncul saat diklik
                onTap: () => _selectDate(context), // Panggil kalender
                decoration: InputDecoration(
                  labelText: "Tanggal Pelanggaran", 
                  hintText: _selectedDate == null ? 'Pilih Tanggal' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.calendar_today, color: primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) => value!.isEmpty ? 'Tanggal Pelanggaran wajib diisi.' : null,
              ),
              const SizedBox(height: 16),

              // Jam Pelanggaran (MENGGUNAKAN TIME PICKER)
              TextFormField(
                controller: _jamController,
                readOnly: true, // Agar keyboard tidak muncul saat diklik
                onTap: () => _selectTime(context), // Panggil time picker
                decoration: InputDecoration(
                  labelText: "Jam Pelanggaran (Opsional)",
                  hintText: "Ketuk untuk memilih jam",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  suffixIcon: _jamController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                          onPressed: () {
                            setState(() {
                              _jamController.clear();
                              _selectedTime = null;
                            });
                          },
                        )
                      : Icon(Icons.schedule, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),

              // Ciri-ciri
              TextFormField(
                controller: _ciriCiriController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Ciri-ciri", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                validator: (value) => value!.isEmpty ? 'Ciri-ciri wajib diisi.' : null, // Tambahkan validasi
              ),
              const SizedBox(height: 32),
              
              // Tombol BUAT LAPORAN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport, // Panggil fungsi submit
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    "BUAT LAPORAN",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// BAGIAN 1.5: SCREEN DETAIL LAPORAN (DetailLaporanScreen)
// ====================================================================

class DetailLaporanScreen extends StatelessWidget {
  final Map<String, String> reportData;
  final File? imageFile;
  final bool isAsset;

  const DetailLaporanScreen({
    super.key,
    required this.reportData,
    required this.imageFile,
    required this.isAsset,
  });
  
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Fungsi: Menampilkan modal konfirmasi dan mengembalikan objek Laporan
  void _confirmReport(BuildContext context) {
    // 1. Buat objek Laporan baru
    final newReport = Laporan(
      kota: reportData['kota']!,
      kategori: reportData['kategori']!,
      lokasi: reportData['lokasi']!,
      waktuPelanggaran: reportData['waktu_pelanggaran']!,
      ciriCiri: reportData['ciri_ciri']!,
      imageFile: imageFile,
      isAsset: isAsset,
    );

    // 2. Tampilkan Dialog "Pelaporan Selesai"
    showDialog(
      context: context,
      barrierDismissible: false, // Tidak bisa ditutup dengan tap di luar
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // Menghilangkan padding default agar bisa mengisi seluruh lebar dialog
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              // Ikon Centang Hijau
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 40,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),
              // Judul
              Text(
                "Pelaporan Selesai",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              // Subteks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Proses pelaporan telah selesai, pelaporan anda akan segera kami proses",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Tombol OK
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // 1. Tutup Dialog
                      Navigator.of(dialogContext).pop(); 
                      
                      // 2. ⭐️ Kunci: Pop dari DetailLaporanScreen dan kirim objek Laporan
                      // Objek Laporan ini akan diterima oleh BuatLaporanScreen
                      Navigator.of(context).pop(newReport); 
                      
                      // Pesan sukses:
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: primaryColor,
                          content: Text("Laporan berhasil dikirim!", style: GoogleFonts.poppins()),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 68, 180, 219), // Warna biru muda sesuai gambar
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      "OK",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
  
  // Widget untuk menampilkan sepasang Label dan Value
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan (Image.file atau Image.asset)
    Widget imageWidget;
    if (isAsset) {
      imageWidget = Image.asset(
        "assets/images/dummy.jpg", 
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          color: Colors.grey.shade300,
          child: const Center(child: Text("Error: Asset dummy.jpg tidak ditemukan")),
        ),
      );
    } else if (imageFile != null) {
      imageWidget = Image.file(
        imageFile!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else {
      imageWidget = Container(
        height: 200, 
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(child: Text("Tidak ada gambar")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area Foto (Tanpa tombol ubah)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
            const SizedBox(height: 24),

            Text(
              "Detail Laporan",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Detail Data
            _buildDetailRow("Kota", reportData['kota'] ?? '-'),
            _buildDetailRow("Kategori", reportData['kategori'] ?? '-'),
            _buildDetailRow("Lokasi", reportData['lokasi'] ?? '-'),
            _buildDetailRow("Waktu Pelanggaran", reportData['waktu_pelanggaran'] ?? '-'),
            _buildDetailRow("Ciri-ciri Pelaku", reportData['ciri_ciri'] ?? '-'),

            const SizedBox(height: 32),

            // Tombol KONFIRMASI
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmReport(context), // Panggil fungsi konfirmasi
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "KONFIRMASI",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BAGIAN 1.6: SCREEN DETAIL LAPORAN TERKIRIM (DetailLaporanTerkirimScreen)
// ====================================================================

class DetailLaporanTerkirimScreen extends StatelessWidget {
  final Laporan laporan;

  const DetailLaporanTerkirimScreen({
    super.key,
    required this.laporan,
  });

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Widget untuk menampilkan sepasang Label dan Value
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;
    if (laporan.isAsset) {
      imageWidget = Image.asset(
        "assets/images/dummy.jpg",
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          color: Colors.grey.shade300,
          child: const Center(child: Text("Error: Asset dummy.jpg tidak ditemukan")),
        ),
      );
    } else if (laporan.imageFile != null) {
      imageWidget = Image.file(
        laporan.imageFile!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else {
      imageWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(child: Text("Tidak ada gambar")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Detail Laporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area Foto dengan overlay "UBAH FOTO"
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageWidget,
                ),
                // Overlay "UBAH FOTO" (hanya untuk tampilan, tidak fungsional)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        "UBAH FOTO",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Header dengan ID dan Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Detail Laporan",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${laporan.id.substring(0, 10)}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "PROSES",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Detail Data
            _buildDetailRow("Kota", laporan.kota),
            _buildDetailRow("Kategori", laporan.kategori),
            _buildDetailRow("Lokasi", laporan.lokasi),
            _buildDetailRow("Waktu Pelanggaran", laporan.waktuPelanggaran),
            _buildDetailRow("Ciri-ciri Pelaku", laporan.ciriCiri),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BAGIAN 2: LAYAR UTAMA PEMILIH FOTO (PelaporanScreen)
// ====================================================================

class PelaporanScreen extends StatefulWidget {
  const PelaporanScreen({super.key});

  @override
  State<PelaporanScreen> createState() => _PelaporanScreenState();
}

class _PelaporanScreenState extends State<PelaporanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImageFile; 
  bool _isDummyImage = false; 
  
  // State untuk menyimpan daftar laporan yang sudah dikirim
  final List<Laporan> _submittedReports = []; 

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  /// 🔹 Fungsi navigasi ke halaman Buat Laporan
  void _goToBuatLaporan() {
    // Memastikan ada gambar sebelum navigasi
    if (_selectedImageFile != null || _isDummyImage) {
      // ⭐️ Menangkap hasil pengiriman laporan dari BuatLaporanScreen
      Navigator.of(context).push(
        MaterialPageRoute<Laporan>( // Tentukan tipe kembalian adalah Laporan
          builder: (ctx) => BuatLaporanScreen(
            imageFile: _selectedImageFile,
            isAsset: _isDummyImage,
          ),
        ),
      ).then((newReport) {
        // Membersihkan gambar di layar ini
        _removeImage();
        
        // Memeriksa dan menyimpan laporan baru
        if (newReport != null) {
          setState(() {
            _submittedReports.insert(0, newReport); // Tambahkan di awal daftar
          });
          // SnackBar sudah ditangani di DetailLaporanScreen
        }
      });
    } else {
       // Tampilkan opsi jika belum ada gambar yang dipilih
       _showPickerOptions(context); 
    }
  }

  /// 🔹 Fungsi ambil gambar dengan fallback ke dummy image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path); 
          _isDummyImage = false;
        });
      } else {
        // Jika tidak ada gambar dipilih -> pakai dummy asset
        setState(() {
          _isDummyImage = true;
          _selectedImageFile = null; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada gambar, menggunakan dummy image.")),
        );
      }
    } catch (e) {
      // Jika error -> fallback ke dummy asset
      setState(() {
        _isDummyImage = true;
        _selectedImageFile = null; 
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error mengambil gambar, menggunakan dummy image.")),
      );
    }
    // Langsung pindah ke form jika gambar sudah berhasil dipilih/diganti dengan dummy
    if (_selectedImageFile != null || _isDummyImage) {
      _goToBuatLaporan();
    }
  }

  /// 🔹 Reset gambar
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _isDummyImage = false;
    });
  }

  /// 🔹 Popup pilih file
  void _showPickerOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Pilih File",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _OptionButton(
              icon: Icons.photo,
              label: "Gallery",
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            _OptionButton(
              icon: Icons.camera_alt,
              label: "Camera",
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "BATAL",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Widget untuk menampilkan gambar (File atau Asset)
  Widget _imageDisplayWidget() {
    // 1. Jika ada gambar dari perangkat
    if (_selectedImageFile != null) {
      return Image.file(
        _selectedImageFile!,
        width: 280,
        height: 280,
        fit: BoxFit.cover,
      );
    // 2. Jika harus menampilkan dummy asset
    } else if (_isDummyImage) {
      return Image.asset(
        "assets/images/dummy.jpg", 
        width: 280,
        height: 280,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 280,
          height: 280,
          color: Colors.grey.shade300,
          child: const Center(child: Text("Error: Asset dummy.jpg tidak ditemukan")),
        ),
      );
    // 3. Jika tidak ada gambar (Empty State/List)
    } else {
      // ⭐️ Tampilkan daftar laporan jika ada
      if (_submittedReports.isNotEmpty) {
        return _ReportList(reports: _submittedReports);
      }
      
      return _PelaporanEmptyState(
        text: "Ketuk '+' untuk memilih foto dan mulai melapor.",
        color: primaryColor,
      );
    }
  }
  
  // 🔹 Widget untuk tombol FAB yang berubah (Plus atau Centang)
  Widget _buildFloatingActionButton() {
    final bool hasImage = _selectedImageFile != null || _isDummyImage;

    return FloatingActionButton(
      backgroundColor: primaryColor,
      // Jika sudah ada gambar, FAB digunakan untuk menavigasi ke form
      // Jika belum ada gambar, FAB digunakan untuk memanggil opsi pilih gambar
      onPressed: hasImage ? _goToBuatLaporan : () => _showPickerOptions(context), 
      child: Icon(
        hasImage ? Icons.check : Icons.add, // Centang jika ada gambar
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan apakah harus menampilkan Gambar Preview atau Empty State/List
    final bool showImagePreview = _selectedImageFile != null || _isDummyImage;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      // Gunakan Stack/Center hanya jika menampilkan Preview Gambar, 
      // jika menampilkan List, gunakan Column/Expanded
      body: showImagePreview
          ? Center(
              child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Gambar Preview
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _imageDisplayWidget(),
                      ),
                    ),
                    // Tombol Hapus Gambar (X)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red.shade600,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white),
                          padding: EdgeInsets.zero,
                          onPressed: _removeImage,
                        ),
                      ),
                    ),
                  ],
                ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _imageDisplayWidget(),
              ),
            ), // Tampilkan Empty State/List dengan Center
      
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

// ====================================================================
// BAGIAN 3: WIDGET REUSABLE
// ====================================================================

// Widget untuk menampilkan daftar laporan yang sudah dikirim
class _ReportList extends StatelessWidget {
  final List<Laporan> reports;

  const _ReportList({required this.reports});

  @override
  Widget build(BuildContext context) {
    // ⭐️ Menggunakan Column dan Expanded agar ListView bisa memenuhi sisa ruang
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Laporan Terakhir (${reports.length})",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _PelaporanScreenState.primaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0), // Berikan padding di bawah agar FAB tidak menutupi list terakhir
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(
                    report.shortDescription,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    "Dikirim: ${DateFormat('dd MMM yyyy HH:mm').format(report.createdAt)}",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigasi ke detail laporan yang sudah terkirim
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => DetailLaporanTerkirimScreen(
                          laporan: report,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


/// 🔹 Reusable tombol pilihan (Untuk Popup Gallery/Camera)
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            child: Icon(icon, size: 28, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// 🔹 Widget reusable untuk empty state (Sesuai Gambar 1)
class _PelaporanEmptyState extends StatelessWidget {
  final String text;
  final Color color;

  const _PelaporanEmptyState({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info, size: 40, color: color),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 16, 
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

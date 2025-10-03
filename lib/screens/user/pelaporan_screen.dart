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
  final TextEditingController _ciriCiriController = TextEditingController();
  
  // State untuk menyimpan tanggal yang dipilih (opsional, untuk logika)
  DateTime? _selectedDate; 
  
  // Pilihan Data Dropdown
  static const List<String> _cities = [
    'Jakarta', 'Bogor', 'Depok', 'Tangerang', 'Bekasi',
    'Bandung', 'Surabaya', 'Medan', 'Semarang', 'Yogyakarta',
  ];

  static const List<String> _categories = [
    'Sampah Liar', 'Fasilitas Rusak', 'Tempat Sampah Penuh',
    'Pengambilan sampah tidak sesuai SOP', 'Warga buang sampah sembarangan',
    'Warga merusak fasilitas', 'Petugas tidak ramah', 'Lainnya',
  ];

  // State untuk menyimpan nilai yang dipilih
  String? _selectedCity;
  String? _selectedCategory;
  
  // Kunci form untuk validasi
  final _formKey = GlobalKey<FormState>();

  // Warna Utama (digunakan untuk tombol dan ikon, dll.)
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void dispose() {
    _lokasiController.dispose();
    _waktuController.dispose();
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

  // Fungsi Navigasi ke DetailLaporanScreen
  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Pastikan semua dropdown terisi
      if (_selectedCity == null || _selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Mohon lengkapi semua field yang wajib diisi.", style: GoogleFonts.poppins()),
          ),
        );
        return;
      }

      // Ambil semua data dari state dan controller
      final reportData = {
        'kota': _selectedCity!,
        'kategori': _selectedCategory!,
        'lokasi': _lokasiController.text,
        'waktu_pelanggaran': _waktuController.text, 
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
        height: 200,
        width: double.infinity,
      );
    } else {
      // Kasus fallback
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Area Foto dengan Tombol Ubah Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    imageWidget,
                    // Tombol Ubah Foto
                    InkWell(
                      onTap: () {
                          // Kembali ke PelaporanScreen untuk memilih foto baru
                          Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.black54,
                        child: Text(
                          "UBAH FOTO",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- FORM FIELDS ---

              // Dropdown KOTA
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  labelText: "Kota", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                items: _buildDropdownItems(_cities),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
                hint: const Text('Pilih Kota'),
                validator: (value) => value == null ? 'Kota wajib dipilih.' : null,
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
                  labelText: "Waktu Pelanggaran", 
                  hintText: _selectedDate == null ? 'Pilih Tanggal' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: const Icon(Icons.calendar_today, color: primaryColor), // Ikon kalender
                ),
                validator: (value) => value!.isEmpty ? 'Waktu Pelanggaran wajib diisi.' : null,
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
          : _imageDisplayWidget(), // Tampilkan Empty State/List
      
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
                    // TODO: Navigasi ke detail laporan yang sudah terkirim
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Melihat detail Laporan ID: ${report.id}")),
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
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

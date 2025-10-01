import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; 

// Fungsi utama untuk menjalankan aplikasi
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Pelaporan',
      // Pastikan delegasi lokal dimuat
      localizationsDelegates: const [
        // Delegate standar
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('id', 'ID'), 
      ],
      locale: const Locale('id', 'ID'), 
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const PelaporanScreen(), 
    );
  }
}

// ====================================================================
// BAGIAN 0: MODEL DATA DAN KONSTANTA
// ====================================================================

const Color primaryColor = Color.fromARGB(255, 21, 145, 137);
const Color statusColor = Color.fromARGB(255, 68, 180, 219); 

class Laporan {
  final String id;
  final String kota;
  final String kategori;
  final String lokasi;
  final String waktuPelanggaran; // Sekarang mencakup tanggal dan jam
  final String ciriCiri;
  final File? imageFile;
  final bool isAsset;
  final DateTime createdAt; 
  final String nomorLaporan; 

  Laporan({
    required this.kota,
    required this.kategori,
    required this.lokasi,
    required this.waktuPelanggaran,
    required this.ciriCiri,
    this.imageFile,
    required this.isAsset,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = DateTime.now(),
       nomorLaporan = 'D${DateFormat('yyMMddHHmmss').format(DateTime.now())}'; 

  String get shortDescription => "$kategori di $lokasi";
}

// ====================================================================
// BAGIAN 1: SCREEN FORM PENGISIAN LAPORAN (BuatLaporanScreen)
// ====================================================================

class BuatLaporanScreen extends StatefulWidget {
  final File? imageFile;
  final bool isAsset;

  // Constructor dengan Key eksplisit
  const BuatLaporanScreen({
    required this.imageFile,
    required this.isAsset,
    Key? key,
  }) : super(key: key);

  @override
  State<BuatLaporanScreen> createState() => _BuatLaporanScreenState();
}

class _BuatLaporanScreenState extends State<BuatLaporanScreen> {
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _waktuController = TextEditingController();
  final TextEditingController _ciriCiriController = TextEditingController();
  
  DateTime? _selectedDate; 
  
  static const List<String> _cities = [
    'Jakarta', 'Bogor', 'Depok', 'Tangerang', 'Bekasi',
    'Bandung', 'Surabaya', 'Medan', 'Semarang', 'Yogyakarta',
  ];

  static const List<String> _categories = [
    'Sampah Liar', 'Fasilitas Rusak', 'Tempat Sampah Penuh',
    'Pengambilan sampah tidak sesuai SOP', 'Warga buang sampah sembarangan',
    'Warga merusak fasilitas', 'Petugas tidak ramah', 'Lainnya',
  ];

  String? _selectedCity;
  String? _selectedCategory;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _lokasiController.dispose();
    _waktuController.dispose();
    _ciriCiriController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(List<String> options) {
    return options.map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }

  // >>> FUNGSI _selectDate DIUBAH UNTUK MENAMBAHKAN TIME PICKER KEMBALI <<<
  Future<void> _selectDate(BuildContext context) async {
    // 1. Pilih Tanggal (Date Picker)
    final DateTime? datePicked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Pelanggaran',
      cancelText: 'BATAL',
      confirmText: 'LANJUT',
    );
    
    // Jika tanggal dipilih, lanjutkan ke Time Picker
    if (datePicked != null) {
      // 2. Pilih Jam (Time Picker)
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
        helpText: 'Pilih Jam Pelanggaran',
        cancelText: 'BATAL',
        confirmText: 'PILIH',
      );

      // Jika jam dipilih
      if (timePicked != null) {
        // 3. Gabungkan Tanggal dan Jam
        final finalDateTime = DateTime(
          datePicked.year,
          datePicked.month,
          datePicked.day,
          timePicked.hour,
          timePicked.minute,
        );
        
        // 4. Update State dan Controller
        setState(() {
          _selectedDate = finalDateTime;
          // Format diubah untuk menyertakan hari dan jam (cth: Senin, 01 Jan 2024 - 15:30)
          _waktuController.text = DateFormat('EEEE, dd MMM yyyy - HH:mm', 'id_ID').format(finalDateTime); 
        });
      }
    }
  }
  
  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCity == null || _selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Mohon lengkapi semua field yang wajib diisi."),
          ),
        );
        return;
      }

      final reportData = {
        'kota': _selectedCity!,
        'kategori': _selectedCategory!,
        'lokasi': _lokasiController.text,
        // Waktu pelanggaran kini mencakup Tanggal dan Jam
        'waktu_pelanggaran': _waktuController.text, 
        'ciri_ciri': _ciriCiriController.text,
      };

      Navigator.of(context).push(
        MaterialPageRoute<Laporan>(
          builder: (ctx) => DetailLaporanScreen(
            reportData: reportData,
            imageFile: widget.imageFile,
            isAsset: widget.isAsset,
          ),
        ),
      ).then((newReport) {
        if (newReport is Laporan) {
          Navigator.of(context).pop(newReport);
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (widget.isAsset) {
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
      imageWidget = Image.file(
        widget.imageFile!,
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
        title: const Text("Pelaporan", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    imageWidget,
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.black54,
                        child: const Text(
                          "UBAH FOTO",
                          textAlign: TextAlign.center,
                          style: TextStyle(
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

              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  labelText: "Kota", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                items: _buildDropdownItems(_cities),
                onChanged: (value) => setState(() => _selectedCity = value),
                hint: const Text('Pilih Kota'),
                validator: (value) => value == null ? 'Kota wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Kategori", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                items: _buildDropdownItems(_categories),
                onChanged: (value) => setState(() => _selectedCategory = value),
                hint: const Text('Pilih Kategori'),
                validator: (value) => value == null ? 'Kategori wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lokasiController,
                decoration: InputDecoration(
                  labelText: "Lokasi", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                validator: (value) => value!.isEmpty ? 'Lokasi wajib diisi.' : null,
              ),
              const SizedBox(height: 16),

              // Bagian Waktu Pelanggaran (Tanggal dan Jam)
              TextFormField(
                controller: _waktuController,
                readOnly: true, 
                onTap: () => _selectDate(context), 
                decoration: InputDecoration(
                  labelText: "Waktu Pelanggaran", // Label diubah kembali
                  hintText: _selectedDate == null ? 'Pilih Tanggal dan Jam' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: const Icon(Icons.calendar_today, color: primaryColor), 
                ),
                validator: (value) => value!.isEmpty ? 'Waktu Pelanggaran wajib diisi.' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ciriCiriController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Ciri-ciri Pelaku", 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                validator: (value) => value!.isEmpty ? 'Ciri-ciri wajib diisi.' : null,
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "BUAT LAPORAN",
                    style: TextStyle(
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
// BAGIAN 1.5: SCREEN DETAIL LAPORAN (Sesaat sebelum konfirmasi)
// ====================================================================

class DetailLaporanScreen extends StatelessWidget {
  final Map<String, String> reportData;
  final File? imageFile;
  final bool isAsset;

  // Constructor dengan Key eksplisit
  const DetailLaporanScreen({
    required this.reportData,
    required this.imageFile,
    required this.isAsset,
    Key? key,
  }) : super(key: key);
  
  void _confirmReport(BuildContext context) {
    final newReport = Laporan(
      kota: reportData['kota']!,
      kategori: reportData['kategori']!,
      lokasi: reportData['lokasi']!,
      waktuPelanggaran: reportData['waktu_pelanggaran']!, // Data sudah berisi jam
      ciriCiri: reportData['ciri_ciri']!,
      imageFile: imageFile,
      isAsset: isAsset,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
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
              const Text(
                "Pelaporan Selesai",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Proses pelaporan telah selesai, pelaporan anda akan segera kami proses",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); 
                      Navigator.of(context).pop(newReport); 
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: primaryColor,
                          content: Text("Laporan berhasil dikirim!"),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
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
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
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
        title: const Text("Pelaporan", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
            const SizedBox(height: 24),

            const Text(
              "Detail Laporan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Label diubah kembali ke "Waktu Pelanggaran"
            _buildDetailRow("Kota", reportData['kota'] ?? '-'),
            _buildDetailRow("Kategori", reportData['kategori'] ?? '-'),
            _buildDetailRow("Lokasi", reportData['lokasi'] ?? '-'),
            _buildDetailRow("Waktu Pelanggaran", reportData['waktu_pelanggaran'] ?? '-'), 
            _buildDetailRow("Ciri-ciri Pelaku", reportData['ciri_ciri'] ?? '-'),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmReport(context), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  "KONFIRMASI",
                  style: TextStyle(
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
  
  final List<Laporan> _submittedReports = []; 

  void _goToBuatLaporan() {
    if (_selectedImageFile != null || _isDummyImage) {
      Navigator.of(context).push(
        MaterialPageRoute<Laporan>(
          builder: (ctx) => BuatLaporanScreen(
            imageFile: _selectedImageFile,
            isAsset: _isDummyImage,
          ),
        ),
      ).then((newReport) {
        _removeImage(); 
        
        if (newReport != null) {
          setState(() {
            _submittedReports.insert(0, newReport); 
          });
        }
      });
    } else {
       _showPickerOptions(context); 
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path); 
          _isDummyImage = false;
        });
      } else {
        setState(() {
          _isDummyImage = true;
          _selectedImageFile = null; 
        });
      }
    } catch (e) {
      setState(() {
        _isDummyImage = true;
        _selectedImageFile = null; 
      });
    }
    
    if (_selectedImageFile != null || _isDummyImage) {
      _goToBuatLaporan();
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _isDummyImage = false;
    });
  }

  void _showPickerOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Pilih File",
          style: TextStyle(fontWeight: FontWeight.w600),
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
            child: const Text(
              "BATAL",
              style: TextStyle(
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

  Widget _imageDisplayWidget() {
    if (_selectedImageFile != null || _isDummyImage) {
      return _selectedImageFile != null ? 
        Image.file(
          _selectedImageFile!,
          width: 280,
          height: 280,
          fit: BoxFit.cover,
        )
      : Image.asset(
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
    } else {
      if (_submittedReports.isNotEmpty) {
        return _ReportList(reports: _submittedReports);
      }
      
      return const _PelaporanEmptyState(
        text: "Ketuk '+' untuk memilih foto dan mulai melapor.",
        color: primaryColor,
      );
    }
  }
  
  Widget _buildFloatingActionButton() {
    final bool hasImage = _selectedImageFile != null || _isDummyImage;

    return FloatingActionButton(
      backgroundColor: primaryColor,
      onPressed: hasImage ? _goToBuatLaporan : () => _showPickerOptions(context), 
      child: Icon(
        hasImage ? Icons.check : Icons.add,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showImagePreview = _selectedImageFile != null || _isDummyImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pelaporan", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: showImagePreview
          ? Center(
              child: Stack(
                  alignment: Alignment.center,
                  children: [
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
          : _imageDisplayWidget(), 
      
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

// ====================================================================
// BAGIAN 3: WIDGET REUSABLE
// ====================================================================

class _ReportList extends StatelessWidget {
  final List<Laporan> reports;

  // Constructor dengan Key eksplisit
  const _ReportList({
    required this.reports, 
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Laporan Terakhir",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0), 
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: primaryColor),
                  title: Text(
                    report.shortDescription,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    "Dikirim: ${DateFormat('dd MMM yyyy').format(report.createdAt)}", 
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => SubmittedReportDetailScreen(report: report),
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


class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  // Constructor dengan Key eksplisit
  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PelaporanEmptyState extends StatelessWidget {
  final String text;
  final Color color;

  // Constructor dengan Key eksplisit
  const _PelaporanEmptyState({
    required this.text, 
    required this.color, 
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// BAGIAN 4: SCREEN DETAIL LAPORAN YANG SUDAH TERSIMPAN (Sesuai Gambar 2)
// ====================================================================

class SubmittedReportDetailScreen extends StatelessWidget {
  final Laporan report;

  // Constructor dengan Key eksplisit
  const SubmittedReportDetailScreen({
    required this.report, 
    Key? key,
  }) : super(key: key);

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildIdRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (report.isAsset) {
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
    } else if (report.imageFile != null) {
      imageWidget = Image.file(
        report.imageFile!,
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
        title: const Text("Detail Laporan", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Detail Laporan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: const Text(
                    "PROSES",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildIdRow("Nomor Laporan", report.nomorLaporan),
            _buildDetailRow("Kota", report.kota),
            _buildDetailRow("Kategori", report.kategori),
            _buildDetailRow("Lokasi", report.lokasi),
            _buildDetailRow("Waktu Pelanggaran", report.waktuPelanggaran), // Label sudah benar
            _buildDetailRow("Ciri-ciri Pelaku", report.ciriCiri),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

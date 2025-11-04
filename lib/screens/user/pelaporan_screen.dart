import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/notification_helper.dart';
import '../../services/complaint_service.dart';
import '../../services/service_account_service.dart';
import '../../models/complaint.dart';
import '../../models/service_account.dart';
import '../../config/api_config.dart';
import '../../utils/file.dart' as custom_file;
import '../../utils/file.dart'; // Import untuk createFileFromBytes
import '../../utils/image_builder.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.teal,
        // Mengatur tema warna primer
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal),
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
  final String? serviceAccount; // Service account yang dilaporkan
  final custom_file.File? imageFile;
  final String? photoUrl; // URL foto dari API
  final bool isAsset;
  final DateTime createdAt;
  final String
  status; // Status dari database: 'open', 'in_progress', 'resolved', 'rejected'

  Laporan({
    required this.kota,
    required this.kategori,
    required this.lokasi,
    required this.waktuPelanggaran,
    required this.ciriCiri,
    this.serviceAccount,
    this.imageFile,
    this.photoUrl,
    required this.isAsset,
    this.status = 'open', // Default status
  }) : id = DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = DateTime.now();

  // Get status display text in Indonesian
  String get statusText {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  // Helper untuk mendapatkan deskripsi singkat
  String get shortDescription => "$kategori di $lokasi";

  // Convert to JSON (untuk penyimpanan)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kota': kota,
      'kategori': kategori,
      'lokasi': lokasi,
      'waktuPelanggaran': waktuPelanggaran,
      'ciriCiri': ciriCiri,
      'serviceAccount': serviceAccount,
      'imagePath': imageFile?.path,
      'photoUrl': photoUrl,
      'isAsset': isAsset,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON (untuk load data)
  factory Laporan.fromJson(Map<String, dynamic> json) {
    return Laporan(
      kota: json['kota'] as String,
      kategori: json['kategori'] as String,
      lokasi: json['lokasi'] as String,
      waktuPelanggaran: json['waktuPelanggaran'] as String,
      ciriCiri: json['ciriCiri'] as String,
      serviceAccount: json['serviceAccount'] as String?,
      imageFile: json['imagePath'] != null
          ? custom_file.File(json['imagePath'] as String)
          : null,
      photoUrl: json['photoUrl'] as String?,
      isAsset: json['isAsset'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
    );
  }
}

// ====================================================================
// BAGIAN 1: SCREEN FORM PENGISIAN LAPORAN (BuatLaporanScreen)
// ====================================================================

class BuatLaporanScreen extends StatefulWidget {
  final custom_file.File? imageFile;
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
  // Controller untuk mengelola input text
  final TextEditingController _deskripsiController = TextEditingController();

  // Pilihan Kategori sesuai API Documentation
  static const List<Map<String, String>> _types = [
    {'value': 'sampah_tidak_diangkut', 'label': 'Sampah Tidak Diangkut'},
    {'value': 'sampah_menumpuk', 'label': 'Sampah Menumpuk'},
    {'value': 'jadwal_tidak_sesuai', 'label': 'Jadwal Tidak Sesuai'},
    {'value': 'pelayanan_buruk', 'label': 'Pelayanan Buruk'},
    {'value': 'petugas_tidak_datang', 'label': 'Petugas Tidak Datang'},
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];

  // State untuk menyimpan tipe yang dipilih
  String? _selectedType;

  // State untuk service account
  List<ServiceAccount> _serviceAccounts = [];
  String? _selectedServiceAccountId;
  bool _isLoadingServiceAccounts = false;

  // Kunci form untuk validasi
  final _formKey = GlobalKey<FormState>();

  // Warna Utama
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _loadServiceAccounts();
  }

  @override
  void dispose() {
    _deskripsiController.dispose();
    super.dispose();
  }

  // Fungsi untuk memuat service accounts dari API
  Future<void> _loadServiceAccounts() async {
    setState(() {
      _isLoadingServiceAccounts = true;
    });

    try {
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();

      setState(() {
        _serviceAccounts = accounts;
        _isLoadingServiceAccounts = false;
      });

      print('✅ Loaded ${accounts.length} service accounts');
    } catch (e) {
      setState(() {
        _isLoadingServiceAccounts = false;
      });

      print('❌ Error loading service accounts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'Gagal memuat service account: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  // Fungsi Navigasi ke DetailLaporanScreen
  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Pastikan dropdown terisi
      if (_selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Mohon pilih kategori laporan.",
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        return;
      }

      // Debug print
      print('🔍 _selectedType: $_selectedType');
      print('🔍 _deskripsiController.text: ${_deskripsiController.text}');
      print('🔍 _selectedServiceAccountId: $_selectedServiceAccountId');

      // Ambil data dari state dan controller
      final reportData = <String, String>{
        'type': _selectedType ?? '', // API field: type - dengan fallback
        'deskripsi': _deskripsiController.text.isNotEmpty
            ? _deskripsiController.text
            : 'Tidak ada deskripsi', // API field: description - dengan fallback
      };

      // Tambahkan service account hanya jika dipilih
      if (_selectedServiceAccountId != null &&
          _selectedServiceAccountId!.isNotEmpty) {
        reportData['serviceAccount'] = _selectedServiceAccountId!;
      }

      print('🔍 reportData: $reportData');

      // Gunakan foto yang dipilih user, fallback ke foto dari parent
      final finalImage = _selectedImage ?? widget.imageFile;

      // Navigasi ke DetailLaporanScreen
      Navigator.of(context)
          .push(
            MaterialPageRoute<Laporan>(
              builder: (ctx) => DetailLaporanScreen(
                reportData: reportData,
                imageFile: finalImage,
                isAsset: widget.isAsset,
              ),
            ),
          )
          .then((newReport) {
            // Jika DetailLaporanScreen me-return objek Laporan
            if (newReport is Laporan) {
              // Kirim objek Laporan kembali ke PelaporanScreen
              Navigator.of(context).pop(newReport);
            }
          });
    }
  }

  // Fungsi untuk memilih foto (galeri/kamera)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final customFile = createFileFromBytes(pickedFile.path, bytes);

        setState(() {
          _selectedImage = customFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Gagal mengambil gambar: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  // Fungsi untuk menampilkan dialog pilihan foto
  void _showPickerOptions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pilih Foto',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionButton(
              icon: Icons.photo_library,
              label: 'Pilih dari Galeri',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            _OptionButton(
              icon: Icons.camera_alt,
              label: 'Ambil Foto',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  custom_file.File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;

    // Gunakan foto yang baru dipilih, atau foto yang dibawa dari parent
    final imageToShow = _selectedImage ?? widget.imageFile;

    if (imageToShow != null) {
      // Menggunakan buildPlatformImage untuk cross-platform compatibility
      imageWidget = buildPlatformImage(
        imageToShow,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
      );
    } else {
      // Placeholder untuk upload foto (menggunakan image dari assets)
      imageWidget = GestureDetector(
        onTap: _showPickerOptions,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/camera-plus.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback jika gambar tidak ditemukan
                return Icon(
                  Icons.add_a_photo,
                  size: 80,
                  color: Colors.grey.shade400,
                );
              },
            ),
          ),
        ),
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
                          onTap: _showPickerOptions,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: const BoxDecoration(
                              color: Color(
                                0xFF3D3D3D,
                              ), // Warna dark gray solid seperti di Figma
                              borderRadius: BorderRadius.only(
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
                                letterSpacing: 0.5,
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

              // --- FORM FIELDS YANG DIPERLUKAN API ---

              // Dropdown KATEGORI/TYPE
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: "Kategori",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(
                      type['label']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
                hint: const Text('Pilih Kategori'),
                validator: (value) =>
                    value == null ? 'Kategori wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              // Service Account Dropdown (Opsional)
              DropdownButtonFormField<String>(
                value: _selectedServiceAccountId,
                decoration: InputDecoration(
                  labelText: "Service Account (Opsional)",
                  prefixIcon: const Icon(Icons.account_circle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: "Kosongkan jika tidak tahu ID service account",
                  helperMaxLines: 2,
                ),
                items: [
                  // Option untuk tidak memilih service account
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tidak ada'),
                  ),
                  // Service accounts dari API
                  ..._serviceAccounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: _isLoadingServiceAccounts
                    ? null
                    : (value) {
                        setState(() {
                          _selectedServiceAccountId = value;
                        });
                      },
                hint: _isLoadingServiceAccounts
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Memuat data...'),
                        ],
                      )
                    : const Text('Pilih Service Account'),
                // Tidak ada validator - field ini opsional
              ),
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                maxLines: 5,
                maxLength: 1000, // Sesuai validasi API
                decoration: InputDecoration(
                  labelText: "Deskripsi",
                  hintText: "Jelaskan detail keluhan Anda...",
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) => value!.isEmpty
                    ? 'Ciri-ciri wajib diisi.'
                    : null, // Tambahkan validasi
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
  final custom_file.File? imageFile;
  final bool isAsset;

  const DetailLaporanScreen({
    super.key,
    required this.reportData,
    required this.imageFile,
    required this.isAsset,
  });

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Type mapping untuk mendapatkan label dari value
  static const List<Map<String, String>> _types = [
    {'value': 'sampah_tidak_diangkut', 'label': 'Sampah Tidak Diangkut'},
    {'value': 'sampah_menumpuk', 'label': 'Sampah Menumpuk'},
    {'value': 'jadwal_tidak_sesuai', 'label': 'Jadwal Tidak Sesuai'},
    {'value': 'pelayanan_buruk', 'label': 'Pelayanan Buruk'},
    {'value': 'petugas_tidak_datang', 'label': 'Petugas Tidak Datang'},
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];

  // Fungsi: Menampilkan modal konfirmasi dan mengirim laporan ke API
  void _confirmReport(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Mengirim laporan...",
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        );
      },
    );

    try {
      // 🔹 Kirim ke API menggunakan ComplaintService
      print('📤 Sending complaint to API...');
      print('  Type: ${reportData['type']}');
      print('  Description: ${reportData['deskripsi']}');
      print('  Service Account: ${reportData['serviceAccount']}');
      print('  Has Image: ${imageFile != null}');

      final (success, message, data) = await ComplaintService.createComplaint(
        type: reportData['type']!, // Langsung dari dropdown value
        description: reportData['deskripsi']!,
        serviceAccountId:
            reportData['serviceAccount'], // Kirim service account ke API
        image: imageFile,
      );

      print('📥 API Response - Success: $success, Message: $message');

      // Tutup loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (success && data != null) {
        // 1. Parse response menjadi Complaint object (optional - tidak critical untuk flow)
        print('✅ API Success! Data: $data');
        Complaint? complaint;
        try {
          complaint = Complaint.fromJson(data);
          print('✅ Complaint parsed: ${complaint.id}');
        } catch (e) {
          print('⚠️ Warning: Could not parse Complaint: $e');
          // Continue anyway, complaint parsing tidak critical
        }

        // 2. Buat objek Laporan untuk kompatibilitas UI (temporary mapping)
        // Note: Laporan model masih menggunakan struktur lama untuk backward compatibility
        print('📋 reportData: $reportData');

        final String typeValue = reportData['type'] ?? 'lainnya';
        print('📋 typeValue from reportData: $typeValue');

        final typeLabel =
            _types.firstWhere(
              (t) => t['value'] == typeValue,
              orElse: () => {'value': typeValue, 'label': 'Lainnya'},
            )['label'] ??
            'Lainnya';
        print('✅ typeLabel: $typeLabel');

        final newReport = Laporan(
          kota: 'Jakarta', // Default
          kategori: typeLabel, // Gunakan label untuk display
          lokasi: '', // Tidak ada lagi
          waktuPelanggaran: DateFormat(
            'dd MMMM yyyy HH:mm',
          ).format(DateTime.now()),
          ciriCiri:
              reportData['deskripsi'] ??
              'Tidak ada deskripsi', // Fallback jika null
          serviceAccount: reportData['serviceAccount'], // Ambil dari form
          imageFile: imageFile,
          isAsset: isAsset,
        );
        print('✅ newReport created: ${newReport.id}');

        // 3. Trigger notifikasi pelaporan berhasil dibuat (optional - jangan block flow)
        try {
          final helper = NotificationHelper();
          await helper.notifyReportCreated(
            category: typeLabel,
            location: 'Jakarta',
          );
        } catch (e) {
          print('⚠️ Notifikasi gagal: $e');
          // Ignore notification error, don't block the flow
        }

        // 4. Tampilkan Dialog "Pelaporan Selesai"
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    const SizedBox(height: 8),
                    // ID Complaint (jika ada)
                    if (complaint != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          "ID: ${complaint.id}",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
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

                            // 2. Pop dari DetailLaporanScreen dan kirim objek Laporan
                            Navigator.of(context).pop(newReport);

                            // Pesan sukses:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: primaryColor,
                                content: Text(
                                  "Laporan berhasil dikirim!",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              68,
                              180,
                              219,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
      } else {
        // Gagal mengirim ke API
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(message, style: GoogleFonts.poppins()),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Tutup loading dialog jika masih ada
      if (context.mounted) Navigator.of(context).pop();

      // Tampilkan error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Terjadi kesalahan: $e',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Helper untuk mendapatkan label dari type value
  String _getTypeLabel(String typeValue) {
    final type = _types.firstWhere(
      (t) => t['value'] == typeValue,
      orElse: () => {'value': typeValue, 'label': typeValue},
    );
    return type['label'] ?? typeValue;
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
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;
    if (imageFile != null) {
      imageWidget = buildPlatformImage(
        imageFile!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else if (isAsset) {
      // Fallback jika ada flag isAsset (tidak digunakan lagi)
      imageWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text("Tidak ada gambar"),
            ],
          ),
        ),
      );
    } else {
      imageWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text("Tidak ada gambar"),
            ],
          ),
        ),
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

            // Detail Data - Hanya yang diperlukan API
            _buildDetailRow(
              "Kategori",
              reportData['type'] != null
                  ? _getTypeLabel(reportData['type']!)
                  : 'Tidak ada kategori',
            ),
            // Service Account - hanya tampilkan jika ada
            if (reportData['serviceAccount'] != null &&
                reportData['serviceAccount']!.isNotEmpty)
              _buildDetailRow("Service Account", reportData['serviceAccount']!),
            _buildDetailRow(
              "Deskripsi",
              reportData['deskripsi'] ?? 'Tidak ada deskripsi',
            ),

            const SizedBox(height: 32),

            // Tombol KONFIRMASI
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    _confirmReport(context), // Panggil fungsi konfirmasi
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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

  const DetailLaporanTerkirimScreen({super.key, required this.laporan});

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

  // Fungsi untuk mendapatkan warna badge berdasarkan status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange; // Menunggu
      case 'in_progress':
        return primaryColor; // Diproses
      case 'resolved':
        return Colors.green; // Selesai
      case 'rejected':
        return Colors.red; // Ditolak
      default:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;
    if (laporan.photoUrl != null) {
      // Prioritaskan foto dari URL (API)
      print('🖼️ Loading image from URL: ${laporan.photoUrl}');
      imageWidget = Image.network(
        laporan.photoUrl!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Image load error: $error');
          print('   URL: ${laporan.photoUrl}');
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    "Gagal memuat gambar",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      laporan.photoUrl ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Image loaded successfully');
            return child;
          }
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey.shade200,
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
    } else if (laporan.imageFile != null) {
      imageWidget = buildPlatformImage(
        laporan.imageFile!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else if (laporan.isAsset) {
      // Fallback jika ada flag isAsset
      imageWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text("Tidak ada gambar"),
            ],
          ),
        ),
      );
    } else {
      imageWidget = Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text("Tidak ada gambar"),
            ],
          ),
        ),
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
            // Area Foto (tanpa overlay)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(laporan.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    laporan.statusText.toUpperCase(),
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
            if (laporan.serviceAccount != null &&
                laporan.serviceAccount!.isNotEmpty)
              _buildDetailRow("Service Account", laporan.serviceAccount!),
            _buildDetailRow("Waktu Pelanggaran", laporan.waktuPelanggaran),
            _buildDetailRow("Deskripsi", laporan.ciriCiri),

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
  custom_file.File? _selectedImageFile;
  bool _isDummyImage = false;
  bool _isLoading = false; // Loading state untuk API call

  // State untuk menyimpan daftar laporan yang sudah dikirim
  final List<Laporan> _submittedReports = [];

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  /// 🔹 Load laporan dari API
  Future<void> _loadSavedReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil data dari API
      final (success, message, data) = await ComplaintService.getComplaints(
        limit: 100, // Ambil maksimal 100 laporan
      );

      if (success && data != null) {
        // Convert API response ke Laporan objects untuk kompatibilitas UI
        final List<Laporan> loadedReports = data.map((item) {
          final complaint = Complaint.fromJson(item);
          return _convertComplaintToLaporan(complaint);
        }).toList();

        setState(() {
          _submittedReports.clear();
          _submittedReports.addAll(loadedReports);
          _isLoading = false;
        });

        print('✅ Loaded ${loadedReports.length} reports from API');
      } else {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('❌ Error loading reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data laporan: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Helper untuk convert Complaint (API) ke Laporan (UI model)
  Laporan _convertComplaintToLaporan(Complaint complaint) {
    // Default values karena Complaint API tidak punya field ini lagi
    final kota = 'Jakarta'; // Default kota
    final waktuPelanggaran = DateFormat(
      'dd MMMM yyyy HH:mm',
    ).format(complaint.createdAt);

    // Ambil URL foto pertama jika ada
    String? photoUrl;
    if (complaint.photos.isNotEmpty) {
      photoUrl = complaint.photos.first.url;
      print('📷 Original Photo URL from API: $photoUrl');

      // Jika URL relatif (dimulai dengan /), tambahkan base URL
      if (photoUrl.isNotEmpty && photoUrl.startsWith('/')) {
        // Ambil base URL tanpa /api/v1
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
        photoUrl = '$baseUrlWithoutApi$photoUrl';
        print('📷 Full Photo URL: $photoUrl');
      } else if (photoUrl.isNotEmpty && !photoUrl.startsWith('http')) {
        // Jika relatif tanpa slash awal
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
        photoUrl = '$baseUrlWithoutApi/$photoUrl';
        print('📷 Full Photo URL: $photoUrl');
      }
    } else {
      print('📷 No photos available for this complaint');
    }

    return Laporan(
      kota: kota,
      kategori: complaint.typeText, // Gunakan getter typeText untuk display
      lokasi: '', // Tidak ada lagi di API
      waktuPelanggaran: waktuPelanggaran,
      ciriCiri: complaint.description,
      serviceAccount: complaint.serviceAccountId, // Service account dari API
      imageFile: null, // API returns URL, bukan File
      photoUrl: photoUrl, // Simpan URL foto
      isAsset: complaint.photos.isNotEmpty, // Ada foto dari API
      status: complaint.status, // Ambil status dari database
    );
  }

  /// 🔹 Fungsi navigasi ke halaman Buat Laporan
  void _goToBuatLaporan() {
    // Langsung navigasi ke BuatLaporanScreen (tidak perlu foto dulu)
    // User bisa upload foto di dalam form
    Navigator.of(context)
        .push(
          MaterialPageRoute<Laporan>(
            // Tentukan tipe kembalian adalah Laporan
            builder: (ctx) => BuatLaporanScreen(
              imageFile: _selectedImageFile, // bisa null
              isAsset: _isDummyImage,
            ),
          ),
        )
        .then((newReport) {
          // Membersihkan gambar di layar ini
          _removeImage();

          // Jika laporan berhasil dikirim, refresh list dari API
          if (newReport != null) {
            _loadSavedReports(); // Refresh data dari API
            // SnackBar sudah ditangani di DetailLaporanScreen
          }
        });
  }

  /// 🔹 Reset gambar
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _isDummyImage = false;
    });
  }

  /// 🔹 Widget untuk menampilkan gambar (File atau daftar laporan)
  Widget _imageDisplayWidget() {
    // 1. Jika ada gambar dari perangkat
    if (_selectedImageFile != null) {
      return buildPlatformImage(
        _selectedImageFile!,
        width: 280,
        height: 280,
        fit: BoxFit.cover,
      );
    } else {
      // 2. Tampilkan loading indicator saat memuat data
      if (_isLoading) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat laporan...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }

      // 3. Jika tidak ada gambar, tampilkan daftar laporan atau empty state
      if (_submittedReports.isNotEmpty) {
        return _ReportList(reports: _submittedReports);
      }

      return _PelaporanEmptyState(
        text: "Ketuk '+' untuk memilih foto dan mulai melapor.",
        color: primaryColor,
      );
    }
  }

  // 🔹 Widget untuk tombol FAB - selalu buka form
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      backgroundColor: primaryColor,
      // Langsung buka form BuatLaporanScreen (user upload foto di dalam form)
      onPressed: _goToBuatLaporan,
      child: const Icon(Icons.add), // Selalu icon plus
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pelaporan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      // Selalu tampilkan list laporan atau empty state (tidak ada preview gambar)
      body: RefreshIndicator(
        onRefresh: _loadSavedReports,
        color: primaryColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _imageDisplayWidget(),
          ),
        ),
      ),

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
            padding: const EdgeInsets.only(
              bottom: 80.0,
            ), // Berikan padding di bawah agar FAB tidak menutupi list terakhir
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(
                report: report,
                onTap: () {
                  // Navigasi ke detail laporan yang sudah terkirim
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) =>
                          DetailLaporanTerkirimScreen(laporan: report),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Widget Card untuk setiap laporan (sesuai desain Figma)
class _ReportCard extends StatelessWidget {
  final Laporan report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // Fungsi untuk mendapatkan warna badge berdasarkan status dari database
  Color _getBadgeColor() {
    switch (report.status.toLowerCase()) {
      case 'open':
        return Colors.orange.shade100; // Menunggu
      case 'in_progress':
        return primaryColor.withOpacity(0.2); // Diproses
      case 'resolved':
        return Colors.green.shade100; // Selesai
      case 'rejected':
        return Colors.red.shade100; // Ditolak
      default:
        return Colors.grey.shade100;
    }
  }

  // Fungsi untuk mendapatkan text color badge
  Color _getBadgeTextColor() {
    switch (report.status.toLowerCase()) {
      case 'open':
        return Colors.orange.shade700; // Menunggu
      case 'in_progress':
        return primaryColor; // Diproses
      case 'resolved':
        return Colors.green.shade700; // Selesai
      case 'rejected':
        return Colors.red.shade700; // Ditolak
      default:
        return Colors.grey.shade700;
    }
  }

  // Fungsi untuk mendapatkan status text dari database
  String _getStatusText() {
    return report.statusText;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: report.photoUrl != null
                      ? Image.network(
                          report.photoUrl!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey.shade400,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        )
                      : report.imageFile != null
                      ? buildPlatformImage(
                          report.imageFile!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        )
                      : Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getBadgeTextColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      report.kategori.isNotEmpty
                          ? report.kategori
                          : 'Sampah belum diambil',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Dikirim: ${DateFormat('dd MMM yyyy HH:mm').format(report.createdAt)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Lokasi jika ada
                    if (report.lokasi.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.lokasi,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow Icon
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: primaryColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        // Gambar tanpa container circle background
        Image.asset(
          'assets/images/pelaporan.png',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info, size: 60, color: color),
          ),
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

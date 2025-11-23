import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  final String? serviceAccount; // Service account ID yang dilaporkan
  final String? serviceAccountName; // Service account name untuk display
  final custom_file.File? imageFile;
  final String? photoUrl; // URL foto dari API (deprecated - use photoUrls)
  final List<String> photoUrls; // Multiple photo URLs dari API
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
    this.serviceAccountName,
    this.imageFile,
    this.photoUrl,
    this.photoUrls = const [], // Default empty list
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
      'serviceAccountName': serviceAccountName,
      'imagePath': imageFile?.path,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
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
      serviceAccountName: json['serviceAccountName'] as String?,
      imageFile: json['imagePath'] != null
          ? custom_file.File(json['imagePath'] as String)
          : null,
      photoUrl: json['photoUrl'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
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
  final String? initialType;
  final String? initialLocation;
  final String? initialServiceAccountId;
  final String? initialServiceAccountName;

  const BuatLaporanScreen({
    super.key,
    required this.imageFile,
    required this.isAsset,
    this.initialType,
    this.initialLocation,
    this.initialServiceAccountId,
    this.initialServiceAccountName,
  });

  @override
  State<BuatLaporanScreen> createState() => _BuatLaporanScreenState();
}

class _BuatLaporanScreenState extends State<BuatLaporanScreen> {
  // Controller untuk mengelola input text
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();

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
  String? _selectedServiceAccountId; // Tidak set default, biarkan null
  bool _isLoadingServiceAccounts = false;

  // State untuk map
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  bool _isLoadingLocation = false;

  // Kunci form untuk validasi
  final _formKey = GlobalKey<FormState>();

  // Warna Utama
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _loadServiceAccounts();
    // Tambahkan image dari parent jika ada
    if (widget.imageFile != null) {
      _selectedImages.add(widget.imageFile!);
    }
    // Set initial values jika ada
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
    }
    if (widget.initialLocation != null) {
      _lokasiController.text = widget.initialLocation!;
    }
    // Load service accounts terlebih dahulu
    _loadServiceAccounts().then((_) {
      // Set service account ID setelah data dimuat
      if (widget.initialServiceAccountId != null) {
        setState(() {
          _selectedServiceAccountId = widget.initialServiceAccountId;
        });
      }
    });
  }

  @override
  void dispose() {
    _deskripsiController.dispose();
    _lokasiController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen. Aktifkan di pengaturan.');
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        forceAndroidLocationManager: true,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Lokasi Saat Ini';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}';
      }

      setState(() {
        _selectedLocation = location;
        _lokasiController.text = address;
        _isLoadingLocation = false;
      });

      // Move camera to location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingLocation = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lokasi tidak tersedia. Silakan ketuk peta untuk memilih lokasi manual.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Fungsi untuk pick location dari map
  Future<void> _pickLocationFromMap(LatLng location) async {
    if (!mounted) return;
    
    try {
      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      String address = '${location.latitude}, ${location.longitude}';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '') // Remove leading/trailing commas
            .replaceAll(RegExp(r',\s*,'), ','); // Remove double commas
        if (address.isEmpty) {
          address = '${location.latitude}, ${location.longitude}';
        }
      }

      setState(() {
        _selectedLocation = location;
        _lokasiController.text = address;
      });
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _selectedLocation = location;
        _lokasiController.text = '${location.latitude}, ${location.longitude}';
      });
    }
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
        'lokasi': _lokasiController.text, // API field: location
      };

      // Tambahkan service account hanya jika dipilih
      if (_selectedServiceAccountId != null &&
          _selectedServiceAccountId!.isNotEmpty) {
        reportData['serviceAccount'] = _selectedServiceAccountId!;
      }

      print('🔍 reportData: $reportData');

      // Navigasi ke DetailLaporanScreen dengan list images
      Navigator.of(context)
          .push(
            MaterialPageRoute<Laporan>(
              builder: (ctx) => DetailLaporanScreen(
                reportData: reportData,
                imageFiles: _selectedImages,
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
          _selectedImages.add(customFile);
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

  final List<custom_file.File> _selectedImages = [];

  // Helper untuk cek apakah kategori butuh map
  bool _shouldShowMap() {
    return _selectedType == 'sampah_menumpuk' || _selectedType == 'lainnya';
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;

    // Gunakan foto yang sudah dipilih
    final hasImages = _selectedImages.isNotEmpty;

    if (hasImages) {
      // Tampilkan horizontal scroll untuk multiple images
      imageWidget = Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _selectedImages.length + 1, // +1 untuk tombol tambah
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              // Tombol untuk tambah foto
              return GestureDetector(
                onTap: _showPickerOptions,
                child: Container(
                  width: 160,
                  height: 200,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tambah Foto',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Tampilkan foto yang sudah dipilih
            return Container(
              width: 280,
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: buildPlatformImage(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                        width: 280,
                        height: 200,
                      ),
                    ),
                  ),
                  // Badge nomor foto
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}/${_selectedImages.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Tombol hapus foto
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // Placeholder untuk upload foto pertama
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

              // Info jumlah foto jika ada multiple images
              if (_selectedImages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedImages.length} foto siap diupload',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.check_circle, size: 18, color: primaryColor),
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

              // Map Picker untuk kategori Sampah Menumpuk dan Lainnya
              if (_shouldShowMap()) ...[ 
                Text(
                  'Pilih Lokasi di Peta',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        GoogleMap(
                          key: ValueKey('map_${_selectedType ?? ""}_${_selectedLocation?.latitude.toString() ?? "0"}'),
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation ?? const LatLng(-6.2088, 106.8456),
                            zoom: 15,
                          ),
                          mapType: MapType.normal,
                          liteModeEnabled: false,
                          onMapCreated: (controller) async {
                            if (!mounted) return;
                            _mapController = controller;
                            
                            // Set map style untuk memastikan rendering
                            try {
                              await controller.setMapStyle(null);
                            } catch (e) {
                              print('Map style error: $e');
                            }
                          },
                          onTap: (location) {
                            if (!mounted) return;
                            _pickLocationFromMap(location);
                          },
                          markers: _selectedLocation != null
                              ? {
                                  Marker(
                                    markerId: const MarkerId('selected'),
                                    position: _selectedLocation!,
                                    draggable: true,
                                    onDragEnd: (location) {
                                      if (!mounted) return;
                                      _pickLocationFromMap(location);
                                    },
                                  ),
                                }
                              : {},
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          mapToolbarEnabled: false,
                          compassEnabled: true,
                          rotateGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          trafficEnabled: false,
                          buildingsEnabled: true,
                          indoorViewEnabled: false,
                        ),
                        // Tombol Get Current Location
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            elevation: 2,
                            child: InkWell(
                              onTap: _isLoadingLocation ? null : _getCurrentLocation,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: _isLoadingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ketuk peta untuk memilih lokasi atau klik tombol lokasi untuk menggunakan GPS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Field Lokasi
              // Tampilkan info jika lokasi sudah dipilih otomatis
              if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lokasi sudah terisi otomatis dari data service account',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _lokasiController,
                decoration: InputDecoration(
                  labelText: "Lokasi",
                  hintText: "Masukkan alamat lokasi kejadian",
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: widget.initialLocation != null
                      ? "Anda dapat mengubah lokasi jika diperlukan"
                      : "Contoh: Jl. Sudirman No. 123, Jakarta",
                  helperMaxLines: 2,
                ),
                maxLength: 255,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lokasi wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Service Account Dropdown (Opsional)
              // Tampilkan info jika service account sudah dipilih otomatis
              if (widget.initialServiceAccountId != null && widget.initialServiceAccountId!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Service Account sudah dipilih otomatis dari data pengambilan sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              DropdownButtonFormField<String>(
                value: _selectedServiceAccountId,
                decoration: InputDecoration(
                  labelText: "Service Account (Opsional)",
                  prefixIcon: const Icon(Icons.account_circle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: widget.initialServiceAccountId != null 
                      ? "Anda dapat mengubah pilihan jika diperlukan"
                      : "Kosongkan jika tidak tahu ID service account",
                  helperMaxLines: 2,
                ),
                isExpanded: true, // ✅ PENTING: Agar dropdown full width
                items: _serviceAccounts.isEmpty
                    ? [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tidak ada service account tersedia'),
                        ),
                      ]
                    : [
                        // Option untuk tidak memilih service account
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Pilih Service Account --'),
                        ),
                        // Service accounts dari API
                        ..._serviceAccounts.map((account) {
                          return DropdownMenuItem<String>(
                            value: account.id,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_city,
                                  size: 18,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        account.name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (account.rwName != null && account.rwName!.isNotEmpty)
                                        Text(
                                          // ✅ PERBAIKAN: Cek apakah rwName sudah mengandung "RW"
                                          account.rwName!.toUpperCase().startsWith('RW') 
                                              ? account.rwName! 
                                              : 'RW ${account.rwName}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                onChanged: _isLoadingServiceAccounts
                    ? null
                    : (value) {
                        print('🔍 Service Account Selected: $value');
                        setState(() {
                          // ✅ PERBAIKAN: Set ke null jika empty string
                          _selectedServiceAccountId = (value == null || value.isEmpty) ? null : value;
                        });
                      },
                selectedItemBuilder: (BuildContext context) {
                  // ✅ PENTING: Custom builder untuk menampilkan selected value
                  return [
                    // Empty option
                    Text('-- Pilih Service Account --', style: GoogleFonts.poppins(fontSize: 14)),
                    // Service accounts
                    ..._serviceAccounts.map((account) {
                      return Text(
                        account.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ];
                },
                hint: _isLoadingServiceAccounts
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Memuat service account...',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                      )
                    : Text(
                        _serviceAccounts.isEmpty
                            ? 'Tidak ada data'
                            : 'Pilih Service Account',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
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
  final List<custom_file.File> imageFiles;
  final bool isAsset;

  const DetailLaporanScreen({
    super.key,
    required this.reportData,
    required this.imageFiles,
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
      print('  Location: ${reportData['lokasi']}');
      print('  Service Account: ${reportData['serviceAccount']}');
      print('  Has Images: ${imageFiles.length}');

      // Kirim semua foto ke API
      final (success, message, data) = await ComplaintService.createComplaint(
        type: reportData['type']!, // Langsung dari dropdown value
        description: reportData['deskripsi']!,
        location: reportData['lokasi']!, // Tambahkan lokasi
        serviceAccountId:
            reportData['serviceAccount'], // Kirim service account ke API
        images: imageFiles, // Kirim semua foto
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
          lokasi: reportData['lokasi'] ?? '', // Ambil dari form
          waktuPelanggaran: DateFormat(
            'dd MMMM yyyy HH:mm',
          ).format(DateTime.now()),
          ciriCiri:
              reportData['deskripsi'] ??
              'Tidak ada deskripsi', // Fallback jika null
          serviceAccount: reportData['serviceAccount'], // Ambil dari form
          imageFile: imageFiles.isNotEmpty ? imageFiles.first : null,
          isAsset: imageFiles.isNotEmpty,
        );
        print('✅ newReport created: ${newReport.id}');

        // 3. Trigger notifikasi pelaporan berhasil dibuat (optional - jangan block flow)
        try {
          final helper = NotificationHelper();
          await helper.notifyReportCreated(
            category: typeLabel,
            location: reportData['lokasi'] ?? 'Jakarta',
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
                        "Pelaporan anda telah berhasil kami terima dan akan kami proses",
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
    if (imageFiles.isNotEmpty) {
      imageWidget = _InstagramStylePhotoGallery(
        imageFiles: imageFiles,
        isAsset: isAsset,
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
            imageWidget,

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
            _buildDetailRow(
              "Lokasi",
              reportData['lokasi'] ?? 'Tidak ada lokasi',
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

  // Widget untuk menampilkan sepasang Label dan Value dengan Icon
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk membuat progress timeline sesuai Figma
  Widget _buildProgressTimeline(String currentStatus) {
    // Status flow: Menunggu -> Diproses -> Selesai/Ditolak
    final isOpen = currentStatus.toLowerCase() == 'open';
    final isInProgress = currentStatus.toLowerCase() == 'in_progress';
    final isResolved = currentStatus.toLowerCase() == 'resolved';
    final isRejected = currentStatus.toLowerCase() == 'rejected';
    final Color pendingColor =
        (isOpen || isInProgress || isResolved || isRejected)
        ? primaryColor
        : Colors.grey.shade300;

    final Color inProgressColor = (isInProgress || isResolved || isRejected)
        ? primaryColor
        : Colors.grey.shade300;

    final Color resolvedColor = isResolved
        ? primaryColor
        : (isRejected ? Colors.red : Colors.grey.shade300);

    // Line color logic
    final Color line1Color = (isInProgress || isResolved || isRejected)
        ? primaryColor
        : Colors.grey.shade300;

    final Color line2Color = (isResolved || isRejected)
        ? primaryColor
        : Colors.grey.shade300;

    // Format tanggal dan waktu (gunakan data dari laporan jika ada)
    final now = DateTime.now();
    
    // Format manual untuk menghindari locale issue
    String formatDate(DateTime date) {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Oct', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    
    String formatTime(DateTime date) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    
    final createdDate = formatDate(laporan.createdAt);
    final createdTime = formatTime(laporan.createdAt);
    
    // Simulasi waktu untuk status lainnya (bisa diganti dengan data real dari API)
    final processDateTime = laporan.createdAt.add(const Duration(hours: 2));
    final processDate = isInProgress || isResolved || isRejected 
        ? formatDate(processDateTime)
        : formatDate(now);
    final processTime = isInProgress || isResolved || isRejected
        ? formatTime(processDateTime)
        : formatTime(now);
    
    final completedDateTime = laporan.createdAt.add(const Duration(hours: 4));
    final completedDate = isResolved || isRejected
        ? formatDate(completedDateTime)
        : formatDate(now);
    final completedTime = isResolved || isRejected
        ? formatTime(completedDateTime)
        : formatTime(now);

    return Column(
      children: [
        // Row untuk progress dots dan lines
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pending (Menunggu)
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    createdDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    createdTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen ? pendingColor : Colors.white,
                      border: Border.all(
                        color: pendingColor,
                        width: isOpen ? 3 : 2,
                      ),
                    ),
                    child: isOpen
                        ? Icon(Icons.schedule, color: Colors.white, size: 24)
                        : (isInProgress || isResolved || isRejected)
                        ? Icon(Icons.check, color: pendingColor, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Menunggu",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "Laporan sedang menunggu untuk diproses",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Line 1
            Expanded(
              flex: 1,
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 65),
                color: line1Color,
              ),
            ),

            // 2. On Progress (Diproses)
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    processDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isInProgress || isResolved || isRejected
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    processTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isInProgress || isResolved || isRejected
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInProgress ? inProgressColor : Colors.white,
                      border: Border.all(
                        color: inProgressColor,
                        width: isInProgress ? 3 : 2,
                      ),
                    ),
                    child: isInProgress
                        ? Icon(Icons.autorenew, color: Colors.white, size: 24)
                        : (isResolved || isRejected)
                        ? Icon(Icons.check, color: inProgressColor, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Di-proses",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isInProgress || isResolved || isRejected
                          ? Colors.black87
                          : Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isInProgress || isResolved || isRejected
                          ? "Sampah telah di proses oleh admin"
                          : "",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Line 2
            Expanded(
              flex: 1,
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 65),
                color: line2Color,
              ),
            ),

            // 3. Resolve (Selesai) - hijau atau merah tergantung status
            Expanded(
              child: Column(
                children: [
                  // Tanggal dan Waktu
                  Text(
                    completedDate,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isResolved || isRejected
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    completedTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isResolved || isRejected
                          ? primaryColor
                          : Colors.grey.shade400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isResolved || isRejected)
                          ? resolvedColor
                          : Colors.white,
                      border: Border.all(
                        color: resolvedColor,
                        width: (isResolved || isRejected) ? 3 : 2,
                      ),
                    ),
                    child: (isResolved || isRejected)
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selesai",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isResolved || isRejected)
                          ? Colors.black87
                          : Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isResolved
                          ? "Laporan berhasil diselesaikan"
                          : isRejected
                              ? "Laporan ditolak"
                              : "",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan widget gambar yang akan ditampilkan
    Widget imageWidget;

    // Prioritaskan photoUrls (multiple photos dari API)
    if (laporan.photoUrls.isNotEmpty) {
      print('🖼️ Loading ${laporan.photoUrls.length} images from API');
      imageWidget = _InstagramStylePhotoGalleryNetwork(
        photoUrls: laporan.photoUrls,
      );
    } else if (laporan.photoUrl != null) {
      // Fallback untuk single photo (backward compatibility)
      print('🖼️ Loading single image from URL: ${laporan.photoUrl}');
      imageWidget = _InstagramStylePhotoGalleryNetwork(
        photoUrls: [laporan.photoUrl!],
      );
    } else if (laporan.imageFile != null) {
      // File dari local (jarang digunakan untuk detail terkirim)
      imageWidget = Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: buildPlatformImage(
            laporan.imageFile!,
            fit: BoxFit.cover,
            height: 250,
            width: double.infinity,
          ),
        ),
      );
    } else {
      // No image available
      imageWidget = Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade200, Colors.grey.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 60,
                color: Colors.grey.shade600,
              ),
              SizedBox(height: 12),
              Text(
                "Tidak ada gambar",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Detail Laporan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Progress Timeline Status (Sesuai Figma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Keterlambatan
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Keterlambatan",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Subtitle lokasi/kategori dan service account
                    Text(
                      laporan.lokasi.isNotEmpty
                          ? "${laporan.lokasi} • ${laporan.serviceAccountName ?? 'None'}"
                          : "${laporan.kategori} • ${laporan.serviceAccountName ?? 'None'}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Bar dengan 4 Status
                    _buildProgressTimeline(laporan.status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card Deskripsi (sesuai Figma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Deskripsi dengan icon
                    Row(
                      children: [
                        Icon(Icons.menu, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Deskripsi",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Area Foto di dalam Deskripsi
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageWidget,
                    ),
                    const SizedBox(height: 12),
                    
                    // Isi Deskripsi
                    Text(
                      laporan.ciriCiri,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card Informasi dengan Design Modern
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Informasi Laporan",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "ID: ${laporan.id.substring(0, 12)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Detail Data dengan Icon (TANPA Deskripsi karena sudah terpisah)
                    _buildDetailRow("Kota", laporan.kota, Icons.location_city),
                    const Divider(height: 24),
                    _buildDetailRow(
                      "Kategori",
                      laporan.kategori,
                      Icons.category,
                    ),
                    if (laporan.lokasi.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        "Lokasi",
                        laporan.lokasi,
                        Icons.location_on,
                      ),
                    ],
                    if (laporan.serviceAccount != null &&
                        laporan.serviceAccount!.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        "Service Account",
                        laporan.serviceAccount!,
                        Icons.business,
                      ),
                    ],
                    const Divider(height: 24),
                    _buildDetailRow(
                      "Waktu Pelanggaran",
                      laporan.waktuPelanggaran,
                      Icons.access_time,
                    ),
                  ],
                ),
              ),
            ),

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
  
  // Cache untuk service account names (serviceAccountId -> name)
  final Map<String, String> _serviceAccountNames = {};

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
        // Load service accounts untuk mapping ID ke nama
        await _loadServiceAccountNames();
        
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
  
  /// 🔹 Load service account names untuk mapping
  Future<void> _loadServiceAccountNames() async {
    try {
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();
      
      // Build mapping dari ID ke nama
      _serviceAccountNames.clear(); // Clear existing cache
      for (var account in accounts) {
        _serviceAccountNames[account.id] = account.name;
        print('📋 Mapped Service Account: ID=${account.id}, Name=${account.name}');
      }
      
      print('✅ Loaded ${accounts.length} service account names');
      print('📋 Service Account Cache: $_serviceAccountNames');
    } catch (e) {
      print('❌ Error loading service account names: $e');
      // Continue even if this fails
    }
  }

  /// Helper untuk convert Complaint (API) ke Laporan (UI model)
  Laporan _convertComplaintToLaporan(Complaint complaint) {
    // Default values karena Complaint API tidak punya field ini lagi
    final kota = 'Jakarta'; // Default kota
    final waktuPelanggaran = DateFormat(
      'dd MMMM yyyy HH:mm',
    ).format(complaint.createdAt);

    // 📍 Debug lokasi dari API
    print('📍 Location from API: ${complaint.location}');
    print('📍 Is location empty? ${complaint.location?.isEmpty ?? true}');

    // Ambil semua URL foto dari API
    String? photoUrl; // Backward compatibility
    List<String> photoUrls = [];
    if (complaint.photos.isNotEmpty) {
      // Ambil foto pertama untuk backward compatibility
      photoUrl = complaint.photos.first.url;
      print('📷 Original Photo URL from API: $photoUrl');

      // Process semua foto
      for (var photo in complaint.photos) {
        String fullUrl = photo.url;

        // Jika URL relatif (dimulai dengan /), tambahkan base URL
        if (fullUrl.isNotEmpty && fullUrl.startsWith('/')) {
          final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
          fullUrl = '$baseUrlWithoutApi$fullUrl';
        } else if (fullUrl.isNotEmpty && !fullUrl.startsWith('http')) {
          // Jika relatif tanpa slash awal
          final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api/v1', '');
          fullUrl = '$baseUrlWithoutApi/$fullUrl';
        }

        photoUrls.add(fullUrl);
      }

      // Update photoUrl untuk backward compatibility
      if (photoUrls.isNotEmpty) {
        photoUrl = photoUrls.first;
      }

      print('📷 Loaded ${photoUrls.length} photos from API');
    } else {
      print('📷 No photos available for this complaint');
    }

    // Get service account name from cache
    String? serviceAccountName;
    if (complaint.serviceAccountId != null && complaint.serviceAccountId!.isNotEmpty) {
      serviceAccountName = _serviceAccountNames[complaint.serviceAccountId];
      print('📋 Service Account Lookup:');
      print('   - ID from API: ${complaint.serviceAccountId}');
      print('   - Name from cache: ${serviceAccountName ?? "NOT FOUND IN CACHE"}');
      print('   - Cache has ${_serviceAccountNames.length} entries');
      
      // If not found, try to reload service accounts
      if (serviceAccountName == null) {
        print('⚠️ Service account name not found in cache, will show ID as fallback');
        // Fallback: use ID as display name
        serviceAccountName = 'Service Account #${complaint.serviceAccountId}';
      }
    } else {
      print('📋 No service account ID in complaint');
    }
    
    final laporan = Laporan(
      kota: kota,
      kategori: complaint.typeText, // Gunakan getter typeText untuk display
      lokasi: complaint.location ?? '', // Ambil lokasi dari API
      waktuPelanggaran: waktuPelanggaran,
      ciriCiri: complaint.description,
      serviceAccount: complaint.serviceAccountId, // Service account ID dari API
      serviceAccountName: serviceAccountName, // Service account name dari cache
      imageFile: null, // API returns URL, bukan File
      photoUrl: photoUrl, // Simpan URL foto pertama (backward compatibility)
      photoUrls: photoUrls, // Simpan semua URL foto
      isAsset: complaint.photos.isNotEmpty, // Ada foto dari API
      status: complaint.status, // Ambil status dari database
    );

    print('📍 Laporan object lokasi: ${laporan.lokasi}');
    print('📍 Laporan lokasi isEmpty: ${laporan.lokasi.isEmpty}');

    return laporan;
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail Image dengan Border Gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withOpacity(0.3),
                        primaryColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade100,
                      child: report.photoUrl != null
                          ? Image.network(
                              report.photoUrl!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.shade300,
                                        Colors.grey.shade200,
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 40,
                                    color: Colors.grey.shade500,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2.5,
                                          color: primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                            )
                          : report.imageFile != null
                          ? buildPlatformImage(
                              report.imageFile!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade300,
                                    Colors.grey.shade200,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge dengan Gradient
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getBadgeTextColor(),
                              _getBadgeTextColor().withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _getBadgeTextColor().withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _getStatusText().toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title dengan Icon
                      Row(
                        children: [
                          Icon(
                            Icons.report_problem_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              report.kategori.isNotEmpty
                                  ? report.kategori
                                  : 'Sampah belum diambil',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Date dengan Background
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd MMM yyyy HH:mm',
                              ).format(report.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lokasi jika ada
                      if (report.lokasi.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.lokasi,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
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

                // Arrow Icon dengan Gradient Background
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withOpacity(0.1),
                        primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
              ],
            ),
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

/// 🔹 Instagram-style Photo Gallery dengan PageView dan Dot Indicators
class _InstagramStylePhotoGallery extends StatefulWidget {
  final List<custom_file.File> imageFiles;
  final bool isAsset;

  const _InstagramStylePhotoGallery({
    required this.imageFiles,
    required this.isAsset,
  });

  @override
  State<_InstagramStylePhotoGallery> createState() =>
      _InstagramStylePhotoGalleryState();
}

class _InstagramStylePhotoGalleryState
    extends State<_InstagramStylePhotoGallery> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // PageView untuk foto
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.imageFiles.length,
                itemBuilder: (context, index) {
                  return buildPlatformImage(
                    widget.imageFiles[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                  );
                },
              ),
            ),

            // Counter badge di kanan atas (seperti Instagram)
            if (widget.imageFiles.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.imageFiles.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Dot indicators di bawah (seperti Instagram)
            if (widget.imageFiles.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imageFiles.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kiri (muncul jika bukan foto pertama)
            if (widget.imageFiles.length > 1 && _currentPage > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kanan (muncul jika bukan foto terakhir)
            if (widget.imageFiles.length > 1 &&
                _currentPage < widget.imageFiles.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
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

/// 🔹 Instagram-style Photo Gallery untuk Network Images (dari API)
class _InstagramStylePhotoGalleryNetwork extends StatefulWidget {
  final List<String> photoUrls;

  const _InstagramStylePhotoGalleryNetwork({required this.photoUrls});

  @override
  State<_InstagramStylePhotoGalleryNetwork> createState() =>
      _InstagramStylePhotoGalleryNetworkState();
}

class _InstagramStylePhotoGalleryNetworkState
    extends State<_InstagramStylePhotoGalleryNetwork> {
  late PageController _pageController;
  int _currentPage = 0;
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // PageView untuk foto dari network
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.photoUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.photoUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 3,
                            color: primaryColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 60,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Gagal memuat gambar',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Counter badge di kanan atas (seperti Instagram)
            if (widget.photoUrls.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.photoUrls.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Dot indicators di bawah (seperti Instagram)
            if (widget.photoUrls.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.photoUrls.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kiri (muncul jika bukan foto pertama)
            if (widget.photoUrls.length > 1 && _currentPage > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            // Arrow navigasi kanan (muncul jika bukan foto terakhir)
            if (widget.photoUrls.length > 1 &&
                _currentPage < widget.photoUrls.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
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

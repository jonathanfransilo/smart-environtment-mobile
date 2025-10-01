import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart'; 

class TambahAkunLayananScreen extends StatefulWidget {
  const TambahAkunLayananScreen({super.key});

  @override
  State<TambahAkunLayananScreen> createState() =>
      _TambahAkunLayananScreenState();
}

class _TambahAkunLayananScreenState extends State<TambahAkunLayananScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _teleponController = TextEditingController(); 
  final TextEditingController _detailAlamatController = TextEditingController();
  final TextEditingController _kelurahanController = TextEditingController();
  final TextEditingController _kecamatanController = TextEditingController();

  double _latitude = -6.2;
  double _longitude = 106.8;
  double _currentZoom = 16.0;

  final MapController _mapController = MapController();

  // Data Dummy Kecamatan & Kelurahan
  final List<String> _kecamatanList = [
    "Gambir",
    "Tanah Abang",
    "Menteng",
    "Cempaka Putih",
    "Tanjung Priok",
    "Penjaringan",
    "Setiabudi",
    "Pasar Minggu",
  ];

  final Map<String, LatLng> _kecamatanCoordinates = {
    "Gambir": LatLng(-6.1754, 106.8272),
    "Tanah Abang": LatLng(-6.1860, 106.8113),
    "Menteng": LatLng(-6.1901, 106.8326),
    "Cempaka Putih": LatLng(-6.1770, 106.8650),
    "Tanjung Priok": LatLng(-6.1286, 106.8807),
    "Penjaringan": LatLng(-6.1180, 106.7894),
    "Setiabudi": LatLng(-6.2196, 106.8325),
    "Pasar Minggu": LatLng(-6.2845, 106.8331),
  };

  final Map<String, List<String>> _kecamatanKelurahanMap = {
    "Menteng": ["Kelurahan Menteng", "Kelurahan Cikini", "Kelurahan Gondangdia"],
    "Cempaka Putih": [
      "Kelurahan Cempaka Putih Barat",
      "Kelurahan Cempaka Putih Timur"
    ],
    "Tanjung Priok": ["Kelurahan Sunter Agung", "Kelurahan Papanggo"],
    "Penjaringan": ["Kelurahan Pluit", "Kelurahan Penjaringan"],
    "Setiabudi": ["Kelurahan Kuningan Timur", "Kelurahan Karet"],
    "Pasar Minggu": ["Kelurahan Pejaten Timur", "Kelurahan Jati Padang"],
    "Gambir": ["Kelurahan Gambir", "Kelurahan Petojo Selatan"],
    "Tanah Abang": ["Kelurahan Kebon Melati", "Kelurahan Bendungan Hilir"],
  };

  final Map<String, LatLng> _kelurahanCoordinates = {
    "Kelurahan Menteng": LatLng(-6.1901, 106.8326),
    "Kelurahan Cikini": LatLng(-6.1972, 106.8416),
    "Kelurahan Gondangdia": LatLng(-6.1898, 106.8364),
    "Kelurahan Cempaka Putih Barat": LatLng(-6.1770, 106.8650),
    "Kelurahan Cempaka Putih Timur": LatLng(-6.1775, 106.8700),
    "Kelurahan Sunter Agung": LatLng(-6.1420, 106.8655),
    "Kelurahan Papanggo": LatLng(-6.1280, 106.8800),
    "Kelurahan Pluit": LatLng(-6.1180, 106.7894),
    "Kelurahan Penjaringan": LatLng(-6.1200, 106.8000),
    "Kelurahan Kuningan Timur": LatLng(-6.2220, 106.8330),
    "Kelurahan Karet": LatLng(-6.2100, 106.8200),
    "Kelurahan Pejaten Timur": LatLng(-6.2845, 106.8331),
    "Kelurahan Jati Padang": LatLng(-6.2900, 106.8200),
    "Kelurahan Gambir": LatLng(-6.1754, 106.8272),
    "Kelurahan Petojo Selatan": LatLng(-6.1760, 106.8200),
    "Kelurahan Kebon Melati": LatLng(-6.1900, 106.8100),
    "Kelurahan Bendungan Hilir": LatLng(-6.2000, 106.8150),
  };

  String? _selectedKecamatan;
  String? _selectedKelurahan;
  bool _isLoading = true;

  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () { // ⏱️ Mengurangi waktu shimmer
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    // 💡 Implementasi reverse geocoding untuk mendapatkan alamat jika diperlukan
    debugPrint("Koordinat dipilih: $lat, $lng");
  }

  Future<void> _searchAddress(String address) async {
    try {
      if (address.isEmpty) return;
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        });
        _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
      }
    } catch (e) {
      debugPrint("Gagal mencari alamat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alamat tidak ditemukan")),
      );
    }
  }

  void _showSuccessBottomSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                "Akun layanan berhasil dibuat!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600), // 🎨 Style diperbarui
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue, // 🎨 Warna tombol diubah ke hijau
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // 🎨 Radius disesuaikan
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Mengirim data kembali ke LayananSampahScreen
                    Navigator.pop(context, data);
                  },
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _simpanData() {
    // 💡 Tambahkan validasi untuk memastikan kelurahan dan kecamatan terpilih
    if (_selectedKecamatan == null || _selectedKelurahan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Harap pilih Kecamatan dan Kelurahan yang valid."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final data = {
        "id": DateTime.now().millisecondsSinceEpoch.toString(),
        "nama": _namaController.text,
        "telepon": _teleponController.text, // 🟢 Menyimpan data telepon
        "provinsi": "DKI Jakarta",
        "kecamatan": _selectedKecamatan,
        "kelurahan": _selectedKelurahan,
        "alamat lengkap": _detailAlamatController.text,
        "latitude": _latitude,
        "longitude": _longitude,
      };
      _showSuccessBottomSheet(context, data);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose(); // 🟢 Dispose controller telepon
    _detailAlamatController.dispose();
    _kelurahanController.dispose();
    _kecamatanController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🎨 Background putih
      appBar: AppBar(
        title: Text(
          "Tambahkan Akun Layanan",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white), // 🎨 Teks putih
        ),
        backgroundColor: const Color(0xFF4CAF50), // 🎨 AppBar hijau
        foregroundColor: Colors.white,
        elevation: 0, // 🎨 Hilangkan shadow
      ),
      body: _isLoading ? _buildShimmer() : _buildForm(),
      bottomNavigationBar: !_isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpanData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // 🎨 Tombol Simpan Hijau
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text("Simpan",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16)),
                ),
              ),
            )
          : null,
    );
  }

  // ------------------------------------
  // Helper Widget
  // ------------------------------------

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nama Lengkap
              _buildLabel("Nama Lengkap"),
              _buildTextFormField(
                controller: _namaController,
                hintText: "Masukkan nama lengkap",
                validatorMessage: "Nama wajib diisi",
              ),
              const SizedBox(height: 16),
              
              // 2. Nomor Telepon (🟢 Tambahan)
              _buildLabel("Nomor Telepon"),
              _buildTextFormField(
                controller: _teleponController,
                hintText: "Contoh: 0812xxxxxxxx",
                keyboardType: TextInputType.phone,
                validatorMessage: "Nomor telepon wajib diisi",
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 16),

              // 3. Provinsi (Otomatis)
              _buildLabel("Provinsi"),
              _buildReadOnlyTextFormField(value: "DKI Jakarta"),
              const SizedBox(height: 16),

              // 4. Kecamatan (Autocomplete)
              _buildLabel("Kecamatan"),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _kecamatanList;
                  }
                  return _kecamatanList.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedKecamatan = selection;
                    _kecamatanController.text = selection;
                    _selectedKelurahan = null;
                    _kelurahanController.clear();
                    if (_kecamatanCoordinates.containsKey(selection)) {
                      final pos = _kecamatanCoordinates[selection]!;
                      _latitude = pos.latitude;
                      _longitude = pos.longitude;
                      _mapController.move(
                          LatLng(_latitude, _longitude), _currentZoom);
                    }
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  _kecamatanController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _inputDecoration(
                        hintText: "Pilih atau ketik kecamatan"),
                    validator: (value) => value == null || value.isEmpty
                        ? "Kecamatan wajib diisi"
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // 5. Kelurahan (Autocomplete Filtered)
              _buildLabel("Kelurahan"),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (_selectedKecamatan == null) {
                    return const Iterable<String>.empty();
                  }
                  final kelurahanList =
                      _kecamatanKelurahanMap[_selectedKecamatan] ?? [];
                  if (textEditingValue.text.isEmpty) {
                    return kelurahanList;
                  }
                  return kelurahanList.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedKelurahan = selection;
                    _kelurahanController.text = selection;
                    if (_kelurahanCoordinates.containsKey(selection)) {
                      final pos = _kelurahanCoordinates[selection]!;
                      _latitude = pos.latitude;
                      _longitude = pos.longitude;
                      _mapController.move(
                          LatLng(_latitude, _longitude), _currentZoom);
                    }
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  _kelurahanController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _inputDecoration(
                        hintText: "Pilih kelurahan (isi kecamatan dulu)"),
                    validator: (value) => value == null || value.isEmpty
                        ? "Kelurahan wajib diisi"
                        : null,
                    enabled: _selectedKecamatan != null, // 💡 Nonaktifkan jika kecamatan belum dipilih
                  );
                },
              ),
              const SizedBox(height: 16),

              // 6. Preview Lokasi Map
              _buildLabel("Preview Lokasi (Titik Merah = Lokasi Dipilih)"),
              const SizedBox(height: 8),
              _buildMapPreview(),
              const SizedBox(height: 16),

              // 7. Detail Alamat
              _buildLabel("Detail Alamat"),
              _buildTextFormField(
                controller: _detailAlamatController,
                hintText: "Contoh: nama bangunan, nomor unit",
                onFieldSubmitted: _searchAddress,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), // 🎨 Radius disesuaikan
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2), // 🎨 Warna fokus hijau
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? validatorMessage,
    Function(String)? onFieldSubmitted,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(hintText: hintText),
      validator: (value) {
        if (validatorMessage != null && (value == null || value.isEmpty)) {
          return validatorMessage;
        }
        return null;
      },
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  Widget _buildReadOnlyTextFormField({required String value}) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: _inputDecoration(hintText: value).copyWith(
        fillColor: Colors.grey.shade100,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_latitude, _longitude),
                initialZoom: _currentZoom,
                onTap: (tapPosition, point) {
                  setState(() {
                    _latitude = point.latitude;
                    _longitude = point.longitude;
                  });
                  _getAddressFromCoordinates(point.latitude, point.longitude);
                  _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.mycompany.myapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_latitude, _longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container( // 🎨 Container untuk menggabungkan zoom buttons
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    )
                  ]
                ),
                child: Column(
                  children: [
                    _buildZoomButton(Icons.add, _zoomIn, "zoomIn"),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                    _buildZoomButton(Icons.remove, _zoomOut, "zoomOut"),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                    _buildZoomButton(Icons.fullscreen, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenMapPage(
                            latitude: _latitude,
                            longitude: _longitude,
                            zoom: _currentZoom,
                          ),
                        ),
                      ).then((result) {
                        // 💡 Jika kembali dari fullscreen map, perbarui posisi
                        if (result != null && result is LatLng) {
                          setState(() {
                            _latitude = result.latitude;
                            _longitude = result.longitude;
                          });
                          _mapController.move(result, _currentZoom);
                        }
                      });
                    }, "fullscreenMap", isLast: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed, String tag, {bool isLast = false}) {
    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 0),
      child: FloatingActionButton.small(
        heroTag: tag,
        backgroundColor: Colors.transparent, // 🎨 Transparan karena sudah ada container
        elevation: 0,
        onPressed: onPressed,
        child: Icon(icon, color: Colors.black),
      ),
    );
  }
}

class FullscreenMapPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;

  const FullscreenMapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  @override
  State<FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<FullscreenMapPage> {
  late MapController _mapController;
  late double _latitude;
  late double _longitude;
  late double _currentZoom;

  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    _currentZoom = widget.zoom;
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peta Lengkap"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // 💡 Mengembalikan koordinat yang dipilih ke halaman sebelumnya
              Navigator.pop(context, LatLng(_latitude, _longitude));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_latitude, _longitude),
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                setState(() {
                  _latitude = point.latitude;
                  _longitude = point.longitude;
                });
                _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.mycompany.myapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_latitude, _longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "fullscreenZoomIn",
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "fullscreenZoomOut",
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
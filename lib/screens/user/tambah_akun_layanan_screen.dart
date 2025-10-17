import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

import '../../models/app_settings.dart';
import '../../models/area_option.dart';
import '../../models/service_account.dart';
import '../../services/area_service.dart';
import '../../services/config_service.dart';
import '../../services/service_account_service.dart';
import '../../services/notification_helper.dart';

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
  final TextEditingController _provinsiController = TextEditingController();
  final TextEditingController _kotaController = TextEditingController();

  final AreaService _areaService = AreaService();
  final ServiceAccountService _serviceAccountService = ServiceAccountService();
  final ConfigService _configService = ConfigService();
  final Dio _geocodeClient = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      headers: {
        'User-Agent':
            'smart-environment-mobile/1.0 (https://github.com/citiasia-inc/smart-environment-mobile)',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  double _latitude = -6.2;
  double _longitude = 106.8;
  double _currentZoom = 16.0;

  final MapController _mapController = MapController();

  List<AreaOption> _kecamatanOptions = [];
  List<AreaOption> _kelurahanOptions = [];
  AreaOption? _selectedKecamatanOption;
  AreaOption? _selectedKelurahanOption;

  bool _isLoading = true;
  bool _isKelurahanLoading = false;
  bool _isSubmitting = false;

  String? _provinceName;
  String? _cityName;

  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    try {
      final AppSettingsData? settings = await _configService.fetchAppSettings();
      final kecamatan = await _areaService.fetchKecamatan();

      if (!mounted) return;

      setState(() {
        _provinceName = settings?.province?.name;
        _cityName = settings?.city?.name;
        _provinsiController.text = _provinceName ?? '';
        _kotaController.text = _cityName ?? '';
        _kecamatanOptions = kecamatan;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Gagal memuat data awal: ${_errorMessage(error)}');
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map &&
          data['errors'] is Map &&
          data['errors']['message'] != null) {
        return data['errors']['message'].toString();
      }
      return error.message ?? 'Terjadi kesalahan jaringan';
    }
    return error.toString();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  AreaOption? _findOptionByName(List<AreaOption> options, String name) {
    final query = name.toLowerCase();
    for (final option in options) {
      if (option.name.toLowerCase() == query) {
        return option;
      }
    }
    return null;
  }

  Future<void> _handleKecamatanSelection(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final option = _findOptionByName(_kecamatanOptions, trimmed);
    if (option == null) {
      _showSnackBar('Kecamatan "$trimmed" tidak ditemukan');
      return;
    }

    if (_selectedKecamatanOption?.id == option.id) {
      _kecamatanController.text = option.name;
      return;
    }

    setState(() {
      _selectedKecamatanOption = option;
      _kecamatanController.text = option.name;
      _kelurahanController.clear();
      _selectedKelurahanOption = null;
      _kelurahanOptions = [];
    });

    await _searchAddress(
      '${option.name}, ${_cityName ?? ''}, ${_provinceName ?? ''}',
    );
    await _loadKelurahanOptions(option);
  }

  Future<void> _loadKelurahanOptions(AreaOption kecamatan) async {
    setState(() {
      _isKelurahanLoading = true;
    });

    try {
      final kelurahan =
          await _areaService.fetchKelurahan(parentId: kecamatan.id);
      if (!mounted) return;

      setState(() {
        _kelurahanOptions = kelurahan;
      });

      if (kelurahan.isEmpty) {
        _showSnackBar('Kelurahan untuk ${kecamatan.name} tidak ditemukan');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Gagal memuat kelurahan: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isKelurahanLoading = false;
        });
      }
    }
  }

  Future<void> _handleKelurahanSelection(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final option = _findOptionByName(_kelurahanOptions, trimmed);
    if (option == null) {
      _showSnackBar('Kelurahan "$trimmed" tidak ditemukan');
      return;
    }

    setState(() {
      _selectedKelurahanOption = option;
      _kelurahanController.text = option.name;
    });

    await _searchAddress(
      '${option.name}, ${_selectedKecamatanOption?.name ?? ''}, ${_cityName ?? ''}, ${_provinceName ?? ''}',
    );
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    debugPrint('Koordinat dipilih: $lat, $lng');
  }

  Future<void> _searchAddress(String address) async {
    if (address.trim().isEmpty) {
      return;
    }

    final LatLng? coordinates = await _resolveCoordinates(address);

    if (!mounted) return;

    if (coordinates == null) {
      _showSnackBar('Alamat tidak ditemukan');
      return;
    }

    setState(() {
      _latitude = coordinates.latitude;
      _longitude = coordinates.longitude;
    });
    _mapController.move(LatLng(_latitude, _longitude), _currentZoom);
  }

  Future<LatLng?> _resolveCoordinates(String address) async {
    try {
      if (kIsWeb) {
        final response = await _geocodeClient.get<List<dynamic>>(
          '/search',
          queryParameters: {
            'format': 'json',
            'limit': 1,
            'q': address,
          },
        );

        final data = response.data;
        if (data == null || data.isEmpty) {
          return null;
        }

        final first = data.first;
        if (first is Map<String, dynamic>) {
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
        return null;
      } else {
        final locations = await locationFromAddress(address);
        if (locations.isEmpty) {
          return null;
        }
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (error, stackTrace) {
      debugPrint('Gagal menemukan koordinat untuk "$address": $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<void> _simpanData() async {
    if (_selectedKecamatanOption == null ||
        _selectedKelurahanOption == null) {
      _showSnackBar(
        'Harap pilih Kecamatan dan Kelurahan yang valid.',
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final account = await _serviceAccountService.createAccount(
        name: _namaController.text,
        contactPhone: _teleponController.text,
        address: _detailAlamatController.text,
        areaId: _selectedKelurahanOption!.id,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (!mounted) return;

      // Trigger notifikasi akun layanan berhasil dibuat
      final helper = NotificationHelper();
      await helper.notifyServiceAccountCreated(
        accountName: account.name,
      );

      _showSuccessBottomSheet(context, account);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Gagal menyimpan akun: ${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessBottomSheet(BuildContext context, ServiceAccount account) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                'Akun layanan berhasil dibuat!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                account.name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                account.address,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, account);
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _detailAlamatController.dispose();
    _kelurahanController.dispose();
    _kecamatanController.dispose();
    _provinsiController.dispose();
    _kotaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tambahkan Akun Layanan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading ? _buildShimmer() : _buildForm(),
      bottomNavigationBar: !_isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _simpanData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Menyimpan...',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Simpan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

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
              _buildLabel('Nama Lengkap'),
              _buildTextFormField(
                controller: _namaController,
                hintText: 'Masukkan nama lengkap',
                validatorMessage: 'Nama wajib diisi',
              ),
              const SizedBox(height: 16),
              _buildLabel('Nomor Telepon'),
              _buildTextFormField(
                controller: _teleponController,
                hintText: 'Contoh: 0812xxxxxxxx',
                keyboardType: TextInputType.phone,
                validatorMessage: 'Nomor telepon wajib diisi',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Kota/Kabupaten'),
              _buildReadOnlyTextFormField(
                controller: _kotaController,
                hintText: 'Masukkan kota/kabupaten',
                readOnly: (_cityName ?? '').isNotEmpty,
              ),
              const SizedBox(height: 16),
              _buildLabel('Kecamatan'),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  final names =
                      _kecamatanOptions.map((option) => option.name).toList();
                  if (query.isEmpty) {
                    return names;
                  }
                  return names.where(
                    (name) => name.toLowerCase().contains(query),
                  );
                },
                onSelected: _handleKecamatanSelection,
                fieldViewBuilder: (
                  context,
                  textController,
                  focusNode,
                  onEditingComplete,
                ) {
                  if (textController.text != _kecamatanController.text) {
                    textController.value = _kecamatanController.value;
                  }
                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration:
                        _inputDecoration(hintText: 'Pilih atau ketik kecamatan'),
                    validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Kecamatan wajib diisi'
                            : null,
                    onEditingComplete: () {
                      onEditingComplete();
                      _handleKecamatanSelection(textController.text);
                    },
                    onChanged: (value) {
                      _kecamatanController.text = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Kelurahan'),
              Column(
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (_selectedKecamatanOption == null) {
                        return const Iterable<String>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      final names = _kelurahanOptions
                          .map((option) => option.name)
                          .toList();
                      if (query.isEmpty) {
                        return names;
                      }
                      return names.where(
                        (name) => name.toLowerCase().contains(query),
                      );
                    },
                    onSelected: _handleKelurahanSelection,
                    fieldViewBuilder: (
                      context,
                      textController,
                      focusNode,
                      onEditingComplete,
                    ) {
                      if (textController.text != _kelurahanController.text) {
                        textController.value = _kelurahanController.value;
                      }
                      return TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: _selectedKecamatanOption != null &&
                            !_isKelurahanLoading,
                        decoration: _inputDecoration(
                          hintText: _selectedKecamatanOption == null
                              ? 'Pilih kecamatan terlebih dahulu'
                              : 'Pilih kelurahan',
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Kelurahan wajib diisi'
                                : null,
                        onEditingComplete: () {
                          onEditingComplete();
                          _handleKelurahanSelection(textController.text);
                        },
                        onChanged: (value) {
                          _kelurahanController.text = value;
                        },
                      );
                    },
                  ),
                  if (_isKelurahanLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Preview Lokasi (Titik Merah = Lokasi Dipilih)'),
              const SizedBox(height: 8),
              _buildMapPreview(),
              const SizedBox(height: 16),
              _buildLabel('Detail Alamat'),
              _buildTextFormField(
                controller: _detailAlamatController,
                hintText: 'Contoh: nama bangunan, nomor unit',
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
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.black87,
        ),
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
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
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
      onFieldSubmitted: (value) {
        if (onFieldSubmitted != null) {
          onFieldSubmitted(value);
        }
      },
    );
  }

  Widget _buildReadOnlyTextFormField({
    required TextEditingController controller,
    String? hintText,
    bool readOnly = true,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: _inputDecoration(
        hintText: hintText ?? controller.text,
      ).copyWith(
        fillColor: readOnly ? Colors.grey.shade100 : null,
        filled: readOnly,
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
                  _mapController.move(
                    LatLng(_latitude, _longitude),
                    _currentZoom,
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.mycompany.myapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_latitude, _longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(217),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildZoomButton(Icons.add, _zoomIn, 'zoomIn'),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey,
                    ),
                    _buildZoomButton(Icons.remove, _zoomOut, 'zoomOut'),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey,
                    ),
                    _buildZoomButton(
                      Icons.fullscreen,
                      () {
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
                          if (result != null && result is LatLng) {
                            setState(() {
                              _latitude = result.latitude;
                              _longitude = result.longitude;
                            });
                            _mapController.move(result, _currentZoom);
                          }
                        });
                      },
                      'fullscreenMap',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(
    IconData icon,
    VoidCallback onPressed,
    String tag, {
    bool isLast = false,
  }) {
    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 0),
      child: FloatingActionButton.small(
        heroTag: tag,
        backgroundColor: Colors.transparent,
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
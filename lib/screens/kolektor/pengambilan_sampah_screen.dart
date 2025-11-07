import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ambil_foto_screen.dart';
import '../../services/pickup_service.dart';

class PengambilanSampahScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String userPhone;
  final String address;
  final String idPengambilan;
  final String distance;
  final String time;
  final double latitude;
  final double longitude;
  final String status; // Tambahkan parameter status

  const PengambilanSampahScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.userPhone,
    required this.address,
    required this.idPengambilan,
    required this.distance,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.status = 'pending', // Default ke pending
  });

  @override
  State<PengambilanSampahScreen> createState() =>
      _PengambilanSampahScreenState();
}

class _PengambilanSampahScreenState extends State<PengambilanSampahScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _animController;
  late Animation<double> _markerScale;
  double _sheetExtent = 0.4;
  bool _isFullScreen = false;
  bool _isConfirmed = false; // Status konfirmasi pengambilan

  Future<void> _openGoogleMaps(double lat, double lng) async {
    // Format URL dengan query parameter yang lebih jelas untuk navigasi
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    print('🗺️ Opening Google Maps with coordinates: $lat, $lng');
    print('🔗 URL: $googleMapsUrl');

    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  Future<void> _confirmPickup() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Mengkonfirmasi pengambilan...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    // Call API to start pickup
    final (success, message) = await PickupService.startPickup(widget.pickupId);

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (success) {
      setState(() {
        _isConfirmed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengambilan sampah dikonfirmasi!',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Gagal mengkonfirmasi pengambilan',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper method untuk format nomor telepon dari 0xxx menjadi +62xxx
  String _formatPhoneNumber(String phone) {
    // Bersihkan nomor dari spasi, dash, dan tanda kurung
    String formatted = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');

    // Jika diawali dengan 0, ganti dengan +62
    if (formatted.startsWith('0')) {
      return '+62${formatted.substring(1)}';
    }

    // Jika diawali dengan 62 tanpa +, tambahkan +
    if (formatted.startsWith('62') && !formatted.startsWith('+')) {
      return '+$formatted';
    }

    // Jika sudah benar formatnya, return as is
    return formatted;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Format nomor telepon ke format internasional (+62xxx)
    final String formattedPhone = _formatPhoneNumber(phoneNumber);
    final Uri phoneUri = Uri.parse('tel:$formattedPhone');

    if (!await launchUrl(phoneUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi telepon.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openChat(String phoneNumber) async {
    // Format nomor telepon ke format internasional (+62xxx)
    final String formattedPhone = _formatPhoneNumber(phoneNumber);

    // Untuk WhatsApp, hilangkan tanda + (butuh format 62xxx saja)
    final String whatsappNumber = formattedPhone
        .replaceAll('+', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    final Uri whatsappUri = Uri.parse('https://wa.me/$whatsappNumber');

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<Widget> _buildContactButtons() {
    return [
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => _openChat(widget.userPhone),
          icon: const Icon(Icons.chat_bubble_outline),
          color: Colors.blue[600],
          iconSize: 22,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => _makePhoneCall(widget.userPhone),
          icon: const Icon(Icons.phone_outlined),
          color: Colors.green[600],
          iconSize: 22,
        ),
      ),
    ];
  }

  // Method untuk membuat TileLayer yang lebih reliable dengan fallback providers
  TileLayer _buildTileLayer() {
    // Gunakan Cartodb Positron yang lebih reliable dan tidak memblokir akses
    return TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.citiasia.smartenvironment/1.0',
      additionalOptions: const {
        'attribution': '© OpenStreetMap contributors, © CartoDB',
      },
      maxZoom: 19,
      minZoom: 1,
    );
  }

  void _showFullScreenMap(LatLng location) {
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  _buildTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 70,
                        height: 70,
                        child: const Icon(
                          Icons.location_on,
                          size: 45,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 40,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _markerScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    // Cek status - jika sudah on_progress, set _isConfirmed = true
    if (widget.status == 'on_progress') {
      _isConfirmed = true;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF009688);
    final LatLng pickupLocation = LatLng(widget.latitude, widget.longitude);
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isFullScreen
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Pengambilan Sampah',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
      body: Stack(
        children: [
          // Map dengan animasi fullscreen
          GestureDetector(
            onTap: () => _showFullScreenMap(pickupLocation),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isFullScreen ? screenHeight : screenHeight * 0.6,
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: pickupLocation,
                  initialZoom: 15.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  _buildTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pickupLocation,
                        width: 60,
                        height: 60,
                        child: ScaleTransition(
                          scale: _markerScale,
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tombol kontrol map (zoom & fullscreen)
          if (!_isFullScreen)
            Positioned(
              bottom: screenHeight * 0.45,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: "zoomIn",
                    onPressed: _zoomIn,
                    mini: true,
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: "zoomOut",
                    onPressed: _zoomOut,
                    mini: true,
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: "fullscreen",
                    onPressed: _toggleFullScreen,
                    mini: true,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(
                      _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Efek blur saat sheet naik
          if (_sheetExtent > 0.45 && !_isFullScreen)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: (_sheetExtent - 0.45) * 40,
                  sigmaY: (_sheetExtent - 0.45) * 40,
                ),
                child: Container(color: Colors.black.withOpacity(0)),
              ),
            ),

          // Bottom Sheet
          if (!_isFullScreen)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() => _sheetExtent = notification.extent);
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.35,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _sectionTitle("Pengguna"),
                          const SizedBox(height: 12),
                          _userInfo(),
                          const SizedBox(height: 16),
                          _locationInfo(primaryColor),
                          const SizedBox(height: 20),
                          _lihatLokasiButton(primaryColor),
                          const SizedBox(height: 12),
                          // Tampilkan tombol berdasarkan status konfirmasi
                          _isConfirmed
                              ? _ambilFotoButton(primaryColor)
                              : _ambilButton(primaryColor),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Tombol exit fullscreen
          if (_isFullScreen)
            Positioned(
              top: 40,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: _toggleFullScreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget Reusable

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );

  Widget _userInfo() => Row(
    children: [
      const CircleAvatar(
        radius: 24,
        backgroundColor: Color(0xFFE0E0E0),
        child: Icon(Icons.person, color: Colors.black54, size: 28),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              widget.userPhone.isNotEmpty && widget.userPhone != '-'
                  ? widget.userPhone
                  : 'Nomor telepon tidak tersedia',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: widget.userPhone.isNotEmpty && widget.userPhone != '-'
                    ? Colors.grey[600]
                    : Colors.grey[400],
                fontStyle:
                    widget.userPhone.isNotEmpty && widget.userPhone != '-'
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      // Tampilkan tombol chat dan telepon hanya setelah konfirmasi dan jika ada nomor telepon
      if (_isConfirmed &&
          widget.userPhone.isNotEmpty &&
          widget.userPhone != '-')
        ..._buildContactButtons(),
    ],
  );

  Widget _locationInfo(Color primaryColor) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, color: primaryColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lokasi Pengambilan',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.address,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'ID Pengambilan: ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    widget.idPengambilan,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _lihatLokasiButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => _openGoogleMaps(widget.latitude, widget.longitude),
      icon: const Icon(Icons.map_outlined, color: Colors.white),
      label: Text(
        'Lihat di Google Maps',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[600],
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  );

  Widget _ambilButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _confirmPickup,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        'Ambil',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _ambilFotoButton(Color primaryColor) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () async {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Memulai pengambilan...',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );

        // Call API to start pickup
        final (success, message) = await PickupService.startPickup(
          widget.pickupId,
        );

        // Close loading
        if (mounted) Navigator.of(context).pop();

        if (success) {
          // Navigate to photo screen
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmbilFotoScreen(
                  pickupId: widget.pickupId,
                  userName: widget.userName,
                  address: widget.address,
                  idPengambilan: widget.idPengambilan,
                ),
              ),
            );
          }
        } else {
          // Show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'Gagal memulai pengambilan'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        'Ambil Foto',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

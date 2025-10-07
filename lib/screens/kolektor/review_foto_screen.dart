import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'input_kantong_screen.dart';

class ReviewFotoScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String address;
  final String idPengambilan;
  final XFile imageFile;

  const ReviewFotoScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    required this.imageFile,
  });

  @override
  State<ReviewFotoScreen> createState() => _ReviewFotoScreenState();
}

class _ReviewFotoScreenState extends State<ReviewFotoScreen> {
  int _currentStep = 1; // 0: Datang, 1: Foto (completed), 2: Input Kantong, 3: Selesai
  bool _isUploading = false;

  Future<void> _retakePhoto() async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      // Jika user mengambil foto baru, replace foto lama
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewFotoScreen(
              pickupId: widget.pickupId,
              userName: widget.userName,
              address: widget.address,
              idPengambilan: widget.idPengambilan,
              imageFile: pickedFile,
            ),
          ),
        );
      }
    }
    // Jika user membatalkan kamera, tetap di halaman review dengan foto lama
  }

  Future<void> _confirmPhoto() async {
    setState(() => _isUploading = true);
    
    // Simulasi upload foto
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    setState(() => _isUploading = false);

    // Tampilkan success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Foto berhasil disimpan!',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // Navigate ke InputKantongScreen
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InputKantongScreen(
            pickupId: widget.pickupId,
            userName: widget.userName,
            address: widget.address,
            idPengambilan: widget.idPengambilan,
            imageFile: widget.imageFile,
          ),
        ),
      );
    }
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepItem(0, 'Datang', 'Selesai'),
          _buildStepLine(0),
          _buildStepItem(1, 'Foto', 'Progress'),
          _buildStepLine(1),
          _buildStepItem(2, 'Input Kantong', 'Pending'),
          _buildStepLine(2),
          _buildStepItem(3, 'Selesai', 'Pending'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String status) {
    Color circleColor;
    Color textColor;
    
    if (step < _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else if (step == _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else {
      circleColor = Colors.grey[300]!;
      textColor = Colors.grey[500]!;
    }
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: step < _currentStep
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        Text(
          status,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    bool isCompleted = step < _currentStep;
    
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 40),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF009688) : Colors.grey[300],
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Container(
      height: 400,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb
            ? Image.network(
                widget.imageFile.path,
                height: 400,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(widget.imageFile.path),
                height: 400,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Review Foto',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Stepper
          _buildProgressStepper(),
          
          // Photo Preview
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhotoPreview(),
                const SizedBox(height: 20),
                
                // Info text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Apakah foto sudah sesuai?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pastikan sampah dan lokasi terlihat jelas',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Retake button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _retakePhoto,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: primaryColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, 
                             color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ambil Foto Ulang',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _confirmPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Menyimpan...',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Input Kantong',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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
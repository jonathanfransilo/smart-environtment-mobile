import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = "User";
  String _email = "user@email.com";
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Gunakan UserStorage untuk mendapatkan data user yang tersimpan saat login
    final name = await UserStorage.getUserName();
    final email = await UserStorage.getUserEmail();
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = name ?? "User";
      _email = email ?? "user@email.com";
      _profileImagePath = prefs.getString("profile_image");
    });
  }

  // 🔹 Fungsi untuk memilih foto dari galeri
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        await _saveProfileImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔹 Fungsi untuk mengambil foto dari kamera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        await _saveProfileImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔹 Fungsi untuk menyimpan foto profil
  Future<void> _saveProfileImage(String imagePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File('${directory.path}/$fileName');

      await File(imagePath).copy(savedImage.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("profile_image", savedImage.path);

      setState(() {
        _profileImagePath = savedImage.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔹 Fungsi untuk menghapus foto profil
  Future<void> _deleteProfileImage() async {
    try {
      if (_profileImagePath != null) {
        final file = File(_profileImagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("profile_image");

      setState(() {
        _profileImagePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil dihapus'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔹 Dialog untuk memilih sumber foto
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Pilih Foto Profil',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: Text('Pilih dari Galeri', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Ambil Foto', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            if (_profileImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('Hapus Foto', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  // 🔹 Konfirmasi hapus foto
  void _confirmDeleteImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Hapus Foto Profil',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus foto profil?',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfileImage();
            },
            child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔹 widget menu agar lebih rapi & reusable
  Widget _menuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green, // hijau biar match HomeScreen
        title: Text(
          "Profil Saya",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Header dengan avatar & nama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // 🔹 Foto profil dengan tombol edit
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.green.shade200,
                        backgroundImage: _profileImagePath != null
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: _profileImagePath == null
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _email,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Menu list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _menuItem(Icons.settings, "Pengaturan", onTap: () {}),
                  _menuItem(Icons.help, "Bantuan", onTap: () {}),
                  _menuItem(
                    Icons.privacy_tip,
                    "Kebijakan Privasi",
                    onTap: () {},
                  ),

                  const SizedBox(height: 30),

                  // 🔹 Tombol logout
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Gunakan AuthService untuk logout yang proper
                      final auth = AuthService();
                      await auth.logout();

                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          "/login",
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: Text(
                      "Keluar",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

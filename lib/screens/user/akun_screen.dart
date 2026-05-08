import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/user_storage.dart';
import '../../services/profile_service.dart';

/// AkunScreen - Halaman gabungan untuk Edit Akun dan Ubah Password.
///
/// Halaman ini menggabungkan dua fitur utama pengelolaan akun:
/// 1. **Edit Akun** - Mengubah informasi profil seperti nama dan nomor telepon
/// 2. **Ubah Password** - Mengubah kata sandi akun
///
/// Kedua fitur ditampilkan dalam satu halaman menggunakan sistem tab,
/// sehingga pengguna tidak perlu berpindah-pindah halaman.
class AkunScreen extends StatefulWidget {
  const AkunScreen({super.key});

  @override
  State<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends State<AkunScreen>
    with SingleTickerProviderStateMixin {
  // === Tab Controller ===
  late TabController _tabController;

  // === Form Keys (kunci validasi form) ===
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // === Controller untuk Edit Akun ===
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // === Controller untuk Ubah Password ===
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // === Service untuk komunikasi ke API ===
  final _profileService = ProfileService();

  // === State variabel ===
  bool _isLoading = false; // Status loading saat memuat data profil
  bool _isSavingProfile = false; // Status loading saat menyimpan profil
  bool _isSavingPassword = false; // Status loading saat menyimpan password
  bool _obscureCurrentPassword = true; // Sembunyikan password lama
  bool _obscureNewPassword = true; // Sembunyikan password baru
  bool _obscureConfirmPassword = true; // Sembunyikan konfirmasi password
  bool _dataUpdated = false; // Tandai jika ada data yang diubah

  @override
  void initState() {
    super.initState();
    // Inisialisasi TabController dengan 2 tab: Edit Akun & Ubah Password
    _tabController = TabController(length: 2, vsync: this);
    // Muat data profil dari API saat halaman pertama kali dibuka
    _loadUserData();
  }

  @override
  void dispose() {
    // Bersihkan semua controller agar tidak terjadi memory leak
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Memuat data profil pengguna dari API.
  ///
  /// Alur kerja:
  /// 1. Coba ambil data dari API melalui ProfileService
  /// 2. Jika berhasil, tampilkan data dari API
  /// 3. Jika gagal, gunakan data lokal dari SharedPreferences sebagai cadangan
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Langkah 1: Ambil profil dari API
      final (success, message, data) = await _profileService.getProfile();

      if (success && data != null) {
        // Langkah 2: API berhasil - isi form dengan data dari server
        if (mounted) {
          setState(() {
            _nameController.text = data['name']?.toString() ?? '';
            _emailController.text = data['email']?.toString() ?? '';
            _phoneController.text = data['phone']?.toString() ?? '';
            _isLoading = false;
          });
        }
      } else {
        // Langkah 3: API gagal - gunakan data lokal sebagai cadangan
        final email = await UserStorage.getUserEmail();
        final name = await UserStorage.getUserName();
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('user_phone') ?? '';

        if (mounted) {
          setState(() {
            _nameController.text = name ?? '';
            _emailController.text = email ?? '';
            _phoneController.text = phone;
            _isLoading = false;
          });
        }

        // Tampilkan peringatan bahwa data yang ditampilkan adalah data lokal
        if (mounted && message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Memuat data lokal: $message'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Menyimpan perubahan data profil (nama & nomor telepon) ke server.
  ///
  /// Alur kerja:
  /// 1. Validasi form (cek apakah semua field terisi dengan benar)
  /// 2. Kirim data ke API melalui ProfileService
  /// 3. Jika berhasil, simpan juga ke penyimpanan lokal
  /// 4. Tampilkan notifikasi sukses/gagal
  Future<void> _saveProfileChanges() async {
    // Validasi form sebelum menyimpan
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      // Kirim perubahan ke API
      final (success, message, data) = await _profileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (success) {
        // Simpan ke penyimpanan lokal agar data tetap tersedia saat offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text.trim());
        await prefs.setString('user_phone', _phoneController.text.trim());

        // Update UserStorage dengan data terbaru dari server
        if (data != null) {
          int? userId;
          if (data['id'] != null) {
            if (data['id'] is int) {
              userId = data['id'] as int;
            } else if (data['id'] is String) {
              userId = int.tryParse(data['id'] as String);
            }
          }

          if (userId != null) {
            await UserStorage.saveUser(
              id: userId,
              name: data['name']?.toString() ?? _nameController.text.trim(),
              email: data['email']?.toString() ?? _emailController.text.trim(),
              roles: (data['roles'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
              fullData: data,
            );
          }
        }

        if (mounted) {
          setState(() {
            _isSavingProfile = false;
            _dataUpdated = true; // Tandai bahwa data telah diperbarui
          });

          // Tampilkan notifikasi sukses
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Profil berhasil diperbarui',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isSavingProfile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal memperbarui profil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Menyimpan password baru ke server.
  ///
  /// Alur kerja:
  /// 1. Validasi form password (cek format, panjang minimal, kecocokan)
  /// 2. Kirim ke API untuk mengubah password
  /// 3. Jika berhasil, simpan notifikasi dan tampilkan dialog sukses
  Future<void> _saveNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      // Kirim permintaan ubah password ke API
      final (success, message) = await _profileService.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        newPasswordConfirmation: _confirmPasswordController.text.trim(),
      );

      if (success) {
        // Simpan notifikasi perubahan password
        await _savePasswordChangeNotification();

        if (mounted) {
          setState(() {
            _isSavingPassword = false;
            _dataUpdated = true;
          });

          // Kosongkan form password setelah berhasil
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();

          // Tampilkan dialog sukses
          _showPasswordSuccessDialog();
        }
      } else {
        if (mounted) {
          setState(() => _isSavingPassword = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal mengubah password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Menyimpan notifikasi perubahan password ke penyimpanan lokal.
  /// Notifikasi ini akan tampil di halaman notifikasi pengguna.
  Future<void> _savePasswordChangeNotification() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> notifications =
        prefs.getStringList('user_notifications') ?? [];

    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': 'Password Berhasil Diubah',
      'message':
          'Password akun Anda telah berhasil diubah pada ${_formatDateTime(DateTime.now())}',
      'type': 'security',
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    };

    notifications.insert(0, notification.toString());
    await prefs.setStringList('user_notifications', notifications);
  }

  /// Format tanggal dan waktu ke format Indonesia.
  /// Contoh output: "Kamis, 27 Maret 2026 21:59"
  String _formatDateTime(DateTime dateTime) {
    final days = [
      'Minggu', 'Senin', 'Selasa', 'Rabu',
      'Kamis', 'Jumat', 'Sabtu',
    ];
    final months = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember',
    ];

    return '${days[dateTime.weekday % 7]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Menampilkan dialog sukses setelah password berhasil diubah.
  void _showPasswordSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikon sukses dengan animasi lingkaran hijau
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Judul dialog
              Text(
                'Password Berhasil Diubah!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Pesan deskripsi
              Text(
                'Password Anda telah berhasil diperbarui. Gunakan password baru untuk login berikutnya.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Badge notifikasi
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifikasi telah dikirim ke akun Anda',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol OK
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Tutup dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
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

  // ============================================================
  // BAGIAN BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dataUpdated) {
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.green,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, _dataUpdated);
            },
          ),
          title: Text(
            lang.t('account'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            tabs: [
              Tab(
                icon: const Icon(Icons.person_outline, size: 20),
                text: lang.t('edit_account'),
              ),
              Tab(
                icon: const Icon(Icons.lock_outline, size: 20),
                text: lang.t('change_password'),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildEditAkunTab(),
                  _buildChangePasswordTab(),
                ],
              ),
      ),
    );
  }

  /// Membangun tampilan tab "Edit Akun".
  ///
  /// Tab ini berisi form untuk mengubah:
  /// - Nama Lengkap (wajib diisi, minimal 3 karakter)
  /// - Email (hanya ditampilkan, tidak bisa diubah)
  /// - Nomor Telepon (wajib diisi, minimal 10 digit)
  Widget _buildEditAkunTab() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lang.t('info_correct'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildFieldLabel(lang.t('full_name')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _buildInputDecoration(
                  hint: lang.t('enter_name'),
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lang.t('name_required');
                  }
                  if (value.length < 3) {
                    return lang.t('name_min');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildFieldLabel(lang.t('email_login')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                decoration: InputDecoration(
                  hintText: lang.t('registered_email'),
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildFieldLabel(lang.t('phone_number')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _buildInputDecoration(
                  hint: lang.t('enter_phone'),
                  icon: Icons.phone_outlined,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lang.t('phone_required');
                  }
                  if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                    return lang.t('phone_digits_only');
                  }
                  if (value.length < 10) {
                    return lang.t('phone_min');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _saveProfileChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSavingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          lang.t('save_changes'),
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

  /// Membangun tampilan tab "Ubah Password".
  ///
  /// Tab ini berisi form untuk mengubah password dengan validasi:
  /// - Password Lama (wajib diisi)
  /// - Password Baru (minimal 8 karakter, harus mengandung huruf & angka)
  /// - Konfirmasi Password (harus sama dengan password baru)
  Widget _buildChangePasswordTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Kartu Keamanan ===
              // Menampilkan instruksi keamanan password
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade50,
                      Colors.green.shade100,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.security,
                        color: Colors.green.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keamanan Akun',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Password minimal 8 karakter dengan kombinasi huruf dan angka',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // === Field Password Lama ===
              _buildFieldLabel('Password Lama'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: _buildPasswordInputDecoration(
                  hint: 'Masukkan password lama',
                  obscure: _obscureCurrentPassword,
                  onToggle: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password lama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // === Field Password Baru ===
              _buildFieldLabel('Password Baru'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: _buildPasswordInputDecoration(
                  hint: 'Masukkan password baru',
                  obscure: _obscureNewPassword,
                  onToggle: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru tidak boleh kosong';
                  }
                  if (value.length < 8) {
                    return 'Password minimal 8 karakter';
                  }
                  // Cek harus mengandung minimal 1 huruf dan 1 angka
                  if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                    return 'Password harus mengandung huruf dan angka';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Trigger validasi ulang saat pengguna mengetik
                  _passwordFormKey.currentState?.validate();
                },
              ),
              const SizedBox(height: 20),

              // === Field Konfirmasi Password ===
              _buildFieldLabel('Konfirmasi Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: _buildPasswordInputDecoration(
                  hint: 'Masukkan ulang password baru',
                  obscure: _obscureConfirmPassword,
                  onToggle: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konfirmasi password tidak boleh kosong';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // === Kartu Syarat Password ===
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Syarat Password:',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRequirement('Minimal 8 karakter'),
                    _buildRequirement('Mengandung huruf (A-Z atau a-z)'),
                    _buildRequirement('Mengandung angka (0-9)'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // === Tombol Ubah Password ===
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingPassword ? null : _saveNewPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSavingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ubah Password',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WIDGET HELPER
  // ============================================================

  /// Membuat label field form dengan style yang konsisten.
  Widget _buildFieldLabel(String label) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  /// Membuat dekorasi input field standar (untuk nama, telepon, dll).
  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade400,
      ),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.green,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  /// Membuat dekorasi input field untuk password (dengan tombol show/hide).
  InputDecoration _buildPasswordInputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade400,
      ),
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey.shade600,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.green,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  /// Membuat item syarat password (baris dengan ikon centang).
  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

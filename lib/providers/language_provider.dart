import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LanguageProvider - Provider untuk mengelola bahasa aplikasi.
///
/// Mendukung dua bahasa:
/// - Bahasa Indonesia (id)
/// - English (en)
///
/// Provider ini menyimpan preferensi bahasa ke SharedPreferences
/// dan menyediakan terjemahan teks untuk seluruh aplikasi.
class LanguageProvider extends ChangeNotifier {
  // Key untuk menyimpan preferensi bahasa di SharedPreferences
  static const String _languageKey = 'app_language';

  // Kode bahasa saat ini (default: Indonesia)
  String _languageCode = 'id';

  // Getter untuk kode bahasa saat ini
  String get languageCode => _languageCode;

  // Getter untuk mengecek apakah bahasa saat ini adalah Indonesia
  bool get isIndonesian => _languageCode == 'id';

  // Getter untuk Locale saat ini
  Locale get locale => Locale(_languageCode);

  /// Konstruktor - langsung memuat preferensi yang tersimpan
  LanguageProvider() {
    _loadLanguagePreference();
  }

  /// Memuat preferensi bahasa dari SharedPreferences
  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString(_languageKey) ?? 'id';
    notifyListeners();
  }

  /// Mengubah bahasa aplikasi
  /// [code] - kode bahasa ('id' untuk Indonesia, 'en' untuk English)
  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return; // Tidak perlu update jika sama

    _languageCode = code;
    notifyListeners();

    // Simpan preferensi ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  /// Mendapatkan terjemahan teks berdasarkan key.
  ///
  /// Contoh penggunaan:
  /// ```dart
  /// final lang = Provider.of<LanguageProvider>(context);
  /// Text(lang.t('profile_title'))
  /// ```
  String t(String key) {
    return _translations[_languageCode]?[key] ?? key;
  }

  /// Map terjemahan untuk semua teks di aplikasi.
  /// Format: { kode_bahasa: { key: terjemahan } }
  static final Map<String, Map<String, String>> _translations = {
    'id': {
      // === General ===
      'app_name': 'Sirkular',
      'save': 'Simpan',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'close': 'Tutup',
      'ok': 'OK',
      'yes': 'Ya',
      'no': 'Tidak',
      'loading': 'Memuat...',
      'error': 'Terjadi kesalahan',
      'success': 'Berhasil',
      'retry': 'Coba Lagi',
      'search': 'Cari',
      'back': 'Kembali',

      // === Home Screen ===
      'hello': 'Halo',
      'welcome': 'Selamat Datang',
      'service_account': 'Akun Layanan Sampah',
      'billing': 'Tagihan & Pembayaran',
      'service_list': 'Daftar Layanan',
      'schedule': 'Jadwal\n Pengambilan',
      'request_pickup': 'Request\nPengambilan',
      'pickup_history': 'Riwayat\nPengambilan',
      'payment_history': 'Riwayat\nPembayaran',
      'articles': 'Artikel',
      'reporting': 'Pelaporan',
      'home': 'Home',
      'ai_bot': 'AI Bot',
      'profile': 'Profile',

      // === Profile Screen ===
      'my_profile': 'Profile Saya',
      'account': 'Akun',
      'account_subtitle': 'Edit profil & ubah password',
      'settings': 'Pengaturan',
      'settings_subtitle': 'Mode gelap & bahasa',
      'logout': 'Keluar',
      'choose_photo': 'Pilih Foto Profil',
      'choose_gallery': 'Pilih dari Galeri',
      'take_photo': 'Ambil Foto',
      'delete_photo': 'Hapus Foto',
      'delete_photo_confirm': 'Apakah Anda yakin ingin menghapus foto profil?',
      'photo_updated': 'Foto profil berhasil diperbarui',
      'photo_deleted': 'Foto profil berhasil dihapus',

      // === Account Screen ===
      'edit_account': 'Edit Akun',
      'change_password': 'Ubah Password',
      'full_name': 'Nama Lengkap',
      'email_login': 'Email (untuk login)',
      'phone_number': 'Nomor Telepon',
      'save_changes': 'Simpan Perubahan',
      'profile_updated': 'Profil berhasil diperbarui',
      'info_correct': 'Pastikan data yang Anda masukkan benar dan aktif',
      'name_required': 'Nama lengkap tidak boleh kosong',
      'name_min': 'Nama lengkap minimal 3 karakter',
      'phone_required': 'Nomor telepon tidak boleh kosong',
      'phone_digits_only': 'Nomor telepon hanya boleh berisi angka',
      'phone_min': 'Nomor telepon minimal 10 digit',
      'enter_name': 'Masukkan nama lengkap Anda',
      'registered_email': 'Email yang terdaftar',
      'enter_phone': 'Contoh: 081234567890',

      // === Password ===
      'old_password': 'Password Lama',
      'new_password': 'Password Baru',
      'confirm_password': 'Konfirmasi Password',
      'enter_old_password': 'Masukkan password lama',
      'enter_new_password': 'Masukkan password baru',
      'reenter_password': 'Masukkan ulang password baru',
      'password_changed': 'Password Berhasil Diubah!',
      'password_changed_desc':
          'Password Anda telah berhasil diperbarui. Gunakan password baru untuk login berikutnya.',
      'notification_sent': 'Notifikasi telah dikirim ke akun Anda',
      'account_security': 'Keamanan Akun',
      'password_requirement_desc':
          'Password minimal 8 karakter dengan kombinasi huruf dan angka',
      'password_requirements': 'Syarat Password:',
      'req_min_chars': 'Minimal 8 karakter',
      'req_letters': 'Mengandung huruf (A-Z atau a-z)',
      'req_numbers': 'Mengandung angka (0-9)',
      'old_password_required': 'Password lama tidak boleh kosong',
      'new_password_required': 'Password baru tidak boleh kosong',
      'password_min': 'Password minimal 8 karakter',
      'password_alpha_numeric': 'Password harus mengandung huruf dan angka',
      'confirm_password_required': 'Konfirmasi password tidak boleh kosong',
      'password_mismatch': 'Password tidak cocok',

      // === Settings Screen ===
      'dark_mode': 'Mode Gelap',
      'dark_mode_subtitle': 'Ubah tampilan menjadi gelap',
      'language': 'Bahasa',
      'language_subtitle': 'Pilih bahasa aplikasi',
      'indonesian': 'Indonesia',
      'english': 'English',
      'language_changed': 'Bahasa diubah ke',
      'select_language': 'Pilih Bahasa',
      'dark_mode_on': 'Mode Gelap Diaktifkan',
      'dark_mode_off': 'Mode Terang Diaktifkan',

      // === Service Account ===
      'no_service_account':
          'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
      'add_account': 'Tambah Akun',
      'activate': 'Aktifkan',
      'account_activated': 'berhasil diaktifkan',
    },
    'en': {
      // === General ===
      'app_name': 'Sirkular',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'close': 'Close',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'loading': 'Loading...',
      'error': 'An error occurred',
      'success': 'Success',
      'retry': 'Retry',
      'search': 'Search',
      'back': 'Back',

      // === Home Screen ===
      'hello': 'Hello',
      'welcome': 'Welcome',
      'service_account': 'Waste Service Account',
      'billing': 'Bills & Payments',
      'service_list': 'Services',
      'schedule': 'Pickup\nSchedule',
      'request_pickup': 'Request\nPickup',
      'pickup_history': 'Pickup\nHistory',
      'payment_history': 'Payment\nHistory',
      'articles': 'Articles',
      'reporting': 'Reports',
      'home': 'Home',
      'ai_bot': 'AI Bot',
      'profile': 'Profile',

      // === Profile Screen ===
      'my_profile': 'My Profile',
      'account': 'Account',
      'account_subtitle': 'Edit profile & change password',
      'settings': 'Settings',
      'settings_subtitle': 'Dark mode & language',
      'logout': 'Log Out',
      'choose_photo': 'Choose Profile Photo',
      'choose_gallery': 'Choose from Gallery',
      'take_photo': 'Take Photo',
      'delete_photo': 'Delete Photo',
      'delete_photo_confirm':
          'Are you sure you want to delete your profile photo?',
      'photo_updated': 'Profile photo updated successfully',
      'photo_deleted': 'Profile photo deleted successfully',

      // === Account Screen ===
      'edit_account': 'Edit Account',
      'change_password': 'Change Password',
      'full_name': 'Full Name',
      'email_login': 'Email (for login)',
      'phone_number': 'Phone Number',
      'save_changes': 'Save Changes',
      'profile_updated': 'Profile updated successfully',
      'info_correct': 'Make sure the data you enter is correct and active',
      'name_required': 'Full name cannot be empty',
      'name_min': 'Full name minimum 3 characters',
      'phone_required': 'Phone number cannot be empty',
      'phone_digits_only': 'Phone number can only contain digits',
      'phone_min': 'Phone number minimum 10 digits',
      'enter_name': 'Enter your full name',
      'registered_email': 'Registered email',
      'enter_phone': 'Example: 081234567890',

      // === Password ===
      'old_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_password': 'Confirm Password',
      'enter_old_password': 'Enter current password',
      'enter_new_password': 'Enter new password',
      'reenter_password': 'Re-enter new password',
      'password_changed': 'Password Changed Successfully!',
      'password_changed_desc':
          'Your password has been updated. Use your new password for the next login.',
      'notification_sent': 'Notification has been sent to your account',
      'account_security': 'Account Security',
      'password_requirement_desc':
          'Password minimum 8 characters with combination of letters and numbers',
      'password_requirements': 'Password Requirements:',
      'req_min_chars': 'Minimum 8 characters',
      'req_letters': 'Contains letters (A-Z or a-z)',
      'req_numbers': 'Contains numbers (0-9)',
      'old_password_required': 'Current password cannot be empty',
      'new_password_required': 'New password cannot be empty',
      'password_min': 'Password minimum 8 characters',
      'password_alpha_numeric': 'Password must contain letters and numbers',
      'confirm_password_required': 'Confirm password cannot be empty',
      'password_mismatch': 'Passwords do not match',

      // === Settings Screen ===
      'dark_mode': 'Dark Mode',
      'dark_mode_subtitle': 'Switch to dark appearance',
      'language': 'Language',
      'language_subtitle': 'Choose app language',
      'indonesian': 'Indonesian',
      'english': 'English',
      'language_changed': 'Language changed to',
      'select_language': 'Select Language',
      'dark_mode_on': 'Dark Mode Enabled',
      'dark_mode_off': 'Light Mode Enabled',

      // === Service Account ===
      'no_service_account':
          'You don\'t have a service account yet. Please create one first.',
      'add_account': 'Add Account',
      'activate': 'Activate',
      'account_activated': 'successfully activated',
    },
  };
}

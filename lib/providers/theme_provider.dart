import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ThemeProvider extends ChangeNotifier {
  // Key untuk menyimpan preferensi tema di SharedPreferences
  static const String _themeKey = 'is_dark_mode';

  // Status apakah mode gelap aktif
  bool _isDarkMode = false;

  // Getter untuk mengecek apakah mode gelap aktif
  bool get isDarkMode => _isDarkMode;

  // Getter untuk mendapatkan ThemeMode saat ini
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Konstruktor - langsung memuat preferensi yang tersimpan
  ThemeProvider() {
    _loadThemePreference();
  }

  /// Memuat preferensi tema dari SharedPreferences.
  /// Dipanggil saat provider pertama kali dibuat.
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  /// Mengubah tema antara mode gelap dan terang.
  /// [isDark] - true untuk mode gelap, false untuk mode terang
  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();

    // Simpan preferensi ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  /// Toggle tema (balik dari mode saat ini ke mode sebaliknya)
  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }

  /// Tema terang untuk aplikasi
  ThemeData get lightTheme => ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
      );

  /// Tema gelap untuk aplikasi
  ThemeData get darkTheme => ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF2D2D2D),
        ),
      );
}

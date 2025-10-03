import 'package:flutter/material.dart';

// 🔹 Gunakan folder "screens"
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/layanan_sampah_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/user/artikel_screen.dart';
import 'screens/user/pelaporan_screen.dart'; // ✅ Import pelaporan
import 'screens/kolektor/home_screens_kolektor.dart';


void main() {
  runApp(const SirkularApp());
}

class SirkularApp extends StatelessWidget {
  const SirkularApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sirkular',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/layanan-sampah': (context) => const LayananSampahScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/artikel': (context) => const ArtikelScreen(),
        '/pelaporan': (context) => const PelaporanScreen(),
        '/home-kolektor': (context) => const HomeScreensKolektor(), // 🔹 route kolektor
      },
      // Handling kalau route tidak ada
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                "404 - Halaman tidak ditemukan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/layanan_sampah_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/user/artikel_screen.dart';
import 'screens/user/pelaporan_screen.dart';
import 'screens/kolektor/home_screens_kolektor.dart';
import 'screens/kolektor/pengambilan_sampah_screen.dart';
import 'screens/kolektor/ambil_foto_screen.dart';

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
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
        },
      ),

      // 🔹 Route awal
      initialRoute: '/',

      // 🔹 Daftar route
      routes: {
        // --- ROUTE UMUM ---
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),

        // --- ROUTE USER ---
        '/home': (context) => const HomeScreen(),
        '/layanan-sampah': (context) => const LayananSampahScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/artikel': (context) => const ArtikelScreen(),
        '/pelaporan': (context) => const PelaporanScreen(),

        // --- ROUTE KOLEKTOR ---
        '/home-kolektor': (context) => const HomeScreensKolektor(),

        // 🔹 Halaman Pengambilan Sampah
        '/pengambilan-sampah': (context) => const PengambilanSampahScreen(
              userName: 'Davina Ajah',
              userPhone: '+6285943643645',
              address: 'Jl. Raya Menteng no. 11 RT05 / RW03',
              idPengambilan: '#CLUAP09141441',
              distance: '10 Km',
              time: '50m',
              latitude: -6.198324,
              longitude: 106.841729,
            ),

        // 🔹 Halaman Ambil Foto
        '/ambil-foto': (context) => const AmbilFotoScreen(
              userName: 'Davina Ajah',
              address: 'Jl. Raya Menteng no. 11 RT05 / RW03',
              idPengambilan: '#CLUAP09141441',
            ),
      },

      // 🔹 Handling kalau route tidak ditemukan
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

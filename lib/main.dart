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
import 'screens/user/artikel_detail_screen.dart';
import 'screens/user/pelaporan_screen.dart';
import 'screens/user/riwayat_pembayaran_screen.dart';
import 'screens/user/express_request_screen.dart';
import 'screens/kolektor/home_screens_kolektor.dart';

/// Global navigator key untuk akses navigation dari mana saja (termasuk ApiClient)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey, // Global navigator key
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
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),

        // --- ROUTE USER ---
        '/home': (context) => const HomeScreen(),
        '/layanan-sampah': (context) => const LayananSampahScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/artikel': (context) => const ArtikelScreen(),
        '/pelaporan': (context) => const PelaporanScreen(),
        '/riwayat-pembayaran': (context) => const RiwayatPembayaranScreen(),
        '/express-request': (context) => const ExpressRequestScreen(),

        // --- ROUTE KOLEKTOR ---
        '/home-kolektor': (context) => const HomeScreensKolektor(),

        // Note: PengambilanSampahScreen, AmbilFotoScreen, dll sekarang diakses via Navigator.push dengan parameter dinamis
      },

      // Custom route handler for routes with parameters
      onGenerateRoute: (settings) {
        // Handle splash screen dengan sessionExpired parameter
        if (settings.name == '/') {
          final args = settings.arguments;
          bool sessionExpired = false;
          if (args is Map<String, dynamic>) {
            sessionExpired = args['sessionExpired'] ?? false;
          }
          return MaterialPageRoute(
            builder: (context) => SplashScreen(sessionExpired: sessionExpired),
          );
        }
        
        // Handle artikel-detail route with ID parameter
        if (settings.name == '/artikel-detail') {
          final artikelId = settings.arguments as int?;
          if (artikelId != null) {
            return MaterialPageRoute(
              builder: (context) => ArtikelDetailScreen(articleId: artikelId),
            );
          }
        }
        return null;
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

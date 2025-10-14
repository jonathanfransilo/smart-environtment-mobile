import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/token_storage.dart';
import '../services/user_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();

    // Controller animasi background wave
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Controller animasi pulse logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Check auto-login
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      print('🔍 [Splash] Starting auto-login check...');
      
      await Future.delayed(const Duration(seconds: 2)); // Minimal splash time
      
      if (!mounted) {
        print('⚠️ [Splash] Widget not mounted, aborting');
        return;
      }
      
      final token = await TokenStorage.getToken();
      print('🔑 [Splash] Token: ${token != null ? "Found (${token.substring(0, 20)}...)" : "Not found"}');
      
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // User sudah login, check role untuk redirect
        print('👤 [Splash] Checking user role...');
        final isCollector = await UserStorage.isCollector();
        print('📋 [Splash] Is collector: $isCollector');
        
        if (!mounted) return;
        
        // Small delay to ensure context is ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        if (isCollector) {
          print('🚛 [Splash] Redirecting to collector home...');
          Navigator.of(context).pushReplacementNamed('/home-kolektor');
        } else {
          print('🏠 [Splash] Redirecting to user home...');
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Belum login, tampilkan tombol
        print('🔓 [Splash] No token found, showing login button');
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ [Splash] Error during auto-login check: $e');
      print('Stack trace: $stackTrace');
      
      // Jika error, tampilkan tombol login sebagai fallback
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        
        // Optional: Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat memuat aplikasi'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ===== Wave Background =====
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper1(_waveController.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  color: const Color(0xFF2A8D7C),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper2(_waveController.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.50,
                  color: const Color(0xFF36B8A6).withAlpha(179),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper3(_waveController.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  color: const Color(0xFF4ECDC4).withAlpha(128),
                ),
              );
            },
          ),

          // ===== Konten Utama =====
          Center(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo PNG dengan animasi pulse
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/sirkular.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Judul
                Text(
                  "SIRKULAR",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                // Subjudul
                Text(
                  "Waste Management App",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 1),

                // Tombol Mulai Sekarang atau Loading
                if (_isChecking)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 21, 145, 137),
                    ),
                  )
                else
                  SizedBox(
                    width: 230,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Mulai Sekarang",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Color.fromARGB(255, 21, 145, 137),
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 150),
              ],
            ),
          ),

          // ===== Versi Aplikasi =====
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "V. 1.0.0",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ====================
/// Wave Clippers
/// ====================
class WaveClipper1 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper1(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 40;
    double waveLength = size.width / 1.0;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin((i / waveLength * 2 * math.pi) +
                    (animationValue * 2 * math.pi)) *
                20,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper1 oldClipper) => true;
}

class WaveClipper2 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper2(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 30;
    double waveLength = size.width / 1.2;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin((i / waveLength * 2 * math.pi) +
                    (animationValue * 2 * math.pi)) *
                15,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper2 oldClipper) => true;
}

class WaveClipper3 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper3(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 20;
    double waveLength = size.width / 1.5;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin((i / waveLength * 2 * math.pi) +
                    (animationValue * 2 * math.pi)) *
                10,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper3 oldClipper) => true;
}
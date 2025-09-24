import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // animasi berulang
  }

  @override
  void dispose() {
    _controller.dispose();
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
            animation: _controller,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper1(_controller.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  color: const Color(0xFF2A8D7C),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper2(_controller.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.50,
                  color: const Color(0xFF36B8A6).withOpacity(0.7),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipPath(
                clipper: WaveClipper3(_controller.value),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  color: const Color(0xFF4ECDC4).withOpacity(0.5),
                ),
              );
            },
          ),

          // ===== Konten Utama =====
          Center(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/logscreen.png',
                      width: 60,
                      height: 60,
                      placeholderBuilder: (BuildContext context) => Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco,
                          color: Colors.white,
                          size: 30,
                        ),
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
                  "Lorem ipsum dolor sit amet",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 1),

                // Tombol Mulai Sekarang
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
                      mainAxisSize: MainAxisSize.min, // biar ngepas konten
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Home Page",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
      ),
      body: Center(
        child: Text(
          "Selamat datang di Home Page!",
          style: GoogleFonts.poppins(fontSize: 18),
        ),
      ),
    );
  }
}

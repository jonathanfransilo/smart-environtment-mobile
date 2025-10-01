import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArtikelDetailScreen extends StatelessWidget {
  final Map<String, String> article;

  const ArtikelDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detail Artikel", style: GoogleFonts.poppins()),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Header
            Image.network(
              article['image']!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),

            // Judul Artikel
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                article['title']!,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Isi Artikel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                article['content']!,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

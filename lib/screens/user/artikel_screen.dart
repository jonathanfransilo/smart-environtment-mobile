import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:blur/blur.dart'; 
import 'artikel_detail_screen.dart';

class ArtikelScreen extends StatefulWidget {
  const ArtikelScreen({super.key});

  @override
  State<ArtikelScreen> createState() => _ArtikelScreenState();
}

class _ArtikelScreenState extends State<ArtikelScreen> {
  final List<Map<String, String>> _articles = const [
    {
      "title": "Perpanjangan Tanggung Jawab Produsen dan Implementasi di Indonesia",
      "image": "https://drive.google.com/uc?export=view&id=1qjMCUnULqvjAzzMtpd2v2jctliNJWi9G",
      "content": "Extended Producer Responsibility (EPR) menekankan bahwa produsen bertanggung jawab atas seluruh siklus hidup produk mereka, termasuk tahap akhir (pembuangan dan daur ulang).",
      "type": "artikel"
    },
    {
      "title": "5 Hal yang Perlu Anda Ketahui Tentang Extended Producer Responsibility (EPR)",
      "image": "https://drive.google.com/uc?export=view&id=1rcruFRS7rrGgQP5whXAonFPEQfz27mMq",
      "content": "EPR adalah konsep yang memberikan tanggung jawab lebih besar kepada produsen untuk mengelola limbah kemasan yang mereka hasilkan, mendorong desain produk yang ramah lingkungan.",
      "type": "artikel"
    },
    {
      "title": "Tips Mengurangi Sampah Plastik di Kehidupan Sehari-hari",
      "image": "https://drive.google.com/uc?export=view&id=1ZawfY_Ktp5ZVeQb4T1mVQ9qONZXVaKDO",
      "content": "Kurangi penggunaan plastik sekali pakai dengan membawa tas belanja, botol minum, dan wadah makanan sendiri. Ini adalah langkah kecil dengan dampak besar.",
      "type": "artikel"
    },
    {
      "title": "Manfaat Daur Ulang bagi Lingkungan dan Ekonomi",
      "image": "https://drive.google.com/uc?export=view&id=1DIdr3ulKtU5oagWsA4pufnTzhZ1S_9ge",
      "content": "Daur ulang bukan hanya menyelamatkan lingkungan dari penumpukan limbah, tapi juga memberi manfaat ekonomi dengan menciptakan lapangan kerja dan mengurangi biaya produksi.",
      "type": "artikel"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Artikel",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        elevation: 4,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _articles.length,
        itemBuilder: (context, i) => FancyArtikelCard(article: _articles[i], index: i),
      ),
    );
  }
}

class FancyArtikelCard extends StatefulWidget {
  final Map<String, String> article;
  final int index;

  const FancyArtikelCard({super.key, required this.article, required this.index});

  @override
  State<FancyArtikelCard> createState() => _FancyArtikelCardState();
}

class _FancyArtikelCardState extends State<FancyArtikelCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArtikelDetailScreen(article: widget.article)),
              );
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 100),
              child: ArtikelCard(article: widget.article),
            ),
          ),
        ),
      ),
    );
  }
}

class ArtikelCard extends StatelessWidget {
  final Map<String, String> article;
  const ArtikelCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              article['image']!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                // Blur + Shimmer
                return Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    color: Colors.grey.shade300,
                  ),
                ).blurred(
                  blur: 5,
                  blurColor: Colors.grey.shade300,
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 50,
            right: 16,
            child: Text(
              article['title']!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [const Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Baca Selengkapnya",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    shadows: [const Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

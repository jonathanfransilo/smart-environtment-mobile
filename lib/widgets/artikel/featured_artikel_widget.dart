import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artikel_model.dart';
import '../../services/artikel_service.dart';
import '../../screens/user/artikel_detail_screen.dart';
import '../../screens/user/artikel_screen.dart';

/// Widget untuk menampilkan artikel unggulan di homepage/dashboard
/// Default menampilkan 3 artikel terbaru
class FeaturedArtikelWidget extends StatefulWidget {
  final int limit;
  final bool showViewAllButton;

  const FeaturedArtikelWidget({
    super.key,
    this.limit = 3,
    this.showViewAllButton = true,
  });

  @override
  State<FeaturedArtikelWidget> createState() => _FeaturedArtikelWidgetState();
}

class _FeaturedArtikelWidgetState extends State<FeaturedArtikelWidget> {
  final ArtikelService _artikelService = ArtikelService();
  List<ArtikelModel> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeaturedArticles();
  }

  Future<void> _loadFeaturedArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final articles = await _artikelService.getFeaturedArticles(
        limit: widget.limit,
      );
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Artikel Terbaru',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (widget.showViewAllButton)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ArtikelScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Lihat Semua',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF009688),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Content
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat artikel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadFeaturedArticles,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Coba Lagi', style: GoogleFonts.poppins(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF009688),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_articles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Belum ada artikel',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          return FeaturedArtikelCard(article: _articles[index]);
        },
      ),
    );
  }
}

/// Card untuk artikel unggulan (horizontal scroll)
class FeaturedArtikelCard extends StatelessWidget {
  final ArtikelModel article;

  const FeaturedArtikelCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.imageUrl ?? 'https://via.placeholder.com/300x180?text=No+Image';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtikelDetailScreen(article: article),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 110,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (article.publishedAt != null)
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(article.publishedAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hari ini';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }
}

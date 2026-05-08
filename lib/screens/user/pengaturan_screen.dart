import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';

/// PengaturanScreen - Halaman Pengaturan Aplikasi
///
/// Halaman ini menampilkan pengaturan yang tersedia:
/// 1. **Mode Gelap** - Toggle switch untuk mengubah tema (gelap/terang)
/// 2. **Bahasa** - Pilihan bahasa (Indonesia/English) dengan ikon bendera
///
/// Semua perubahan langsung diterapkan dan disimpan secara permanen.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green,
        title: Text(
          langProvider.t('settings'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Header Pengaturan ===
              _buildSettingsHeader(context, isDark, langProvider),
              const SizedBox(height: 24),

              // === Section: Tampilan ===
              _buildSectionTitle(
                context,
                isDark,
                Icons.palette_outlined,
                langProvider.isIndonesian ? 'Tampilan' : 'Appearance',
              ),
              const SizedBox(height: 12),

              // === Card Mode Gelap ===
              _buildDarkModeCard(context, themeProvider, langProvider, isDark),
              const SizedBox(height: 24),

              // === Section: Bahasa ===
              _buildSectionTitle(
                context,
                isDark,
                Icons.language,
                langProvider.t('language'),
              ),
              const SizedBox(height: 12),

              // === Card Bahasa ===
              _buildLanguageCard(context, langProvider, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Header pengaturan dengan ilustrasi
  Widget _buildSettingsHeader(
    BuildContext context,
    bool isDark,
    LanguageProvider langProvider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikon settings animasi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langProvider.t('settings'),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  langProvider.isIndonesian
                      ? 'Sesuaikan tampilan & bahasa'
                      : 'Customize appearance & language',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section title dengan ikon
  Widget _buildSectionTitle(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Card mode gelap dengan toggle switch
  Widget _buildDarkModeCard(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider langProvider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Ikon mode gelap dengan animasi
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.shade800.withOpacity(0.2)
                    : Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  key: ValueKey(isDark),
                  color: isDark ? Colors.amber.shade400 : Colors.indigo,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Teks deskripsi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langProvider.t('dark_mode'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    langProvider.t('dark_mode_subtitle'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Toggle Switch dengan animasi
            Transform.scale(
              scale: 1.1,
              child: Switch(
                value: isDark,
                onChanged: (value) {
                  themeProvider.setDarkMode(value);

                  // Tampilkan snackbar konfirmasi
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            value ? Icons.dark_mode : Icons.light_mode,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            value
                                ? langProvider.t('dark_mode_on')
                                : langProvider.t('dark_mode_off'),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                activeColor: Colors.green,
                activeTrackColor: Colors.green.shade200,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card pilihan bahasa
  Widget _buildLanguageCard(
    BuildContext context,
    LanguageProvider langProvider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // === Bahasa Indonesia ===
          _buildLanguageOption(
            context: context,
            langProvider: langProvider,
            isDark: isDark,
            languageCode: 'id',
            languageName: 'Indonesia',
            nativeName: 'Bahasa Indonesia',
            flagEmoji: '🇮🇩',
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            indent: 70,
            endIndent: 16,
          ),

          // === English ===
          _buildLanguageOption(
            context: context,
            langProvider: langProvider,
            isDark: isDark,
            languageCode: 'en',
            languageName: 'English',
            nativeName: 'English',
            flagEmoji: '🇬🇧',
          ),
        ],
      ),
    );
  }

  /// Widget item bahasa individual
  Widget _buildLanguageOption({
    required BuildContext context,
    required LanguageProvider langProvider,
    required bool isDark,
    required String languageCode,
    required String languageName,
    required String nativeName,
    required String flagEmoji,
  }) {
    final isSelected = langProvider.languageCode == languageCode;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          langProvider.setLanguage(languageCode);

          // Tampilkan snackbar konfirmasi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(
                    flagEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${langProvider.t('language_changed')} $languageName',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.green.withOpacity(0.1)
                  : Colors.green.withOpacity(0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Bendera
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  flagEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Nama bahasa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.green
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nativeName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Indikator terpilih
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.green : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.green
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

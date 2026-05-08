import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sirkular_app/services/chatbot_service.dart';
import 'jadwal_pengambilan_screen.dart';
import 'riwayat_pengambilan_screen.dart';
import 'payment_method_screen.dart';
import 'payment_process_screen.dart';
import 'tambah_akun_layanan_screen.dart';

class ChatbotScreen extends StatefulWidget {
  final String? userName;
  final String? serviceAccountId;
  
  const ChatbotScreen({super.key, this.userName, this.serviceAccountId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final ChatbotService _chatbotService = ChatbotService();
  bool _isTyping = false;
  // Store latest invoice data for payment navigation
  List<Map<String, dynamic>>? _pendingInvoiceData;

  @override
  void initState() {
    super.initState();
    // Initial greeting
    _messages.add({
      'role': 'bot',
      'type': 'text',
      'content': 'Halo! Saya Smart AI Anda. 🤖\n\nSaya bisa berbicara dalam Bahasa Indonesia dan English! 🌐\n\nAda yang bisa saya bantu terkait pengelolaan sampah atau jadwal penjemputan hari ini?',
      'time': '11:30',
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        // Read bytes for cross-platform display (works on both web and mobile)
        final Uint8List imageBytes = await photo.readAsBytes();
        final String fileName = photo.name;

        setState(() {
          _messages.add({
            'role': 'user',
            'type': 'image',
            'content': photo.path,
            'imageBytes': imageBytes,
            'fileName': fileName,
            'time': _getCurrentTime(),
          });
          _isTyping = true;
        });
        _scrollToBottom();
        
        // AI responds to the image with helpful context
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isTyping = false;
              _messages.add({
                'role': 'bot',
                'type': 'text',
                'content': _getImageResponse(fileName),
                'time': _getCurrentTime(),
              });
            });
            _scrollToBottom();
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat gambar. Silakan coba lagi.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getImageResponse(String fileName) {
    final name = widget.userName ?? 'Kak';
    final lowerName = fileName.toLowerCase();

    // Detect image content from filename hints
    if (lowerName.contains('sampah') || lowerName.contains('trash') || 
        lowerName.contains('waste') || lowerName.contains('garbage')) {
      return "Terima kasih sudah kirim fotonya, $name! 📸\n\n"
             "Sepertinya foto ini berkaitan dengan sampah. Berikut yang bisa aku bantu:\n\n"
             "🗑️ **Pelaporan Sampah**\n"
             "   Jika kamu ingin melaporkan tumpukan sampah, ketik \"buka pelaporan\"\n\n"
             "📅 **Jadwal Pengambilan**\n"
             "   Untuk cek jadwal pengambilan, ketik \"jadwal\"\n\n"
             "Atau ceritakan lebih detail tentang foto ini ya! 😊";
    }

    // General image response - helpful and contextual
    return "Terima kasih sudah kirim fotonya, $name! 📸\n\n"
           "Fotonya sudah aku terima dengan baik. Untuk saat ini, aku belum bisa menganalisis isi gambar secara otomatis, tapi aku bisa bantu kamu dengan beberapa hal:\n\n"
           "🗑️ Jika ini foto **sampah menumpuk**, ketik \"buka pelaporan\" untuk melaporkan\n\n"
           "📋 Jika ini foto **bukti pembayaran**, kamu bisa cek di menu \"riwayat pembayaran\"\n\n"
           "💬 Atau ceritakan apa yang ada di foto tersebut, dan aku akan coba membantu! 😊";
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ambil foto dari',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  color: Colors.blue,
                  label: 'Kamera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library_rounded,
                  color: Colors.purple,
                  label: 'Galeri',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== NAVIGATION HANDLING ==========

  void _handleNavAction(ChatbotNavAction action) {
    switch (action.route) {
      case 'jadwal_pengambilan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JadwalPengambilanScreen(
              serviceAccountId: int.tryParse(widget.serviceAccountId ?? '1') ?? 1,
            ),
          ),
        );
        break;
      case 'request_pengambilan':
        Navigator.pushNamed(
          context,
          '/express-request',
          arguments: {
            'serviceAccountId': widget.serviceAccountId,
          },
        );
        break;
      case 'riwayat_pengambilan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RiwayatPengambilanScreen(
              serviceAccountId: widget.serviceAccountId ?? '0',
              accountName: widget.userName ?? 'Akun',
            ),
          ),
        );
        break;
      case 'riwayat_pembayaran':
        Navigator.pushNamed(
          context,
          '/riwayat-pembayaran',
          arguments: {
            'serviceAccountId': widget.serviceAccountId,
          },
        );
        break;
      case 'artikel':
        Navigator.pushNamed(context, '/artikel');
        break;
      case 'pelaporan':
        Navigator.pushNamed(
          context,
          '/pelaporan',
          arguments: {
            'serviceAccountId': widget.serviceAccountId,
          },
        );
        break;
      case 'tambah_akun_layanan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TambahAkunLayananScreen(),
          ),
        );
        break;
      case 'payment_method':
        _navigateToPayment();
        break;
      default:
        debugPrint('Unknown route: ${action.route}');
    }
  }

  void _navigateToPayment() {
    if (_pendingInvoiceData != null && _pendingInvoiceData!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(
            invoices: _pendingInvoiceData!,
          ),
        ),
      );
    }
  }

  IconData _getIconForAction(String iconName) {
    switch (iconName) {
      case 'calendar_today': return Icons.calendar_today_rounded;
      case 'local_shipping': return Icons.local_shipping_rounded;
      case 'history': return Icons.history_rounded;
      case 'receipt_long': return Icons.receipt_long_rounded;
      case 'article': return Icons.article_rounded;
      case 'report_problem': return Icons.report_problem_rounded;
      case 'payment': return Icons.payment_rounded;
      case 'person_add': return Icons.person_add_alt_1_rounded;
      default: return Icons.open_in_new_rounded;
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'type': 'text',
        'content': text,
        'time': _getCurrentTime(),
      });
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _chatbotService.sendMessage(
        text,
        serviceAccountId: widget.serviceAccountId,
        userName: widget.userName,
      );
      
      if (mounted) {
        // Store invoice data if this is a payment intent
        if (response.hasPaymentIntent) {
          _pendingInvoiceData = response.invoiceData;
        }

        setState(() {
          _isTyping = false;
          final messageData = <String, dynamic>{
            'role': 'bot',
            'type': response.hasActions ? 'nav_actions' : 'text',
            'content': response.message,
            'time': _getCurrentTime(),
          };
          if (response.hasActions) {
            messageData['actions'] = response.actions;
          }
          _messages.add(messageData);
        });
        _scrollToBottom();

        // Auto-navigate to PaymentProcessScreen if AI processed payment automatically
        if (response.hasAutoPayment) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentProcessScreen(
                  payment: response.paymentResult!,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'bot',
            'type': 'text', 
            'content': 'Maaf, terjadi kesalahan saat menghubungi server.',
            'time': _getCurrentTime(),
          });
        });
        _scrollToBottom();
      }
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9), // Very light mint background
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isTyping ? 1 : 1), // +1 for date header or typing indicator
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDateSeparator(); // Always show date at top
                }
                
                // Adjust index because of the 0-th item (Date Separator)
                final messageIndex = index - 1;
                
                if (messageIndex >= _messages.length) {
                   return _isTyping ? _buildTypingIndicator() : const SizedBox.shrink();
                }

                final message = _messages[messageIndex];
                final isLastMessage = messageIndex == _messages.length - 1;

                return Column(
                  children: [
                     // Show suggestions only after the initial welcome message, if it's the last one
                    if (messageIndex == 0 && isLastMessage && !_isTyping)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 24.0),
                         child: _buildWelcomeSuggestions(),
                       ),

                    if (message['role'] == 'bot')
                      _buildIncomingMessage(message)
                    else
                      _buildOutgoingMessage(message),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF00897B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${widget.userName ?? 'Warga'}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'AI Assistant Online',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'HARI INI, ${_getCurrentTime()}',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSuggestions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 44), // Offset for avatar space
          _buildChip('Klasifikasi Sampah'),
          const SizedBox(width: 8),
          _buildChip('Jadwal Jemput'),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.grey.shade600, size: 20),
                onPressed: _showAttachmentOptions, 
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: _handleSubmitted,
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () => _handleSubmitted(_messageController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingMessage(Map<String, dynamic> message) {
    Widget contentWidget;

    if (message['type'] == 'nav_actions') {
      // Navigation actions message - show text + clickable action buttons
      final actions = message['actions'] as List<ChatbotNavAction>? ?? [];
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['content'],
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) => _buildNavActionButton(action)).toList(),
            ),
          ],
        ],
      );
    } else if (message['type'] == 'rich_warning') {
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['content'],
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF4A4A4A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildWarningCard(
            label: 'Pecahan Kaca',
            description: 'Bungkus dengan koran atau kardus tebal, beri label "TAJAM", dan masukkan ke sampah residu.',
            color: const Color(0xFFFFEBEE),
            borderColor: const Color(0xFFFFCDD2),
            iconColor: Colors.red.shade700,
            textColor: const Color(0xFFD32F2F),
            descColor: const Color(0xFFB71C1C),
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
          _buildWarningCard(
            label: 'Baterai Bekas',
            description: 'JANGAN buang ke tempat sampah biasa. Simpan terpisah dan serahkan ke petugas B3.',
            color: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFECB3),
            iconColor: Colors.amber.shade900,
            textColor: Colors.amber.shade900,
            descColor: Colors.brown.shade700,
            icon: Icons.battery_alert,
          ),
        ],
      );
    } else {
      contentWidget = Text(
        message['content'],
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFF1A1A1A),
          height: 1.5,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFB2DFDB)),
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            size: 18,
            color: Color(0xFF00897B),
          ),
        ),
        const SizedBox(width: 12),
        // Bubble
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                 BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: contentWidget,
          ),
        ),
        const SizedBox(width: 40), // Spacing from right edge
      ],
    );
  }

  Widget _buildNavActionButton(ChatbotNavAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNavAction(action),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00897B).withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForAction(action.icon),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required String label,
    required String description,
    required Color color,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    required Color descColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: descColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingMessage(Map<String, dynamic> message) {
    
    Widget contentWidget;
    if (message['type'] == 'image') {
      final Uint8List? imageBytes = message['imageBytes'] as Uint8List?;
      Widget imageWidget;

      if (imageBytes != null) {
        // Primary: Use Image.memory for cross-platform support
        imageWidget = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorPlaceholder();
          },
        );
      } else if (kIsWeb) {
        // Web fallback: Use Image.network (XFile.path is a blob URL on web)
        imageWidget = Image.network(
          message['content'],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorPlaceholder();
          },
        );
      } else {
        // Mobile fallback: Use Image.file
        imageWidget = Image.file(
          File(message['content']),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorPlaceholder();
          },
        );
      }

      contentWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 250,
            maxWidth: 250,
          ),
          child: imageWidget,
        ),
      );
    } else {
      contentWidget = Text(
        message['content'],
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white,
          height: 1.5,
        ),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
         const SizedBox(width: 40), // Spacing from left edge
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: message['type'] == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)], // Teal Gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 137, 123, 0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: contentWidget,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageErrorPlaceholder() {
    return Container(
      width: 200,
      height: 150,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(
            'Gambar tidak dapat ditampilkan',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return GestureDetector(
      onTap: () => _handleSubmitted(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF00897B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFB2DFDB),
          shape: BoxShape.circle,
        ),
      );
  }
}
